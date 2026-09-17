package service

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"
)

func TestWhitespaceOnlyFilterBecomesActionBoundAllAudience(t *testing.T) {
	store := NewMemoryAdminStore()
	email := "alice@example.com"
	store.Users = append(store.Users, AdminUser{ID: uuid.New(), Username: "alice", Email: &email, EmailVerified: true})
	action := AdminAction{Kind: ActionEmail, Subject: "Notice", Body: "Hello"}
	filterValue := "  \t\n  "
	request := AudiencePreviewRequest{
		Audience: Audience{Kind: AudienceFilterKind, Resource: AudienceAccounts, Filter: &AudienceFilter{Resource: AudienceAccounts, Username: &filterValue}},
		Action:   action,
	}
	actor := AdminActor{ID: uuid.New(), Capabilities: []string{"audience.preview", "campaign.email"}}
	svc := NewAdminAudienceService(store)
	if _, err := svc.Preview(context.Background(), actor, request); !errors.Is(err, ErrRecentMFARequired) {
		t.Fatalf("whitespace-only filter error = %v, want action-bound mfa", err)
	}
	now := time.Now().UTC()
	actor.RecentMFAAt = &now
	actor.RecentMFAAction = ActionEmail
	preview, err := svc.Preview(context.Background(), actor, request)
	if err != nil {
		t.Fatalf("all-equivalent filter preview: %v", err)
	}
	if preview.AccountCount != 1 {
		t.Fatalf("account count = %d, want 1", preview.AccountCount)
	}
	snapshot, err := store.GetAudienceSnapshot(context.Background(), preview.SnapshotID)
	if err != nil {
		t.Fatalf("snapshot: %v", err)
	}
	if snapshot.Audience.Kind != AudienceAll || snapshot.Audience.Filter != nil {
		t.Fatalf("normalized audience = %#v, want all", snapshot.Audience)
	}
	if err := (Audience{Kind: AudienceFilterKind, Resource: AudienceAccounts, Filter: &AudienceFilter{Resource: AudienceAccounts}}).Validate(); !errors.Is(err, ErrInvalidAudience) {
		t.Fatalf("raw empty filter validation = %v, want invalid", err)
	}
	if _, err := svc.Preview(context.Background(), actor, AudiencePreviewRequest{Audience: Audience{Kind: AudienceFilterKind, Resource: AudienceAccounts, Filter: &AudienceFilter{Resource: AudienceReports}}, Action: action}); !errors.Is(err, ErrInvalidAudience) {
		t.Fatalf("mismatched empty filter preview = %v, want invalid", err)
	}
}

type boundedAudienceProbe struct {
	*MemoryAdminStore
	count     int64
	listCalls int
	queued    bool
}

func (p *boundedAudienceProbe) CountAudience(context.Context, Audience) (int64, error) {
	return p.count, nil
}

func (p *boundedAudienceProbe) ListAudienceMembers(context.Context, Audience, int64, int) ([]AudienceMember, error) {
	p.listCalls++
	return nil, nil
}

func (p *boundedAudienceProbe) QueueAudienceMaterialization(_ context.Context, snapshot AudienceSnapshot) (uuid.UUID, error) {
	p.queued = true
	return uuid.New(), nil
}

func TestLargeAudienceUsesCountAndAsyncMaterializationWithoutPaging(t *testing.T) {
	probe := &boundedAudienceProbe{MemoryAdminStore: NewMemoryAdminStore(), count: 3}
	svc := NewAdminAudienceService(probe)
	svc.SetMaterializeLimit(2)
	now := time.Now().UTC()
	actor := AdminActor{ID: uuid.New(), Capabilities: []string{"audience.preview", "campaign.email"}, RecentMFAAt: &now, RecentMFAAction: ActionEmail}
	preview, err := svc.Preview(context.Background(), actor, AudiencePreviewRequest{Audience: Audience{Kind: AudienceAll, Resource: AudienceAccounts}, Action: AdminAction{Kind: ActionEmail, Subject: "A", Body: "B"}})
	if err != nil {
		t.Fatalf("preview: %v", err)
	}
	if preview.Status != AudienceSnapshotPending || !probe.queued || probe.listCalls != 0 {
		t.Fatalf("large preview = %#v, queued=%v list calls=%d", preview, probe.queued, probe.listCalls)
	}
}

