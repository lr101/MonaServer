package handler

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/google/uuid"
	genserver "github.com/lrprojects/monaserver/internal/gen/server"
	"github.com/lrprojects/monaserver/internal/middleware"
	"github.com/lrprojects/monaserver/internal/service"
)

func TestPrivateGroupDetailsAreHiddenFromNonMembers(t *testing.T) {
	authHandler, auth := setupAuthServicer(t)
	q := authHandler.q
	userSvc := service.NewUser(q, nil, nil, auth, nil)
	groupSvc := service.NewGroup(q, nil, userSvc)
	servicer := NewGroupsServicer(groupSvc, service.NewGuard(q))
	ctx := context.Background()

	owner, err := auth.Signup(ctx, "private_group_owner", "password123", nil)
	if err != nil {
		t.Fatalf("signup owner: %v", err)
	}
	outsider, err := auth.Signup(ctx, "private_group_outsider", "password123", nil)
	if err != nil {
		t.Fatalf("signup outsider: %v", err)
	}
	description := "members only"
	link := "https://private.example"
	group, err := groupSvc.Create(ctx, service.CreateGroupInput{
		Name:        "private_group",
		Description: &description,
		Link:        &link,
		Visibility:  1,
		GroupAdmin:  owner.UserID,
	})
	if err != nil {
		t.Fatalf("create group: %v", err)
	}

	outsiderCtx := middleware.WithUser(ctx, outsider.UserID, middleware.RoleUser)
	resp, err := servicer.GetGroup(outsiderCtx, group.ID.String())
	if err != nil {
		t.Fatalf("get group: %v", err)
	}
	if resp.Code != 200 {
		t.Fatalf("get group status = %d, want 200", resp.Code)
	}
	got, ok := resp.Body.(genserver.GroupDto)
	if !ok {
		t.Fatalf("response body type = %T, want genserver.GroupDto", resp.Body)
	}
	if got.Description != "" || got.Link != "" || got.GroupAdmin != "" || got.InviteUrl != "" || !got.LastUpdated.IsZero() {
		t.Fatalf("private fields leaked to non-member: %+v", got)
	}
	progress, err := servicer.GetGroupProgression(outsiderCtx, group.ID.String())
	if err != nil {
		t.Fatalf("get private group progression: %v", err)
	}
	if progress.Code != http.StatusForbidden {
		t.Fatalf("private group progression status = %d, want %d", progress.Code, http.StatusForbidden)
	}
	ownerProgress, err := servicer.GetGroupProgression(
		middleware.WithUser(ctx, owner.UserID, middleware.RoleUser),
		group.ID.String(),
	)
	if err != nil {
		t.Fatalf("get private group progression as member: %v", err)
	}
	if ownerProgress.Code != http.StatusOK {
		t.Fatalf("private group progression for member status = %d, want %d", ownerProgress.Code, http.StatusOK)
	}
}

