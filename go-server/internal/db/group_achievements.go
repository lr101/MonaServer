package db

import (
	"context"

	"github.com/google/uuid"
	dbgen "github.com/lrprojects/monaserver/internal/gen/db"
)

type GroupAchievementDef struct {
	ID             int32
	Name           string
	Description    string
	Difficulty     string
	Threshold      int32
	RewardPinStyle string
}

var groupAchievementDefs = []GroupAchievementDef{
	{
		ID: 1, Name: "First gathering", Description: "Add 10 active sticks to this group.",
		Difficulty: "easy", Threshold: 10, RewardPinStyle: "moss",
	},
	{
		ID: 2, Name: "Local landmark", Description: "Add 25 active sticks to this group.",
		Difficulty: "medium", Threshold: 25, RewardPinStyle: "sunset",
	},
	{
		ID: 3, Name: "Mapmaker crew", Description: "Add 50 active sticks to this group.",
		Difficulty: "hard", Threshold: 50, RewardPinStyle: "aurora",
	},
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
	switch style {
	case "classic", "moss", "sunset", "aurora":
		return true
	default:
		return false
	}
}

type GroupAchievementProgress struct {
	ID             int32
	Name           string
	Description    string
	Difficulty     string
	CurrentValue   int32
	Threshold      int32
	Claimed        bool
	Claimable      bool
	RewardPinStyle string
}

func (q *Queries) GetGroupAchievementProgress(ctx context.Context, groupID uuid.UUID) ([]GroupAchievementProgress, error) {
	current, err := q.g.GetGroupPinCount(ctx, pgUUID(groupID))
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
		progress = append(progress, GroupAchievementProgress{
			ID:             def.ID,
			Name:           def.Name,
			Description:    def.Description,
			Difficulty:     def.Difficulty,
			CurrentValue:   current,
			Threshold:      def.Threshold,
			Claimed:        isClaimed,
			Claimable:      !isClaimed && current >= def.Threshold,
			RewardPinStyle: def.RewardPinStyle,
		})
	}
	return progress, nil
}

func (q *Queries) ClaimGroupAchievementReward(ctx context.Context, groupID, memberID uuid.UUID, achievementID int32) (bool, error) {
	def, ok := GroupAchievementDefinition(achievementID)
	if !ok {
		return false, nil
	}

	claimed := false
	err := q.InTx(ctx, func(tx *Queries) error {
		rows, err := tx.g.ClaimGroupAchievement(ctx, dbgen.ClaimGroupAchievementParams{
			GroupID:       pgUUID(groupID),
			AchievementID: achievementID,
			ClaimedBy:     pgUUID(memberID),
			Threshold:     def.Threshold,
		})
		if err != nil {
			return err
		}
		if rows == 0 {
			return nil
		}
		if err := tx.g.UnlockGroupPinStyle(ctx, dbgen.UnlockGroupPinStyleParams{
			GroupID:       pgUUID(groupID),
			PinStyle:      def.RewardPinStyle,
			AchievementID: achievementID,
		}); err != nil {
			return err
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
