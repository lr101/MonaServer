ALTER TABLE users
    ALTER COLUMN reset_password_expiration TYPE TIMESTAMP WITH TIME ZONE USING reset_password_expiration AT TIME ZONE 'UTC';
ALTER TABLE users
    ALTER COLUMN code_expiration TYPE TIMESTAMP WITH TIME ZONE USING code_expiration AT TIME ZONE 'UTC';
ALTER TABLE users
    ALTER COLUMN last_username_update TYPE TIMESTAMP WITH TIME ZONE USING last_username_update AT TIME ZONE 'UTC';

ALTER TABLE users    ADD COLUMN IF NOT EXISTS xp int not null default 0;


CREATE TABLE IF NOT EXISTS user_achievement
(
    id uuid not null primary key,
    user_id        UUID                     NOT NULL,
    achievement_id INT                      NOT NULL,
    claimed        BOOLEAN                  NOT NULL DEFAULT FALSE,
    creation_date  timestamp with time zone not null,
    update_date    timestamp with time zone not null,
    CONSTRAINT unique_user_achievement UNIQUE (user_id, achievement_id),
    CONSTRAINT fk_achievement_user FOREIGN KEY (user_id) REFERENCES users (id) on delete cascade
);

ALTER TABLE users ADD COLUMN IF NOT EXISTS  selected_batch uuid null;
ALTER TABLE users ADD CONSTRAINT fk_selected_batch FOREIGN KEY (selected_batch) REFERENCES user_achievement(id);
ALTER TABLE likes DROP CONSTRAINT fk_likes_pin;
ALTER TABLE likes DROP CONSTRAINT fk_likes_user;

ALTER TABLE likes ADD CONSTRAINT fk_likes_pin FOREIGN KEY (pin_id) REFERENCES pins(id) on delete cascade;
ALTER TABLE likes ADD CONSTRAINT fk_likes_user FOREIGN KEY (user_id) REFERENCES users(id) on delete cascade;

UPDATE users u SET xp = (
    SELECT COUNT(*) * 5
    FROM pins
    WHERE creator_id = u.id
);


