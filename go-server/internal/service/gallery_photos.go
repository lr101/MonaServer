package service

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"github.com/google/uuid"
	"github.com/lrprojects/monaserver/internal/apperrors"
	"github.com/lrprojects/monaserver/internal/db"
	"time"
)

type GalleryPhoto struct {
	Pin   db.Pin
	Photo PinPhotoDTO
}
type GalleryCursor struct {
	Date  time.Time `json:"date"`
	ID    uuid.UUID `json:"id"`
	Scope string    `json:"scope"`
}

func (s *Pin) Gallery(ctx context.Context, in db.GalleryPhotoSearch, cursor, scope string) ([]GalleryPhoto, string, error) {
	if in.Limit < 1 || in.Limit > 100 {
		return nil, "", apperrors.ErrBadRequest
	}
	if cursor != "" {
		var c GalleryCursor
		raw, err := base64.RawURLEncoding.DecodeString(cursor)
		if err != nil || json.Unmarshal(raw, &c) != nil || c.Date.IsZero() || c.ID == uuid.Nil || c.Scope != scope {
			return nil, "", apperrors.ErrBadRequest
		}
		in.BeforeDate = &c.Date
		in.BeforeID = &c.ID
	}
	limit := in.Limit
	in.Limit++
	rows, err := s.q.GalleryPhotos(ctx, in)
	if err != nil {
		return nil, "", err
	}
	next := ""
	if len(rows) > int(limit) {
		rows = rows[:limit]
		last := rows[len(rows)-1].Photo
		b, _ := json.Marshal(GalleryCursor{Date: last.ObservedAt, ID: last.ID, Scope: scope})
		next = base64.RawURLEncoding.EncodeToString(b)
	}
	out := make([]GalleryPhoto, 0, len(rows))
	for _, row := range rows {
		photo, err := s.photoDTO(ctx, row.Photo)
		if err != nil {
			return nil, "", err
		}
		out = append(out, GalleryPhoto{Pin: row.Pin, Photo: *photo})
	}
	return out, next, nil
}

// ResolvePhotoURLs uses a single authorized database query. A hidden resource
// has exactly the same externally observable result as an unknown photo.
func (s *Pin) ResolvePhotoURLs(ctx context.Context, caller uuid.UUID, ids []uuid.UUID) (map[uuid.UUID]*PinPhotoDTO, error) {
	rows, err := s.q.GalleryPhotos(ctx, db.GalleryPhotoSearch{CallerID: caller, PhotoIDs: ids, Limit: 100})
	if err != nil {
		return nil, err
	}
	out := make(map[uuid.UUID]*PinPhotoDTO, len(rows))
	for _, row := range rows {
		photo, err := s.photoDTO(ctx, row.Photo)
		if err != nil {
			out[row.Photo.ID] = nil
			continue
		}
		out[photo.ID] = photo
	}
	return out, nil
}
