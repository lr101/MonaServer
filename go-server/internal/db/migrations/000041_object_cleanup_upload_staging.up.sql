ALTER TABLE object_cleanup_queue
    ADD COLUMN is_staged BOOLEAN NOT NULL DEFAULT FALSE;
