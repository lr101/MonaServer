-- Keep the parent pin for visibility and deletion, and give each photograph
-- its own like identity. Migration 38 created each original photo with id = pin id.
ALTER TABLE likes ADD COLUMN photo_id UUID;

UPDATE likes SET photo_id = pin_id;

ALTER TABLE likes ALTER COLUMN photo_id SET NOT NULL;
ALTER TABLE likes DROP CONSTRAINT unique_like_user_pin;
ALTER TABLE likes
    ADD CONSTRAINT unique_like_user_photo UNIQUE (user_id, photo_id);

CREATE INDEX likes_photo_id_idx ON likes (photo_id);
