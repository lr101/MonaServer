CREATE TABLE pin_photos (
    id UUID PRIMARY KEY,
    pin_id UUID NOT NULL REFERENCES pins(id) ON DELETE CASCADE,
    contributor_id UUID REFERENCES users(id) ON DELETE SET NULL,
    contributor_username TEXT NOT NULL,
    image_key TEXT NOT NULL UNIQUE,
    idempotency_key UUID,
    request_hash BYTEA,
    caption TEXT,
    observed_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_original BOOLEAN NOT NULL DEFAULT FALSE,
    CHECK ((idempotency_key IS NULL) = (request_hash IS NULL))
);

CREATE UNIQUE INDEX pin_photos_one_original_per_pin
    ON pin_photos (pin_id) WHERE is_original = TRUE;
CREATE UNIQUE INDEX pin_photos_contributor_idempotency_idx
    ON pin_photos (contributor_id, idempotency_key)
    WHERE idempotency_key IS NOT NULL;
CREATE INDEX pin_photos_pin_observed_idx
    ON pin_photos (pin_id, observed_at, id);

INSERT INTO pin_photos (
    id, pin_id, contributor_id, contributor_username, image_key,
    caption, observed_at, created_at, is_original
)
SELECT p.id, p.id, p.creator_id, COALESCE(u.username, 'Former user'),
       'pins/' || p.id || '.png', p.description, p.creation_date,
       p.creation_date, TRUE
FROM pins p
LEFT JOIN users u ON u.id = p.creator_id;
