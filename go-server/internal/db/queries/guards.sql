-- Guard queries: fast authorization checks used by middleware.

-- name: IsGroupAdmin :one
SELECT EXISTS (
  SELECT 1 FROM groups
  WHERE id = $1 AND admin_id = $2 AND is_deleted = FALSE
);

-- name: IsGroupMember :one
SELECT EXISTS (
  SELECT 1 FROM members m
  JOIN groups g ON g.id = m.group_id
  WHERE m.group_id = $1 AND m.user_id = $2 AND g.is_deleted = FALSE
);

-- name: IsGroupVisible :one
SELECT EXISTS (
  SELECT 1 FROM groups g
  WHERE g.id = $1 AND g.is_deleted = FALSE AND (
    g.visibility = 0
    OR EXISTS (SELECT 1 FROM members m WHERE m.group_id = g.id AND m.user_id = $2)
  )
);

-- name: IsPinCreator :one
SELECT EXISTS (
  SELECT 1 FROM pins WHERE id = $1 AND creator_id = $2 AND is_deleted = FALSE
);

-- name: IsPinGroupAdmin :one
SELECT EXISTS (
  SELECT 1 FROM pins p
  JOIN groups g ON g.id = p.group_id
  WHERE p.id = $1 AND g.admin_id = $2 AND p.is_deleted = FALSE
);

-- name: IsPinPublicOrMember :one
SELECT EXISTS (
  SELECT 1 FROM pins p
  JOIN groups g ON g.id = p.group_id
  WHERE p.id = $1 AND p.is_deleted = FALSE AND g.is_deleted = FALSE AND (
    g.visibility = 0
    OR EXISTS (SELECT 1 FROM members m WHERE m.group_id = g.id AND m.user_id = $2)
  )
);
