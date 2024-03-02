
ALTER TABLE groups ADD COLUMN IF NOT EXISTS is_deleted bool not null default false;
ALTER TABLE pins ADD COLUMN IF NOT EXISTS is_deleted bool not null default false;
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_deleted bool not null default false;



ALTER TABLE  IF EXISTS  users ADD COLUMN IF NOT EXISTS user_id BIGSERIAL;
UPDATE users SET user_id = DEFAULT;

ALTER TABLE members ADD COLUMN IF NOT EXISTS member_id bigint;
ALTER TABLE pins ADD COLUMN IF NOT EXISTS creator_id bigint;
ALTER TABLE groups ADD COLUMN IF NOT EXISTS admin_id bigint;

DO $$
    DECLARE
        id INTEGER;
        member_username VARCHAR(255);
    BEGIN
        -- Loop through each record in the members table
        FOR member_username IN SELECT username FROM members LOOP
                -- Find the corresponding user_id for the current username
                SELECT user_id INTO id FROM users WHERE username = member_username;

                -- Update the foreign key column with the new user_id
                UPDATE members SET member_id = id WHERE username = member_username;
            END LOOP;
    EXCEPTION
        WHEN OTHERS THEN
            -- Handle any other exceptions occurring outside of the loop
            RAISE NOTICE 'An error occurred outside of the loop';
    END $$;

DO $$
    DECLARE
        id INTEGER;
        member_username VARCHAR(255);
    BEGIN
        -- Loop through each record in the members table
        FOR member_username IN SELECT group_admin FROM groups LOOP
                -- Find the corresponding user_id for the current username
                SELECT user_id INTO id FROM users WHERE username = member_username;

                -- Update the foreign key column with the new user_id
                UPDATE groups SET admin_id = id WHERE group_admin = member_username;
            END LOOP;
    EXCEPTION
        WHEN OTHERS THEN
            -- Handle any other exceptions occurring outside of the loop
            RAISE NOTICE 'An error occurred outside of the loop';
    END $$;

DO $$
    DECLARE
        u_id INTEGER;
        member_username VARCHAR(255);
    BEGIN
        -- Loop through each record in the members table
        FOR member_username IN SELECT creation_user FROM pins LOOP
                -- Find the corresponding user_id for the current username
                SELECT user_id INTO u_id FROM users WHERE username = member_username;

                -- Update the foreign key column with the new user_id
                UPDATE pins SET creator_id = u_id WHERE creation_user = member_username;
            END LOOP;
    EXCEPTION
        WHEN OTHERS THEN
            -- Handle any other exceptions occurring outside of the loop
            RAISE NOTICE 'An error occurred outside of the loop';
    END $$;



ALTER TABLE IF EXISTS  groups
    DROP CONSTRAINT IF EXISTS fka9d16foh70dh031qaipyt53om; -- Drop existing foreign key constraint

ALTER TABLE IF EXISTS  members
    DROP CONSTRAINT IF EXISTS fkn0wccjg5nnc1fpme0tbskrqyk; -- Drop existing foreign key constraint

ALTER TABLE IF EXISTS  pins
    DROP CONSTRAINT IF EXISTS fkcmfp4avd369iporoc0wul4wvf; -- Drop existing foreign key constraint

ALTER TABLE IF EXISTS  users DROP CONSTRAINT IF EXISTS users_pkey;
ALTER TABLE IF EXISTS  users ADD CONSTRAINT users_pkey_id PRIMARY KEY (user_id);

ALTER TABLE IF EXISTS  members
    ADD CONSTRAINT fk_members_username FOREIGN KEY (member_id) REFERENCES users(user_id) ON UPDATE CASCADE ON DELETE CASCADE;
ALTER TABLE IF EXISTS  members DROP COLUMN IF EXISTS  username;

ALTER TABLE IF EXISTS  groups
    ADD CONSTRAINT fk_groups_group_admin FOREIGN KEY (admin_id) REFERENCES users(user_id) ON UPDATE CASCADE ON DELETE CASCADE;
ALTER TABLE IF EXISTS  groups DROP COLUMN IF EXISTS  group_admin;

ALTER TABLE IF EXISTS  pins
    ADD CONSTRAINT fk_pins_creation_user FOREIGN KEY (creator_id) REFERENCES users(user_id) ON UPDATE CASCADE ON DELETE CASCADE;
ALTER TABLE IF EXISTS  pins DROP COLUMN IF EXISTS creation_user;


ALTER TABLE IF EXISTS users ALTER COLUMN  username DROP NOT NULL;
ALTER TABLE IF EXISTS users ADD CONSTRAINT unique_username UNIQUE (username);
