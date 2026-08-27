-- Pin queries.

-- name: CreatePin :exec
INSERT INTO pins (id, latitude, longitude, creation_date, update_date,
                  description, creator_id, group_id, state_province_id)
VALUES ($1, $2, $3, $4, NOW(), $5, $6, $7, $8);

-- name: GetPinByID :one
SELECT id, latitude, longitude, creation_date, update_date, description,
       creator_id, group_id, state_province_id
FROM pins
WHERE id = $1 AND is_deleted = FALSE;

-- name: PinExistsForUserAt :one
SELECT EXISTS (
  SELECT 1 FROM pins
  WHERE creator_id = $1 AND latitude = $2 AND longitude = $3
    AND creation_date = $4 AND is_deleted = FALSE
);

-- name: SoftDeletePin :exec
UPDATE pins SET is_deleted = TRUE, update_date = NOW() WHERE id = $1;

-- name: HardDeletePin :exec
DELETE FROM pins WHERE id = $1;

-- name: ListUserPinIDs :many
SELECT id FROM pins WHERE creator_id = $1 AND is_deleted = FALSE ORDER BY creation_date DESC;

-- name: ListGroupPinIDs :many
SELECT id FROM pins WHERE group_id = $1 AND is_deleted = FALSE ORDER BY creation_date DESC;

-- name: ListUpdatedPinsForGroups :many
SELECT id, latitude, longitude, creation_date, update_date, description,
       creator_id, group_id, state_province_id
FROM pins
WHERE is_deleted = FALSE
  AND group_id = ANY(sqlc.arg('group_ids')::uuid[])
  AND (sqlc.narg('updated_after')::timestamptz IS NULL
       OR update_date > sqlc.narg('updated_after')::timestamptz)
ORDER BY update_date DESC;

-- name: SearchPins :many
SELECT p.id, p.latitude, p.longitude, p.creation_date, p.update_date,
       p.description, p.creator_id, p.group_id, p.state_province_id
FROM pins p
JOIN groups g ON g.id = p.group_id
WHERE p.is_deleted = FALSE
  AND g.is_deleted = FALSE
  AND (
      g.visibility = 0
      OR EXISTS (
          SELECT 1
          FROM members m
          WHERE m.group_id = g.id
            AND m.user_id = sqlc.arg('caller_id')::uuid
            AND m.is_deleted = FALSE
      )
  )
  AND (
      cardinality(sqlc.arg('ids')::uuid[]) = 0
      OR p.id = ANY(sqlc.arg('ids')::uuid[])
  )
  AND (
      sqlc.narg('group_id')::uuid IS NULL
      OR p.group_id = sqlc.narg('group_id')::uuid
  )
  AND (
      sqlc.narg('creator_id')::uuid IS NULL
      OR p.creator_id = sqlc.narg('creator_id')::uuid
  )
  AND (
      sqlc.narg('updated_after')::timestamptz IS NULL
      OR p.update_date > sqlc.narg('updated_after')::timestamptz
  )
ORDER BY p.creation_date DESC
LIMIT sqlc.arg('lim') OFFSET sqlc.arg('off');

-- name: ListDeletedPinsAfter :many
SELECT deleted_entity_id FROM delete_log
WHERE deleted_entity_type = 1 AND creation_date > $1
ORDER BY creation_date;

-- name: FindUsersWithNewPinsSinceLastActive :many
SELECT u.id, u.firebase_token, COUNT(DISTINCT p.id)::int AS pin_count
FROM users u
JOIN members m ON m.user_id = u.id AND m.is_deleted = FALSE
JOIN pins p ON m.group_id = p.group_id
WHERE p.creator_id != u.id
  AND u.is_deleted = FALSE
  AND u.firebase_token IS NOT NULL
  AND p.is_deleted = FALSE
  AND p.creation_date > (
      SELECT COALESCE(MAX(rt.last_active_date), NOW() - INTERVAL '7 days')
      FROM refresh_token rt
      WHERE rt.user_id = u.id
  )
GROUP BY u.id, u.firebase_token
HAVING COUNT(DISTINCT p.id) > 0;

-- name: FindBoundaryForPoint :one
SELECT id
FROM admin2_boundaries
ORDER BY
  ST_Contains(geom, ST_SetSRID(ST_Point($1, $2), 4326)) DESC,
  geom <-> ST_SetSRID(ST_Point($1, $2), 4326)
LIMIT 1;
