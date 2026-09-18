package service

import (
	"context"
	"errors"
	"sync"
	"sync/atomic"
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
	actorID   uuid.UUID
	action    AdminAction
}

func (p *boundedAudienceProbe) CountAudience(_ context.Context, actorID uuid.UUID, _ Audience, action AdminAction) (int64, error) {
	p.actorID = actorID
	p.action = action
	return p.count, nil
}

func (p *boundedAudienceProbe) ListAudienceMembers(_ context.Context, actorID uuid.UUID, _ Audience, action AdminAction, _ int64, _ int) ([]AudienceMember, error) {
	p.actorID = actorID
	p.action = action
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
	if probe.actorID != actor.ID || probe.action.Kind != ActionEmail {
		t.Fatalf("audience handoff = actor %s action %#v, want actor/action context", probe.actorID, probe.action)
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
	bulk := NewAdminBulkService(store, audience, &AdminActionPorts{Email: sender, Eligibility: readyEligibilityChecker{}})
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

func TestBulkReloadUsesDurableMFAProofWhenMembershipLookupOmitsIt(t *testing.T) {
	store := NewMemoryAdminStore()
	targetID := uuid.New()
	store.Users = append(store.Users, AdminUser{ID: targetID, Username: "target"})
	now := time.Now().UTC()
	actor := AdminActor{
		ID: uuid.New(), State: "authenticated",
		Capabilities: []string{"audience.preview", "security.revoke", "jobs.create", "jobs.execute_all"},
		RecentMFAAt:  &now, RecentMFAAction: ActionRevokeSessions,
	}
	audience := NewAdminAudienceService(store)
	preview, err := audience.Preview(context.Background(), actor, AudiencePreviewRequest{
		Audience: Audience{Kind: AudienceSelected, Resource: AudienceAccounts, IDs: []uuid.UUID{targetID}},
		Action:   AdminAction{Kind: ActionRevokeSessions, Reason: "operator recovery"},
	})
	if err != nil {
		t.Fatalf("preview: %v", err)
	}
	bulk := NewAdminBulkService(store, audience, &AdminActionPorts{SessionRevoker: selfContainmentRevoker{}, Eligibility: readyEligibilityChecker{}})
	job, err := bulk.Create(context.Background(), actor, AdminJobCreateRequest{
		SnapshotID: preview.SnapshotID, PayloadHash: preview.PayloadHash, Action: preview.Action, IdempotencyKey: "reload-mfa-proof",
	})
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	// A persistence-backed reloader refreshes membership and capabilities. MFA
	// freshness is reconstructed from the durable job and is deliberately
	// absent from this reloaded actor.
	reloaded := actor
	reloaded.RecentMFAAt = nil
	reloaded.RecentMFAAction = ""
	bulk.SetActorReloader(staticAdminActorReloader{actor: reloaded})
	itemID := store.JobItems[job.ID][0].ID
	item, err := bulk.ProcessItem(context.Background(), actor, job.ID, itemID)
	if err != nil || item == nil || item.Outcome != OutcomeSecured {
		t.Fatalf("processed item = %#v, err=%v; want session MFA proof preserved", item, err)
	}
}

func TestBulkExecutionRequiresRecipientEligibilityChecker(t *testing.T) {
	store := NewMemoryAdminStore()
	targetID := uuid.New()
	email := "recipient@example.com"
	store.Users = append(store.Users, AdminUser{ID: targetID, Username: "recipient", Email: &email, EmailVerified: true})
	actor := AdminActor{ID: uuid.New(), State: "authenticated", Capabilities: []string{"audience.preview", "campaign.email", "jobs.create", "jobs.execute_all"}}
	audience := NewAdminAudienceService(store)
	preview, err := audience.Preview(context.Background(), actor, AudiencePreviewRequest{
		Audience: Audience{Kind: AudienceSelected, Resource: AudienceAccounts, IDs: []uuid.UUID{targetID}},
		Action:   AdminAction{Kind: ActionEmail, Subject: "A", Body: "B"},
	})
	if err != nil {
		t.Fatalf("preview: %v", err)
	}
	sender := &countingEmailSender{}
	bulk := NewAdminBulkService(store, audience, &AdminActionPorts{Email: sender})
	bulk.SetActorReloader(staticAdminActorReloader{actor: actor})
	job, err := bulk.Create(context.Background(), actor, AdminJobCreateRequest{SnapshotID: preview.SnapshotID, PayloadHash: preview.PayloadHash, Action: preview.Action, IdempotencyKey: "missing-eligibility"})
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	item, err := bulk.ProcessItem(context.Background(), actor, job.ID, store.JobItems[job.ID][0].ID)
	if !errors.Is(err, ErrAdminRepositoryAbsent) || item != nil {
		t.Fatalf("missing eligibility result = %#v, %v; want fail closed", item, err)
	}
	if sender.calls != 0 {
		t.Fatalf("sender calls without eligibility checker = %d, want zero", sender.calls)
	}
}

func TestAdminTestMessageRequiresRecipientEligibilityChecker(t *testing.T) {
	actor := AdminActor{ID: uuid.New(), State: "authenticated", Capabilities: []string{"messages.test"}}
	sender := &countingTestMessageSender{}
	bulk := NewAdminBulkService(nil, nil, &AdminActionPorts{Test: sender})
	result, err := bulk.SendTestMessage(context.Background(), actor, uuid.New(), AdminAction{Kind: ActionEmail, Subject: "A", Body: "B"})
	if !errors.Is(err, ErrAdminRepositoryAbsent) || result != nil {
		t.Fatalf("missing direct-send eligibility result = %#v, %v; want fail closed", result, err)
	}
	if sender.calls != 0 {
		t.Fatalf("direct test sender calls without eligibility = %d, want zero", sender.calls)
	}
}

type countingTestMessageSender struct{ calls int }

func (s *countingTestMessageSender) SendTestMessage(context.Context, uuid.UUID, uuid.UUID, AdminAction) (ActionResult, error) {
	s.calls++
	return ActionResult{Outcome: OutcomeProviderAccepted}, nil
}

type incompleteEligibilityChecker struct{}

func (incompleteEligibilityChecker) CheckRecipient(context.Context, uuid.UUID, AdminAction) (RecipientEligibility, error) {
	return RecipientEligibility{Eligible: true}, nil
}

func TestBulkExecutionRejectsIncompleteRecipientEligibility(t *testing.T) {
	store := NewMemoryAdminStore()
	targetID := uuid.New()
	email := "recipient@example.com"
	store.Users = append(store.Users, AdminUser{ID: targetID, Username: "recipient", Email: &email, EmailVerified: true})
	actor := AdminActor{ID: uuid.New(), State: "authenticated", Capabilities: []string{"audience.preview", "campaign.email", "jobs.create", "jobs.execute_all"}}
	audience := NewAdminAudienceService(store)
	preview, err := audience.Preview(context.Background(), actor, AudiencePreviewRequest{
		Audience: Audience{Kind: AudienceSelected, Resource: AudienceAccounts, IDs: []uuid.UUID{targetID}},
		Action:   AdminAction{Kind: ActionEmail, Subject: "A", Body: "B"},
	})
	if err != nil {
		t.Fatalf("preview: %v", err)
	}
	sender := &countingEmailSender{}
	bulk := NewAdminBulkService(store, audience, &AdminActionPorts{Email: sender, Eligibility: incompleteEligibilityChecker{}})
	bulk.SetActorReloader(staticAdminActorReloader{actor: actor})
	job, err := bulk.Create(context.Background(), actor, AdminJobCreateRequest{SnapshotID: preview.SnapshotID, PayloadHash: preview.PayloadHash, Action: preview.Action, IdempotencyKey: "incomplete-eligibility"})
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	item, err := bulk.ProcessItem(context.Background(), actor, job.ID, store.JobItems[job.ID][0].ID)
	if err != nil || item == nil || item.Outcome != OutcomeSkipped || item.Reason != "recipient_eligibility_incomplete" {
		t.Fatalf("incomplete eligibility result = %#v, %v; want skipped", item, err)
	}
	if sender.calls != 0 {
		t.Fatalf("sender calls with incomplete eligibility = %d, want zero", sender.calls)
	}
}

type readyEligibilityChecker struct{}

func (readyEligibilityChecker) CheckRecipient(context.Context, uuid.UUID, AdminAction) (RecipientEligibility, error) {
	return RecipientEligibility{Eligible: true, Complete: true}, nil
}

type promotedEligibilityChecker struct{}

func (promotedEligibilityChecker) CheckRecipient(context.Context, uuid.UUID, AdminAction) (RecipientEligibility, error) {
	return RecipientEligibility{Eligible: true, IsAdmin: true, Complete: true}, nil
}

func TestBulkExecutionRechecksSnapshotAdminAcknowledgementAfterPromotion(t *testing.T) {
	store := NewMemoryAdminStore()
	targetID := uuid.New()
	email := "recipient@example.com"
	store.Users = append(store.Users, AdminUser{ID: targetID, Username: "recipient", Email: &email, EmailVerified: true})
	actor := AdminActor{ID: uuid.New(), State: "authenticated", Capabilities: []string{"audience.preview", "campaign.email", "jobs.create", "jobs.execute_all", "audience.include_admins"}}
	audience := NewAdminAudienceService(store)
	preview, err := audience.Preview(context.Background(), actor, AudiencePreviewRequest{
		Audience: Audience{Kind: AudienceSelected, Resource: AudienceAccounts, IDs: []uuid.UUID{targetID}},
		Action:   AdminAction{Kind: ActionEmail, Subject: "A", Body: "B"},
	})
	if err != nil {
		t.Fatalf("preview: %v", err)
	}
	sender := &countingEmailSender{}
	bulk := NewAdminBulkService(store, audience, &AdminActionPorts{Email: sender, Eligibility: promotedEligibilityChecker{}})
	bulk.SetActorReloader(staticAdminActorReloader{actor: actor})
	job, err := bulk.Create(context.Background(), actor, AdminJobCreateRequest{SnapshotID: preview.SnapshotID, PayloadHash: preview.PayloadHash, Action: preview.Action, IdempotencyKey: "promoted-after-preview"})
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	store.Users[0].IsAdmin = true
	item, err := bulk.ProcessItem(context.Background(), actor, job.ID, store.JobItems[job.ID][0].ID)
	if err != nil || item == nil || item.Outcome != OutcomeSkipped || item.Reason != "admin_target_requires_ack" {
		t.Fatalf("promoted target result = %#v, %v; want snapshot acknowledgement skip", item, err)
	}
	if sender.calls != 0 {
		t.Fatalf("promoted target sender calls = %d, want zero", sender.calls)
	}
}

type blockingEmailSender struct {
	started chan struct{}
	release chan struct{}
	once    sync.Once
	calls   atomic.Int32
}

func (s *blockingEmailSender) SendCampaignEmail(context.Context, uuid.UUID, uuid.UUID, AdminAction) (ActionResult, error) {
	s.calls.Add(1)
	s.once.Do(func() { close(s.started) })
	<-s.release
	return ActionResult{Outcome: OutcomeProviderAccepted}, nil
}

func TestBulkLeaseRenewalPreventsReclaimDuringLongAction(t *testing.T) {
	store := NewMemoryAdminStore()
	targetID := uuid.New()
	email := "recipient@example.com"
	store.Users = append(store.Users, AdminUser{ID: targetID, Username: "recipient", Email: &email, EmailVerified: true})
	actor := AdminActor{ID: uuid.New(), State: "authenticated", Capabilities: []string{"audience.preview", "campaign.email", "jobs.create", "jobs.execute_all"}}
	audience := NewAdminAudienceService(store)
	preview, err := audience.Preview(context.Background(), actor, AudiencePreviewRequest{
		Audience: Audience{Kind: AudienceSelected, Resource: AudienceAccounts, IDs: []uuid.UUID{targetID}},
		Action:   AdminAction{Kind: ActionEmail, Subject: "A", Body: "B"},
	})
	if err != nil {
		t.Fatalf("preview: %v", err)
	}
	job, err := NewAdminBulkService(store, audience, &AdminActionPorts{Eligibility: readyEligibilityChecker{}}).Create(context.Background(), actor, AdminJobCreateRequest{SnapshotID: preview.SnapshotID, PayloadHash: preview.PayloadHash, Action: preview.Action, IdempotencyKey: "long-action-lease"})
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	firstSender := &blockingEmailSender{started: make(chan struct{}), release: make(chan struct{})}
	first := NewAdminBulkService(store, audience, &AdminActionPorts{Email: firstSender, Eligibility: readyEligibilityChecker{}})
	first.SetActorReloader(staticAdminActorReloader{actor: actor})
	first.SetWorkerID("worker-one")
	first.SetLeaseTTL(25 * time.Millisecond)
	firstErr := make(chan error, 1)
	go func() {
		_, processErr := first.ProcessItem(context.Background(), actor, job.ID, store.JobItems[job.ID][0].ID)
		firstErr <- processErr
	}()
	select {
	case <-firstSender.started:
	case <-time.After(time.Second):
		t.Fatal("first action did not start")
	}
	time.Sleep(80 * time.Millisecond)
	secondSender := &countingEmailSender{}
	second := NewAdminBulkService(store, audience, &AdminActionPorts{Email: secondSender, Eligibility: readyEligibilityChecker{}})
	second.SetActorReloader(staticAdminActorReloader{actor: actor})
	second.SetWorkerID("worker-two")
	second.SetLeaseTTL(25 * time.Millisecond)
	secondItem, secondErr := second.ProcessItem(context.Background(), actor, job.ID, store.JobItems[job.ID][0].ID)
	if secondErr != nil || secondItem == nil {
		t.Fatalf("second worker result = %#v, %v; want current lease retained", secondItem, secondErr)
	}
	if secondSender.calls != 0 {
		t.Fatalf("second worker calls = %d, want zero while first action is running", secondSender.calls)
	}
	close(firstSender.release)
	select {
	case processErr := <-firstErr:
		if processErr != nil {
			t.Fatalf("first worker: %v", processErr)
		}
	case <-time.After(time.Second):
		t.Fatal("first worker did not finish")
	}
}

// renewalLostMemoryStore models the durable adapter reporting that the lease
// could not be renewed after the provider call had already started. The
// terminal path is intentionally exposed by the adapter so the service must
// use it instead of the ordinary expiry-sensitive finish CAS.
type renewalLostMemoryStore struct {
	*MemoryAdminStore
	renewalCalls atomic.Int32
}

func (s *renewalLostMemoryStore) RenewJobItemLease(context.Context, uuid.UUID, AdminJobLease, time.Duration) (*AdminJobLease, error) {
	s.renewalCalls.Add(1)
	return nil, ErrJobLeaseLost
}

type delayedRenewalMemoryStore struct {
	*MemoryAdminStore
	renewalStarted   chan struct{}
	renewalRelease   chan struct{}
	renewalStartOnce sync.Once
}

func (s *delayedRenewalMemoryStore) RenewJobItemLease(context.Context, uuid.UUID, AdminJobLease, time.Duration) (*AdminJobLease, error) {
	s.renewalStartOnce.Do(func() { close(s.renewalStarted) })
	<-s.renewalRelease
	return nil, ErrJobLeaseLost
}

func (s *delayedRenewalMemoryStore) CommitUnknownDeliveryAfterLeaseLoss(ctx context.Context, itemID uuid.UUID, lease AdminJobLease, operationID uuid.UUID, audit AdminJobItemAudit) (*AdminJobItem, error) {
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	return s.MemoryAdminStore.CommitUnknownDeliveryAfterLeaseLoss(ctx, itemID, lease, operationID, audit)
}

type blockedRenewalMemoryStore struct {
	*MemoryAdminStore
	renewalStarted   chan struct{}
	renewalRelease   chan struct{}
	renewalResult    chan error
	renewalStartOnce sync.Once
}

func (s *blockedRenewalMemoryStore) RenewJobItemLease(_ context.Context, itemID uuid.UUID, lease AdminJobLease, ttl time.Duration) (*AdminJobLease, error) {
	s.renewalStartOnce.Do(func() { close(s.renewalStarted) })
	<-s.renewalRelease
	next, err := s.MemoryAdminStore.RenewJobItemLease(context.Background(), itemID, lease, ttl)
	s.renewalResult <- err
	return next, err
}

type returnAfterRenewalEmailSender struct {
	renewalStarted <-chan struct{}
	started        chan struct{}
	returned       chan struct{}
	startOnce      sync.Once
	returnOnce     sync.Once
	calls          atomic.Int32
}

func (s *returnAfterRenewalEmailSender) SendCampaignEmail(context.Context, uuid.UUID, uuid.UUID, AdminAction) (ActionResult, error) {
	s.calls.Add(1)
	s.startOnce.Do(func() { close(s.started) })
	<-s.renewalStarted
	s.returnOnce.Do(func() { close(s.returned) })
	return ActionResult{Outcome: OutcomeProviderAccepted}, nil
}

func waitForBulkItemOutcome(t *testing.T, store *MemoryAdminStore, jobID, itemID uuid.UUID, want string, timeout time.Duration) bool {
	t.Helper()
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		page, err := store.ListJobItems(context.Background(), jobID, "", maxPageLimit)
		if err == nil {
			for _, item := range page.Items {
				if item.ID == itemID && item.Outcome == want {
					return true
				}
			}
		}
		time.Sleep(time.Millisecond)
	}
	return false
}

func waitForBulkJobStatus(t *testing.T, store *MemoryAdminStore, jobID uuid.UUID, want string, timeout time.Duration) bool {
	t.Helper()
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		job, err := store.GetJob(context.Background(), jobID)
		if err == nil && job != nil && job.Status == want {
			return true
		}
		time.Sleep(time.Millisecond)
	}
	return false
}

