-- Additive storage queries for web administration and email-link auth.
-- Callers use the db.Queries facade below these generated methods so service
-- code does not duplicate SQL or accidentally escape a caller transaction.

-- Canonical email claims -----------------------------------------------------

-- name: BackfillEmailLoginClaims :exec
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

-- name: GetEmailLoginClaim :one
SELECT canonical_email, owner_user_id, state, is_ambiguous, blocked_reason,
       created_at, updated_at
FROM email_login_claims
WHERE canonical_email = $1;

-- name: LockEmailLoginClaim :one
SELECT canonical_email, owner_user_id, state, is_ambiguous, blocked_reason,
       created_at, updated_at
FROM email_login_claims
WHERE canonical_email = $1
FOR UPDATE;

-- name: ClaimEmailLoginClaim :one
INSERT INTO email_login_claims
    (canonical_email, owner_user_id, state, is_ambiguous, blocked_reason)
VALUES ($1, $2, 'owned', FALSE, NULL)
ON CONFLICT (canonical_email) DO UPDATE
SET owner_user_id = EXCLUDED.owner_user_id,
    state = 'owned',
    is_ambiguous = FALSE,
    blocked_reason = NULL,
    updated_at = now()
WHERE email_login_claims.state = 'available'
   OR email_login_claims.owner_user_id = EXCLUDED.owner_user_id
RETURNING canonical_email, owner_user_id, state, is_ambiguous, blocked_reason,
          created_at, updated_at;

-- name: SetEmailLoginClaim :exec
UPDATE email_login_claims
SET owner_user_id = $2,
    state = $3,
    is_ambiguous = $4,
    blocked_reason = $5,
    updated_at = now()
WHERE canonical_email = $1;

-- name: ListVerifiedUsersForEmailClaim :many
SELECT id
FROM users
WHERE lower(btrim(email)) = $1
  AND email_confirmed = TRUE
  AND is_deleted = FALSE
ORDER BY id;

-- name: DeleteEmailLoginClaim :exec
DELETE FROM email_login_claims WHERE canonical_email = $1;

-- User security state --------------------------------------------------------

-- name: GetUserSecurityState :one
SELECT id, email, email_confirmed, is_deleted, auth_generation, security_state,
       password_disabled, password_reset_required, compromised_at
FROM users
WHERE id = $1;

-- name: LockUserSecurityState :one
SELECT id, email, email_confirmed, is_deleted, auth_generation, security_state,
       password_disabled, password_reset_required, compromised_at
FROM users
WHERE id = $1
FOR UPDATE;

-- name: AdvanceUserAuthGeneration :one
UPDATE users
SET auth_generation = auth_generation + 1,
    update_date = now()
WHERE id = $1
RETURNING auth_generation;

-- name: SetUserSecurityState :exec
UPDATE users
SET security_state = $2,
    password_disabled = $3,
    password_reset_required = $4,
    compromised_at = $5,
    update_date = now()
WHERE id = $1;

-- Soft deletion is a containment boundary.  It advances the generation only
-- once, clears legacy action URLs/codes, and disables password use while the
-- caller holds the user row lock.
-- name: ContainUser :one
UPDATE users
SET is_deleted = TRUE,
    security_state = 'deleted',
    password_disabled = TRUE,
    password_reset_required = TRUE,
    auth_generation = auth_generation + 1,
    code = NULL,
    code_expiration = NULL,
    reset_password_url = NULL,
    reset_password_expiration = NULL,
    deletion_url = NULL,
    email_confirmation_url = NULL,
    update_date = now()
WHERE id = $1 AND is_deleted = FALSE
RETURNING auth_generation;

-- name: ClearUserRecoveryRestriction :exec
UPDATE users
SET security_state = 'normal',
    password_disabled = FALSE,
    password_reset_required = FALSE,
    compromised_at = NULL,
    failed_login_attempts = 0,
    update_date = now()
WHERE id = $1;

-- Action tokens -------------------------------------------------------------

-- name: CreateAccountActionToken :exec
INSERT INTO account_action_tokens
    (id, token_hash, purpose, account_id, email_binding, auth_generation, expires_at,
     delivery_attempt_id, created_at, updated_at)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, now(), now());

-- name: GetAccountActionTokenByHash :one
SELECT id, token_hash, purpose, account_id, email_binding, auth_generation, expires_at,
       consumed_at, revoked_at, delivery_attempt_id, created_at, updated_at
FROM account_action_tokens
WHERE token_hash = $1;

-- name: GetAccountActionTokenByID :one
SELECT id, token_hash, purpose, account_id, email_binding, auth_generation, expires_at,
       consumed_at, revoked_at, delivery_attempt_id, created_at, updated_at
FROM account_action_tokens
WHERE id = sqlc.arg('id')::uuid;

-- name: LockAccountActionTokenByHash :one
SELECT id, token_hash, purpose, account_id, email_binding, auth_generation, expires_at,
       consumed_at, revoked_at, delivery_attempt_id, created_at, updated_at
FROM account_action_tokens
WHERE token_hash = $1
FOR UPDATE;

-- The update is the single-use boundary.  Concurrent redemptions can both
-- read a token, but only one can satisfy consumed_at/revoked_at being NULL.
-- Purpose and expiry are checked here as well as in the service.
-- name: ConsumeAccountActionToken :one
UPDATE account_action_tokens
SET consumed_at = now(), updated_at = now()
WHERE token_hash = $1
  AND purpose = $2
  AND consumed_at IS NULL
  AND revoked_at IS NULL
  AND expires_at > $3
RETURNING id, token_hash, purpose, account_id, email_binding, auth_generation, expires_at,
          consumed_at, revoked_at, delivery_attempt_id, created_at, updated_at;

-- name: RevokeAccountActionTokens :exec
UPDATE account_action_tokens
SET revoked_at = COALESCE(revoked_at, now()), updated_at = now()
WHERE account_id = $1
  AND ($2::text = '' OR purpose = $2)
  AND consumed_at IS NULL
  AND revoked_at IS NULL;

-- name: RevokeAccountActionTokensExcept :exec
UPDATE account_action_tokens
SET revoked_at = COALESCE(revoked_at, now()), updated_at = now()
WHERE account_id = $1
  AND ($2::uuid IS NULL OR id <> $2)
  AND consumed_at IS NULL
  AND revoked_at IS NULL;

