// Package jobs provides the durable PostgreSQL worker used by asynchronous
// account and delivery work.  A job is claimed with a database lease and can
// only be acknowledged by the worker that owns the current lease token.
package jobs

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"math/rand"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"

	"github.com/lrprojects/monaserver/internal/db"
)

// Job is the application-facing durable job row.  It aliases the DB facade
// value so handlers cannot accidentally use generated SQL types.
type Job = db.DurableJob

// DurableJobStore is deliberately narrow.  The concrete *db.Queries facade
// satisfies it while tests and future queue backends can provide the same
// lease semantics without coupling handlers to PostgreSQL.
type DurableJobStore interface {
	ClaimDurableJobsByKinds(context.Context, string, []string, int, time.Duration) ([]db.DurableJob, error)
	ExtendDurableJobLease(context.Context, uuid.UUID, string, uuid.UUID, time.Duration) (bool, error)
	FinishDurableJob(context.Context, uuid.UUID, string, uuid.UUID, string) (bool, error)
	ReleaseDurableJobLease(context.Context, uuid.UUID, string, uuid.UUID, time.Time) (bool, error)
}

const (
	// Durable job statuses mirror the checked values in the database.
	StatusPending   = db.DurableJobPending
	StatusRunning   = db.DurableJobRunning
	StatusCompleted = db.DurableJobCompleted
	StatusFailed    = db.DurableJobFailed
	StatusCancelled = db.DurableJobCancelled
)

// Outcome is the structured business result vocabulary shared by worker
// handlers and admin recipient records.  A durable job status describes the
// queue lifecycle; an Outcome describes the recipient/provider result.
type Outcome string

const (
	OutcomeSkipped          Outcome = "skipped"
	OutcomeSecured          Outcome = "secured"
	OutcomeQueued           Outcome = "queued"
	OutcomeProviderAccepted Outcome = "provider_accepted"
	OutcomeFailed           Outcome = "failed"
	OutcomeUnknownDelivery  Outcome = "unknown_delivery"
)

// Result is returned by a business handler.  Retry asks the worker to release
// the lease for a later attempt.  Error is used for diagnostics and is never
// persisted or logged verbatim by the worker.  ErrorCode is a bounded,
// provider-independent summary that delivery adapters may persist separately.
type Result struct {
	Status     string
	Outcome    Outcome
	Retry      bool
	RetryAfter time.Duration
	ErrorCode  string
	Err        error
}

// Success marks a job as completed.  Handlers may set Outcome after calling
// this helper when a recipient-level result needs to be surfaced.
func Success() Result { return Result{Status: StatusCompleted} }

// Retry requests another attempt.  The worker applies exponential backoff
// and caps the retry at the row's MaxAttempts.
func Retry(err error) Result { return Result{Retry: true, Outcome: OutcomeUnknownDelivery, Err: err} }

// Failed marks a job permanently failed.  The error is retained only by the
// caller's structured delivery record, never copied into queue diagnostics.
func Failed(err error) Result { return Result{Status: StatusFailed, Outcome: OutcomeFailed, Err: err} }

// Cancelled releases a claimed lease so an authorized job is not silently
// lost when a worker is shutting down.  A user-requested cancellation should
// finish the row as StatusCancelled through the owning command service.
func Cancelled() Result { return Result{Status: StatusCancelled, Retry: true} }

// Handler is the untyped boundary used by the worker registry.  RegisterTyped
// adds JSON decoding at registration time while preserving this narrow runtime
// interface.
type Handler interface {
	Handle(context.Context, Job) Result
}

// HandlerFunc adapts a function to Handler.
type HandlerFunc func(context.Context, Job) Result

func (f HandlerFunc) Handle(ctx context.Context, job Job) Result { return f(ctx, job) }

// TypedHandler receives a decoded, business-specific payload.
type TypedHandler[T any] func(context.Context, Job, T) Result

