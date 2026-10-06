package db

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	dbgen "github.com/lrprojects/monaserver/internal/gen/db"
)

type GroupAchievementDef struct {
	ID                     int32
	Track                  string
	Name                   string
	Description            string
	Difficulty             string
	Threshold              int32
	ContributorMinimumPins int32
	RewardType             string
	RewardXP               int32
	RewardColor            string
	RewardPinStyle         string
}

var groupAchievementDefs = []GroupAchievementDef{
	{
		ID: 1, Track: "active_pins", Name: "Gatherer", Description: "Add 40 active sticks to this group.",
		Difficulty: "easy", Threshold: 40, RewardType: "xp", RewardXP: 50,
	},
	{
		ID: 2, Track: "active_pins", Name: "Landmark", Description: "Add 100 active sticks to this group.",
		Difficulty: "medium", Threshold: 100, RewardType: "color", RewardColor: "#D57B50", RewardPinStyle: "sunset",
	},
	{
		ID: 3, Track: "active_pins", Name: "Mapmaker", Description: "Add 200 active sticks to this group.",
		Difficulty: "hard", Threshold: 200, RewardType: "badge", RewardPinStyle: "aurora",
	},
	{
		ID: 4, Track: "active_pins", Name: "Spark", Description: "Add 2 active sticks to this group.",
		Difficulty: "easy", Threshold: 2, RewardType: "xp", RewardXP: 10,
	},
	{
		ID: 5, Track: "active_pins", Name: "Pioneer", Description: "Add 400 active sticks to this group.",
		Difficulty: "hard", Threshold: 400, RewardType: "badge", RewardPinStyle: "honey",
	},
	{
		ID: 6, Track: "active_pins", Name: "Epic", Description: "Add 1,000 active sticks to this group.",
		Difficulty: "hard", Threshold: 1000, RewardType: "badge", RewardPinStyle: "orchid",
	},
	{
		ID: 7, Track: "contributors", Name: "Teamwork", Description: "Have 2 people each add at least 1 stick.",
		Difficulty: "easy", Threshold: 2, ContributorMinimumPins: 1, RewardType: "xp", RewardXP: 50,
	},
	{
		ID: 8, Track: "contributors", Name: "Network", Description: "Have 20 people each add at least 3 sticks.",
		Difficulty: "medium", Threshold: 20, ContributorMinimumPins: 3, RewardType: "color", RewardColor: "#388E67", RewardPinStyle: "jade",
	},
	{
		ID: 9, Track: "contributors", Name: "Mosaic", Description: "Have 60 people each add at least 5 sticks.",
		Difficulty: "hard", Threshold: 60, ContributorMinimumPins: 5, RewardType: "badge", RewardPinStyle: "ember",
	},
	{
		ID: 10, Track: "members", Name: "Host", Description: "Grow this group to 10 active members.",
		Difficulty: "easy", Threshold: 10, RewardType: "xp", RewardXP: 50,
	},
	{
		ID: 11, Track: "members", Name: "Circle", Description: "Grow this group to 60 active members.",
		Difficulty: "medium", Threshold: 60, RewardType: "color", RewardColor: "#C35C84", RewardPinStyle: "rose",
	},
	{
		ID: 12, Track: "members", Name: "Society", Description: "Grow this group to 200 active members.",
		Difficulty: "hard", Threshold: 200, RewardType: "badge", RewardPinStyle: "midnight",
	},
	{
		ID: 13, Track: "photo_updates", Name: "Refresher", Description: "Add 2 photo updates to this group.",
		Difficulty: "easy", Threshold: 2, RewardType: "xp", RewardXP: 50,
	},
	{
		ID: 14, Track: "photo_updates", Name: "Chroniclers", Description: "Add 20 photo updates to this group.",
		Difficulty: "medium", Threshold: 20, RewardType: "color", RewardColor: "#77A88A", RewardPinStyle: "seafoam",
	},
	{
		ID: 15, Track: "photo_updates", Name: "Archivists", Description: "Add 100 photo updates to this group.",
		Difficulty: "hard", Threshold: 100, RewardType: "badge", RewardPinStyle: "glacier",
	},
	{
		ID: 16, Track: "gone_pins", Name: "Spotter", Description: "Mark 1 stick in this group as gone.",
		Difficulty: "easy", Threshold: 1, RewardType: "xp", RewardXP: 50,
	},
	{
		ID: 17, Track: "gone_pins", Name: "Caretakers", Description: "Mark 10 sticks in this group as gone.",
		Difficulty: "medium", Threshold: 10, RewardType: "color", RewardColor: "#BD8054", RewardPinStyle: "copper",
	},
	{
		ID: 18, Track: "gone_pins", Name: "Stewards", Description: "Mark 50 sticks in this group as gone.",
		Difficulty: "hard", Threshold: 50, RewardType: "badge", RewardPinStyle: "moss",
	},
}

