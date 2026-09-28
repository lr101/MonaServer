ALTER TABLE admin_jobs
    ADD COLUMN IF NOT EXISTS recent_mfa_at timestamp with time zone,
    ADD COLUMN IF NOT EXISTS recent_mfa_action varchar(64);

ALTER TABLE admin_jobs
    ADD CONSTRAINT admin_jobs_recent_mfa_pair_check
    CHECK ((recent_mfa_at IS NULL AND recent_mfa_action IS NULL)
        OR (recent_mfa_at IS NOT NULL AND recent_mfa_action IS NOT NULL AND btrim(recent_mfa_action) <> ''));
