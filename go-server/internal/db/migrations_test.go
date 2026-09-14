package db

import (
	"context"
	"os"
	"testing"
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