var groupPinStyleOrder = []string{
	"classic", "moss", "sunset", "aurora", "seafoam", "honey", "orchid",
	"copper", "jade", "ember", "glacier", "rose", "midnight",
}

func GroupPinStyles() []string {
	return append([]string(nil), groupPinStyleOrder...)
}

func GroupAchievementDefinition(id int32) (GroupAchievementDef, bool) {
	for _, def := range groupAchievementDefs {
		if def.ID == id {
			return def, true
		}
	}
	return GroupAchievementDef{}, false
}

func ValidGroupPinStyle(style string) bool {
	for _, candidate := range groupPinStyleOrder {
		if candidate == style {
			return true
		}
	}
	return false
}

type GroupAchievementProgress struct {
	ID             int32
	Track          string
	Name           string
	Description    string
	Difficulty     string
	CurrentValue   int32
	Threshold      int32
	RewardType     string
	RewardXP       int32
	RewardColor    string
	Claimed        bool
	Claimable      bool
	RewardPinStyle string
}

func (q *Queries) GetGroupAchievementProgress(ctx context.Context, groupID uuid.UUID) ([]GroupAchievementProgress, error) {
	metrics, err := q.g.GetGroupAchievementMetrics(ctx, pgUUID(groupID))
	if err != nil {
		return nil, err
	}
	claimed, err := q.g.ListGroupAchievementClaims(ctx, pgUUID(groupID))
	if err != nil {
		return nil, err
	}
	claimedSet := make(map[int32]bool, len(claimed))
	for _, id := range claimed {
		claimedSet[id] = true
	}

	progress := make([]GroupAchievementProgress, 0, len(groupAchievementDefs))
	for _, def := range groupAchievementDefs {
		isClaimed := claimedSet[def.ID]
		current := groupMetricValue(metrics, def)
		progress = append(progress, GroupAchievementProgress{
			ID:             def.ID,
			Track:          def.Track,
			Name:           def.Name,
			Description:    def.Description,
			Difficulty:     def.Difficulty,
			CurrentValue:   current,
			Threshold:      def.Threshold,
			RewardType:     def.RewardType,
			RewardXP:       def.RewardXP,
			RewardColor:    def.RewardColor,
			Claimed:        isClaimed,
			Claimable:      !isClaimed && current >= def.Threshold,
			RewardPinStyle: def.RewardPinStyle,
		})
	}
	return progress, nil
}

func groupMetricValue(metrics dbgen.GetGroupAchievementMetricsRow, def GroupAchievementDef) int32 {
	switch def.Track {
	case "active_pins":
		return metrics.ActivePins
	case "contributors":
		switch def.ContributorMinimumPins {
		case 3:
			return metrics.ContributorsThreePins
		case 5:
			return metrics.ContributorsFivePins
		default:
			return metrics.Contributors
		}
	case "members":
		return metrics.Members
	case "photo_updates":
		return metrics.PhotoUpdates
	case "gone_pins":
		return metrics.GonePins
	default:
		return 0
	}
}

func (q *Queries) ClaimGroupAchievementReward(ctx context.Context, groupID, memberID uuid.UUID, achievementID int32) (bool, error) {
	def, ok := GroupAchievementDefinition(achievementID)
	if !ok {
		return false, nil
	}

	claimed := false
	err := q.InTx(ctx, func(tx *Queries) error {
		rows, err := tx.g.ClaimGroupAchievement(ctx, dbgen.ClaimGroupAchievementParams{
			GroupID:                pgUUID(groupID),
			AchievementID:          achievementID,
			ClaimedBy:              pgUUID(memberID),
			Track:                  def.Track,
			Threshold:              def.Threshold,
			ContributorMinimumPins: def.ContributorMinimumPins,
		})
		if err != nil {
			return err
		}
		if rows == 0 {
			return nil
		}
		if def.RewardType == "color" || def.RewardType == "badge" {
			if err := tx.g.UnlockGroupPinStyle(ctx, dbgen.UnlockGroupPinStyleParams{
				GroupID:       pgUUID(groupID),
				PinStyle:      def.RewardPinStyle,
				AchievementID: achievementID,
			}); err != nil {
				return err
			}
		}
		if def.RewardType == "xp" {
			if err := tx.AwardGroupXP(ctx, groupID, fmt.Sprintf("achievement:%d", def.ID), def.RewardXP); err != nil {
				return err
			}
		}
		claimed = true
		return nil
	})
	return claimed, err
}

func (q *Queries) IsGroupPinStyleUnlocked(ctx context.Context, groupID uuid.UUID, style string) (bool, error) {
	if style == "classic" {
		return true, nil
	}
	return q.g.IsGroupPinStyleUnlocked(ctx, dbgen.IsGroupPinStyleUnlockedParams{
		GroupID:  pgUUID(groupID),
		PinStyle: style,
	})
}

func (q *Queries) ListGroupAchievementClaims(ctx context.Context, groupID uuid.UUID) ([]int32, error) {
	return q.g.ListGroupAchievementClaims(ctx, pgUUID(groupID))
}
