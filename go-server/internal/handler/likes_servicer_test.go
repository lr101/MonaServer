package handler

import (
	"context"
	"testing"
	"time"

	genserver "github.com/lrprojects/monaserver/internal/gen/server"
	"github.com/lrprojects/monaserver/internal/middleware"
	"github.com/lrprojects/monaserver/internal/service"
)

func TestPartialLikeUpdatePreservesOmittedFlags(t *testing.T) {
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
		Name: "partial_like_group", Visibility: 0, GroupAdmin: user.UserID,
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
		UserID: user.UserID, Like: &on, LikeLocation: &on, LikePhotography: &on, LikeArt: &on,
	}); err != nil {
		t.Fatalf("create initial like: %v", err)
	}

	userCtx := middleware.WithUser(ctx, user.UserID, middleware.RoleUser)
	off := false
	resp, err := servicer.CreateOrUpdateLike(userCtx, pin.ID.String(), genserver.CreateLikeDto{
		UserId: user.UserID.String(), LikeArt: &off,
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
	if got.LikeCount != 1 || got.LikeLocationCount != 1 || got.LikePhotographyCount != 1 || got.LikeArtCount != 0 {
		t.Fatalf("partial update produced %+v", got)
	}
}
