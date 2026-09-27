package db

import (
	"context"
	"testing"

	"github.com/google/uuid"

	"github.com/lrprojects/monaserver/internal/apperrors"
)

func TestGroupPinDesignCatalogAdvancesRevisionAndRejectsStaleWrite(t *testing.T) {
	q, cleanup := t02Database(t)
	defer cleanup()
	ctx := context.Background()

	userID := uuid.New()
	if _, err := q.Pool().Exec(ctx, `
		INSERT INTO users (id, username, password, email_confirmed, creation_date, update_date)
		VALUES ($1, 'pin-design-revision-user', 'hash', FALSE, NOW(), NOW())`, userID); err != nil {
		t.Fatalf("insert group admin: %v", err)
	}
	groupID, err := q.CreateGroup(ctx, Group{
		ID: uuid.New(), Name: "Pin design revisions", AdminID: userID,
	})
	if err != nil {
		t.Fatalf("create group: %v", err)
	}

	first := []GroupPinDesign{DefaultGroupPinDesign("moss")}
	created, err := q.UpdateGroupPinDesignCatalog(ctx, groupID, 1, first)
	if err != nil {
		t.Fatalf("save initial catalog: %v", err)
	}
	if created.Revision != 2 || len(created.Designs) != 1 {
		t.Fatalf("initial save = %#v, want revision 2 with one design", created)
	}

	second := []GroupPinDesign{DefaultGroupPinDesign("moss"), DefaultGroupPinDesign("sunset")}
	updated, err := q.UpdateGroupPinDesignCatalog(ctx, groupID, created.Revision, second)
	if err != nil {
		t.Fatalf("save revised catalog: %v", err)
	}
	if updated.Revision != 3 || len(updated.Designs) != 2 {
		t.Fatalf("revised save = %#v, want revision 3 with two designs", updated)
	}

	if _, err := q.UpdateGroupPinDesignCatalog(ctx, groupID, created.Revision, first); err != apperrors.ErrConflict {
		t.Fatalf("stale save error = %v, want conflict", err)
	}
	latest, err := q.GetGroupPinDesignCatalog(ctx, groupID)
	if err != nil {
		t.Fatalf("read catalog after stale save: %v", err)
	}
	if latest.Revision != 3 || len(latest.Designs) != 2 {
		t.Fatalf("catalog after stale save = %#v, want unchanged revision 3 with two designs", latest)
	}
}