-- name: DeleteExpiredAccountActionTokens :exec
DELETE FROM account_action_tokens
WHERE expires_at < $1
   OR (consumed_at IS NOT NULL AND consumed_at < $2)
   OR (revoked_at IS NOT NULL AND revoked_at < $2);

-- Delivery attempts ---------------------------------------------------------

-- name: CreateDeliveryAttempt :exec
INSERT INTO delivery_attempts
    (id, channel, account_id, device_id, job_id, item_id, status, attempt_number,
     encrypted_payload, delivery_key_id, payload_expires_at, created_at, updated_at)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, now(), now());

-- name: GetDeliveryAttempt :one
SELECT id, channel, account_id, device_id, job_id, item_id, status, attempt_number,
       provider_reference, provider_outcome, error_code, encrypted_payload,
       delivery_key_id, payload_expires_at, accepted_at, created_at, updated_at,
       lease_owner, lease_token, lease_until
FROM delivery_attempts
WHERE id = $1;

-- name: UpdateDeliveryAttemptOutcome :exec
UPDATE delivery_attempts
SET status = $2,
    provider_reference = $3,
    provider_outcome = $4,
    error_code = $5,
    accepted_at = $6,
    attempt_number = attempt_number + 1,
    updated_at = now()
WHERE id = $1;

-- Clear the short-lived delivery secret only once the attempt is terminal or
-- its encrypted payload has expired.  The status/expiry predicate is part of
-- the same UPDATE, so a retryable outcome cannot clear its payload by racing
-- a cleanup call.
-- name: ClearDeliveryAttemptPayload :one
UPDATE delivery_attempts
SET encrypted_payload = NULL,
    delivery_key_id = NULL,
    updated_at = now()
WHERE id = $1
  AND encrypted_payload IS NOT NULL
  AND (
      status IN ('accepted', 'failed')
      OR (payload_expires_at IS NOT NULL AND payload_expires_at <= $2)
  )
RETURNING id;

-- name: ClearExpiredDeliveryPayloads :exec
UPDATE delivery_attempts
SET encrypted_payload = NULL, delivery_key_id = NULL, updated_at = now()
WHERE payload_expires_at < $1 OR accepted_at < $2;

-- Admin membership and bootstrap -------------------------------------------

-- The singleton claim serializes competing environment bootstraps. A prior
-- explicit operator enrollment marks the deployment claimed too.
-- name: ClaimAdminBootstrap :one
INSERT INTO admin_bootstrap_claims (singleton)
SELECT TRUE WHERE NOT EXISTS (SELECT 1 FROM admin_memberships)
ON CONFLICT DO NOTHING
RETURNING singleton;

-- name: MarkAdminBootstrapClaimed :exec
INSERT INTO admin_bootstrap_claims (singleton)
VALUES (TRUE)
ON CONFLICT DO NOTHING;

-- name: GetAdminMembership :one
SELECT id, user_id, permissions, active, totp_secret_ciphertext, totp_key_id,
       totp_enrolled_at, created_at, updated_at, revoked_at
FROM admin_memberships
WHERE user_id = $1;

-- name: UpsertAdminMembership :exec
INSERT INTO admin_memberships
    (id, user_id, permissions, active, totp_secret_ciphertext, totp_key_id,
     totp_enrolled_at, created_at, updated_at, revoked_at)
VALUES ($1, $2, $3, $4, $5, $6, $7, now(), now(), $8)
ON CONFLICT (user_id) DO UPDATE
SET permissions = EXCLUDED.permissions,
    active = EXCLUDED.active,
    totp_secret_ciphertext = EXCLUDED.totp_secret_ciphertext,
    totp_key_id = EXCLUDED.totp_key_id,
    totp_enrolled_at = EXCLUDED.totp_enrolled_at,
    updated_at = now(),
    revoked_at = EXCLUDED.revoked_at;

-- name: RevokeAdminMembership :exec
UPDATE admin_memberships
SET active = FALSE, revoked_at = COALESCE(revoked_at, now()), updated_at = now()
WHERE user_id = $1;

-- name: CreateAdminSession :exec
INSERT INTO admin_sessions
    (id, session_hash, user_id, csrf_hash, state, auth_generation, issued_at,
     last_seen_at, idle_expires_at, absolute_expires_at, recent_mfa_at,
     recent_mfa_action, revoked_at)
VALUES ($1, $2, $3, $4, $5, $6, now(), now(), $7, $8, $9, $10, NULL);

-- name: GetAdminSessionByHash :one
SELECT id, session_hash, user_id, csrf_hash, state, auth_generation, issued_at,
       last_seen_at, idle_expires_at, absolute_expires_at, recent_mfa_at,
       recent_mfa_action, revoked_at
FROM admin_sessions
WHERE session_hash = $1;

-- name: TouchAdminSession :exec
UPDATE admin_sessions
SET last_seen_at = now(), idle_expires_at = LEAST($2, absolute_expires_at)
WHERE session_hash = $1
  AND revoked_at IS NULL
  AND state = 'authenticated'
  AND idle_expires_at > now()
  AND absolute_expires_at > now();

-- name: RotateAdminSessionCSRF :exec
UPDATE admin_sessions
SET csrf_hash = $2,
    recent_mfa_at = COALESCE($3, recent_mfa_at),
    recent_mfa_action = COALESCE($4, recent_mfa_action),
    last_seen_at = now()
WHERE id = $1 AND revoked_at IS NULL;

-- name: RevokeAdminSession :exec
UPDATE admin_sessions
SET state = 'revoked', revoked_at = COALESCE(revoked_at, now())
WHERE id = $1;

-- name: RevokeAdminSessionsForUser :exec
UPDATE admin_sessions
SET state = 'revoked', revoked_at = COALESCE(revoked_at, now())
WHERE user_id = $1 AND revoked_at IS NULL;

-- name: RevokeExpiredAdminSessions :exec
UPDATE admin_sessions
SET state = 'revoked', revoked_at = COALESCE(revoked_at, now())
WHERE revoked_at IS NULL
  AND (idle_expires_at <= $1 OR absolute_expires_at <= $1);

