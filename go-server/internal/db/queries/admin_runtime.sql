-- Bounded production projections used by the browser-admin runtime adapter.
-- The service layer owns authorization; these queries deliberately keep all
-- filtering, counting, and page limits in PostgreSQL.

-- name: ListAdminRuntimeAccounts :many
SELECT u.id,
       u.username,
       u.email,
       u.email_confirmed,
       u.creation_date,
       u.security_state,
       u.auth_generation,
       u.password_disabled,
       u.password_reset_required,
       u.compromised_at,
       EXISTS (
           SELECT 1
           FROM admin_memberships membership
           WHERE membership.user_id = u.id
             AND membership.active = TRUE
             AND membership.revoked_at IS NULL
       ) AS is_admin,
       COALESCE(preferences.general_email_enabled, TRUE) AS general_email_enabled,
       COALESCE(preferences.push_enabled, TRUE) AS push_enabled,
       COALESCE(devices.device_count, 0)::integer AS device_count
FROM users u
LEFT JOIN communication_preferences preferences ON preferences.user_id = u.id
LEFT JOIN LATERAL (
    SELECT count(*)::integer AS device_count
    FROM device_registrations device
    WHERE device.user_id = u.id
      AND device.enabled = TRUE
) devices ON TRUE
WHERE u.is_deleted = FALSE
  AND (sqlc.narg('after_id')::uuid IS NULL OR u.id > sqlc.narg('after_id')::uuid)
  AND (COALESCE(array_length(sqlc.arg('selected_ids')::uuid[], 1), 0) = 0 OR u.id = ANY(sqlc.arg('selected_ids')::uuid[]))
  AND (sqlc.arg('search')::text = '' OR position(lower(sqlc.arg('search')::text) in lower(coalesce(u.username, '') || ' ' || coalesce(u.email, '') || ' ' || u.id::text)) > 0)
  AND (sqlc.arg('username')::text = '' OR position(lower(sqlc.arg('username')::text) in lower(coalesce(u.username, ''))) > 0)
  AND (sqlc.arg('email')::text = '' OR position(lower(sqlc.arg('email')::text) in lower(coalesce(u.email, ''))) > 0)
  AND (sqlc.arg('id_text')::text = '' OR position(lower(sqlc.arg('id_text')::text) in lower(u.id::text)) > 0)
  AND (sqlc.arg('security_state')::text = '' OR u.security_state = sqlc.arg('security_state')::text)
  AND (COALESCE(array_length(sqlc.arg('security_states')::text[], 1), 0) = 0 OR u.security_state = ANY(sqlc.arg('security_states')::text[]))
  AND (sqlc.narg('verified_email')::boolean IS NULL OR u.email_confirmed = sqlc.narg('verified_email')::boolean)
  AND (sqlc.narg('created_after')::timestamptz IS NULL OR u.creation_date >= sqlc.narg('created_after')::timestamptz)
  AND (sqlc.narg('created_before')::timestamptz IS NULL OR u.creation_date < sqlc.narg('created_before')::timestamptz)
  AND (sqlc.arg('include_admins')::boolean OR NOT EXISTS (
      SELECT 1 FROM admin_memberships membership
      WHERE membership.user_id = u.id AND membership.active = TRUE AND membership.revoked_at IS NULL
  ))
ORDER BY u.id ASC
LIMIT sqlc.arg('page_limit')::integer
OFFSET sqlc.arg('page_offset')::integer;

-- name: CountAdminRuntimeAccounts :one
SELECT count(*)::bigint
FROM users u
WHERE u.is_deleted = FALSE
  AND (COALESCE(array_length(sqlc.arg('selected_ids')::uuid[], 1), 0) = 0 OR u.id = ANY(sqlc.arg('selected_ids')::uuid[]))
  AND (sqlc.arg('username')::text = '' OR position(lower(sqlc.arg('username')::text) in lower(coalesce(u.username, ''))) > 0)
  AND (sqlc.arg('email')::text = '' OR position(lower(sqlc.arg('email')::text) in lower(coalesce(u.email, ''))) > 0)
  AND (sqlc.arg('id_text')::text = '' OR position(lower(sqlc.arg('id_text')::text) in lower(u.id::text)) > 0)
  AND (sqlc.arg('security_state')::text = '' OR u.security_state = sqlc.arg('security_state')::text)
  AND (COALESCE(array_length(sqlc.arg('security_states')::text[], 1), 0) = 0 OR u.security_state = ANY(sqlc.arg('security_states')::text[]))
  AND (sqlc.narg('verified_email')::boolean IS NULL OR u.email_confirmed = sqlc.narg('verified_email')::boolean)
  AND (sqlc.narg('created_after')::timestamptz IS NULL OR u.creation_date >= sqlc.narg('created_after')::timestamptz)
  AND (sqlc.narg('created_before')::timestamptz IS NULL OR u.creation_date < sqlc.narg('created_before')::timestamptz)
  AND (sqlc.arg('include_admins')::boolean OR NOT EXISTS (
      SELECT 1 FROM admin_memberships membership
      WHERE membership.user_id = u.id AND membership.active = TRUE AND membership.revoked_at IS NULL
  ));

