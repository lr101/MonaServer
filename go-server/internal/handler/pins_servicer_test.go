package handler

import (
	"context"
	"fmt"
	"net/http"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/lrprojects/monaserver/internal/db"
	genserver "github.com/lrprojects/monaserver/internal/gen/server"
	"github.com/lrprojects/monaserver/internal/middleware"
	"github.com/lrprojects/monaserver/internal/service"
)

func TestPinSyncAppliesVisibilityAndFilters(t *testing.T) {
	authHandler, auth := setupAuthServicer(t)
	q := authHandler.q
	userSvc := service.NewUser(q, nil, nil, auth, nil)
	groupSvc := service.NewGroup(q, nil, userSvc)
	pinSvc := service.NewPin(q, nil)
	guardSvc := service.NewGuard(q)
	servicer := NewPinsServicer(pinSvc, groupSvc, guardSvc, q)
	ctx := context.Background()

	owner, err := auth.Signup(ctx, "pin_sync_owner", "password123", nil)
	if err != nil {
		t.Fatalf("signup owner: %v", err)
	}
	outsider, err := auth.Signup(ctx, "pin_sync_outsider", "password123", nil)
	if err != nil {
		t.Fatalf("signup outsider: %v", err)
	}
	privateGroup, err := groupSvc.Create(ctx, service.CreateGroupInput{
		Name: "pin_sync_private", Visibility: 1, GroupAdmin: owner.UserID,
	})
	if err != nil {
		t.Fatalf("create private group: %v", err)
	}
	publicGroup, err := groupSvc.Create(ctx, service.CreateGroupInput{
		Name: "pin_sync_public", Visibility: 0, GroupAdmin: owner.UserID,
	})
	if err != nil {
		t.Fatalf("create public group: %v", err)
	}
	privatePin, err := pinSvc.Create(ctx, service.CreatePinInput{
		Latitude: 1, Longitude: 1, CreationDate: time.Now().Add(-time.Minute),
		UserID: owner.UserID, GroupID: privateGroup.ID,
	})
	if err != nil {
		t.Fatalf("create private pin: %v", err)
	}
	publicPin, err := pinSvc.Create(ctx, service.CreatePinInput{
		Latitude: 2, Longitude: 2, CreationDate: time.Now(),
		UserID: owner.UserID, GroupID: publicGroup.ID,
	})
	if err != nil {
		t.Fatalf("create public pin: %v", err)
	}

	outsiderCtx := middleware.WithUser(ctx, outsider.UserID, middleware.RoleUser)
	resp, err := servicer.GetPinImagesByIds(outsiderCtx, nil, privateGroup.ID.String(), "", false, 0, 0, 0, 20, time.Time{})
	if err != nil {
		t.Fatalf("private group sync: %v", err)
	}
	privateResult, ok := resp.Body.(genserver.PinsSyncDto)
	if !ok {
		t.Fatalf("private response body type = %T", resp.Body)
	}
	if len(privateResult.Items) != 0 {
		t.Fatalf("non-member received %d private pins", len(privateResult.Items))
	}

	resp, err = servicer.GetPinImagesByIds(outsiderCtx, []string{publicPin.ID.String()}, "", "", false, 0, 0, 0, 20, time.Time{})
	if err != nil {
		t.Fatalf("id-filtered sync: %v", err)
	}
	if resp.Code != 200 {
		t.Fatalf("id-filtered sync status = %d, want 200", resp.Code)
	}
	idResult, ok := resp.Body.(genserver.PinsSyncDto)
	if !ok {
		t.Fatalf("id response body type = %T", resp.Body)
	}
	if len(idResult.Items) != 1 || idResult.Items[0].Id != publicPin.ID.String() {
		t.Fatalf("id filter returned %+v, want only %s", idResult.Items, publicPin.ID)
	}
	for _, item := range idResult.Items {
		if item.Id == privatePin.ID.String() {
			t.Fatal("id filter leaked a private pin")
		}
	}
}