func TestBulkProviderReturnDoesNotWaitForBlockedRenewalBeforeTerminalCommit(t *testing.T) {
	base, audience, actor, job := makeCredentialJob(t, ActionEmail)
	store := &blockedRenewalMemoryStore{
		MemoryAdminStore: base,
		renewalStarted:   make(chan struct{}),
		renewalRelease:   make(chan struct{}),
		renewalResult:    make(chan error, 1),
	}
	sender := &returnAfterRenewalEmailSender{
		renewalStarted: store.renewalStarted,
		started:        make(chan struct{}),
		returned:       make(chan struct{}),
	}
	first := NewAdminBulkService(store, audience, &AdminActionPorts{Email: sender, Eligibility: readyEligibilityChecker{}})
	first.SetActorReloader(staticAdminActorReloader{actor: actor})
	first.SetWorkerID("worker-one")
	first.SetLeaseTTL(20 * time.Millisecond)
	itemID := store.JobItems[job.ID][0].ID
	firstResult := make(chan struct {
		item *AdminJobItem
		err  error
	}, 1)
	go func() {
		item, err := first.ProcessItem(context.Background(), actor, job.ID, itemID)
		firstResult <- struct {
			item *AdminJobItem
			err  error
		}{item: item, err: err}
	}()
	var releaseOnce sync.Once
	releaseRenewal := func() { releaseOnce.Do(func() { close(store.renewalRelease) }) }
	defer releaseRenewal()
	select {
	case <-sender.started:
	case <-time.After(time.Second):
		t.Fatal("provider call did not start")
	}
	select {
	case <-store.renewalStarted:
	case <-time.After(time.Second):
		t.Fatal("lease renewal did not start")
	}
	select {
	case <-sender.returned:
	case <-time.After(time.Second):
		t.Fatal("provider did not return while renewal was blocked")
	}

	// Let the initial lease expire while the renewal adapter is still blocked.
	time.Sleep(30 * time.Millisecond)
	secondSender := &countingEmailSender{}
	second := NewAdminBulkService(store, audience, &AdminActionPorts{Email: secondSender, Eligibility: readyEligibilityChecker{}})
	second.SetActorReloader(staticAdminActorReloader{actor: actor})
	second.SetWorkerID("worker-two")
	second.SetLeaseTTL(20 * time.Millisecond)
	secondItem, secondErr := second.ProcessItem(context.Background(), actor, job.ID, itemID)
	if secondErr != nil || secondItem == nil || secondItem.Outcome != OutcomeProviderAccepted {
		t.Fatalf("second worker result = %#v, %v; want first terminal outcome", secondItem, secondErr)
	}
	if secondSender.calls != 0 {
		t.Fatalf("second worker calls = %d, want zero before first outcome", secondSender.calls)
	}
	releaseRenewal()
	select {
	case result := <-firstResult:
		if result.err != nil || result.item == nil || result.item.Outcome != OutcomeProviderAccepted {
			t.Fatalf("first worker result = %#v, %v; want provider accepted", result.item, result.err)
		}
	case <-time.After(time.Second):
		t.Fatal("first worker did not terminalize before reclaim")
	}
	select {
	case err := <-store.renewalResult:
		if !errors.Is(err, ErrJobConflict) {
			t.Fatalf("late renewal error = %v, want fenced conflict", err)
		}
	case <-time.After(time.Second):
		t.Fatal("blocked renewal did not finish")
	}
}

