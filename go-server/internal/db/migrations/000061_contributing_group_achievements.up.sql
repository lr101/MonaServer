CREATE OR REPLACE FUNCTION user_achievement_is_current(
    p_user_id UUID,
    p_achievement_id INT
) RETURNS BOOLEAN
LANGUAGE SQL
STABLE
AS $function$
    SELECT (p_achievement_id NOT IN (0, 10, 11, 20, 13, 21) AND EXISTS (
        SELECT 1
        FROM user_achievement_reward_ledger
        WHERE user_id = p_user_id
          AND achievement_id = p_achievement_id
          AND definition_version < 7
    )) OR CASE
        WHEN p_achievement_id IN (3, 9, 12, 16) THEN
            (SELECT COUNT(*) FROM pins
             WHERE creator_id = p_user_id AND is_deleted = FALSE) >=
            CASE p_achievement_id
                WHEN 3 THEN 2 WHEN 9 THEN 40 WHEN 12 THEN 200 ELSE 400
            END
        WHEN p_achievement_id IN (0, 10, 11, 20) THEN
            (SELECT COUNT(DISTINCT b.gid_0)
             FROM pins p
             JOIN admin2_boundaries b ON b.id = p.state_province_id
             WHERE p.creator_id = p_user_id AND p.is_deleted = FALSE
               AND b.gid_0 IS NOT NULL AND b.gid_0 <> '') >=
            CASE p_achievement_id
                WHEN 0 THEN 2 WHEN 10 THEN 10 WHEN 11 THEN 25 ELSE 50
            END
        WHEN p_achievement_id IN (2, 4) THEN
            (SELECT COUNT(DISTINCT m.group_id)
             FROM members m
             JOIN groups g ON g.id = m.group_id
             WHERE m.user_id = p_user_id AND m.is_deleted = FALSE AND g.is_deleted = FALSE) >=
            CASE p_achievement_id
                WHEN 2 THEN 2 ELSE 5
            END
        WHEN p_achievement_id IN (13, 21) THEN
            (SELECT COUNT(DISTINCT p.group_id)
             FROM pins p
             JOIN groups g ON g.id = p.group_id
             WHERE p.creator_id = p_user_id AND p.is_deleted = FALSE
               AND p.is_gone = FALSE AND g.is_deleted = FALSE) >=
            CASE p_achievement_id WHEN 13 THEN 3 ELSE 10 END
        WHEN p_achievement_id IN (5, 7, 14, 22) THEN
            (SELECT COUNT(*)
             FROM likes l
             JOIN pins p ON p.id = l.pin_id
             WHERE l.user_id = p_user_id AND p.creator_id <> p_user_id AND p.is_deleted = FALSE
               AND (l.like_all OR l.like_location OR l.like_photography OR l.like_art)) >=
            CASE p_achievement_id
                WHEN 5 THEN 20 WHEN 7 THEN 200 WHEN 14 THEN 400 ELSE 1000
            END
        WHEN p_achievement_id IN (6, 8, 15, 23) THEN
            (SELECT COUNT(*)
             FROM likes l
             JOIN pins p ON p.id = l.pin_id
             WHERE p.creator_id = p_user_id AND l.user_id <> p_user_id AND p.is_deleted = FALSE
               AND (l.like_all OR l.like_location OR l.like_photography OR l.like_art)) >=
            CASE p_achievement_id
                WHEN 6 THEN 20 WHEN 8 THEN 200 WHEN 15 THEN 400 ELSE 1000
            END
        WHEN p_achievement_id IN (17, 18, 19) THEN
            (SELECT COUNT(DISTINCT pp.pin_id)
             FROM pin_photos pp
             JOIN pins p ON p.id = pp.pin_id
             WHERE p.creator_id = p_user_id AND p.is_deleted = FALSE AND p.is_gone = FALSE) >=
            CASE p_achievement_id WHEN 17 THEN 2 WHEN 18 THEN 40 ELSE 200 END
        ELSE FALSE
    END;
$function$;

-- A prior group-joining reward does not complete the new contribution goal.
UPDATE users u
SET selected_batch = NULL, update_date = NOW()
FROM user_achievement ua
WHERE ua.id = u.selected_batch
  AND ua.achievement_id = 21
  AND NOT user_achievement_is_current(u.id, 21);

UPDATE users u
SET selected_batch_color = 'default', update_date = NOW()
WHERE u.selected_batch_color = '#FFC2185B'
  AND NOT user_achievement_is_current(u.id, 13);

UPDATE user_achievement ua
SET claimed = FALSE, update_date = NOW()
WHERE ua.achievement_id IN (13, 21)
  AND ua.claimed = TRUE
  AND NOT user_achievement_is_current(ua.user_id, ua.achievement_id);
