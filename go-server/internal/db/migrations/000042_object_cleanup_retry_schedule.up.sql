ALTER TABLE object_cleanup_queue
    ADD COLUMN next_attempt_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

CREATE INDEX object_cleanup_queue_retry_idx
    ON object_cleanup_queue (next_attempt_at, created_at, object_key);
