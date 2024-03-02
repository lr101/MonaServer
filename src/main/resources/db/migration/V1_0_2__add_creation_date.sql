
-- 1. Alter the 'pins' table to add the 'image' column
ALTER TABLE groups ADD COLUMN IF NOT EXISTS creation_date timestamp with time zone default current_timestamp;