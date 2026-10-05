package service

import (
	"context"

	"github.com/google/uuid"

	"github.com/lrprojects/monaserver/internal/apperrors"
	"github.com/lrprojects/monaserver/internal/db"
)

// Like service — mirrors LikeServiceImpl.
type Like struct{ q *db.Queries }

func NewLike(q *db.Queries) *Like { return &Like{q: q} }

// CreateLikeInput mirrors CreateLikeDto.
type CreateLikeInput struct {
	UserID uuid.UUID `json:"userId"`
	Like   *bool     `json:"like,omitempty"`
}

// PinLikeDTO mirrors PinLikeDto.
type PinLikeDTO struct {
	LikeCount   int64 `json:"likeCount"`
	LikedByUser bool  `json:"likedByUser"`
}

// UserLikesDTO mirrors UserLikesDto — aggregates likes received on user's pins.
type UserLikesDTO struct {
	LikeCount int64 `json:"likeCount"`
}

func (s *Like) CreateOrUpdate(ctx context.Context, pinID uuid.UUID, in CreateLikeInput) (*PinLikeDTO, error) {
	if in.Like != nil {
		if *in.Like {
			if err := s.q.UpsertLike(ctx, in.UserID, pinID, db.LikeFlags{LikeAll: true}); err != nil {
				return nil, err
			}
		} else if err := s.q.DeleteLike(ctx, in.UserID, pinID); err != nil {
			return nil, err
		}
	}
	return s.CountByPin(ctx, pinID, in.UserID)
}

func (s *Like) CountByPin(ctx context.Context, pinID, userID uuid.UUID) (*PinLikeDTO, error) {
	count, err := s.q.CountPinLikes(ctx, pinID)
	if err != nil {
		return nil, err
	}
	out := &PinLikeDTO{LikeCount: count}
	mine, err := s.q.GetLikeByUserAndPin(ctx, userID, pinID)
	if err != nil {
		return nil, err
	}
	if mine != nil {
		out.LikedByUser = mine.LikeAll
	}
	return out, nil
}

func (s *Like) UserLikes(ctx context.Context, userID uuid.UUID) (*UserLikesDTO, error) {
	c, err := s.q.CountLikesForCreator(ctx, userID)
	if err != nil {
		return nil, err
	}
	return &UserLikesDTO{LikeCount: c}, nil
}

var _ = apperrors.ErrNotFound
