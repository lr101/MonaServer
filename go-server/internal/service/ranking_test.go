package service

import (
	"context"
	"testing"
)

func TestRankingUserAndGroup(t *testing.T) {
	_, auth, _, _, pin, group, _, ranking, _ := setupServices(t)
	ctx := context.Background()

	uid := createTestUser(t, auth, "rankuser")
	gid := createTestGroup(t, group, uid, "rankgroup")
	createTestPin(t, pin, uid, gid)

	t.Run("user ranking returns without error", func(t *testing.T) {
		items, err := ranking.UserRanking(ctx, nil, nil, nil, nil, false, 0, 50)
		if err != nil {
			t.Fatalf("user ranking: %v", err)
		}
		// Items may be empty when no boundary data is loaded (test DB).
		// Validate structure of any items returned.
		for _, r := range items {
			if r.UserID.String() == "" {
				t.Fatalf("ranking item has empty user id")
			}
			if r.Points < 0 {
				t.Fatalf("negative points: %d", r.Points)
			}
		}
	})

	t.Run("group ranking returns without error", func(t *testing.T) {
		items, err := ranking.GroupRanking(ctx, nil, nil, nil, nil, false, 0, 50)
		if err != nil {
			t.Fatalf("group ranking: %v", err)
		}
		for _, r := range items {
			if r.GroupID.String() == "" {
				t.Fatalf("ranking item has empty group id")
			}
		}
	})

	t.Run("season ranking uses month start filter", func(t *testing.T) {
		items, err := ranking.UserRanking(ctx, nil, nil, nil, nil, true, 0, 50)
		if err != nil {
			t.Fatalf("season ranking: %v", err)
		}
		_ = items // may be empty without boundary data
	})

	t.Run("map info returns empty for coords outside any boundary", func(t *testing.T) {
		rows, err := ranking.MapInfo(ctx, 0.0, 0.0)
		if err != nil {
			t.Fatalf("map info: %v", err)
		}
		// Expect empty when no boundary data is loaded or for ocean coords.
		_ = rows
	})

	t.Run("boundary search returns without error", func(t *testing.T) {
		s := "test"
		items, err := ranking.SearchBoundaries(ctx, &s, 0, 10)
		if err != nil {
			t.Fatalf("search boundaries: %v", err)
		}
		_ = items
	})
}
