package db

import "testing"

func TestAchievementCatalogHasTieredMilestonesForEveryPersonalTrack(t *testing.T) {
	type milestone struct {
		difficulty string
		rewardXP   int32
	}
	want := map[string]map[int32]milestone{
		"sticks": {
			1:  {difficulty: "easy", rewardXP: 20},
			10: {difficulty: "medium", rewardXP: 50},
			50: {difficulty: "hard", rewardXP: 100},
		},
		"places": {
			1:  {difficulty: "easy", rewardXP: 20},
			3:  {difficulty: "medium", rewardXP: 50},
			10: {difficulty: "hard", rewardXP: 100},
		},
		"groups": {
			1:  {difficulty: "easy", rewardXP: 20},
			3:  {difficulty: "medium", rewardXP: 50},
			10: {difficulty: "hard", rewardXP: 100},
		},
		"likes_given": {
			10:  {difficulty: "easy", rewardXP: 20},
			50:  {difficulty: "medium", rewardXP: 50},
			100: {difficulty: "hard", rewardXP: 100},
		},
		"likes_received": {
			10:  {difficulty: "easy", rewardXP: 20},
			50:  {difficulty: "medium", rewardXP: 50},
			100: {difficulty: "hard", rewardXP: 100},
		},
	}
	got := make(map[string]map[int32]milestone)
	ids := make(map[int32]bool, len(achievementDefs))
	for _, def := range achievementDefs {
		if ids[def.ID] {
			t.Errorf("duplicate achievement ID %d", def.ID)
		}
		ids[def.ID] = true
		if def.Name == "" || def.Description == "" || def.DefinitionVersion < 2 {
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
	if len(achievementDefs) != 15 {
		t.Errorf("active achievement count = %d, want 15", len(achievementDefs))
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
