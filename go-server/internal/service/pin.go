package service

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/json"
	"errors"
	"math"
	"reflect"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/google/uuid"

	"github.com/lrprojects/monaserver/internal/apperrors"
	"github.com/lrprojects/monaserver/internal/db"
	"github.com/lrprojects/monaserver/internal/image"
)

const CreatePinXP = 5
const CreateGroupPinXP = 5
const maxPinPhotoBytes = 8 << 20

// PinObjectStore is the subset of the object service used by pin photos.
type PinObjectStore interface {
	Put(context.Context, string, []byte, string) error
	Remove(context.Context, string) error
	GetIfExists(context.Context, string) ([]byte, bool, error)
	PresignedGet(context.Context, string) (string, error)
}

// Pin service — mirrors PinServiceImpl.
type Pin struct {
	q   *db.Queries
	obj PinObjectStore
}

func NewPin(q *db.Queries, obj PinObjectStore) *Pin {
	if obj != nil {
		value := reflect.ValueOf(obj)
		if (value.Kind() == reflect.Pointer || value.Kind() == reflect.Interface) && value.IsNil() {
			obj = nil
		}
	}
	return &Pin{q: q, obj: obj}
}

// PinDTO is the shape returned by pin endpoints.
type PinDTO struct {
	ID            uuid.UUID  `json:"id"`
	Latitude      float64    `json:"latitude"`
	Longitude     float64    `json:"longitude"`
	CreationDate  *time.Time `json:"creationDate,omitempty"`
	UpdateDate    *time.Time `json:"updateDate,omitempty"`
	Title         *string    `json:"title,omitempty"`
	Description   *string    `json:"description,omitempty"`
	UserID        uuid.UUID  `json:"userId"`
	GroupID       uuid.UUID  `json:"groupId"`
	IsGone        bool       `json:"isGone"`
	Image         *string    `json:"image,omitempty"`
	ImageBlurhash *string    `json:"imageBlurhash,omitempty"`
}

func (s *Pin) toDTO(ctx context.Context, p *db.Pin, withImage bool) *PinDTO {
	out := &PinDTO{
		ID: p.ID, Latitude: p.Latitude, Longitude: p.Longitude,
		CreationDate: p.CreationDate, UpdateDate: p.UpdateDate,
		Title: p.Title, Description: p.Description, UserID: p.CreatorID, GroupID: p.GroupID,
		IsGone: p.IsGone, ImageBlurhash: p.ImageBlurhash,
	}
	if withImage && s.obj != nil {
		if u, _ := s.obj.PresignedGet(ctx, PinKey(p.ID)); u != "" {
			out.Image = &u
		}
	}
	return out
}

// CreatePinInput mirrors PinRequestDto.
type CreatePinInput struct {
	Latitude       float64    `json:"latitude"`
	Longitude      float64    `json:"longitude"`
	CreationDate   time.Time  `json:"creationDate"`
	Title          *string    `json:"title,omitempty"`
	Description    *string    `json:"description,omitempty"`
	UserID         uuid.UUID  `json:"userId"`
	GroupID        uuid.UUID  `json:"groupId"`
	Image          []byte     `json:"image,omitempty"`
	CallerID       uuid.UUID  `json:"-"`
	IdempotencyKey *uuid.UUID `json:"-"`
}

type AddPinPhotoInput struct {
	Image          []byte
	IdempotencyKey uuid.UUID
	Latitude       float64
	Longitude      float64
	AccuracyMeters float64
	Caption        *string
}

type PinPhotoDTO struct {
	ID                  uuid.UUID  `json:"id"`
	PinID               uuid.UUID  `json:"pinId"`
	ContributorID       *uuid.UUID `json:"contributorId,omitempty"`
	ContributorUsername string     `json:"contributorUsername"`
	Image               *string    `json:"image"`
	ImageThumbnail      *string    `json:"imageThumbnail,omitempty"`
	ImageBlurhash       *string    `json:"imageBlurhash,omitempty"`
	Caption             *string    `json:"caption,omitempty"`
	ObservedAt          time.Time  `json:"observedAt"`
	IsOriginal          bool       `json:"isOriginal"`
}

