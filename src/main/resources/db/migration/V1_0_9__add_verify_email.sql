
ALTER TABLE users ADD COLUMN IF NOT EXISTS email_verification_url varchar(63) null default null;
ALTER TABLE users ADD COLUMN IF NOT EXISTS email_verification_expiration timestamp(6) null default null;
ALTER TABLE users ADD COLUMN IF NOT EXISTS email_verified boolean default false not null;