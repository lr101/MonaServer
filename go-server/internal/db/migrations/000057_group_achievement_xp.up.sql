WITH awards AS (
    INSERT INTO group_xp_ledger (group_id, award_key, xp_awarded)
    SELECT
        claims.group_id,
        'achievement:' || claims.achievement_id::text,
        CASE
            WHEN claims.achievement_id IN (1, 4, 7, 10) THEN 50
            WHEN claims.achievement_id IN (2, 8, 11) THEN 150
            ELSE 400
        END
    FROM group_achievement_claims claims
    ON CONFLICT (group_id, award_key) DO NOTHING
    RETURNING group_id, xp_awarded
), totals AS (
    SELECT group_id, SUM(xp_awarded)::INTEGER AS xp_awarded
    FROM awards
    GROUP BY group_id
)
UPDATE groups g
SET group_xp = g.group_xp + totals.xp_awarded,
    update_date = NOW()
FROM totals
WHERE g.id = totals.group_id;
