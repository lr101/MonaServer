package service

import (
	"context"
	"errors"
	"strings"
	"testing"

	"github.com/google/uuid"

	"github.com/lrprojects/monaserver/internal/apperrors"
)

func TestCampaignServiceEnforcesCapabilitiesBoundsAndLifecycle(t *testing.T) {
	ctx := context.Background()
	store := NewMemoryCampaignStore()
	campaigns := NewCampaignService(store)
	reader := AdminActor{ID: uuid.New(), Capabilities: []string{"campaigns.read"}}
	writer := AdminActor{ID: uuid.New(), Capabilities: []string{"campaigns.write"}}

	if _, err := campaigns.List(ctx, AdminActor{ID: uuid.New()}, CampaignListRequest{}); !errors.Is(err, ErrAudienceForbidden) {
		t.Fatalf("list without campaigns.read error = %v, want forbidden", err)
	}
	if _, err := campaigns.Create(ctx, reader, CampaignCreateInput{Name: "Newsletter", Channel: CampaignChannelEmail, Subject: stringPtr("September"), Body: "Hello", Status: CampaignStatusDraft}); !errors.Is(err, ErrAudienceForbidden) {
		t.Fatalf("create without campaigns.write error = %v, want forbidden", err)
	}

	created, err := campaigns.Create(ctx, writer, CampaignCreateInput{
		Name: "  Newsletter  ", Channel: CampaignChannelEmail, Subject: stringPtr("  September  "), Body: "  Hello  ", Status: CampaignStatusDraft,
	})
	if err != nil {
		t.Fatalf("create campaign: %v", err)
	}
	if created.ID == uuid.Nil || created.CreatedByUserID == nil || *created.CreatedByUserID != writer.ID || created.Revision != 1 || created.Status != CampaignStatusDraft {
		t.Fatalf("created campaign = %#v, want draft revision one owned by writer", created)
	}
	if created.Name != "Newsletter" || created.Body != "Hello" || created.Title != nil || created.Subject == nil || *created.Subject != "September" {
		t.Fatalf("created email content = %#v, want subject only", created)
	}

	if _, err := campaigns.Create(ctx, writer, CampaignCreateInput{Name: "Bad push", Channel: CampaignChannelPush, Subject: stringPtr("not allowed"), Body: "Hello", Status: CampaignStatusDraft}); !errors.Is(err, ErrInvalidCampaign) {
		t.Fatalf("push subject error = %v, want invalid campaign", err)
	}
	if _, err := campaigns.Create(ctx, writer, CampaignCreateInput{Name: strings.Repeat("n", MaxCampaignNameBytes+1), Channel: CampaignChannelEmail, Subject: stringPtr("Subject"), Body: "Hello", Status: CampaignStatusDraft}); !errors.Is(err, ErrInvalidCampaign) {
		t.Fatalf("oversized name error = %v, want invalid campaign", err)
	}
	if _, err := campaigns.Create(ctx, writer, CampaignCreateInput{Name: strings.Repeat("é", MaxCampaignNameBytes), Channel: CampaignChannelEmail, Subject: stringPtr("Subject"), Body: "Hello", Status: CampaignStatusDraft}); err != nil {
		t.Fatalf("valid unicode name error = %v, want character-count bounded name accepted", err)
	}

	if _, err := campaigns.Get(ctx, AdminActor{ID: uuid.New()}, created.ID); !errors.Is(err, ErrAudienceForbidden) {
		t.Fatalf("get without campaigns.read error = %v, want forbidden", err)
	}
	got, err := campaigns.Get(ctx, reader, created.ID)
	if err != nil || got.ID != created.ID {
		t.Fatalf("get campaign = %#v, %v", got, err)
	}

	updated, err := campaigns.Update(ctx, writer, CampaignUpdateInput{
		CampaignID: created.ID, ExpectedRevision: created.Revision,
		Name: "Newsletter revised", Channel: CampaignChannelEmail, Subject: stringPtr("October"), Body: "Updated", Status: CampaignStatusActive,
	})
	if err != nil {
		t.Fatalf("update campaign: %v", err)
	}
	if updated.Revision != 2 || updated.Status != CampaignStatusActive || updated.Name != "Newsletter revised" {
		t.Fatalf("updated campaign = %#v, want active revision two", updated)
	}
	if _, err := campaigns.Update(ctx, writer, CampaignUpdateInput{CampaignID: created.ID, ExpectedRevision: created.Revision, Name: "stale", Channel: CampaignChannelEmail, Subject: stringPtr("October"), Body: "Updated", Status: CampaignStatusActive}); !errors.Is(err, apperrors.ErrConflict) {
		t.Fatalf("stale update error = %v, want conflict", err)
	}
	if err := campaigns.Delete(ctx, writer, CampaignRevisionInput{CampaignID: updated.ID, ExpectedRevision: updated.Revision}); !errors.Is(err, apperrors.ErrConflict) {
		t.Fatalf("delete active campaign error = %v, want conflict", err)
	}

	archived, err := campaigns.Archive(ctx, writer, CampaignRevisionInput{CampaignID: updated.ID, ExpectedRevision: updated.Revision})
	if err != nil {
		t.Fatalf("archive campaign: %v", err)
	}
	if archived.Status != CampaignStatusArchived || archived.Revision != 3 {
		t.Fatalf("archived campaign = %#v, want archived revision three", archived)
	}
	if _, err := campaigns.Update(ctx, writer, CampaignUpdateInput{CampaignID: archived.ID, ExpectedRevision: archived.Revision, Name: "nope", Channel: CampaignChannelEmail, Subject: stringPtr("October"), Body: "Updated", Status: CampaignStatusActive}); !errors.Is(err, apperrors.ErrConflict) {
		t.Fatalf("update archived campaign error = %v, want conflict", err)
	}
	if err := campaigns.Delete(ctx, writer, CampaignRevisionInput{CampaignID: archived.ID, ExpectedRevision: archived.Revision}); !errors.Is(err, apperrors.ErrConflict) {
		t.Fatalf("delete archived campaign error = %v, want conflict", err)
	}

	draft, err := campaigns.Create(ctx, writer, CampaignCreateInput{Name: "Disposable", Channel: CampaignChannelPush, Title: stringPtr("Notice"), Body: "Push body", Status: CampaignStatusDraft})
	if err != nil {
		t.Fatalf("create draft campaign: %v", err)
	}
	if err := campaigns.Delete(ctx, writer, CampaignRevisionInput{CampaignID: draft.ID, ExpectedRevision: draft.Revision}); err != nil {
		t.Fatalf("delete draft campaign: %v", err)
	}
	if _, err := campaigns.Get(ctx, reader, draft.ID); !errors.Is(err, apperrors.ErrNotFound) {
		t.Fatalf("get deleted draft error = %v, want not found", err)
	}
}

