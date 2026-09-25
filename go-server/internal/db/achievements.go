package db

import (
	"context"
	"time"

	"github.com/google/uuid"
	dbgen "github.com/lrprojects/monaserver/internal/gen/db"
)

const userAchievementDefinitionVersion int32 = 2

// AchievementDef is a server-owned personal milestone and reward.
type AchievementDef struct {
	ID                int32
	Name              string
	Description       string
	Track             string
	Difficulty        string
	RewardXP          int32
	DefinitionVersion int32
	Threshold         int32
	ThresholdUp       bool // true = currentValue >= threshold to claim
	sql               string
}

// AchievementConfig remains part of the handler construction API for callers
// that still provide the legacy achievement configuration.
type AchievementConfig struct {
	MonaGroupID   uuid.UUID
	CreatedBefore time.Time
}

var achievementDefs = []AchievementDef{
	{
		ID: 0, Name: "First place", Description: "Add a stick in your first place.",
		Track: "places", Difficulty: "easy", RewardXP: 20, DefinitionVersion: userAchievementDefinitionVersion,
		Threshold: 1, ThresholdUp: true,
		sql: `SELECT COUNT(DISTINCT state_province_id)::int FROM pins WHERE creator_id=$1 AND is_deleted=FALSE AND state_province_id IS NOT NULL`,
	},
	{
		ID: 2, Name: "First crew", Description: "Join your first group.",
		Track: "groups", Difficulty: "easy", RewardXP: 20, DefinitionVersion: userAchievementDefinitionVersion,
		Threshold: 1, ThresholdUp: true,
		sql: `SELECT COUNT(DISTINCT m.group_id)::int FROM members m JOIN groups g ON g.id=m.group_id WHERE m.user_id=$1 AND m.is_deleted=FALSE AND g.is_deleted=FALSE`,
	},
	{
		ID: 3, Name: "First stick", Description: "Add your first stick.",
		Track: "sticks", Difficulty: "easy", RewardXP: 20, DefinitionVersion: userAchievementDefinitionVersion,
		Threshold: 1, ThresholdUp: true,
		sql: `SELECT COUNT(*)::int FROM pins WHERE creator_id=$1 AND is_deleted=FALSE`,
	},
	{
		ID: 4, Name: "Team regular", Description: "Join three groups.",
		Track: "groups", Difficulty: "medium", RewardXP: 50, DefinitionVersion: userAchievementDefinitionVersion,
		Threshold: 3, ThresholdUp: true,
		sql: `SELECT COUNT(DISTINCT m.group_id)::int FROM members m JOIN groups g ON g.id=m.group_id WHERE m.user_id=$1 AND m.is_deleted=FALSE AND g.is_deleted=FALSE`,
	},
	{
		ID: 5, Name: "Supporter", Description: "Give likes to ten sticks from other people.",
		Track: "likes_given", Difficulty: "easy", RewardXP: 20, DefinitionVersion: userAchievementDefinitionVersion,
		Threshold: 10, ThresholdUp: true,
		sql: `SELECT COUNT(*)::int FROM likes l JOIN pins p ON p.id=l.pin_id WHERE l.user_id=$1 AND (l.like_all=TRUE OR l.like_location=TRUE OR l.like_photography=TRUE OR l.like_art=TRUE) AND p.creator_id<>l.user_id AND p.is_deleted=FALSE`,
	},
	{
		ID: 6, Name: "Getting noticed", Description: "Receive ten likes on your sticks.",
		Track: "likes_received", Difficulty: "easy", RewardXP: 20, DefinitionVersion: userAchievementDefinitionVersion,
		Threshold: 10, ThresholdUp: true,
		sql: `SELECT COUNT(*)::int FROM likes l JOIN pins p ON p.id=l.pin_id WHERE p.creator_id=$1 AND l.user_id<>p.creator_id AND (l.like_all=TRUE OR l.like_location=TRUE OR l.like_photography=TRUE OR l.like_art=TRUE) AND p.is_deleted=FALSE`,
	},
	{
		ID: 7, Name: "Super supporter", Description: "Give likes to fifty sticks from other people.",
		Track: "likes_given", Difficulty: "medium", RewardXP: 50, DefinitionVersion: userAchievementDefinitionVersion,
		Threshold: 50, ThresholdUp: true,
		sql: `SELECT COUNT(*)::int FROM likes l JOIN pins p ON p.id=l.pin_id WHERE l.user_id=$1 AND (l.like_all=TRUE OR l.like_location=TRUE OR l.like_photography=TRUE OR l.like_art=TRUE) AND p.creator_id<>l.user_id AND p.is_deleted=FALSE`,
	},
	{
		ID: 8, Name: "Fan favorite", Description: "Receive likes on fifty of your sticks.",
		Track: "likes_received", Difficulty: "medium", RewardXP: 50, DefinitionVersion: userAchievementDefinitionVersion,
		Threshold: 50, ThresholdUp: true,
		sql: `SELECT COUNT(*)::int FROM likes l JOIN pins p ON p.id=l.pin_id WHERE p.creator_id=$1 AND l.user_id<>p.creator_id AND (l.like_all=TRUE OR l.like_location=TRUE OR l.like_photography=TRUE OR l.like_art=TRUE) AND p.is_deleted=FALSE`,
	},
	{
		ID: 9, Name: "Stick collector", Description: "Add ten sticks.",
		Track: "sticks", Difficulty: "medium", RewardXP: 50, DefinitionVersion: userAchievementDefinitionVersion,
		Threshold: 10, ThresholdUp: true,
		sql: `SELECT COUNT(*)::int FROM pins WHERE creator_id=$1 AND is_deleted=FALSE`,
	},
	{
		ID: 10, Name: "Explorer", Description: "Add sticks in three different places.",
		Track: "places", Difficulty: "medium", RewardXP: 50, DefinitionVersion: userAchievementDefinitionVersion,
		Threshold: 3, ThresholdUp: true,
		sql: `SELECT COUNT(DISTINCT state_province_id)::int FROM pins WHERE creator_id=$1 AND is_deleted=FALSE AND state_province_id IS NOT NULL`,
	},
	{
		ID: 11, Name: "Wide-ranging explorer", Description: "Add sticks in ten different places.",
		Track: "places", Difficulty: "hard", RewardXP: 100, DefinitionVersion: userAchievementDefinitionVersion,
		Threshold: 10, ThresholdUp: true,
		sql: `SELECT COUNT(DISTINCT state_province_id)::int FROM pins WHERE creator_id=$1 AND is_deleted=FALSE AND state_province_id IS NOT NULL`,
	},
	{
		ID: 12, Name: "Dedicated collector", Description: "Add fifty sticks.",
		Track: "sticks", Difficulty: "hard", RewardXP: 100, DefinitionVersion: userAchievementDefinitionVersion,
		Threshold: 50, ThresholdUp: true,
		sql: `SELECT COUNT(*)::int FROM pins WHERE creator_id=$1 AND is_deleted=FALSE`,
	},
	{
		ID: 13, Name: "Community regular", Description: "Join ten groups.",
		Track: "groups", Difficulty: "hard", RewardXP: 100, DefinitionVersion: userAchievementDefinitionVersion,
		Threshold: 10, ThresholdUp: true,
		sql: `SELECT COUNT(DISTINCT m.group_id)::int FROM members m JOIN groups g ON g.id=m.group_id WHERE m.user_id=$1 AND m.is_deleted=FALSE AND g.is_deleted=FALSE`,
	},
	{
		ID: 14, Name: "Big supporter", Description: "Give likes to one hundred sticks from other people.",
		Track: "likes_given", Difficulty: "hard", RewardXP: 100, DefinitionVersion: userAchievementDefinitionVersion,
		Threshold: 100, ThresholdUp: true,
		sql: `SELECT COUNT(*)::int FROM likes l JOIN pins p ON p.id=l.pin_id WHERE l.user_id=$1 AND (l.like_all=TRUE OR l.like_location=TRUE OR l.like_photography=TRUE OR l.like_art=TRUE) AND p.creator_id<>l.user_id AND p.is_deleted=FALSE`,
	},
	{
		ID: 15, Name: "Community favorite", Description: "Receive likes on one hundred of your sticks.",
		Track: "likes_received", Difficulty: "hard", RewardXP: 100, DefinitionVersion: userAchievementDefinitionVersion,
		Threshold: 100, ThresholdUp: true,
		sql: `SELECT COUNT(*)::int FROM likes l JOIN pins p ON p.id=l.pin_id WHERE p.creator_id=$1 AND l.user_id<>p.creator_id AND (l.like_all=TRUE OR l.like_location=TRUE OR l.like_photography=TRUE OR l.like_art=TRUE) AND p.is_deleted=FALSE`,
	},
}

