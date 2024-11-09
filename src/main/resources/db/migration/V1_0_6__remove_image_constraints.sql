ALTER TABLE groups
    ALTER COLUMN group_profile DROP NOT NULL,
    ALTER COLUMN pin_image DROP NOT NULL;

ALTER TABLE users
    ALTER COLUMN profile_picture DROP NOT NULL,
    ALTER COLUMN profile_picture_small DROP NOT NULL;

ALTER TABLE users ADD COLUMN IF NOT EXISTS profile_picture_exists boolean not null default false;
UPDATE users SET profile_picture_exists = (profile_picture IS NOT NULL);

DELETE FROM pins WHERE pin_image IS NULL;