-- Content-only campaign persistence. Campaigns have no audience, provider,
-- queue, recipient, or delivery state in this release.

-- name: CreateCampaign :one
INSERT INTO campaigns (id, name, channel, subject, title, body, status, created_by_user_id)
VALUES (
    sqlc.arg('id')::uuid,
    sqlc.arg('name')::text,
    sqlc.arg('channel')::text,
    sqlc.narg('subject')::text,
    sqlc.narg('title')::text,
    sqlc.arg('body')::text,
    sqlc.arg('status')::text,
    sqlc.arg('created_by_user_id')::uuid
)
RETURNING id, name, channel, subject, title, body, status, revision, created_at, updated_at, created_by_user_id;

-- name: GetCampaign :one
SELECT id, name, channel, subject, title, body, status, revision, created_at, updated_at, created_by_user_id
FROM campaigns
WHERE id = sqlc.arg('id')::uuid;

-- name: ListCampaigns :many
SELECT id, name, channel, subject, title, body, status, revision, created_at, updated_at, created_by_user_id
FROM campaigns
WHERE sqlc.narg('before_created_at')::timestamptz IS NULL
   OR (created_at, id) < (sqlc.narg('before_created_at')::timestamptz, sqlc.narg('before_id')::uuid)
ORDER BY created_at DESC, id DESC
LIMIT sqlc.arg('page_limit')::integer;

-- name: UpdateCampaignIfRevision :one
UPDATE campaigns
SET name = sqlc.arg('name')::text,
    channel = sqlc.arg('channel')::text,
    subject = sqlc.narg('subject')::text,
    title = sqlc.narg('title')::text,
    body = sqlc.arg('body')::text,
    status = sqlc.arg('status')::text,
    revision = revision + 1,
    updated_at = now()
WHERE id = sqlc.arg('id')::uuid
  AND revision = sqlc.arg('expected_revision')::bigint
RETURNING id, name, channel, subject, title, body, status, revision, created_at, updated_at, created_by_user_id;

-- name: DeleteCampaignIfRevision :execrows
DELETE FROM campaigns
WHERE id = sqlc.arg('id')::uuid
  AND revision = sqlc.arg('expected_revision')::bigint
  AND status = 'draft';
