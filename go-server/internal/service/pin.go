package service

import (
	"context"
	"time"

	"github.com/google/uuid"

	"github.com/lrprojects/monaserver/internal/apperrors"
	"github.com/lrprojects/monaserver/internal/db"
	"github.com/lrprojects/monaserver/internal/image"
)

const CreatePinXP = 5

// Pin service — mirrors PinServiceImpl.
type Pin struct {
	q   *db.Queries
	obj *Object
}

func NewPin(q *db.Queries, obj *Object) *Pin { return &Pin{q: q, obj: obj} }

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
	Image        *string    `json:"image,omitempty"`
}

func (s *Pin) toDTO(ctx context.Context, p *db.Pin, withImage bool) *PinDTO {
	out := &PinDTO{
		ID: p.ID, Latitude: p.Latitude, Longitude: p.Longitude,
		CreationDate: p.CreationDate, UpdateDate: p.UpdateDate,
		Description: p.Description, UserID: p.CreatorID, GroupID: p.GroupID,
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
		if len(compressed) > 0 && s.obj != nil {
			return s.obj.Put(ctx, PinKey(id), compressed, "image/jpeg")
		}
		return nil
	}); err != nil {
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

func (s *Pin) Delete(ctx context.Context, id uuid.UUID) error {
	p, err := s.q.GetPinByID(ctx, id)
	if err != nil {
		return err
	}
	if p == nil {
		return apperrors.ErrNotFound
	}
	if err := s.q.InTx(ctx, func(q *db.Queries) error {
		if err := q.LogDeletion(ctx, db.DeletedEntityPin, id); err != nil {
			return err
		}
		return q.HardDeletePin(ctx, id)
	}); err != nil {
		return err
	}
	if s.obj != nil {
		_ = s.obj.Remove(ctx, PinKey(id))
	}
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
