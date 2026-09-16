package service

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"
)

func TestBulkCommitRejectsChangedPayloadAndEmptySelection(t *testing.T) {
	store := NewMemoryAdminStore()
	actor := AdminActor{ID: uuid.New(), Capabilities: []string{"audience.preview", "campaign.email", "jobs.create"}}
	account := uuid.New()
	store.Users = append(store.Users, AdminUser{ID: account, Username: "alice", Email: stringPtr("alice@example.com"), EmailVerified: true})
	audienceService := NewAdminAudienceService(store)
	preview, err := audienceService.Preview(context.Background(), actor, AudiencePreviewRequest{
		Audience: Audience{Kind: AudienceSelected, Resource: AudienceAccounts, IDs: []uuid.UUID{account}},
		Action:   AdminAction{Kind: ActionEmail, Subject: "A", Body: "B"},
	})
	if err != nil {
		t.Fatalf("preview: %v", err)
	}
	if err := audienceService.CommitCheck(context.Background(), actor, preview.SnapshotID, "different", preview.Action); !errors.Is(err, ErrSnapshotBinding) {
		t.Fatalf("changed payload error = %v, want binding conflict", err)
	}
	if _, err := audienceService.Preview(context.Background(), actor, AudiencePreviewRequest{
		Audience: Audience{Kind: AudienceSelected, Resource: AudienceAccounts},
		Action:   AdminAction{Kind: ActionEmail, Subject: "A", Body: "B"},
	}); !errors.Is(err, ErrInvalidAudience) {
		t.Fatalf("empty selection error = %v, want invalid audience", err)
	}
}

func TestBulkJobExecutionRechecksActorAndDoesNotRepeatCompletedItems(t *testing.T) {
	store := NewMemoryAdminStore()
	actorID := uuid.New()
	account := uuid.New()
	store.Users = append(store.Users, AdminUser{ID: account, Username: "alice", Email: stringPtr("alice@example.com"), EmailVerified: true})
	actor := AdminActor{ID: actorID, Capabilities: []string{"audience.preview", "campaign.email", "jobs.create", "jobs.control"}}
	audienceService := NewAdminAudienceService(store)
	preview, err := audienceService.Preview(context.Background(), actor, AudiencePreviewRequest{
		Audience: Audience{Kind: AudienceSelected, Resource: AudienceAccounts, IDs: []uuid.UUID{account}},
		Action:   AdminAction{Kind: ActionEmail, Subject: "A", Body: "B"},
	})
	if err != nil {
		t.Fatalf("preview: %v", err)
	}
	bulk := NewAdminBulkService(store, audienceService, &AdminActionPorts{Email: bulkTestEmailSender{}})
	job, err := bulk.Create(context.Background(), actor, BulkJobCreateRequest{SnapshotID: preview.SnapshotID, PayloadHash: preview.PayloadHash, Action: preview.Action, IdempotencyKey: "same"})
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	if job.ID == uuid.Nil || len(store.JobItems[job.ID]) != 1 {
		t.Fatalf("unexpected job: %#v items=%d", job, len(store.JobItems[job.ID]))
	}
	first, err := bulk.ProcessItem(context.Background(), actor, job.ID, store.JobItems[job.ID][0].ID)
	if err != nil || first.Outcome != OutcomeQueued {
		t.Fatalf("process first: %#v %v", first, err)
	}
	second, err := bulk.ProcessItem(context.Background(), actor, job.ID, store.JobItems[job.ID][0].ID)
	if err != nil || second.Outcome != OutcomeQueued {
		t.Fatalf("process duplicate: %#v %v", second, err)
	}
	if got := store.JobItems[job.ID][0].AttemptCount; got != 1 {
		t.Fatalf("attempt count after duplicate = %d, want 1", got)
	}

	actor.Capabilities = []string{"jobs.create"}
	if _, err := bulk.ProcessItem(context.Background(), actor, job.ID, store.JobItems[job.ID][0].ID); !errors.Is(err, ErrAudienceForbidden) {
		t.Fatalf("revoked actor process error = %v, want forbidden", err)
	}
}

type bulkTestEmailSender struct{}

