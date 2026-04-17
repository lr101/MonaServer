ALTER TABLE refresh_token ADD COLUMN IF NOT EXISTS last_active_date timestamp(6) with time zone not null default now();
ALTER TABLE refresh_token DROP COLUMN IF EXISTS expiry_date;