-- Login challenges are one-use and account-generation bound.
-- name: CreateAdminLoginChallenge :exec
INSERT INTO admin_login_challenges
    (id, challenge_hash, user_id, ip_hmac, failed_attempts, auth_generation,
     expires_at, consumed_at, revoked_at, created_at)
VALUES ($1, $2, $3, $4, 0, $5, $6, NULL, NULL, now());

-- name: GetAdminLoginChallenge :one
SELECT id, challenge_hash, user_id, ip_hmac, failed_attempts, auth_generation,
       expires_at, consumed_at, revoked_at, created_at
FROM admin_login_challenges
WHERE id = $1;

-- name: LockAdminLoginChallenge :one
SELECT id, challenge_hash, user_id, ip_hmac, failed_attempts, auth_generation,
       expires_at, consumed_at, revoked_at, created_at
FROM admin_login_challenges
WHERE id = $1
FOR UPDATE;

-- name: ConsumeAdminLoginChallenge :one
UPDATE admin_login_challenges
SET consumed_at = now()
WHERE id = $1
  AND consumed_at IS NULL
  AND revoked_at IS NULL
  AND expires_at > $2
RETURNING id, challenge_hash, user_id, ip_hmac, failed_attempts, auth_generation,
          expires_at, consumed_at, revoked_at, created_at;

-- name: IncrementAdminChallengeFailure :one
UPDATE admin_login_challenges
SET failed_attempts = failed_attempts + 1
WHERE id = $1 AND consumed_at IS NULL AND revoked_at IS NULL
RETURNING failed_attempts;

-- name: RevokeAdminLoginChallengesForUser :exec
UPDATE admin_login_challenges
SET revoked_at = COALESCE(revoked_at, now())
WHERE user_id = $1 AND consumed_at IS NULL AND revoked_at IS NULL;

-- name: GetAdminMFAReplayCounter :one
SELECT session_id, last_counter, updated_at
FROM admin_mfa_replay_counters
WHERE session_id = $1;

-- name: AdvanceAdminMFAReplayCounter :one
INSERT INTO admin_mfa_replay_counters (session_id, last_counter, updated_at)
VALUES ($1, $2, now())
ON CONFLICT (session_id) DO UPDATE
SET last_counter = EXCLUDED.last_counter, updated_at = now()
WHERE admin_mfa_replay_counters.last_counter < EXCLUDED.last_counter
RETURNING session_id, last_counter, updated_at;

-- The replay scope is membership/user enrollment scoped and therefore shared
-- by all authenticated browser sessions for the operator.
-- name: GetAdminMFAReplayScope :one
SELECT membership_id, user_id, last_counter, updated_at
FROM admin_mfa_replay_scopes
WHERE membership_id = $1 AND user_id = $2;

-- name: AdvanceAdminMFAReplayScope :one
INSERT INTO admin_mfa_replay_scopes (membership_id, user_id, last_counter, updated_at)
VALUES ($1, $2, $3, now())
ON CONFLICT (membership_id) DO UPDATE
SET last_counter = EXCLUDED.last_counter, updated_at = now()
WHERE admin_mfa_replay_scopes.user_id = EXCLUDED.user_id
  AND admin_mfa_replay_scopes.last_counter < EXCLUDED.last_counter
RETURNING membership_id, user_id, last_counter, updated_at;

-- name: ResetAdminMFAReplayScope :exec
DELETE FROM admin_mfa_replay_scopes
WHERE membership_id = $1 AND user_id = $2;

-- Security incidents and append-only audit ---------------------------------

-- name: CreateSecurityIncident :exec
INSERT INTO security_incidents
    (id, account_id, actor_id, reason, previous_state, new_state, auth_generation,
     metadata, created_at)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, now());

-- name: ListSecurityIncidentsForAccount :many
SELECT id, account_id, actor_id, reason, previous_state, new_state, auth_generation,
       metadata, created_at
FROM security_incidents
WHERE account_id = $1
ORDER BY created_at DESC, id DESC
LIMIT $2;

-- name: CreateAuditEvent :exec
INSERT INTO audit_events
    (id, actor_id, target_account_id, action, reason, outcome, metadata, created_at)
VALUES ($1, $2, $3, $4, $5, $6, $7, now());

-- name: ListAuditEvents :many
SELECT id, actor_id, target_account_id, action, reason, outcome, metadata, created_at
FROM audit_events
WHERE ($1::timestamptz IS NULL OR created_at < $1)
ORDER BY created_at DESC, id DESC
LIMIT $2;

-- Reports -------------------------------------------------------------------

-- Report submissions and account deletion use the same transaction-scoped
-- advisory lock. This keeps the target row and report insert in one ordered
-- critical section even when a hard delete removes the user row.
-- name: LockReportTarget :exec
SELECT pg_advisory_xact_lock(hashtextextended('report-target:' || $1::text, 0));

-- name: CreateReport :one
INSERT INTO reports
    (id, reporter_user_id, target_id, target_kind, target_name, target_deleted,
     body, legacy_text, status, assignee_user_id, revision, request_id, created_at, updated_at)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'open', NULL, 1, $9, now(), now())
ON CONFLICT (request_id) WHERE request_id IS NOT NULL DO UPDATE SET id = reports.id
RETURNING id, reporter_user_id, target_id, target_kind, target_name, target_deleted,
          body, legacy_text, status, assignee_user_id, revision, request_id,
          created_at, updated_at, resolved_at;

-- InsertReport reports whether this transaction won a request-key race. A
-- losing insert returns no row, allowing the caller to replay the committed
-- row without consuming quota or writing another audit event.
-- name: InsertReport :one
INSERT INTO reports
    (id, reporter_user_id, target_id, target_kind, target_name, target_deleted,
     body, legacy_text, status, assignee_user_id, revision, request_id, created_at, updated_at)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'open', NULL, 1, $9, now(), now())
ON CONFLICT (request_id) WHERE request_id IS NOT NULL DO NOTHING
RETURNING id, reporter_user_id, target_id, target_kind, target_name, target_deleted,
          body, legacy_text, status, assignee_user_id, revision, request_id,
          created_at, updated_at, resolved_at;

