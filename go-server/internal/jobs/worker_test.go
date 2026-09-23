package jobs

import (
	"context"
	"encoding/json"
	"errors"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/lrprojects/monaserver/internal/db"
)

type fakeJobStore struct {
	mu                 sync.Mutex
	finished           []finishCall
	released           []releaseCall
	extended           []extendCall
	releaseContextErr  error
	releaseHasDeadline bool
}

type finishCall struct {
	id     uuid.UUID
	worker string
	token  uuid.UUID
	status string
}

type releaseCall struct {
	id          uuid.UUID
	worker      string
	token       uuid.UUID
	availableAt time.Time
}

type extendCall struct {
	id     uuid.UUID
	worker string
	token  uuid.UUID
	lease  time.Duration
}

func (f *fakeJobStore) ClaimDurableJobs(context.Context, string, int, time.Duration) ([]db.DurableJob, error) {
	return nil, nil
}

func (f *fakeJobStore) ClaimDurableJobsByKinds(context.Context, string, []string, int, time.Duration) ([]db.DurableJob, error) {
	return nil, nil
}

func (f *fakeJobStore) ExtendDurableJobLease(_ context.Context, id uuid.UUID, worker string, token uuid.UUID, lease time.Duration) (bool, error) {
	f.mu.Lock()
	f.extended = append(f.extended, extendCall{id: id, worker: worker, token: token, lease: lease})
	f.mu.Unlock()
	return true, nil
}

func (f *fakeJobStore) FinishDurableJob(_ context.Context, id uuid.UUID, worker string, token uuid.UUID, status string) (bool, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.finished = append(f.finished, finishCall{id: id, worker: worker, token: token, status: status})
	return true, nil
}

func (f *fakeJobStore) ReleaseDurableJobLease(ctx context.Context, id uuid.UUID, worker string, token uuid.UUID, availableAt time.Time) (bool, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.releaseContextErr = ctx.Err()
	_, f.releaseHasDeadline = ctx.Deadline()
	f.released = append(f.released, releaseCall{id: id, worker: worker, token: token, availableAt: availableAt})
	return true, nil
}

type failingHeartbeatStore struct {
	fakeJobStore
	result chan struct{}
}

func (f *failingHeartbeatStore) ExtendDurableJobLease(_ context.Context, id uuid.UUID, worker string, token uuid.UUID, lease time.Duration) (bool, error) {
	f.mu.Lock()
	f.extended = append(f.extended, extendCall{id: id, worker: worker, token: token, lease: lease})
	f.mu.Unlock()
	select {
	case f.result <- struct{}{}:
	default:
	}
	return false, nil
}

type queueJobStore struct {
	mu          sync.Mutex
	jobs        []db.DurableJob
	claimLimits []int
	claimKinds  []claimKindsCall
	finished    []finishCall
	released    []releaseCall
}

type claimKindsCall struct {
	worker string
	kinds  []string
	limit  int
}

func (f *queueJobStore) ClaimDurableJobs(_ context.Context, worker string, limit int, _ time.Duration) ([]db.DurableJob, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.claimLimits = append(f.claimLimits, limit)
	if len(f.jobs) == 0 {
		return nil, nil
	}
	if limit > len(f.jobs) {
		limit = len(f.jobs)
	}
	claimed := append([]db.DurableJob(nil), f.jobs[:limit]...)
	f.jobs = f.jobs[limit:]
	for i := range claimed {
		claimed[i].LeaseOwner = stringPtr(worker)
		if claimed[i].LeaseToken == uuid.Nil {
			claimed[i].LeaseToken = uuid.New()
		}
	}
	return claimed, nil
}

