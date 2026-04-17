package handler

import (
	"context"
	"net/http"

	"github.com/google/uuid"

	"github.com/lrprojects/monaserver/internal/apperrors"
	genserver "github.com/lrprojects/monaserver/internal/gen/server"
	"github.com/lrprojects/monaserver/internal/service"
)

// LikesServicer implements genserver.LikesAPIServicer.
type LikesServicer struct {
	like  *service.Like
	guard *service.Guard
}

func NewLikesServicer(like *service.Like, guard *service.Guard) *LikesServicer {
	return &LikesServicer{like: like, guard: guard}
}

func (s *LikesServicer) GetPinLikes(ctx context.Context, pinID string) (genserver.ImplResponse, error) {
	pid, err := uuid.Parse(pinID)
	if err != nil {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	uid, ok := ctxUserID(ctx)
	if !ok {
		return genserver.Response(http.StatusUnauthorized, nil), nil
	}
	if ok2, _ := s.guard.IsPinPublicOrMember(ctx, pid, uid); !ok2 {
		return genserver.Response(http.StatusForbidden, nil), nil
	}
	dto, err := s.like.CountByPin(ctx, pid, uid)
	if err != nil {
		return genserver.Response(apperrors.HTTPStatus(err), nil), nil
	}
	return genserver.Response(http.StatusOK, toLikesDto(dto)), nil
}

func (s *LikesServicer) CreateOrUpdateLike(ctx context.Context, pinID string, dto genserver.CreateLikeDto) (genserver.ImplResponse, error) {
	pid, err := uuid.Parse(pinID)
	if err != nil {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	uid, ok := ctxUserID(ctx)
	if !ok {
		return genserver.Response(http.StatusUnauthorized, nil), nil
	}
	if ok2, _ := s.guard.IsPinPublicOrMember(ctx, pid, uid); !ok2 {
		return genserver.Response(http.StatusForbidden, nil), nil
	}
	likeAll := dto.Like
	likeLoc := dto.LikeLocation
	likePhoto := dto.LikePhotography
	likeArt := dto.LikeArt
	result, err := s.like.CreateOrUpdate(ctx, pid, service.CreateLikeInput{
		UserID:          uid,
		Like:            &likeAll,
		LikeLocation:    &likeLoc,
		LikePhotography: &likePhoto,
		LikeArt:         &likeArt,
	})
	if err != nil {
		return genserver.Response(apperrors.HTTPStatus(err), nil), nil
	}
	return genserver.Response(http.StatusOK, toLikesDto(result)), nil
}

func (s *LikesServicer) GetUserLikes(ctx context.Context, userID string) (genserver.ImplResponse, error) {
	uid, err := uuid.Parse(userID)
	if err != nil {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	dto, err := s.like.UserLikes(ctx, uid)
	if err != nil {
		return genserver.Response(apperrors.HTTPStatus(err), nil), nil
	}
	return genserver.Response(http.StatusOK, genserver.UserLikesDto{
		LikeCount:            int32(dto.LikeCount),
		LikeArtCount:         int32(dto.LikeArtCount),
		LikeLocationCount:    int32(dto.LikeLocationCount),
		LikePhotographyCount: int32(dto.LikePhotographyCount),
	}), nil
}

func toLikesDto(d *service.PinLikeDTO) genserver.PinLikeDto {
	return genserver.PinLikeDto{
		LikeCount:              int32(d.LikeCount),
		LikeArtCount:           int32(d.LikeArtCount),
		LikeLocationCount:      int32(d.LikeLocationCount),
		LikePhotographyCount:   int32(d.LikePhotographyCount),
		LikedByUser:            d.LikedByUser,
		LikedArtByUser:         d.LikedArtByUser,
		LikedLocationByUser:    d.LikedLocationByUser,
		LikedPhotographyByUser: d.LikedPhotographyByUser,
	}
}