func TestGroupAchievementVisibilityAndClaimRequireMembership(t *testing.T) {
	authHandler, auth := setupAuthServicer(t)
	q := authHandler.q
	userSvc := service.NewUser(q, nil, nil, auth, nil)
	groupSvc := service.NewGroup(q, nil, userSvc)
	servicer := NewGroupsServicer(groupSvc, service.NewGuard(q))
	ctx := context.Background()
	owner, err := auth.Signup(ctx, "group_achievement_owner", "password123", nil)
	if err != nil {
		t.Fatalf("signup owner: %v", err)
	}
	outsider, err := auth.Signup(ctx, "group_achievement_outsider", "password123", nil)
	if err != nil {
		t.Fatalf("signup outsider: %v", err)
	}

	publicGroup, err := groupSvc.Create(ctx, service.CreateGroupInput{
		Name: "group_achievement_public", Visibility: 0, GroupAdmin: owner.UserID,
	})
	if err != nil {
		t.Fatalf("create public group: %v", err)
	}
	outsiderCtx := middleware.WithUser(ctx, outsider.UserID, middleware.RoleUser)
	publicProgress, err := servicer.GetGroupAchievements(outsiderCtx, publicGroup.ID.String())
	if err != nil {
		t.Fatalf("get public group achievements: %v", err)
	}
	if publicProgress.Code != http.StatusOK {
		t.Fatalf("public group achievements status = %d, want %d", publicProgress.Code, http.StatusOK)
	}
	if got := publicProgress.Body.([]genserver.GroupAchievementsDtoInner); len(got) != 3 ||
		got[0].RewardPinStyle != "moss" || got[0].Track != "active_pins" {
		t.Fatalf("public group achievements = %+v, want three pin style rewards", got)
	}
	nonMemberClaim, err := servicer.ClaimGroupAchievement(outsiderCtx, publicGroup.ID.String(), 1)
	if err != nil {
		t.Fatalf("claim public group achievement as outsider: %v", err)
	}
	if nonMemberClaim.Code != http.StatusForbidden {
		t.Fatalf("non-member claim status = %d, want %d", nonMemberClaim.Code, http.StatusForbidden)
	}

	privateGroup, err := groupSvc.Create(ctx, service.CreateGroupInput{
		Name: "group_achievement_private", Visibility: 1, GroupAdmin: owner.UserID,
	})
	if err != nil {
		t.Fatalf("create private group: %v", err)
	}
	privateProgress, err := servicer.GetGroupAchievements(outsiderCtx, privateGroup.ID.String())
	if err != nil {
		t.Fatalf("get private group achievements as outsider: %v", err)
	}
	if privateProgress.Code != http.StatusForbidden {
		t.Fatalf("private group achievements status = %d, want %d", privateProgress.Code, http.StatusForbidden)
	}
}

func TestGroupAchievementClaimIsVisibleToAdminAfterSync(t *testing.T) {
	authHandler, auth := setupAuthServicer(t)
	q := authHandler.q
	userSvc := service.NewUser(q, nil, nil, auth, nil)
	groupSvc := service.NewGroup(q, nil, userSvc)
	guard := service.NewGuard(q)
	groups := NewGroupsServicer(groupSvc, guard)
	pinSvc := service.NewPin(q, nil)
	pins := NewPinsServicer(pinSvc, groupSvc, guard, q)
	ctx := context.Background()

	claimant, err := auth.Signup(ctx, "group_achievement_claim_member", "password123", nil)
	if err != nil {
		t.Fatalf("signup claimant: %v", err)
	}
	admin, err := auth.Signup(ctx, "group_achievement_claim_admin", "password123", nil)
	if err != nil {
		t.Fatalf("signup admin: %v", err)
	}
	group, err := groupSvc.Create(ctx, service.CreateGroupInput{
		Name: "group_achievement_claim_sync", Visibility: 0, GroupAdmin: admin.UserID,
	})
	if err != nil {
		t.Fatalf("create group: %v", err)
	}
	if err := q.AddMember(ctx, group.ID, claimant.UserID); err != nil {
		t.Fatalf("add claimant: %v", err)
	}
	createdAt := time.Now()
	for i := 0; i < 10; i++ {
		if _, err := pinSvc.Create(ctx, service.CreatePinInput{
			Latitude: 1 + float64(i)/1000, Longitude: 1 + float64(i)/1000,
			CreationDate: createdAt,
			UserID:       admin.UserID, GroupID: group.ID,
		}); err != nil {
			t.Fatalf("create active pin %d: %v", i+1, err)
		}
	}

	oldUpdate := time.Date(2020, time.January, 1, 0, 0, 0, 0, time.UTC)
	if _, err := q.Pool().Exec(ctx, `UPDATE groups SET update_date = $2 WHERE id = $1`, group.ID, oldUpdate); err != nil {
		t.Fatalf("set group sync cursor: %v", err)
	}
	oldPinUpdate := oldUpdate.Add(-time.Hour)
	if _, err := q.Pool().Exec(ctx, `UPDATE pins SET update_date = $2 WHERE group_id = $1`, group.ID, oldPinUpdate); err != nil {
		t.Fatalf("set pin sync cursor: %v", err)
	}
	claimantCtx := middleware.WithUser(ctx, claimant.UserID, middleware.RoleUser)
	claim, err := groups.ClaimGroupAchievement(claimantCtx, group.ID.String(), 1)
	if err != nil {
		t.Fatalf("claim group achievement: %v", err)
	}
	if claim.Code != http.StatusOK {
		t.Fatalf("claim status = %d, want %d", claim.Code, http.StatusOK)
	}

	adminCtx := middleware.WithUser(ctx, admin.UserID, middleware.RoleUser)
	sync, err := pins.Sync(adminCtx, oldUpdate)
	if err != nil {
		t.Fatalf("sync for group admin: %v", err)
	}
	if sync.Code != http.StatusOK {
		t.Fatalf("sync status = %d, want %d", sync.Code, http.StatusOK)
	}
	syncDTO, ok := sync.Body.(genserver.SyncDto)
	if !ok {
		t.Fatalf("sync response body type = %T, want genserver.SyncDto", sync.Body)
	}
	var syncedGroup *genserver.GroupDto
	for i := range syncDTO.GroupUpdates {
		if syncDTO.GroupUpdates[i].Group.Id == group.ID.String() {
			syncedGroup = &syncDTO.GroupUpdates[i].Group
			if len(syncDTO.GroupUpdates[i].PinsAdded) != 0 {
				t.Fatalf(
					"admin sync returned %d pins, want metadata-only update",
					len(syncDTO.GroupUpdates[i].PinsAdded),
				)
			}
			break
		}
	}
	if syncedGroup == nil || !syncedGroup.LastUpdated.After(oldUpdate) {
		t.Fatalf("admin sync group update = %+v, want claim revision after %s", syncedGroup, oldUpdate)
	}

	progress, err := groups.GetGroupAchievements(adminCtx, group.ID.String())
	if err != nil {
		t.Fatalf("get achievements for admin: %v", err)
	}
	items, ok := progress.Body.([]genserver.GroupAchievementsDtoInner)
	if !ok || len(items) != 3 {
		t.Fatalf("admin achievement body = %#v, want three rewards", progress.Body)
	}
	if !items[0].Claimed || items[0].RewardPinStyle != "moss" {
		t.Fatalf("admin achievement = %+v, want claimant's moss reward", items[0])
	}
}

