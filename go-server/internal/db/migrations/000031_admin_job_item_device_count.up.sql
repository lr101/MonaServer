ALTER TABLE admin_job_items
    ADD COLUMN IF NOT EXISTS device_count integer NOT NULL DEFAULT 0;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'admin_job_items_device_count_check'
          AND conrelid = 'admin_job_items'::regclass
    ) THEN
        ALTER TABLE admin_job_items
            ADD CONSTRAINT admin_job_items_device_count_check CHECK (device_count >= 0);
    END IF;
END
$$;
