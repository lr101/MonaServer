package handler

import (
	"context"
	"encoding/json"
	"net/http"
	"testing"
	"time"

	genserver "github.com/lrprojects/monaserver/internal/gen/server"
	"github.com/lrprojects/monaserver/internal/middleware"
	"github.com/lrprojects/monaserver/internal/service"
)

func TestGetUserLikesReturnsOnlyNormalLikeCount(t *testing.T) {
	authHandler, auth := setupAuthServicer(t)
	servicer := NewLikesServicer(service.NewLike(authHandler.q), service.NewGuard(authHandler.q))
	ctx := context.Background()
	user, err := auth.Signup(ctx, "normal_like_counts_user", "password123", nil)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}

	resp, err := servicer.GetUserLikes(ctx, user.UserID.String())
	if err != nil {
		t.Fatalf("get user likes: %v", err)
	}
	if resp.Code != http.StatusOK {
		t.Fatalf("get user likes status = %d, want 200", resp.Code)
	}
	body, err := json.Marshal(resp.Body)
	if err != nil {
		t.Fatalf("marshal user likes: %v", err)
	}
	var fields map[string]json.RawMessage
	if err := json.Unmarshal(body, &fields); err != nil {
		t.Fatalf("decode user likes: %v", err)
	}
	if len(fields) != 1 || fields["likeCount"] == nil {
		t.Fatalf("user likes response = %s, want only likeCount", body)
	}
}

func TestNormalLikeCanBeRemoved(t *testing.T) {
	authHandler, auth := setupAuthServicer(t)
	q := authHandler.q
	userSvc := service.NewUser(q, nil, nil, auth, nil)
	groupSvc := service.NewGroup(q, nil, userSvc)
	pinSvc := service.NewPin(q, nil)
	likeSvc := service.NewLike(q)
	servicer := NewLikesServicer(likeSvc, service.NewGuard(q))
	ctx := context.Background()
	user, err := auth.Signup(ctx, "partial_like_user", "password123", nil)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}
	group, err := groupSvc.Create(ctx, service.CreateGroupInput{
		Name: "normal_like_group", Visibility: 0, GroupAdmin: user.UserID,
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
	on := true
	if _, err := likeSvc.CreateOrUpdate(ctx, pin.ID, service.CreateLikeInput{
		UserID: user.UserID, Like: &on,
	}); err != nil {
		t.Fatalf("create initial like: %v", err)
	}

	userCtx := middleware.WithUser(ctx, user.UserID, middleware.RoleUser)
	off := false
	resp, err := servicer.CreateOrUpdateLike(userCtx, pin.ID.String(), genserver.CreateLikeDto{
		UserId: user.UserID.String(), Like: &off,
	})
	if err != nil {
		t.Fatalf("update like: %v", err)
	}
	if resp.Code != 201 {
		t.Fatalf("update status = %d, want 201", resp.Code)
	}
	got, err := likeSvc.CountByPin(ctx, pin.ID, user.UserID)
	if err != nil {
		t.Fatalf("count likes: %v", err)
	}
	if got.LikeCount != 0 || got.LikedByUser {
		t.Fatalf("unlike produced %+v", got)
	}
}