func (f *queueJobStore) ClaimDurableJobsByKinds(_ context.Context, worker string, kinds []string, limit int, _ time.Duration) ([]db.DurableJob, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.claimLimits = append(f.claimLimits, limit)
	call := claimKindsCall{worker: worker, kinds: append([]string{}, kinds...), limit: limit}
	f.claimKinds = append(f.claimKinds, call)
	allowed := make(map[string]struct{}, len(kinds))
	for _, kind := range kinds {
		allowed[kind] = struct{}{}
	}
	allKinds := len(kinds) == 0
	claimed := make([]db.DurableJob, 0, limit)
	remaining := f.jobs[:0]
	for _, job := range f.jobs {
		if len(claimed) >= limit {
			remaining = append(remaining, job)
			continue
		}
		if !allKinds {
			if _, ok := allowed[job.Kind]; !ok {
				remaining = append(remaining, job)
				continue
			}
		}
		job.LeaseOwner = stringPtr(worker)
		if job.LeaseToken == uuid.Nil {
			job.LeaseToken = uuid.New()
		}
		claimed = append(claimed, job)
	}
	f.jobs = remaining
	return claimed, nil
}

func (f *queueJobStore) ExtendDurableJobLease(context.Context, uuid.UUID, string, uuid.UUID, time.Duration) (bool, error) {
	return true, nil
}

func (f *queueJobStore) FinishDurableJob(_ context.Context, id uuid.UUID, worker string, token uuid.UUID, status string) (bool, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.finished = append(f.finished, finishCall{id: id, worker: worker, token: token, status: status})
	return true, nil
}

func (f *queueJobStore) ReleaseDurableJobLease(_ context.Context, id uuid.UUID, worker string, token uuid.UUID, availableAt time.Time) (bool, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.released = append(f.released, releaseCall{id: id, worker: worker, token: token, availableAt: availableAt})
	return true, nil
}

func testJob(payload any, attempt, maxAttempts int32) db.DurableJob {
	raw, _ := json.Marshal(payload)
	return db.DurableJob{
		ID:           uuid.New(),
		Kind:         "email",
		Payload:      raw,
		AttemptCount: attempt,
		MaxAttempts:  maxAttempts,
		LeaseOwner:   stringPtr("worker-a"),
		LeaseToken:   uuid.New(),
		AvailableAt:  time.Unix(100, 0),
	}
}

func stringPtr(value string) *string { return &value }

func TestRegisterTypedHandlerDecodesPayloadAndCompletesLease(t *testing.T) {
	store := &fakeJobStore{}
	w := NewWorker(store, Config{WorkerID: "worker-a", Clock: func() time.Time { return time.Unix(200, 0) }})

	type emailPayload struct {
		To string `json:"to"`
	}
	var got string
	if err := RegisterTyped(w, "email", func(_ context.Context, _ Job, payload emailPayload) Result {
		got = payload.To
		return Success()
	}); err != nil {
		t.Fatalf("register typed handler: %v", err)
	}

	job := testJob(emailPayload{To: "person@example.test"}, 1, 3)
	if err := w.process(context.Background(), job); err != nil {
		t.Fatalf("process job: %v", err)
	}
	if got != "person@example.test" {
		t.Fatalf("handler payload = %q, want recipient", got)
	}
	if len(store.finished) != 1 || store.finished[0].status != StatusCompleted {
		t.Fatalf("finished calls = %#v, want completed", store.finished)
	}
}

func TestTransientHandlerResultUsesExponentialBackoffAndStopsAtAttemptLimit(t *testing.T) {
	now := time.Unix(200, 0)
	store := &fakeJobStore{}
	w := NewWorker(store, Config{
		WorkerID:      "worker-a",
		Clock:         func() time.Time { return now },
		BackoffBase:   2 * time.Second,
		BackoffMax:    20 * time.Second,
		DisableJitter: true,
	})
	if err := w.Register("email", HandlerFunc(func(context.Context, Job) Result {
		return Retry(errors.New("provider unavailable"))
	})); err != nil {
		t.Fatalf("register handler: %v", err)
	}

	first := testJob(map[string]string{"to": "person@example.test"}, 1, 3)
	if err := w.process(context.Background(), first); err != nil {
		t.Fatalf("first process: %v", err)
	}
	if len(store.released) != 1 || !store.released[0].availableAt.Equal(now.Add(2*time.Second)) {
		t.Fatalf("first release = %#v, want +2s", store.released)
	}

	second := first
	second.AttemptCount = 2
	if err := w.process(context.Background(), second); err != nil {
		t.Fatalf("second process: %v", err)
	}
	if len(store.released) != 2 || !store.released[1].availableAt.Equal(now.Add(4*time.Second)) {
		t.Fatalf("second release = %#v, want +4s", store.released)
	}

	third := first
	third.AttemptCount = 3
	if err := w.process(context.Background(), third); err != nil {
		t.Fatalf("final process: %v", err)
	}
	if len(store.finished) != 1 || store.finished[0].status != StatusFailed {
		t.Fatalf("final finish = %#v, want failed", store.finished)
	}
}

