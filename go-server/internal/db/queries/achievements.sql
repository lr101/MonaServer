-- name: ListUserAchievements :many
SELECT id, achievement_id, claimed
FROM user_achievement
WHERE user_id = $1
ORDER BY achievement_id;

-- name: GetUserAchievement :one
SELECT id, user_id, achievement_id, claimed
FROM user_achievement
WHERE user_id = $1 AND achievement_id = $2;

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
