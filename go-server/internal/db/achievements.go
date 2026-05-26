package db

import (
	"context"
	"time"

	"github.com/google/uuid"
)

// AchievementDef mirrors AchievementType from the Kotlin server.
type AchievementDef struct {
	ID          int32
	Threshold   int32
	ThresholdUp bool // true = currentValue >= threshold to claim
	sql         string
	needsGroup  bool
	needsDate   bool
}

// AchievementConfig holds environment-specific parameters used by certain achievements.
type AchievementConfig struct {
	MonaGroupID    uuid.UUID
	CreatedBefore  time.Time
}

var achievementDefs = []AchievementDef{
	{0, 10, true, `SELECT COALESCE(MAX(cnt),0) FROM (SELECT COUNT(*) AS cnt FROM pins WHERE creator_id=$1 AND is_deleted=FALSE GROUP BY state_province_id) t`, false, false},
	{1, 1, true, `SELECT COUNT(*)::int FROM users WHERE creation_date < $2 AND id=$1 AND is_deleted=FALSE`, false, true},
	{2, 1, true, `SELECT COUNT(*)::int FROM members WHERE user_id=$1 AND group_id=$2 AND is_deleted=FALSE`, true, false},
	{3, 1, true, `SELECT COUNT(*)::int FROM pins WHERE creator_id=$1 AND is_deleted=FALSE`, false, false},
	{4, 1, true, `SELECT COUNT(*)::int FROM members WHERE user_id=$1 AND is_deleted=FALSE`, false, false},
	{5, 1000, true, `SELECT COUNT(*)::int FROM likes WHERE user_id=$1 AND like_all=TRUE`, false, false},
	{6, 1000, true, `SELECT COUNT(*)::int FROM likes WHERE user_id=$1 AND like_art=TRUE`, false, false},
	{7, 1000, true, `SELECT COUNT(*)::int FROM likes WHERE user_id=$1 AND like_location=TRUE`, false, false},
	{8, 1000, true, `SELECT COUNT(*)::int FROM likes WHERE user_id=$1 AND like_photography=TRUE`, false, false},
	{9, 500, true, `SELECT COUNT(*)::int FROM pins WHERE creator_id=$1 AND is_deleted=FALSE`, false, false},
	{10, 100, true, `SELECT COALESCE(MAX(cnt),0) FROM (SELECT COUNT(*) AS cnt FROM pins JOIN admin2_boundaries ON pins.state_province_id=admin2_boundaries.id WHERE creator_id=$1 AND is_deleted=FALSE GROUP BY admin2_boundaries.gid_1) t`, false, false},
	{11, 250, true, `SELECT COALESCE(MAX(cnt),0) FROM (SELECT COUNT(*) AS cnt FROM pins JOIN admin2_boundaries ON pins.state_province_id=admin2_boundaries.id WHERE creator_id=$1 AND is_deleted=FALSE GROUP BY admin2_boundaries.gid_0) t`, false, false},
	{12, 3, false, `WITH rk AS (SELECT creator_id, RANK() OVER (PARTITION BY b.gid_2 ORDER BY COUNT(*) DESC) AS r FROM pins JOIN admin2_boundaries b ON pins.state_province_id=b.id WHERE is_deleted=FALSE GROUP BY creator_id,b.gid_2) SELECT COALESCE(MIN(r),0)::int FROM rk WHERE creator_id=$1`, false, false},
	{13, 3, false, `WITH rk AS (SELECT creator_id, RANK() OVER (PARTITION BY b.gid_1 ORDER BY COUNT(*) DESC) AS r FROM pins JOIN admin2_boundaries b ON pins.state_province_id=b.id WHERE is_deleted=FALSE GROUP BY creator_id,b.gid_1) SELECT COALESCE(MIN(r),0)::int FROM rk WHERE creator_id=$1`, false, false},
	{14, 3, false, `WITH rk AS (SELECT creator_id, RANK() OVER (PARTITION BY b.gid_0 ORDER BY COUNT(*) DESC) AS r FROM pins JOIN admin2_boundaries b ON pins.state_province_id=b.id WHERE is_deleted=FALSE GROUP BY creator_id,b.gid_0) SELECT COALESCE(MIN(r),0)::int FROM rk WHERE creator_id=$1`, false, false},
	{15, 3, false, `WITH rk AS (SELECT creator_id, RANK() OVER (ORDER BY COUNT(*) DESC) AS r FROM pins WHERE is_deleted=FALSE GROUP BY creator_id) SELECT COALESCE(MIN(r),0)::int FROM rk WHERE creator_id=$1`, false, false},
}

type AchievementProgress struct {
	ID           int32
	CurrentValue int32
	Threshold    int32
	ThresholdUp  bool
	Claimed      bool
}

func (q *Queries) GetAchievementProgress(ctx context.Context, userID uuid.UUID, cfg AchievementConfig) ([]AchievementProgress, error) {
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

	out := make([]AchievementProgress, 0, len(achievementDefs))
	for _, def := range achievementDefs {
		cur, err := q.runAchievementQuery(ctx, def, userID, cfg)
		if err != nil {
			cur = 0
		}
		out = append(out, AchievementProgress{
			ID:           def.ID,
			CurrentValue: int32(cur),
			Threshold:    def.Threshold,
			ThresholdUp:  def.ThresholdUp,
			Claimed:      claimedSet[def.ID],
		})
	}
	return out, nil
}

func (q *Queries) CheckAchievementClaimable(ctx context.Context, achievementID int32, userID uuid.UUID, cfg AchievementConfig) (bool, error) {
	for _, def := range achievementDefs {
		if def.ID != achievementID {
			continue
		}
		cur, err := q.runAchievementQuery(ctx, def, userID, cfg)
		if err != nil {
			return false, err
		}
		if def.ThresholdUp {
			return cur >= int(def.Threshold), nil
		}
		return cur <= int(def.Threshold) && cur > 0, nil
	}
	return false, nil
}

func (q *Queries) runAchievementQuery(ctx context.Context, def AchievementDef, userID uuid.UUID, cfg AchievementConfig) (int, error) {
	var row interface{ Scan(...any) error }
	uid := pgUUID(userID)
	if def.needsGroup && def.needsDate {
		row = q.pool.QueryRow(ctx, def.sql, uid, pgUUID(cfg.MonaGroupID), pgTZ(&cfg.CreatedBefore))
	} else if def.needsGroup {
		row = q.pool.QueryRow(ctx, def.sql, uid, pgUUID(cfg.MonaGroupID))
	} else if def.needsDate {
		row = q.pool.QueryRow(ctx, def.sql, uid, pgTZ(&cfg.CreatedBefore))
	} else {
		row = q.pool.QueryRow(ctx, def.sql, uid)
	}
	var n int
	if err := row.Scan(&n); err != nil {
		return 0, err
	}
	return n, nil
}