type reloadActorSequence struct {
	actors []AdminActor
	called int
}

func (r *reloadActorSequence) ReloadAdminActor(_ context.Context, _ uuid.UUID) (AdminActor, error) {
	if len(r.actors) == 0 {
		return AdminActor{}, errors.New("no actor")
	}
	index := r.called
	if index >= len(r.actors) {
		index = len(r.actors) - 1
	}
	r.called++
	return r.actors[index], nil
}

type recordingBulkEmailSender struct {
	targets []uuid.UUID
}

func (s *recordingBulkEmailSender) SendCampaignEmail(_ context.Context, targetID, _ uuid.UUID, _ AdminAction) (ActionResult, error) {
	s.targets = append(s.targets, targetID)
	return ActionResult{Outcome: OutcomeProviderAccepted}, nil
}

func TestBulkProcessingReloadsActorBeforeEveryItemAndPausesOnDemotion(t *testing.T) {
	store := NewMemoryAdminStore()
	email := "alice@example.com"
	first, second := uuid.New(), uuid.New()
	store.Users = append(store.Users,
		AdminUser{ID: first, Username: "one", Email: &email, EmailVerified: true},
		AdminUser{ID: second, Username: "two", Email: &email, EmailVerified: true},
	)
	actorID := uuid.New()
	actor := AdminActor{ID: actorID, State: "authenticated", Capabilities: []string{"audience.preview", "campaign.email", "jobs.create", "jobs.execute_all"}}
	audience := NewAdminAudienceService(store)
	preview, err := audience.Preview(context.Background(), actor, AudiencePreviewRequest{Audience: Audience{Kind: AudienceSelected, Resource: AudienceAccounts, IDs: []uuid.UUID{first, second}}, Action: AdminAction{Kind: ActionEmail, Subject: "A", Body: "B"}})
	if err != nil {
		t.Fatalf("preview: %v", err)
	}
	job, err := NewAdminBulkService(store, audience, &AdminActionPorts{Email: &recordingBulkEmailSender{}}).Create(context.Background(), actor, AdminJobCreateRequest{SnapshotID: preview.SnapshotID, PayloadHash: preview.PayloadHash, Action: preview.Action, IdempotencyKey: "reload-job"})
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	sender := &recordingBulkEmailSender{}
	bulk := NewAdminBulkService(store, audience, &AdminActionPorts{Email: sender})
	bulk.SetActorReloader(&reloadActorSequence{actors: []AdminActor{
		actor,
		actor,
		{ID: actorID, State: "authenticated", Capabilities: []string{"audience.preview", "jobs.create"}},
	}})
	if err := bulk.Process(context.Background(), actor, job.ID); !errors.Is(err, ErrAudienceForbidden) {
		t.Fatalf("process demotion error = %v, want forbidden", err)
	}
	if len(sender.targets) != 1 {
		t.Fatalf("sent targets = %d, want first item only", len(sender.targets))
	}
	stored, err := store.GetJob(context.Background(), job.ID)
	if err != nil {
		t.Fatalf("job: %v", err)
	}
	if stored.Status != JobPaused {
		t.Fatalf("job status = %q, want paused", stored.Status)
	}
}

type idempotentLoginLinkSender struct {
	keys   []uuid.UUID
	calls  int
	first  ActionResult
	second ActionResult
}

func (s *idempotentLoginLinkSender) SendCampaignLoginLinkWithKey(_ context.Context, _ uuid.UUID, _ uuid.UUID, operationID uuid.UUID) (ActionResult, error) {
	s.calls++
	s.keys = append(s.keys, operationID)
	if s.calls == 1 {
		return s.first, nil
	}
	return s.second, nil
}

