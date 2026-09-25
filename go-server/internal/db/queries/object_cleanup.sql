-- name: EnqueueObjectCleanup :exec
INSERT INTO object_cleanup_queue (object_key)
SELECT unnest(sqlc.arg('object_keys')::text[])
ON CONFLICT (object_key) DO NOTHING;

-- name: ListPendingObjectCleanup :many
SELECT object_key
FROM object_cleanup_queue
ORDER BY created_at, object_key
LIMIT sqlc.arg('page_limit')::int;

-- name: DeletePendingObjectCleanup :exec
DELETE FROM object_cleanup_queue
WHERE object_key = $1;