func TestBulkLeaseLossCommitsTerminalUnknownAndBlocksReclaim(t *testing.T) {
	base, audience, actor, job := makeCredentialJob(t, ActionEmail)
	store := &renewalLostMemoryStore{MemoryAdminStore: base}
	sender := &blockingEmailSender{started: make(chan struct{}), release: make(chan struct{})}
	first := NewAdminBulkService(store, audience, &AdminActionPorts{Email: sender, Eligibility: readyEligibilityChecker{}})
	first.SetActorReloader(staticAdminActorReloader{actor: actor})
	first.SetWorkerID("worker-one")
	first.SetLeaseTTL(20 * time.Millisecond)
	itemID := store.JobItems[job.ID][0].ID
	firstResult := make(chan struct {
		item *AdminJobItem
		err  error
	}, 1)
	go func() {
		item, err := first.ProcessItem(context.Background(), actor, job.ID, itemID)
		firstResult <- struct {
			item *AdminJobItem
			err  error
		}{item: item, err: err}
	}()
	select {
	case <-sender.started:
	case <-time.After(time.Second):
		t.Fatal("provider call did not start")
	}
	select {
	case <-func() chan struct{} {
		ready := make(chan struct{})
		go func() {
			for store.renewalCalls.Load() == 0 {
				time.Sleep(time.Millisecond)
			}
			close(ready)
		}()
		return ready
	}():
	case <-time.After(time.Second):
		t.Fatal("lease renewal was not attempted")
	}
	secondSender := &countingEmailSender{}
	second := NewAdminBulkService(store, audience, &AdminActionPorts{Email: secondSender, Eligibility: readyEligibilityChecker{}})
	second.SetActorReloader(staticAdminActorReloader{actor: actor})
	second.SetWorkerID("worker-two")
	second.SetLeaseTTL(20 * time.Millisecond)
	if !waitForBulkItemOutcome(t, store.MemoryAdminStore, job.ID, itemID, OutcomeUnknownDelivery, 100*time.Millisecond) {
		// A legacy implementation leaves the provider blocked and will only be
		// observed by the reclaim assertion below.
		time.Sleep(30 * time.Millisecond)
	}
	replayed, err := second.ProcessItem(context.Background(), actor, job.ID, itemID)
	if err != nil || replayed == nil || replayed.Outcome != OutcomeUnknownDelivery {
		t.Fatalf("reclaimed lease-loss item = %#v, %v; want terminal item before provider unblocks", replayed, err)
	}
	if secondSender.calls != 0 {
		t.Fatalf("reclaimed uncertain item sent %d times, want zero", secondSender.calls)
	}
	close(sender.release)
	var result struct {
		item *AdminJobItem
		err  error
	}
	select {
	case result = <-firstResult:
	case <-time.After(time.Second):
		t.Fatal("lease-loss worker did not finish")
	}
	if !errors.Is(result.err, ErrJobLeaseLost) || result.item == nil || result.item.Outcome != OutcomeUnknownDelivery || !result.item.Ambiguous || result.item.Retryable {
		t.Fatalf("lease-loss result = %#v, %v; want terminal uncertainty", result.item, result.err)
	}
	if len(store.Audit) != 1 || store.Audit[0].Outcome != OutcomeUnknownDelivery || store.Audit[0].Details["operation_id"] != result.item.OperationID.String() {
		t.Fatalf("lease-loss audit = %#v; want one durable unknown outcome audit", store.Audit)
	}
}

