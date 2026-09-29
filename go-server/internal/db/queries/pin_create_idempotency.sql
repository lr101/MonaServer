-- name: ClaimPinCreateIdempotency :execrows
INSERT INTO pin_create_idempotency (caller_id, idempotency_key, request_hash)
VALUES ($1, $2, $3)
ON CONFLICT (caller_id, idempotency_key) DO NOTHING;

-- name: GetPinCreateIdempotencyForUpdate :one
SELECT request_hash, pin_id
FROM pin_create_idempotency
WHERE caller_id = $1 AND idempotency_key = $2
FOR UPDATE;

-- name: FinishPinCreateIdempotency :execrows
UPDATE pin_create_idempotency SET pin_id = $3
WHERE caller_id = $1 AND idempotency_key = $2 AND pin_id IS NULL;