func TestCredentialItemUnknownOutcomeIsDurableAndNeverRetried(t *testing.T) {
	store, audience, actor, job := makeCredentialJob(t, ActionLoginLink)
	sender := &idempotentLoginLinkSender{first: ActionResult{Outcome: OutcomeUnknownDelivery, ErrorCode: "provider_timeout"}, second: ActionResult{Outcome: OutcomeProviderAccepted}}
	bulk := NewAdminBulkService(store, audience, &AdminActionPorts{LoginLinkIdempotent: sender})
	item := store.JobItems[job.ID][0]
	got, err := bulk.ProcessItem(context.Background(), actor, job.ID, item.ID)
	if err != nil {
		t.Fatalf("first process: %v", err)
	}
	if got.Outcome != OutcomeUnknownDelivery || !got.Ambiguous || got.Retryable {
		t.Fatalf("unknown item = %#v", got)
	}
	if _, err := bulk.Retry(context.Background(), AdminActor{ID: actor.ID, Capabilities: []string{"jobs.control"}}, AdminJobCommand{JobID: job.ID, IdempotencyKey: "retry-unknown"}); !errors.Is(err, ErrJobConflict) {
		t.Fatalf("retry unknown error = %v, want conflict", err)
	}
	if _, err := bulk.ProcessItem(context.Background(), actor, job.ID, item.ID); err != nil {
		t.Fatalf("replayed unknown item: %v", err)
	}
	if sender.calls != 1 {
		t.Fatalf("credential sender calls = %d, want 1", sender.calls)
	}
}

func TestCredentialItemSafeFailureRetriesWithSameOperationID(t *testing.T) {
	store, audience, actor, job := makeCredentialJob(t, ActionLoginLink)
	sender := &idempotentLoginLinkSender{first: ActionResult{Outcome: OutcomeFailed, ErrorCode: "rate_limited", SafeToRetry: true}, second: ActionResult{Outcome: OutcomeProviderAccepted}}
	bulk := NewAdminBulkService(store, audience, &AdminActionPorts{LoginLinkIdempotent: sender})
	item := store.JobItems[job.ID][0]
	failed, err := bulk.ProcessItem(context.Background(), actor, job.ID, item.ID)
	if err != nil || failed.Outcome != OutcomeFailed || !failed.Retryable || failed.Ambiguous {
		t.Fatalf("safe failure = %#v, %v", failed, err)
	}
	if _, err := bulk.Retry(context.Background(), AdminActor{ID: actor.ID, Capabilities: []string{"jobs.control"}}, AdminJobCommand{JobID: job.ID, IdempotencyKey: "retry-safe"}); err != nil {
		t.Fatalf("retry safe failure: %v", err)
	}
	succeeded, err := bulk.ProcessItem(context.Background(), actor, job.ID, item.ID)
	if err != nil || succeeded.Outcome != OutcomeProviderAccepted {
		t.Fatalf("second process = %#v, %v", succeeded, err)
	}
	if sender.calls != 2 || len(sender.keys) != 2 || sender.keys[0] != sender.keys[1] || sender.keys[0] == uuid.Nil {
		t.Fatalf("operation keys = %#v, calls=%d", sender.keys, sender.calls)
	}
}

func TestBulkItemOutcomeAppendsActorTargetAudit(t *testing.T) {
	store, audience, actor, job := makeCredentialJob(t, ActionLoginLink)
	sender := &idempotentLoginLinkSender{first: ActionResult{Outcome: OutcomeProviderAccepted}}
	bulk := NewAdminBulkService(store, audience, &AdminActionPorts{LoginLinkIdempotent: sender})
	item := store.JobItems[job.ID][0]
	if _, err := bulk.ProcessItem(context.Background(), actor, job.ID, item.ID); err != nil {
		t.Fatalf("process: %v", err)
	}
	if len(store.Audit) != 1 {
		t.Fatalf("audit events = %d, want one", len(store.Audit))
	}
	event := store.Audit[0]
	if event.ActorID == nil || *event.ActorID != actor.ID || event.TargetID == nil || *event.TargetID != item.TargetID || event.Outcome != OutcomeProviderAccepted || event.Action != ActionLoginLink {
		t.Fatalf("audit event = %#v", event)
	}
	if event.Details["operation_id"] != item.OperationID.String() {
		t.Fatalf("audit operation id = %q, want %q", event.Details["operation_id"], item.OperationID)
	}
}