type AchievementProgress struct {
	ID                int32
	Name              string
	Description       string
	Track             string
	Difficulty        string
	RewardXP          int32
	DefinitionVersion int32
	CurrentValue      int32
	Threshold         int32
	ThresholdUp       bool
	Claimed           bool
	Claimable         bool
	RewardAvailable   bool
}

func (q *Queries) GetAchievementProgress(ctx context.Context, userID uuid.UUID, _ AchievementConfig) ([]AchievementProgress, error) {
	claimed, err := q.ListUserAchievements(ctx, userID)
	if err != nil {
		return nil, err
	}
	claimedSet := make(map[int32]bool, len(claimed))
	for _, c := range claimed {
		if c.Claimed {
			claimedSet[c.AchievementID] = true
		}
	}
	rewards, err := q.g.ListUserAchievementRewardAwards(ctx, pgUUID(userID))
	if err != nil {
		return nil, err
	}
	rewardedSet := make(map[int32]bool, len(rewards))
	for _, id := range rewards {
		rewardedSet[id] = true
	}

	type currentProgress struct {
		def   AchievementDef
		value int32
	}
	currents := make([]currentProgress, 0, len(achievementDefs))
	currentByTrack := make(map[string]int32, 5)
	qualifies := make(map[int32]bool, len(achievementDefs))
	for _, def := range achievementDefs {
		cur, ok := currentByTrack[def.Track]
		if !ok {
			value, err := q.runAchievementQuery(ctx, def, userID)
			if err != nil {
				return nil, err
			}
			cur = int32(value)
			currentByTrack[def.Track] = cur
		}
		qualifies[def.ID] = cur >= def.Threshold
		currents = append(currents, currentProgress{def: def, value: cur})
	}

	for _, c := range claimed {
		if !c.Claimed || qualifies[c.AchievementID] {
			continue
		}
		if err := q.g.ReconcileUserAchievementClaim(ctx, dbgen.ReconcileUserAchievementClaimParams{
			ID: pgUUID(userID), AchievementID: c.AchievementID,
		}); err != nil {
			return nil, err
		}
		delete(claimedSet, c.AchievementID)
	}

	out := make([]AchievementProgress, 0, len(currents))
	for _, current := range currents {
		def := current.def
		claimed := claimedSet[def.ID]
		out = append(out, AchievementProgress{
			ID:                def.ID,
			Name:              def.Name,
			Description:       def.Description,
			Track:             def.Track,
			Difficulty:        def.Difficulty,
			RewardXP:          def.RewardXP,
			DefinitionVersion: def.DefinitionVersion,
			CurrentValue:      current.value,
			Threshold:         def.Threshold,
			ThresholdUp:       def.ThresholdUp,
			Claimed:           claimed,
			Claimable:         !claimed && qualifies[def.ID],
			RewardAvailable:   !rewardedSet[def.ID],
		})
	}
	return out, nil
}

func (q *Queries) CheckAchievementClaimable(ctx context.Context, achievementID int32, userID uuid.UUID, _ AchievementConfig) (bool, error) {
	def, ok := achievementDefinition(achievementID)
	if !ok {
		return false, nil
	}
	cur, err := q.runAchievementQuery(ctx, def, userID)
	if err != nil {
		return false, err
	}
	return cur >= int(def.Threshold), nil
}

func achievementDefinition(achievementID int32) (AchievementDef, bool) {
	for _, def := range achievementDefs {
		if def.ID == achievementID {
			return def, true
		}
	}
	return AchievementDef{}, false
}

func (q *Queries) runAchievementQuery(ctx context.Context, def AchievementDef, userID uuid.UUID) (int, error) {
	var n int
	if err := q.runner.QueryRow(ctx, def.sql, pgUUID(userID)).Scan(&n); err != nil {
		return 0, err
	}
	return n, nil
}