-- name: GetReport :one
SELECT id, reporter_user_id, target_id, target_kind, target_name, target_deleted,
       body, legacy_text, status, assignee_user_id, revision, request_id,
       created_at, updated_at, resolved_at
FROM reports
WHERE id = $1;

-- name: GetReportByRequestID :one
SELECT id, reporter_user_id, target_id, target_kind, target_name, target_deleted,
       body, legacy_text, status, assignee_user_id, revision, request_id,
       created_at, updated_at, resolved_at
FROM reports
WHERE request_id = $1;

-- name: GetReportTargetSnapshot :one
SELECT id, username, is_deleted
FROM users
WHERE id = $1
FOR UPDATE;

-- name: ListReportsPage :many
SELECT id, reporter_user_id, target_id, target_kind, target_name, target_deleted,
       body, legacy_text, status, assignee_user_id, revision, request_id,
       created_at, updated_at, resolved_at
FROM reports
WHERE ($1::text = '' OR status = $1)
  AND ($2::timestamptz IS NULL OR created_at < $2::timestamptz
       OR (created_at = $2::timestamptz AND id < $3::uuid))
  AND ($4::text = '' OR position(lower($4) in lower(
      coalesce(body, '') || ' ' || coalesce(legacy_text, '') || ' ' ||
      coalesce(target_name, '') || ' ' || coalesce(target_id::text, ''))) > 0)
ORDER BY created_at DESC, id DESC
LIMIT $5;

-- name: ListReports :many
SELECT id, reporter_user_id, target_id, target_kind, target_name, target_deleted,
       body, legacy_text, status, assignee_user_id, revision, request_id,
       created_at, updated_at, resolved_at
FROM reports
WHERE ($1::text = '' OR status = $1)
  AND ($2::timestamptz IS NULL OR created_at < $2)
ORDER BY created_at DESC, id DESC
LIMIT $3;

-- name: UpdateReportIfRevision :one
UPDATE reports
SET status = CASE WHEN $2 = '' THEN status ELSE $2 END,
    assignee_user_id = CASE WHEN sqlc.arg('assignee_set')::boolean THEN $3 ELSE assignee_user_id END,
    revision = revision + 1,
    updated_at = now(),
    resolved_at = CASE WHEN $2 IN ('resolved', 'dismissed') THEN now()
                       WHEN $2 = 'open' THEN NULL
                       ELSE resolved_at END
WHERE id = $1 AND revision = $4
RETURNING id, reporter_user_id, target_id, target_kind, target_name, target_deleted,
          body, legacy_text, status, assignee_user_id, revision, request_id,
          created_at, updated_at, resolved_at;

-- name: CreateReportNote :one
INSERT INTO report_notes (id, report_id, author_user_id, body, created_at)
VALUES ($1, $2, $3, $4, now())
RETURNING id, report_id, author_user_id, body, created_at;

-- name: ListReportNotes :many
SELECT id, report_id, author_user_id, body, created_at
FROM report_notes
WHERE report_id = $1
ORDER BY created_at ASC, id ASC
LIMIT $2;

-- name: ListReportNotesPage :many
SELECT id, report_id, author_user_id, body, created_at
FROM report_notes
WHERE report_id = $1
  AND ($2::timestamptz IS NULL OR created_at < $2::timestamptz
       OR (created_at = $2::timestamptz AND id < $3::uuid))
ORDER BY created_at DESC, id DESC
LIMIT $4;

-- Audience snapshots --------------------------------------------------------

-- Acquire this lock in a statement before reading the current ordinal.  A
-- separate statement is required under PostgreSQL READ COMMITTED: a waiting
-- SELECT FOR UPDATE does not refresh the aggregate's statement snapshot.
-- name: LockAudienceSnapshot :one
SELECT id
FROM audience_snapshots
WHERE id = $1
FOR UPDATE;

-- name: CreateAudienceSnapshot :exec
INSERT INTO audience_snapshots
    (id, actor_id, resource, action, payload_hash, filter, status,
     account_count, eligible_count, device_count, exclusion_count,
     expires_at, created_at, updated_at)
VALUES ($1, $2, $3, $4, $5, $6, $7, 0, 0, 0, 0, $8, now(), now());

-- name: GetAudienceSnapshot :one
SELECT id, actor_id, resource, action, payload_hash, filter, status,
       account_count, eligible_count, device_count, exclusion_count,
       expires_at, created_at, updated_at
FROM audience_snapshots
WHERE id = $1;

-- name: UpdateAudienceSnapshotCounts :exec
UPDATE audience_snapshots
SET status = $2,
    account_count = $3,
    eligible_count = $4,
    device_count = $5,
    exclusion_count = $6,
    updated_at = now()
WHERE id = $1;

-- name: AddAudienceSnapshotMember :exec
INSERT INTO audience_snapshot_members
    (snapshot_id, ordinal, resource_id, eligible, exclusion_code, created_at)
VALUES ($1, $2, $3, $4, $5, now())
ON CONFLICT (snapshot_id, resource_id) DO NOTHING;

-- Append members under the snapshot row lock so separate materializer batches
-- cannot reuse ordinals.  The caller order is retained via WITH ORDINALITY;
-- duplicate IDs in one batch are ignored without changing existing members.
-- name: AppendAudienceSnapshotMembers :exec
WITH snapshot_lock AS (
    SELECT id
    FROM audience_snapshots
    WHERE id = $1
    FOR UPDATE
), input AS (
    SELECT DISTINCT ON (resource_id) resource_id, input_ordinal
    FROM unnest($2::uuid[]) WITH ORDINALITY AS values(resource_id, input_ordinal)
    ORDER BY resource_id, input_ordinal
), new_members AS (
    SELECT i.resource_id,
           row_number() OVER (ORDER BY i.input_ordinal) - 1 AS offset_ordinal
    FROM input i
    WHERE NOT EXISTS (
        SELECT 1
        FROM audience_snapshot_members existing
        WHERE existing.snapshot_id = $1 AND existing.resource_id = i.resource_id
    )
), base AS (
    SELECT COALESCE(MAX(ordinal) + 1, 0) AS ordinal
    FROM audience_snapshot_members
    WHERE snapshot_id = $1
      AND EXISTS (SELECT 1 FROM snapshot_lock)
)
INSERT INTO audience_snapshot_members
    (snapshot_id, ordinal, resource_id, eligible, exclusion_code, created_at)
