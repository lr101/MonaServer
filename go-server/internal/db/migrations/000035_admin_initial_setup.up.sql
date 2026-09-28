-- A browser may claim initial administrator setup only once. This marker is
-- independent of the enrolled account so deleting that account cannot reopen
-- setup. Existing deployments with any administrator are already claimed.
CREATE TABLE admin_initial_setup_claims (
    singleton boolean PRIMARY KEY DEFAULT TRUE CHECK (singleton),
    claimed_at timestamp with time zone NOT NULL DEFAULT now()
);

INSERT INTO admin_initial_setup_claims (singleton)
SELECT TRUE WHERE EXISTS (SELECT 1 FROM admin_memberships)
ON CONFLICT DO NOTHING;