func (s *Pin) Create(ctx context.Context, in CreatePinInput) (*PinDTO, error) {
	var requestHash []byte
	if in.IdempotencyKey != nil {
		if in.CallerID == uuid.Nil {
			return nil, apperrors.ErrBadRequest
		}
		imageHash := sha256.Sum256(in.Image)
		payload, err := json.Marshal(struct {
			Version      int
			Latitude     float64
			Longitude    float64
			CreationDate time.Time
			Title        *string
			Description  *string
			UserID       uuid.UUID
			GroupID      uuid.UUID
			ImageHash    [32]byte
		}{1, in.Latitude, in.Longitude, in.CreationDate.UTC(), in.Title,
			in.Description, in.UserID, in.GroupID, imageHash})
		if err != nil {
			return nil, err
		}
		hash := sha256.Sum256(payload)
		requestHash = hash[:]
	}
	var err error
	boundary, err := s.q.FindBoundaryForPoint(ctx, in.Latitude, in.Longitude)
	if err != nil {
		return nil, err
	}
	var compressed []byte
	var thumbnail []byte
	var imageBlurhash *string
	if len(in.Image) > 0 {
		compressed, err = image.CompressPinJPEG(in.Image)
		if err != nil {
			return nil, apperrors.ErrBadRequest
		}
		thumbnail, err = image.CompressPinThumbnailJPEG(compressed)
		if err != nil {
			return nil, apperrors.ErrBadRequest
		}
		hash, err := image.PinImageBlurhash(thumbnail)
		if err != nil {
			return nil, apperrors.ErrBadRequest
		}
		imageBlurhash = &hash
	}
	id := uuid.New()
	imageKey := PinKey(id)
	imageKeys := []string{imageKey, PinThumbnailKey(imageKey)}
	stagedImage := len(compressed) > 0 && s.obj != nil
	if stagedImage {
		if err := s.stageImageCleanups(ctx, imageKeys); err != nil {
			return nil, err
		}
	}
	var replayID *uuid.UUID
	err = s.q.InTx(ctx, func(q *db.Queries) error {
		var err error
		if in.IdempotencyKey != nil {
			originalID, originalHash, err := q.ClaimPinCreate(ctx, in.CallerID, *in.IdempotencyKey, requestHash)
			if err != nil {
				return err
			}
			if originalHash != nil {
				if !bytes.Equal(originalHash, requestHash) {
					return apperrors.ErrConflict
				}
				if originalID == nil {
					return apperrors.ErrUnavailable
				}
				replayID = originalID
				return nil
			}
		}
		exists, err := q.PinExistsForUserAt(ctx, in.UserID, in.Latitude, in.Longitude, in.CreationDate)
		if err != nil {
			return err
		}
		if exists {
			return apperrors.ErrConflict
		}
		id, err = q.CreatePin(ctx, db.Pin{
			ID:       id,
			Latitude: in.Latitude, Longitude: in.Longitude,
			CreationDate: &in.CreationDate, Title: in.Title, Description: in.Description,
			CreatorID: in.UserID, GroupID: in.GroupID, StateProvinceID: boundary,
			ImageBlurhash: imageBlurhash,
		})
		if err != nil {
			return err
		}
		if err := q.AddUserXp(ctx, in.UserID, CreatePinXP); err != nil {
			return err
		}
		if err := q.AwardGroupXP(ctx, in.GroupID, "pin:"+id.String(), CreateGroupPinXP); err != nil {
			return err
		}
		if len(compressed) > 0 {
			if s.obj != nil {
				for _, key := range imageKeys {
					locked, err := q.LockStagedObjectCleanup(ctx, key)
					if err != nil {
						return err
					}
					if !locked {
						return apperrors.ErrUnavailable
					}
				}
				if err := s.obj.Put(ctx, imageKey, compressed, "image/jpeg"); err != nil {
					return err
				}
				if err := s.obj.Put(ctx, PinThumbnailKey(imageKey), thumbnail, "image/jpeg"); err != nil {
					return err
				}
			}
			contributorUsername, err := q.GetUsernameByID(ctx, in.UserID)
			if err != nil {
				return err
			}
			contributorID := in.UserID
			if err := q.CreatePinPhoto(ctx, db.PinPhoto{
				ID: id, PinID: id, ContributorID: &contributorID,
				ContributorUsername: contributorUsername, ImageKey: imageKey,
				Caption: in.Description, ObservedAt: in.CreationDate,
				IsOriginal: true, ImageBlurhash: imageBlurhash,
			}); err != nil {
				return err
			}
			if stagedImage {
				for _, key := range imageKeys {
					if err := q.DeletePendingObjectCleanup(ctx, key); err != nil {
						return err
					}
				}
			}
		}
		if in.IdempotencyKey != nil {
			return q.FinishPinCreate(ctx, in.CallerID, *in.IdempotencyKey, id)
		}
		return nil
	})
	if err != nil {
		if stagedImage {
			if readyErr := s.releaseStagedObjectCleanups(ctx, imageKeys); readyErr != nil {
				return nil, errors.Join(err, readyErr)
			}
		}
		return nil, err
	}
	if replayID != nil {
		if stagedImage {
			if err := s.releaseStagedObjectCleanups(ctx, imageKeys); err != nil {
				return nil, err
			}
		}
		id = *replayID
	}
	p, err := s.q.GetPinByID(ctx, id)
	if err != nil {
		return nil, err
	}
	if p == nil {
		return nil, apperrors.ErrConflict
	}
	return s.toDTO(ctx, p, true), nil
}

