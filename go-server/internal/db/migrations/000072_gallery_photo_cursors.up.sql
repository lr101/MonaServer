-- Photo galleries seek by photo identity rather than reloading every pin's
-- history. Cover contributor scopes and the global observed-at cursor.
CREATE INDEX pin_photos_gallery_cursor_idx ON pin_photos (observed_at DESC, id DESC);
CREATE INDEX pin_photos_contributor_gallery_idx ON pin_photos (contributor_id, observed_at DESC, id DESC);
