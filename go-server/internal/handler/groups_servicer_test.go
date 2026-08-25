package handler

import (
	"context"
	"fmt"
	"net/http"
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
