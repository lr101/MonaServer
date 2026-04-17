-- Group + member queries.

-- name: CreateGroup :exec
INSERT INTO groups (id, name, description, link, visibility, admin_id, invite_url, creation_date, update_date)
VALUES ($1, $2, $3, $4, $5, $6, $7, NOW(), NOW());

-- name: GetGroupByID :one
SELECT id, name, description, link, visibility, admin_id, invite_url,
       creation_date, update_date
FROM groups
WHERE id = $1 AND is_deleted = FALSE;

-- name: GroupExistsByName :one
SELECT EXISTS (SELECT 1 FROM groups WHERE name = $1 AND is_deleted = FALSE);

-- name: GetGroupAdminUsername :one
SELECT u.username
FROM groups g JOIN users u ON u.id = g.admin_id
WHERE g.id = $1 AND g.is_deleted = FALSE;

-- name: UpdateGroup :exec
UPDATE groups
SET name       = COALESCE(sqlc.narg('name'),       name),
    description= COALESCE(sqlc.narg('description'),description),
    link       = COALESCE(sqlc.narg('link'),       link),
    visibility = COALESCE(sqlc.narg('visibility'), visibility),
    admin_id   = COALESCE(sqlc.narg('admin_id'),   admin_id),
    invite_url = COALESCE(sqlc.narg('invite_url'), invite_url),
    update_date= NOW()
WHERE id = sqlc.arg('id');

-- name: SetGroupInviteUrl :exec
UPDATE groups SET invite_url = $2, update_date = NOW() WHERE id = $1;

-- name: SoftDeleteGroup :exec
UPDATE groups SET is_deleted = TRUE, update_date = NOW() WHERE id = $1;

-- name: SearchGroups :many
SELECT id, name, description, link, visibility, admin_id, invite_url,
       creation_date, update_date
FROM groups
WHERE is_deleted = FALSE
  AND (sqlc.narg('search')::text IS NULL OR name ILIKE '%' || sqlc.narg('search')::text || '%')
  AND (sqlc.narg('updated_after')::timestamptz IS NULL OR update_date > sqlc.narg('updated_after')::timestamptz)
ORDER BY name
LIMIT sqlc.arg('lim') OFFSET sqlc.arg('off');

-- name: SearchGroupsInUser :many
SELECT g.id, g.name, g.description, g.link, g.visibility, g.admin_id, g.invite_url,
       g.creation_date, g.update_date
FROM groups g
JOIN members m ON m.group_id = g.id
WHERE g.is_deleted = FALSE AND m.user_id = sqlc.arg('user_id')
  AND (sqlc.narg('search')::text IS NULL OR g.name ILIKE '%' || sqlc.narg('search')::text || '%')
  AND (sqlc.narg('updated_after')::timestamptz IS NULL OR g.update_date > sqlc.narg('updated_after')::timestamptz)
ORDER BY g.name
LIMIT sqlc.arg('lim') OFFSET sqlc.arg('off');

-- name: SearchGroupsNotInUser :many
SELECT g.id, g.name, g.description, g.link, g.visibility, g.admin_id, g.invite_url,
       g.creation_date, g.update_date
FROM groups g
WHERE g.is_deleted = FALSE
  AND NOT EXISTS (SELECT 1 FROM members m WHERE m.group_id = g.id AND m.user_id = sqlc.arg('user_id'))
  AND (sqlc.narg('search')::text IS NULL OR g.name ILIKE '%' || sqlc.narg('search')::text || '%')
  AND (sqlc.narg('updated_after')::timestamptz IS NULL OR g.update_date > sqlc.narg('updated_after')::timestamptz)
ORDER BY g.name
LIMIT sqlc.arg('lim') OFFSET sqlc.arg('off');

-- Members --

-- name: AddMember :exec
INSERT INTO members (group_id, user_id, creation_date, update_date)
VALUES ($1, $2, NOW(), NOW())
ON CONFLICT DO NOTHING;

-- name: RemoveMember :exec
DELETE FROM members WHERE group_id = $1 AND user_id = $2;

-- name: ListGroupMembers :many
SELECT m.user_id, u.username, (g.admin_id = m.user_id) AS is_admin
FROM members m
JOIN users u ON u.id = m.user_id
JOIN groups g ON g.id = m.group_id
WHERE m.group_id = $1 AND g.is_deleted = FALSE
ORDER BY u.username;

-- name: CountGroupMembers :one
SELECT COUNT(*)::bigint FROM members WHERE group_id = $1;

-- name: GetGroupRanking :many
SELECT m.user_id, u.username,
       COUNT(pg.creator_id)::int AS points,
       ua.achievement_id
FROM members m
LEFT JOIN (
    SELECT p.id, p.creator_id FROM pins p WHERE p.group_id = $1 AND p.is_deleted = FALSE
) AS pg ON pg.creator_id = m.user_id
JOIN users u ON u.id = m.user_id
LEFT JOIN user_achievement ua ON u.selected_batch = ua.id
WHERE m.group_id = $1
GROUP BY m.user_id, u.username, ua.achievement_id
ORDER BY points DESC, m.user_id;

-- name: IsMember :one
SELECT EXISTS (SELECT 1 FROM members WHERE group_id = $1 AND user_id = $2);

-- Delete log --

-- name: ListDeletedGroupsAfter :many
SELECT deleted_entity_id FROM delete_log
WHERE deleted_entity_type = 2 AND creation_date > $1
ORDER BY creation_date;

-- name: LogDeletion :exec
INSERT INTO delete_log (deleted_entity_type, deleted_entity_id, creation_date)
VALUES ($1, $2, NOW())
ON CONFLICT DO NOTHING;