// Config controls polling, lease duration, concurrency, and retry timing.
// Zero values use conservative production defaults.
type Config struct {
	WorkerID      string
	Concurrency   int
	PollInterval  time.Duration
	LeaseDuration time.Duration
	BackoffBase   time.Duration
	BackoffMax    time.Duration
	// Jitter is a fraction of the computed delay, in [0, 1].  The default is
	// 0.2. Set DisableJitter for deterministic tests that need exact delays.
	Jitter float64
	// DisableJitter is an explicit deterministic-test switch. A zero Jitter
	// value otherwise selects the documented production default.
	DisableJitter bool
	// Kinds optionally limits this worker to one queue family.  A worker with
	// no allowlist handles every registered kind.  Jobs from another queue are
	// released immediately and remain available to their dedicated worker.
	Kinds  []string
	Clock  func() time.Time
	Rand   *rand.Rand
	Logger *slog.Logger
}

const (
	defaultPollInterval  = time.Second
	defaultLeaseDuration = 30 * time.Second
	defaultBackoffBase   = time.Second
	defaultBackoffMax    = 5 * time.Minute
	defaultJitter        = 0.2
)

// Worker claims durable jobs and dispatches them to registered handlers.
// Every goroutine started by Start/Run is accounted for by handlersWG and the
// run completion channel, which makes Shutdown deterministic.
type Worker struct {
	store DurableJobStore
	cfg   Config

	mu       sync.RWMutex
	handlers map[string]Handler
	started  bool
	cancel   context.CancelFunc
	done     chan struct{}
	runErr   error

	handlersWG sync.WaitGroup
	randMu     sync.Mutex
}

// NewWorker constructs a worker.  It does not start goroutines; callers may
// register all business handlers before invoking Start or Run.
func NewWorker(store DurableJobStore, cfg Config) *Worker {
	if cfg.WorkerID == "" {
		cfg.WorkerID = "worker-" + uuid.NewString()
	}
	if cfg.Concurrency <= 0 {
		cfg.Concurrency = 1
	}
	if cfg.PollInterval <= 0 {
		cfg.PollInterval = defaultPollInterval
	}
	if cfg.LeaseDuration <= 0 {
		cfg.LeaseDuration = defaultLeaseDuration
	}
	if cfg.BackoffBase <= 0 {
		cfg.BackoffBase = defaultBackoffBase
	}
	if cfg.BackoffMax <= 0 {
		cfg.BackoffMax = defaultBackoffMax
	}
	if cfg.BackoffMax < cfg.BackoffBase {
		cfg.BackoffMax = cfg.BackoffBase
	}
	if cfg.Jitter < 0 {
		cfg.Jitter = 0
	}
	if cfg.Jitter > 1 {
		cfg.Jitter = 1
	}
	if cfg.Jitter == 0 && !cfg.DisableJitter {
		cfg.Jitter = defaultJitter
	}
	if cfg.Clock == nil {
		cfg.Clock = time.Now
	}
	if cfg.Rand == nil {
		cfg.Rand = rand.New(rand.NewSource(time.Now().UnixNano()))
	}
	if cfg.Logger == nil {
		cfg.Logger = slog.Default()
	}

	kinds := make([]string, 0, len(cfg.Kinds))
	seen := make(map[string]struct{}, len(cfg.Kinds))
	for _, kind := range cfg.Kinds {
		kind = strings.TrimSpace(kind)
		if kind == "" {
			continue
		}
		if _, ok := seen[kind]; ok {
			continue
		}
		seen[kind] = struct{}{}
		kinds = append(kinds, kind)
	}
	cfg.Kinds = kinds

	return &Worker{store: store, cfg: cfg, handlers: make(map[string]Handler)}
}

// Register adds or replaces a handler for a durable job kind.  Kind names are
// bounded to avoid accepting an empty/database-invalid registration.
func (w *Worker) Register(kind string, handler Handler) error {
	kind = strings.TrimSpace(kind)
	if kind == "" {
		return errors.New("job kind is required")
	}
	if handler == nil {
		return errors.New("job handler is required")
	}
	w.mu.Lock()
	w.handlers[kind] = handler
	w.mu.Unlock()
	return nil
}

