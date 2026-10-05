package db

import "testing"

func TestGroupAchievementCatalogTracksPhotoUpdatesAndGonePins(t *testing.T) {
	want := map[string]map[int32]bool{
		"active_pins":   {2: true, 40: true, 100: true, 200: true, 400: true, 1000: true},
		"contributors":  {2: true, 20: true, 60: true},
		"members":       {10: true, 60: true, 200: true},
		"photo_updates": {2: true, 20: true, 100: true},
		"gone_pins":     {1: true, 10: true, 50: true},
	}
	got := make(map[string]map[int32]bool)
	ids := make(map[int32]bool, len(groupAchievementDefs))
	for _, def := range groupAchievementDefs {
		if ids[def.ID] {
			t.Errorf("duplicate group achievement ID %d", def.ID)
		}
		ids[def.ID] = true
		if def.Name == "" || def.Description == "" {
			t.Errorf("group achievement %d has empty display metadata", def.ID)
		}
		if got[def.Track] == nil {
			got[def.Track] = make(map[int32]bool)
		}
		got[def.Track][def.Threshold] = true
	}
	if len(groupAchievementDefs) != 18 {
		t.Errorf("active group achievement count = %d, want 18", len(groupAchievementDefs))
	}
	if len(got) != len(want) {
		t.Fatalf("track count = %d, want %d (%v)", len(got), len(want), got)
	}
	for track, thresholds := range want {
		if len(got[track]) != len(thresholds) {
			t.Errorf("%s thresholds = %v, want %v", track, got[track], thresholds)
			continue
		}
		for threshold := range thresholds {
			if !got[track][threshold] {
				t.Errorf("%s is missing threshold %d", track, threshold)
			}
		}
	}
}

func TestNewGroupAchievementRewardsMatchTheDifficultyLadder(t *testing.T) {
	want := map[int32]struct {
		track       string
		difficulty  string
		rewardType  string
		rewardXP    int32
		rewardColor string
		pinStyle    string
	}{
		13: {track: "photo_updates", difficulty: "easy", rewardType: "xp", rewardXP: 50},
		14: {track: "photo_updates", difficulty: "medium", rewardType: "color", rewardColor: "#77A88A", pinStyle: "seafoam"},
		15: {track: "photo_updates", difficulty: "hard", rewardType: "badge", pinStyle: "glacier"},
		16: {track: "gone_pins", difficulty: "easy", rewardType: "xp", rewardXP: 50},
		17: {track: "gone_pins", difficulty: "medium", rewardType: "color", rewardColor: "#BD8054", pinStyle: "copper"},
		18: {track: "gone_pins", difficulty: "hard", rewardType: "badge", pinStyle: "moss"},
	}

	for _, def := range groupAchievementDefs {
		expected, ok := want[def.ID]
		if !ok {
			continue
		}
		if def.Track != expected.track || def.Difficulty != expected.difficulty ||
			def.RewardType != expected.rewardType || def.RewardXP != expected.rewardXP ||
			def.RewardColor != expected.rewardColor || def.RewardPinStyle != expected.pinStyle {
			t.Errorf("group achievement %d reward = (%s, %s, %s, %d, %s, %s), want (%s, %s, %s, %d, %s, %s)",
				def.ID, def.Track, def.Difficulty, def.RewardType, def.RewardXP, def.RewardColor, def.RewardPinStyle,
				expected.track, expected.difficulty, expected.rewardType, expected.rewardXP, expected.rewardColor, expected.pinStyle)
		}
		if def.Difficulty != "easy" && def.RewardPinStyle == "" {
			t.Errorf("group achievement %d is missing its pin appearance reward", def.ID)
		}
	}
}
