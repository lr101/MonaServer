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

-- name: ListDeletedPinsAfter :many
SELECT deleted_entity_id FROM delete_log
WHERE deleted_entity_type = 3 AND creation_date > $1
ORDER BY creation_date;

-- name: FindBoundaryForPoint :one
SELECT id FROM admin2_boundaries
WHERE ST_Contains(geom, ST_SetSRID(ST_Point($1, $2), 4326))
LIMIT 1;