func TestWorkerCancellationReleasesInFlightLease(t *testing.T) {
	store := &fakeJobStore{}
	w := NewWorker(store, Config{WorkerID: "worker-a", Clock: time.Now})
	started := make(chan struct{})
	if err := w.Register("email", HandlerFunc(func(ctx context.Context, _ Job) Result {
		close(started)
		<-ctx.Done()
		return Cancelled()
	})); err != nil {
		t.Fatalf("register handler: %v", err)
	}

	ctx, cancel := context.WithCancel(context.Background())
	job := testJob(map[string]string{"to": "person@example.test"}, 1, 3)
	done := make(chan error, 1)
	go func() { done <- w.process(ctx, job) }()
	<-started
	cancel()
	if err := <-done; err != nil && !errors.Is(err, context.Canceled) {
		t.Fatalf("cancelled process: %v", err)
	}
	if len(store.released) != 1 {
		t.Fatalf("released calls = %#v, want one lease release", store.released)
	}
}

func TestProcessHeartbeatsLeaseDuringLongHandler(t *testing.T) {
	store := &fakeJobStore{}
	w := NewWorker(store, Config{WorkerID: "worker-a", LeaseDuration: 30 * time.Millisecond, Clock: time.Now})
	started := make(chan struct{})
	if err := w.Register("email", HandlerFunc(func(ctx context.Context, _ Job) Result {
		close(started)
		<-ctx.Done()
		return Cancelled()
	})); err != nil {
		t.Fatalf("register handler: %v", err)
	}

	ctx, cancel := context.WithCancel(context.Background())
	job := testJob(map[string]string{"to": "person@example.test"}, 1, 3)
	done := make(chan error, 1)
	go func() { done <- w.process(ctx, job) }()
	<-started
	deadline := time.After(250 * time.Millisecond)
	for {
		store.mu.Lock()
		extensions := len(store.extended)
		store.mu.Unlock()
		if extensions > 0 {
			break
		}
		select {
		case <-deadline:
			cancel()
			t.Fatal("worker did not extend the in-flight lease")
		case <-time.After(time.Millisecond):
		}
	}
	cancel()
	if err := <-done; err != nil {
		t.Fatalf("cancelled process: %v", err)
	}
	store.mu.Lock()
	defer store.mu.Unlock()
	if len(store.extended) == 0 || store.extended[0].lease != 30*time.Millisecond {
		t.Fatalf("lease extensions = %#v, want the configured lease", store.extended)
	}
}

func TestProcessFencesHandlerWhenLeaseHeartbeatFails(t *testing.T) {
	store := &failingHeartbeatStore{result: make(chan struct{}, 1)}
	w := NewWorker(store, Config{WorkerID: "worker-a", LeaseDuration: 30 * time.Millisecond, Clock: time.Now})
	started := make(chan struct{})
	cancelled := make(chan struct{})
	if err := w.Register("email", HandlerFunc(func(ctx context.Context, _ Job) Result {
		close(started)
		<-ctx.Done()
		close(cancelled)
		return Success()
	})); err != nil {
		t.Fatalf("register handler: %v", err)
	}

	job := testJob(map[string]string{"to": "person@example.test"}, 1, 3)
	done := make(chan error, 1)
	go func() { done <- w.process(context.Background(), job) }()
	<-started
	select {
	case <-cancelled:
	case <-time.After(250 * time.Millisecond):
		t.Fatal("heartbeat failure did not cancel the handler")
	}
	if err := <-done; !errors.Is(err, ErrLeaseLost) {
		t.Fatalf("fenced process error = %v, want lease lost", err)
	}
	store.mu.Lock()
	defer store.mu.Unlock()
	if len(store.finished) != 0 || len(store.released) != 0 {
		t.Fatalf("fenced lease was acknowledged: finish=%#v release=%#v", store.finished, store.released)
	}
}

