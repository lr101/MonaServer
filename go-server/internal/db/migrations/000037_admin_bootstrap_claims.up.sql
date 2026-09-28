-- Keep the one-time environment bootstrap marker after removing browser setup.
ALTER TABLE admin_initial_setup_claims RENAME TO admin_bootstrap_claims;
ALTER TABLE admin_bootstrap_claims
    RENAME CONSTRAINT admin_initial_setup_claims_pkey TO admin_bootstrap_claims_pkey;
ALTER TABLE admin_bootstrap_claims
    RENAME CONSTRAINT admin_initial_setup_claims_singleton_check TO admin_bootstrap_claims_singleton_check;