func (s *Pin) Get(ctx context.Context, id uuid.UUID) (*PinDTO, error) {
	p, err := s.q.GetPinByID(ctx, id)
	if err != nil {
		return nil, err
	}
	if p == nil {
		return nil, apperrors.ErrNotFound
	}
	return s.toDTO(ctx, p, true), nil
}

func (s *Pin) SetGone(ctx context.Context, id, userID uuid.UUID, isGone bool) error {
	updated, err := s.q.SetPinGone(ctx, id, userID, isGone)
	if err != nil {
		return err
	}
	if !updated {
		return apperrors.ErrNotFound
	}
	return nil
}

func (s *Pin) Delete(ctx context.Context, id uuid.UUID) error {
	p, err := s.q.GetPinByID(ctx, id)
	if err != nil {
		return err
	}
	if p == nil {
		return apperrors.ErrNotFound
	}
	var photoKeys []string
	if err := s.q.InTx(ctx, func(q *db.Queries) error {
		locked, err := q.LockPinForDelete(ctx, id)
		if err != nil {
			return err
		}
		if !locked {
			return apperrors.ErrNotFound
		}
		photoKeys, err = q.ListPinPhotoKeys(ctx, id)
		if err != nil {
			return err
		}
		objectKeys := PinObjectKeysForCleanup(id, photoKeys)
		if err := q.EnqueueObjectCleanup(ctx, objectKeys); err != nil {
			return err
		}
		if err := q.LogDeletion(ctx, db.DeletedEntityPin, id); err != nil {
			return err
		}
		return q.HardDeletePin(ctx, id)
	}); err != nil {
		return err
	}
	tryObjectCleanup(ctx, s.q, s.obj)
	return nil
}

func (s *Pin) ImageURL(ctx context.Context, id uuid.UUID) (*string, error) {
	return s.imageURLForKey(ctx, PinKey(id))
}

// ThumbnailImageURL returns the cached small preview, creating it on first
// access for images stored before thumbnails were introduced.
func (s *Pin) ThumbnailImageURL(ctx context.Context, id uuid.UUID) (*string, error) {
	if s.obj == nil {
		return nil, nil
	}
	imageKey := PinKey(id)
	thumbnailKey := PinThumbnailKey(imageKey)
	thumbnail, available, _, err := s.ensurePinThumbnail(ctx, id, imageKey, false)
	if err != nil {
		return nil, err
	}
	if !available {
		return nil, nil
	}
	s.ensureImageBlurhash(ctx, id, thumbnail)
	return s.imageURLForKey(ctx, thumbnailKey)
}