SELECT $1, base.ordinal + new_members.offset_ordinal, new_members.resource_id,
       TRUE, NULL, now()
FROM base
JOIN new_members ON TRUE
ON CONFLICT (snapshot_id, resource_id) DO NOTHING;

-- name: ListAudienceSnapshotMembers :many
SELECT snapshot_id, ordinal, resource_id, eligible, exclusion_code, created_at
FROM audience_snapshot_members
WHERE snapshot_id = $1
  AND ($2::bigint < 0 OR ordinal > $2)
ORDER BY ordinal ASC, resource_id ASC
LIMIT $3;

-- name: CountAudienceSnapshotMembers :one
SELECT count(*)::bigint AS total,
       count(*) FILTER (WHERE eligible)::bigint AS eligible,
       count(*) FILTER (WHERE NOT eligible)::bigint AS excluded
FROM audience_snapshot_members
WHERE snapshot_id = $1;

-- name: DeleteExpiredAudienceSnapshots :exec
DELETE FROM audience_snapshots WHERE expires_at < $1;

-- Admin jobs and recipient items --------------------------------------------

-- name: CreateAdminJob :one
INSERT INTO admin_jobs
    (id, actor_id, snapshot_id, action, payload_hash, idempotency_key, status,
     account_count, eligible_count, device_count, reason, recent_mfa_at,
     recent_mfa_action, created_at, updated_at)
VALUES ($1, $2, $3, $4, $5, $6, 'pending', $7, $8, $9, $10, $11, $12, now(), now())
ON CONFLICT (idempotency_key) DO UPDATE SET id = admin_jobs.id
RETURNING id, actor_id, snapshot_id, action, payload_hash, idempotency_key, status,
          account_count, eligible_count, device_count, completed_count, failed_count,
          reason, created_at, updated_at, started_at, completed_at,
          recent_mfa_at, recent_mfa_action;

-- name: GetAdminJob :one
SELECT id, actor_id, snapshot_id, action, payload_hash, idempotency_key, status,
       account_count, eligible_count, device_count, completed_count, failed_count,
       reason, created_at, updated_at, started_at, completed_at,
       recent_mfa_at, recent_mfa_action
FROM admin_jobs
WHERE id = $1;

-- name: ListAdminJobs :many
SELECT id, actor_id, snapshot_id, action, payload_hash, idempotency_key, status,
       account_count, eligible_count, device_count, completed_count, failed_count,
       reason, created_at, updated_at, started_at, completed_at,
       recent_mfa_at, recent_mfa_action
FROM admin_jobs
WHERE ($1::text = '' OR status = $1)
  AND ($2::timestamptz IS NULL OR created_at < $2)
ORDER BY created_at DESC, id DESC
LIMIT $3;

-- name: UpdateAdminJobProgress :exec
UPDATE admin_jobs
SET status = $2,
    completed_count = $3,
    failed_count = $4,
    updated_at = now(),
    started_at = COALESCE(started_at, CASE WHEN $2 = 'running' THEN now() ELSE started_at END),
    completed_at = CASE WHEN $2 IN ('completed', 'completed_with_errors', 'cancelled') THEN now() ELSE completed_at END
WHERE id = $1;

-- name: AddAdminJobItem :exec
INSERT INTO admin_job_items
    (id, job_id, target_id, device_id, outcome, error_code, provider_reference,
     attempt_count, created_at, updated_at)
VALUES ($1, $2, $3, $4, $5, $6, $7, 0, now(), now())
ON CONFLICT DO NOTHING;

-- name: GetAdminJobItem :one
SELECT id, job_id, target_id, device_id, outcome, error_code, provider_reference,
       attempt_count, lease_owner, lease_token, lease_until, completed_at,
       created_at, updated_at
FROM admin_job_items
WHERE id = $1;

-- name: ListAdminJobItems :many
SELECT id, job_id, target_id, device_id, outcome, error_code, provider_reference,
       attempt_count, lease_owner, lease_token, lease_until, completed_at,
       created_at, updated_at
FROM admin_job_items
WHERE job_id = $1
  AND ($2::timestamptz IS NULL OR created_at < $2)
ORDER BY created_at ASC, id ASC
LIMIT $3;

-- name: ClaimAdminJobItems :many
WITH candidates AS (
    SELECT id
    FROM admin_job_items
    WHERE admin_job_items.job_id = $1
      AND admin_job_items.outcome IN ('queued', 'unknown_delivery')
      AND (admin_job_items.lease_until IS NULL OR admin_job_items.lease_until <= clock_timestamp())
    ORDER BY admin_job_items.created_at ASC, admin_job_items.id ASC
    FOR UPDATE SKIP LOCKED
    LIMIT $2
), claimed AS (
    UPDATE admin_job_items i
    SET lease_owner = $3, lease_token = uuid_generate_v4(),
        lease_until = clock_timestamp() + make_interval(secs => $4::double precision),
        attempt_count = attempt_count + 1, updated_at = now()
    FROM candidates c
    WHERE i.id = c.id
    RETURNING i.id, i.job_id, i.target_id, i.device_id, i.outcome, i.error_code,
              i.provider_reference, i.attempt_count, i.lease_owner, i.lease_token,
              i.lease_until, i.completed_at, i.created_at, i.updated_at
)
SELECT * FROM claimed ORDER BY created_at ASC, id ASC;

