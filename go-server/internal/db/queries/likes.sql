-- name: GetLikeByUserAndPin :one
SELECT id, pin_id, user_id, like_all, like_location, like_photography, like_art
FROM likes
WHERE user_id = $1 AND pin_id = $2;

-- name: UpsertLike :exec
INSERT INTO likes (id, pin_id, user_id, like_all, like_location, like_photography, like_art, creation_date, update_date)
VALUES ($1, $2, $3, $4, $5, $6, $7, NOW(), NOW())
ON CONFLICT (user_id, pin_id) DO UPDATE
  SET like_all = EXCLUDED.like_all,
      like_location = EXCLUDED.like_location,
      like_photography = EXCLUDED.like_photography,
      like_art = EXCLUDED.like_art,
      update_date = NOW();

-- name: DeleteLike :exec
DELETE FROM likes WHERE user_id = $1 AND pin_id = $2;

-- name: CountPinLikes :one
SELECT COUNT(*)::bigint AS n FROM likes WHERE pin_id = $1;

-- name: ListPinLikes :many
SELECT l.id, l.user_id, u.username, l.like_all, l.like_location, l.like_photography, l.like_art
FROM likes l JOIN users u ON u.id = l.user_id
WHERE l.pin_id = $1
ORDER BY l.creation_date DESC;

-- name: CountPinLikesByType :one
SELECT
  COALESCE(SUM(CASE WHEN like_all         THEN 1 ELSE 0 END), 0)::bigint AS like_all,
  COALESCE(SUM(CASE WHEN like_location    THEN 1 ELSE 0 END), 0)::bigint AS like_location,
  COALESCE(SUM(CASE WHEN like_photography THEN 1 ELSE 0 END), 0)::bigint AS like_photography,
  COALESCE(SUM(CASE WHEN like_art         THEN 1 ELSE 0 END), 0)::bigint AS like_art
FROM likes WHERE pin_id = $1;

-- name: CountLikesForCreator :one
SELECT
  COALESCE(SUM(CASE WHEN l.like_all         THEN 1 ELSE 0 END), 0)::bigint AS like_all,
  COALESCE(SUM(CASE WHEN l.like_location    THEN 1 ELSE 0 END), 0)::bigint AS like_location,
  COALESCE(SUM(CASE WHEN l.like_photography THEN 1 ELSE 0 END), 0)::bigint AS like_photography,
  COALESCE(SUM(CASE WHEN l.like_art         THEN 1 ELSE 0 END), 0)::bigint AS like_art
FROM likes l
JOIN pins p ON p.id = l.pin_id
WHERE p.creator_id = $1 AND p.is_deleted = FALSE;

-- name: ListUserLikedPins :many
SELECT l.pin_id, l.like_all, l.like_location, l.like_photography, l.like_art
FROM likes l
JOIN pins p ON p.id = l.pin_id
WHERE l.user_id = $1 AND p.is_deleted = FALSE
ORDER BY l.creation_date DESC;