func TestBulkCancelAuditsEverySkippedItem(t *testing.T) {
	store := NewMemoryAdminStore()
	email := "alice@example.com"
	first, second := uuid.New(), uuid.New()
	store.Users = append(store.Users,
		AdminUser{ID: first, Username: "one", Email: &email, EmailVerified: true},
		AdminUser{ID: second, Username: "two", Email: &email, EmailVerified: true},
	)
	actor := AdminActor{ID: uuid.New(), State: "authenticated", Capabilities: []string{"audience.preview", "campaign.email", "jobs.create", "jobs.control"}}
	audience := NewAdminAudienceService(store)
	preview, err := audience.Preview(context.Background(), actor, AudiencePreviewRequest{Audience: Audience{Kind: AudienceSelected, Resource: AudienceAccounts, IDs: []uuid.UUID{first, second}}, Action: AdminAction{Kind: ActionEmail, Subject: "A", Body: "B"}})
	if err != nil {
		t.Fatalf("preview: %v", err)
	}
	bulk := NewAdminBulkService(store, audience, nil)
	job, err := bulk.Create(context.Background(), actor, AdminJobCreateRequest{SnapshotID: preview.SnapshotID, PayloadHash: preview.PayloadHash, Action: preview.Action, IdempotencyKey: "audit-cancel"})
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	if _, err := bulk.Cancel(context.Background(), actor, AdminJobCommand{JobID: job.ID, IdempotencyKey: "audit-cancel-command"}); err != nil {
		t.Fatalf("cancel: %v", err)
	}
	if len(store.Audit) != 2 {
		t.Fatalf("cancel audit count = %d, want two", len(store.Audit))
	}
	for _, event := range store.Audit {
		if event.ActorID == nil || *event.ActorID != actor.ID || event.TargetID == nil || event.Outcome != OutcomeSkipped {
			t.Fatalf("cancel audit event = %#v", event)
		}
	}
}

func TestFencedJobItemRejectsStaleWorkerFinish(t *testing.T) {
	store, _, _, job := makeCredentialJob(t, ActionLoginLink)
	itemID := store.JobItems[job.ID][0].ID
	first, firstLease, ok, err := store.ClaimJobItemWithLease(context.Background(), job.ID, itemID, "worker-one", time.Minute)
	if err != nil || !ok || firstLease == nil {
		t.Fatalf("first claim = %#v %#v %v", first, firstLease, err)
	}
	// Simulate lease expiry before a second worker fences the first one.
	store.JobItems[job.ID][0].leaseExpiresAt = time.Now().UTC().Add(-time.Second)
	second, secondLease, ok, err := store.ClaimJobItemWithLease(context.Background(), job.ID, itemID, "worker-two", time.Minute)
	if err != nil || !ok || secondLease == nil || secondLease.Fence <= firstLease.Fence {
		t.Fatalf("second claim = %#v %#v %v", second, secondLease, err)
	}
	if _, err := store.FinishJobItemWithLease(context.Background(), itemID, *firstLease, first.OperationID, OutcomeProviderAccepted, "", "", "", false, false); !errors.Is(err, ErrJobConflict) {
		t.Fatalf("stale finish error = %v, want conflict", err)
	}
	if _, err := store.FinishJobItemWithLease(context.Background(), itemID, *secondLease, second.OperationID, OutcomeProviderAccepted, "", "", "", false, false); err != nil {
		t.Fatalf("current finish: %v", err)
	}
}

func makeCredentialJob(t *testing.T, kind string) (*MemoryAdminStore, *AdminAudienceService, AdminActor, *AdminJob) {
	t.Helper()
	store := NewMemoryAdminStore()
	email := "alice@example.com"
	target := uuid.New()
	store.Users = append(store.Users, AdminUser{ID: target, Username: "alice", Email: &email, EmailVerified: true})
	actor := AdminActor{ID: uuid.New(), State: "authenticated", Capabilities: []string{"audience.preview", "campaign.login_link", "campaign.email", "jobs.create", "jobs.control"}}
	audience := NewAdminAudienceService(store)
	preview, err := audience.Preview(context.Background(), actor, AudiencePreviewRequest{Audience: Audience{Kind: AudienceSelected, Resource: AudienceAccounts, IDs: []uuid.UUID{target}}, Action: AdminAction{Kind: kind, Reason: "account requested"}})
	if err != nil {
		t.Fatalf("preview: %v", err)
	}
	bulk := NewAdminBulkService(store, audience, nil)
	job, err := bulk.Create(context.Background(), actor, AdminJobCreateRequest{SnapshotID: preview.SnapshotID, PayloadHash: preview.PayloadHash, Action: preview.Action, IdempotencyKey: "credential-job-" + kind})
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	return store, audience, actor, job
}
