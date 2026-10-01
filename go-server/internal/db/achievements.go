package db

import (
	"context"

	"github.com/google/uuid"
	dbgen "github.com/lrprojects/monaserver/internal/gen/db"
)

const userAchievementDefinitionVersion int32 = 7

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

var achievementDefs = []AchievementDef{
	{
		ID: 0, Name: "Two countries", Description: "Add sticks in two different countries.",
		Track: "places", Difficulty: "easy", RewardXP: 20, DefinitionVersion: userAchievementDefinitionVersion,
		Threshold: 2, ThresholdUp: true,
		sql: `SELECT COUNT(DISTINCT b.gid_0)::int FROM pins p JOIN admin2_boundaries b ON b.id=p.state_province_id WHERE p.creator_id=$1 AND p.is_deleted=FALSE AND b.gid_0 IS NOT NULL AND b.gid_0<>''`,
	},
	{
		ID: 2, Name: "Two groups", Description: "Join two groups.",
		Track: "groups", Difficulty: "easy", RewardXP: 20, DefinitionVersion: userAchievementDefinitionVersion,
		Threshold: 2, ThresholdUp: true,
		sql: `SELECT COUNT(DISTINCT m.group_id)::int FROM members m JOIN groups g ON g.id=m.group_id WHERE m.user_id=$1 AND m.is_deleted=FALSE AND g.is_deleted=FALSE`,
	},
	{
		ID: 3, Name: "Two sticks", Description: "Add two sticks.",
		Track: "sticks", Difficulty: "easy", RewardXP: 20, DefinitionVersion: userAchievementDefinitionVersion,
		Threshold: 2, ThresholdUp: true,
		sql: `SELECT COUNT(*)::int FROM pins WHERE creator_id=$1 AND is_deleted=FALSE`,
	},
	{
		ID: 4, Name: "Team regular", Description: "Join five groups.",
		Track: "groups", Difficulty: "medium", RewardXP: 0, DefinitionVersion: userAchievementDefinitionVersion,
		Threshold: 5, ThresholdUp: true,
		sql: `SELECT COUNT(DISTINCT m.group_id)::int FROM members m JOIN groups g ON g.id=m.group_id WHERE m.user_id=$1 AND m.is_deleted=FALSE AND g.is_deleted=FALSE`,
	},
	{
		ID: 5, Name: "Supporter", Description: "Give likes to twenty sticks from other people.",
		Track: "likes_given", Difficulty: "easy", RewardXP: 20, DefinitionVersion: userAchievementDefinitionVersion,
		Threshold: 20, ThresholdUp: true,
		sql: `SELECT COUNT(*)::int FROM likes l JOIN pins p ON p.id=l.pin_id WHERE l.user_id=$1 AND (l.like_all=TRUE OR l.like_location=TRUE OR l.like_photography=TRUE OR l.like_art=TRUE) AND p.creator_id<>l.user_id AND p.is_deleted=FALSE`,
	},
	{
		ID: 6, Name: "Getting noticed", Description: "Receive twenty likes on your sticks.",
		Track: "likes_received", Difficulty: "easy", RewardXP: 20, DefinitionVersion: userAchievementDefinitionVersion,
		Threshold: 20, ThresholdUp: true,
		sql: `SELECT COUNT(*)::int FROM likes l JOIN pins p ON p.id=l.pin_id WHERE p.creator_id=$1 AND l.user_id<>p.creator_id AND (l.like_all=TRUE OR l.like_location=TRUE OR l.like_photography=TRUE OR l.like_art=TRUE) AND p.is_deleted=FALSE`,
	},
	{
		ID: 7, Name: "Super supporter", Description: "Give likes to two hundred sticks from other people.",
		Track: "likes_given", Difficulty: "medium", RewardXP: 0, DefinitionVersion: userAchievementDefinitionVersion,
		Threshold: 200, ThresholdUp: true,
		sql: `SELECT COUNT(*)::int FROM likes l JOIN pins p ON p.id=l.pin_id WHERE l.user_id=$1 AND (l.like_all=TRUE OR l.like_location=TRUE OR l.like_photography=TRUE OR l.like_art=TRUE) AND p.creator_id<>l.user_id AND p.is_deleted=FALSE`,
	},
	{
		ID: 8, Name: "Fan favorite", Description: "Receive 200 likes on your sticks.",
		Track: "likes_received", Difficulty: "medium", RewardXP: 0, DefinitionVersion: userAchievementDefinitionVersion,
		Threshold: 200, ThresholdUp: true,
		sql: `SELECT COUNT(*)::int FROM likes l JOIN pins p ON p.id=l.pin_id WHERE p.creator_id=$1 AND l.user_id<>p.creator_id AND (l.like_all=TRUE OR l.like_location=TRUE OR l.like_photography=TRUE OR l.like_art=TRUE) AND p.is_deleted=FALSE`,
	},
	{
		ID: 9, Name: "Stick collector", Description: "Add forty sticks.",
		Track: "sticks", Difficulty: "medium", RewardXP: 0, DefinitionVersion: userAchievementDefinitionVersion,
		Threshold: 40, ThresholdUp: true,
		sql: `SELECT COUNT(*)::int FROM pins WHERE creator_id=$1 AND is_deleted=FALSE`,
	},
	{
		ID: 10, Name: "Explorer", Description: "Add sticks in ten different countries.",
		Track: "places", Difficulty: "medium", RewardXP: 0, DefinitionVersion: userAchievementDefinitionVersion,
		Threshold: 10, ThresholdUp: true,
		sql: `SELECT COUNT(DISTINCT b.gid_0)::int FROM pins p JOIN admin2_boundaries b ON b.id=p.state_province_id WHERE p.creator_id=$1 AND p.is_deleted=FALSE AND b.gid_0 IS NOT NULL AND b.gid_0<>''`,
	},
	{
		ID: 11, Name: "Wide-ranging explorer", Description: "Add sticks in 25 different countries.",
		Track: "places", Difficulty: "hard", RewardXP: 0, DefinitionVersion: userAchievementDefinitionVersion,
		Threshold: 25, ThresholdUp: true,
		sql: `SELECT COUNT(DISTINCT b.gid_0)::int FROM pins p JOIN admin2_boundaries b ON b.id=p.state_province_id WHERE p.creator_id=$1 AND p.is_deleted=FALSE AND b.gid_0 IS NOT NULL AND b.gid_0<>''`,
	},
	{
		ID: 12, Name: "Dedicated collector", Description: "Add two hundred sticks.",
		Track: "sticks", Difficulty: "hard", RewardXP: 0, DefinitionVersion: userAchievementDefinitionVersion,
		Threshold: 200, ThresholdUp: true,
		sql: `SELECT COUNT(*)::int FROM pins WHERE creator_id=$1 AND is_deleted=FALSE`,
	},
	{
		ID: 13, Name: "Community contributor", Description: "Add sticks in three different groups.",
		Track: "contributing_groups", Difficulty: "medium", RewardXP: 0, DefinitionVersion: userAchievementDefinitionVersion,
		Threshold: 3, ThresholdUp: true,
		sql: `SELECT COUNT(DISTINCT p.group_id)::int FROM pins p JOIN groups g ON g.id=p.group_id WHERE p.creator_id=$1 AND p.is_deleted=FALSE AND p.is_gone=FALSE AND g.is_deleted=FALSE`,
	},
	{
		ID: 14, Name: "Big supporter", Description: "Give likes to four hundred sticks from other people.",
		Track: "likes_given", Difficulty: "hard", RewardXP: 0, DefinitionVersion: userAchievementDefinitionVersion,
		Threshold: 400, ThresholdUp: true,
		sql: `SELECT COUNT(*)::int FROM likes l JOIN pins p ON p.id=l.pin_id WHERE l.user_id=$1 AND (l.like_all=TRUE OR l.like_location=TRUE OR l.like_photography=TRUE OR l.like_art=TRUE) AND p.creator_id<>l.user_id AND p.is_deleted=FALSE`,
	},
	{
		ID: 15, Name: "Community favorite", Description: "Receive 400 likes on your sticks.",
		Track: "likes_received", Difficulty: "hard", RewardXP: 0, DefinitionVersion: userAchievementDefinitionVersion,
		Threshold: 400, ThresholdUp: true,
		sql: `SELECT COUNT(*)::int FROM likes l JOIN pins p ON p.id=l.pin_id WHERE p.creator_id=$1 AND l.user_id<>p.creator_id AND (l.like_all=TRUE OR l.like_location=TRUE OR l.like_photography=TRUE OR l.like_art=TRUE) AND p.is_deleted=FALSE`,
	},
	{
		ID: 16, Name: "Four hundred collector", Description: "Add 400 sticks.",
		Track: "sticks", Difficulty: "hard", RewardXP: 0, DefinitionVersion: userAchievementDefinitionVersion,
		Threshold: 400, ThresholdUp: true,
		sql: `SELECT COUNT(*)::int FROM pins WHERE creator_id=$1 AND is_deleted=FALSE`,
	},
	{
		ID: 17, Name: "Photo storyteller", Description: "Have photos on two of your sticks.",
		Track: "photos", Difficulty: "easy", RewardXP: 20, DefinitionVersion: userAchievementDefinitionVersion,
		Threshold: 2, ThresholdUp: true,
		sql: `SELECT COUNT(DISTINCT pp.pin_id)::int FROM pin_photos pp JOIN pins p ON p.id=pp.pin_id WHERE p.creator_id=$1 AND p.is_deleted=FALSE AND p.is_gone=FALSE`,
	},
	{
		ID: 18, Name: "Album keeper", Description: "Have photos on 40 of your sticks.",
		Track: "photos", Difficulty: "medium", RewardXP: 0, DefinitionVersion: userAchievementDefinitionVersion,
		Threshold: 40, ThresholdUp: true,
		sql: `SELECT COUNT(DISTINCT pp.pin_id)::int FROM pin_photos pp JOIN pins p ON p.id=pp.pin_id WHERE p.creator_id=$1 AND p.is_deleted=FALSE AND p.is_gone=FALSE`,
	},
	{
		ID: 19, Name: "Gallery curator", Description: "Have photos on 200 of your sticks.",
		Track: "photos", Difficulty: "hard", RewardXP: 0, DefinitionVersion: userAchievementDefinitionVersion,
		Threshold: 200, ThresholdUp: true,
		sql: `SELECT COUNT(DISTINCT pp.pin_id)::int FROM pin_photos pp JOIN pins p ON p.id=pp.pin_id WHERE p.creator_id=$1 AND p.is_deleted=FALSE AND p.is_gone=FALSE`,
	},
	{
		ID: 20, Name: "Seasoned explorer", Description: "Add sticks in 50 different countries.",
		Track: "places", Difficulty: "hard", RewardXP: 0, DefinitionVersion: userAchievementDefinitionVersion,
		Threshold: 50, ThresholdUp: true,
		sql: `SELECT COUNT(DISTINCT b.gid_0)::int FROM pins p JOIN admin2_boundaries b ON b.id=p.state_province_id WHERE p.creator_id=$1 AND p.is_deleted=FALSE AND b.gid_0 IS NOT NULL AND b.gid_0<>''`,
	},
	{
		ID: 21, Name: "Cross-group builder", Description: "Add sticks in ten different groups.",
		Track: "contributing_groups", Difficulty: "hard", RewardXP: 0, DefinitionVersion: userAchievementDefinitionVersion,
		Threshold: 10, ThresholdUp: true,
		sql: `SELECT COUNT(DISTINCT p.group_id)::int FROM pins p JOIN groups g ON g.id=p.group_id WHERE p.creator_id=$1 AND p.is_deleted=FALSE AND p.is_gone=FALSE AND g.is_deleted=FALSE`,
	},
	{
		ID: 22, Name: "Generous supporter", Description: "Give likes to 1,000 sticks from other people.",
		Track: "likes_given", Difficulty: "hard", RewardXP: 0, DefinitionVersion: userAchievementDefinitionVersion,
		Threshold: 1000, ThresholdUp: true,
		sql: `SELECT COUNT(*)::int FROM likes l JOIN pins p ON p.id=l.pin_id WHERE l.user_id=$1 AND (l.like_all=TRUE OR l.like_location=TRUE OR l.like_photography=TRUE OR l.like_art=TRUE) AND p.creator_id<>l.user_id AND p.is_deleted=FALSE`,
	},
	{
		ID: 23, Name: "Crowd favorite", Description: "Receive 1,000 likes on your sticks.",
		Track: "likes_received", Difficulty: "hard", RewardXP: 0, DefinitionVersion: userAchievementDefinitionVersion,
		Threshold: 1000, ThresholdUp: true,
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
	RewardType        string
	RewardColor       *string
	DefinitionVersion int32
	CurrentValue      int32
	Threshold         int32
	ThresholdUp       bool
	Claimed           bool
	Claimable         bool
	RewardAvailable   bool
}

// AchievementReward describes the single reward category for an achievement.
type AchievementReward struct {
	Type  string
	Color *string
}

func achievementReward(def AchievementDef) AchievementReward {
	switch def.Difficulty {
	case "easy":
		return AchievementReward{Type: "xp"}
	case "medium":
		color := ""
		switch def.ID {
		case 4:
			color = "#FF7CB342" // leaf green
		case 7:
			color = "#FF3F51B5" // indigo
		case 8:
			color = "#FFC62828" // crimson
		case 9:
			color = "#FF26A69A" // sea teal
		case 10:
			color = "#FFD81B60" // magenta
		case 13:
			color = "#FF7B1FA2" // amethyst purple
		case 18:
			color = "#FFFF7043" // coral
		default:
			return AchievementReward{Type: "color"}
		}
		return AchievementReward{Type: "color", Color: &color}
	case "hard":
		return AchievementReward{Type: "badge"}
	default:
		return AchievementReward{}
	}
}

// AchievementRewardForID returns the profile customization granted by an
// achievement definition.
func AchievementRewardForID(achievementID int32) AchievementReward {
	def, ok := achievementDefinition(achievementID)
	if !ok {
		return AchievementReward{}
	}
	return achievementReward(def)
}

// HasUserAchievementRewardColor reports whether an earned, still-current
// achievement grants the requested badge color.
func (q *Queries) HasUserAchievementRewardColor(ctx context.Context, userID uuid.UUID, color string) (bool, error) {
	ids, err := q.g.ListCurrentClaimedUserAchievementIDs(ctx, pgUUID(userID))
	if err != nil {
		return false, err
	}
	for _, id := range ids {
		def, ok := achievementDefinition(id)
		if !ok {
			continue
		}
		reward := achievementReward(def)
		if reward.Color != nil && *reward.Color == color {
			return true, nil
		}
		// Keep colors selected before reward colors became unique available to
		// their original owners. This lets them keep or reselect a legacy color.
		if legacyColor, ok := legacyAchievementRewardColor(id); ok && legacyColor == color {
			return true, nil
		}
		if (id == 7 && color == "#FFE53935") || (id == 13 && color == "#FFC2185B") {
			return true, nil
		}
	}
	return false, nil
}

func legacyAchievementRewardColor(achievementID int32) (string, bool) {
	switch achievementID {
	case 4:
		return "#FF8BC34A", true
	case 7, 8:
		return "#FFFF5252", true
	case 9:
		return "#FF64FFDA", true
	case 10:
		return "#FFE91E63", true
	case 18:
		return "#FFFF7043", true
	default:
		return "", false
	}
}

func (q *Queries) GetAchievementProgress(ctx context.Context, userID uuid.UUID) ([]AchievementProgress, error) {
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
	legacyRewards, err := q.g.ListUserAchievementRewardAwardsBeforeVersion(
		ctx,
		dbgen.ListUserAchievementRewardAwardsBeforeVersionParams{
			UserID:            pgUUID(userID),
			DefinitionVersion: userAchievementDefinitionVersion,
		},
	)
	if err != nil {
		return nil, err
	}
	legacyRewardedSet := make(map[int32]bool, len(legacyRewards))
	for _, id := range legacyRewards {
		if def, ok := achievementDefinition(id); ok && (def.Track == "places" || def.Track == "contributing_groups") {
			continue
		}
		legacyRewardedSet[id] = true
	}

	type currentProgress struct {
		def   AchievementDef
		value int32
	}
	currents := make([]currentProgress, 0, len(achievementDefs))
	currentByTrack := make(map[string]int32, 6)
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
		if !c.Claimed || qualifies[c.AchievementID] || legacyRewardedSet[c.AchievementID] {
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
		reward := achievementReward(def)
		out = append(out, AchievementProgress{
			ID:                def.ID,
			Name:              def.Name,
			Description:       def.Description,
			Track:             def.Track,
			Difficulty:        def.Difficulty,
			RewardXP:          def.RewardXP,
			RewardType:        reward.Type,
			RewardColor:       reward.Color,
			DefinitionVersion: def.DefinitionVersion,
			CurrentValue:      current.value,
			Threshold:         def.Threshold,
			ThresholdUp:       def.ThresholdUp,
			Claimed:           claimed,
			Claimable:         !claimed && qualifies[def.ID],
			RewardAvailable:   reward.Type == "xp" && !rewardedSet[def.ID],
		})
	}
	return out, nil
}

// GetClaimedAchievementProgress returns display data for earned achievements
// without evaluating live activity progress or reward eligibility.
func (q *Queries) GetClaimedAchievementProgress(ctx context.Context, userID uuid.UUID) ([]AchievementProgress, error) {
	claimed, err := q.ListUserAchievements(ctx, userID)
	if err != nil {
		return nil, err
	}
	return publicAchievementProgress(claimed), nil
}

func publicAchievementProgress(claimed []UserAchievement) []AchievementProgress {
	claimedSet := make(map[int32]bool, len(claimed))
	for _, item := range claimed {
		if item.Claimed {
			claimedSet[item.AchievementID] = true
		}
	}
	progress := make([]AchievementProgress, 0, len(claimedSet))
	for _, def := range achievementDefs {
		if !claimedSet[def.ID] {
			continue
		}
		progress = append(progress, AchievementProgress{
			ID:           def.ID,
			Name:         def.Name,
			Description:  def.Description,
			Track:        def.Track,
			Difficulty:   def.Difficulty,
			CurrentValue: def.Threshold,
			Threshold:    def.Threshold,
			ThresholdUp:  def.ThresholdUp,
			Claimed:      true,
		})
	}
	return progress
}

func (q *Queries) CheckAchievementClaimable(ctx context.Context, achievementID int32, userID uuid.UUID) (bool, error) {
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
