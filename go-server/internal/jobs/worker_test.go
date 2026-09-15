package jobs

import (
	"context"
	"encoding/json"
	"errors"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/lrprojects/monaserver/internal/db"
)

type fakeJobStore struct {
	mu       sync.Mutex
	finished []finishCall
	released []releaseCall
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

func (f *fakeJobStore) ClaimDurableJobs(context.Context, string, int, time.Duration) ([]db.DurableJob, error) {
	return nil, nil
}

func (f *fakeJobStore) ExtendDurableJobLease(context.Context, uuid.UUID, string, uuid.UUID, time.Duration) (bool, error) {
	return true, nil
}

func (f *fakeJobStore) FinishDurableJob(_ context.Context, id uuid.UUID, worker string, token uuid.UUID, status string) (bool, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.finished = append(f.finished, finishCall{id: id, worker: worker, token: token, status: status})
	return true, nil
}

func (f *fakeJobStore) ReleaseDurableJobLease(_ context.Context, id uuid.UUID, worker string, token uuid.UUID, availableAt time.Time) (bool, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.released = append(f.released, releaseCall{id: id, worker: worker, token: token, availableAt: availableAt})
	return true, nil
}

type queueJobStore struct {
	mu          sync.Mutex
	jobs        []db.DurableJob
	claimLimits []int
	finished    []finishCall
	released    []releaseCall
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
		WorkerID:    "worker-a",
		Clock:       func() time.Time { return now },
		BackoffBase: 2 * time.Second,
		BackoffMax:  20 * time.Second,
		Jitter:      0,
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