func TestCancelledProcessUsesIndependentCleanupContext(t *testing.T) {
	store := &fakeJobStore{}
	w := NewWorker(store, Config{WorkerID: "worker-a", Clock: time.Now})
	started := make(chan struct{})
	if err := w.Register("email", HandlerFunc(func(ctx context.Context, _ Job) Result {
		close(started)
		<-ctx.Done()
		return Cancelled()
	})); err != nil {
		t.Fatalf("register handler: %v", err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan error, 1)
	go func() { done <- w.process(ctx, testJob(map[string]string{"to": "person@example.test"}, 1, 3)) }()
	<-started
	cancel()
	if err := <-done; err != nil {
		t.Fatalf("cancelled process: %v", err)
	}
	store.mu.Lock()
	defer store.mu.Unlock()
	if len(store.released) != 1 {
		t.Fatalf("released calls = %#v, want one lease release", store.released)
	}
	if store.releaseContextErr != nil || !store.releaseHasDeadline {
		t.Fatalf("cleanup context err=%v deadline=%v, want independent bounded context", store.releaseContextErr, store.releaseHasDeadline)
	}
}

func TestRunKeepsClaimedWorkWithinConfiguredConcurrency(t *testing.T) {
	store := &queueJobStore{}
	for i := 0; i < 5; i++ {
		store.jobs = append(store.jobs, testJob(map[string]int{"index": i}, 1, 2))
	}
	w := NewWorker(store, Config{
		WorkerID:     "worker-a",
		Concurrency:  2,
		PollInterval: time.Millisecond,
		Clock:        time.Now,
	})
	var active atomic.Int32
	var maximum atomic.Int32
	var finished atomic.Int32
	allFinished := make(chan struct{})
	if err := w.Register("email", HandlerFunc(func(ctx context.Context, _ Job) Result {
		current := active.Add(1)
		for {
			old := maximum.Load()
			if current <= old || maximum.CompareAndSwap(old, current) {
				break
			}
		}
		select {
		case <-time.After(10 * time.Millisecond):
		case <-ctx.Done():
		}
		active.Add(-1)
		if finished.Add(1) == 5 {
			close(allFinished)
		}
		return Success()
	})); err != nil {
		t.Fatalf("register handler: %v", err)
	}

	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan error, 1)
	go func() { done <- w.Run(ctx) }()
	select {
	case <-allFinished:
		cancel()
	case <-time.After(time.Second):
		cancel()
		t.Fatal("worker did not process all queued jobs")
	}
	if err := <-done; !errors.Is(err, context.Canceled) {
		t.Fatalf("run error = %v, want context cancellation", err)
	}
	if got := maximum.Load(); got > 2 {
		t.Fatalf("maximum concurrent handlers = %d, want at most 2", got)
	}
	if len(store.claimLimits) == 0 {
		t.Fatal("worker never claimed jobs")
	}
	for _, limit := range store.claimLimits {
		if limit > 2 {
			t.Fatalf("claim limit = %d, want at most configured concurrency", limit)
		}
	}
}