// BackfillThumbnail creates a missing thumbnail for an existing pin image.
// It returns (created, available), skipping pins deleted during the backfill.
func (s *Pin) BackfillThumbnail(ctx context.Context, pinID uuid.UUID, imageKey string) (created, available bool, err error) {
	if s.obj == nil {
		return false, false, nil
	}
	thumbnail, available, created, err := s.ensurePinThumbnail(ctx, pinID, imageKey, true)
	if err != nil {
		return false, false, err
	}
	if available && imageKey == PinKey(pinID) {
		s.ensureImageBlurhash(ctx, pinID, thumbnail)
	}
	return created, available, nil
}

func (s *Pin) ensurePinThumbnail(ctx context.Context, pinID uuid.UUID, imageKey string, ignoreMissingPin bool) ([]byte, bool, bool, error) {
	thumbnailKey := PinThumbnailKey(imageKey)
	existingThumbnail, exists, err := s.obj.GetIfExists(ctx, thumbnailKey)
	if err != nil {
		return nil, false, false, err
	}
	if exists {
		return existingThumbnail, true, false, nil
	}
	if err := s.q.StageObjectCleanup(ctx, thumbnailKey); err != nil {
		return nil, false, false, err
	}
	var available bool
	var created bool
	var thumbnail []byte
	err = s.q.InTx(ctx, func(q *db.Queries) error {
		locked, err := q.LockPinForDelete(ctx, pinID)
		if err != nil {
			return err
		}
		if !locked {
			return apperrors.ErrNotFound
		}
		staged, err := q.LockStagedObjectCleanup(ctx, thumbnailKey)
		if err != nil {
			return err
		}
		if !staged {
			existing, exists, err := s.obj.GetIfExists(ctx, thumbnailKey)
			if err != nil {
				return err
			}
			if exists {
				available = true
				thumbnail = existing
				return nil
			}
			return apperrors.ErrUnavailable
		}
		existing, exists, err := s.obj.GetIfExists(ctx, thumbnailKey)
		if err != nil {
			return err
		}
		if exists {
			available = true
			thumbnail = existing
			return q.DeletePendingObjectCleanup(ctx, thumbnailKey)
		}
		original, exists, err := s.obj.GetIfExists(ctx, imageKey)
		if err != nil {
			return err
		}
		if !exists {
			return q.DeletePendingObjectCleanup(ctx, thumbnailKey)
		}
		thumbnail, err = image.CompressPinThumbnailJPEG(original)
		if err != nil {
			return err
		}
		if err := s.obj.Put(ctx, thumbnailKey, thumbnail, "image/jpeg"); err != nil {
			return err
		}
		available = true
		created = true
		return q.DeletePendingObjectCleanup(ctx, thumbnailKey)
	})
	if err != nil {
		if readyErr := s.releaseStagedObjectCleanup(ctx, thumbnailKey); readyErr != nil {
			return nil, false, false, errors.Join(err, readyErr)
		}
		if ignoreMissingPin && errors.Is(err, apperrors.ErrNotFound) {
			return nil, false, false, nil
		}
		return nil, false, false, err
	}
	return thumbnail, available, created, nil
}

// ensureImageBlurhash backfills placeholders for images created before the
// hash was stored on the pin. Failure is best-effort so thumbnail delivery
// remains available when an old object is unreadable or the metadata update
// cannot be saved.
func (s *Pin) ensureImageBlurhash(ctx context.Context, id uuid.UUID, thumbnail []byte) {
	if s.obj == nil {
		return
	}
	p, err := s.q.GetPinByID(ctx, id)
	if err != nil || p == nil || p.ImageBlurhash != nil {
		return
	}
	if len(thumbnail) == 0 {
		var exists bool
		thumbnail, exists, err = s.obj.GetIfExists(ctx, PinThumbnailKey(PinKey(id)))
		if err != nil || !exists {
			return
		}
	}
	hash, err := image.PinImageBlurhash(thumbnail)
	if err != nil {
		return
	}
	_, _ = s.q.SetPinImageBlurhash(ctx, id, hash)
}