-- Claim one requested item for the T07 action boundary.  The candidate row
-- lock and lease transition are one statement.  A targeted claim waits for an
-- in-flight row transition, then rechecks eligibility, so a concurrent worker
-- either observes no claimable row or receives a fresh owner/token pair.  The
-- token returned here is the acknowledgement fence for this lease attempt.
-- name: ClaimJobItem :one
WITH locked AS (
    SELECT i.id
    FROM admin_job_items i
    WHERE i.id = $1
      AND i.job_id = $2
    FOR UPDATE
), claimed AS (
    UPDATE admin_job_items i
    SET lease_owner = $3,
        lease_token = uuid_generate_v4(),
        lease_until = clock_timestamp() + make_interval(secs => $4::double precision),
        attempt_count = attempt_count + 1,
        updated_at = now()
    WHERE i.id = $1
      AND EXISTS (SELECT 1 FROM locked)
      AND i.outcome IN ('queued', 'unknown_delivery')
      AND (i.lease_until IS NULL OR i.lease_until <= clock_timestamp())
    RETURNING i.id, i.job_id, i.target_id, i.device_id, i.outcome, i.error_code,
              i.provider_reference, i.attempt_count, i.lease_owner, i.lease_token,
              i.lease_until, i.completed_at, i.created_at, i.updated_at
)
SELECT id, job_id, target_id, device_id, outcome, error_code, provider_reference,
       attempt_count, lease_owner, lease_token, lease_until, completed_at,
       created_at, updated_at
FROM claimed;

-- name: FinishAdminJobItem :one
WITH locked AS (
    SELECT item.id
    FROM admin_job_items AS item
    WHERE item.id = $1
    FOR UPDATE
)
UPDATE admin_job_items AS item
SET outcome = $2::varchar, error_code = $3, provider_reference = $4,
    completed_at = CASE WHEN $2::varchar IN ('skipped', 'secured', 'provider_accepted', 'failed') THEN now() ELSE completed_at END,
    lease_owner = NULL, lease_token = NULL, lease_until = NULL, updated_at = now()
WHERE item.id = $1
  AND EXISTS (SELECT 1 FROM locked)
  AND item.lease_owner = $5
  AND item.lease_token = $6
  AND item.lease_until > clock_timestamp()
RETURNING item.id;

-- Finish, heartbeat, and retry acknowledgement all carry the worker and the
-- exact token returned by ClaimJobItem.  A reclaimed row has a different
-- token, so an old worker's rows-affected result is zero even if it races the
-- current owner.
-- name: FinishJobItem :one
WITH locked AS (
    SELECT item.id
    FROM admin_job_items AS item
    WHERE item.id = $1
    FOR UPDATE
)
UPDATE admin_job_items AS item
SET outcome = $4::varchar, error_code = $5, provider_reference = $6,
    completed_at = CASE WHEN $4::varchar IN ('skipped', 'secured', 'provider_accepted', 'failed') THEN now() ELSE completed_at END,
    lease_owner = NULL, lease_token = NULL, lease_until = NULL, updated_at = now()
WHERE item.id = $1
  AND EXISTS (SELECT 1 FROM locked)
  AND item.lease_owner = $2
  AND item.lease_token = $3
  AND item.lease_until > clock_timestamp()
RETURNING item.id;

-- name: ExtendAdminJobItemLease :one
WITH locked AS (
    SELECT item.id
    FROM admin_job_items AS item
    WHERE item.id = $1
    FOR UPDATE
)
UPDATE admin_job_items AS item
SET lease_until = clock_timestamp() + make_interval(secs => $4::double precision), updated_at = now()
WHERE item.id = $1
  AND EXISTS (SELECT 1 FROM locked)
  AND item.lease_owner = $2
  AND item.lease_token = $3
  AND item.lease_until > clock_timestamp()
RETURNING item.id, item.lease_until;

-- name: HeartbeatJobItem :one
WITH locked AS (
    SELECT item.id
    FROM admin_job_items AS item
    WHERE item.id = $1
    FOR UPDATE
)
UPDATE admin_job_items AS item
SET lease_until = clock_timestamp() + make_interval(secs => $4::double precision), updated_at = now()
WHERE item.id = $1
  AND EXISTS (SELECT 1 FROM locked)
  AND item.lease_owner = $2
  AND item.lease_token = $3
  AND item.lease_until > clock_timestamp()
RETURNING item.id, item.lease_until;

-- name: ReleaseAdminJobItemLease :one
WITH locked AS (
    SELECT item.id
    FROM admin_job_items AS item
    WHERE item.id = $1
    FOR UPDATE
)
UPDATE admin_job_items AS item
SET outcome = 'unknown_delivery', lease_owner = NULL, lease_token = NULL,
    lease_until = NULL, updated_at = now()
WHERE item.id = $1
  AND EXISTS (SELECT 1 FROM locked)
  AND item.lease_owner = $2
  AND item.lease_token = $3
  AND item.lease_until > clock_timestamp()
RETURNING item.id;

-- Retry acceptance returns the item to the retryable outcome only for the
-- current lease owner.  The token check fences a stale worker from changing
-- the outcome after another worker has reclaimed the item.
-- name: RetryJobItem :one
WITH locked AS (
    SELECT item.id
    FROM admin_job_items AS item
    WHERE item.id = $1
    FOR UPDATE
)
UPDATE admin_job_items AS item
SET outcome = 'unknown_delivery', lease_owner = NULL, lease_token = NULL,
    lease_until = NULL, updated_at = now()
WHERE item.id = $1
  AND EXISTS (SELECT 1 FROM locked)
  AND item.lease_owner = $2
  AND item.lease_token = $3
  AND item.lease_until > clock_timestamp()
RETURNING item.id;

-- Durable jobs and outbox leases -------------------------------------------

-- name: CreateDurableJob :exec
INSERT INTO durable_jobs
    (id, kind, idempotency_key, payload, priority, status, available_at,
     attempt_count, max_attempts, created_at, updated_at)
VALUES ($1, $2, $3, $4, $5, 'pending', $6, 0, $7, now(), now())
ON CONFLICT (kind, idempotency_key) DO NOTHING;

-- name: GetDurableJob :one
SELECT id, kind, idempotency_key, payload, priority, status, available_at,
       attempt_count, max_attempts, lease_owner, lease_token, lease_until,
       last_error, created_at, updated_at, started_at, completed_at
FROM durable_jobs
WHERE id = $1;

