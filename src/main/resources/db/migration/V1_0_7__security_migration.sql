
ALTER TABLE users ADD COLUMN IF NOT EXISTS reset_password_expiration timestamp(6) null default null;
ALTER TABLE users ADD COLUMN IF NOT EXISTS failed_login_attempts integer not null default 0;
ALTER TABLE users ADD COLUMN IF NOT EXISTS code_expiration timestamp(6) null default null;
ALTER TABLE users ADD COLUMN IF NOT EXISTS deletion_url varchar(63) null default null;
ALTER TABLE users ALTER COLUMN reset_password_url TYPE varchar(63);
ALTER TABLE users ADD CONSTRAINT unique_reset_password_url UNIQUE (reset_password_url);
ALTER TABLE users ADD CONSTRAINT unique_deletion_url UNIQUE (deletion_url);