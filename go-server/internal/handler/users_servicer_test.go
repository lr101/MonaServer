package handler

import (
	"context"
	"encoding/json"
	"testing"
	"time"

	"github.com/lrprojects/monaserver/internal/db"
	genserver "github.com/lrprojects/monaserver/internal/gen/server"
	"github.com/lrprojects/monaserver/internal/middleware"
	"github.com/lrprojects/monaserver/internal/service"
)

func TestGetUserIncludesSelectedAchievementMessagingStateAndBestSeason(t *testing.T) {
	authHandler, auth := setupAuthServicer(t)
	q := authHandler.q
	userSvc := service.NewUser(q, nil, nil, auth, nil)
	servicer := NewUsersServicer(userSvc, service.NewGuard(q), q, db.AchievementConfig{})
	ctx := context.Background()
	user, err := auth.Signup(ctx, "complete_user_info", "password123", nil)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}
	groupSvc := service.NewGroup(q, nil, userSvc)
	if _, err := groupSvc.Create(ctx, service.CreateGroupInput{
		Name: "achievement_profile_group", Visibility: 0, GroupAdmin: user.UserID,
	}); err != nil {
		t.Fatalf("create group for achievement eligibility: %v", err)
	}
	if err := q.ClaimUserAchievement(ctx, user.UserID, 2); err != nil {
		t.Fatalf("claim achievement: %v", err)
	}
	rowID, err := q.GetUserAchievementRow(ctx, user.UserID, 2)
	if err != nil || rowID == nil {
		t.Fatalf("get achievement row: id=%v err=%v", rowID, err)
	}
	if err := q.SetUserSelectedBatch(ctx, user.UserID, *rowID); err != nil {
		t.Fatalf("select achievement: %v", err)
	}
	token := "firebase-token"
	if err := q.UpdateUserFirebaseToken(ctx, user.UserID, &token); err != nil {
		t.Fatalf("set messaging token: %v", err)
	}
	seasonID, err := q.CreateSeason(ctx, 7, 2026, 8)
	if err != nil {
		t.Fatalf("create season: %v", err)
	}
	if err := q.CreateUserSeason(ctx, user.UserID, seasonID, 2, 31); err != nil {
		t.Fatalf("create user season: %v", err)
	}

	userCtx := middleware.WithUser(ctx, user.UserID, middleware.RoleUser)
	resp, err := servicer.GetUser(userCtx, user.UserID.String())
	if err != nil {
		t.Fatalf("get user: %v", err)
	}
	got, ok := resp.Body.(genserver.UserInfoDto)
	if !ok {
		t.Fatalf("response body type = %T", resp.Body)
	}
	if got.SelectedBatch == nil || *got.SelectedBatch != 2 {
		t.Fatalf("selectedBatch = %v, want 2", got.SelectedBatch)
	}
	if got.IsMessagingRegistered == nil || !*got.IsMessagingRegistered {
		t.Fatalf("isMessagingRegistered = %v, want true", got.IsMessagingRegistered)
	}
	if got.BestSeason == nil || got.BestSeason.Id == "" || got.BestSeason.Points != 31 || got.BestSeason.Rank != 2 {
		t.Fatalf("bestSeason = %+v, want season with 31 points at rank 2", got.BestSeason)
	}
	if got.BestSeason.Season.Id != seasonID.String() || got.BestSeason.Season.SeasonNumber != 7 || got.BestSeason.Season.Year != 2026 || got.BestSeason.Season.Month != 8 {
		t.Fatalf("season metadata = %+v", got.BestSeason.Season)
	}

	other, err := auth.Signup(ctx, "user_info_outsider", "password123", nil)
	if err != nil {
		t.Fatalf("signup outsider: %v", err)
	}
	otherCtx := middleware.WithUser(ctx, other.UserID, middleware.RoleUser)
	resp, err = servicer.GetUser(otherCtx, user.UserID.String())
	if err != nil {
		t.Fatalf("get user as outsider: %v", err)
	}
	if public := resp.Body.(genserver.UserInfoDto); public.IsMessagingRegistered == nil || *public.IsMessagingRegistered {
		t.Fatalf("messaging registration = %v for another user, want false", public.IsMessagingRegistered)
	}

}

func TestGetUserAchievementsReturnsVersionedTieredCatalog(t *testing.T) {
	authHandler, auth := setupAuthServicer(t)
	q := authHandler.q
	userSvc := service.NewUser(q, nil, nil, auth, nil)
	servicer := NewUsersServicer(userSvc, service.NewGuard(q), q, db.AchievementConfig{})
	ctx := context.Background()
	user, err := auth.Signup(ctx, "achievement_catalog_user", "password123", nil)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}

	userCtx := middleware.WithUser(ctx, user.UserID, middleware.RoleUser)
	resp, err := servicer.GetUserAchievements(userCtx, user.UserID.String())
	if err != nil {
		t.Fatalf("get achievements: %v", err)
	}
	items, ok := resp.Body.([]genserver.UserAchievementsDtoInner)
	if !ok {
		t.Fatalf("response body type = %T", resp.Body)
	}
	if len(items) != 15 {
		t.Fatalf("achievement count = %d, want 15", len(items))
	}
	firstStickFound := false
	for _, item := range items {
		if item.Name == "First stick" {
			firstStickFound = true
			if item.Track != "sticks" || item.Difficulty != "easy" || item.RewardXp != 20 || item.DefinitionVersion != 2 {
				t.Fatalf("first-stick metadata = %+v", item)
			}
			if item.Claimed || item.Claimable || item.RewardAvailable == nil || !*item.RewardAvailable || item.CurrentValue != 0 {
				t.Fatalf("first-stick initial state = %+v", item)
			}
		}
	}
	if !firstStickFound {
		t.Fatal("first-stick milestone missing from response")
	}
}