// RegisterTyped decodes each job's JSON payload into T before calling handler.
// Decode failures become permanent failed jobs, ensuring malformed payloads do
// not spin forever while remaining visible through the queue status.
func RegisterTyped[T any](w *Worker, kind string, handler TypedHandler[T]) error {
	if handler == nil {
		return errors.New("job handler is required")
	}
	return w.Register(kind, HandlerFunc(func(ctx context.Context, job Job) Result {
		var payload T
		if err := json.Unmarshal(job.Payload, &payload); err != nil {
			return Failed(fmt.Errorf("invalid job payload: %w", err))
		}
		return handler(ctx, job, payload)
	}))
}

func (w *Worker) handler(kind string) (Handler, bool) {
	w.mu.RLock()
	h, ok := w.handlers[kind]
	w.mu.RUnlock()
	return h, ok
}

func (w *Worker) handlesKind(kind string) bool {
	if len(w.cfg.Kinds) == 0 {
		return true
	}
	for _, allowed := range w.cfg.Kinds {
		if allowed == kind {
			return true
		}
	}
	return false
}

// Process executes one already-claimed job.  It is exported for queue
// adapters and deterministic tests; normal callers should use Run or Start.
func (w *Worker) Process(ctx context.Context, job Job) error { return w.process(ctx, job) }

func (w *Worker) process(ctx context.Context, job Job) error {
	if ctx == nil {
		ctx = context.Background()
	}
	if w.store == nil {
		return errors.New("job store is required")
	}
	if job.ID == uuid.Nil || job.LeaseToken == uuid.Nil || job.LeaseOwner == nil || *job.LeaseOwner == "" {
		return errors.New("claimed job lease is required")
	}

	handler, ok := w.handler(job.Kind)
	if !ok || !w.handlesKind(job.Kind) {
		// Unknown kinds must not remain leased forever.  Finishing as failed
		// also prevents a dedicated queue from repeatedly stealing the row.
		return w.finish(ctx, job, StatusFailed)
	}

	handlerCtx, cancelHandler := context.WithCancel(ctx)
	heartbeatCtx, stopHeartbeat := context.WithCancel(ctx)
	heartbeatDone := make(chan bool, 1)
	go w.monitorLease(heartbeatCtx, job, cancelHandler, heartbeatDone)
	result := handler.Handle(handlerCtx, job)
	cancelHandler()
	stopHeartbeat()
	if <-heartbeatDone {
		return ErrLeaseLost
	}
	if ctx.Err() != nil {
		// A cancelled handler may return Success after observing cancellation;
		// the worker owns the shutdown boundary and must release the lease.
		result = Cancelled()
	}

	if result.Retry || result.Status == StatusCancelled {
		if job.MaxAttempts > 0 && job.AttemptCount >= job.MaxAttempts {
			return w.finish(ctx, job, StatusFailed)
		}
		delay := w.retryDelay(job.AttemptCount, result.RetryAfter)
		availableAt := w.cfg.Clock().Add(delay)
		cleanupCtx, cleanupCancel := leaseCleanupContext(ctx)
		ok, err := w.store.ReleaseDurableJobLease(cleanupCtx, job.ID, *job.LeaseOwner, job.LeaseToken, availableAt)
		cleanupCancel()
		if err != nil {
			return err
		}
		if !ok {
			return ErrLeaseLost
		}
		return nil
	}

	status := result.Status
	if status == "" {
		if result.Err != nil {
			status = StatusFailed
		} else {
			status = StatusCompleted
		}
	}
	if status != StatusCompleted && status != StatusFailed && status != StatusCancelled {
		status = StatusFailed
	}
	return w.finish(ctx, job, status)
}

// ErrLeaseLost means the row was reclaimed or acknowledged by another
// worker.  It is intentionally distinct from a provider failure.
var ErrLeaseLost = errors.New("durable job lease lost")

const leaseCleanupTimeout = 5 * time.Second