func (bulkTestEmailSender) SendCampaignEmail(context.Context, uuid.UUID, uuid.UUID, AdminAction) (ActionResult, error) {
	return ActionResult{Outcome: OutcomeQueued}, nil
}

func TestAdminAuditRedactsSecretLikeDetails(t *testing.T) {
	store := NewMemoryAdminStore()
	actor := AdminActor{ID: uuid.New(), Capabilities: []string{"audit.read"}}
	store.Audit = append(store.Audit, AdminAuditEvent{ID: uuid.New(), ActorID: &actor.ID, Action: ActionMarkCompromised, Outcome: "secured", Details: map[string]string{
		"generation": "3", "token": "opaque-secret", "password": "never", "delivery": "manual_recovery_required",
	}, OccurredAt: time.Now()})
	service := NewAdminAuditService(store)
	page, err := service.List(context.Background(), actor, "", 25, "", "")
	if err != nil {
		t.Fatalf("list audit: %v", err)
	}
	if len(page.Items) != 1 || page.Items[0].Details["token"] != "[redacted]" || page.Items[0].Details["password"] != "[redacted]" {
		t.Fatalf("secret details were not redacted: %#v", page.Items)
	}
}

func TestAdminAuditAppendBindsActorAndRedactsNewlines(t *testing.T) {
	store := NewMemoryAdminStore()
	service := NewAdminAuditService(store)
	actor := AdminActor{ID: uuid.New()}
	forged := uuid.New()
	reason := "operator\naction"
	if err := service.Append(context.Background(), actor, AdminAuditEvent{ActorID: &forged, Action: ActionRevokeSessions, Outcome: "secured", Reason: &reason, Details: map[string]string{"note": "safe", "secret": "value"}}); err != nil {
		t.Fatalf("append: %v", err)
	}
	page, err := service.List(context.Background(), AdminActor{ID: uuid.New(), Capabilities: []string{"audit.read"}}, "", 25, "", "")
	if err != nil || len(page.Items) != 1 {
		t.Fatalf("list = %#v, %v", page, err)
	}
	if page.Items[0].ActorID == nil || *page.Items[0].ActorID != actor.ID || page.Items[0].Details["secret"] != "[redacted]" || page.Items[0].Reason != nil {
		t.Fatalf("actor or secret binding failed: %#v", page.Items[0])
	}
}

func TestAdminAuditPaginationIsStable(t *testing.T) {
	store := NewMemoryAdminStore()
	when := time.Now().UTC()
	store.Audit = append(store.Audit,
		AdminAuditEvent{ID: uuid.New(), Action: ActionEmail, Outcome: "provider_accepted", OccurredAt: when},
		AdminAuditEvent{ID: uuid.New(), Action: ActionPush, Outcome: "provider_accepted", OccurredAt: when.Add(-time.Second)},
	)
	service := NewAdminAuditService(store)
	actor := AdminActor{ID: uuid.New(), Capabilities: []string{"audit.read"}}
	first, err := service.List(context.Background(), actor, "", 1, "", "")
	if err != nil || len(first.Items) != 1 || first.Next == nil {
		t.Fatalf("first page = %#v, %v", first, err)
	}
	second, err := service.List(context.Background(), actor, *first.Next, 1, "", "")
	if err != nil || len(second.Items) != 1 || second.Items[0].ID == first.Items[0].ID {
		t.Fatalf("second page = %#v, %v", second, err)
	}
}

