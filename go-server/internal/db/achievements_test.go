package db

import (
	"context"
	"strings"
	"testing"

	"github.com/google/uuid"
)

func TestAchievementCatalogHasTieredMilestonesForEveryPersonalTrack(t *testing.T) {
	type milestone struct {
		difficulty string
		rewardXP   int32
	}
	want := map[string]map[int32]milestone{
		"sticks": {
			2:   {difficulty: "easy", rewardXP: 20},
			40:  {difficulty: "medium", rewardXP: 0},
			200: {difficulty: "hard", rewardXP: 0},
			400: {difficulty: "hard", rewardXP: 0},
		},
		"places": {
			2:  {difficulty: "easy", rewardXP: 20},
			10: {difficulty: "medium", rewardXP: 0},
			25: {difficulty: "hard", rewardXP: 0},
			50: {difficulty: "hard", rewardXP: 0},
		},
		"groups": {
			2: {difficulty: "easy", rewardXP: 20},
			5: {difficulty: "medium", rewardXP: 0},
		},
		"contributing_groups": {
			3:  {difficulty: "medium", rewardXP: 0},
			10: {difficulty: "hard", rewardXP: 0},
		},
		"likes_given": {
			20:   {difficulty: "easy", rewardXP: 20},
			200:  {difficulty: "medium", rewardXP: 0},
			400:  {difficulty: "hard", rewardXP: 0},
			1000: {difficulty: "hard", rewardXP: 0},
		},
		"likes_received": {
			20:   {difficulty: "easy", rewardXP: 20},
			200:  {difficulty: "medium", rewardXP: 0},
			400:  {difficulty: "hard", rewardXP: 0},
			1000: {difficulty: "hard", rewardXP: 0},
		},
		"photos": {
			2:   {difficulty: "easy", rewardXP: 20},
			40:  {difficulty: "medium", rewardXP: 0},
			200: {difficulty: "hard", rewardXP: 0},
		},
	}
	got := make(map[string]map[int32]milestone)
	ids := make(map[int32]bool, len(achievementDefs))
	for _, def := range achievementDefs {
		if ids[def.ID] {
			t.Errorf("duplicate achievement ID %d", def.ID)
		}
		ids[def.ID] = true
		if def.Name == "" || def.Description == "" || def.DefinitionVersion != userAchievementDefinitionVersion {
			t.Errorf("achievement %d is missing versioned display metadata: %+v", def.ID, def)
		}
		if !def.ThresholdUp {
			t.Errorf("achievement %d must use an increasing milestone", def.ID)
		}
		if got[def.Track] == nil {
			got[def.Track] = make(map[int32]milestone)
		}
		got[def.Track][def.Threshold] = milestone{difficulty: def.Difficulty, rewardXP: def.RewardXP}
	}
	if len(achievementDefs) != 23 {
		t.Errorf("active achievement count = %d, want 23", len(achievementDefs))
	}
	if len(got) != len(want) {
		t.Fatalf("track count = %d, want %d (%v)", len(got), len(want), got)
	}
	for track, milestones := range want {
		if len(got[track]) != len(milestones) {
			t.Errorf("%s milestones = %v, want %v", track, got[track], milestones)
			continue
		}
		for threshold, expected := range milestones {
			if actual, ok := got[track][threshold]; !ok || actual != expected {
				t.Errorf("%s threshold %d = %+v, present=%t; want %+v", track, threshold, actual, ok, expected)
			}
		}
	}
}

func TestContributionMilestonesCountGroupsWithPins(t *testing.T) {
	for _, tc := range []struct {
		id, threshold int32
	}{
		{13, 3}, {21, 10},
	} {
		def, ok := achievementDefinition(tc.id)
		if !ok || def.Track != "contributing_groups" || def.Threshold != tc.threshold {
			t.Fatalf("achievement %d = %+v, present %t", tc.id, def, ok)
		}
		if def.sql == "" || !containsAll(def.sql, "pins", "group_id", "creator_id", "is_deleted") {
			t.Errorf("achievement %d does not count contributed groups", tc.id)
		}
	}
}

