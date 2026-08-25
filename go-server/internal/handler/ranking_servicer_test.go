package handler

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	genserver "github.com/lrprojects/monaserver/internal/gen/server"
	"github.com/lrprojects/monaserver/internal/service"
)

func TestUserRankingIncludesSelectedAchievement(t *testing.T) {
	authHandler, auth := setupAuthServicer(t)
	q := authHandler.q
	userSvc := service.NewUser(q, nil, nil, auth, nil)
	groupSvc := service.NewGroup(q, nil, userSvc)
	pinSvc := service.NewPin(q, nil)
	servicer := NewRankingServicer(service.NewRanking(q))
	ctx := context.Background()
	boundaryID := uuid.New()
	if _, err := q.Pool().Exec(ctx, `
		INSERT INTO admin2_boundaries (id, gid_0, name_0, gid_1, name_1, gid_2, name_2, geom)
		VALUES ($1, 'TST', 'Test', 'TST.1', 'Test One', 'TST.1.1', 'Test Two',
		        ST_GeomFromText('MULTIPOLYGON(((0 0, 0 3, 3 3, 3 0, 0 0)))', 4326))`, boundaryID,
	); err != nil {
		t.Fatalf("insert boundary: %v", err)
	}
	t.Cleanup(func() {
		_, _ = q.Pool().Exec(context.Background(), `DELETE FROM admin2_boundaries WHERE id = $1`, boundaryID)
	})

	user, err := auth.Signup(ctx, "ranking_badge_user", "password123", nil)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}
	group, err := groupSvc.Create(ctx, service.CreateGroupInput{
		Name: "ranking_badge_group", Visibility: 0, GroupAdmin: user.UserID,
	})
	if err != nil {
		t.Fatalf("create group: %v", err)
	}
	if _, err := pinSvc.Create(ctx, service.CreatePinInput{
		Latitude: 1, Longitude: 1, CreationDate: time.Now(), UserID: user.UserID, GroupID: group.ID,
	}); err != nil {
		t.Fatalf("create pin: %v", err)
	}
	if err := userSvc.ClaimAchievement(ctx, user.UserID, 4); err != nil {
		t.Fatalf("claim achievement: %v", err)
	}
	rowID, err := q.GetUserAchievementRow(ctx, user.UserID, 4)
	if err != nil || rowID == nil {
		t.Fatalf("get achievement row: %v", err)
	}
	if err := q.SetUserSelectedBatch(ctx, user.UserID, *rowID); err != nil {
		t.Fatalf("select achievement: %v", err)
	}

	resp, err := servicer.UserRanking(ctx, "", "", "", time.Time{}, false, 0, 20)
	if err != nil {
		t.Fatalf("user ranking: %v", err)
	}
	items, ok := resp.Body.([]genserver.UserRankingDtoInner)
	if !ok {
		t.Fatalf("response body type = %T", resp.Body)
	}
	if len(items) != 1 || items[0].UserInfoDto.SelectedBatch == nil || *items[0].UserInfoDto.SelectedBatch != 4 {
		t.Fatalf("ranking response = %+v, want selectedBatch 4", items)
	}
}