func TestGetGroupIncludesBestSeason(t *testing.T) {
	authHandler, auth := setupAuthServicer(t)
	q := authHandler.q
	userSvc := service.NewUser(q, nil, nil, auth, nil)
	groupSvc := service.NewGroup(q, nil, userSvc)
	servicer := NewGroupsServicer(groupSvc, service.NewGuard(q))
	ctx := context.Background()
	user, err := auth.Signup(ctx, "group_season_owner", "password123", nil)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}
	group, err := groupSvc.Create(ctx, service.CreateGroupInput{Name: "group_with_season", Visibility: 0, GroupAdmin: user.UserID})
	if err != nil {
		t.Fatalf("create group: %v", err)
	}
	seasonID, err := q.CreateSeason(ctx, 8, 2026, 9)
	if err != nil {
		t.Fatalf("create season: %v", err)
	}
	if err := q.CreateGroupSeason(ctx, group.ID, seasonID, 3, 19); err != nil {
		t.Fatalf("create group season: %v", err)
	}

	userCtx := middleware.WithUser(ctx, user.UserID, middleware.RoleUser)
	resp, err := servicer.GetGroup(userCtx, group.ID.String())
	if err != nil {
		t.Fatalf("get group: %v", err)
	}
	got := resp.Body.(genserver.GroupDto)
	if got.BestSeason == nil || got.BestSeason.Points != 19 || got.BestSeason.Rank != 3 || got.BestSeason.Season.Id != seasonID.String() {
		t.Fatalf("bestSeason = %+v, want season with 19 points at rank 3", got.BestSeason)
	}
}

