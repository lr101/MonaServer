CREATE TABLE user_achievement_reward_ledger (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    achievement_id INT NOT NULL,
    xp_awarded INT NOT NULL CHECK (xp_awarded > 0),
    definition_version INT NOT NULL CHECK (definition_version > 0),
    awarded_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    CONSTRAINT user_achievement_reward_ledger_pkey PRIMARY KEY (user_id, achievement_id)
);

-- Existing claims have already added 20 XP to users.xp. Record those awards
-- without changing totals so a revoked and later reclaimed badge cannot pay twice.
INSERT INTO user_achievement_reward_ledger (user_id, achievement_id, xp_awarded, definition_version, awarded_at)
SELECT user_id, achievement_id, 20, 1, COALESCE(update_date, NOW())
FROM user_achievement
WHERE claimed = TRUE
ON CONFLICT (user_id, achievement_id) DO NOTHING;
