CREATE TABLE pin_create_idempotency (
    caller_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    idempotency_key UUID NOT NULL,
    request_hash BYTEA NOT NULL,
    pin_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (caller_id, idempotency_key)
);

CREATE INDEX pin_create_idempotency_pin_idx ON pin_create_idempotency (pin_id);