type failedUnknownCommitStore struct {
	*renewalLostMemoryStore
}

func (s *failedUnknownCommitStore) CommitUnknownDeliveryAfterLeaseLoss(context.Context, uuid.UUID, AdminJobLease, uuid.UUID, AdminJobItemAudit) (*AdminJobItem, error) {
	return nil, errors.New("terminal uncertainty commit unavailable")
}

func TestBulkLeaseLossFailsClosedWhenTerminalCommitIsUnavailable(t *testing.T) {
	base, audience, actor, job := makeCredentialJob(t, ActionEmail)
	store := &failedUnknownCommitStore{renewalLostMemoryStore: &renewalLostMemoryStore{MemoryAdminStore: base}}
	sender := &blockingEmailSender{started: make(chan struct{}), release: make(chan struct{})}
	first := NewAdminBulkService(store, audience, &AdminActionPorts{Email: sender, Eligibility: readyEligibilityChecker{}})
	first.SetActorReloader(staticAdminActorReloader{actor: actor})
	first.SetLeaseTTL(20 * time.Millisecond)
	itemID := store.JobItems[job.ID][0].ID
	resultCh := make(chan error, 1)
	go func() {
		_, err := first.ProcessItem(context.Background(), actor, job.ID, itemID)
		resultCh <- err
	}()
	select {
	case <-sender.started:
	case <-time.After(time.Second):
		t.Fatal("provider call did not start")
	}
	select {
	case <-func() chan struct{} {
		ready := make(chan struct{})
		go func() {
			for store.renewalCalls.Load() == 0 {
				time.Sleep(time.Millisecond)
			}
			close(ready)
		}()
		return ready
	}():
	case <-time.After(time.Second):
		t.Fatal("lease renewal was not attempted")
	}
	time.Sleep(30 * time.Millisecond)
	secondSender := &countingEmailSender{}
	second := NewAdminBulkService(store, audience, &AdminActionPorts{Email: secondSender, Eligibility: readyEligibilityChecker{}})
	takeover := AdminActor{ID: uuid.New(), State: "authenticated", Capabilities: []string{"campaign.email", "jobs.execute_all"}}
	now := time.Now().UTC()
	takeover.RecentMFAAt = &now
	takeover.RecentMFAAction = ActionEmail
	second.SetActorReloader(staticAdminActorReloader{actor: takeover})
	if !waitForBulkJobStatus(t, store.MemoryAdminStore, job.ID, JobPaused, 100*time.Millisecond) {
		// A legacy implementation only pauses after the blocked provider
		// returns; let the reclaim assertion exercise that unsafe window.
		time.Sleep(30 * time.Millisecond)
	}
	item := store.JobItems[job.ID][0]
	replayed, err := second.ProcessItem(context.Background(), takeover, job.ID, item.ID)
	if err != nil || replayed == nil || replayed.Outcome != OutcomeQueued {
		t.Fatalf("paused item result = %#v, %v; want unresolved queued item", replayed, err)
	}
	if secondSender.calls != 0 {
		t.Fatalf("paused uncertain item sent %d times, want zero", secondSender.calls)
	}
	close(sender.release)
	select {
	case err := <-resultCh:
		if !errors.Is(err, ErrAdminRepositoryAbsent) {
			t.Fatalf("terminal commit failure = %v, want unavailable", err)
		}
	case <-time.After(time.Second):
		t.Fatal("lease-loss worker did not finish")
	}
	paused, err := store.GetJob(context.Background(), job.ID)
	if err != nil || paused == nil || paused.Status != JobPaused {
		t.Fatalf("job after terminal commit failure = %#v, %v; want paused", paused, err)
	}
	item = store.JobItems[job.ID][0]
	if item.Outcome == OutcomeUnknownDelivery || !item.claimed {
		t.Fatalf("item after terminal commit failure = %#v; want unresolved claimed item", item)
	}
}

func TestBulkLeaseLossOnCancellationWithDelayedRenewalBlocksReclaim(t *testing.T) {
	base, audience, actor, job := makeCredentialJob(t, ActionEmail)
	store := &delayedRenewalMemoryStore{
		MemoryAdminStore: base,
		renewalStarted:   make(chan struct{}),
		renewalRelease:   make(chan struct{}),
	}
	sender := &blockingEmailSender{started: make(chan struct{}), release: make(chan struct{})}
	bulk := NewAdminBulkService(store, audience, &AdminActionPorts{Email: sender, Eligibility: readyEligibilityChecker{}})
	bulk.SetActorReloader(staticAdminActorReloader{actor: actor})
	bulk.SetLeaseTTL(20 * time.Millisecond)
	itemID := store.JobItems[job.ID][0].ID
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	resultCh := make(chan struct {
		item *AdminJobItem
		err  error
	}, 1)
	go func() {
		item, err := bulk.ProcessItem(ctx, actor, job.ID, itemID)
		resultCh <- struct {
			item *AdminJobItem
			err  error
		}{item: item, err: err}
	}()
	select {
	case <-sender.started:
	case <-time.After(time.Second):
		t.Fatal("provider call did not start")
	}
	select {
	case <-store.renewalStarted:
	case <-time.After(time.Second):
		t.Fatal("delayed lease renewal was not started")
	}
	cancel()
	var result struct {
		item *AdminJobItem
		err  error
	}
	select {
	case result = <-resultCh:
	case <-time.After(100 * time.Millisecond):
		close(sender.release)
		close(store.renewalRelease)
		t.Fatal("cancellation did not quarantine the item while renewal was delayed")
	}
	if !errors.Is(result.err, ErrJobLeaseLost) || result.item == nil || result.item.Outcome != OutcomeUnknownDelivery {
		close(sender.release)
		close(store.renewalRelease)
		t.Fatalf("cancelled lease result = %#v, %v; want terminal uncertainty", result.item, result.err)
	}
	secondSender := &countingEmailSender{}
	second := NewAdminBulkService(store, audience, &AdminActionPorts{Email: secondSender, Eligibility: readyEligibilityChecker{}})
	second.SetActorReloader(staticAdminActorReloader{actor: actor})
	second.SetLeaseTTL(20 * time.Millisecond)
	replayed, err := second.ProcessItem(context.Background(), actor, job.ID, itemID)
	if err != nil || replayed == nil || replayed.Outcome != OutcomeUnknownDelivery || secondSender.calls != 0 {
		close(sender.release)
		close(store.renewalRelease)
		t.Fatalf("replayed cancelled item = %#v, %v, sends=%d; want quarantined result", replayed, err, secondSender.calls)
	}
	close(sender.release)
	close(store.renewalRelease)
}

