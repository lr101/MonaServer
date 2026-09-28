CREATE OR REPLACE FUNCTION user_achievement_is_current(
    p_user_id UUID,
    p_achievement_id INT
) RETURNS BOOLEAN
LANGUAGE SQL
STABLE
AS $function$
    SELECT EXISTS (
        SELECT 1
        FROM user_achievement_reward_ledger
        WHERE user_id = p_user_id
          AND achievement_id = p_achievement_id
          AND definition_version < 4
    ) OR CASE
        WHEN p_achievement_id IN (3, 9, 12, 16) THEN
            (SELECT COUNT(*) FROM pins
             WHERE creator_id = p_user_id AND is_deleted = FALSE) >=
            CASE p_achievement_id
                WHEN 3 THEN 2 WHEN 9 THEN 40 WHEN 12 THEN 200 ELSE 400
            END
        WHEN p_achievement_id IN (0, 10, 11, 20) THEN
            (SELECT COUNT(DISTINCT state_province_id) FROM pins
             WHERE creator_id = p_user_id AND is_deleted = FALSE AND state_province_id IS NOT NULL) >=
            CASE p_achievement_id
                WHEN 0 THEN 2 WHEN 10 THEN 12 WHEN 11 THEN 40 ELSE 100
            END
        WHEN p_achievement_id IN (2, 4, 13, 21) THEN
            (SELECT COUNT(DISTINCT m.group_id)
             FROM members m
             JOIN groups g ON g.id = m.group_id
             WHERE m.user_id = p_user_id AND m.is_deleted = FALSE AND g.is_deleted = FALSE) >=
            CASE p_achievement_id
                WHEN 2 THEN 2 WHEN 4 THEN 12 WHEN 13 THEN 40 ELSE 100
            END
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