func TestPinSyncIncludesAllUserGroups(t *testing.T) {
	authHandler, auth := setupAuthServicer(t)
	q := authHandler.q
	userSvc := service.NewUser(q, nil, nil, auth, nil)
	groupSvc := service.NewGroup(q, nil, userSvc)
	servicer := NewPinsServicer(service.NewPin(q, nil), groupSvc, service.NewGuard(q), q)
	ctx := context.Background()

	user, err := auth.Signup(ctx, "pin_sync_many_groups", "password123", nil)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}

	const groupCount = 1001
	for i := range groupCount {
		groupID := uuid.New()
		if _, err := q.CreateGroup(ctx, db.Group{
			ID:         groupID,
			Name:       fmt.Sprintf("pin_sync_many_%04d", i),
			Visibility: 0,
			AdminID:    user.UserID,
		}); err != nil {
			t.Fatalf("create group %d: %v", i, err)
		}
		if err := q.AddMember(ctx, groupID, user.UserID); err != nil {
			t.Fatalf("add member %d: %v", i, err)
		}
	}

	resp, err := servicer.Sync(
		middleware.WithUser(ctx, user.UserID, middleware.RoleUser),
		time.Time{},
	)
	if err != nil {
		t.Fatalf("sync: %v", err)
	}
	result, ok := resp.Body.(genserver.SyncDto)
	if !ok {
		t.Fatalf("sync response body type = %T", resp.Body)
	}
	if len(result.GroupUpdates) != groupCount {
		t.Fatalf("sync returned %d groups, want %d", len(result.GroupUpdates), groupCount)
	}
}

func TestGetPinOmitsImageWhenWithImageIsFalse(t *testing.T) {
	authHandler, auth := setupAuthServicer(t)
	q := authHandler.q
	userSvc := service.NewUser(q, nil, nil, auth, nil)
	groupSvc := service.NewGroup(q, nil, userSvc)
	obj, err := service.NewObject("localhost:9999", "localhost:9999", "key", "secret", "bucket", false, time.Hour)
	if err != nil {
		t.Fatalf("create object service: %v", err)
	}
	pinSvc := service.NewPin(q, obj)
	servicer := NewPinsServicer(pinSvc, groupSvc, service.NewGuard(q), q)
	ctx := context.Background()
	user, err := auth.Signup(ctx, "pin_without_image", "password123", nil)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}
	group, err := groupSvc.Create(ctx, service.CreateGroupInput{
		Name: "pin_without_image_group", Visibility: 0, GroupAdmin: user.UserID,
	})
	if err != nil {
		t.Fatalf("create group: %v", err)
	}
	pin, err := pinSvc.Create(ctx, service.CreatePinInput{
		Latitude: 1, Longitude: 1, CreationDate: time.Now(), UserID: user.UserID, GroupID: group.ID,
	})
	if err != nil {
		t.Fatalf("create pin: %v", err)
	}

	userCtx := middleware.WithUser(ctx, user.UserID, middleware.RoleUser)
	resp, err := servicer.GetPin(userCtx, pin.ID.String(), false)
	if err != nil {
		t.Fatalf("get pin: %v", err)
	}
	got, ok := resp.Body.(genserver.PinWithOptionalImageDto)
	if !ok {
		t.Fatalf("response body type = %T", resp.Body)
	}
	if got.Image != "" {
		t.Fatalf("withImage=false returned image URL %q", got.Image)
	}
}

func TestCreatePinRejectsEmptyImage(t *testing.T) {
	authHandler, auth := setupAuthServicer(t)
	q := authHandler.q
	userSvc := service.NewUser(q, nil, nil, auth, nil)
	groupSvc := service.NewGroup(q, nil, userSvc)
	servicer := NewPinsServicer(service.NewPin(q, nil), groupSvc, service.NewGuard(q), q)
	ctx := context.Background()
	user, err := auth.Signup(ctx, "empty_pin_image_user", "password123", nil)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}
	group, err := groupSvc.Create(ctx, service.CreateGroupInput{
		Name: "empty_pin_image_group", Visibility: 0, GroupAdmin: user.UserID,
	})
	if err != nil {
		t.Fatalf("create group: %v", err)
	}
	userCtx := middleware.WithUser(ctx, user.UserID, middleware.RoleUser)
	resp, err := servicer.CreatePin(userCtx, genserver.PinRequestDto{
		Image: "", Latitude: 1, Longitude: 1, UserId: user.UserID.String(), GroupId: group.ID.String(),
	})
	if err != nil {
		t.Fatalf("create pin: %v", err)
	}
	if resp.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want 400", resp.Code)
	}
}