func TestGroupProgressionRouteReportsLevelsEarnedByPinActivity(t *testing.T) {
	authHandler, auth := setupAuthServicer(t)
	q := authHandler.q
	userSvc := service.NewUser(q, nil, nil, auth, nil)
	groupSvc := service.NewGroup(q, nil, userSvc)
	pinSvc := service.NewPin(q, nil)
	servicer := NewGroupsServicer(groupSvc, service.NewGuard(q))
	ctx := context.Background()
	user, err := auth.Signup(ctx, "group_progression_owner", "password123", nil)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}
	group, err := groupSvc.Create(ctx, service.CreateGroupInput{
		Name: "group_progression_group", Visibility: 0, GroupAdmin: user.UserID,
	})
	if err != nil {
		t.Fatalf("create group: %v", err)
	}
	for i := 0; i < 9; i++ {
		if _, err := pinSvc.Create(ctx, service.CreatePinInput{
			Latitude: 48.1 + float64(i)/1000, Longitude: 11.6, CreationDate: time.Now(),
			UserID: user.UserID, GroupID: group.ID,
		}); err != nil {
			t.Fatalf("create group pin %d: %v", i, err)
		}
	}

	var got struct {
		TotalXP        int32 `json:"totalXp"`
		CurrentLevel   int32 `json:"currentLevel"`
		CurrentLevelXP int32 `json:"currentLevelXp"`
		NextLevelXP    int32 `json:"nextLevelXp"`
	}
	router := genserver.NewRouter(genserver.NewGroupsAPIController(servicer))
	readProgress := func() struct {
		TotalXP        int32 `json:"totalXp"`
		CurrentLevel   int32 `json:"currentLevel"`
		CurrentLevelXP int32 `json:"currentLevelXp"`
		NextLevelXP    int32 `json:"nextLevelXp"`
	} {
		t.Helper()
		request := httptest.NewRequest(http.MethodGet, "/api/v2/groups/"+group.ID.String()+"/progression", nil)
		request = request.WithContext(middleware.WithUser(request.Context(), user.UserID, middleware.RoleUser))
		response := httptest.NewRecorder()
		router.ServeHTTP(response, request)
		if response.Code != http.StatusOK {
			t.Fatalf("group progression status = %d, body = %s; want 200", response.Code, response.Body.String())
		}
		var result struct {
			TotalXP        int32 `json:"totalXp"`
			CurrentLevel   int32 `json:"currentLevel"`
			CurrentLevelXP int32 `json:"currentLevelXp"`
			NextLevelXP    int32 `json:"nextLevelXp"`
		}
		if err := json.Unmarshal(response.Body.Bytes(), &result); err != nil {
			t.Fatalf("decode group progression: %v", err)
		}
		return result
	}
	got = readProgress()
	if got.TotalXP != 45 || got.CurrentLevel != 1 || got.CurrentLevelXP != 0 || got.NextLevelXP != 50 {
		t.Fatalf("group progression before level-up = %+v, want 45 XP at level 1 toward 50", got)
	}
	if _, err := pinSvc.Create(ctx, service.CreatePinInput{
		Latitude: 48.11, Longitude: 11.6, CreationDate: time.Now(),
		UserID: user.UserID, GroupID: group.ID,
	}); err != nil {
		t.Fatalf("create level-up pin: %v", err)
	}
	got = readProgress()
	if got.TotalXP != 50 || got.CurrentLevel != 2 || got.CurrentLevelXP != 50 || got.NextLevelXP != 150 {
		t.Fatalf("group progression = %+v, want 50 XP at level 2 with next threshold 150", got)
	}
}

