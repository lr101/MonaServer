
ALTER TABLE users ADD COLUMN IF NOT EXISTS description varchar(500) null default null;
ALTER TABLE users ADD COLUMN IF NOT EXISTS last_username_update timestamp(6) null default null;