func TestBulkTakeoverCannotUseCreatorMFAProof(t *testing.T) {
	store := NewMemoryAdminStore()
	targetID := uuid.New()
	store.Users = append(store.Users, AdminUser{ID: targetID, Username: "target"})
	now := time.Now().UTC()
	creator := AdminActor{ID: uuid.New(), State: "authenticated", Capabilities: []string{"audience.preview", "security.revoke", "jobs.create"}, RecentMFAAt: &now, RecentMFAAction: ActionRevokeSessions}
	audience := NewAdminAudienceService(store)
	preview, err := audience.Preview(context.Background(), creator, AudiencePreviewRequest{Audience: Audience{Kind: AudienceSelected, Resource: AudienceAccounts, IDs: []uuid.UUID{targetID}}, Action: AdminAction{Kind: ActionRevokeSessions, Reason: "operator recovery"}})
	if err != nil {
		t.Fatalf("preview: %v", err)
	}
	job, err := NewAdminBulkService(store, audience, &AdminActionPorts{SessionRevoker: selfContainmentRevoker{}, Eligibility: readyEligibilityChecker{}}).Create(context.Background(), creator, AdminJobCreateRequest{SnapshotID: preview.SnapshotID, PayloadHash: preview.PayloadHash, Action: preview.Action, IdempotencyKey: "takeover-mfa"})
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	takeover := AdminActor{ID: uuid.New(), State: "authenticated", Capabilities: []string{"security.revoke", "jobs.execute_all"}}
	bulk := NewAdminBulkService(store, audience, &AdminActionPorts{SessionRevoker: selfContainmentRevoker{}, Eligibility: readyEligibilityChecker{}})
	bulk.SetActorReloader(staticAdminActorReloader{actor: takeover})
	item, err := bulk.ProcessItem(context.Background(), takeover, job.ID, store.JobItems[job.ID][0].ID)
	if !errors.Is(err, ErrRecentMFARequired) || item != nil {
		t.Fatalf("takeover without own MFA = %#v, %v; want rejected", item, err)
	}
	paused, err := store.GetJob(context.Background(), job.ID)
	if err != nil || paused == nil || paused.Status != JobPaused {
		t.Fatalf("takeover job = %#v, %v; want paused", paused, err)
	}

	takeover.RecentMFAAt = &now
	takeover.RecentMFAAction = ActionRevokeSessions
	bulk.SetActorReloader(staticAdminActorReloader{actor: takeover})
	allowedJob, err := NewAdminBulkService(store, audience, &AdminActionPorts{SessionRevoker: selfContainmentRevoker{}, Eligibility: readyEligibilityChecker{}}).Create(context.Background(), creator, AdminJobCreateRequest{SnapshotID: preview.SnapshotID, PayloadHash: preview.PayloadHash, Action: preview.Action, IdempotencyKey: "takeover-mfa-allowed"})
	if err != nil {
		t.Fatalf("create allowed takeover job: %v", err)
	}
	item, err = bulk.ProcessItem(context.Background(), takeover, allowedJob.ID, store.JobItems[allowedJob.ID][0].ID)
	if err != nil || item == nil || item.Outcome != OutcomeSecured {
		t.Fatalf("takeover with own MFA = %#v, %v; want success", item, err)
	}
}

func TestBulkTakeoverUsesOwnFreshMFAWhenCreatorProofIsExpired(t *testing.T) {
	newJob := func(t *testing.T) (*MemoryAdminStore, *AdminAudienceService, *AdminJob) {
		t.Helper()
		store := NewMemoryAdminStore()
		targetID := uuid.New()
		store.Users = append(store.Users, AdminUser{ID: targetID, Username: "target"})
		creatorNow := time.Now().UTC()
		creator := AdminActor{
			ID: uuid.New(), State: "authenticated",
			Capabilities: []string{"audience.preview", "security.revoke", "jobs.create"},
			RecentMFAAt:  &creatorNow, RecentMFAAction: ActionRevokeSessions,
		}
		audience := NewAdminAudienceService(store)
		preview, err := audience.Preview(context.Background(), creator, AudiencePreviewRequest{
			Audience: Audience{Kind: AudienceSelected, Resource: AudienceAccounts, IDs: []uuid.UUID{targetID}},
			Action:   AdminAction{Kind: ActionRevokeSessions, Reason: "operator recovery"},
		})
		if err != nil {
			t.Fatalf("preview: %v", err)
		}
		creatorService := NewAdminBulkService(store, audience, &AdminActionPorts{SessionRevoker: selfContainmentRevoker{}, Eligibility: readyEligibilityChecker{}})
		job, err := creatorService.Create(context.Background(), creator, AdminJobCreateRequest{
			SnapshotID: preview.SnapshotID, PayloadHash: preview.PayloadHash, Action: preview.Action, IdempotencyKey: uuid.NewString(),
		})
		if err != nil {
			t.Fatalf("create: %v", err)
		}
		return store, audience, job
	}

	newTakeover := func() AdminActor {
		takeoverNow := time.Now().UTC()
		return AdminActor{
			ID: uuid.New(), State: "authenticated",
			Capabilities: []string{"security.revoke", "jobs.execute_all"},
			RecentMFAAt:  &takeoverNow, RecentMFAAction: ActionRevokeSessions,
		}
	}

	t.Run("fresh takeover proof satisfies freshness after creator proof expires", func(t *testing.T) {
		store, audience, job := newJob(t)
		old := time.Now().UTC().Add(-time.Hour)
		stored := store.Jobs[job.ID]
		stored.RecentMFAAt = &old
		stored.RecentMFAAction = ActionRevokeSessions
		store.Jobs[job.ID] = stored

		takeover := newTakeover()
		bulk := NewAdminBulkService(store, audience, &AdminActionPorts{SessionRevoker: selfContainmentRevoker{}, Eligibility: readyEligibilityChecker{}})
		bulk.SetActorReloader(staticAdminActorReloader{actor: takeover})
		item, err := bulk.ProcessItem(context.Background(), takeover, job.ID, store.JobItems[job.ID][0].ID)
		if err != nil || item == nil || item.Outcome != OutcomeSecured {
			t.Fatalf("takeover with expired creator proof = %#v, %v; want secured", item, err)
		}
	})

	for _, tc := range []struct {
		name   string
		change func(*AdminJob)
	}{
		{name: "missing creator proof", change: func(job *AdminJob) {
			job.RecentMFAAt = nil
			job.RecentMFAAction = ""
		}},
		{name: "mismatched creator proof", change: func(job *AdminJob) {
			job.RecentMFAAction = ActionMarkCompromised
		}},
	} {
		t.Run(tc.name, func(t *testing.T) {
			store, audience, job := newJob(t)
			stored := store.Jobs[job.ID]
			tc.change(&stored)
			store.Jobs[job.ID] = stored

			takeover := newTakeover()
			bulk := NewAdminBulkService(store, audience, &AdminActionPorts{SessionRevoker: selfContainmentRevoker{}, Eligibility: readyEligibilityChecker{}})
			bulk.SetActorReloader(staticAdminActorReloader{actor: takeover})
			item, err := bulk.ProcessItem(context.Background(), takeover, job.ID, store.JobItems[job.ID][0].ID)
			if !errors.Is(err, ErrRecentMFARequired) || item != nil {
				t.Fatalf("takeover with %s = %#v, %v; want rejected", tc.name, item, err)
			}
		})
	}
}

