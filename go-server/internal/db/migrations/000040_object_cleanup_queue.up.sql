CREATE TABLE object_cleanup_queue (
    object_key TEXT PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX object_cleanup_queue_created_idx
    ON object_cleanup_queue (created_at, object_key);