// monitorLease keeps a claimed job's lease alive while its handler runs. A
// failed or stale extension fences the handler before it can acknowledge the
// row with an expired lease.
func (w *Worker) monitorLease(ctx context.Context, job Job, cancelHandler context.CancelFunc, done chan<- bool) {
	lost := false
	interval := w.cfg.LeaseDuration / 3
	if interval <= 0 {
		interval = time.Nanosecond
	}
	ticker := time.NewTicker(interval)
	defer ticker.Stop()
	defer func() { done <- lost }()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			if ctx.Err() != nil {
				return
			}
			owner := ""
			if job.LeaseOwner != nil {
				owner = *job.LeaseOwner
			}
			ok, err := w.store.ExtendDurableJobLease(ctx, job.ID, owner, job.LeaseToken, w.cfg.LeaseDuration)
			if ctx.Err() != nil {
				return
			}
			if err != nil || !ok {
				lost = true
				cancelHandler()
				return
			}
		}
	}
}

// leaseCleanupContext detaches an acknowledgement from handler cancellation
// while preserving context values and bounding the database call.
func leaseCleanupContext(ctx context.Context) (context.Context, context.CancelFunc) {
	if ctx == nil {
		ctx = context.Background()
	}
	return context.WithTimeout(context.WithoutCancel(ctx), leaseCleanupTimeout)
}

func (w *Worker) finish(ctx context.Context, job Job, status string) error {
	owner := ""
	if job.LeaseOwner != nil {
		owner = *job.LeaseOwner
	}
	cleanupCtx, cleanupCancel := leaseCleanupContext(ctx)
	defer cleanupCancel()
	ok, err := w.store.FinishDurableJob(cleanupCtx, job.ID, owner, job.LeaseToken, status)
	if err != nil {
		return err
	}
	if !ok {
		return ErrLeaseLost
	}
	return nil
}

func (w *Worker) retryDelay(attempt int32, override time.Duration) time.Duration {
	if override > 0 {
		if override > w.cfg.BackoffMax {
			return w.cfg.BackoffMax
		}
		return override
	}
	if attempt < 1 {
		attempt = 1
	}
	delay := w.cfg.BackoffBase
	for i := int32(1); i < attempt && delay < w.cfg.BackoffMax; i++ {
		if delay > w.cfg.BackoffMax/2 {
			delay = w.cfg.BackoffMax
			break
		}
		delay *= 2
	}
	if delay > w.cfg.BackoffMax {
		delay = w.cfg.BackoffMax
	}
	if w.cfg.Jitter == 0 {
		return delay
	}
	w.randMu.Lock()
	factor := 1 + ((w.cfg.Rand.Float64()*2)-1)*w.cfg.Jitter
	w.randMu.Unlock()
	withJitter := time.Duration(float64(delay) * factor)
	if withJitter < 0 {
		return 0
	}
	if withJitter > w.cfg.BackoffMax {
		return w.cfg.BackoffMax
	}
	return withJitter
}

// Run polls until ctx is cancelled, then waits for every dispatched handler
// to finish.  It returns ctx.Err() for direct callers; Start records that
// normal lifecycle result so Shutdown can distinguish it from a worker error.
func (w *Worker) Run(ctx context.Context) error {
	if ctx == nil {
		ctx = context.Background()
	}
	if w.store == nil {
		return errors.New("job store is required")
	}
	semaphore := make(chan struct{}, w.cfg.Concurrency)

	for {
		if ctx.Err() != nil {
			w.handlersWG.Wait()
			return ctx.Err()
		}

		available := cap(semaphore) - len(semaphore)
		if available > 0 {
			claimed, err := w.store.ClaimDurableJobsByKinds(ctx, w.cfg.WorkerID, w.cfg.Kinds, available, w.cfg.LeaseDuration)
			if err != nil {
				if ctx.Err() != nil {
					w.handlersWG.Wait()
					return ctx.Err()
				}
				w.cfg.Logger.Warn("durable job claim failed", "worker", w.cfg.WorkerID, "err", safeError(err))
			} else {
				for _, job := range claimed {
					select {
					case semaphore <- struct{}{}:
					case <-ctx.Done():
						_ = w.releaseUnowned(context.Background(), job)
						continue
					}
					w.handlersWG.Add(1)
					go func(job Job) {
						defer w.handlersWG.Done()
						defer func() { <-semaphore }()
						if err := w.process(ctx, job); err != nil && !errors.Is(err, ErrLeaseLost) && ctx.Err() == nil {
							w.cfg.Logger.Warn("durable job processing failed", "worker", w.cfg.WorkerID, "job_id", job.ID, "kind", job.Kind, "err", safeError(err))
						}
					}(job)
				}
			}
		}

		timer := time.NewTimer(w.cfg.PollInterval)
		select {
		case <-ctx.Done():
			if !timer.Stop() {
				<-timer.C
			}
			w.handlersWG.Wait()
			return ctx.Err()
		case <-timer.C:
		}
	}
}

