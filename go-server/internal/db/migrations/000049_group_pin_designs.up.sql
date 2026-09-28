CREATE TABLE group_pin_designs (
    group_id UUID PRIMARY KEY REFERENCES groups(id) ON DELETE CASCADE,
    revision BIGINT NOT NULL DEFAULT 1 CHECK (revision > 0),
    designs JSONB NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(designs) = 'array'),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
