-- A local development database may already have the initial photo-history
-- migration from before upload retries were added. Keep both fresh and
-- already-migrated databases compatible.
ALTER TABLE pin_photos
    ADD COLUMN IF NOT EXISTS idempotency_key UUID,
    ADD COLUMN IF NOT EXISTS request_hash BYTEA;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'pin_photos_idempotency_pair_check'
    ) THEN
        ALTER TABLE pin_photos
            ADD CONSTRAINT pin_photos_idempotency_pair_check
            CHECK ((idempotency_key IS NULL) = (request_hash IS NULL));
    END IF;
END
$$;

CREATE UNIQUE INDEX IF NOT EXISTS pin_photos_contributor_idempotency_idx
    ON pin_photos (contributor_id, idempotency_key)
    WHERE idempotency_key IS NOT NULL;
