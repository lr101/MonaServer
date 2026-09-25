-- name: EnqueueObjectCleanup :exec
INSERT INTO object_cleanup_queue (object_key)
SELECT unnest(sqlc.arg('object_keys')::text[])
ON CONFLICT (object_key) DO NOTHING;

-- name: StageObjectCleanup :exec
INSERT INTO object_cleanup_queue (object_key, is_staged)
VALUES ($1, TRUE)
ON CONFLICT (object_key) DO UPDATE
SET is_staged = TRUE, created_at = NOW(), next_attempt_at = NOW();

-- name: MarkObjectCleanupReady :exec
UPDATE object_cleanup_queue
SET is_staged = FALSE, created_at = NOW(), next_attempt_at = NOW()
WHERE object_key = $1;

-- name: RescheduleObjectCleanup :exec
UPDATE object_cleanup_queue
SET is_staged = FALSE, next_attempt_at = NOW() + INTERVAL '1 minute'
WHERE object_key = $1;

-- name: LockStagedObjectCleanup :one
SELECT object_key
FROM object_cleanup_queue
WHERE object_key = $1 AND is_staged = TRUE
FOR UPDATE;

-- name: ClaimPendingObjectCleanup :one
SELECT object_key
FROM object_cleanup_queue
WHERE (is_staged = FALSE AND next_attempt_at <= NOW())
   OR (is_staged = TRUE AND created_at <= NOW() - INTERVAL '30 minutes')
ORDER BY next_attempt_at, created_at, object_key
LIMIT 1
FOR UPDATE SKIP LOCKED;

-- name: DeletePendingObjectCleanup :exec
DELETE FROM object_cleanup_queue
WHERE object_key = $1;