-- name: GetAdminRuntimeAccount :one
SELECT u.id,
       u.username,
       u.email,
       u.email_confirmed,
       u.creation_date,
       u.security_state,
       u.auth_generation,
       u.password_disabled,
       u.password_reset_required,
       u.compromised_at,
       EXISTS (
           SELECT 1 FROM admin_memberships membership
           WHERE membership.user_id = u.id AND membership.active = TRUE AND membership.revoked_at IS NULL
       ) AS is_admin,
       COALESCE(preferences.general_email_enabled, TRUE) AS general_email_enabled,
       COALESCE(preferences.push_enabled, TRUE) AS push_enabled,
       COALESCE(devices.device_count, 0)::integer AS device_count
FROM users u
LEFT JOIN communication_preferences preferences ON preferences.user_id = u.id
LEFT JOIN LATERAL (
    SELECT count(*)::integer AS device_count
    FROM device_registrations device
    WHERE device.user_id = u.id AND device.enabled = TRUE
) devices ON TRUE
WHERE u.id = sqlc.arg('user_id')::uuid
  AND u.is_deleted = FALSE;

-- name: ListAdminRuntimeReports :many
SELECT report.id, report.status, report.target_kind, report.assignee_user_id
FROM reports report
WHERE (sqlc.narg('after_id')::uuid IS NULL OR report.id > sqlc.narg('after_id')::uuid)
  AND (COALESCE(array_length(sqlc.arg('selected_ids')::uuid[], 1), 0) = 0 OR report.id = ANY(sqlc.arg('selected_ids')::uuid[]))
  AND (COALESCE(array_length(sqlc.arg('statuses')::text[], 1), 0) = 0 OR report.status = ANY(sqlc.arg('statuses')::text[]))
  AND (COALESCE(array_length(sqlc.arg('target_types')::text[], 1), 0) = 0 OR coalesce(report.target_kind, '') = ANY(sqlc.arg('target_types')::text[]))
  AND (sqlc.narg('assignee_user_id')::uuid IS NULL OR report.assignee_user_id = sqlc.narg('assignee_user_id')::uuid)
  AND (sqlc.narg('created_after')::timestamptz IS NULL OR report.created_at >= sqlc.narg('created_after')::timestamptz)
  AND (sqlc.narg('created_before')::timestamptz IS NULL OR report.created_at < sqlc.narg('created_before')::timestamptz)
ORDER BY report.id ASC
LIMIT sqlc.arg('page_limit')::integer
OFFSET sqlc.arg('page_offset')::integer;

-- name: CountAdminRuntimeReports :one
SELECT count(*)::bigint
FROM reports report
WHERE (COALESCE(array_length(sqlc.arg('selected_ids')::uuid[], 1), 0) = 0 OR report.id = ANY(sqlc.arg('selected_ids')::uuid[]))
  AND (COALESCE(array_length(sqlc.arg('statuses')::text[], 1), 0) = 0 OR report.status = ANY(sqlc.arg('statuses')::text[]))
  AND (COALESCE(array_length(sqlc.arg('target_types')::text[], 1), 0) = 0 OR coalesce(report.target_kind, '') = ANY(sqlc.arg('target_types')::text[]))
  AND (sqlc.narg('assignee_user_id')::uuid IS NULL OR report.assignee_user_id = sqlc.narg('assignee_user_id')::uuid)
  AND (sqlc.narg('created_after')::timestamptz IS NULL OR report.created_at >= sqlc.narg('created_after')::timestamptz)
  AND (sqlc.narg('created_before')::timestamptz IS NULL OR report.created_at < sqlc.narg('created_before')::timestamptz);

-- name: ListAdminRuntimeAuditEvents :many
SELECT id, actor_id, target_account_id, action, reason, outcome, metadata, created_at
FROM audit_events
WHERE (sqlc.narg('after_id')::uuid IS NULL OR id > sqlc.narg('after_id')::uuid)
  AND (sqlc.narg('target_account_id')::uuid IS NULL OR target_account_id = sqlc.narg('target_account_id')::uuid)
  AND (sqlc.arg('action_filter')::text = '' OR action = sqlc.arg('action_filter')::text)
ORDER BY id ASC
LIMIT sqlc.arg('page_limit')::integer;

-- name: ListAdminRuntimeJobs :many
SELECT id, actor_id, snapshot_id, action, payload_hash, idempotency_key, status,
       account_count, eligible_count, device_count, completed_count, failed_count,
       reason, created_at, updated_at, started_at, completed_at,
       recent_mfa_at, recent_mfa_action
FROM admin_jobs
WHERE (sqlc.narg('after_id')::uuid IS NULL OR id > sqlc.narg('after_id')::uuid)
  AND (sqlc.arg('status_filter')::text = '' OR status = sqlc.arg('status_filter')::text)
  AND (sqlc.arg('action_filter')::text = '' OR action = sqlc.arg('action_filter')::text)
ORDER BY id ASC
LIMIT sqlc.arg('page_limit')::integer;

-- name: ListAdminRuntimeJobItems :many
SELECT id, job_id, target_id, device_id, device_count, outcome, error_code, provider_reference,
       attempt_count, lease_owner, lease_token, lease_until, completed_at,
       created_at, updated_at
FROM admin_job_items
WHERE job_id = sqlc.arg('job_id')::uuid
  AND (sqlc.narg('after_id')::uuid IS NULL OR id > sqlc.narg('after_id')::uuid)
ORDER BY id ASC
LIMIT sqlc.arg('page_limit')::integer;
