package db

import (
	"context"
	"sort"
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
		"updates": {
			1:  {difficulty: "easy", rewardXP: 20},
			10: {difficulty: "medium", rewardXP: 0},
			50: {difficulty: "hard", rewardXP: 0},
		},
		"gone_pins": {
			1:  {difficulty: "easy", rewardXP: 20},
			10: {difficulty: "medium", rewardXP: 0},
			50: {difficulty: "hard", rewardXP: 0},
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
	if len(achievementDefs) != 29 {
		t.Errorf("active achievement count = %d, want 29", len(achievementDefs))
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

func TestAchievementNamesAreSingleWordAndDifficultyMatchesTrackProgress(t *testing.T) {
	rank := map[string]int{"easy": 1, "medium": 2, "hard": 3}
	reward := map[string]string{"easy": "xp", "medium": "color", "hard": "badge"}
	type milestone struct {
		threshold  int32
		difficulty string
	}
	tracks := make(map[string][]milestone)

	for _, def := range achievementDefs {
		if len(strings.Fields(def.Name)) != 1 {
			t.Errorf("personal achievement %d name %q must be one word", def.ID, def.Name)
		}
		if want, ok := reward[def.Difficulty]; !ok || achievementReward(def).Type != want {
			t.Errorf("personal achievement %d has difficulty %q and reward %q", def.ID, def.Difficulty, achievementReward(def).Type)
		}
		track := "personal/" + def.Track
		tracks[track] = append(tracks[track], milestone{threshold: def.Threshold, difficulty: def.Difficulty})
	}

	for _, def := range groupAchievementDefs {
		if len(strings.Fields(def.Name)) != 1 {
			t.Errorf("group achievement %d name %q must be one word", def.ID, def.Name)
		}
		if want, ok := reward[def.Difficulty]; !ok || def.RewardType != want {
			t.Errorf("group achievement %d has difficulty %q and reward %q", def.ID, def.Difficulty, def.RewardType)
		}
		track := "group/" + def.Track
		tracks[track] = append(tracks[track], milestone{threshold: def.Threshold, difficulty: def.Difficulty})
	}

	for track, milestones := range tracks {
		sort.Slice(milestones, func(i, j int) bool {
			return milestones[i].threshold < milestones[j].threshold
		})
		lastRank := 0
		for _, milestone := range milestones {
			currentRank, ok := rank[milestone.difficulty]
			if !ok {
				t.Errorf("%s has unknown difficulty %q", track, milestone.difficulty)
				continue
			}
			if currentRank < lastRank {
				t.Errorf("%s difficulty drops at threshold %d: %q", track, milestone.threshold, milestone.difficulty)
			}
			lastRank = currentRank
		}
	}
}

func TestPhotoUpdateAndGonePinMilestonesReachTheLegendaryRewardTier(t *testing.T) {
	want := map[int32]struct {
		track       string
		threshold   int32
		difficulty  string
		rewardType  string
		rewardXP    int32
		rewardColor string
	}{
		24: {track: "updates", threshold: 1, difficulty: "easy", rewardType: "xp", rewardXP: 20},
		25: {track: "updates", threshold: 10, difficulty: "medium", rewardType: "color", rewardColor: "#FF00897B"},
		26: {track: "updates", threshold: 50, difficulty: "hard", rewardType: "badge"},
		27: {track: "gone_pins", threshold: 1, difficulty: "easy", rewardType: "xp", rewardXP: 20},
		28: {track: "gone_pins", threshold: 10, difficulty: "medium", rewardType: "color", rewardColor: "#FF795548"},
		29: {track: "gone_pins", threshold: 50, difficulty: "hard", rewardType: "badge"},
	}

	for id, expected := range want {
		def, ok := achievementDefinition(id)
		if !ok {
			t.Errorf("achievement %d is missing", id)
			continue
		}
		reward := achievementReward(def)
		gotColor := ""
		if reward.Color != nil {
			gotColor = *reward.Color
		}
		if def.Track != expected.track || def.Threshold != expected.threshold ||
			def.Difficulty != expected.difficulty || reward.Type != expected.rewardType ||
			def.RewardXP != expected.rewardXP || gotColor != expected.rewardColor {
			t.Errorf("achievement %d = (%s, %d, %s, %s, %d, %s), want (%s, %d, %s, %s, %d, %s)",
				id, def.Track, def.Threshold, def.Difficulty, reward.Type, def.RewardXP, gotColor,
				expected.track, expected.threshold, expected.difficulty, expected.rewardType, expected.rewardXP, expected.rewardColor)
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

func TestLikeAchievementQueriesCountOnlyNormalLikes(t *testing.T) {
	for _, def := range achievementDefs {
		if def.Track != "likes_given" && def.Track != "likes_received" {
			continue
		}
		if !strings.Contains(def.sql, "l.like_all=TRUE") {
			t.Errorf("achievement %d does not count normal likes", def.ID)
		}
		for _, oldType := range []string{"like_location", "like_photography", "like_art"} {
			if strings.Contains(def.sql, oldType) {
				t.Errorf("achievement %d still counts obsolete %s likes", def.ID, oldType)
			}
		}
	}
}

func TestPublicAchievementProgressIncludesOnlyClaimedDefinitions(t *testing.T) {
	got := publicAchievementProgress([]int32{3, 999})
	if len(got) != 1 {
		t.Fatalf("public achievements = %d, want 1", len(got))
	}
	item := got[0]
	if item.ID != 3 || item.Name != "Creator" || !item.Claimed || item.CurrentValue != item.Threshold || item.Threshold != 2 {
		t.Fatalf("public achievement = %+v, want earned Creator with completed threshold", item)
	}
	if item.RewardXP != 0 || item.RewardType != "" || item.Claimable || item.RewardAvailable || item.DefinitionVersion != 0 {
		t.Fatalf("public achievement exposes reward metadata: %+v", item)
	}
}

func TestGetClaimedAchievementProgressHidesRevokedClaims(t *testing.T) {
	q, cleanup := t02Database(t)
	defer cleanup()
	ctx := context.Background()
	userID := uuid.New()
	if _, err := q.Pool().Exec(ctx, `
		INSERT INTO users (id, username, password, email_confirmed, creation_date, update_date)
		VALUES ($1, 'revoked_public_claim_user', 'hash', FALSE, NOW(), NOW())`, userID); err != nil {
		t.Fatalf("insert user: %v", err)
	}
	if _, err := q.Pool().Exec(ctx, `
		INSERT INTO user_achievement (id, user_id, achievement_id, claimed, creation_date, update_date)
		VALUES ($1, $2, 3, TRUE, NOW(), NOW())`, uuid.New(), userID); err != nil {
		t.Fatalf("insert revoked achievement claim: %v", err)
	}

	got, err := q.GetClaimedAchievementProgress(ctx, userID)
	if err != nil {
		t.Fatalf("get current public achievements: %v", err)
	}
	if len(got) != 0 {
		t.Fatalf("public achievements = %+v, want stale Creator claim hidden", got)
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
	cleanupSQL := strings.SplitN(string(migration), "$function$;", 2)
	if len(cleanupSQL) != 2 {
		t.Fatal("contribution migration is missing its function terminator")
	}
	// The current function was installed by the full migration chain. Reapply
	// only the data cleanup statements because the historical function body
	// references like-type columns removed by a later migration.
	if _, err := q.Pool().Exec(ctx, cleanupSQL[1]); err != nil {
		t.Fatalf("apply contribution data cleanup: %v", err)
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
