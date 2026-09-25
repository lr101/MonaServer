ALTER TABLE groups
    ADD COLUMN group_xp INTEGER NOT NULL DEFAULT 0 CHECK (group_xp >= 0);

CREATE TABLE group_xp_ledger (
    group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    award_key TEXT NOT NULL,
    xp_awarded INTEGER NOT NULL CHECK (xp_awarded > 0),
    awarded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (group_id, award_key)
);

INSERT INTO group_xp_ledger (group_id, award_key, xp_awarded)
SELECT p.group_id, 'pin:' || p.id::text, 5
FROM pins p
JOIN groups g ON g.id = p.group_id
WHERE p.is_deleted = FALSE AND g.is_deleted = FALSE
ON CONFLICT (group_id, award_key) DO NOTHING;

UPDATE groups g
SET group_xp = COALESCE((
    SELECT SUM(l.xp_awarded)::INTEGER
    FROM group_xp_ledger l
    WHERE l.group_id = g.id
), 0);