func TestGroupListHonorsIdsDescriptionSearchAndUnpagedRequests(t *testing.T) {
	authHandler, auth := setupAuthServicer(t)
	q := authHandler.q
	userSvc := service.NewUser(q, nil, nil, auth, nil)
	groupSvc := service.NewGroup(q, nil, userSvc)
	servicer := NewGroupsServicer(groupSvc, service.NewGuard(q))
	ctx := context.Background()
	user, err := auth.Signup(ctx, "group_filter_user", "password123", nil)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}
	userCtx := middleware.WithUser(ctx, user.UserID, middleware.RoleUser)
	description := "needle only in description"
	wanted, err := groupSvc.Create(ctx, service.CreateGroupInput{
		Name: "group_filter_wanted", Description: &description, Visibility: 0, GroupAdmin: user.UserID,
	})
	if err != nil {
		t.Fatalf("create wanted group: %v", err)
	}
	if _, err := groupSvc.Create(ctx, service.CreateGroupInput{
		Name: "group_filter_other", Visibility: 0, GroupAdmin: user.UserID,
	}); err != nil {
		t.Fatalf("create other group: %v", err)
	}

	resp, err := servicer.GetGroupsByIds(userCtx, []string{wanted.ID.String()}, "", "", false, false, 0, 20, time.Time{})
	if err != nil {
		t.Fatalf("list by ids: %v", err)
	}
	byID, ok := resp.Body.(genserver.GroupsSyncDto)
	if !ok {
		t.Fatalf("id response body type = %T", resp.Body)
	}
	if len(byID.Items) != 1 || byID.Items[0].Id != wanted.ID.String() {
		t.Fatalf("id filter returned %+v, want only %s", byID.Items, wanted.ID)
	}

	resp, err = servicer.GetGroupsByIds(userCtx, nil, "needle only", "", false, false, 0, 20, time.Time{})
	if err != nil {
		t.Fatalf("search description: %v", err)
	}
	byDescription := resp.Body.(genserver.GroupsSyncDto)
	if len(byDescription.Items) != 1 || byDescription.Items[0].Id != wanted.ID.String() {
		t.Fatalf("description search returned %+v, want only %s", byDescription.Items, wanted.ID)
	}

	for i := 0; i < 25; i++ {
		if _, err := groupSvc.Create(ctx, service.CreateGroupInput{
			Name: fmt.Sprintf("group_unpaged_%02d", i), Visibility: 0, GroupAdmin: user.UserID,
		}); err != nil {
			t.Fatalf("create unpaged group %d: %v", i, err)
		}
	}
	resp, err = servicer.GetGroupsByIds(userCtx, nil, "group_unpaged_", "", false, false, 0, 0, time.Time{})
	if err != nil {
		t.Fatalf("unpaged group list: %v", err)
	}
	unpaged := resp.Body.(genserver.GroupsSyncDto)
	if len(unpaged.Items) != 25 {
		t.Fatalf("unpaged result count = %d, want 25", len(unpaged.Items))
	}
}

func TestUpdateGroupCanMakePrivateGroupPublicAndClearOptionalText(t *testing.T) {
	authHandler, auth := setupAuthServicer(t)
	q := authHandler.q
	userSvc := service.NewUser(q, nil, nil, auth, nil)
	groupSvc := service.NewGroup(q, nil, userSvc)
	servicer := NewGroupsServicer(groupSvc, service.NewGuard(q))
	ctx := context.Background()
	user, err := auth.Signup(ctx, "group_update_user", "password123", nil)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}
	description := "remove me"
	link := "https://remove.example"
	group, err := groupSvc.Create(ctx, service.CreateGroupInput{
		Name: "group_update_optional", Description: &description, Link: &link,
		Visibility: 1, GroupAdmin: user.UserID,
	})
	if err != nil {
		t.Fatalf("create group: %v", err)
	}

	userCtx := middleware.WithUser(ctx, user.UserID, middleware.RoleUser)
	empty := ""
	public := int32(0)
	resp, err := servicer.UpdateGroup(userCtx, group.ID.String(), genserver.UpdateGroupDto{
		Description: &empty, Link: &empty, Visibility: &public,
	})
	if err != nil {
		t.Fatalf("update group: %v", err)
	}
	if resp.Code != 200 {
		t.Fatalf("update status = %d, want 200", resp.Code)
	}
	stored, err := groupSvc.Get(ctx, group.ID)
	if err != nil {
		t.Fatalf("get updated group: %v", err)
	}
	if stored.Visibility != 0 {
		t.Fatalf("visibility = %d, want public visibility 0", stored.Visibility)
	}
	if stored.Description != nil && *stored.Description != "" {
		t.Fatalf("description was not cleared: %q", *stored.Description)
	}
	if stored.Link != nil && *stored.Link != "" {
		t.Fatalf("link was not cleared: %q", *stored.Link)
	}
	if stored.InviteUrl != nil {
		t.Fatalf("invite URL was not cleared: %q", *stored.InviteUrl)
	}

	second, err := groupSvc.Create(ctx, service.CreateGroupInput{
		Name: "group_update_optional_second", Visibility: 1, GroupAdmin: user.UserID,
	})
	if err != nil {
		t.Fatalf("create second private group: %v", err)
	}
	resp, err = servicer.UpdateGroup(userCtx, second.ID.String(), genserver.UpdateGroupDto{Visibility: &public})
	if err != nil {
		t.Fatalf("make second group public: %v", err)
	}
	if resp.Code != http.StatusOK {
		t.Fatalf("second public update status = %d, want 200", resp.Code)
	}
}