func TestRunClaimsConfiguredKindsInsideStore(t *testing.T) {
	store := &queueJobStore{jobs: []db.DurableJob{
		jobWithKind("bulk.email", 1),
		jobWithKind("auth.email", 1),
	}}
	w := NewWorker(store, Config{
		WorkerID:     "auth-worker",
		Kinds:        []string{" auth.email ", "auth.email"},
		PollInterval: time.Millisecond,
		Clock:        time.Now,
	})
	processed := make(chan struct{})
	if err := w.Register("auth.email", HandlerFunc(func(context.Context, Job) Result {
		close(processed)
		return Success()
	})); err != nil {
		t.Fatalf("register handler: %v", err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan error, 1)
	go func() { done <- w.Run(ctx) }()
	select {
	case <-processed:
		waitForFinishedJobs(t, store, 1)
		cancel()
	case <-time.After(time.Second):
		cancel()
		t.Fatal("worker did not process the configured kind")
	}
	if err := <-done; !errors.Is(err, context.Canceled) {
		t.Fatalf("run error = %v, want context cancellation", err)
	}
	store.mu.Lock()
	defer store.mu.Unlock()
	if len(store.claimKinds) == 0 {
		t.Fatal("worker never used kind-aware claim")
	}
	if got := store.claimKinds[0].kinds; len(got) != 1 || got[0] != "auth.email" {
		t.Fatalf("claimed kinds = %#v, want normalized auth kind", got)
	}
	if len(store.finished) != 1 || store.finished[0].status != StatusCompleted {
		t.Fatalf("finished calls = %#v, want auth completion", store.finished)
	}
	if len(store.released) != 0 {
		t.Fatalf("released calls = %#v, want no cross-family release", store.released)
	}
	if len(store.jobs) != 1 || store.jobs[0].Kind != "bulk.email" {
		t.Fatalf("remaining jobs = %#v, want bulk job untouched", store.jobs)
	}
}

func TestRunEmptyKindsClaimsAllFamilies(t *testing.T) {
	store := &queueJobStore{jobs: []db.DurableJob{
		jobWithKind("bulk.email", 1),
		jobWithKind("auth.email", 1),
	}}
	w := NewWorker(store, Config{WorkerID: "all-worker", PollInterval: time.Millisecond, Clock: time.Now})
	var processed atomic.Int32
	allProcessed := make(chan struct{})
	if err := w.Register("bulk.email", HandlerFunc(func(context.Context, Job) Result {
		if processed.Add(1) == 2 {
			close(allProcessed)
		}
		return Success()
	})); err != nil {
		t.Fatalf("register bulk handler: %v", err)
	}
	if err := w.Register("auth.email", HandlerFunc(func(context.Context, Job) Result {
		if processed.Add(1) == 2 {
			close(allProcessed)
		}
		return Success()
	})); err != nil {
		t.Fatalf("register auth handler: %v", err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan error, 1)
	go func() { done <- w.Run(ctx) }()
	select {
	case <-allProcessed:
		waitForFinishedJobs(t, store, 2)
		cancel()
	case <-time.After(time.Second):
		cancel()
		t.Fatal("worker did not process every family with empty kinds")
	}
	if err := <-done; !errors.Is(err, context.Canceled) {
		t.Fatalf("run error = %v, want context cancellation", err)
	}
	store.mu.Lock()
	defer store.mu.Unlock()
	if len(store.claimKinds) == 0 || store.claimKinds[0].kinds == nil || len(store.claimKinds[0].kinds) != 0 {
		t.Fatalf("empty kind claim = %#v, want explicit empty allowlist", store.claimKinds)
	}
	if len(store.jobs) != 0 || len(store.finished) != 2 {
		t.Fatalf("jobs/finished = %d/%d, want all families processed", len(store.jobs), len(store.finished))
	}
}

func waitForFinishedJobs(t *testing.T, store *queueJobStore, want int) {
	t.Helper()
	deadline := time.Now().Add(time.Second)
	for time.Now().Before(deadline) {
		store.mu.Lock()
		finished := len(store.finished)
		store.mu.Unlock()
		if finished >= want {
			return
		}
		time.Sleep(time.Millisecond)
	}
	store.mu.Lock()
	defer store.mu.Unlock()
	t.Fatalf("finished jobs = %d, want at least %d", len(store.finished), want)
}

func jobWithKind(kind string, attempt int32) db.DurableJob {
	job := testJob(map[string]string{"kind": kind}, attempt, 3)
	job.Kind = kind
	return job
}

func TestShutdownWaitsForHandlerBeforeReturning(t *testing.T) {
	store := &queueJobStore{jobs: []db.DurableJob{testJob(map[string]string{"to": "person@example.test"}, 1, 2)}}
	w := NewWorker(store, Config{WorkerID: "worker-a", PollInterval: time.Millisecond, Clock: time.Now})
	started := make(chan struct{})
	release := make(chan struct{})
	if err := w.Register("email", HandlerFunc(func(context.Context, Job) Result {
		close(started)
		<-release
		return Success()
	})); err != nil {
		t.Fatalf("register handler: %v", err)
	}
	w.Start(context.Background())
	<-started
	shutdownDone := make(chan error, 1)
	go func() { shutdownDone <- w.Shutdown(context.Background()) }()
	select {
	case err := <-shutdownDone:
		t.Fatalf("shutdown returned before handler completed: %v", err)
	case <-time.After(10 * time.Millisecond):
	}
	close(release)
	if err := <-shutdownDone; err != nil {
		t.Fatalf("shutdown: %v", err)
	}
	if len(store.finished) != 0 || len(store.released) != 1 {
		t.Fatalf("finish/release calls = %#v/%#v, want the cancelled lease released", store.finished, store.released)
	}
}

type fakeEnqueueStore struct {
	mu       sync.Mutex
	jobs     map[uuid.UUID]db.DurableJob
	outboxes map[uuid.UUID]db.OutboxEvent
}

func newFakeEnqueueStore() *fakeEnqueueStore {
	return &fakeEnqueueStore{jobs: make(map[uuid.UUID]db.DurableJob), outboxes: make(map[uuid.UUID]db.OutboxEvent)}
}

func (f *fakeEnqueueStore) CreateDurableJob(_ context.Context, p db.DurableJobParams) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	for _, existing := range f.jobs {
		if existing.Kind == p.Kind && existing.IdempotencyKey == p.IdempotencyKey {
			return nil
		}
	}
	f.jobs[p.ID] = db.DurableJob{ID: p.ID, Kind: p.Kind, IdempotencyKey: p.IdempotencyKey, Payload: append([]byte(nil), p.Payload...), Priority: p.Priority, AvailableAt: p.AvailableAt, MaxAttempts: p.MaxAttempts, Status: StatusPending}
	return nil
}

func (f *fakeEnqueueStore) GetDurableJob(_ context.Context, id uuid.UUID) (*db.DurableJob, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	job, ok := f.jobs[id]
	if !ok {
		return nil, nil
	}
	return &job, nil
}

func (f *fakeEnqueueStore) GetDurableJobByIdempotencyKey(_ context.Context, kind, key string) (*db.DurableJob, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	for _, job := range f.jobs {
		if job.Kind == kind && job.IdempotencyKey == key {
			copy := job
			return &copy, nil
		}
	}
	return nil, nil
}

func (f *fakeEnqueueStore) CreateOutboxEvent(_ context.Context, p db.OutboxEventParams) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	for _, existing := range f.outboxes {
		if existing.IdempotencyKey == p.IdempotencyKey {
			return nil
		}
	}
	f.outboxes[p.ID] = db.OutboxEvent{ID: p.ID, Topic: p.Topic, AggregateID: p.AggregateID, IdempotencyKey: p.IdempotencyKey, Payload: append([]byte(nil), p.Payload...), AvailableAt: p.AvailableAt, Status: "pending"}
	return nil
}

