package db

import (
	"context"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
)

func TestMigration23RestoresMembersSoftDeleteColumn(t *testing.T) {
	dsn := os.Getenv("TEST_DATABASE_URL")
	if dsn == "" {
		t.Skip("TEST_DATABASE_URL not set; skipping integration test")
	}

	pool, err := NewPool(context.Background(), dsn)
	if err != nil {
		t.Fatalf("connect to test database: %v", err)
	}
	defer pool.Close()

	tx, err := pool.Begin(context.Background())
	if err != nil {
		t.Fatalf("begin transaction: %v", err)
	}
	defer tx.Rollback(context.Background())

	if _, err := tx.Exec(context.Background(), `
		CREATE TEMP TABLE members (
			group_id uuid NOT NULL,
			user_id uuid NOT NULL,
			active boolean NOT NULL DEFAULT true
		) ON COMMIT DROP
	`); err != nil {
		t.Fatalf("create legacy members table: %v", err)
	}
	if _, err := tx.Exec(context.Background(), `
		INSERT INTO members (group_id, user_id, active)
		VALUES
			('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', true),
			('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000003', false)
	`); err != nil {
		t.Fatalf("insert legacy member: %v", err)
	}

	migration, err := migrationsFS.ReadFile("migrations/000023_restore_members_is_deleted.up.sql")
	if err != nil {
		t.Fatalf("read migration 23: %v", err)
	}
	if _, err := tx.Exec(context.Background(), string(migration)); err != nil {
		t.Fatalf("apply migration 23: %v", err)
	}

	rows, err := tx.Query(context.Background(), "SELECT active, is_deleted FROM members ORDER BY user_id")
	if err != nil {
		t.Fatalf("read restored is_deleted values: %v", err)
	}
	defer rows.Close()

	want := [][2]bool{{true, false}, {false, true}}
	var got [][2]bool
	for rows.Next() {
		var values [2]bool
		if err := rows.Scan(&values[0], &values[1]); err != nil {
			t.Fatalf("scan restored is_deleted values: %v", err)
		}
		got = append(got, values)
	}
	if err := rows.Err(); err != nil {
		t.Fatalf("iterate restored is_deleted values: %v", err)
	}
	if len(got) != len(want) || got[0] != want[0] || got[1] != want[1] {
		t.Fatalf("restored membership states = %v, want %v", got, want)
	}
}

func TestMigration37BackfillsPinsWithNullCreationDate(t *testing.T) {
	dsn := os.Getenv("TEST_DATABASE_URL")
	if dsn == "" {
		t.Skip("TEST_DATABASE_URL not set; skipping integration test")
	}

	pool, err := NewPool(context.Background(), dsn)
	if err != nil {
		t.Fatalf("connect to test database: %v", err)
	}
	defer pool.Close()

	ctx := context.Background()
	tx, err := pool.Begin(ctx)
	if err != nil {
		t.Fatalf("begin transaction: %v", err)
	}
	defer tx.Rollback(ctx)

	schema := "pin_photo_migration_test_" + strings.ReplaceAll(uuid.NewString(), "-", "")
	if _, err := tx.Exec(ctx, "CREATE SCHEMA "+schema); err != nil {
		t.Fatalf("create isolated schema: %v", err)
	}
	if _, err := tx.Exec(ctx, "SET LOCAL search_path TO "+schema); err != nil {
		t.Fatalf("set isolated schema: %v", err)
	}
	if _, err := tx.Exec(ctx, `
		CREATE TABLE users (id uuid PRIMARY KEY, username text);
		CREATE TABLE pins (
			id uuid PRIMARY KEY,
			creator_id uuid,
			description text,
			creation_date timestamptz,
			update_date timestamptz
		)`); err != nil {
		t.Fatalf("create legacy tables: %v", err)
	}
	updateDate := time.Date(2024, 3, 4, 5, 6, 7, 0, time.UTC)
	pinID := uuid.New()
	if _, err := tx.Exec(ctx, `INSERT INTO pins (id, creation_date, update_date) VALUES ($1, NULL, $2)`, pinID, updateDate); err != nil {
		t.Fatalf("insert legacy pin with null creation date: %v", err)
	}

	migration, err := migrationsFS.ReadFile("migrations/000038_pin_photos.up.sql")
	if err != nil {
		t.Fatalf("read pin photos migration: %v", err)
	}
	if _, err := tx.Exec(ctx, string(migration)); err != nil {
		t.Fatalf("apply pin photos migration: %v", err)
	}

	var observedAt, createdAt time.Time
	if err := tx.QueryRow(ctx, `SELECT observed_at, created_at FROM pin_photos WHERE pin_id = $1`, pinID).Scan(&observedAt, &createdAt); err != nil {
		t.Fatalf("read backfilled original photo: %v", err)
	}
	if !observedAt.Equal(updateDate) || !createdAt.Equal(updateDate) {
		t.Fatalf("backfilled photo dates = %s/%s, want %s/%s", observedAt, createdAt, updateDate, updateDate)
	}
}

