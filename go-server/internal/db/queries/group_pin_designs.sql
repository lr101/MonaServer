-- name: GetGroupPinDesignCatalog :one
SELECT revision, designs
FROM group_pin_designs
WHERE group_id = $1;

-- name: UpdateGroupPinDesignCatalog :one
INSERT INTO group_pin_designs AS stored (
    group_id, revision, designs
)
SELECT sqlc.arg(group_id), 2, sqlc.arg(designs)
WHERE sqlc.arg(expected_revision)::bigint = 1
ON CONFLICT (group_id) DO UPDATE
SET revision = stored.revision + 1,
    designs = EXCLUDED.designs,
    updated_at = now()
WHERE stored.revision = sqlc.arg(expected_revision)
RETURNING revision, designs;
