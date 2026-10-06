-- Keep likes on a former contributor’s photo separate from the parent pin owner.
CREATE OR REPLACE FUNCTION user_achievement_is_current(
    p_user_id UUID,
    p_achievement_id INT
) RETURNS BOOLEAN
LANGUAGE SQL
STABLE
AS $function$
    SELECT (p_achievement_id NOT IN (0, 3, 9, 10, 11, 12, 13, 16, 20, 21, 24, 25, 26, 27, 28, 29) AND EXISTS (
        SELECT 1
        FROM user_achievement_reward_ledger
        WHERE user_id = p_user_id
          AND achievement_id = p_achievement_id
          AND definition_version < 8
    )) OR CASE
        WHEN p_achievement_id IN (3, 9, 12, 16) THEN
            (SELECT COUNT(*) FROM (
                SELECT p.id FROM pins p
                WHERE p.creator_id = p_user_id AND p.is_deleted = FALSE
                UNION
                SELECT pp.pin_id FROM pin_photos pp
                JOIN pins p ON p.id = pp.pin_id
                WHERE pp.contributor_id = p_user_id AND pp.is_original = FALSE
                  AND p.is_deleted = FALSE
            ) contributed_pins) >=
            CASE p_achievement_id
                WHEN 3 THEN 2 WHEN 9 THEN 40 WHEN 12 THEN 200 ELSE 400
            END
        WHEN p_achievement_id IN (24, 25, 26) THEN
            (SELECT COUNT(*)
             FROM pin_photos pp
             JOIN pins p ON p.id = pp.pin_id
             WHERE pp.contributor_id = p_user_id AND pp.is_original = FALSE
               AND p.is_deleted = FALSE) >=
            CASE p_achievement_id WHEN 24 THEN 1 WHEN 25 THEN 10 ELSE 50 END
        WHEN p_achievement_id IN (27, 28, 29) THEN
            (SELECT COUNT(DISTINCT report.pin_id)
             FROM pin_gone_reports report
             JOIN pins p ON p.id = report.pin_id
             WHERE report.user_id = p_user_id AND p.is_deleted = FALSE) >=
            CASE p_achievement_id WHEN 27 THEN 1 WHEN 28 THEN 10 ELSE 50 END
        WHEN p_achievement_id IN (0, 10, 11, 20) THEN
            (SELECT COUNT(DISTINCT b.gid_0)
             FROM pins p
             JOIN admin2_boundaries b ON b.id = p.state_province_id
             WHERE p.is_deleted = FALSE AND b.gid_0 IS NOT NULL AND b.gid_0 <> ''
               AND (p.creator_id = p_user_id OR EXISTS (
                   SELECT 1 FROM pin_photos pp WHERE pp.pin_id = p.id
                     AND pp.contributor_id = p_user_id AND pp.is_original = FALSE))) >=
            CASE p_achievement_id
                WHEN 0 THEN 2 WHEN 10 THEN 10 WHEN 11 THEN 25 ELSE 50
            END
        WHEN p_achievement_id IN (2, 4) THEN
            (SELECT COUNT(DISTINCT m.group_id)
             FROM members m
             JOIN groups g ON g.id = m.group_id
             WHERE m.user_id = p_user_id AND m.is_deleted = FALSE AND g.is_deleted = FALSE) >=
            CASE p_achievement_id WHEN 2 THEN 2 ELSE 5 END
        WHEN p_achievement_id IN (13, 21) THEN
            (SELECT COUNT(DISTINCT p.group_id)
             FROM pins p
             JOIN groups g ON g.id = p.group_id
             WHERE p.is_deleted = FALSE AND p.is_gone = FALSE AND g.is_deleted = FALSE
               AND (p.creator_id = p_user_id OR EXISTS (
                   SELECT 1 FROM pin_photos pp WHERE pp.pin_id = p.id
                     AND pp.contributor_id = p_user_id AND pp.is_original = FALSE))) >=
            CASE p_achievement_id WHEN 13 THEN 3 ELSE 10 END
        WHEN p_achievement_id IN (5, 7, 14, 22) THEN
            (SELECT COUNT(*)
             FROM likes l
             JOIN pins p ON p.id = l.pin_id
             LEFT JOIN pin_photos pp ON pp.id = l.photo_id
             WHERE l.user_id = p_user_id
               AND CASE WHEN pp.id IS NULL THEN p.creator_id ELSE pp.contributor_id END <> p_user_id
               AND p.is_deleted = FALSE
               AND l.like_all = TRUE) >=
            CASE p_achievement_id
                WHEN 5 THEN 20 WHEN 7 THEN 200 WHEN 14 THEN 400 ELSE 1000
            END
        WHEN p_achievement_id IN (6, 8, 15, 23) THEN
            (SELECT COUNT(*)
             FROM likes l
             JOIN pins p ON p.id = l.pin_id
             LEFT JOIN pin_photos pp ON pp.id = l.photo_id
             WHERE CASE WHEN pp.id IS NULL THEN p.creator_id ELSE pp.contributor_id END = p_user_id
               AND l.user_id <> p_user_id AND p.is_deleted = FALSE
               AND l.like_all = TRUE) >=
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
