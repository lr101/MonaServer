-- Campaign content survives deletion of its creator; the audit field becomes
-- empty rather than preventing the account removal.
ALTER TABLE campaigns
    ALTER COLUMN created_by_user_id DROP NOT NULL;

ALTER TABLE campaigns
    DROP CONSTRAINT campaigns_created_by_user_id_fkey,
    ADD CONSTRAINT campaigns_created_by_user_id_fkey
        FOREIGN KEY (created_by_user_id) REFERENCES users (id) ON DELETE SET NULL;