-- Expired running leases are made claimable in the same statement that claims
-- work.  A fresh lease token makes an old worker's acknowledgement harmless.
-- name: ClaimDurableJobs :many
WITH candidates AS (
    SELECT id
    FROM durable_jobs
    WHERE (status = 'pending' OR (status = 'running' AND lease_until <= clock_timestamp()))
      AND available_at <= now()
      AND attempt_count < max_attempts
    ORDER BY priority DESC, available_at ASC, created_at ASC, id ASC
    FOR UPDATE SKIP LOCKED
    LIMIT $1
), claimed AS (
    UPDATE durable_jobs j
    SET status = 'running', lease_owner = $2, lease_token = uuid_generate_v4(),
        lease_until = clock_timestamp() + make_interval(secs => $3::double precision), attempt_count = attempt_count + 1,
        started_at = COALESCE(started_at, now()), updated_at = now()
    FROM candidates c
    WHERE j.id = c.id
    RETURNING j.id, j.kind, j.idempotency_key, j.payload, j.priority, j.status,
              j.available_at, j.attempt_count, j.max_attempts, j.lease_owner,
              j.lease_token, j.lease_until, j.last_error, j.created_at,
              j.updated_at, j.started_at, j.completed_at
)
SELECT * FROM claimed ORDER BY priority DESC, available_at ASC, created_at ASC, id ASC;

-- Claiming with a kind allowlist keeps queue-family isolation in the same
-- SELECT ... FOR UPDATE SKIP LOCKED statement as the lease transition.  A
-- worker therefore never claims a row it will later release because it does
-- not own that kind.
-- name: ClaimDurableJobsByKinds :many
WITH candidates AS (
    SELECT id
    FROM durable_jobs
    WHERE (status = 'pending' OR (status = 'running' AND lease_until <= clock_timestamp()))
      AND available_at <= now()
      AND attempt_count < max_attempts
      AND (cardinality($2::text[]) = 0 OR kind = ANY($2::text[]))
    ORDER BY priority DESC, available_at ASC, created_at ASC, id ASC
    FOR UPDATE SKIP LOCKED
    LIMIT $1
), claimed AS (
    UPDATE durable_jobs j
    SET status = 'running', lease_owner = $3, lease_token = uuid_generate_v4(),
        lease_until = clock_timestamp() + make_interval(secs => $4::double precision), attempt_count = attempt_count + 1,
        started_at = COALESCE(started_at, now()), updated_at = now()
    FROM candidates c
    WHERE j.id = c.id
    RETURNING j.id, j.kind, j.idempotency_key, j.payload, j.priority, j.status,
              j.available_at, j.attempt_count, j.max_attempts, j.lease_owner,
              j.lease_token, j.lease_until, j.last_error, j.created_at,
              j.updated_at, j.started_at, j.completed_at
)
SELECT * FROM claimed ORDER BY priority DESC, available_at ASC, created_at ASC, id ASC;

-- name: ExtendDurableJobLease :one
WITH locked AS (
    SELECT job.id
    FROM durable_jobs AS job
    WHERE job.id = $1
    FOR UPDATE
)
UPDATE durable_jobs AS job
SET lease_until = clock_timestamp() + make_interval(secs => $4::double precision), updated_at = now()
WHERE job.id = $1
  AND EXISTS (SELECT 1 FROM locked)
  AND job.status = 'running'
  AND job.lease_owner = $2
  AND job.lease_token = $3
  AND job.lease_until > clock_timestamp()
RETURNING job.id, job.lease_until;

-- name: FinishDurableJob :one
WITH locked AS (
    SELECT job.id
    FROM durable_jobs AS job
    WHERE job.id = $1
    FOR UPDATE
)
UPDATE durable_jobs AS job
SET status = $4, last_error = $5, lease_owner = NULL, lease_token = NULL,
    lease_until = NULL, completed_at = now(), updated_at = now()
WHERE job.id = $1
  AND EXISTS (SELECT 1 FROM locked)
  AND job.status = 'running'
  AND job.lease_owner = $2
  AND job.lease_token = $3
  AND job.lease_until > clock_timestamp()
RETURNING job.id;

-- name: ReleaseDurableJobLease :one
WITH locked AS (
    SELECT job.id
    FROM durable_jobs AS job
    WHERE job.id = $1
    FOR UPDATE
)
UPDATE durable_jobs AS job
SET status = 'pending', available_at = $4, lease_owner = NULL,
    lease_token = NULL, lease_until = NULL, updated_at = now()
WHERE job.id = $1
  AND EXISTS (SELECT 1 FROM locked)
  AND job.status = 'running'
  AND job.lease_owner = $2
  AND job.lease_token = $3
  AND job.lease_until > clock_timestamp()
RETURNING job.id;

-- name: CreateOutboxEvent :exec
INSERT INTO outbox_events
    (id, topic, aggregate_id, idempotency_key, payload, status, available_at,
     attempt_count, created_at, updated_at)
VALUES ($1, $2, $3, $4, $5, 'pending', $6, 0, now(), now())
ON CONFLICT (idempotency_key) DO NOTHING;

-- name: GetOutboxEvent :one
SELECT id, topic, aggregate_id, idempotency_key, payload, status, available_at,
       attempt_count, lease_owner, lease_token, lease_until, accepted_at,
       created_at, updated_at
FROM outbox_events
WHERE id = $1;

-- name: ClaimOutboxEvents :many
WITH candidates AS (
    SELECT id
    FROM outbox_events
    WHERE (status = 'pending' OR (status = 'running' AND lease_until <= clock_timestamp()))
      AND available_at <= now()
    ORDER BY available_at ASC, created_at ASC, id ASC
    FOR UPDATE SKIP LOCKED
    LIMIT $1
), claimed AS (
    UPDATE outbox_events e
    SET status = 'running', lease_owner = $2, lease_token = uuid_generate_v4(),
        lease_until = clock_timestamp() + make_interval(secs => $3::double precision), attempt_count = attempt_count + 1,
        updated_at = now()
    FROM candidates c
    WHERE e.id = c.id
    RETURNING e.id, e.topic, e.aggregate_id, e.idempotency_key, e.payload, e.status,
              e.available_at, e.attempt_count, e.lease_owner, e.lease_token,
              e.lease_until, e.accepted_at, e.created_at, e.updated_at
)
SELECT * FROM claimed ORDER BY available_at ASC, created_at ASC, id ASC;

-- name: FinishOutboxEvent :one
WITH locked AS (
    SELECT event.id
    FROM outbox_events AS event
    WHERE event.id = $1
    FOR UPDATE
)
UPDATE outbox_events AS event
SET status = $4::varchar, accepted_at = CASE WHEN $4::varchar = 'accepted' THEN now() ELSE accepted_at END,
    lease_owner = NULL, lease_token = NULL, lease_until = NULL, updated_at = now()
