-- Snapshot member ordinals form one immutable, paginated stream per snapshot.
-- Earlier versions only enforced unique resources, so repair duplicate
-- ordinals deterministically before adding the invariant for existing data.

WITH ranked_members AS (
    SELECT snapshot_id, resource_id,
           row_number() OVER (
               PARTITION BY snapshot_id, ordinal
               ORDER BY created_at ASC, resource_id ASC
           ) AS ordinal_rank
    FROM audience_snapshot_members
)
DELETE FROM audience_snapshot_members members
USING ranked_members duplicates
WHERE members.snapshot_id = duplicates.snapshot_id
  AND members.resource_id = duplicates.resource_id
  AND duplicates.ordinal_rank > 1;

-- Keep denormalized account/eligibility counts aligned with the repaired
-- immutable member set.  Device counts are delivery-specific and cannot be
-- inferred from member rows, so they are retained.
WITH member_counts AS (
    SELECT snapshot_id,
           count(*)::bigint AS account_count,
           count(*) FILTER (WHERE eligible)::bigint AS eligible_count,
           count(*) FILTER (WHERE NOT eligible)::bigint AS exclusion_count
    FROM audience_snapshot_members
    GROUP BY snapshot_id
)
UPDATE audience_snapshots snapshots
SET account_count = member_counts.account_count,
    eligible_count = member_counts.eligible_count,
    exclusion_count = member_counts.exclusion_count,
    updated_at = now()
FROM member_counts
WHERE snapshots.id = member_counts.snapshot_id;

UPDATE audience_snapshots snapshots
SET account_count = 0,
    eligible_count = 0,
    exclusion_count = 0,
    updated_at = now()
WHERE NOT EXISTS (
    SELECT 1
    FROM audience_snapshot_members members
    WHERE members.snapshot_id = snapshots.id
)
  AND (snapshots.account_count <> 0
       OR snapshots.eligible_count <> 0
       OR snapshots.exclusion_count <> 0);

CREATE UNIQUE INDEX IF NOT EXISTS idx_audience_snapshot_members_snapshot_ordinal
    ON audience_snapshot_members (snapshot_id, ordinal);
