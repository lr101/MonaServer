ALTER TABLE groups
    ADD COLUMN pin_style TEXT NOT NULL DEFAULT 'classic'
        CHECK (pin_style IN ('classic', 'moss', 'sunset', 'aurora'));

CREATE TABLE group_achievement_claims (
    group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    achievement_id INTEGER NOT NULL CHECK (achievement_id BETWEEN 1 AND 3),
    claimed_by UUID,
    claimed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (group_id, achievement_id)
);

CREATE TABLE group_pin_style_unlocks (
    group_id UUID NOT NULL,
    pin_style TEXT NOT NULL CHECK (pin_style IN ('moss', 'sunset', 'aurora')),
    achievement_id INTEGER NOT NULL,
    unlocked_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (group_id, pin_style),
    UNIQUE (group_id, achievement_id),
    FOREIGN KEY (group_id, achievement_id)
        REFERENCES group_achievement_claims(group_id, achievement_id)
        ON DELETE CASCADE
);
