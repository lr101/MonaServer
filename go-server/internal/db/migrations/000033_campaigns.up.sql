CREATE TABLE IF NOT EXISTS campaigns
(
    id                 uuid                     NOT NULL PRIMARY KEY,
    name               varchar(200)             NOT NULL,
    channel            varchar(16)              NOT NULL,
    subject            varchar(200),
    title              varchar(200),
    body               varchar(10000)           NOT NULL,
    status             varchar(16)              NOT NULL DEFAULT 'draft',
    revision           bigint                   NOT NULL DEFAULT 1,
    created_at         timestamp with time zone NOT NULL DEFAULT now(),
    updated_at         timestamp with time zone NOT NULL DEFAULT now(),
    created_by_user_id uuid                     NOT NULL REFERENCES users (id) ON DELETE RESTRICT,
    CONSTRAINT campaigns_channel_check CHECK (channel IN ('email', 'push')),
    CONSTRAINT campaigns_status_check CHECK (status IN ('draft', 'active', 'archived')),
    CONSTRAINT campaigns_revision_check CHECK (revision >= 1),
    CONSTRAINT campaigns_content_check CHECK (
        (channel = 'email' AND subject IS NOT NULL AND btrim(subject) <> '' AND title IS NULL)
        OR (channel = 'push' AND title IS NOT NULL AND btrim(title) <> '' AND subject IS NULL)
    ),
    CONSTRAINT campaigns_required_text_check CHECK (
        btrim(name) <> '' AND btrim(body) <> ''
    )
);

CREATE INDEX IF NOT EXISTS idx_campaigns_created_at_id
    ON campaigns (created_at DESC, id DESC);