func TestGetUserAchievementsIncludesFalseRewardAvailability(t *testing.T) {
	authHandler, auth := setupAuthServicer(t)
	q := authHandler.q
	userSvc := service.NewUser(q, nil, nil, auth, nil)
	groupSvc := service.NewGroup(q, nil, userSvc)
	pinSvc := service.NewPin(q, nil)
	servicer := NewUsersServicer(userSvc, service.NewGuard(q), q, db.AchievementConfig{})
	ctx := context.Background()
	user, err := auth.Signup(ctx, "reward_availability_user", "password123", nil)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}
	group, err := groupSvc.Create(ctx, service.CreateGroupInput{
		Name: "reward_availability_group", Visibility: 0, GroupAdmin: user.UserID,
	})
	if err != nil {
		t.Fatalf("create group: %v", err)
	}
	if _, err := pinSvc.Create(ctx, service.CreatePinInput{
		Latitude: 48.1, Longitude: 11.6, CreationDate: time.Now(), UserID: user.UserID, GroupID: group.ID,
	}); err != nil {
		t.Fatalf("create qualifying pin: %v", err)
	}
	if err := userSvc.ClaimAchievement(ctx, user.UserID, 3); err != nil {
		t.Fatalf("claim achievement: %v", err)
	}

	resp, err := servicer.GetUserAchievements(middleware.WithUser(ctx, user.UserID, middleware.RoleUser), user.UserID.String())
	if err != nil {
		t.Fatalf("get achievements: %v", err)
	}
	items, ok := resp.Body.([]genserver.UserAchievementsDtoInner)
	if !ok {
		t.Fatalf("response body type = %T", resp.Body)
	}
	encoded, err := json.Marshal(items)
	if err != nil {
		t.Fatalf("marshal achievements: %v", err)
	}
	var payload []map[string]any
	if err := json.Unmarshal(encoded, &payload); err != nil {
		t.Fatalf("decode achievements: %v", err)
	}
	for _, item := range payload {
		if item["achievementId"] == float64(3) {
			if available, present := item["rewardAvailable"]; !present || available != false {
				t.Fatalf("serialized rewardAvailable = %v, present=%t; want false", available, present)
			}
			return
		}
	}
	t.Fatal("first-stick achievement missing from response")
}

func TestGetUserXpIncludesLevelProgress(t *testing.T) {
	authHandler, auth := setupAuthServicer(t)
	q := authHandler.q
	userSvc := service.NewUser(q, nil, nil, auth, nil)
	servicer := NewUsersServicer(userSvc, service.NewGuard(q), q, db.AchievementConfig{})
	ctx := context.Background()
	user, err := auth.Signup(ctx, "xp_progress_user", "password123", nil)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}
	if err := q.AddUserXp(ctx, user.UserID, 100); err != nil {
		t.Fatalf("add xp: %v", err)
	}

	userCtx := middleware.WithUser(ctx, user.UserID, middleware.RoleUser)
	resp, err := servicer.GetUserXp(userCtx, user.UserID.String())
	if err != nil {
		t.Fatalf("get xp: %v", err)
	}
	got, ok := resp.Body.(genserver.UserXpDto)
	if !ok {
		t.Fatalf("response body type = %T", resp.Body)
	}
	want := genserver.UserXpDto{TotalXp: 100, CurrentLevel: 3, CurrentLevelXp: 75, NextLevelXp: 150}
	if got != want {
		t.Fatalf("XP response = %+v, want %+v", got, want)
	}
}

func TestUpdateUserRejectsInvalidBase64Image(t *testing.T) {
	authHandler, auth := setupAuthServicer(t)
	q := authHandler.q
	userSvc := service.NewUser(q, nil, nil, auth, nil)
	servicer := NewUsersServicer(userSvc, service.NewGuard(q), q, db.AchievementConfig{})
	ctx := context.Background()
	user, err := auth.Signup(ctx, "invalid_user_image", "password123", nil)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}
	userCtx := middleware.WithUser(ctx, user.UserID, middleware.RoleUser)
	resp, err := servicer.UpdateUser(userCtx, user.UserID.String(), genserver.UserUpdateDto{Image: "%%%not-base64%%%"})
	if err != nil {
		t.Fatalf("update user: %v", err)
	}
	if resp.Code != 400 {
		t.Fatalf("status = %d, want 400", resp.Code)
	}
}