func TestCampaignServicePaginatesWithBoundedStableCursor(t *testing.T) {
	ctx := context.Background()
	store := NewMemoryCampaignStore()
	campaigns := NewCampaignService(store)
	actor := AdminActor{ID: uuid.New(), Capabilities: []string{"campaigns.read", "campaigns.write"}}

	for _, name := range []string{"first", "second"} {
		if _, err := campaigns.Create(ctx, actor, CampaignCreateInput{Name: name, Channel: CampaignChannelEmail, Subject: stringPtr("Subject"), Body: "Body", Status: CampaignStatusDraft}); err != nil {
			t.Fatalf("create %s: %v", name, err)
		}
	}
	first, err := campaigns.List(ctx, actor, CampaignListRequest{Limit: 1})
	if err != nil || len(first.Items) != 1 || first.NextCursor == nil {
		t.Fatalf("first page = %#v, %v; want one item and cursor", first, err)
	}
	second, err := campaigns.List(ctx, actor, CampaignListRequest{Limit: 1, Cursor: *first.NextCursor})
	if err != nil || len(second.Items) != 1 || second.NextCursor != nil || second.Items[0].ID == first.Items[0].ID {
		t.Fatalf("second page = %#v, %v; want remaining item without cursor", second, err)
	}
	if _, err := campaigns.List(ctx, actor, CampaignListRequest{Cursor: strings.Repeat("x", MaxCampaignCursorBytes+1)}); !errors.Is(err, ErrInvalidCampaign) {
		t.Fatalf("oversized cursor error = %v, want invalid campaign", err)
	}
}