WHERE event.id = $1
  AND EXISTS (SELECT 1 FROM locked)
  AND event.status = 'running'
  AND event.lease_owner = $2
  AND event.lease_token = $3
  AND event.lease_until > clock_timestamp()
RETURNING event.id;

-- name: ExtendOutboxEventLease :one
WITH locked AS (
    SELECT event.id
    FROM outbox_events AS event
    WHERE event.id = $1
    FOR UPDATE
)
UPDATE outbox_events AS event
SET lease_until = clock_timestamp() + make_interval(secs => $4::double precision), updated_at = now()
WHERE event.id = $1
  AND EXISTS (SELECT 1 FROM locked)
  AND event.status = 'running'
  AND event.lease_owner = $2
  AND event.lease_token = $3
  AND event.lease_until > clock_timestamp()
RETURNING event.id, event.lease_until;

-- name: ReleaseOutboxEventLease :one
WITH locked AS (
    SELECT event.id
    FROM outbox_events AS event
    WHERE event.id = $1
    FOR UPDATE
)
UPDATE outbox_events AS event
SET status = 'pending', available_at = $4, lease_owner = NULL,
    lease_token = NULL, lease_until = NULL, updated_at = now()
WHERE event.id = $1
  AND EXISTS (SELECT 1 FROM locked)
  AND event.status = 'running'
  AND event.lease_owner = $2
  AND event.lease_token = $3
  AND event.lease_until > clock_timestamp()
RETURNING event.id;

-- Shared HMAC-keyed quotas --------------------------------------------------

-- Advisory locking is scoped to the logical scope/window, so current and
-- previous HMAC key rows cannot bypass one another during key rotation.
-- name: LockRateLimitWindow :exec
SELECT pg_advisory_xact_lock(hashtextextended($1 || ':' || $2::text, 0));

-- name: SumRateLimitBuckets :one
SELECT COALESCE(sum(hit_count), 0)::bigint AS hit_count
FROM rate_limit_buckets
WHERE scope = $1
  AND window_start = $2
  AND identifier_hmac = ANY($3::bytea[]);

-- name: UpsertRateLimitBucket :one
INSERT INTO rate_limit_buckets
    (scope, identifier_hmac, key_id, window_start, window_end, hit_count, updated_at)
VALUES ($1, $2, $3, $4, $5, $6, now())
ON CONFLICT (scope, identifier_hmac, window_start) DO UPDATE
SET hit_count = rate_limit_buckets.hit_count + EXCLUDED.hit_count,
    key_id = EXCLUDED.key_id, window_end = EXCLUDED.window_end, updated_at = now()
RETURNING scope, identifier_hmac, key_id, window_start, window_end, hit_count, updated_at;

-- name: PurgeRateLimitBuckets :exec
DELETE FROM rate_limit_buckets
WHERE window_end < $1;

-- Devices and communication preferences -----------------------------------

-- name: UpsertDeviceRegistration :one
INSERT INTO device_registrations
    (id, user_id, provider, device_token, token_hash, enabled, last_seen_at,
     created_at, updated_at)
VALUES ($1, $2, $3, $4, $5, $6, now(), now(), now())
ON CONFLICT (user_id, provider, device_token) DO UPDATE
SET token_hash = EXCLUDED.token_hash, enabled = EXCLUDED.enabled,
    last_seen_at = now(), updated_at = now()
RETURNING id, user_id, provider, device_token, token_hash, enabled,
          last_seen_at, created_at, updated_at;

-- name: ListDeviceRegistrations :many
SELECT id, user_id, provider, device_token, token_hash, enabled, last_seen_at,
       created_at, updated_at
FROM device_registrations
WHERE user_id = $1 AND enabled = TRUE
ORDER BY updated_at DESC, id DESC;

-- name: DisableDeviceRegistration :exec
UPDATE device_registrations
SET enabled = FALSE, updated_at = now()
WHERE id = $1 AND user_id = $2;

-- name: GetCommunicationPreferences :one
SELECT user_id, security_email_enabled, general_email_enabled, push_enabled, updated_at
FROM communication_preferences
WHERE user_id = $1;

-- name: UpsertCommunicationPreferences :one
INSERT INTO communication_preferences
    (user_id, security_email_enabled, general_email_enabled, push_enabled, updated_at)
VALUES ($1, $2, $3, $4, now())
ON CONFLICT (user_id) DO UPDATE
SET security_email_enabled = EXCLUDED.security_email_enabled,
    general_email_enabled = EXCLUDED.general_email_enabled,
    push_enabled = EXCLUDED.push_enabled, updated_at = now()
RETURNING user_id, security_email_enabled, general_email_enabled, push_enabled, updated_at;

-- Retention and account cleanup --------------------------------------------

-- Keep incident and audit rows (their IDs and operational summaries are not
-- account-owned secrets), while removing credentials, delivery payloads,
-- sessions, devices and preferences for a physically deleted account.
-- name: PurgeDeletedAccountData :exec
WITH deleted AS (
    SELECT u.id FROM users u WHERE u.id = $1 AND u.is_deleted = TRUE
), clear_claims AS (
    UPDATE email_login_claims c
    SET owner_user_id = NULL, state = 'available', is_ambiguous = FALSE,
        blocked_reason = NULL, updated_at = now()
    WHERE c.owner_user_id = $1
      AND EXISTS (SELECT 1 FROM deleted)
), clear_delivery AS (
    UPDATE delivery_attempts d
    SET account_id = NULL, device_id = NULL,
        encrypted_payload = NULL, delivery_key_id = NULL, updated_at = now()
    WHERE d.account_id = $1
      AND EXISTS (SELECT 1 FROM deleted)
), delete_tokens AS (
    DELETE FROM account_action_tokens t
    USING deleted d
    WHERE t.account_id = d.id
    RETURNING t.id
)
SELECT 1;

-- name: PurgeExpiredAdminChallenges :exec
DELETE FROM admin_login_challenges WHERE expires_at < $1 OR consumed_at < $2 OR revoked_at < $2;