func TestEnqueueDurableJobIsIdempotentAndRejectsPayloadConflicts(t *testing.T) {
	store := newFakeEnqueueStore()
	req := EnqueueRequest{Kind: "email", IdempotencyKey: "command-1", Payload: json.RawMessage(`{"to":"person@example.test"}`), AvailableAt: time.Unix(200, 0), MaxAttempts: 3}
	first, err := EnqueueDurableJob(context.Background(), store, req)
	if err != nil {
		t.Fatalf("first enqueue: %v", err)
	}
	second, err := EnqueueDurableJob(context.Background(), store, req)
	if err != nil {
		t.Fatalf("idempotent enqueue: %v", err)
	}
	if first != second || len(store.jobs) != 1 {
		t.Fatalf("ids/jobs = %v/%d, want one stable job", first, len(store.jobs))
	}
	req.Payload = json.RawMessage(`{"to":"other@example.test"}`)
	if _, err := EnqueueDurableJob(context.Background(), store, req); !errors.Is(err, ErrIdempotencyConflict) {
		t.Fatalf("conflicting enqueue error = %v, want idempotency conflict", err)
	}
}

func TestEnqueueDurableJobRejectsExplicitIDReuseWithDifferentJobID(t *testing.T) {
	store := newFakeEnqueueStore()
	firstID := uuid.New()
	first, err := EnqueueDurableJob(context.Background(), store, EnqueueRequest{
		ID: firstID, Kind: "email", IdempotencyKey: "explicit-reuse", Payload: json.RawMessage(`{"to":"person@example.test"}`), AvailableAt: time.Unix(200, 0), MaxAttempts: 3,
	})
	if err != nil || first != firstID {
		t.Fatalf("first enqueue = %v, %v", first, err)
	}
	secondID := uuid.New()
	if _, err := EnqueueDurableJob(context.Background(), store, EnqueueRequest{
		ID: secondID, Kind: "email", IdempotencyKey: "explicit-reuse", Payload: json.RawMessage(`{"to":"person@example.test"}`), AvailableAt: time.Unix(200, 0), MaxAttempts: 3,
	}); !errors.Is(err, ErrIdempotencyConflict) {
		t.Fatalf("explicit-ID reuse error = %v, want idempotency conflict", err)
	}
}

