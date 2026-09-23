-- Web administration and email-link login storage.
--
-- This migration is deliberately additive.  In particular, users.email stays
-- non-unique: old installations can contain mixed-case and duplicate values.
-- email_login_claims is the eligibility boundary for the new email flow.

ALTER TABLE users ADD COLUMN IF NOT EXISTS auth_generation bigint NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN IF NOT EXISTS security_state varchar(48) NOT NULL DEFAULT 'normal';
ALTER TABLE users ADD COLUMN IF NOT EXISTS password_disabled boolean NOT NULL DEFAULT false;
ALTER TABLE users ADD COLUMN IF NOT EXISTS password_reset_required boolean NOT NULL DEFAULT false;
ALTER TABLE users ADD COLUMN IF NOT EXISTS compromised_at timestamp with time zone;

CREATE INDEX IF NOT EXISTS idx_users_canonical_email
    ON users (lower(btrim(email)))
    WHERE is_deleted = FALSE AND email IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_users_security_state
    ON users (security_state, is_deleted, id);
CREATE INDEX IF NOT EXISTS idx_users_auth_generation
    ON users (id, auth_generation);

CREATE TABLE IF NOT EXISTS email_login_claims
(
    canonical_email varchar(320) NOT NULL PRIMARY KEY,
    owner_user_id uuid REFERENCES users(id) ON DELETE SET NULL,
    state varchar(16) NOT NULL DEFAULT 'available',
    is_ambiguous boolean NOT NULL DEFAULT false,
    blocked_reason varchar(64),
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    updated_at timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT email_login_claims_state_check
        CHECK (state IN ('available', 'owned', 'blocked')),
    CONSTRAINT email_login_claims_owner_check
        CHECK ((state = 'owned' AND owner_user_id IS NOT NULL)
            OR (state IN ('available', 'blocked') AND owner_user_id IS NULL)),
    CONSTRAINT email_login_claims_ambiguity_check
        CHECK (is_ambiguous = (state = 'blocked'))
);

-- Populate only from active, verified rows.  A duplicate group is retained as
-- one blocked claim with no owner, so startup never depends on a failing
-- uniqueness constraint or an administrator choosing a winner.
INSERT INTO email_login_claims
    (canonical_email, owner_user_id, state, is_ambiguous, blocked_reason)
SELECT
    lower(btrim(email)),
    CASE WHEN count(*) = 1 THEN (array_agg(id ORDER BY id))[1] ELSE NULL END,
    CASE WHEN count(*) = 1 THEN 'owned' ELSE 'blocked' END,
    count(*) > 1,
    CASE WHEN count(*) > 1 THEN 'duplicate_verified_accounts' ELSE NULL END
FROM users
WHERE is_deleted = FALSE
  AND email_confirmed = TRUE
  AND email IS NOT NULL
  AND btrim(email) <> ''
GROUP BY lower(btrim(email))
ON CONFLICT (canonical_email) DO UPDATE
SET owner_user_id = EXCLUDED.owner_user_id,
    state = EXCLUDED.state,
    is_ambiguous = EXCLUDED.is_ambiguous,
    blocked_reason = EXCLUDED.blocked_reason,
    updated_at = now();

CREATE INDEX IF NOT EXISTS idx_email_login_claims_owner
    ON email_login_claims (owner_user_id)
    WHERE owner_user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_email_login_claims_blocked
    ON email_login_claims (state, canonical_email)
    WHERE state = 'blocked';

CREATE TABLE IF NOT EXISTS delivery_attempts
(
    id uuid NOT NULL PRIMARY KEY,
    channel varchar(24) NOT NULL,
    account_id uuid,
    device_id uuid,
    job_id uuid,
    item_id uuid,
    status varchar(32) NOT NULL DEFAULT 'pending',
    attempt_number integer NOT NULL DEFAULT 0,
    provider_reference varchar(255),
    provider_outcome varchar(32),
    error_code varchar(64),
    encrypted_payload bytea,
    delivery_key_id varchar(128),
    payload_expires_at timestamp with time zone,
    accepted_at timestamp with time zone,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    updated_at timestamp with time zone NOT NULL DEFAULT now(),
    lease_owner varchar(255),
    lease_token uuid,
    lease_until timestamp with time zone,
    CONSTRAINT delivery_attempts_attempt_number_check CHECK (attempt_number >= 0)
);

