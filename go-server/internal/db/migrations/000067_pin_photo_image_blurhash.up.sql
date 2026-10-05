ALTER TABLE pin_photos
    ADD COLUMN image_blurhash varchar(16);

UPDATE pin_photos AS photo
SET image_blurhash = pin.image_blurhash
FROM pins AS pin
WHERE photo.pin_id = pin.id
  AND photo.is_original = TRUE
  AND pin.image_blurhash IS NOT NULL;
