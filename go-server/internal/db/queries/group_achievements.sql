-- Group achievements count active pins that belong to the group.

-- name: GetGroupPinCount :one
SELECT COUNT(*)::int
FROM pins
WHERE group_id = $1 AND is_deleted = FALSE AND is_gone = FALSE;

-- name: GetGroupAchievementMetrics :one
SELECT
    (SELECT COUNT(*)::int
     FROM pins p
     WHERE p.group_id = $1 AND p.is_deleted = FALSE AND p.is_gone = FALSE) AS active_pins,
    (SELECT COUNT(DISTINCT p.creator_id)::int
     FROM pins p
     WHERE p.group_id = $1 AND p.is_deleted = FALSE AND p.is_gone = FALSE
       AND p.creator_id IS NOT NULL) AS contributors,
    (SELECT COUNT(*)::int
     FROM (
         SELECT p.creator_id
         FROM pins p
         WHERE p.group_id = $1 AND p.is_deleted = FALSE AND p.is_gone = FALSE
           AND p.creator_id IS NOT NULL
         GROUP BY p.creator_id
         HAVING COUNT(*) >= 3
     ) qualified_contributors) AS contributors_three_pins,
    (SELECT COUNT(*)::int
     FROM (
         SELECT p.creator_id
         FROM pins p
         WHERE p.group_id = $1 AND p.is_deleted = FALSE AND p.is_gone = FALSE
           AND p.creator_id IS NOT NULL
         GROUP BY p.creator_id
         HAVING COUNT(*) >= 5
     ) qualified_contributors) AS contributors_five_pins,
    (SELECT COUNT(DISTINCT m.user_id)::int
     FROM members m
     WHERE m.group_id = $1 AND m.is_deleted = FALSE AND m.user_id IS NOT NULL) AS members;

-- name: ListGroupAchievementClaims :many
SELECT achievement_id
FROM group_achievement_claims
WHERE group_id = $1
ORDER BY achievement_id;

-- name: ClaimGroupAchievement :execrows
WITH claimed AS (
    INSERT INTO group_achievement_claims (group_id, achievement_id, claimed_by)
    SELECT sqlc.arg(group_id)::uuid,
           sqlc.arg(achievement_id)::integer,
           sqlc.arg(claimed_by)::uuid
    WHERE CASE sqlc.arg(track)::text
        WHEN 'active_pins' THEN (
            SELECT COUNT(*) FROM pins p
            WHERE p.group_id = sqlc.arg(group_id)
              AND p.is_deleted = FALSE AND p.is_gone = FALSE
        )
        WHEN 'contributors' THEN (
            SELECT COUNT(*) FROM (
                SELECT p.creator_id
                FROM pins p
                WHERE p.group_id = sqlc.arg(group_id)
                  AND p.is_deleted = FALSE AND p.is_gone = FALSE
                  AND p.creator_id IS NOT NULL
                GROUP BY p.creator_id
                HAVING COUNT(*) >= sqlc.arg(contributor_minimum_pins)::integer
            ) qualified_contributors
        )
        WHEN 'members' THEN (
            SELECT COUNT(DISTINCT m.user_id) FROM members m
            WHERE m.group_id = sqlc.arg(group_id)
              AND m.is_deleted = FALSE AND m.user_id IS NOT NULL
        )
        ELSE 0
    END >= sqlc.arg(threshold)::integer
    ON CONFLICT (group_id, achievement_id) DO NOTHING
    RETURNING group_id
)
UPDATE groups g
SET update_date = GREATEST(
    NOW(),
    COALESCE(g.update_date, NOW() - INTERVAL '1 microsecond') + INTERVAL '1 microsecond'
)
FROM claimed
WHERE g.id = claimed.group_id;

-- name: UnlockGroupPinStyle :exec
INSERT INTO group_pin_style_unlocks (group_id, pin_style, achievement_id)
VALUES ($1, $2, $3)
ON CONFLICT (group_id, pin_style) DO NOTHING;

-- name: IsGroupPinStyleUnlocked :one
SELECT EXISTS (
    SELECT 1
    FROM group_pin_style_unlocks
    WHERE group_id = $1 AND pin_style = $2
);