func TestMigration43BackfillsAchievementRewardsWithoutChangingUserXP(t *testing.T) {
	dsn := os.Getenv("TEST_DATABASE_URL")
	if dsn == "" {
		t.Skip("TEST_DATABASE_URL not set; skipping integration test")
	}

	pool, err := NewPool(context.Background(), dsn)
	if err != nil {
		t.Fatalf("connect to test database: %v", err)
	}
	defer pool.Close()

	ctx := context.Background()
	tx, err := pool.Begin(ctx)
	if err != nil {
		t.Fatalf("begin transaction: %v", err)
	}
	defer tx.Rollback(ctx)

	schema := "achievement_reward_migration_test_" + strings.ReplaceAll(uuid.NewString(), "-", "")
	if _, err := tx.Exec(ctx, "CREATE SCHEMA "+schema); err != nil {
		t.Fatalf("create isolated migration schema: %v", err)
	}
	if _, err := tx.Exec(ctx, "SET LOCAL search_path TO "+schema); err != nil {
		t.Fatalf("set isolated migration search path: %v", err)
	}
	if _, err := tx.Exec(ctx, `CREATE TABLE users (id uuid PRIMARY KEY, xp integer NOT NULL DEFAULT 0)`); err != nil {
		t.Fatalf("create isolated users: %v", err)
	}
	if _, err := tx.Exec(ctx, `CREATE TABLE user_achievement (user_id uuid NOT NULL, achievement_id integer NOT NULL, claimed boolean NOT NULL, update_date timestamptz)`); err != nil {
		t.Fatalf("create isolated user achievements: %v", err)
	}
	if _, err := tx.Exec(ctx, `INSERT INTO users (id, xp) VALUES
		('00000000-0000-0000-0000-000000000001', 240),
		('00000000-0000-0000-0000-000000000002', 75)`); err != nil {
		t.Fatalf("seed legacy users: %v", err)
	}
	if _, err := tx.Exec(ctx, `INSERT INTO user_achievement (user_id, achievement_id, claimed, update_date) VALUES
		('00000000-0000-0000-0000-000000000001', 3, TRUE, '2025-01-01T00:00:00Z'),
		('00000000-0000-0000-0000-000000000001', 4, FALSE, '2025-01-02T00:00:00Z'),
		('00000000-0000-0000-0000-000000000002', 15, TRUE, '2025-01-03T00:00:00Z')`); err != nil {
		t.Fatalf("seed legacy achievement rows: %v", err)
	}

	migration, err := migrationsFS.ReadFile("migrations/000043_user_achievement_reward_ledger.up.sql")
	if err != nil {
		t.Fatalf("read migration 43: %v", err)
	}
	if _, err := tx.Exec(ctx, string(migration)); err != nil {
		t.Fatalf("apply migration 43: %v", err)
	}

	var ownerXP, otherXP int
	if err := tx.QueryRow(ctx, `SELECT xp FROM users WHERE id = '00000000-0000-0000-0000-000000000001'`).Scan(&ownerXP); err != nil {
		t.Fatalf("read first user XP: %v", err)
	}
	if err := tx.QueryRow(ctx, `SELECT xp FROM users WHERE id = '00000000-0000-0000-0000-000000000002'`).Scan(&otherXP); err != nil {
		t.Fatalf("read second user XP: %v", err)
	}
	if ownerXP != 240 || otherXP != 75 {
		t.Fatalf("migration changed historical XP: first=%d second=%d", ownerXP, otherXP)
	}

	rows, err := tx.Query(ctx, `
		SELECT achievement_id, xp_awarded, definition_version
		FROM user_achievement_reward_ledger
		ORDER BY user_id, achievement_id
	`)
	if err != nil {
		t.Fatalf("read backfilled reward ledger: %v", err)
	}
	defer rows.Close()
	type reward struct{ id, xp, version int }
	var got []reward
	for rows.Next() {
		var item reward
		if err := rows.Scan(&item.id, &item.xp, &item.version); err != nil {
			t.Fatalf("scan backfilled reward: %v", err)
		}
		got = append(got, item)
	}
	if err := rows.Err(); err != nil {
		t.Fatalf("iterate reward ledger: %v", err)
	}
	if len(got) != 2 || got[0] != (reward{id: 3, xp: 20, version: 1}) || got[1] != (reward{id: 15, xp: 20, version: 1}) {
		t.Fatalf("backfilled rewards = %v, want two prior 20 XP awards at version 1", got)
	}
}

