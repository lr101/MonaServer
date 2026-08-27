package service

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
)

func TestSeasonCreationSnapshotsCompleteRankings(t *testing.T) {
	q, auth, _, _, pin, group, _, _, _ := setupServices(t)
	ctx := context.Background()
	boundaryID := uuid.New()
	if _, err := q.Pool().Exec(ctx, `
		INSERT INTO admin2_boundaries (id, gid_0, name_0, gid_1, name_1, gid_2, name_2, geom)
		VALUES ($1, 'SEASON', 'Season', 'SEASON.1', 'Season One', 'SEASON.1.1', 'Season Two',
		        ST_GeomFromText('MULTIPOLYGON(((0 0, 0 20, 20 20, 20 0, 0 0)))', 4326))`, boundaryID,
	); err != nil {
		t.Fatalf("insert boundary: %v", err)
	}
	t.Cleanup(func() {
		_, _ = q.Pool().Exec(context.Background(), `DELETE FROM pins WHERE state_province_id = $1`, boundaryID)
		_, _ = q.Pool().Exec(context.Background(), `DELETE FROM admin2_boundaries WHERE id = $1`, boundaryID)
	})
	userID := createTestUser(t, auth, "season_snapshot_user")
	groupID := createTestGroup(t, group, userID, "season_snapshot_group")
	if _, err := pin.Create(ctx, CreatePinInput{
		Latitude: 5, Longitude: 5, CreationDate: time.Date(2026, 8, 10, 0, 0, 0, 0, time.UTC), UserID: userID, GroupID: groupID,
	}); err != nil {
		t.Fatalf("create pin: %v", err)
	}

	result, err := NewSeason(q).CreateMonth(ctx, time.Date(2026, 8, 31, 23, 59, 0, 0, time.UTC))
	if err != nil {
		t.Fatalf("create season: %v", err)
	}
	if result.Number != 1 || result.Users != 1 || result.Groups != 1 {
		t.Fatalf("season result = %+v", result)
	}
	userSeason, err := q.GetBestUserSeason(ctx, userID)
	if err != nil || userSeason == nil || userSeason.Points != 1 || userSeason.Rank != 1 {
		t.Fatalf("user season = %+v, err = %v", userSeason, err)
	}
	groupSeason, err := q.GetBestGroupSeason(ctx, groupID)
	if err != nil || groupSeason == nil || groupSeason.Points != 1 || groupSeason.Rank != 1 {
		t.Fatalf("group season = %+v, err = %v", groupSeason, err)
	}
}
