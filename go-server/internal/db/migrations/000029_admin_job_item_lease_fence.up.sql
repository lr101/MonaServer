-- Every administrative item lease is one complete worker/token/expiry
-- capability.  Repair partially populated lease columns from early durable
-- queue rows before making that invariant explicit.
UPDATE admin_job_items
SET lease_owner = NULL,
    lease_token = NULL,
    lease_until = NULL,
    updated_at = now()
WHERE NOT (
    (lease_owner IS NULL AND lease_token IS NULL AND lease_until IS NULL)
    OR (
        lease_owner IS NOT NULL
        AND btrim(lease_owner) <> ''
        AND lease_token IS NOT NULL
        AND lease_until IS NOT NULL
    )
);

ALTER TABLE admin_job_items
    ADD CONSTRAINT admin_job_items_lease_fence_check
    CHECK (
        (lease_owner IS NULL AND lease_token IS NULL AND lease_until IS NULL)
        OR (
            lease_owner IS NOT NULL
            AND btrim(lease_owner) <> ''
            AND lease_token IS NOT NULL
            AND lease_until IS NOT NULL
        )
    );