func containsAll(s string, words ...string) bool {
	for _, word := range words {
		if !strings.Contains(s, word) {
			return false
		}
	}
	return true
}

func TestLegacyGroupJoinRewardDoesNotCompleteContributionGoal(t *testing.T) {
	q, cleanup := t02Database(t)
	defer cleanup()
	ctx := context.Background()
	userID := uuid.New()
	if _, err := q.Pool().Exec(ctx, `
		INSERT INTO users (id, username, password, email_confirmed, creation_date, update_date)
		VALUES ($1, 'legacy_group_claim_user', 'hash', FALSE, NOW(), NOW())`, userID); err != nil {
		t.Fatalf("insert user: %v", err)
	}
	for _, id := range []int32{13, 21} {
		if _, err := q.Pool().Exec(ctx, `
			INSERT INTO user_achievement_reward_ledger
			(user_id, achievement_id, xp_awarded, definition_version, awarded_at)
			VALUES ($1, $2, 0, 6, NOW())`, userID, id); err != nil {
			t.Fatalf("seed legacy reward %d: %v", id, err)
		}
		var current bool
		if err := q.Pool().QueryRow(ctx,
			`SELECT user_achievement_is_current($1, $2)`, userID, id,
		).Scan(&current); err != nil {
			t.Fatalf("check legacy reward %d: %v", id, err)
		}
		if current {
			t.Errorf("legacy joining reward %d completed a contribution goal", id)
		}
	}
}

func TestContributionMigrationRevokesLegacySelectionWithoutPins(t *testing.T) {
	q, cleanup := t02Database(t)
	defer cleanup()
	ctx := context.Background()
	userID := uuid.New()
	badgeRowID := uuid.New()
	colorRowID := uuid.New()
	if _, err := q.Pool().Exec(ctx, `
		INSERT INTO users (id, username, password, email_confirmed, creation_date, update_date, selected_batch, selected_batch_color)
		VALUES ($1, 'legacy_group_selection_user', 'hash', FALSE, NOW(), NOW(), NULL, '#FFC2185B')`, userID); err != nil {
		t.Fatalf("insert user: %v", err)
	}
	if _, err := q.Pool().Exec(ctx, `
		INSERT INTO user_achievement (id, user_id, achievement_id, claimed, creation_date, update_date)
		VALUES ($1, $3, 13, TRUE, NOW(), NOW()), ($2, $3, 21, TRUE, NOW(), NOW())`, colorRowID, badgeRowID, userID); err != nil {
		t.Fatalf("insert legacy claims: %v", err)
	}
	if _, err := q.Pool().Exec(ctx, `UPDATE users SET selected_batch = $2 WHERE id = $1`, userID, badgeRowID); err != nil {
		t.Fatalf("select legacy badge: %v", err)
	}
	migration, err := migrationsFS.ReadFile("migrations/000061_contributing_group_achievements.up.sql")
	if err != nil {
		t.Fatalf("read contribution migration: %v", err)
	}
	if _, err := q.Pool().Exec(ctx, string(migration)); err != nil {
		t.Fatalf("reapply contribution migration: %v", err)
	}
	var badgeCleared, colorCleared bool
	if err := q.Pool().QueryRow(ctx, `
		SELECT selected_batch IS NULL, selected_batch_color = 'default' FROM users WHERE id = $1`, userID,
	).Scan(&badgeCleared, &colorCleared); err != nil {
		t.Fatalf("read cleared selection: %v", err)
	}
	if !badgeCleared || !colorCleared {
		t.Fatalf("legacy selection after migration: badgeCleared=%t colorCleared=%t", badgeCleared, colorCleared)
	}
	var claimed int
	if err := q.Pool().QueryRow(ctx, `
		SELECT COUNT(*) FROM user_achievement
		WHERE user_id = $1 AND achievement_id IN (13, 21) AND claimed = TRUE`, userID,
	).Scan(&claimed); err != nil {
		t.Fatalf("count remaining claims: %v", err)
	}
	if claimed != 0 {
		t.Fatalf("legacy contribution claims still active: %d", claimed)
	}
}
