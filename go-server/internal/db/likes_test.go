package db

import (
	"context"
	"strings"
	"testing"

	"github.com/google/uuid"
)

func TestLikeSchemaStoresOnlyNormalLikes(t *testing.T) {
	q, cleanup := t02Database(t)
	defer cleanup()

	var oldTypeColumns int
	err := q.Pool().QueryRow(context.Background(), `
		SELECT COUNT(*)
		FROM information_schema.columns
		WHERE table_schema = current_schema()
		  AND table_name = 'likes'
		  AND column_name IN ('like_location', 'like_photography', 'like_art')`,
	).Scan(&oldTypeColumns)
	if err != nil {
		t.Fatalf("count obsolete like columns: %v", err)
	}
	if oldTypeColumns != 0 {
		t.Fatalf("likes table still has %d obsolete type columns", oldTypeColumns)
	}

	var normalLikeColumn bool
	err = q.Pool().QueryRow(context.Background(), `
		SELECT EXISTS (
			SELECT 1 FROM information_schema.columns
			WHERE table_schema = current_schema()
			  AND table_name = 'likes'
			  AND column_name = 'like_all'
		)`,
	).Scan(&normalLikeColumn)
	if err != nil {
		t.Fatalf("check normal like column: %v", err)
	}
	if !normalLikeColumn {
		t.Fatal("likes table is missing the normal like column")
	}
}

func TestNormalLikeMigrationPreservesOldCategoryLikes(t *testing.T) {
	q, cleanup := t02Database(t)
	defer cleanup()
	ctx := context.Background()
	conn, err := q.Pool().Acquire(ctx)
	if err != nil {
		t.Fatalf("acquire connection: %v", err)
	}
	defer conn.Release()

	schema := "normal_like_migration_test_" + strings.ReplaceAll(uuid.NewString(), "-", "")
	if _, err := conn.Exec(ctx, "CREATE SCHEMA "+schema); err != nil {
		t.Fatalf("create isolated schema: %v", err)
	}
	defer conn.Exec(ctx, "DROP SCHEMA "+schema+" CASCADE")
	if _, err := conn.Exec(ctx, "SET search_path TO "+schema+", public"); err != nil {
		t.Fatalf("set isolated search path: %v", err)
	}
	if _, err := conn.Exec(ctx, `
		CREATE TABLE likes (
			id uuid PRIMARY KEY,
			pin_id uuid NOT NULL,
			user_id uuid NOT NULL,
			like_all boolean NOT NULL DEFAULT FALSE,
			like_location boolean NOT NULL DEFAULT FALSE,
			like_photography boolean NOT NULL DEFAULT FALSE,
			like_art boolean NOT NULL DEFAULT FALSE
		)`); err != nil {
		t.Fatalf("create legacy likes table: %v", err)
	}
	for _, flags := range [][4]bool{
		{true, false, false, false},
		{false, true, false, false},
		{false, false, true, false},
		{false, false, false, true},
		{false, false, false, false},
	} {
		if _, err := conn.Exec(ctx, `INSERT INTO likes (id, pin_id, user_id, like_all, like_location, like_photography, like_art)
			VALUES ($1, $2, $3, $4, $5, $6, $7)`, uuid.New(), uuid.New(), uuid.New(), flags[0], flags[1], flags[2], flags[3]); err != nil {
			t.Fatalf("insert legacy like: %v", err)
		}
	}

	migration, err := migrationsFS.ReadFile("migrations/000065_normal_likes_only.up.sql")
	if err != nil {
		t.Fatalf("read normal likes migration: %v", err)
	}
	if _, err := conn.Exec(ctx, string(migration)); err != nil {
		t.Fatalf("apply normal likes migration: %v", err)
	}

	var rows, normalLikes, oldColumns int
	if err := conn.QueryRow(ctx, "SELECT COUNT(*), COUNT(*) FILTER (WHERE like_all) FROM likes").Scan(&rows, &normalLikes); err != nil {
		t.Fatalf("count migrated likes: %v", err)
	}
	if rows != 4 || normalLikes != 4 {
		t.Fatalf("migrated likes = %d rows, %d normal likes; want 4/4", rows, normalLikes)
	}
	if err := conn.QueryRow(ctx, `SELECT COUNT(*) FROM information_schema.columns
		WHERE table_schema = current_schema() AND table_name = 'likes'
		AND column_name IN ('like_location', 'like_photography', 'like_art')`).Scan(&oldColumns); err != nil {
		t.Fatalf("check removed like columns: %v", err)
	}
	if oldColumns != 0 {
		t.Fatalf("migration left %d old like columns", oldColumns)
	}
}
