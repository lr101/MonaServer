ALTER TABLE likes ADD CONSTRAINT unique_like_user_pin UNIQUE (user_id, pin_id);