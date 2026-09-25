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
