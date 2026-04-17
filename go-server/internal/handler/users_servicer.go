package handler

import (
	"context"
	"encoding/base64"
	"net/http"

	"github.com/google/uuid"

	"github.com/lrprojects/monaserver/internal/apperrors"
	genserver "github.com/lrprojects/monaserver/internal/gen/server"
	"github.com/lrprojects/monaserver/internal/service"
)

// UsersServicer implements genserver.UsersAPIServicer.
type UsersServicer struct {
	user  *service.User
	guard *service.Guard
}

func NewUsersServicer(user *service.User, guard *service.Guard) *UsersServicer {
	return &UsersServicer{user: user, guard: guard}
}

func (s *UsersServicer) GetUser(ctx context.Context, userID string) (genserver.ImplResponse, error) {
	id, err := uuid.Parse(userID)
	if err != nil {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	u, err := s.user.Get(ctx, id)
	if err != nil {
		return genserver.Response(apperrors.HTTPStatus(err), nil), nil
	}
	if u == nil {
		return genserver.Response(http.StatusNotFound, nil), nil
	}
	return genserver.Response(http.StatusOK, toUserInfoDto(service.ToPublicUserInfo(u))), nil
}

func (s *UsersServicer) UpdateUser(ctx context.Context, userID string, dto genserver.UserUpdateDto) (genserver.ImplResponse, error) {
	id, err := uuid.Parse(userID)
	if err != nil {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	caller, ok := ctxUserID(ctx)
	if !ok {
		return genserver.Response(http.StatusUnauthorized, nil), nil
	}
	if caller != id {
		return genserver.Response(http.StatusForbidden, nil), nil
	}
	var imgBytes []byte
	if dto.Image != "" {
		b, err2 := base64.StdEncoding.DecodeString(dto.Image)
		if err2 == nil {
			imgBytes = b
		}
	}
	in := service.UserUpdateInput{
		Description:    strNilable(dto.Description),
		Email:          strNilable(dto.Email),
		Image:          imgBytes,
		MessagingToken: strNilable(dto.MessagingToken),
		Password:       strNilable(dto.Password),
		Username:       strNilable(dto.Username),
		SelectedBatch:  dto.SelectedBatch,
	}
	result, err := s.user.Update(ctx, id, in)
	if err != nil {
		return genserver.Response(apperrors.HTTPStatus(err), nil), nil
	}
	resp := genserver.UserUpdateResponseDto{
		UserInfoDto: toUserInfoDto(result.UserInfoDto),
	}
	if result.ProfileImage != nil {
		resp.ProfileImage = *result.ProfileImage
	}
	if result.ProfileImageSmall != nil {
		resp.ProfileImageSmall = *result.ProfileImageSmall
	}
	if result.UserTokenDto != nil {
		resp.UserTokenDto = toTokenResponseDto(result.UserTokenDto)
	}
	return genserver.Response(http.StatusOK, resp), nil
}

func (s *UsersServicer) DeleteUser(ctx context.Context, userID string, code int32) (genserver.ImplResponse, error) {
	id, err := uuid.Parse(userID)
	if err != nil {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	caller, ok := ctxUserID(ctx)
	if !ok {
		return genserver.Response(http.StatusUnauthorized, nil), nil
	}
	if caller != id {
		return genserver.Response(http.StatusForbidden, nil), nil
	}
	if err := s.user.Delete(ctx, id, int(code)); err != nil {
		return genserver.Response(apperrors.HTTPStatus(err), nil), nil
	}
	return genserver.Response(http.StatusOK, nil), nil
}

func (s *UsersServicer) GetUserProfileImageSmall(ctx context.Context, userID string, redirect bool) (genserver.ImplResponse, error) {
	id, err := uuid.Parse(userID)
	if err != nil {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	u, err := s.user.ProfileImageURL(ctx, id, true)
	if err != nil {
		return genserver.Response(apperrors.HTTPStatus(err), nil), nil
	}
	if u == nil {
		return genserver.Response(http.StatusOK, nil), nil
	}
	if redirect {
		return genserver.Response(http.StatusOK, *u), nil
	}
	return genserver.Response(http.StatusOK, *u), nil
}

func (s *UsersServicer) GetUserProfileImage(ctx context.Context, userID string, redirect bool) (genserver.ImplResponse, error) {
	id, err := uuid.Parse(userID)
	if err != nil {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	u, err := s.user.ProfileImageURL(ctx, id, false)
	if err != nil {
		return genserver.Response(apperrors.HTTPStatus(err), nil), nil
	}
	if u == nil {
		return genserver.Response(http.StatusOK, nil), nil
	}
	if redirect {
		return genserver.Response(http.StatusOK, *u), nil
	}
	return genserver.Response(http.StatusOK, *u), nil
}

func (s *UsersServicer) GetUserXp(ctx context.Context, userID string) (genserver.ImplResponse, error) {
	id, err := uuid.Parse(userID)
	if err != nil {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	caller, ok := ctxUserID(ctx)
	if !ok {
		return genserver.Response(http.StatusUnauthorized, nil), nil
	}
	if caller != id {
		return genserver.Response(http.StatusForbidden, nil), nil
	}
	u, err := s.user.Get(ctx, id)
	if err != nil {
		return genserver.Response(apperrors.HTTPStatus(err), nil), nil
	}
	if u == nil {
		return genserver.Response(http.StatusNotFound, nil), nil
	}
	return genserver.Response(http.StatusOK, genserver.UserXpDto{TotalXp: int32(u.XP)}), nil
}

func (s *UsersServicer) GetUserAchievements(ctx context.Context, userID string) (genserver.ImplResponse, error) {
	id, err := uuid.Parse(userID)
	if err != nil {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	caller, ok := ctxUserID(ctx)
	if !ok {
		return genserver.Response(http.StatusUnauthorized, nil), nil
	}
	if caller != id {
		return genserver.Response(http.StatusForbidden, nil), nil
	}
	items, err := s.user.Achievements(ctx, id)
	if err != nil {
		return genserver.Response(apperrors.HTTPStatus(err), nil), nil
	}
	dtos := make([]genserver.UserAchievementsDtoInner, 0, len(items))
	for _, a := range items {
		dtos = append(dtos, genserver.UserAchievementsDtoInner{
			AchievementId: a.AchievementID,
			Claimed:       a.Claimed,
		})
	}
	return genserver.Response(http.StatusOK, dtos), nil
}

func (s *UsersServicer) ClaimUserAchievement(ctx context.Context, userID string, achievementID int32) (genserver.ImplResponse, error) {
	id, err := uuid.Parse(userID)
	if err != nil {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	caller, ok := ctxUserID(ctx)
	if !ok {
		return genserver.Response(http.StatusUnauthorized, nil), nil
	}
	if caller != id {
		return genserver.Response(http.StatusForbidden, nil), nil
	}
	if err := s.user.ClaimAchievement(ctx, id, achievementID); err != nil {
		return genserver.Response(apperrors.HTTPStatus(err), nil), nil
	}
	return genserver.Response(http.StatusOK, nil), nil
}
