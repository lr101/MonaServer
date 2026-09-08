ALTER TABLE members
    ADD COLUMN IF NOT EXISTS is_deleted boolean NOT NULL DEFAULT false;

UPDATE members
SET is_deleted = NOT active;
