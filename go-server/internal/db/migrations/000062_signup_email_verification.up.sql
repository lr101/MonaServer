ALTER TABLE users
    ADD COLUMN IF NOT EXISTS account_activated boolean NOT NULL DEFAULT TRUE,
    ADD COLUMN IF NOT EXISTS email_confirmation_expires_at timestamp with time zone;

-- Preserve old users as active during rollout. Existing confirmation links,
-- when present, still get a bounded lifetime.
UPDATE users
SET email_confirmation_expires_at = NOW() + INTERVAL '24 hours'
WHERE email_confirmation_url IS NOT NULL
  AND email_confirmation_expires_at IS NULL;