func TestBulkWorkerRechecksRecipientEligibilityBeforeDelivery(t *testing.T) {
	store := NewMemoryAdminStore()
	actorID, account := uuid.New(), uuid.New()
	email := "alice@example.com"
	store.Users = append(store.Users, AdminUser{ID: account, Username: "alice", Email: &email, EmailVerified: true})
	actor := AdminActor{ID: actorID, Capabilities: []string{"audience.preview", "campaign.email", "jobs.create", "jobs.read"}}
	audience := NewAdminAudienceService(store)
	preview, err := audience.Preview(context.Background(), actor, AudiencePreviewRequest{Audience: Audience{Kind: AudienceSelected, Resource: AudienceAccounts, IDs: []uuid.UUID{account}}, Action: AdminAction{Kind: ActionEmail, Subject: "A", Body: "B"}})
	if err != nil {
		t.Fatalf("preview: %v", err)
	}
	sender := &countingEmailSender{}
	bulk := NewAdminBulkService(store, audience, &AdminActionPorts{Email: sender, Eligibility: alwaysIneligibleChecker{}})
	job, err := bulk.Create(context.Background(), actor, BulkJobCreateRequest{SnapshotID: preview.SnapshotID, PayloadHash: preview.PayloadHash, Action: preview.Action, IdempotencyKey: "eligibility"})
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	item, err := bulk.ProcessItem(context.Background(), actor, job.ID, store.JobItems[job.ID][0].ID)
	if err != nil {
		t.Fatalf("process: %v", err)
	}
	if item.Outcome != OutcomeSkipped || sender.calls != 0 {
		t.Fatalf("item=%#v sender calls=%d, want skipped without delivery", item, sender.calls)
	}
}

func TestBulkSecuritySelfContainmentPausesRemainingWork(t *testing.T) {
	store := NewMemoryAdminStore()
	actorID := uuid.New()
	otherID := uuid.New()
	store.Users = append(store.Users,
		AdminUser{ID: actorID, Username: "operator"},
		AdminUser{ID: otherID, Username: "other"},
	)
	now := time.Now().UTC()
	actor := AdminActor{ID: actorID, Capabilities: []string{"audience.preview", "security.revoke", "jobs.create"}, RecentMFAAt: &now, RecentMFAAction: ActionRevokeSessions}
	audience := NewAdminAudienceService(store)
	preview, err := audience.Preview(context.Background(), actor, AudiencePreviewRequest{Audience: Audience{Kind: AudienceSelected, Resource: AudienceAccounts, IDs: []uuid.UUID{actorID, otherID}}, Action: AdminAction{Kind: ActionRevokeSessions, Reason: "operator recovery"}})
	if err != nil {
		t.Fatalf("preview: %v", err)
	}
	bulk := NewAdminBulkService(store, audience, &AdminActionPorts{SessionRevoker: selfContainmentRevoker{}})
	job, err := bulk.Create(context.Background(), actor, BulkJobCreateRequest{SnapshotID: preview.SnapshotID, PayloadHash: preview.PayloadHash, Action: preview.Action, IdempotencyKey: "self-containment"})
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	if err := bulk.Process(context.Background(), actor, job.ID); err != nil {
		t.Fatalf("process: %v", err)
	}
	stored, err := store.GetJob(context.Background(), job.ID)
	if err != nil || stored.Status != JobPaused {
		t.Fatalf("stored job = %#v, %v; want paused", stored, err)
	}
}

func TestBulkRetryRequiresExplicitCommandForFailedItems(t *testing.T) {
	store := NewMemoryAdminStore()
	actorID, account := uuid.New(), uuid.New()
	email := "alice@example.com"
	store.Users = append(store.Users, AdminUser{ID: account, Username: "alice", Email: &email, EmailVerified: true})
	actor := AdminActor{ID: actorID, Capabilities: []string{"audience.preview", "campaign.email", "jobs.create", "jobs.control"}}
	audience := NewAdminAudienceService(store)
	preview, err := audience.Preview(context.Background(), actor, AudiencePreviewRequest{Audience: Audience{Kind: AudienceSelected, Resource: AudienceAccounts, IDs: []uuid.UUID{account}}, Action: AdminAction{Kind: ActionEmail, Subject: "A", Body: "B"}})
	if err != nil {
		t.Fatalf("preview: %v", err)
	}
	sender := &flakyEmailSender{}
	bulk := NewAdminBulkService(store, audience, &AdminActionPorts{Email: sender})
	job, err := bulk.Create(context.Background(), actor, BulkJobCreateRequest{SnapshotID: preview.SnapshotID, PayloadHash: preview.PayloadHash, Action: preview.Action, IdempotencyKey: "retry-explicit"})
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	itemID := store.JobItems[job.ID][0].ID
	if _, err := bulk.ProcessItem(context.Background(), actor, job.ID, itemID); err == nil {
		t.Fatal("failed delivery unexpectedly returned success")
	}
	if _, err := bulk.ProcessItem(context.Background(), actor, job.ID, itemID); err != nil {
		t.Fatalf("failed item was not returned idempotently: %v", err)
	}
	if sender.calls != 1 {
		t.Fatalf("failed item replay sent %d times, want 1", sender.calls)
	}
	if _, err := bulk.Retry(context.Background(), actor, AdminJobCommand{JobID: job.ID, IdempotencyKey: "retry-command"}); err != nil {
		t.Fatalf("retry command: %v", err)
	}
	if _, err := bulk.ProcessItem(context.Background(), actor, job.ID, itemID); err != nil {
		t.Fatalf("retry process: %v", err)
	}
	if sender.calls != 2 {
		t.Fatalf("explicit retry sent %d times, want 2", sender.calls)
	}
}