func (s *Pin) LatestImageURL(ctx context.Context, id uuid.UUID) (*string, error) {
	imageURL, _, err := s.LatestImageAndBlurhash(ctx, id)
	return imageURL, err
}

// LatestImageAndBlurhash returns metadata for the same selected photo so
// callers never display a placeholder generated from a different image.
func (s *Pin) LatestImageAndBlurhash(ctx context.Context, id uuid.UUID) (*string, *string, error) {
	photos, err := s.q.ListPinPhotos(ctx, id)
	if err != nil {
		return nil, nil, err
	}
	if len(photos) == 0 {
		p, err := s.q.GetPinByID(ctx, id)
		if err != nil || p == nil {
			return nil, nil, err
		}
		imageURL, err := s.ImageURL(ctx, id)
		return imageURL, p.ImageBlurhash, err
	}
	latest := photos[len(photos)-1]
	imageURL, err := s.imageURLForKey(ctx, latest.ImageKey)
	if err != nil {
		return nil, nil, err
	}
	blurhash := latest.ImageBlurhash
	if blurhash == nil {
		blurhash = s.ensurePinPhotoImageBlurhash(ctx, latest)
	}
	return imageURL, blurhash, nil
}

func (s *Pin) ensurePinPhotoImageBlurhash(ctx context.Context, photo db.PinPhoto) *string {
	if s.obj == nil {
		return nil
	}
	for _, key := range []string{PinThumbnailKey(photo.ImageKey), photo.ImageKey} {
		content, exists, err := s.obj.GetIfExists(ctx, key)
		if err != nil || !exists {
			continue
		}
		hash, err := image.PinImageBlurhash(content)
		if err != nil {
			continue
		}
		_, _ = s.q.SetPinPhotoImageBlurhash(ctx, photo.ID, hash)
		return &hash
	}
	return nil
}

func (s *Pin) imageURLForKey(ctx context.Context, key string) (*string, error) {
	if s.obj == nil {
		return nil, nil
	}
	u, err := s.obj.PresignedGet(ctx, key)
	if err != nil || u == "" {
		return nil, err
	}
	return &u, nil
}

func (s *Pin) Photos(ctx context.Context, id uuid.UUID) ([]PinPhotoDTO, error) {
	p, err := s.q.GetPinByID(ctx, id)
	if err != nil {
		return nil, err
	}
	if p == nil {
		return nil, apperrors.ErrNotFound
	}
	photos, err := s.q.ListPinPhotos(ctx, id)
	if err != nil {
		return nil, err
	}
	result := make([]PinPhotoDTO, 0, len(photos))
	for _, photo := range photos {
		dto, err := s.photoDTO(ctx, photo)
		if err != nil {
			return nil, err
		}
		result = append(result, *dto)
	}
	return result, nil
}

