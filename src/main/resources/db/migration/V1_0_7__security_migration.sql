
ALTER TABLE users ADD COLUMN IF NOT EXISTS reset_password_expiration timestamp(6) null default null;
ALTER TABLE users ADD COLUMN IF NOT EXISTS failed_login_attempts integer not null default 0;