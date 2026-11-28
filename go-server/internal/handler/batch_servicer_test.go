package handler

import (
	"context"
	"net/http"
	"testing"

	"github.com/google/uuid"

	genserver "github.com/lrprojects/monaserver/internal/gen/server"
	"github.com/lrprojects/monaserver/internal/middleware"
	"github.com/lrprojects/monaserver/internal/service"
)

func TestBatchReadConcurrentOrderDeduplicationAndCancellation(t *testing.T) {
	authHandler, auth := setupAuthServicer(t)
	q := authHandler.q
	userSvc := service.NewUser(q, nil, nil, auth, nil)
	groupSvc := service.NewGroup(q, nil, userSvc)
	pinSvc := service.NewPin(q, nil)
	likeSvc := service.NewLike(q)
	guardSvc := service.NewGuard(q)

	usersServicer := NewUsersServicer(userSvc, nil, q)
	groupsServicer := NewGroupsServicer(groupSvc, guardSvc)
	pinsServicer := NewPinsServicer(pinSvc, groupSvc, guardSvc, q)
	likesServicer := NewLikesServicer(likeSvc, guardSvc)
	batch := NewBatchServicer(pinsServicer, usersServicer, groupsServicer, likesServicer, guardSvc)

	ctx := context.Background()
	viewer, err := auth.Signup(ctx, "batch_viewer", "password123", nil)
	if err != nil {
		t.Fatalf("signup viewer: %v", err)
	}
	other, err := auth.Signup(ctx, "batch_other", "password123", nil)
	if err != nil {
		t.Fatalf("signup other: %v", err)
	}
	missingUserID := uuid.New()

	viewerCtx := middleware.WithUser(ctx, viewer.UserID, middleware.RoleUser)
	requests := []genserver.BatchReadItem{
		{Kind: "user", Id: viewer.UserID.String()},
		{Kind: "user", Id: other.UserID.String()},
		{Kind: "user", Id: missingUserID.String()},
		{Kind: "user", Id: viewer.UserID.String()},
		{Kind: "userProgression", Id: viewer.UserID.String()},
	}

	resp, err := batch.BatchRead(viewerCtx, genserver.BatchReadRequest{Requests: requests})
	if err != nil {
		t.Fatalf("BatchRead: %v", err)
	}
	if resp.Code != http.StatusOK {
		t.Fatalf("BatchRead status = %d, want 200", resp.Code)
	}
	body, ok := resp.Body.(genserver.BatchReadResponse)
	if !ok {
		t.Fatalf("BatchRead body type = %T", resp.Body)
	}
	if len(body.Results) != len(requests) {
		t.Fatalf("BatchRead returned %d results, want %d", len(body.Results), len(requests))
	}

	if body.Results[0].Status != http.StatusOK || body.Results[0].User == nil || body.Results[0].User.Username != "batch_viewer" {
		t.Fatalf("result[0] = %+v, want batch_viewer", body.Results[0])
	}
	if body.Results[1].Status != http.StatusOK || body.Results[1].User == nil || body.Results[1].User.Username != "batch_other" {
		t.Fatalf("result[1] = %+v, want batch_other", body.Results[1])
	}
	if body.Results[2].Status != http.StatusNotFound {
		t.Fatalf("result[2].Status = %d, want 404", body.Results[2].Status)
	}
	if body.Results[3].Status != http.StatusOK || body.Results[3].User == nil || body.Results[3].User.Username != "batch_viewer" {
		t.Fatalf("result[3] (deduplicated) = %+v, want batch_viewer", body.Results[3])
	}
	if body.Results[4].Status != http.StatusOK || body.Results[4].Progression == nil {
		t.Fatalf("result[4] = %+v, want progression", body.Results[4])
	}

	canceledCtx, cancel := context.WithCancel(viewerCtx)
	cancel()
	canceledResp, err := batch.BatchRead(canceledCtx, genserver.BatchReadRequest{
		Requests: []genserver.BatchReadItem{
			{Kind: "user", Id: viewer.UserID.String()},
			{Kind: "user", Id: other.UserID.String()},
		},
	})
	if err != nil {
		t.Fatalf("canceled BatchRead returned unexpected error: %v", err)
	}
	if canceledResp.Code == http.StatusOK {
		t.Fatalf("canceled BatchRead status = %d, want non-200 error status", canceledResp.Code)
	}
}
