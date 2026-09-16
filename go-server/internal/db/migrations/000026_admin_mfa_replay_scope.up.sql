-- Keep the TOTP moving factor at the membership/user enrollment boundary.
-- A session-scoped counter permits the same code to be replayed through a
-- second browser session, so this table is shared by every session for one
-- stable membership and user.
CREATE TABLE IF NOT EXISTS admin_mfa_replay_scopes
(
    membership_id uuid NOT NULL REFERENCES admin_memberships(id) ON DELETE CASCADE,
    user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    last_counter bigint NOT NULL DEFAULT -1,
    updated_at timestamp with time zone NOT NULL DEFAULT now(),
    PRIMARY KEY (membership_id, user_id),
    CONSTRAINT admin_mfa_replay_scopes_membership_unique UNIQUE (membership_id),
    CONSTRAINT admin_mfa_replay_scopes_nonnegative_check CHECK (last_counter >= -1)
);

CREATE INDEX IF NOT EXISTS idx_admin_mfa_replay_scopes_user
    ON admin_mfa_replay_scopes (user_id);