func TestNewWorkerAppliesDefaultJitterAndSupportsDeterministicOverride(t *testing.T) {
	defaultWorker := NewWorker(&fakeJobStore{}, Config{WorkerID: "worker-a"})
	if defaultWorker.cfg.Jitter != defaultJitter {
		t.Fatalf("default jitter = %v, want %v", defaultWorker.cfg.Jitter, defaultJitter)
	}
	deterministicWorker := NewWorker(&fakeJobStore{}, Config{WorkerID: "worker-b", DisableJitter: true})
	if deterministicWorker.cfg.Jitter != 0 {
		t.Fatalf("deterministic jitter = %v, want zero", deterministicWorker.cfg.Jitter)
	}
}

func TestSafeErrorReturnsOnlyAllowlistedDiagnostics(t *testing.T) {
	secret := "opaque-token-value"
	for _, tc := range []struct {
		name string
		err  error
		want string
	}{
		{name: "timeout", err: errors.New("smtp timeout token=" + secret), want: "timeout"},
		{name: "database conflict", err: errors.New("serialization failure password=hunter2"), want: "database_conflict"},
		{name: "unknown", err: errors.New("provider returned secret=" + secret), want: "worker_error"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			got := safeError(tc.err)
			if got != tc.want {
				t.Fatalf("safe error = %q, want %q", got, tc.want)
			}
			if len(got) > 64 || strings.Contains(got, secret) {
				t.Fatalf("safe error exposed unbounded/secret text: %q", got)
			}
		})
	}
}

func TestEnqueueOutboxUsesCallerOwnedStoreAndDeduplicates(t *testing.T) {
	store := newFakeEnqueueStore()
	req := OutboxRequest{ID: uuid.New(), Topic: "account.recovery", IdempotencyKey: "outbox-1", Payload: json.RawMessage(`{"account":"id"}`), AvailableAt: time.Unix(200, 0)}
	if err := EnqueueOutboxEvent(context.Background(), store, req); err != nil {
		t.Fatalf("first outbox enqueue: %v", err)
	}
	if err := EnqueueOutboxEvent(context.Background(), store, req); err != nil {
		t.Fatalf("duplicate outbox enqueue: %v", err)
	}
	if len(store.outboxes) != 1 {
		t.Fatalf("outbox rows = %d, want one idempotent row", len(store.outboxes))
	}
}