func TestBulkTakeoverResumeRequiresOwnActionBoundMFA(t *testing.T) {
	store := NewMemoryAdminStore()
	targetID := uuid.New()
	email := "target@example.com"
	store.Users = append(store.Users, AdminUser{ID: targetID, Username: "target", Email: &email, EmailVerified: true})
	creator := AdminActor{ID: uuid.New(), State: "authenticated", Capabilities: []string{"audience.preview", "campaign.email", "jobs.create", "jobs.control"}}
	audience := NewAdminAudienceService(store)
	preview, err := audience.Preview(context.Background(), creator, AudiencePreviewRequest{Audience: Audience{Kind: AudienceSelected, Resource: AudienceAccounts, IDs: []uuid.UUID{targetID}}, Action: AdminAction{Kind: ActionEmail, Subject: "A", Body: "B"}})
	if err != nil {
		t.Fatalf("preview: %v", err)
	}
	sender := &countingEmailSender{}
	bulk := NewAdminBulkService(store, audience, &AdminActionPorts{Email: sender, Eligibility: readyEligibilityChecker{}})
	bulk.SetActorReloader(staticAdminActorReloader{actor: creator})
	job, err := bulk.Create(context.Background(), creator, AdminJobCreateRequest{SnapshotID: preview.SnapshotID, PayloadHash: preview.PayloadHash, Action: preview.Action, IdempotencyKey: "takeover-resume-mfa"})
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	store.JobItems[job.ID][0].Outcome = OutcomeFailed
	store.JobItems[job.ID][0].Retryable = true
	takeover := AdminActor{ID: uuid.New(), State: "authenticated", Capabilities: []string{"campaign.email", "jobs.control", "jobs.control_all"}}
	if _, err := bulk.Retry(context.Background(), takeover, AdminJobCommand{JobID: job.ID, IdempotencyKey: "takeover-resume-mfa-command"}); !errors.Is(err, ErrRecentMFARequired) {
		t.Fatalf("takeover retry without own MFA = %v; want recent MFA required", err)
	}
	if store.JobItems[job.ID][0].Outcome != OutcomeFailed {
		t.Fatalf("failed item was queued without takeover MFA: %#v", store.JobItems[job.ID][0])
	}

	now := time.Now().UTC()
	takeover.RecentMFAAt = &now
	takeover.RecentMFAAction = ActionEmail
	if _, err := bulk.Retry(context.Background(), takeover, AdminJobCommand{JobID: job.ID, IdempotencyKey: "takeover-resume-mfa-command-1"}); !errors.Is(err, ErrRecentMFARequired) {
		t.Fatalf("takeover retry with underlying action MFA = %v; want command MFA required", err)
	}

	takeover.RecentMFAAction = "jobs.control"
	if _, err := bulk.Retry(context.Background(), takeover, AdminJobCommand{JobID: job.ID, IdempotencyKey: "takeover-resume-mfa-command-2"}); err != nil {
		t.Fatalf("takeover retry with own MFA: %v", err)
	}
}

type countingPushSender struct{ calls int }

func (s *countingPushSender) SendCampaignPush(context.Context, uuid.UUID, uuid.UUID, AdminAction) (ActionResult, error) {
	s.calls++
	return ActionResult{Outcome: OutcomeProviderAccepted}, nil
}

func allAudienceMessageAction(kind string) AdminAction {
	switch kind {
	case ActionEmail:
		return AdminAction{Kind: kind, Subject: "A", Body: "B"}
	case ActionLoginLink:
		return AdminAction{Kind: kind, Reason: "account requested"}
	default:
		return AdminAction{Kind: kind, Title: "A", Body: "B"}
	}
}

func TestBulkRestartRequiresDurableMFAProofForAllAccountMessages(t *testing.T) {
	for _, kind := range []string{ActionEmail, ActionLoginLink, ActionPush} {
		t.Run(kind, func(t *testing.T) {
			store := NewMemoryAdminStore()
			targetID := uuid.New()
			email := "target@example.com"
			store.Users = append(store.Users, AdminUser{ID: targetID, Username: "target", Email: &email, EmailVerified: true, RegisteredDeviceCount: 1})
			now := time.Now().UTC()
			creator := AdminActor{ID: uuid.New(), State: "authenticated", Capabilities: []string{"audience.preview", "campaign.email", "campaign.login_link", "campaign.push", "jobs.create"}, RecentMFAAt: &now, RecentMFAAction: kind}
			audience := NewAdminAudienceService(store)
			action := allAudienceMessageAction(kind)
			preview, err := audience.Preview(context.Background(), creator, AudiencePreviewRequest{Audience: Audience{Kind: AudienceAll, Resource: AudienceAccounts}, Action: action})
			if err != nil {
				t.Fatalf("preview: %v", err)
			}
			ports := &AdminActionPorts{Eligibility: readyEligibilityChecker{}}
			switch kind {
			case ActionEmail:
				ports.Email = &countingEmailSender{}
			case ActionLoginLink:
				ports.LoginLinkIdempotent = &idempotentLoginLinkSender{first: ActionResult{Outcome: OutcomeProviderAccepted}}
			case ActionPush:
				ports.Push = &countingPushSender{}
			}
			creatorService := NewAdminBulkService(store, audience, ports)
			job, err := creatorService.Create(context.Background(), creator, AdminJobCreateRequest{SnapshotID: preview.SnapshotID, PayloadHash: preview.PayloadHash, Action: preview.Action, IdempotencyKey: "all-message-restart-" + kind})
			if err != nil {
				t.Fatalf("create: %v", err)
			}
			stored := store.Jobs[job.ID]
			stored.RecentMFAAt = nil
			stored.RecentMFAAction = ""
			store.Jobs[job.ID] = stored
			restartedActor := creator
			restartedActor.RecentMFAAt = nil
			restartedActor.RecentMFAAction = ""
			restarted := NewAdminBulkService(store, audience, ports)
			restarted.SetActorReloader(staticAdminActorReloader{actor: restartedActor})
			item, err := restarted.ProcessItem(context.Background(), restartedActor, job.ID, store.JobItems[job.ID][0].ID)
			if !errors.Is(err, ErrRecentMFARequired) || item != nil {
				t.Fatalf("missing durable all-account proof = %#v, %v; want rejected", item, err)
			}
		})
	}
}

func TestBulkRestartReconstructsDurableMFAProof(t *testing.T) {
	store := NewMemoryAdminStore()
	targetID := uuid.New()
	store.Users = append(store.Users, AdminUser{ID: targetID, Username: "target"})
	now := time.Now().UTC()
	actor := AdminActor{ID: uuid.New(), State: "authenticated", Capabilities: []string{"audience.preview", "security.revoke", "jobs.create", "jobs.execute_all"}, RecentMFAAt: &now, RecentMFAAction: ActionRevokeSessions}
	audience := NewAdminAudienceService(store)
	preview, err := audience.Preview(context.Background(), actor, AudiencePreviewRequest{
		Audience: Audience{Kind: AudienceSelected, Resource: AudienceAccounts, IDs: []uuid.UUID{targetID}},
		Action:   AdminAction{Kind: ActionRevokeSessions, Reason: "operator recovery"},
	})
	if err != nil {
		t.Fatalf("preview: %v", err)
	}
	ports := &AdminActionPorts{SessionRevoker: selfContainmentRevoker{}, Eligibility: readyEligibilityChecker{}}
	creator := NewAdminBulkService(store, audience, ports)
	job, err := creator.Create(context.Background(), actor, AdminJobCreateRequest{SnapshotID: preview.SnapshotID, PayloadHash: preview.PayloadHash, Action: preview.Action, IdempotencyKey: "restart-mfa-proof"})
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	restartedActor := actor
	restartedActor.RecentMFAAt = nil
	restartedActor.RecentMFAAction = ""
	restarted := NewAdminBulkService(store, audience, ports)
	restarted.SetActorReloader(staticAdminActorReloader{actor: restartedActor})
	item, err := restarted.ProcessItem(context.Background(), restartedActor, job.ID, store.JobItems[job.ID][0].ID)
	if err != nil || item == nil || item.Outcome != OutcomeSecured {
		t.Fatalf("restart item = %#v, err=%v; want durable MFA proof", item, err)
	}
}

