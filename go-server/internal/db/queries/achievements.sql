-- name: ListUserAchievements :many
SELECT id, achievement_id, claimed
FROM user_achievement
WHERE user_id = $1
ORDER BY achievement_id;

-- name: GetUserAchievement :one
SELECT id, user_id, achievement_id, claimed
FROM user_achievement
WHERE user_id = $1 AND achievement_id = $2;

-- name: GetSelectedUserAchievementID :one
SELECT ua.achievement_id
FROM users u
JOIN user_achievement ua ON ua.id = u.selected_batch
WHERE u.id = $1 AND u.is_deleted = FALSE;

-- name: UpsertUserAchievement :one
INSERT INTO user_achievement (id, user_id, achievement_id, claimed, creation_date, update_date)
VALUES ($1, $2, $3, FALSE, NOW(), NOW())
ON CONFLICT (user_id, achievement_id) DO UPDATE
  SET update_date = NOW()
RETURNING id, user_id, achievement_id, claimed;

-- name: ClaimUserAchievement :exec
UPDATE user_achievement
SET claimed = TRUE, update_date = NOW()
WHERE user_id = $1 AND achievement_id = $2;

-- name: ReconcileUserAchievementClaim :exec
WITH revoked AS (
    UPDATE user_achievement
    SET claimed = FALSE, update_date = NOW()
    WHERE user_id = $1 AND achievement_id = $2 AND claimed = TRUE
    RETURNING id
)
UPDATE users u
SET selected_batch = NULL, update_date = NOW()
WHERE u.id = $1 AND u.selected_batch IN (SELECT id FROM revoked);

-- name: ClaimUserAchievementAndAwardXP :one
WITH claim AS (
    INSERT INTO user_achievement (
        id, user_id, achievement_id, claimed, creation_date, update_date
    )
    VALUES ($1, $2, $3, TRUE, NOW(), NOW())
    ON CONFLICT (user_id, achievement_id) DO UPDATE
        SET claimed = TRUE, update_date = NOW()
    WHERE user_achievement.claimed = FALSE
    RETURNING user_id, achievement_id
), reward AS (
    INSERT INTO user_achievement_reward_ledger (
        user_id, achievement_id, xp_awarded, definition_version, awarded_at
    )
    SELECT user_id, achievement_id, $4, $5, NOW()
    FROM claim
    ON CONFLICT (user_id, achievement_id) DO NOTHING
    RETURNING user_id, xp_awarded
), award AS (
    UPDATE users u
    SET xp = xp + reward.xp_awarded, update_date = NOW()
    FROM reward
    WHERE u.id = reward.user_id
    RETURNING u.id
)
SELECT claim.user_id
FROM claim;
