ALTER TABLE users
    ADD COLUMN IF NOT EXISTS email_confirmation_sent_at timestamp with time zone;

UPDATE users
SET email_confirmation_sent_at = email_confirmation_expires_at - INTERVAL '24 hours'
WHERE email_confirmation_url IS NOT NULL
  AND email_confirmation_expires_at IS NOT NULL
  AND email_confirmation_sent_at IS NULL;
