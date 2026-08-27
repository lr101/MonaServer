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
	UserID          uuid.UUID `json:"userId"`
	Like            *bool     `json:"like,omitempty"`
	LikeLocation    *bool     `json:"likeLocation,omitempty"`
	LikePhotography *bool     `json:"likePhotography,omitempty"`
	LikeArt         *bool     `json:"likeArt,omitempty"`
}

// PinLikeDTO mirrors PinLikeDto.
type PinLikeDTO struct {
	LikeCount              int64 `json:"likeCount"`
	LikeLocationCount      int64 `json:"likeLocationCount"`
	LikePhotographyCount   int64 `json:"likePhotographyCount"`
	LikeArtCount           int64 `json:"likeArtCount"`
	LikedByUser            bool  `json:"likedByUser"`
	LikedLocationByUser    bool  `json:"likedLocationByUser"`
	LikedPhotographyByUser bool  `json:"likedPhotographyByUser"`
	LikedArtByUser         bool  `json:"likedArtByUser"`
}

// UserLikesDTO mirrors UserLikesDto — aggregates likes received on user's pins.
type UserLikesDTO struct {
	LikeCount            int64 `json:"likeCount"`
	LikeLocationCount    int64 `json:"likeLocationCount"`
	LikePhotographyCount int64 `json:"likePhotographyCount"`
	LikeArtCount         int64 `json:"likeArtCount"`
}

func (s *Like) CreateOrUpdate(ctx context.Context, pinID uuid.UUID, in CreateLikeInput) (*PinLikeDTO, error) {
	existing, err := s.q.GetLikeByUserAndPin(ctx, in.UserID, pinID)
	if err != nil {
		return nil, err
	}
	flags := db.LikeFlags{}
	if existing != nil {
		flags = *existing
	}
	if in.Like != nil {
		flags.LikeAll = *in.Like
	}
	if in.LikeLocation != nil {
		flags.LikeLocation = *in.LikeLocation
	}
	if in.LikePhotography != nil {
		flags.LikePhotography = *in.LikePhotography
	}
	if in.LikeArt != nil {
		flags.LikeArt = *in.LikeArt
	}
	if err := s.q.UpsertLike(ctx, in.UserID, pinID, flags); err != nil {
		return nil, err
	}
	return s.CountByPin(ctx, pinID, in.UserID)
}

func (s *Like) CountByPin(ctx context.Context, pinID, userID uuid.UUID) (*PinLikeDTO, error) {
	counts, err := s.q.CountPinLikesByType(ctx, pinID)
	if err != nil {
		return nil, err
	}
	out := &PinLikeDTO{
		LikeCount: counts.LikeAll, LikeLocationCount: counts.LikeLocation,
		LikePhotographyCount: counts.LikePhotography, LikeArtCount: counts.LikeArt,
	}
	mine, err := s.q.GetLikeByUserAndPin(ctx, userID, pinID)
	if err != nil {
		return nil, err
	}
	if mine != nil {
		out.LikedByUser = mine.LikeAll
		out.LikedLocationByUser = mine.LikeLocation
		out.LikedPhotographyByUser = mine.LikePhotography
		out.LikedArtByUser = mine.LikeArt
	}
	return out, nil
}

func (s *Like) UserLikes(ctx context.Context, userID uuid.UUID) (*UserLikesDTO, error) {
	c, err := s.q.CountLikesForCreator(ctx, userID)
	if err != nil {
		return nil, err
	}
	return &UserLikesDTO{
		LikeCount: c.LikeAll, LikeLocationCount: c.LikeLocation,
		LikePhotographyCount: c.LikePhotography, LikeArtCount: c.LikeArt,
	}, nil
}

var _ = apperrors.ErrNotFound