CREATE INDEX IF NOT EXISTS idx_delivery_attempts_account
    ON delivery_attempts (account_id, channel, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_delivery_attempts_pending
    ON delivery_attempts (status, lease_until, created_at)
    WHERE status IN ('pending', 'unknown_delivery');

CREATE TABLE IF NOT EXISTS account_action_tokens
(
    id uuid NOT NULL PRIMARY KEY,
    token_hash bytea NOT NULL UNIQUE,
    purpose varchar(64) NOT NULL,
    account_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    email_binding varchar(320),
    auth_generation bigint NOT NULL DEFAULT 0,
    expires_at timestamp with time zone NOT NULL,
    consumed_at timestamp with time zone,
    revoked_at timestamp with time zone,
    delivery_attempt_id uuid REFERENCES delivery_attempts(id) ON DELETE SET NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    updated_at timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT account_action_tokens_state_check
        CHECK (consumed_at IS NULL OR revoked_at IS NULL)
);

CREATE INDEX IF NOT EXISTS idx_account_action_tokens_active
    ON account_action_tokens (account_id, purpose, expires_at)
    WHERE consumed_at IS NULL AND revoked_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_account_action_tokens_expiry
    ON account_action_tokens (expires_at);

CREATE TABLE IF NOT EXISTS admin_memberships
(
    id uuid NOT NULL PRIMARY KEY,
    user_id uuid NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    permissions text[] NOT NULL DEFAULT '{}',
    active boolean NOT NULL DEFAULT true,
    totp_secret_ciphertext bytea,
    totp_key_id varchar(128),
    totp_enrolled_at timestamp with time zone,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    updated_at timestamp with time zone NOT NULL DEFAULT now(),
    revoked_at timestamp with time zone
);

CREATE INDEX IF NOT EXISTS idx_admin_memberships_permissions
    ON admin_memberships USING GIN (permissions)
    WHERE active = TRUE;

CREATE TABLE IF NOT EXISTS admin_sessions
(
    id uuid NOT NULL PRIMARY KEY,
    session_hash bytea NOT NULL UNIQUE,
    user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    csrf_hash bytea NOT NULL,
    state varchar(24) NOT NULL DEFAULT 'pre_auth',
    auth_generation bigint NOT NULL DEFAULT 0,
    issued_at timestamp with time zone NOT NULL DEFAULT now(),
    last_seen_at timestamp with time zone NOT NULL DEFAULT now(),
    idle_expires_at timestamp with time zone NOT NULL,
    absolute_expires_at timestamp with time zone NOT NULL,
    recent_mfa_at timestamp with time zone,
    revoked_at timestamp with time zone,
    CONSTRAINT admin_sessions_state_check
        CHECK (state IN ('pre_auth', 'authenticated', 'revoked'))
);

CREATE INDEX IF NOT EXISTS idx_admin_sessions_user
    ON admin_sessions (user_id, revoked_at, absolute_expires_at);
CREATE INDEX IF NOT EXISTS idx_admin_sessions_expiry
    ON admin_sessions (idle_expires_at, absolute_expires_at)
    WHERE revoked_at IS NULL;

CREATE TABLE IF NOT EXISTS admin_login_challenges
(
    id uuid NOT NULL PRIMARY KEY,
    challenge_hash bytea NOT NULL UNIQUE,
    user_id uuid REFERENCES users(id) ON DELETE CASCADE,
    ip_hmac bytea,
    failed_attempts integer NOT NULL DEFAULT 0,
    auth_generation bigint NOT NULL DEFAULT 0,
    expires_at timestamp with time zone NOT NULL,
    consumed_at timestamp with time zone,
    revoked_at timestamp with time zone,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT admin_login_challenges_attempts_check CHECK (failed_attempts >= 0),
    CONSTRAINT admin_login_challenges_state_check
        CHECK (consumed_at IS NULL OR revoked_at IS NULL)
);

CREATE INDEX IF NOT EXISTS idx_admin_login_challenges_active
    ON admin_login_challenges (user_id, expires_at)
    WHERE consumed_at IS NULL AND revoked_at IS NULL;

CREATE TABLE IF NOT EXISTS admin_mfa_replay_counters
(
    session_id uuid NOT NULL PRIMARY KEY REFERENCES admin_sessions(id) ON DELETE CASCADE,
    last_counter bigint NOT NULL DEFAULT -1,
    updated_at timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT admin_mfa_replay_counters_nonnegative_check CHECK (last_counter >= -1)
);

CREATE TABLE IF NOT EXISTS security_incidents
(
    id uuid NOT NULL PRIMARY KEY,
    account_id uuid NOT NULL,
    actor_id uuid REFERENCES users(id) ON DELETE SET NULL,
    reason varchar(2000) NOT NULL,
    previous_state varchar(48),
    new_state varchar(48) NOT NULL,
    auth_generation bigint NOT NULL,
    metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamp with time zone NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_security_incidents_account
    ON security_incidents (account_id, created_at DESC);

CREATE TABLE IF NOT EXISTS audit_events
(
    id uuid NOT NULL PRIMARY KEY,
    actor_id uuid REFERENCES users(id) ON DELETE SET NULL,
    target_account_id uuid,
    action varchar(64) NOT NULL,
    reason varchar(2000),
    outcome varchar(64),
    metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamp with time zone NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_audit_events_created
    ON audit_events (created_at DESC, id DESC);
CREATE INDEX IF NOT EXISTS idx_audit_events_actor
    ON audit_events (actor_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_events_target
    ON audit_events (target_account_id, created_at DESC);

CREATE TABLE IF NOT EXISTS rate_limit_buckets
(
    scope varchar(64) NOT NULL,
    identifier_hmac bytea NOT NULL,
    key_id varchar(128) NOT NULL,
    window_start timestamp with time zone NOT NULL,
    window_end timestamp with time zone NOT NULL,
    hit_count bigint NOT NULL DEFAULT 0,
    updated_at timestamp with time zone NOT NULL DEFAULT now(),
    PRIMARY KEY (scope, identifier_hmac, window_start),
    CONSTRAINT rate_limit_buckets_count_check CHECK (hit_count >= 0),
    CONSTRAINT rate_limit_buckets_window_check CHECK (window_end > window_start)
);

CREATE INDEX IF NOT EXISTS idx_rate_limit_buckets_expiry
    ON rate_limit_buckets (window_end);


CREATE TABLE IF NOT EXISTS reports
(
    id uuid NOT NULL PRIMARY KEY,
    reporter_user_id uuid REFERENCES users(id) ON DELETE SET NULL,
    target_id uuid,
    target_kind varchar(32),
    target_name varchar(255),
    target_deleted boolean NOT NULL DEFAULT false,
    body text NOT NULL,
    legacy_text text,
    status varchar(16) NOT NULL DEFAULT 'open',
    assignee_user_id uuid REFERENCES users(id) ON DELETE SET NULL,
    revision bigint NOT NULL DEFAULT 1,
    request_id varchar(255),
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    updated_at timestamp with time zone NOT NULL DEFAULT now(),
    resolved_at timestamp with time zone,
    CONSTRAINT reports_status_check CHECK (status IN ('open', 'resolved', 'dismissed')),
    CONSTRAINT reports_revision_check CHECK (revision > 0)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_reports_request_id
    ON reports (request_id)
    WHERE request_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_reports_inbox
    ON reports (status, created_at DESC, id DESC);
CREATE INDEX IF NOT EXISTS idx_reports_reporter
    ON reports (reporter_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_reports_target
    ON reports (target_id, target_kind);

CREATE TABLE IF NOT EXISTS report_notes
(
    id uuid NOT NULL PRIMARY KEY,
    report_id uuid NOT NULL REFERENCES reports(id) ON DELETE CASCADE,
    author_user_id uuid REFERENCES users(id) ON DELETE SET NULL,
    body text NOT NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_report_notes_report
    ON report_notes (report_id, created_at, id);

CREATE TABLE IF NOT EXISTS audience_snapshots
(
    id uuid NOT NULL PRIMARY KEY,
    actor_id uuid REFERENCES users(id) ON DELETE SET NULL,
    resource varchar(16) NOT NULL,
    action varchar(64) NOT NULL,
    payload_hash bytea NOT NULL,
    filter jsonb,
    status varchar(24) NOT NULL DEFAULT 'ready',
    account_count bigint NOT NULL DEFAULT 0,
    eligible_count bigint NOT NULL DEFAULT 0,
    device_count bigint NOT NULL DEFAULT 0,
    exclusion_count bigint NOT NULL DEFAULT 0,
    expires_at timestamp with time zone NOT NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    updated_at timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT audience_snapshots_resource_check CHECK (resource IN ('accounts', 'reports')),
    CONSTRAINT audience_snapshots_counts_check
        CHECK (account_count >= 0 AND eligible_count >= 0 AND device_count >= 0
            AND exclusion_count >= 0)
);

CREATE INDEX IF NOT EXISTS idx_audience_snapshots_actor
    ON audience_snapshots (actor_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audience_snapshots_expiry
    ON audience_snapshots (expires_at);

CREATE TABLE IF NOT EXISTS audience_snapshot_members
(
    snapshot_id uuid NOT NULL REFERENCES audience_snapshots(id) ON DELETE CASCADE,
    ordinal bigint NOT NULL,
    resource_id uuid NOT NULL,
    eligible boolean NOT NULL DEFAULT true,
    exclusion_code varchar(64),
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    PRIMARY KEY (snapshot_id, resource_id),
    CONSTRAINT audience_snapshot_members_ordinal_check CHECK (ordinal >= 0)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_audience_snapshot_members_order
    ON audience_snapshot_members (snapshot_id, ordinal, resource_id);
CREATE INDEX IF NOT EXISTS idx_audience_snapshot_members_page
    ON audience_snapshot_members (snapshot_id, ordinal, resource_id)
    INCLUDE (eligible, exclusion_code);

CREATE TABLE IF NOT EXISTS admin_jobs
(
    id uuid NOT NULL PRIMARY KEY,
    actor_id uuid REFERENCES users(id) ON DELETE SET NULL,
    snapshot_id uuid REFERENCES audience_snapshots(id) ON DELETE RESTRICT,
    action varchar(64) NOT NULL,
    payload_hash bytea NOT NULL,
    idempotency_key varchar(255) NOT NULL UNIQUE,
    status varchar(32) NOT NULL DEFAULT 'pending',
    account_count bigint NOT NULL DEFAULT 0,
    eligible_count bigint NOT NULL DEFAULT 0,
    device_count bigint NOT NULL DEFAULT 0,
    completed_count bigint NOT NULL DEFAULT 0,
    failed_count bigint NOT NULL DEFAULT 0,
    reason varchar(2000),
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    updated_at timestamp with time zone NOT NULL DEFAULT now(),
    started_at timestamp with time zone,
    completed_at timestamp with time zone,
    CONSTRAINT admin_jobs_status_check
        CHECK (status IN ('pending', 'running', 'completed', 'completed_with_errors', 'paused', 'cancelled')),
    CONSTRAINT admin_jobs_counts_check
        CHECK (account_count >= 0 AND eligible_count >= 0 AND device_count >= 0
            AND completed_count >= 0 AND failed_count >= 0)
);

CREATE INDEX IF NOT EXISTS idx_admin_jobs_actor
    ON admin_jobs (actor_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_admin_jobs_status
    ON admin_jobs (status, created_at, id);

CREATE TABLE IF NOT EXISTS admin_job_items
(
    id uuid NOT NULL PRIMARY KEY,
    job_id uuid NOT NULL REFERENCES admin_jobs(id) ON DELETE CASCADE,
    target_id uuid NOT NULL,
    device_id uuid,
    outcome varchar(32) NOT NULL DEFAULT 'queued',
    error_code varchar(64),
    provider_reference varchar(255),
    attempt_count integer NOT NULL DEFAULT 0,
    lease_owner varchar(255),
    lease_token uuid,
    lease_until timestamp with time zone,
    completed_at timestamp with time zone,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    updated_at timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT admin_job_items_attempt_check CHECK (attempt_count >= 0),
    CONSTRAINT admin_job_items_outcome_check
        CHECK (outcome IN ('skipped', 'secured', 'queued', 'provider_accepted', 'failed', 'unknown_delivery'))
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_admin_job_items_unique_recipient
    ON admin_job_items (job_id, target_id, COALESCE(device_id, '00000000-0000-0000-0000-000000000000'::uuid));
CREATE INDEX IF NOT EXISTS idx_admin_job_items_page
    ON admin_job_items (job_id, created_at, id);
CREATE INDEX IF NOT EXISTS idx_admin_job_items_lease
    ON admin_job_items (job_id, lease_until, created_at)
    WHERE outcome IN ('queued', 'unknown_delivery');

CREATE TABLE IF NOT EXISTS durable_jobs
(
    id uuid NOT NULL PRIMARY KEY,
    kind varchar(64) NOT NULL,
    idempotency_key varchar(255) NOT NULL,
    payload jsonb NOT NULL DEFAULT '{}'::jsonb,
    priority integer NOT NULL DEFAULT 0,
    status varchar(24) NOT NULL DEFAULT 'pending',
    available_at timestamp with time zone NOT NULL DEFAULT now(),
    attempt_count integer NOT NULL DEFAULT 0,
    max_attempts integer NOT NULL DEFAULT 5,
    lease_owner varchar(255),
    lease_token uuid,
    lease_until timestamp with time zone,
    last_error varchar(512),
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    updated_at timestamp with time zone NOT NULL DEFAULT now(),
    started_at timestamp with time zone,
    completed_at timestamp with time zone,
    CONSTRAINT durable_jobs_kind_key UNIQUE (kind, idempotency_key),
    CONSTRAINT durable_jobs_attempt_check CHECK (attempt_count >= 0 AND max_attempts > 0),
    CONSTRAINT durable_jobs_status_check
        CHECK (status IN ('pending', 'running', 'completed', 'failed', 'cancelled'))
);

CREATE INDEX IF NOT EXISTS idx_durable_jobs_claim
    ON durable_jobs (priority DESC, available_at, created_at, id)
    WHERE status IN ('pending', 'running');
CREATE INDEX IF NOT EXISTS idx_durable_jobs_lease
    ON durable_jobs (lease_until)
    WHERE status = 'running';

CREATE TABLE IF NOT EXISTS outbox_events
(
    id uuid NOT NULL PRIMARY KEY,
    topic varchar(128) NOT NULL,
    aggregate_id uuid,
    idempotency_key varchar(255) NOT NULL UNIQUE,
    payload jsonb NOT NULL DEFAULT '{}'::jsonb,
    status varchar(24) NOT NULL DEFAULT 'pending',
    available_at timestamp with time zone NOT NULL DEFAULT now(),
    attempt_count integer NOT NULL DEFAULT 0,
    lease_owner varchar(255),
    lease_token uuid,
    lease_until timestamp with time zone,
    accepted_at timestamp with time zone,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    updated_at timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT outbox_events_status_check
        CHECK (status IN ('pending', 'running', 'accepted', 'failed', 'cancelled'))
);

CREATE INDEX IF NOT EXISTS idx_outbox_events_claim
    ON outbox_events (available_at, created_at, id)
    WHERE status IN ('pending', 'running');

CREATE TABLE IF NOT EXISTS device_registrations
(
    id uuid NOT NULL PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    provider varchar(24) NOT NULL,
    device_token text NOT NULL,
    token_hash bytea,
    enabled boolean NOT NULL DEFAULT true,
    last_seen_at timestamp with time zone,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    updated_at timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT device_registrations_user_provider_token UNIQUE (user_id, provider, device_token)
);

CREATE INDEX IF NOT EXISTS idx_device_registrations_targeting
    ON device_registrations (user_id, provider, enabled, updated_at DESC);

-- Keep each user's legacy token as its own registration.  The user_id is part
-- of the idempotency key so a token appearing on two legacy rows does not
-- merge accounts or expose an address during the backfill.
INSERT INTO device_registrations (id, user_id, provider, device_token, enabled, created_at, updated_at)
SELECT uuid_generate_v4(), id, 'firebase', firebase_token, TRUE, now(), now()
FROM users
WHERE firebase_token IS NOT NULL AND btrim(firebase_token) <> ''
ON CONFLICT (user_id, provider, device_token) DO NOTHING;

CREATE TABLE IF NOT EXISTS communication_preferences
(
    user_id uuid NOT NULL PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    security_email_enabled boolean NOT NULL DEFAULT true,
    general_email_enabled boolean NOT NULL DEFAULT true,
    push_enabled boolean NOT NULL DEFAULT true,
    updated_at timestamp with time zone NOT NULL DEFAULT now()
);

-- Retention is enforced by the named purge operations in the database facade:
-- expired action tokens/encrypted payloads within 24 hours, delivery details
-- within 30 days, and audit/report summaries according to deployment policy.
-- Security incidents intentionally have no account FK so their operational
-- summary survives account deletion.
