package service

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/json"
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
const maxPinPhotoBytes = 8 << 20

// PinObjectStore is the subset of the object service used by pin photos.
type PinObjectStore interface {
	Put(context.Context, string, []byte, string) error
	Remove(context.Context, string) error
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
	ID           uuid.UUID  `json:"id"`
	Latitude     float64    `json:"latitude"`
	Longitude    float64    `json:"longitude"`
	CreationDate *time.Time `json:"creationDate,omitempty"`
	UpdateDate   *time.Time `json:"updateDate,omitempty"`
	Description  *string    `json:"description,omitempty"`
	UserID       uuid.UUID  `json:"userId"`
	GroupID      uuid.UUID  `json:"groupId"`
	IsGone       bool       `json:"isGone"`
	Image        *string    `json:"image,omitempty"`
}

func (s *Pin) toDTO(ctx context.Context, p *db.Pin, withImage bool) *PinDTO {
	out := &PinDTO{
		ID: p.ID, Latitude: p.Latitude, Longitude: p.Longitude,
		CreationDate: p.CreationDate, UpdateDate: p.UpdateDate,
		Description: p.Description, UserID: p.CreatorID, GroupID: p.GroupID,
		IsGone: p.IsGone,
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
	Latitude     float64   `json:"latitude"`
	Longitude    float64   `json:"longitude"`
	CreationDate time.Time `json:"creationDate"`
	Description  *string   `json:"description,omitempty"`
	UserID       uuid.UUID `json:"userId"`
	GroupID      uuid.UUID `json:"groupId"`
	Image        []byte    `json:"image,omitempty"`
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
	Caption             *string    `json:"caption,omitempty"`
	ObservedAt          time.Time  `json:"observedAt"`
	IsOriginal          bool       `json:"isOriginal"`
}

func (s *Pin) Create(ctx context.Context, in CreatePinInput) (*PinDTO, error) {
	exists, err := s.q.PinExistsForUserAt(ctx, in.UserID, in.Latitude, in.Longitude, in.CreationDate)
	if err != nil {
		return nil, err
	}
	if exists {
		return nil, apperrors.ErrConflict
	}
	boundary, err := s.q.FindBoundaryForPoint(ctx, in.Latitude, in.Longitude)
	if err != nil {
		return nil, err
	}
	var compressed []byte
	if len(in.Image) > 0 {
		compressed, err = image.CompressPinJPEG(in.Image)
		if err != nil {
			return nil, apperrors.ErrBadRequest
		}
	}
	var id uuid.UUID
	if err := s.q.InTx(ctx, func(q *db.Queries) error {
		var err error
		id, err = q.CreatePin(ctx, db.Pin{
			Latitude: in.Latitude, Longitude: in.Longitude,
			CreationDate: &in.CreationDate, Description: in.Description,
			CreatorID: in.UserID, GroupID: in.GroupID, StateProvinceID: boundary,
		})
		if err != nil {
			return err
		}
		if err := q.AddUserXp(ctx, in.UserID, CreatePinXP); err != nil {
			return err
		}
		if len(compressed) > 0 {
			if s.obj != nil {
				if err := s.obj.Put(ctx, PinKey(id), compressed, "image/jpeg"); err != nil {
					return err
				}
			}
			contributorUsername, err := q.GetUsernameByID(ctx, in.UserID)
			if err != nil {
				return err
			}
			contributorID := in.UserID
			return q.CreatePinPhoto(ctx, db.PinPhoto{
				ID: id, PinID: id, ContributorID: &contributorID,
				ContributorUsername: contributorUsername, ImageKey: PinKey(id),
				Caption: in.Description, ObservedAt: in.CreationDate,
				IsOriginal: true,
			})
		}
		return nil
	}); err != nil {
		if id != uuid.Nil && len(compressed) > 0 && s.obj != nil {
			_ = s.obj.Remove(ctx, PinKey(id))
		}
		return nil, err
	}
	p, err := s.q.GetPinByID(ctx, id)
	if err != nil {
		return nil, err
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

func (s *Pin) SetGone(ctx context.Context, id uuid.UUID, isGone bool) error {
	p, err := s.q.GetPinByID(ctx, id)
	if err != nil {
		return err
	}
	if p == nil {
		return apperrors.ErrNotFound
	}
	updated, err := s.q.SetPinGone(ctx, id, isGone)
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
		var err error
		photoKeys, err = q.ListPinPhotoKeys(ctx, id)
		if err != nil {
			return err
		}
		objectKeys := append([]string{PinKey(id)}, photoKeys...)
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
	if s.obj == nil {
		return nil, nil
	}
	u, err := s.obj.PresignedGet(ctx, PinKey(id))
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
	contributorUsername, err := s.q.GetUsernameByID(ctx, contributorID)
	if err != nil {
		return nil, err
	}
	photoID := uuid.New()
	imageKey := PinPhotoKey(pinID, photoID)
	if err := s.obj.Put(ctx, imageKey, compressed, "image/jpeg"); err != nil {
		return nil, apperrors.ErrUnavailable
	}
	observedAt := time.Now().UTC()
	photo := db.PinPhoto{
		ID: photoID, PinID: pinID, ContributorID: &contributorID,
		ContributorUsername: contributorUsername, ImageKey: imageKey,
		IdempotencyKey: &in.IdempotencyKey, RequestHash: requestHash,
		Caption: caption, ObservedAt: observedAt,
	}
	err = s.q.InTx(ctx, func(q *db.Queries) error {
		updated, err := q.TouchPinForPhoto(ctx, pinID)
		if err != nil {
			return err
		}
		if !updated {
			return apperrors.ErrNotFound
		}
		return q.CreatePinPhoto(ctx, photo)
	})
	if err != nil {
		_ = s.obj.Remove(ctx, imageKey)
		existing, lookupErr := s.q.GetPinPhotoByIdempotencyKey(ctx, contributorID, in.IdempotencyKey)
		if lookupErr != nil {
			return nil, lookupErr
		}
		if existing != nil {
			return s.resolveIdempotentPhoto(ctx, existing, pinID, requestHash)
		}
		return nil, err
	}
	return s.photoDTO(ctx, photo)
}

func (s *Pin) resolveIdempotentPhoto(ctx context.Context, existing *db.PinPhoto, pinID uuid.UUID, requestHash []byte) (*PinPhotoDTO, error) {
	if existing.PinID != pinID || !bytes.Equal(existing.RequestHash, requestHash) {
		return nil, apperrors.ErrConflict
	}
	return s.photoDTO(ctx, *existing)
}

func (s *Pin) photoDTO(ctx context.Context, photo db.PinPhoto) (*PinPhotoDTO, error) {
	var imageURL *string
	if s.obj != nil {
		url, err := s.obj.PresignedGet(ctx, photo.ImageKey)
		if err != nil {
			return nil, err
		}
		if url != "" {
			imageURL = &url
		}
	}
	return &PinPhotoDTO{
		ID: photo.ID, PinID: photo.PinID, ContributorID: photo.ContributorID,
		ContributorUsername: photo.ContributorUsername, Image: imageURL,
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
