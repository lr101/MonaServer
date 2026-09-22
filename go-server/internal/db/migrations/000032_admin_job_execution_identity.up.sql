-- Each item has one provider-facing operation identity for its entire
-- lifetime. A new lease cannot mint a second credential or delivery key.
ALTER TABLE admin_job_items
    ADD COLUMN IF NOT EXISTS operation_id uuid,
    ADD COLUMN IF NOT EXISTS lease_fence bigint NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS reason varchar(2000),
    ADD COLUMN IF NOT EXISTS retryable boolean NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS ambiguous boolean NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS last_attempt_at timestamp with time zone;

UPDATE admin_job_items
SET operation_id = uuid_generate_v4()
WHERE operation_id IS NULL;

ALTER TABLE admin_job_items
    ALTER COLUMN operation_id SET NOT NULL,
    ALTER COLUMN operation_id SET DEFAULT uuid_generate_v4();

ALTER TABLE admin_job_items
    ADD CONSTRAINT admin_job_items_lease_fence_monotonic_check
    CHECK (lease_fence >= 0),
    ADD CONSTRAINT admin_job_items_retryable_outcome_check
    CHECK (NOT retryable OR outcome = 'failed'),
    ADD CONSTRAINT admin_job_items_ambiguous_outcome_check
    CHECK (NOT ambiguous OR outcome = 'unknown_delivery');

-- An unknown result is never safe to requeue: a provider may have accepted
-- the operation before its response was lost. Existing unknown rows are
-- conservatively terminalized during the migration as well.
UPDATE admin_job_items
SET completed_at = COALESCE(completed_at, now()),
    lease_owner = NULL,
    lease_token = NULL,
    lease_until = NULL,
    retryable = FALSE,
    ambiguous = TRUE,
    updated_at = now()
WHERE outcome = 'unknown_delivery';

-- Transition fields make an audit event independently traceable to the exact
-- operation and lease fence that committed it. The partial uniqueness rule is
-- also the idempotency boundary for a terminal transition audit.
ALTER TABLE audit_events
    ADD COLUMN IF NOT EXISTS admin_job_item_id uuid,
    ADD COLUMN IF NOT EXISTS operation_id uuid,
    ADD COLUMN IF NOT EXISTS lease_fence bigint;

ALTER TABLE audit_events
    ADD CONSTRAINT audit_events_admin_job_transition_identity_check
    CHECK (
        admin_job_item_id IS NULL
        OR (operation_id IS NOT NULL AND lease_fence IS NOT NULL AND lease_fence >= 0)
    );

CREATE UNIQUE INDEX IF NOT EXISTS idx_audit_events_admin_job_item_fence
    ON audit_events (admin_job_item_id, lease_fence)
    WHERE admin_job_item_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_admin_job_items_execution_claim
    ON admin_job_items (job_id, created_at, id)
    WHERE outcome = 'queued' AND completed_at IS NULL;
