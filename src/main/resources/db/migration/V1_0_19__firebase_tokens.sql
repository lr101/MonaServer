
ALTER TABLE users ADD COLUMN IF NOT EXISTS firebase_token varchar(255) null default null;