func TestT02SnapshotOrdinalMigrationRepairsPopulatedData(t *testing.T) {
	dsn := os.Getenv("TEST_DATABASE_URL")
	if dsn == "" {
		t.Skip("TEST_DATABASE_URL not set; skipping integration test")
	}
	if err := RunMigrations(dsn); err != nil {
		t.Fatalf("migrations: %v", err)
	}

	pool, err := NewPool(context.Background(), dsn)
	if err != nil {
		t.Fatalf("connect to test database: %v", err)
	}
	defer pool.Close()
	ctx := context.Background()
	tx, err := pool.Begin(ctx)
	if err != nil {
		t.Fatalf("begin transaction: %v", err)
	}
	defer tx.Rollback(ctx)

	snapshotID := uuid.New()
	firstID, secondID := uuid.New(), uuid.New()
	if _, err := tx.Exec(ctx, `DROP INDEX idx_audience_snapshot_members_snapshot_ordinal`); err != nil {
		t.Fatalf("drop ordinal index: %v", err)
	}
	if _, err := tx.Exec(ctx, `
		INSERT INTO audience_snapshots
			(id, resource, action, payload_hash, account_count, eligible_count,
			 exclusion_count, expires_at)
		VALUES ($1, 'accounts', 'migration-test', 'payload', 2, 1, 1, NOW() + interval '1 hour')`, snapshotID); err != nil {
		t.Fatalf("insert snapshot: %v", err)
	}
	firstCreated := time.Now().UTC().Add(-2 * time.Minute)
	secondCreated := firstCreated.Add(time.Minute)
	if _, err := tx.Exec(ctx, `
		INSERT INTO audience_snapshot_members
			(snapshot_id, ordinal, resource_id, eligible, created_at)
		VALUES ($1, 0, $2, TRUE, $3), ($1, 0, $4, FALSE, $5)`,
		snapshotID, firstID, firstCreated, secondID, secondCreated); err != nil {
		t.Fatalf("insert duplicate ordinals: %v", err)
	}

	migration, err := migrationsFS.ReadFile("migrations/000025_snapshot_member_ordinal_unique.up.sql")
	if err != nil {
		t.Fatalf("read ordinal migration: %v", err)
	}
	if _, err := tx.Exec(ctx, string(migration)); err != nil {
		t.Fatalf("apply ordinal migration: %v", err)
	}

	var count int
	if err := tx.QueryRow(ctx, `
		SELECT count(*)
		FROM audience_snapshot_members
		WHERE snapshot_id = $1`, snapshotID).Scan(&count); err != nil {
		t.Fatalf("count repaired members: %v", err)
	}
	var keptID uuid.UUID
	if err := tx.QueryRow(ctx, `
		SELECT resource_id
		FROM audience_snapshot_members
		WHERE snapshot_id = $1
		ORDER BY created_at ASC
		LIMIT 1`, snapshotID).Scan(&keptID); err != nil {
		t.Fatalf("read repaired member: %v", err)
	}
	if count != 1 || keptID != firstID {
		t.Fatalf("repaired members = count %d, resource %s; want first row only", count, keptID)
	}
	var accountCount, eligibleCount, exclusionCount int64
	if err := tx.QueryRow(ctx, `
		SELECT account_count, eligible_count, exclusion_count
		FROM audience_snapshots WHERE id = $1`, snapshotID).
		Scan(&accountCount, &eligibleCount, &exclusionCount); err != nil {
		t.Fatalf("read repaired counts: %v", err)
	}
	if accountCount != 1 || eligibleCount != 1 || exclusionCount != 0 {
		t.Fatalf("repaired counts = %d/%d/%d; want 1/1/0", accountCount, eligibleCount, exclusionCount)
	}
}