func TestBulkCancelSkipsUnclaimedItemsAndIsIdempotent(t *testing.T) {
	store := NewMemoryAdminStore()
	actorID := uuid.New()
	firstID, secondID := uuid.New(), uuid.New()
	email := "alice@example.com"
	store.Users = append(store.Users,
		AdminUser{ID: firstID, Username: "first", Email: &email, EmailVerified: true},
		AdminUser{ID: secondID, Username: "second", Email: &email, EmailVerified: true},
	)
	actor := AdminActor{ID: actorID, Capabilities: []string{"audience.preview", "campaign.email", "jobs.create", "jobs.control"}}
	audience := NewAdminAudienceService(store)
	preview, err := audience.Preview(context.Background(), actor, AudiencePreviewRequest{Audience: Audience{Kind: AudienceSelected, Resource: AudienceAccounts, IDs: []uuid.UUID{firstID, secondID}}, Action: AdminAction{Kind: ActionEmail, Subject: "A", Body: "B"}})
	if err != nil {
		t.Fatalf("preview: %v", err)
	}
	bulk := NewAdminBulkService(store, audience, &AdminActionPorts{Email: &countingEmailSender{}})
	job, err := bulk.Create(context.Background(), actor, BulkJobCreateRequest{SnapshotID: preview.SnapshotID, PayloadHash: preview.PayloadHash, Action: preview.Action, IdempotencyKey: "cancel-job"})
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	cancel, err := bulk.Cancel(context.Background(), actor, AdminJobCommand{JobID: job.ID, IdempotencyKey: "cancel-command"})
	if err != nil || cancel.Status != JobCancelled {
		t.Fatalf("cancel = %#v, %v", cancel, err)
	}
	replay, err := bulk.Cancel(context.Background(), actor, AdminJobCommand{JobID: job.ID, IdempotencyKey: "cancel-command"})
	if err != nil || replay.Status != JobCancelled {
		t.Fatalf("cancel replay = %#v, %v", replay, err)
	}
	for _, item := range store.JobItems[job.ID] {
		if item.Outcome != OutcomeSkipped || item.Reason != "cancelled" {
			t.Fatalf("unclaimed item after cancel = %#v", item)
		}
	}
}

type flakyEmailSender struct{ calls int }

func (s *flakyEmailSender) SendCampaignEmail(context.Context, uuid.UUID, uuid.UUID, AdminAction) (ActionResult, error) {
	s.calls++
	if s.calls == 1 {
		return ActionResult{}, errors.New("transient provider failure")
	}
	return ActionResult{Outcome: OutcomeProviderAccepted}, nil
}

type selfContainmentRevoker struct{}

func (selfContainmentRevoker) RevokeSessions(context.Context, uuid.UUID, uuid.UUID, string) error {
	return nil
}

type alwaysIneligibleChecker struct{}

func (alwaysIneligibleChecker) CheckRecipient(context.Context, uuid.UUID, AdminAction) (RecipientEligibility, error) {
	return RecipientEligibility{Reason: "preference_changed"}, nil
}

type countingEmailSender struct{ calls int }

func (s *countingEmailSender) SendCampaignEmail(context.Context, uuid.UUID, uuid.UUID, AdminAction) (ActionResult, error) {
	s.calls++
	return ActionResult{Outcome: OutcomeProviderAccepted}, nil
}