func (s *Pin) AddPhoto(ctx context.Context, pinID, contributorID uuid.UUID, in AddPinPhotoInput) (*PinPhotoDTO, error) {
	caption, err := normalizePinPhotoCaption(in.Caption)
	if err != nil {
		return nil, err
	}
	if in.IdempotencyKey == uuid.Nil || !validPhotoLocation(in) || len(in.Image) == 0 || len(in.Image) > maxPinPhotoBytes {
		return nil, apperrors.ErrBadRequest
	}
	requestHash := pinPhotoRequestHash(in, caption)
	existing, err := s.q.GetPinPhotoByIdempotencyKey(ctx, contributorID, in.IdempotencyKey)
	if err != nil {
		return nil, err
	}
	if existing != nil {
		return s.resolveIdempotentPhoto(ctx, existing, pinID, requestHash)
	}
	p, err := s.q.GetPinByID(ctx, pinID)
	if err != nil {
		return nil, err
	}
	if p == nil {
		return nil, apperrors.ErrNotFound
	}
	if distanceMeters(in.Latitude, in.Longitude, p.Latitude, p.Longitude) > 50 {
		return nil, apperrors.ErrForbidden
	}
	if s.obj == nil {
		return nil, apperrors.ErrUnavailable
	}
	compressed, err := image.CompressPinJPEG(in.Image)
	if err != nil {
		return nil, apperrors.ErrBadRequest
	}
	thumbnail, err := image.CompressPinThumbnailJPEG(compressed)
	if err != nil {
		return nil, apperrors.ErrBadRequest
	}
	photoBlurhash, err := image.PinImageBlurhash(thumbnail)
	if err != nil {
		return nil, apperrors.ErrBadRequest
	}
	contributorUsername, err := s.q.GetUsernameByID(ctx, contributorID)
	if err != nil {
		return nil, err
	}
	photoID := uuid.New()
	imageKey := PinPhotoKey(pinID, photoID)
	observedAt := time.Now().UTC()
	photo := db.PinPhoto{
		ID: photoID, PinID: pinID, ContributorID: &contributorID,
		ContributorUsername: contributorUsername, ImageKey: imageKey,
		IdempotencyKey: &in.IdempotencyKey, RequestHash: requestHash,
		Caption: caption, ObservedAt: observedAt, ImageBlurhash: &photoBlurhash,
	}
	imageKeys := []string{imageKey, PinThumbnailKey(imageKey)}
	if err := s.stageImageCleanups(ctx, imageKeys); err != nil {
		return nil, err
	}
	var putErr error
	err = s.q.InTx(ctx, func(q *db.Queries) error {
		for _, key := range imageKeys {
			locked, err := q.LockStagedObjectCleanup(ctx, key)
			if err != nil {
				return err
			}
			if !locked {
				return apperrors.ErrUnavailable
			}
		}
		if err := s.obj.Put(ctx, imageKey, compressed, "image/jpeg"); err != nil {
			putErr = err
			return err
		}
		if err := s.obj.Put(ctx, PinThumbnailKey(imageKey), thumbnail, "image/jpeg"); err != nil {
			putErr = err
			return err
		}
		updated, err := q.TouchPinForPhoto(ctx, pinID)
		if err != nil {
			return err
		}
		if !updated {
			return apperrors.ErrNotFound
		}
		if err := q.CreatePinPhoto(ctx, photo); err != nil {
			return err
		}
		if err := q.AddUserXp(ctx, contributorID, CreatePinXP); err != nil {
			return err
		}
		for _, key := range imageKeys {
			if err := q.DeletePendingObjectCleanup(ctx, key); err != nil {
				return err
			}
		}
		return nil
	})
	if err != nil {
		if readyErr := s.releaseStagedObjectCleanups(ctx, imageKeys); readyErr != nil {
			return nil, errors.Join(err, readyErr)
		}
		existing, lookupErr := s.q.GetPinPhotoByIdempotencyKey(ctx, contributorID, in.IdempotencyKey)
		if lookupErr != nil {
			return nil, lookupErr
		}
		if existing != nil {
			return s.resolveIdempotentPhoto(ctx, existing, pinID, requestHash)
		}
		if putErr != nil {
			return nil, apperrors.ErrUnavailable
		}
		return nil, err
	}
	return s.photoDTO(ctx, photo)
}

func (s *Pin) releaseStagedObjectCleanup(ctx context.Context, objectKey string) error {
	return s.releaseStagedObjectCleanups(ctx, []string{objectKey})
}

func (s *Pin) releaseStagedObjectCleanups(ctx context.Context, objectKeys []string) error {
	cleanupCtx, cancel := context.WithTimeout(context.WithoutCancel(ctx), 5*time.Second)
	defer cancel()
	var cleanupErr error
	for _, key := range objectKeys {
		cleanupErr = errors.Join(cleanupErr, s.q.MarkObjectCleanupReady(cleanupCtx, key))
	}
	tryObjectCleanup(cleanupCtx, s.q, s.obj)
	return cleanupErr
}

