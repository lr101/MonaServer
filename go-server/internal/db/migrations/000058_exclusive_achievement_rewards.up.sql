ALTER TABLE user_achievement_reward_ledger
    DROP CONSTRAINT user_achievement_reward_ledger_xp_awarded_check;

ALTER TABLE user_achievement_reward_ledger
    ADD CONSTRAINT user_achievement_reward_ledger_xp_awarded_check
    CHECK (xp_awarded >= 0);

WITH awards AS (
    SELECT user_id, achievement_id, xp_awarded
    FROM user_achievement_reward_ledger
    WHERE achievement_id IN (4, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 18, 19, 20, 21, 22, 23)
      AND xp_awarded > 0
    FOR UPDATE
), cleared AS (
    UPDATE user_achievement_reward_ledger ledger
    SET xp_awarded = 0
    FROM awards
    WHERE ledger.user_id = awards.user_id
      AND ledger.achievement_id = awards.achievement_id
    RETURNING awards.user_id, awards.xp_awarded
), totals AS (
    SELECT user_id, SUM(xp_awarded)::INTEGER AS xp_to_remove
    FROM cleared
    GROUP BY user_id
)
UPDATE users u
SET xp = GREATEST(u.xp - totals.xp_to_remove, 0),
    update_date = NOW()
FROM totals
WHERE u.id = totals.user_id;

UPDATE users u
SET selected_batch = NULL,
    update_date = NOW()
FROM user_achievement ua
WHERE ua.id = u.selected_batch
  AND ua.achievement_id NOT IN (11, 12, 13, 14, 15, 16, 19, 20, 21, 22, 23);

UPDATE users u
SET selected_batch_color = 'default',
    update_date = NOW()
WHERE u.selected_batch_color <> 'default'
  AND NOT EXISTS (
      SELECT 1
      FROM user_achievement ua
      WHERE ua.user_id = u.id
        AND ua.claimed = TRUE
        AND (
            (ua.achievement_id = 4 AND u.selected_batch_color IN ('#FF7CB342', '#FF8BC34A'))
            OR (ua.achievement_id = 7 AND u.selected_batch_color IN ('#FFE53935', '#FFFF5252'))
            OR (ua.achievement_id = 8 AND u.selected_batch_color IN ('#FFC62828', '#FFFF5252'))
            OR (ua.achievement_id = 9 AND u.selected_batch_color IN ('#FF26A69A', '#FF64FFDA'))
            OR (ua.achievement_id = 10 AND u.selected_batch_color IN ('#FFD81B60', '#FFE91E63'))
            OR (ua.achievement_id = 18 AND u.selected_batch_color = '#FFFF7043')
        )
  );

WITH removed AS (
    DELETE FROM group_xp_ledger
    WHERE award_key IN (
        'achievement:2', 'achievement:3', 'achievement:5', 'achievement:6',
        'achievement:8', 'achievement:9', 'achievement:11', 'achievement:12'
    )
    RETURNING group_id, xp_awarded
), totals AS (
    SELECT group_id, SUM(xp_awarded)::INTEGER AS xp_to_remove
    FROM removed
    GROUP BY group_id
)
UPDATE groups g
SET group_xp = GREATEST(g.group_xp - totals.xp_to_remove, 0),
    update_date = NOW()
FROM totals
WHERE g.id = totals.group_id;

UPDATE groups g
SET pin_style = COALESCE((
        SELECT earned.pin_style
        FROM group_pin_style_unlocks earned
        WHERE earned.group_id = g.id
          AND earned.achievement_id NOT IN (1, 4, 7, 10)
        ORDER BY earned.achievement_id
        LIMIT 1
    ), 'classic'),
    update_date = NOW()
WHERE EXISTS (
    SELECT 1
    FROM group_pin_style_unlocks easy_reward
    WHERE easy_reward.group_id = g.id
      AND easy_reward.pin_style = g.pin_style
      AND easy_reward.achievement_id IN (1, 4, 7, 10)
);

DELETE FROM group_pin_style_unlocks
WHERE achievement_id IN (1, 4, 7, 10);
