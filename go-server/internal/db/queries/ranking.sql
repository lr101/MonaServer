-- Ranking and map queries (PostGIS).

-- name: GetUserRanking :many
SELECT p.creator_id, u.username, u.description,
       COUNT(p.creator_id)::int AS points,
       ua.achievement_id
FROM pins p
JOIN users u ON p.creator_id = u.id
LEFT JOIN user_achievement ua ON u.selected_batch = ua.id
JOIN admin2_boundaries b ON p.state_province_id = b.id
WHERE p.is_deleted = FALSE
  AND (sqlc.narg('gid0')::text IS NULL OR b.gid_0 = sqlc.narg('gid0')::text)
  AND (sqlc.narg('gid1')::text IS NULL OR b.gid_1 = sqlc.narg('gid1')::text)
  AND (sqlc.narg('gid2')::text IS NULL OR b.gid_2 = sqlc.narg('gid2')::text)
  AND (sqlc.narg('since')::timestamptz IS NULL OR p.creation_date > sqlc.narg('since')::timestamptz)
GROUP BY p.creator_id, u.username, u.description, ua.achievement_id
ORDER BY points DESC, u.username
LIMIT sqlc.arg('lim') OFFSET sqlc.arg('off');

-- name: GetGlobalGroupRanking :many
SELECT p.group_id, g.name, g.visibility, g.description,
       COUNT(p.group_id)::int AS points
FROM pins p
JOIN groups g ON p.group_id = g.id AND g.is_deleted = FALSE
JOIN admin2_boundaries b ON p.state_province_id = b.id
WHERE p.is_deleted = FALSE
  AND (sqlc.narg('gid0')::text IS NULL OR b.gid_0 = sqlc.narg('gid0')::text)
  AND (sqlc.narg('gid1')::text IS NULL OR b.gid_1 = sqlc.narg('gid1')::text)
  AND (sqlc.narg('gid2')::text IS NULL OR b.gid_2 = sqlc.narg('gid2')::text)
  AND (sqlc.narg('since')::timestamptz IS NULL OR p.creation_date > sqlc.narg('since')::timestamptz)
GROUP BY p.group_id, g.name, g.visibility, g.description
ORDER BY points DESC, g.name
LIMIT sqlc.arg('lim') OFFSET sqlc.arg('off');

-- name: GetGeoJson :many
SELECT ST_AsGeoJSON(geom)
FROM admin2_boundaries
WHERE (sqlc.narg('gid0')::text IS NULL OR gid_0 = sqlc.narg('gid0')::text)
  AND (sqlc.narg('gid1')::text IS NULL OR gid_1 = sqlc.narg('gid1')::text)
  AND (sqlc.narg('gid2')::text IS NULL OR gid_2 = sqlc.narg('gid2')::text);

-- name: GetMapInfo :one
SELECT id, gid_0, gid_1, gid_2, name_0, name_1, name_2
FROM admin2_boundaries
WHERE ST_Contains(geom, ST_SetSRID(ST_Point($1, $2), 4326))
   OR id = (
       SELECT a.id FROM admin2_boundaries a
       ORDER BY ST_Distance(a.geom, ST_SetSRID(ST_Point($1, $2), 4326))
       LIMIT 1
   )
LIMIT 1;

-- name: SearchBoundaries :many
SELECT 0 AS level, gid_0 AS gid, name_0 AS name
FROM admin2_boundaries
WHERE (sqlc.narg('search')::text IS NULL OR name_0 ILIKE '%' || sqlc.narg('search')::text || '%')
GROUP BY gid_0, name_0
UNION ALL
SELECT 1 AS level, gid_1 AS gid, name_1 AS name
FROM admin2_boundaries
WHERE (sqlc.narg('search')::text IS NULL OR name_1 ILIKE '%' || sqlc.narg('search')::text || '%')
GROUP BY gid_1, name_1
UNION ALL
SELECT 2 AS level, gid_2 AS gid, name_2 AS name
FROM admin2_boundaries
WHERE (sqlc.narg('search')::text IS NULL OR name_2 ILIKE '%' || sqlc.narg('search')::text || '%')
ORDER BY level, gid
LIMIT sqlc.arg('lim') OFFSET sqlc.arg('off');
