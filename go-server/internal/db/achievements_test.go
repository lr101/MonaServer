package db

import "testing"

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
			2:  {difficulty: "easy", rewardXP: 20},
			5:  {difficulty: "medium", rewardXP: 0},
			10: {difficulty: "medium", rewardXP: 0},
			25: {difficulty: "hard", rewardXP: 0},
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
