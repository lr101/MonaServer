-- A recent MFA proof is scoped to the session and the action it authorized.
-- NULL is retained for the initial login proof, which is a fresh
-- authentication and may authorize the first mutation of the session.
ALTER TABLE admin_sessions
    ADD COLUMN IF NOT EXISTS recent_mfa_action varchar(128);
