
ALTER TABLE users ADD COLUMN IF NOT EXISTS email_confirmed boolean not null default false;
ALTER TABLE users ADD COLUMN IF NOT EXISTS email_confirmation_url varchar(63) null default null;

UPDATE users SET email_confirmed = TRUE;