func (s *Pin) stageImageCleanups(ctx context.Context, objectKeys []string) error {
	staged := make([]string, 0, len(objectKeys))
	for _, key := range objectKeys {
		if err := s.q.StageObjectCleanup(ctx, key); err != nil {
			return errors.Join(err, s.releaseStagedObjectCleanups(ctx, staged))
		}
		staged = append(staged, key)
	}
	return nil
}

func (s *Pin) resolveIdempotentPhoto(ctx context.Context, existing *db.PinPhoto, pinID uuid.UUID, requestHash []byte) (*PinPhotoDTO, error) {
	if existing.PinID != pinID || !bytes.Equal(existing.RequestHash, requestHash) {
		return nil, apperrors.ErrConflict
	}
	return s.photoDTO(ctx, *existing)
}

func (s *Pin) photoDTO(ctx context.Context, photo db.PinPhoto) (*PinPhotoDTO, error) {
	var imageURL, thumbnailURL *string
	if s.obj != nil {
		url, err := s.obj.PresignedGet(ctx, photo.ImageKey)
		if err != nil {
			return nil, err
		}
		if url != "" {
			imageURL = &url
		}
		url, err = s.obj.PresignedGet(ctx, PinThumbnailKey(photo.ImageKey))
		if err != nil {
			return nil, err
		}
		if url != "" {
			thumbnailURL = &url
		}
	}
	blurhash := photo.ImageBlurhash
	if blurhash == nil {
		blurhash = s.ensurePinPhotoImageBlurhash(ctx, photo)
	}
	return &PinPhotoDTO{
		ID: photo.ID, PinID: photo.PinID, ContributorID: photo.ContributorID,
		ContributorUsername: photo.ContributorUsername, Image: imageURL,
		ImageThumbnail: thumbnailURL, ImageBlurhash: blurhash,
		Caption: photo.Caption, ObservedAt: photo.ObservedAt,
		IsOriginal: photo.IsOriginal,
	}, nil
}

func normalizePinPhotoCaption(caption *string) (*string, error) {
	if caption == nil {
		return nil, nil
	}
	value := strings.TrimSpace(*caption)
	if utf8.RuneCountInString(value) > 280 {
		return nil, apperrors.ErrBadRequest
	}
	if value == "" {
		return nil, nil
	}
	return &value, nil
}

func validPhotoLocation(in AddPinPhotoInput) bool {
	return !math.IsNaN(in.Latitude) && !math.IsInf(in.Latitude, 0) &&
		!math.IsNaN(in.Longitude) && !math.IsInf(in.Longitude, 0) &&
		!math.IsNaN(in.AccuracyMeters) && !math.IsInf(in.AccuracyMeters, 0) &&
		in.Latitude >= -90 && in.Latitude <= 90 &&
		in.Longitude >= -180 && in.Longitude <= 180 &&
		in.AccuracyMeters >= 0 && in.AccuracyMeters <= 50
}

func pinPhotoRequestHash(in AddPinPhotoInput, caption *string) []byte {
	imageHash := sha256.Sum256(in.Image)
	payload, _ := json.Marshal(struct {
		ImageHash      [32]byte `json:"imageHash"`
		Latitude       float64  `json:"latitude"`
		Longitude      float64  `json:"longitude"`
		AccuracyMeters float64  `json:"accuracyMeters"`
		Caption        *string  `json:"caption,omitempty"`
	}{imageHash, in.Latitude, in.Longitude, in.AccuracyMeters, caption})
	hash := sha256.Sum256(payload)
	return hash[:]
}

func distanceMeters(lat1, lon1, lat2, lon2 float64) float64 {
	const earthRadiusMeters = 6371000
	toRadians := func(degrees float64) float64 { return degrees * math.Pi / 180 }
	deltaLat := toRadians(lat2 - lat1)
	deltaLon := toRadians(lon2 - lon1)
	a := math.Sin(deltaLat/2)*math.Sin(deltaLat/2) +
		math.Cos(toRadians(lat1))*math.Cos(toRadians(lat2))*
			math.Sin(deltaLon/2)*math.Sin(deltaLon/2)
	return 2 * earthRadiusMeters * math.Asin(math.Min(1, math.Sqrt(a)))
}
