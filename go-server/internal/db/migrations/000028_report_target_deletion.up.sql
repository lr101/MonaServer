-- Keep structured report targets reviewable after their account is removed.
-- Target columns intentionally do not reference users with a foreign key, so
-- this trigger preserves the immutable target snapshot for both soft and hard
-- deletion paths without changing the users table's legacy lifecycle.

CREATE OR REPLACE FUNCTION mark_deleted_report_target() RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'DELETE' OR (OLD.is_deleted IS DISTINCT FROM TRUE AND NEW.is_deleted = TRUE) THEN
        UPDATE reports
        SET target_deleted = TRUE,
            target_name = COALESCE(target_name, OLD.username),
            updated_at = now()
        WHERE target_id = OLD.id
          AND (target_kind IS NULL OR target_kind IN ('user', 'account'));
    END IF;
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS reports_mark_target_deleted ON users;
CREATE TRIGGER reports_mark_target_deleted
AFTER UPDATE OF is_deleted OR DELETE ON users
FOR EACH ROW
EXECUTE FUNCTION mark_deleted_report_target();
