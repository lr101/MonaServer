-- name: GetLikeByUserAndPin :one
SELECT id, pin_id, user_id, like_all
FROM likes
WHERE user_id = $1 AND photo_id = $2;

-- name: UpsertLike :exec
INSERT INTO likes (id, pin_id, photo_id, user_id, like_all, creation_date, update_date)
VALUES ($1, $2, $3, $4, $5, NOW(), NOW())
ON CONFLICT (user_id, photo_id) DO UPDATE
  SET like_all = EXCLUDED.like_all,
      update_date = NOW();

-- name: DeleteLike :exec
DELETE FROM likes WHERE user_id = $1 AND photo_id = $2;

-- name: CountPinLikes :one
SELECT COUNT(*)::bigint AS n
FROM likes
WHERE photo_id = $1 AND like_all = TRUE;

-- name: ListPinLikes :many
SELECT l.id, l.user_id, u.username, l.like_all
FROM likes l JOIN users u ON u.id = l.user_id
WHERE l.photo_id = $1 AND l.like_all = TRUE
ORDER BY l.creation_date DESC;

-- name: CountLikesForCreator :one
SELECT COUNT(*)::bigint AS n
FROM likes l
JOIN pins p ON p.id = l.pin_id
LEFT JOIN pin_photos pp ON pp.id = l.photo_id
WHERE COALESCE(pp.contributor_id, p.creator_id) = $1
  AND p.is_deleted = FALSE
  AND l.like_all = TRUE;

-- name: ListUserLikedPins :many
SELECT l.pin_id, l.photo_id, l.like_all
FROM likes l
JOIN pins p ON p.id = l.pin_id
WHERE l.user_id = $1 AND p.is_deleted = FALSE AND l.like_all = TRUE
ORDER BY l.creation_date DESC;
