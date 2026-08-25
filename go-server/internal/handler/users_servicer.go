package handler

import (
	"context"
	"encoding/base64"
	"net/http"

	"github.com/google/uuid"

	"github.com/lrprojects/monaserver/internal/db"
	genserver "github.com/lrprojects/monaserver/internal/gen/server"
	"github.com/lrprojects/monaserver/internal/service"
)

// UsersServicer implements genserver.UsersAPIServicer.
type UsersServicer struct {
	user   *service.User
	guard  *service.Guard
	q      *db.Queries
	achCfg db.AchievementConfig
}

func NewUsersServicer(user *service.User, guard *service.Guard, q *db.Queries, achCfg db.AchievementConfig) *UsersServicer {
	return &UsersServicer{user: user, guard: guard, q: q, achCfg: achCfg}
}

func (s *UsersServicer) GetUser(ctx context.Context, userID string) (genserver.ImplResponse, error) {
	id, err := uuid.Parse(userID)
	if err != nil {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	u, err := s.user.Get(ctx, id)
	if err != nil {
		return serviceErrResp(err), nil
	}
	if u == nil {
		return genserver.Response(http.StatusNotFound, nil), nil
	}
	info := service.ToPublicUserInfo(u)
	info.SelectedBatch, err = s.q.GetSelectedUserAchievementID(ctx, id)
	if err != nil {
		return serviceErrResp(err), nil
	}
	info.BestSeason, err = s.q.GetBestUserSeason(ctx, id)
	if err != nil {
		return serviceErrResp(err), nil
	}
	registered := false
	if caller, ok := ctxUserID(ctx); ok && caller == id {
		registered = u.FirebaseToken != nil
	}
	info.IsMessagingRegistered = &registered
	return genserver.Response(http.StatusOK, toUserInfoDto(info)), nil
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
		b, err := base64.StdEncoding.DecodeString(dto.Image)
		if err != nil {
			return genserver.Response(http.StatusBadRequest, nil), nil
		}
		imgBytes = b
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
		return serviceErrResp(err), nil
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
		return serviceErrResp(err), nil
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
		return serviceErrResp(err), nil
	}
	if u == nil {
		return genserver.Response(http.StatusOK, nil), nil
	}
	if redirect {
		return genserver.Response(http.StatusOK, *u), nil
	}
	return genserver.Response(http.StatusOK, []byte(*u)), nil
}

func (s *UsersServicer) GetUserProfileImage(ctx context.Context, userID string, redirect bool) (genserver.ImplResponse, error) {
	id, err := uuid.Parse(userID)
	if err != nil {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	u, err := s.user.ProfileImageURL(ctx, id, false)
	if err != nil {
		return serviceErrResp(err), nil
	}
	if u == nil {
		return genserver.Response(http.StatusOK, nil), nil
	}
	if redirect {
		return genserver.Response(http.StatusOK, *u), nil
	}
	return genserver.Response(http.StatusOK, []byte(*u)), nil
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
		return serviceErrResp(err), nil
	}
	if u == nil {
		return genserver.Response(http.StatusNotFound, nil), nil
	}
	progress := service.ProgressForXP(u.XP)
	return genserver.Response(http.StatusOK, genserver.UserXpDto{
		TotalXp:        int32(u.XP),
		CurrentLevel:   progress.Level,
		CurrentLevelXp: progress.CurrentLevel,
		NextLevelXp:    progress.NextLevel,
	}), nil
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
	items, err := s.q.GetAchievementProgress(ctx, id, s.achCfg)
	if err != nil {
		return serviceErrResp(err), nil
	}
	dtos := make([]genserver.UserAchievementsDtoInner, 0, len(items))
	for _, a := range items {
		dtos = append(dtos, genserver.UserAchievementsDtoInner{
			AchievementId:  a.ID,
			Claimed:        a.Claimed,
			CurrentValue:   a.CurrentValue,
			ThresholdValue: a.Threshold,
			ThresholdUp:    a.ThresholdUp,
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
	claimable, err := s.q.CheckAchievementClaimable(ctx, achievementID, id, s.achCfg)
	if err != nil {
		return serviceErrResp(err), nil
	}
	if !claimable {
		return genserver.Response(http.StatusForbidden, nil), nil
	}
	if err := s.user.ClaimAchievement(ctx, id, achievementID); err != nil {
		return serviceErrResp(err), nil
	}
	return genserver.Response(http.StatusOK, nil), nil
}