func TestBulkMissingDurableMFAProofFailsClosedAfterRestart(t *testing.T) {
	store := NewMemoryAdminStore()
	targetID := uuid.New()
	store.Users = append(store.Users, AdminUser{ID: targetID, Username: "target"})
	now := time.Now().UTC()
	actor := AdminActor{ID: uuid.New(), State: "authenticated", Capabilities: []string{"audience.preview", "security.revoke", "jobs.create", "jobs.execute_all"}, RecentMFAAt: &now, RecentMFAAction: ActionRevokeSessions}
	audience := NewAdminAudienceService(store)
	preview, err := audience.Preview(context.Background(), actor, AudiencePreviewRequest{
		Audience: Audience{Kind: AudienceSelected, Resource: AudienceAccounts, IDs: []uuid.UUID{targetID}},
		Action:   AdminAction{Kind: ActionRevokeSessions, Reason: "operator recovery"},
	})
	if err != nil {
		t.Fatalf("preview: %v", err)
	}
	ports := &AdminActionPorts{SessionRevoker: selfContainmentRevoker{}, Eligibility: readyEligibilityChecker{}}
	creator := NewAdminBulkService(store, audience, ports)
	job, err := creator.Create(context.Background(), actor, AdminJobCreateRequest{SnapshotID: preview.SnapshotID, PayloadHash: preview.PayloadHash, Action: preview.Action, IdempotencyKey: "missing-restart-mfa-proof"})
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	storedJob := store.Jobs[job.ID]
	storedJob.RecentMFAAt = nil
	storedJob.RecentMFAAction = ""
	store.Jobs[job.ID] = storedJob
	restartedActor := actor
	restartedActor.RecentMFAAt = nil
	restartedActor.RecentMFAAction = ""
	restarted := NewAdminBulkService(store, audience, ports)
	restarted.SetActorReloader(staticAdminActorReloader{actor: restartedActor})
	if _, err := restarted.ProcessItem(context.Background(), restartedActor, job.ID, store.JobItems[job.ID][0].ID); !errors.Is(err, ErrRecentMFARequired) {
		t.Fatalf("missing durable proof error = %v, want recent MFA required", err)
	}
	stored, err := store.GetJob(context.Background(), job.ID)
	if err != nil || stored == nil || stored.Status != JobPaused {
		t.Fatalf("missing durable proof job = %#v, %v; want paused", stored, err)
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
	bulk := NewAdminBulkService(store, audience, &AdminActionPorts{LoginLinkIdempotent: sender, Eligibility: readyEligibilityChecker{}})
	bulk.SetActorReloader(staticAdminActorReloader{actor: actor})
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
	bulk := NewAdminBulkService(store, audience, &AdminActionPorts{LoginLinkIdempotent: sender, Eligibility: readyEligibilityChecker{}})
	bulk.SetActorReloader(staticAdminActorReloader{actor: actor})
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
	bulk := NewAdminBulkService(store, audience, &AdminActionPorts{LoginLinkIdempotent: sender, Eligibility: readyEligibilityChecker{}})
	bulk.SetActorReloader(staticAdminActorReloader{actor: actor})
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
	staleAudit := AdminJobItemAudit{JobID: job.ID, ItemID: itemID, OperationID: first.OperationID, ActorID: uuid.New(), TargetID: first.TargetID, Action: ActionLoginLink, Outcome: OutcomeProviderAccepted}
	if _, err := store.FinishJobItemWithAudit(context.Background(), itemID, *firstLease, first.OperationID, OutcomeProviderAccepted, "", "", "", false, false, staleAudit); !errors.Is(err, ErrJobConflict) {
		t.Fatalf("stale audit finish after completion error = %v, want conflict", err)
	}
}

type staticAdminActorReloader struct {
	actor AdminActor
}

func (r staticAdminActorReloader) ReloadAdminActor(_ context.Context, _ uuid.UUID) (AdminActor, error) {
	return r.actor, nil
}

type dynamicAdminActorReloader struct {
	actor *AdminActor
}

func (r dynamicAdminActorReloader) ReloadAdminActor(_ context.Context, _ uuid.UUID) (AdminActor, error) {
	if r.actor == nil {
		return AdminActor{}, errors.New("missing actor")
	}
	return *r.actor, nil
}

func TestUnknownDeliveryCompletesJobWithUncertainProgress(t *testing.T) {
	store, audience, actor, job := makeCredentialJob(t, ActionLoginLink)
	sender := &idempotentLoginLinkSender{first: ActionResult{Outcome: OutcomeUnknownDelivery, ErrorCode: "provider_timeout"}}
	bulk := NewAdminBulkService(store, audience, &AdminActionPorts{LoginLinkIdempotent: sender, Eligibility: readyEligibilityChecker{}})
	bulk.SetActorReloader(staticAdminActorReloader{actor: actor})
	if err := bulk.Process(context.Background(), actor, job.ID); err != nil {
		t.Fatalf("process unknown job: %v", err)
	}
	stored, err := store.GetJob(context.Background(), job.ID)
	if err != nil {
		t.Fatalf("get job: %v", err)
	}
	if stored.Status != JobCompletedWithError || stored.CompletedCount != 1 || stored.UncertainCount != 1 {
		t.Fatalf("unknown progress = %#v, want completed uncertainty", stored)
	}
}

type failingAtomicJobItemStore struct {
	*MemoryAdminStore
	fail bool
}

func (s *failingAtomicJobItemStore) FinishJobItemWithAudit(context.Context, uuid.UUID, AdminJobLease, uuid.UUID, string, string, string, string, bool, bool, AdminJobItemAudit) (*AdminJobItem, error) {
	if s.fail {
		return nil, errors.New("item/audit transaction unavailable")
	}
	return nil, errors.New("unexpected test path")
}

func TestBulkItemFinishAndAuditUseOneDurableCommit(t *testing.T) {
	base, audience, actor, job := makeCredentialJob(t, ActionLoginLink)
	store := &failingAtomicJobItemStore{MemoryAdminStore: base, fail: true}
	sender := &idempotentLoginLinkSender{first: ActionResult{Outcome: OutcomeProviderAccepted}}
	bulk := NewAdminBulkService(store, audience, &AdminActionPorts{LoginLinkIdempotent: sender, Eligibility: readyEligibilityChecker{}})
	bulk.SetActorReloader(staticAdminActorReloader{actor: actor})
	itemID := store.JobItems[job.ID][0].ID
	if _, err := bulk.ProcessItem(context.Background(), actor, job.ID, itemID); err == nil {
		t.Fatal("item commit unexpectedly succeeded")
	}
	item := store.JobItems[job.ID][0]
	if item.Outcome != OutcomeQueued || len(store.Audit) != 0 {
		t.Fatalf("failed item/audit commit mutated durable state: item=%#v audit=%d", item, len(store.Audit))
	}
	stored, err := store.GetJob(context.Background(), job.ID)
	if err != nil {
		t.Fatalf("get job: %v", err)
	}
	if stored.Status != JobPaused {
		t.Fatalf("job status = %q, want paused after commit failure", stored.Status)
	}
}

func TestBulkExecutionFailsClosedWithoutActorReloadAndKeyedCredentialPort(t *testing.T) {
	store, audience, actor, job := makeCredentialJob(t, ActionLoginLink)
	legacy := &legacyLoginLinkSender{}
	bulk := NewAdminBulkService(store, audience, &AdminActionPorts{LoginLink: legacy, Eligibility: readyEligibilityChecker{}})
	itemID := store.JobItems[job.ID][0].ID
	if _, err := bulk.ProcessItem(context.Background(), actor, job.ID, itemID); !errors.Is(err, ErrAdminRepositoryAbsent) {
		t.Fatalf("missing actor reloader error = %v, want repository unavailable", err)
	}
	if legacy.calls != 0 {
		t.Fatalf("legacy sender called without actor reload: %d", legacy.calls)
	}
	paused, err := store.GetJob(context.Background(), job.ID)
	if err != nil {
		t.Fatalf("get paused job: %v", err)
	}
	if paused.Status != JobPaused {
		t.Fatalf("missing reloader status = %q, want paused", paused.Status)
	}

	actor.Capabilities = append(actor.Capabilities, "jobs.execute_all")
	bulk.SetActorReloader(staticAdminActorReloader{actor: actor})
	if _, err := bulk.ProcessItem(context.Background(), actor, job.ID, itemID); !errors.Is(err, ErrActionUnavailable) {
		t.Fatalf("legacy credential port error = %v, want unavailable", err)
	}
	if legacy.calls != 0 {
		t.Fatalf("legacy sender called despite keyed-port requirement: %d", legacy.calls)
	}
}

type legacyLoginLinkSender struct{ calls int }

func (s *legacyLoginLinkSender) SendCampaignLoginLink(context.Context, uuid.UUID, uuid.UUID) (ActionResult, error) {
	s.calls++
	return ActionResult{Outcome: OutcomeProviderAccepted}, nil
}

// legacyOnlyJobStore deliberately exposes only the pre-fencing store methods.
// It verifies that an adapter cannot execute a job by silently falling back to
// an unfenced claim path.
type legacyOnlyJobStore struct {
	inner *MemoryAdminStore
}

func (s *legacyOnlyJobStore) CreateJob(ctx context.Context, job AdminJob, items []AdminJobItem) (*AdminJob, error) {
	return s.inner.CreateJob(ctx, job, items)
}

func (s *legacyOnlyJobStore) GetJob(ctx context.Context, id uuid.UUID) (*AdminJob, error) {
	return s.inner.GetJob(ctx, id)
}

func (s *legacyOnlyJobStore) ListJobs(ctx context.Context, cursor string, limit int, status, action string) (AdminJobPage, error) {
	return s.inner.ListJobs(ctx, cursor, limit, status, action)
}

func (s *legacyOnlyJobStore) ListJobItems(ctx context.Context, id uuid.UUID, cursor string, limit int) (AdminJobRecipientPage, error) {
	return s.inner.ListJobItems(ctx, id, cursor, limit)
}

func (s *legacyOnlyJobStore) ClaimJobItem(ctx context.Context, jobID, itemID uuid.UUID, worker string) (*AdminJobItem, bool, error) {
	return s.inner.ClaimJobItem(ctx, jobID, itemID, worker)
}

func (s *legacyOnlyJobStore) FinishJobItem(ctx context.Context, itemID uuid.UUID, outcome, reason, errorCode, providerReference string) (*AdminJobItem, error) {
	return s.inner.FinishJobItem(ctx, itemID, outcome, reason, errorCode, providerReference)
}

func (s *legacyOnlyJobStore) ApplyJobCommand(ctx context.Context, command AdminJobCommand) (*AdminJob, error) {
	return s.inner.ApplyJobCommand(ctx, command)
}

func (s *legacyOnlyJobStore) PauseJob(ctx context.Context, id uuid.UUID, reason string) error {
	return s.inner.PauseJob(ctx, id, reason)
}

func (s *legacyOnlyJobStore) UpdateJobProgress(ctx context.Context, id uuid.UUID) error {
	return s.inner.UpdateJobProgress(ctx, id)
}

func TestBulkExecutionRejectsUnfencedLegacyStore(t *testing.T) {
	store, audience, actor, job := makeCredentialJob(t, ActionLoginLink)
	legacyStore := &legacyOnlyJobStore{inner: store}
	sender := &idempotentLoginLinkSender{first: ActionResult{Outcome: OutcomeProviderAccepted}}
	bulk := NewAdminBulkService(legacyStore, audience, &AdminActionPorts{LoginLinkIdempotent: sender, Eligibility: readyEligibilityChecker{}})
	bulk.SetActorReloader(staticAdminActorReloader{actor: actor})
	itemID := store.JobItems[job.ID][0].ID
	if _, err := bulk.ProcessItem(context.Background(), actor, job.ID, itemID); !errors.Is(err, ErrAdminRepositoryAbsent) {
		t.Fatalf("legacy store error = %v, want repository unavailable", err)
	}
	if sender.calls != 0 {
		t.Fatalf("legacy store reached keyed sender: %d calls", sender.calls)
	}
	stored, err := store.GetJob(context.Background(), job.ID)
	if err != nil {
		t.Fatalf("get paused job: %v", err)
	}
	if stored.Status != JobPaused {
		t.Fatalf("legacy store job status = %q, want paused", stored.Status)
	}
}

type unsupportedUnknownDeliveryStore struct {
	*MemoryAdminStore
}

func (s *unsupportedUnknownDeliveryStore) SupportsTerminalUnknownDelivery() bool {
	return false
}

func TestBulkExecutionRejectsStoreWithoutTerminalUnknownDelivery(t *testing.T) {
	base, audience, actor, job := makeCredentialJob(t, ActionLoginLink)
	store := &unsupportedUnknownDeliveryStore{MemoryAdminStore: base}
	sender := &idempotentLoginLinkSender{first: ActionResult{Outcome: OutcomeProviderAccepted}}
	bulk := NewAdminBulkService(store, audience, &AdminActionPorts{LoginLinkIdempotent: sender, Eligibility: readyEligibilityChecker{}})
	bulk.SetActorReloader(staticAdminActorReloader{actor: actor})
	itemID := store.JobItems[job.ID][0].ID
	if _, err := bulk.ProcessItem(context.Background(), actor, job.ID, itemID); !errors.Is(err, ErrAdminRepositoryAbsent) {
		t.Fatalf("unsupported terminal unknown error = %v, want repository unavailable", err)
	}
	if sender.calls != 0 {
		t.Fatalf("unsupported terminal unknown store reached sender: %d calls", sender.calls)
	}
	stored, err := store.GetJob(context.Background(), job.ID)
	if err != nil {
		t.Fatalf("get paused job: %v", err)
	}
	if stored.Status != JobPaused {
		t.Fatalf("unsupported terminal unknown job status = %q, want paused", stored.Status)
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
	action := allAudienceMessageAction(kind)
	if kind == ActionRevokeSessions {
		action = AdminAction{Kind: kind, Reason: "account requested"}
	}
	preview, err := audience.Preview(context.Background(), actor, AudiencePreviewRequest{Audience: Audience{Kind: AudienceSelected, Resource: AudienceAccounts, IDs: []uuid.UUID{target}}, Action: action})
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