func TestUpdateGroupRejectsMissingNewAdminAsNotFound(t *testing.T) {
	authHandler, auth := setupAuthServicer(t)
	q := authHandler.q
	userSvc := service.NewUser(q, nil, nil, auth, nil)
	groupSvc := service.NewGroup(q, nil, userSvc)
	servicer := NewGroupsServicer(groupSvc, service.NewGuard(q))
	ctx := context.Background()
	user, err := auth.Signup(ctx, "group_admin_update_user", "password123", nil)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}
	group, err := groupSvc.Create(ctx, service.CreateGroupInput{
		Name: "group_admin_update", Visibility: 0, GroupAdmin: user.UserID,
	})
	if err != nil {
		t.Fatalf("create group: %v", err)
	}
	missing := uuid.NewString()
	userCtx := middleware.WithUser(ctx, user.UserID, middleware.RoleUser)
	resp, err := servicer.UpdateGroup(userCtx, group.ID.String(), genserver.UpdateGroupDto{GroupAdmin: &missing})
	if err != nil {
		t.Fatalf("update group: %v", err)
	}
	if resp.Code != 404 {
		t.Fatalf("update status = %d, want 404", resp.Code)
	}
}

func TestAddGroupRejectsInvalidBase64Image(t *testing.T) {
	authHandler, auth := setupAuthServicer(t)
	q := authHandler.q
	userSvc := service.NewUser(q, nil, nil, auth, nil)
	servicer := NewGroupsServicer(service.NewGroup(q, nil, userSvc), service.NewGuard(q))
	ctx := context.Background()
	user, err := auth.Signup(ctx, "invalid_group_image_user", "password123", nil)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}
	userCtx := middleware.WithUser(ctx, user.UserID, middleware.RoleUser)
	resp, err := servicer.AddGroup(userCtx, genserver.CreateGroupDto{
		Name: "invalid_group_image", Visibility: 0, ProfileImage: "%%%not-base64%%%",
	})
	if err != nil {
		t.Fatalf("add group: %v", err)
	}
	if resp.Code != 400 {
		t.Fatalf("status = %d, want 400", resp.Code)
	}
}

func TestAddAndUpdateGroupRejectEmptyImages(t *testing.T) {
	authHandler, auth := setupAuthServicer(t)
	q := authHandler.q
	userSvc := service.NewUser(q, nil, nil, auth, nil)
	groupSvc := service.NewGroup(q, nil, userSvc)
	servicer := NewGroupsServicer(groupSvc, service.NewGuard(q))
	ctx := context.Background()
	user, err := auth.Signup(ctx, "empty_group_image_user", "password123", nil)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}
	userCtx := middleware.WithUser(ctx, user.UserID, middleware.RoleUser)
	resp, err := servicer.AddGroup(userCtx, genserver.CreateGroupDto{
		Name: "empty_group_image", GroupAdmin: user.UserID.String(), Visibility: 0, ProfileImage: "",
	})
	if err != nil {
		t.Fatalf("add group: %v", err)
	}
	if resp.Code != http.StatusBadRequest {
		t.Fatalf("add status = %d, want 400", resp.Code)
	}

	group, err := groupSvc.Create(ctx, service.CreateGroupInput{
		Name: "empty_group_update_image", Visibility: 0, GroupAdmin: user.UserID,
	})
	if err != nil {
		t.Fatalf("create group: %v", err)
	}
	empty := ""
	resp, err = servicer.UpdateGroup(userCtx, group.ID.String(), genserver.UpdateGroupDto{ProfileImage: &empty})
	if err != nil {
		t.Fatalf("update group: %v", err)
	}
	if resp.Code != http.StatusBadRequest {
		t.Fatalf("update status = %d, want 400", resp.Code)
	}
}