func (w *Worker) releaseUnowned(ctx context.Context, job Job) error {
	if job.LeaseOwner == nil || job.LeaseToken == uuid.Nil {
		return nil
	}
	cleanupCtx, cleanupCancel := leaseCleanupContext(ctx)
	defer cleanupCancel()
	ok, err := w.store.ReleaseDurableJobLease(cleanupCtx, job.ID, *job.LeaseOwner, job.LeaseToken, w.cfg.Clock())
	if err == nil && !ok {
		return ErrLeaseLost
	}
	return err
}

// Start owns the worker goroutine.  Calling Start twice is a no-op; use
// Shutdown to cancel and wait for the started run.
func (w *Worker) Start(ctx context.Context) {
	if ctx == nil {
		ctx = context.Background()
	}
	w.mu.Lock()
	if w.started {
		w.mu.Unlock()
		return
	}
	w.started = true
	w.done = make(chan struct{})
	workerCtx, cancel := context.WithCancel(ctx)
	w.cancel = cancel
	done := w.done
	w.mu.Unlock()
	go func() {
		err := w.Run(workerCtx)
		w.mu.Lock()
		w.runErr = err
		close(done)
		w.mu.Unlock()
	}()
}

// Done returns the completion signal for a started worker.  Before Start it
// returns a closed channel, making select-based callers straightforward.
func (w *Worker) Done() <-chan struct{} {
	w.mu.RLock()
	done := w.done
	started := w.started
	w.mu.RUnlock()
	if started && done != nil {
		return done
	}
	closed := make(chan struct{})
	close(closed)
	return closed
}

// Shutdown requests cancellation and waits for the poller and all handlers.
// If the deadline expires, the caller receives its context error while the
// worker goroutines remain accounted for and will finish eventually.
func (w *Worker) Shutdown(ctx context.Context) error {
	if ctx == nil {
		ctx = context.Background()
	}
	w.mu.RLock()
	cancel := w.cancel
	done := w.done
	started := w.started
	w.mu.RUnlock()
	if !started || cancel == nil || done == nil {
		return nil
	}
	cancel()
	select {
	case <-done:
		w.mu.RLock()
		err := w.runErr
		w.mu.RUnlock()
		if errors.Is(err, context.Canceled) || errors.Is(err, context.DeadlineExceeded) {
			return nil
		}
		return err
	case <-ctx.Done():
		return ctx.Err()
	}
}

// Stop is a convenience alias for an unbounded graceful shutdown.
func (w *Worker) Stop() error { return w.Shutdown(context.Background()) }

func safeError(err error) string {
	if err == nil {
		return ""
	}
	// Provider/database errors can contain addresses, credentials, or token
	// fragments. Emit only an allowlisted diagnostic so an unexpected error
	// cannot turn queue logs into a secret-bearing channel.
	value := strings.ToLower(strings.Join(strings.Fields(err.Error()), " "))
	switch {
	case strings.Contains(value, "deadline"), strings.Contains(value, "timeout"):
		return "timeout"
	case strings.Contains(value, "deadlock"), strings.Contains(value, "serialization"):
		return "database_conflict"
	case strings.Contains(value, "connection"), strings.Contains(value, "unavailable"), strings.Contains(value, "temporary"), strings.Contains(value, "try again"):
		return "transient"
	case strings.Contains(value, "invalid"):
		return "invalid_request"
	default:
		return "worker_error"
	}
}
