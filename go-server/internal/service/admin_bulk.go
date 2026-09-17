package service

import (
	"context"
	"encoding/base64"
	"errors"
	"net/http"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"

	"github.com/lrprojects/monaserver/internal/apperrors"
)

const (
	JobPending            = "pending"
	JobRunning            = "running"
	JobCompleted          = "completed"
	JobCompletedWithError = "completed_with_errors"
	JobPaused             = "paused"
	JobCancelled          = "cancelled"

	OutcomeSkipped          = "skipped"
	OutcomeSecured          = "secured"
	OutcomeQueued           = "queued"
	OutcomeProviderAccepted = "provider_accepted"
	OutcomeFailed           = "failed"
	OutcomeUnknownDelivery  = "unknown_delivery"

	CommandRetry        = "retry"
	CommandCancel       = "cancel"
	maxCommandKey       = 255
	jobCommandMFAAction = "jobs.control"
)

var (
	ErrInvalidJobRequest = apperrors.New(http.StatusBadRequest, "invalid job request")
	ErrJobNotFound       = apperrors.New(http.StatusNotFound, "job was not found")
	ErrJobConflict       = apperrors.New(http.StatusConflict, "job command conflicts with current state")
	ErrJobCancelled      = apperrors.New(http.StatusConflict, "job has been cancelled")
	ErrJobLeaseLost      = apperrors.New(http.StatusConflict, "job item lease was lost")
	ErrActionUnavailable = apperrors.New(http.StatusServiceUnavailable, "action delivery is unavailable")
)

type AdminJob struct {
	ID             uuid.UUID
	ActorID        uuid.UUID
	SnapshotID     uuid.UUID
	Action         AdminAction
	PayloadHash    string
	IdempotencyKey string
	Status         string
	AccountCount   int64
	EligibleCount  int64
	DeviceCount    int64
	CompletedCount int64
	FailedCount    int64
	// UncertainCount is the number of terminal items whose provider delivery
	// result could not be confirmed. They are included in CompletedCount so a
	// job cannot remain running forever after an unknown_delivery outcome.
	UncertainCount        int64
	Reason                string
	CancellationRequested bool
	CreatedAt             time.Time
	UpdatedAt             time.Time
	StartedAt             *time.Time
	CompletedAt           *time.Time
	// RecentMFAAt and RecentMFAAction are the action-bound proof captured at
	// job creation. They are durable execution state: a restarted worker must
	// reconstruct this proof from the job rather than trust a browser session.
	RecentMFAAt     *time.Time
	RecentMFAAction string
}

type AdminJobItem struct {
	ID       uuid.UUID
	JobID    uuid.UUID
	TargetID uuid.UUID
	// OperationID is generated once when the item is committed and is reused
	// for every retry. Credential-producing ports use it as their provider
	// idempotency key.
	OperationID       uuid.UUID
	DeviceID          *uuid.UUID
	Outcome           string
	Reason            string
	ErrorCode         string
	ProviderReference string
	Retryable         bool
	Ambiguous         bool
	AttemptCount      int32
	DeviceCount       int32
	LastAttemptAt     *time.Time
	CompletedAt       *time.Time
	CreatedAt         time.Time
	UpdatedAt         time.Time
	claimed           bool
	queuedForRetry    bool
	leaseToken        string
	leaseFence        int64
	leaseExpiresAt    time.Time
}

type AdminJobPage struct {
	Items []AdminJob
	Next  *string
}

type AdminJobRecipientPage struct {
	Items []AdminJobItem
	Next  *string
}

type AdminJobCreateRequest struct {
	SnapshotID     uuid.UUID
	PayloadHash    string
	Action         AdminAction
	IdempotencyKey string
}

// BulkJobCreateRequest is retained as a descriptive compatibility alias for
// callers that use the bulk-action terminology from the admin contract.
type BulkJobCreateRequest = AdminJobCreateRequest

type AdminJobCommand struct {
	JobID          uuid.UUID
	ActorID        uuid.UUID
	Kind           string
	IdempotencyKey string
	Reason         string
}

// AdminJobStore is the transaction boundary for durable administrative jobs.
// CreateJob must commit the job and all recipient items atomically. Production
// stores must implement FencedAdminJobStore, AdminJobLeaseRenewer,
// AdminJobItemCommitStore, and AdminJobItemAuditStore so claims, operation
// state, retries, audit events, and long-running action calls use a
// lease/fence CAS and one durable item transition. The legacy methods remain
// only as a migration seam for adapters that are not allowed to execute a job.
type AdminJobStore interface {
	CreateJob(context.Context, AdminJob, []AdminJobItem) (*AdminJob, error)
	GetJob(context.Context, uuid.UUID) (*AdminJob, error)
	ListJobs(context.Context, string, int, string, string) (AdminJobPage, error)
	ListJobItems(context.Context, uuid.UUID, string, int) (AdminJobRecipientPage, error)
	ClaimJobItem(context.Context, uuid.UUID, uuid.UUID, string) (*AdminJobItem, bool, error)
	FinishJobItem(context.Context, uuid.UUID, string, string, string, string) (*AdminJobItem, error)
	ApplyJobCommand(context.Context, AdminJobCommand) (*AdminJob, error)
	PauseJob(context.Context, uuid.UUID, string) error
	UpdateJobProgress(context.Context, uuid.UUID) error
}

// AdminJobItemStateStore is retained as a descriptive migration seam. It is
// insufficient for execution because it does not bind the item transition to
// its audit event; executable stores must implement AdminJobItemCommitStore.
type AdminJobItemStateStore interface {
	FinishJobItemWithState(context.Context, uuid.UUID, uuid.UUID, string, string, string, string, bool, bool) (*AdminJobItem, error)
}

// AdminJobLease is the fencing proof returned by a durable item claim. Fence
// is monotonic per item; a stale worker must be rejected even if its lease
// token is replayed after a newer claim.
type AdminJobLease struct {
	Token     string
	Fence     int64
	ExpiresAt time.Time
}

// FencedAdminJobStore is mandatory for execution. Claim and finish must be
// implemented by one transaction (or an equivalent compare-and-set) in the
// production adapter. The service rejects legacy unfenced adapters before an
// item can reach an action port.
type FencedAdminJobStore interface {
	ClaimJobItemWithLease(context.Context, uuid.UUID, uuid.UUID, string, time.Duration) (*AdminJobItem, *AdminJobLease, bool, error)
	FinishJobItemWithLease(context.Context, uuid.UUID, AdminJobLease, uuid.UUID, string, string, string, string, bool, bool) (*AdminJobItem, error)
}

// AdminJobLeaseRenewer is mandatory for execution. An action port can block
// longer than its initial lease, so the worker must renew the same fencing
// proof until every provider/security/report call has returned. A failed
// renewal cancels the action and makes its result terminally uncertain rather
// than allowing another worker to send the same operation.
type AdminJobLeaseRenewer interface {
	RenewJobItemLease(context.Context, uuid.UUID, AdminJobLease, time.Duration) (*AdminJobLease, error)
}

// TerminalUnknownDeliveryStore is a mandatory capability marker for job
// execution. The adapter may return true only when its claim query excludes
// terminal unknown_delivery rows and its progress transition counts them as
// completed/uncertain. Until the production SQL is updated, the service fails
// closed before any provider call.
type TerminalUnknownDeliveryStore interface {
	SupportsTerminalUnknownDelivery() bool
}

// AdminJobItemCommitStore durably finishes an item and records its actor,
// target, operation, and outcome audit event as one transaction. A database
// adapter may implement this with an outbox row, but it must never expose a
// successful item finish before the audit intent is durable. This interface is
// mandatory alongside FencedAdminJobStore for executable jobs.
type AdminJobItemCommitStore interface {
	FinishJobItemWithAudit(context.Context, uuid.UUID, AdminJobLease, uuid.UUID, string, string, string, string, bool, bool, AdminJobItemAudit) (*AdminJobItem, error)
}

// AdminJobLeaseLossCommitStore is the fenced terminal path used after a lease
// renewal failure. It must accept the exact worker token and fence even when
// the wall-clock lease has expired, atomically record unknown_delivery and its
// audit intent, and exclude the item from future claims. A normal finish CAS
// must continue rejecting expired leases; allowing it to acknowledge an
// uncertain provider call would let a stale worker race a reclaiming worker.
type AdminJobLeaseLossCommitStore interface {
	CommitUnknownDeliveryAfterLeaseLoss(context.Context, uuid.UUID, AdminJobLease, uuid.UUID, AdminJobItemAudit) (*AdminJobItem, error)
}

// AdminActorReloader supplies fresh membership, auth-generation, and
// capabilities immediately before each item. A revoked or demoted actor
// causes the service to pause the durable job before another item runs.
type AdminActorReloader interface {
	ReloadAdminActor(context.Context, uuid.UUID) (AdminActor, error)
}

// AdminActorStateLoader is a descriptive compatibility alias for adapters
// that name this fresh-membership lookup a state load.
type AdminActorStateLoader = AdminActorReloader

type AdminJobItemAudit struct {
	JobID       uuid.UUID
	ItemID      uuid.UUID
	OperationID uuid.UUID
	ActorID     uuid.UUID
	TargetID    uuid.UUID
	Action      string
	Outcome     string
	Reason      string
	ErrorCode   string
}

// AdminJobItemAuditStore must append an actor/target/outcome record for every
// durable item transition. A DB implementation should perform this in the
// finish transaction or enqueue an idempotent outbox row keyed by JobID/ItemID.
type AdminJobItemAuditStore interface {
	RecordJobItemAudit(context.Context, AdminJobItemAudit) error
}

// ActionResult is the bounded result of one account/device operation. Error
// codes are classifications only; provider response bodies never cross this
// interface.
type ActionResult struct {
	Outcome           string
	Reason            string
	ErrorCode         string
	ProviderReference string
	DeviceCount       int32
	InvalidDeviceIDs  []uuid.UUID
	Retryable         bool
	// SafeToRetry is an explicit provider classification. A failed item is
	// retried only when this flag is true; transport errors default to an
	// ambiguous outcome for credential-producing actions.
	SafeToRetry bool
	Ambiguous   bool
	// Idempotent is set by the keyed action ports. Credential retries require
	// it in addition to SafeToRetry.
	Idempotent bool
}

type AdminActionExecutor interface {
	Execute(context.Context, AdminAction, uuid.UUID, uuid.UUID, uuid.UUID) (ActionResult, error)
}

// IdempotentAdminActionExecutor is the keyed form for adapters that dispatch
// more than one action family through a single port. Credential-producing
// actions must receive OperationID through this interface.
type IdempotentAdminActionExecutor interface {
	ExecuteWithKey(context.Context, AdminAction, uuid.UUID, uuid.UUID, uuid.UUID, uuid.UUID) (ActionResult, error)
}

// RecipientEligibility is evaluated immediately before an item is sent. A
// preview is an immutable scope, while preferences, email ownership, device
// registration, and account state may only make that scope smaller later.
type RecipientEligibility struct {
	Eligible    bool
	Reason      string
	DeviceCount int32
	IsAdmin     bool
	// Complete proves that the checker evaluated all state needed by the
	// action, including current administrator status. Zero is deliberately
	// incomplete so a partial adapter cannot direct-send.
	Complete bool
}

type RecipientEligibilityChecker interface {
	CheckRecipient(context.Context, uuid.UUID, AdminAction) (RecipientEligibility, error)
}

// InvalidDeviceTokenRemover lets a push adapter retire provider-rejected
// device registrations after ownership has been checked by the adapter. Raw
// tokens never enter this service contract.
type InvalidDeviceTokenRemover interface {
	RemoveInvalidDeviceToken(context.Context, uuid.UUID, uuid.UUID, uuid.UUID) error
}

type SessionRevoker interface {
	RevokeSessions(context.Context, uuid.UUID, uuid.UUID, string) error
}

type AccountCompromiser interface {
	MarkCompromised(context.Context, uuid.UUID, *uuid.UUID, string) (*ContainmentResult, error)
}

type RecoveryResender interface {
	ResendRecovery(context.Context, uuid.UUID, uuid.UUID, string) (ActionResult, error)
}

// IdempotentRecoveryResender is required for durable retry of recovery
// credential delivery. RecoveryResender remains as a compatibility seam for
// adapters that only support one-shot delivery.
type IdempotentRecoveryResender interface {
	ResendRecoveryWithKey(context.Context, uuid.UUID, uuid.UUID, string, uuid.UUID) (ActionResult, error)
}

type CampaignEmailSender interface {
	SendCampaignEmail(context.Context, uuid.UUID, uuid.UUID, AdminAction) (ActionResult, error)
}

type CampaignLoginLinkSender interface {
	SendCampaignLoginLink(context.Context, uuid.UUID, uuid.UUID) (ActionResult, error)
}

// IdempotentCampaignLoginLinkSender is required for durable retry of login
// link delivery. CampaignLoginLinkSender remains a one-shot compatibility
// seam.
type IdempotentCampaignLoginLinkSender interface {
	SendCampaignLoginLinkWithKey(context.Context, uuid.UUID, uuid.UUID, uuid.UUID) (ActionResult, error)
}

type CampaignPushSender interface {
	SendCampaignPush(context.Context, uuid.UUID, uuid.UUID, AdminAction) (ActionResult, error)
}

// AdminTestMessageSender owns the explicit one-account test-message path. It
// shares the same recipient preference, device ownership, rendering, and
// provider result policy as campaign jobs while remaining outside a durable
// bulk audience.
type AdminTestMessageSender interface {
	SendTestMessage(context.Context, uuid.UUID, uuid.UUID, AdminAction) (ActionResult, error)
}

type ReportActioner interface {
	ApplyReportAction(context.Context, uuid.UUID, uuid.UUID, AdminAction) (ActionResult, error)
}

type AdminActionPorts struct {
	Executor            AdminActionExecutor
	Eligibility         RecipientEligibilityChecker
	DeviceRemover       InvalidDeviceTokenRemover
	SessionRevoker      SessionRevoker
	Compromiser         AccountCompromiser
	Recovery            RecoveryResender
	RecoveryIdempotent  IdempotentRecoveryResender
	Email               CampaignEmailSender
	LoginLink           CampaignLoginLinkSender
	LoginLinkIdempotent IdempotentCampaignLoginLinkSender
	Push                CampaignPushSender
	Test                AdminTestMessageSender
	Report              ReportActioner
}

type AdminBulkService struct {
	store         AdminJobStore
	aud           *AdminAudienceService
	ports         AdminActionPorts
	clock         func() time.Time
	worker        string
	maxItems      int
	actorReloader AdminActorReloader
	leaseTTL      time.Duration
}

// NewAdminBulkService accepts the actor reloader as an optional fourth
// argument for compatibility with job-creation callers. Execution is always
// fail-closed until a reloader is supplied, either here or through
// SetActorReloader; there is no stale actor fallback.
func NewAdminBulkService(store AdminJobStore, audience *AdminAudienceService, ports *AdminActionPorts, reloaders ...AdminActorReloader) *AdminBulkService {
	var configured AdminActionPorts
	if ports != nil {
		configured = *ports
	}
	var reloader AdminActorReloader
	if len(reloaders) > 0 {
		reloader = reloaders[0]
	}
	return &AdminBulkService{store: store, aud: audience, ports: configured, clock: time.Now, maxItems: defaultMaterializeLimit, worker: uuid.NewString(), actorReloader: reloader, leaseTTL: 5 * time.Minute}
}

func NewAdminBulkActionService(store AdminJobStore, audience *AdminAudienceService, ports *AdminActionPorts, reloaders ...AdminActorReloader) *AdminBulkService {
	return NewAdminBulkService(store, audience, ports, reloaders...)
}

func (s *AdminBulkService) SetClock(clock func() time.Time) {
	if s != nil && clock != nil {
		s.clock = clock
	}
}

func (s *AdminBulkService) SetWorkerID(worker string) {
	if s != nil && strings.TrimSpace(worker) != "" {
		s.worker = strings.TrimSpace(worker)
	}
}

func (s *AdminBulkService) SetMaxItems(limit int) {
	if s != nil && limit > 0 {
		s.maxItems = limit
	}
}

func (s *AdminBulkService) SetActorReloader(reloader AdminActorReloader) {
	if s != nil {
		s.actorReloader = reloader
	}
}

// requireExecutionSafety rejects adapters that cannot prove fresh authority,
// recheck recipient state, fence and renew an item claim, and durably bind its
// outcome to an audit intent. It is called before every execution entry point,
// before any provider side effect.
func (s *AdminBulkService) requireExecutionSafety(ctx context.Context, job AdminJob) error {
	if s == nil || s.store == nil {
		return ErrAdminRepositoryAbsent
	}
	pause := func(reason string, result error) error {
		_ = s.store.PauseJob(ctx, job.ID, reason)
		return result
	}
	if s.actorReloader == nil {
		return pause("actor_reload_required", ErrAdminRepositoryAbsent)
	}
	if _, ok := s.store.(FencedAdminJobStore); !ok {
		return pause("item_lease_fencing_required", ErrAdminRepositoryAbsent)
	}
	terminalUnknown, ok := s.store.(TerminalUnknownDeliveryStore)
	if !ok || !terminalUnknown.SupportsTerminalUnknownDelivery() {
		return pause("terminal_unknown_delivery_required", ErrAdminRepositoryAbsent)
	}
	if _, ok := s.store.(AdminJobItemCommitStore); !ok {
		return pause("item_audit_commit_required", ErrAdminRepositoryAbsent)
	}
	if _, ok := s.store.(AdminJobLeaseLossCommitStore); !ok {
		return pause("lease_loss_commit_required", ErrAdminRepositoryAbsent)
	}
	if _, ok := s.store.(AdminJobItemAuditStore); !ok {
		return pause("audit_outbox_required", ErrAdminRepositoryAbsent)
	}
	if s.ports.Eligibility == nil {
		return pause("recipient_eligibility_required", ErrAdminRepositoryAbsent)
	}
	if _, ok := s.store.(AdminJobLeaseRenewer); !ok {
		return pause("item_lease_renewal_required", ErrAdminRepositoryAbsent)
	}
	if isCredentialAction(job.Action.Kind) && !s.hasKeyedCredentialPort(job.Action.Kind) {
		return pause("credential_idempotency_required", ErrActionUnavailable)
	}
	return nil
}

func (s *AdminBulkService) hasKeyedCredentialPort(action string) bool {
	if s == nil {
		return false
	}
	if _, ok := s.ports.Executor.(IdempotentAdminActionExecutor); ok {
		return true
	}
	switch action {
	case ActionLoginLink:
		return s.ports.LoginLinkIdempotent != nil
	case ActionRecoveryResend:
		return s.ports.RecoveryIdempotent != nil
	default:
		return true
	}
}

func (s *AdminBulkService) SetLeaseTTL(ttl time.Duration) {
	if s != nil && ttl > 0 {
		s.leaseTTL = ttl
	}
}

func (s *AdminBulkService) now() time.Time {
	if s == nil || s.clock == nil {
		return time.Now().UTC()
	}
	now := s.clock()
	if now.IsZero() {
		return time.Now().UTC()
	}
	return now.UTC()
}

func (s *AdminBulkService) Create(ctx context.Context, actor AdminActor, request AdminJobCreateRequest) (*AdminJob, error) {
	if s == nil || s.store == nil || s.aud == nil {
		return nil, ErrAdminRepositoryAbsent
	}
	if strings.TrimSpace(request.IdempotencyKey) == "" || len([]byte(request.IdempotencyKey)) > maxCommandKey || !validUTF8(request.IdempotencyKey) {
		return nil, ErrInvalidJobRequest
	}
	if err := s.aud.CommitCheck(ctx, actor, request.SnapshotID, request.PayloadHash, request.Action); err != nil {
		return nil, err
	}
	snapshot, err := s.aud.store.GetAudienceSnapshot(ctx, request.SnapshotID)
	if err != nil {
		return nil, err
	}
	if snapshot == nil {
		return nil, ErrSnapshotNotFound
	}
	members, err := s.loadMembers(ctx, *snapshot)
	if err != nil {
		return nil, err
	}
	eligible := make([]AudienceMember, 0, len(members))
	for _, member := range members {
		if member.Eligible {
			eligible = append(eligible, member)
		}
	}
	if len(eligible) == 0 {
		return nil, ErrEmptyAudience
	}
	if len(eligible) > s.maxItems {
		return nil, ErrAudienceTooLarge
	}
	clean, err := request.Action.ValidateAndSanitize()
	if err != nil {
		return nil, err
	}
	now := s.now()
	recentMFAAt := cloneTime(actor.RecentMFAAt)
	recentMFAAction := strings.TrimSpace(actor.RecentMFAAction)
	if recentMFAAt == nil || recentMFAAction == "" {
		recentMFAAt = nil
		recentMFAAction = ""
	}
	job := AdminJob{
		ID: uuid.New(), ActorID: actor.ID, SnapshotID: snapshot.ID, Action: clean, PayloadHash: clean.PayloadHash(),
		IdempotencyKey: strings.TrimSpace(request.IdempotencyKey), Status: JobPending, AccountCount: snapshot.AccountCount,
		EligibleCount: int64(len(eligible)), DeviceCount: snapshot.DeviceCount, Reason: clean.Reason,
		CreatedAt: now, UpdatedAt: now, RecentMFAAt: recentMFAAt, RecentMFAAction: recentMFAAction,
	}
	items := make([]AdminJobItem, 0, len(eligible))
	for _, member := range eligible {
		items = append(items, AdminJobItem{ID: uuid.New(), JobID: job.ID, TargetID: member.ResourceID, OperationID: uuid.New(), Outcome: OutcomeQueued, DeviceCount: int32(maxInt64Local(member.DeviceCount, 0)), CreatedAt: now, UpdatedAt: now})
	}
	created, err := s.store.CreateJob(ctx, job, items)
	if err != nil {
		return nil, err
	}
	if created == nil {
		return nil, ErrJobConflict
	}
	return created, nil
}

func (s *AdminBulkService) loadMembers(ctx context.Context, snapshot AudienceSnapshot) ([]AudienceMember, error) {
	if len(snapshot.Members) > 0 {
		if len(snapshot.Members) > s.maxItems {
			return nil, ErrAudienceTooLarge
		}
		return cloneAudienceMembers(snapshot.Members), nil
	}
	all := make([]AudienceMember, 0)
	var ordinal int64 = -1
	for {
		page, err := s.aud.store.ListAudienceSnapshotMembers(ctx, snapshot.ID, maxPageLimit, ordinal)
		if err != nil {
			return nil, err
		}
		if len(page) == 0 {
			break
		}
		if len(page) > s.maxItems-len(all) {
			return nil, ErrAudienceTooLarge
		}
		all = append(all, page...)
		if len(page) < maxPageLimit {
			break
		}
		ordinal++
		// The DB adapter's page is ordinal ordered. We advance by the number
		// of rows rather than using a client-visible cursor.
		ordinal += int64(len(page)) - 1
	}
	return all, nil
}

func (s *AdminBulkService) Process(ctx context.Context, actor AdminActor, jobID uuid.UUID) error {
	if s == nil || s.store == nil {
		return ErrAdminRepositoryAbsent
	}
	job, effectiveActor, err := s.getExecutableJobAndActor(ctx, actor, jobID)
	if err != nil {
		return err
	}
	cursor := ""
	for {
		page, err := s.store.ListJobItems(ctx, jobID, cursor, maxPageLimit)
		if err != nil {
			return err
		}
		for _, item := range page.Items {
			if err := ctx.Err(); err != nil {
				return err
			}
			if current, getErr := s.store.GetJob(ctx, jobID); getErr == nil && current != nil {
				if current.CancellationRequested || current.Status == JobPaused {
					return nil
				}
			}
			snapshot, _, _, snapshotErr := s.executionSnapshot(ctx, *job, uuid.Nil)
			if snapshotErr != nil {
				return snapshotErr
			}
			currentActor, reloadErr := s.reloadActorForJob(ctx, effectiveActor, *job, snapshot)
			if reloadErr != nil {
				return reloadErr
			}
			if _, err := s.processItemWithJob(ctx, currentActor, *job, item.ID); err != nil {
				if errors.Is(err, ErrAudienceForbidden) || errors.Is(err, ErrAudienceUnauthorized) || errors.Is(err, ErrRecentMFARequired) || errors.Is(err, ErrAdminRepositoryAbsent) || errors.Is(err, ErrJobConflict) {
					return err
				}
			}
		}
		if page.Next == nil {
			break
		}
		cursor = *page.Next
	}
	if current, getErr := s.store.GetJob(ctx, jobID); getErr == nil && current != nil && current.Status == JobPaused {
		return nil
	}
	return s.store.UpdateJobProgress(ctx, jobID)
}

func (s *AdminBulkService) getExecutableJob(ctx context.Context, actor AdminActor, jobID uuid.UUID) (*AdminJob, error) {
	job, _, err := s.getExecutableJobAndActor(ctx, actor, jobID)
	return job, err
}

func (s *AdminBulkService) getExecutableJobAndActor(ctx context.Context, actor AdminActor, jobID uuid.UUID) (*AdminJob, AdminActor, error) {
	if s == nil || s.store == nil {
		return nil, AdminActor{}, ErrAdminRepositoryAbsent
	}
	if !actor.Valid() {
		return nil, AdminActor{}, ErrAudienceUnauthorized
	}
	job, err := s.store.GetJob(ctx, jobID)
	if err != nil {
		return nil, AdminActor{}, err
	}
	if job == nil {
		return nil, AdminActor{}, ErrJobNotFound
	}
	if actor.ID != job.ActorID && !actor.Can("jobs.execute_all") {
		return nil, AdminActor{}, ErrAudienceForbidden
	}
	if job.Status == JobCancelled {
		return nil, AdminActor{}, ErrJobCancelled
	}
	if job.Status == JobPaused && actor.ID == job.ActorID && !actor.Can("jobs.execute_all") {
		return nil, AdminActor{}, ErrJobConflict
	}
	if err := s.requireExecutionSafety(ctx, *job); err != nil {
		return nil, AdminActor{}, err
	}
	snapshot, _, _, snapshotErr := s.executionSnapshot(ctx, *job, uuid.Nil)
	if snapshotErr != nil {
		return nil, AdminActor{}, snapshotErr
	}
	effective, reloadErr := s.reloadActorForJob(ctx, actor, *job, snapshot)
	if reloadErr != nil {
		return nil, AdminActor{}, reloadErr
	}
	return job, effective, nil
}

func (s *AdminBulkService) reloadActorForJob(ctx context.Context, actor AdminActor, job AdminJob, snapshot AudienceSnapshot) (AdminActor, error) {
	if s.actorReloader == nil {
		_ = s.store.PauseJob(ctx, job.ID, "actor_reload_required")
		return AdminActor{}, ErrAdminRepositoryAbsent
	}
	current, err := s.actorReloader.ReloadAdminActor(ctx, actor.ID)
	if err != nil {
		_ = s.store.PauseJob(ctx, job.ID, "actor_reload_unavailable")
		return AdminActor{}, ErrAdminRepositoryAbsent
	}
	if current.ID != actor.ID || current.AuthGeneration != actor.AuthGeneration || !current.Valid() {
		_ = s.store.PauseJob(ctx, job.ID, "actor_membership_revoked")
		if !current.Valid() {
			return AdminActor{}, ErrAudienceUnauthorized
		}
		return AdminActor{}, ErrAudienceForbidden
	}
	if current.ID != job.ActorID && !current.Can("jobs.execute_all") {
		_ = s.store.PauseJob(ctx, job.ID, "actor_capability_revoked")
		return AdminActor{}, ErrAudienceForbidden
	}
	creator := actor.ID == job.ActorID
	// A takeover is an explicit handoff to a separately authenticated operator
	// with jobs.execute_all. Its MFA proof belongs to that operator and is read
	// from the authenticated request; it is never replaced with the creator's
	// durable proof. The reloader still supplies fresh membership and
	// capabilities, while the request carries the session-bound MFA evidence.
	if !creator {
		current.RecentMFAAt = cloneTime(actor.RecentMFAAt)
		current.RecentMFAAction = strings.TrimSpace(actor.RecentMFAAction)
		if !RecentMFAValid(current.RecentMFAAt, s.now(), s.recentMFATTL()) || current.RecentMFAAction != job.Action.Kind {
			_ = s.store.PauseJob(ctx, job.ID, "takeover_mfa_required")
			return AdminActor{}, ErrRecentMFARequired
		}
	} else {
		// For the creator, the proof captured atomically at job creation is the
		// only proof used after a restart. The browser session may no longer
		// carry it, so reconstruct it from durable job state below.
		current.RecentMFAAt = cloneTime(job.RecentMFAAt)
		current.RecentMFAAction = job.RecentMFAAction
	}
	// Security/report jobs and unconstrained account messaging jobs carry an
	// action-bound proof in durable job state. Validate it on every execution
	// attempt so deleting or corrupting that proof cannot silently downgrade
	// the job to a non-MFA action. A takeover may satisfy the check with its own
	// fresh proof below, but it cannot erase the creator proof from the job.
	if jobRequiresRecentMFA(job, snapshot) {
		if job.RecentMFAAt == nil || job.RecentMFAAction != job.Action.Kind {
			_ = s.store.PauseJob(ctx, job.ID, "job_mfa_proof_missing")
			return AdminActor{}, ErrRecentMFARequired
		}
		if !RecentMFAValid(job.RecentMFAAt, s.now(), s.recentMFATTL()) {
			_ = s.store.PauseJob(ctx, job.ID, "job_mfa_proof_expired")
			return AdminActor{}, ErrRecentMFARequired
		}
	}
	recentMFATTL := s.recentMFATTL()
	if jobRequiresRecentMFA(job, snapshot) && !RecentMFAValid(current.RecentMFAAt, s.now(), recentMFATTL) {
		_ = s.store.PauseJob(ctx, job.ID, "job_mfa_proof_expired")
		return AdminActor{}, ErrRecentMFARequired
	}
	if err := actorCanPerform(current, job.Action.Kind, s.now(), recentMFATTL); err != nil {
		reason := "actor_capability_revoked"
		if errors.Is(err, ErrRecentMFARequired) {
			reason = "job_mfa_proof_expired"
		}
		_ = s.store.PauseJob(ctx, job.ID, reason)
		return AdminActor{}, err
	}
	return current, nil
}

func isCampaignMessageAction(action string) bool {
	return action == ActionEmail || action == ActionLoginLink || action == ActionPush
}

func jobRequiresRecentMFA(job AdminJob, snapshot AudienceSnapshot) bool {
	return requiresRecentMFA(job.Action.Kind) ||
		(snapshot.Resource == AudienceAccounts && audienceIsUnconstrained(snapshot.Audience) && isCampaignMessageAction(job.Action.Kind))
}

func (s *AdminBulkService) recentMFATTL() time.Duration {
	if s != nil && s.aud != nil && s.aud.recentMFATTL > 0 {
		return s.aud.recentMFATTL
	}
	return 5 * time.Minute
}

func (s *AdminBulkService) jobMFARequired(ctx context.Context, job AdminJob) (bool, error) {
	if requiresRecentMFA(job.Action.Kind) {
		return true, nil
	}
	if !isCampaignMessageAction(job.Action.Kind) {
		return false, nil
	}
	if s == nil || s.aud == nil || s.aud.store == nil {
		return false, ErrAdminRepositoryAbsent
	}
	snapshot, err := s.aud.store.GetAudienceSnapshot(ctx, job.SnapshotID)
	if err != nil {
		return false, ErrAdminRepositoryAbsent
	}
	if snapshot == nil {
		return false, ErrSnapshotNotFound
	}
	return snapshot.Resource == AudienceAccounts && audienceIsUnconstrained(snapshot.Audience), nil
}

// authorizeJobCommandActor applies the same creator/takeover boundary to
// retry/resume commands that execution uses. The creator may use the durable
// proof captured on the job after a restart. A takeover requires the
// separately authenticated request's own action-bound recent MFA; its proof
// is never substituted with job.RecentMFA*.
func (s *AdminBulkService) authorizeJobCommandActor(ctx context.Context, actor AdminActor, job AdminJob) error {
	creator := actor.ID == job.ActorID
	if !creator && !actor.Can("jobs.control_all") {
		return ErrAudienceForbidden
	}
	required, err := s.jobMFARequired(ctx, job)
	if err != nil {
		return err
	}
	if creator {
		if required && (!RecentMFAValid(job.RecentMFAAt, s.now(), s.recentMFATTL()) || job.RecentMFAAction != job.Action.Kind) {
			return ErrRecentMFARequired
		}
		return nil
	}
	if !RecentMFAValid(actor.RecentMFAAt, s.now(), s.recentMFATTL()) || actor.RecentMFAAction != jobCommandMFAAction {
		return ErrRecentMFARequired
	}
	if required && (job.RecentMFAAt == nil || job.RecentMFAAction != job.Action.Kind) {
		return ErrRecentMFARequired
	}
	return nil
}

func (s *AdminBulkService) ProcessItem(ctx context.Context, actor AdminActor, jobID, itemID uuid.UUID) (*AdminJobItem, error) {
	job, effective, err := s.getExecutableJobAndActor(ctx, actor, jobID)
	if err != nil {
		return nil, err
	}
	return s.processItemWithJob(ctx, effective, *job, itemID)
}

// executionSnapshot validates the immutable job binding before an item is
// claimed. The member is looked up again at execution so a durable adapter
// cannot execute an item that is absent from, or excluded by, its snapshot.
func (s *AdminBulkService) executionSnapshot(ctx context.Context, job AdminJob, targetID uuid.UUID) (AudienceSnapshot, AudienceMember, bool, error) {
	if s == nil {
		return AudienceSnapshot{}, AudienceMember{}, false, ErrAdminRepositoryAbsent
	}
	if s.store == nil || s.aud == nil || s.aud.store == nil {
		if s.store != nil {
			_ = s.store.PauseJob(ctx, job.ID, "snapshot_store_required")
		}
		return AudienceSnapshot{}, AudienceMember{}, false, ErrAdminRepositoryAbsent
	}
	snapshot, err := s.aud.store.GetAudienceSnapshot(ctx, job.SnapshotID)
	if err != nil {
		_ = s.store.PauseJob(ctx, job.ID, "snapshot_lookup_unavailable")
		return AudienceSnapshot{}, AudienceMember{}, false, ErrAdminRepositoryAbsent
	}
	if snapshot == nil {
		_ = s.store.PauseJob(ctx, job.ID, "snapshot_not_found")
		return AudienceSnapshot{}, AudienceMember{}, false, ErrSnapshotNotFound
	}
	clean, cleanErr := job.Action.ValidateAndSanitize()
	if cleanErr != nil || snapshot.ID != job.SnapshotID || snapshot.ActorID != job.ActorID || snapshot.Status != AudienceSnapshotReady || snapshot.Resource != actionResource(clean.Kind) || snapshot.Action.Kind != clean.Kind || !strings.EqualFold(snapshot.PayloadHash, job.PayloadHash) || !strings.EqualFold(snapshot.PayloadHash, clean.PayloadHash()) {
		_ = s.store.PauseJob(ctx, job.ID, "snapshot_binding_invalid")
		return AudienceSnapshot{}, AudienceMember{}, false, ErrSnapshotBinding
	}
	if !snapshot.ExpiresAt.After(s.now()) {
		_ = s.store.PauseJob(ctx, job.ID, "snapshot_expired")
		return AudienceSnapshot{}, AudienceMember{}, false, ErrSnapshotExpired
	}
	if targetID == uuid.Nil {
		return *snapshot, AudienceMember{}, false, nil
	}
	member, found, err := s.executionSnapshotMember(ctx, *snapshot, targetID)
	if err != nil {
		_ = s.store.PauseJob(ctx, job.ID, "snapshot_member_lookup_unavailable")
		return AudienceSnapshot{}, AudienceMember{}, false, ErrAdminRepositoryAbsent
	}
	return *snapshot, member, found, nil
}

func (s *AdminBulkService) executionSnapshotMember(ctx context.Context, snapshot AudienceSnapshot, targetID uuid.UUID) (AudienceMember, bool, error) {
	if targetID == uuid.Nil {
		return AudienceMember{}, false, ErrInvalidJobRequest
	}
	if len(snapshot.Members) > 0 {
		for _, member := range snapshot.Members {
			if member.ResourceID == targetID && member.Resource == snapshot.Resource {
				return member, true, nil
			}
		}
		return AudienceMember{}, false, nil
	}
	var ordinal int64 = -1
	for {
		page, err := s.aud.store.ListAudienceSnapshotMembers(ctx, snapshot.ID, maxPageLimit, ordinal)
		if err != nil {
			return AudienceMember{}, false, err
		}
		for _, member := range page {
			if member.ResourceID == targetID && member.Resource == snapshot.Resource {
				return member, true, nil
			}
		}
		if len(page) < maxPageLimit {
			return AudienceMember{}, false, nil
		}
		ordinal += int64(len(page))
	}
}

func snapshotIncludesAdmins(snapshot AudienceSnapshot) bool {
	return snapshot.Audience.Filter != nil && snapshot.Audience.Filter.IncludeAdmins
}

func (s *AdminBulkService) processItemWithJob(ctx context.Context, actor AdminActor, job AdminJob, itemID uuid.UUID) (*AdminJobItem, error) {
	if itemID == uuid.Nil {
		return nil, ErrInvalidJobRequest
	}
	if err := s.requireExecutionSafety(ctx, job); err != nil {
		return nil, err
	}
	snapshot, snapshotMember, snapshotMemberFound, err := s.executionSnapshot(ctx, job, uuid.Nil)
	if err != nil {
		return nil, err
	}
	var claimed *AdminJobItem
	var lease *AdminJobLease
	var ok bool
	if fenced, supportsFencing := s.store.(FencedAdminJobStore); supportsFencing {
		claimed, lease, ok, err = fenced.ClaimJobItemWithLease(ctx, job.ID, itemID, s.worker, s.leaseTTL)
	} else {
		claimed, ok, err = s.store.ClaimJobItem(ctx, job.ID, itemID, s.worker)
	}
	if err != nil {
		return nil, err
	}
	if !ok {
		cursor := ""
		for {
			page, listErr := s.store.ListJobItems(ctx, job.ID, cursor, maxPageLimit)
			if listErr != nil {
				return nil, listErr
			}
			for _, item := range page.Items {
				if item.ID == itemID {
					return &item, nil
				}
			}
			if page.Next == nil {
				break
			}
			cursor = *page.Next
		}
		return nil, ErrJobNotFound
	}
	if claimed == nil || lease == nil {
		_ = s.store.PauseJob(ctx, job.ID, "item_lease_proof_missing")
		return nil, ErrAdminRepositoryAbsent
	}
	snapshot, snapshotMember, snapshotMemberFound, err = s.executionSnapshot(ctx, job, claimed.TargetID)
	if err != nil {
		return nil, err
	}
	result, executeErr, renewedLease := s.executeWithRenewingLease(ctx, *lease, claimed.ID, func(actionCtx context.Context) (ActionResult, error) {
		eligibility, checkErr := s.ports.Eligibility.CheckRecipient(actionCtx, claimed.TargetID, job.Action)
		if checkErr != nil {
			return ActionResult{Outcome: OutcomeSkipped, Reason: "recipient_eligibility_unavailable"}, nil
		}
		if !eligibility.Complete {
			return ActionResult{Outcome: OutcomeSkipped, Reason: "recipient_eligibility_incomplete", DeviceCount: eligibility.DeviceCount}, nil
		}
		if !snapshotMemberFound || !snapshotMember.Eligible {
			return ActionResult{Outcome: OutcomeSkipped, Reason: "snapshot_recipient_not_eligible", DeviceCount: eligibility.DeviceCount}, nil
		}
		if (snapshotMember.IsAdmin || eligibility.IsAdmin) && (!snapshotIncludesAdmins(snapshot) || !actor.Can("audience.include_admins")) {
			return ActionResult{Outcome: OutcomeSkipped, Reason: "admin_target_requires_ack", DeviceCount: eligibility.DeviceCount}, nil
		}
		if !eligibility.Eligible {
			reason := eligibility.Reason
			if reason == "" {
				reason = "recipient_ineligible"
			}
			return ActionResult{Outcome: OutcomeSkipped, Reason: reason, DeviceCount: eligibility.DeviceCount}, nil
		}
		if err := actionCtx.Err(); err != nil {
			return ActionResult{}, err
		}
		return s.executeActionAndCleanup(actionCtx, job, claimed.TargetID, actor.ID, claimed.OperationID)
	})
	*lease = renewedLease
	credentialAction := isCredentialAction(job.Action.Kind)
	if executeErr != nil {
		if credentialAction {
			if result.SafeToRetry && result.Idempotent && !result.Ambiguous {
				// A keyed provider explicitly classified this failure as safe;
				// the stable operation key makes the retry idempotent.
				result.Outcome = OutcomeFailed
				if result.ErrorCode == "" {
					result.ErrorCode = "credential_delivery_failed"
				}
				result.Retryable = true
			} else {
				// A timeout or transport error may have minted a credential
				// before the response was lost. Preserve that ambiguity.
				result = ActionResult{Outcome: OutcomeUnknownDelivery, ErrorCode: "credential_delivery_uncertain", Ambiguous: true}
			}
		} else if result.SafeToRetry && !result.Ambiguous {
			result.Outcome = OutcomeFailed
			if result.ErrorCode == "" {
				result.ErrorCode = "action_failed"
			}
			result.Retryable = true
		} else if errors.Is(executeErr, ErrActionUnavailable) {
			// No provider call was possible, so no side effect can be
			// duplicated. This is an explicit safe failure classification.
			result = ActionResult{Outcome: OutcomeFailed, ErrorCode: "action_unavailable", Retryable: true, SafeToRetry: true}
		} else {
			result = ActionResult{Outcome: OutcomeUnknownDelivery, ErrorCode: "action_result_uncertain", Ambiguous: true}
		}
	}
	if result.Outcome == "" {
		result.Outcome = OutcomeFailed
	}
	if !validOutcome(result.Outcome) {
		result.Outcome = OutcomeFailed
		result.ErrorCode = "invalid_outcome"
	}
	if credentialAction {
		if result.Outcome == OutcomeUnknownDelivery || result.Ambiguous || (result.Outcome == OutcomeFailed && !(result.SafeToRetry && result.Idempotent)) {
			result.Outcome = OutcomeUnknownDelivery
			if result.ErrorCode == "" {
				result.ErrorCode = "credential_delivery_uncertain"
			}
			result.Retryable = false
			result.Ambiguous = true
		} else if result.Outcome == OutcomeFailed {
			result.Retryable = result.SafeToRetry && result.Idempotent
		}
	}
	if result.Outcome == OutcomeFailed && (!result.Retryable || !result.SafeToRetry) {
		result.Retryable = false
	}
	result.InvalidDeviceIDs = nil
	result.Reason = safeOptionalReason(result.Reason)
	result.ErrorCode = safeErrorCode(result.ErrorCode)
	result.ProviderReference = safeOptionalReason(result.ProviderReference)
	if errors.Is(executeErr, ErrJobLeaseLost) {
		terminalStore, supportsTerminal := s.store.(AdminJobLeaseLossCommitStore)
		pauseAfterLeaseLoss := func(reason string) {
			pauseCtx, pauseCancel := adminLeaseCleanupContext(ctx)
			defer pauseCancel()
			_ = s.store.PauseJob(pauseCtx, job.ID, reason)
		}
		if !supportsTerminal || lease == nil {
			pauseAfterLeaseLoss("lease_loss_commit_required")
			return nil, ErrAdminRepositoryAbsent
		}
		// The ordinary finish CAS deliberately rejects an expired lease. A
		// renewal loss instead uses the exact token/fence to terminalize an
		// uncertain outcome, preventing a reclaiming worker from repeating a
		// side effect. The adapter must commit this state and its audit intent
		// atomically; a failure pauses the job and never falls through to retry.
		leaseLossAudit := AdminJobItemAudit{
			JobID: job.ID, ItemID: claimed.ID, OperationID: claimed.OperationID,
			ActorID: actor.ID, TargetID: claimed.TargetID, Action: job.Action.Kind,
			Outcome: OutcomeUnknownDelivery, Reason: "lease_lost", ErrorCode: "lease_lost",
		}
		commitCtx, commitCancel := adminLeaseCleanupContext(ctx)
		updated, commitErr := terminalStore.CommitUnknownDeliveryAfterLeaseLoss(commitCtx, itemID, *lease, claimed.OperationID, leaseLossAudit)
		commitCancel()
		if commitErr != nil {
			pauseAfterLeaseLoss("lease_loss_commit_unavailable")
			if errors.Is(commitErr, ErrJobConflict) {
				return nil, commitErr
			}
			return nil, ErrAdminRepositoryAbsent
		}
		if updated == nil {
			pauseAfterLeaseLoss("lease_loss_commit_unavailable")
			return nil, ErrAdminRepositoryAbsent
		}
		return updated, ErrJobLeaseLost
	}
	var updated *AdminJobItem
	commitStore, supportsCommit := s.store.(AdminJobItemCommitStore)
	if !supportsCommit || lease == nil {
		_ = s.store.PauseJob(ctx, job.ID, "item_audit_commit_required")
		return nil, ErrAdminRepositoryAbsent
	}
	audit := AdminJobItemAudit{JobID: job.ID, ItemID: claimed.ID, OperationID: claimed.OperationID, ActorID: actor.ID, TargetID: claimed.TargetID, Action: job.Action.Kind, Outcome: result.Outcome, Reason: result.Reason, ErrorCode: result.ErrorCode}
	updated, err = commitStore.FinishJobItemWithAudit(ctx, itemID, *lease, claimed.OperationID, result.Outcome, result.Reason, result.ErrorCode, result.ProviderReference, result.Retryable, result.Ambiguous, audit)
	if err != nil {
		// The provider call may already have happened. Pause until the durable
		// commit/outbox is available; the stable operation key makes recovery
		// safe without minting another credential.
		_ = s.store.PauseJob(ctx, job.ID, "item_audit_commit_unavailable")
		if errors.Is(err, ErrJobConflict) {
			return nil, err
		}
		return nil, ErrAdminRepositoryAbsent
	}
	if updated == nil {
		return nil, ErrJobConflict
	}
	if updated.Outcome == OutcomeSecured && isSecurityAction(job.Action.Kind) && claimed.TargetID == actor.ID {
		// A successful self-containment operation may revoke the actor's
		// authority before the remaining items run. Leave the durable job
		// paused for another authorized operator to resume.
		_ = s.store.PauseJob(ctx, job.ID, "actor_self_contained")
	}
	return updated, executeErr
}

type adminJobLeaseState struct {
	mu    sync.RWMutex
	lease AdminJobLease
}

func (s *adminJobLeaseState) get() AdminJobLease {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.lease
}

func (s *adminJobLeaseState) set(lease AdminJobLease) {
	s.mu.Lock()
	s.lease = lease
	s.mu.Unlock()
}

const adminLeaseCleanupTimeout = 5 * time.Second

// adminLeaseCleanupContext detaches the terminal lease transition from caller
// cancellation while preserving context values. A cancelled request must
// still be able to quarantine an item before a delayed renewal can expose it
// to a reclaiming worker.
func adminLeaseCleanupContext(ctx context.Context) (context.Context, context.CancelFunc) {
	if ctx == nil {
		ctx = context.Background()
	}
	return context.WithTimeout(context.WithoutCancel(ctx), adminLeaseCleanupTimeout)
}

// executeWithRenewingLease keeps the fencing proof alive around eligibility,
// provider, security, report, and invalid-device cleanup calls. If the
// durable store cannot renew, or the parent is cancelled after a claim, the
// action context is cancelled and the caller records an uncertain terminal
// result instead of permitting a reclaiming worker to repeat the side effect.
func (s *AdminBulkService) executeWithRenewingLease(ctx context.Context, lease AdminJobLease, itemID uuid.UUID, fn func(context.Context) (ActionResult, error)) (ActionResult, error, AdminJobLease) {
	renewer, ok := s.store.(AdminJobLeaseRenewer)
	if !ok {
		return ActionResult{}, ErrAdminRepositoryAbsent, lease
	}
	actionCtx, cancel := context.WithCancel(ctx)
	defer cancel()
	state := &adminJobLeaseState{lease: lease}
	renewalErrors := make(chan error, 1)
	done := make(chan struct{})
	interval := s.leaseTTL / 3
	if interval <= 0 {
		interval = time.Millisecond
	}
	go func() {
		defer close(done)
		ticker := time.NewTicker(interval)
		defer ticker.Stop()
		for {
			select {
			case <-actionCtx.Done():
				return
			case <-ticker.C:
				current := state.get()
				next, err := renewer.RenewJobItemLease(actionCtx, itemID, current, s.leaseTTL)
				if err != nil {
					select {
					case renewalErrors <- err:
					default:
					}
					cancel()
					return
				}
				if next == nil {
					select {
					case renewalErrors <- ErrJobLeaseLost:
					default:
					}
					cancel()
					return
				}
				state.set(*next)
			}
		}
	}()
	type actionResult struct {
		result ActionResult
		err    error
	}
	actionResults := make(chan actionResult, 1)
	go func() {
		result, err := fn(actionCtx)
		actionResults <- actionResult{result: result, err: err}
	}()
	select {
	case run := <-actionResults:
		if ctx.Err() != nil {
			cancel()
			// Do not wait for a renewal call that may ignore cancellation; the
			// caller must quarantine the exact claim immediately.
			return run.result, ErrJobLeaseLost, state.get()
		}
		cancel()
		<-done
		select {
		case renewalErr := <-renewalErrors:
			if ctx.Err() == nil && !errors.Is(renewalErr, context.Canceled) {
				return run.result, ErrJobLeaseLost, state.get()
			}
		default:
		}
		return run.result, run.err, state.get()
	case <-renewalErrors:
		cancel()
		<-done
		// Return as soon as the lease is lost. The caller must terminalize the
		// item before expiry so a provider that ignores cancellation cannot leave
		// a reclaim window open. The action goroutine drains through its buffered
		// result channel after this return.
		return ActionResult{}, ErrJobLeaseLost, state.get()
	case <-ctx.Done():
		cancel()
		// The renewal goroutine may be blocked in an adapter that ignores its
		// context. Return without waiting so the exact claim can be quarantined
		// while the terminal path still has its fencing proof.
		return ActionResult{}, ErrJobLeaseLost, state.get()
	}
}

func (s *AdminBulkService) executeActionAndCleanup(ctx context.Context, job AdminJob, targetID, actorID, operationID uuid.UUID) (ActionResult, error) {
	result, err := s.executeAction(ctx, job, targetID, actorID, operationID)
	if ctx.Err() != nil {
		result.InvalidDeviceIDs = nil
		return result, ctx.Err()
	}
	if s.ports.DeviceRemover != nil && len(result.InvalidDeviceIDs) <= 100 {
		for _, deviceID := range result.InvalidDeviceIDs {
			if deviceID != uuid.Nil {
				_ = s.ports.DeviceRemover.RemoveInvalidDeviceToken(ctx, targetID, deviceID, actorID)
			}
		}
	}
	return result, err
}

func isCredentialAction(action string) bool {
	return action == ActionLoginLink || action == ActionRecoveryResend
}

func safeErrorCode(value string) string {
	value = strings.TrimSpace(value)
	if value == "" {
		return ""
	}
	if len([]byte(value)) > 64 || !validUTF8(value) {
		return "provider_error"
	}
	for _, char := range value {
		if (char < 'a' || char > 'z') && (char < 'A' || char > 'Z') && (char < '0' || char > '9') && char != '_' && char != '-' && char != '.' {
			return "provider_error"
		}
	}
	return value
}

func (s *AdminBulkService) executeAction(ctx context.Context, job AdminJob, targetID, actorID, operationID uuid.UUID) (ActionResult, error) {
	if isCredentialAction(job.Action.Kind) && !s.hasKeyedCredentialPort(job.Action.Kind) {
		return ActionResult{}, ErrActionUnavailable
	}
	if keyed, ok := s.ports.Executor.(IdempotentAdminActionExecutor); ok {
		result, err := keyed.ExecuteWithKey(ctx, job.Action, targetID, actorID, job.ID, operationID)
		if isCredentialAction(job.Action.Kind) {
			result.Idempotent = true
		}
		return result, err
	}
	if s.ports.Executor != nil {
		return s.ports.Executor.Execute(ctx, job.Action, targetID, actorID, job.ID)
	}
	switch job.Action.Kind {
	case ActionRevokeSessions:
		if s.ports.SessionRevoker == nil {
			return ActionResult{}, ErrActionUnavailable
		}
		return ActionResult{Outcome: OutcomeSecured}, s.ports.SessionRevoker.RevokeSessions(ctx, targetID, actorID, job.Action.Reason)
	case ActionMarkCompromised:
		if s.ports.Compromiser == nil {
			return ActionResult{}, ErrActionUnavailable
		}
		result, err := s.ports.Compromiser.MarkCompromised(ctx, targetID, &actorID, job.Action.Reason)
		if err != nil {
			return ActionResult{}, err
		}
		if result == nil {
			return ActionResult{Outcome: OutcomeSecured}, nil
		}
		return ActionResult{Outcome: OutcomeSecured, Reason: string(result.Recovery.Status)}, nil
	case ActionRecoveryResend:
		if s.ports.RecoveryIdempotent != nil {
			result, err := s.ports.RecoveryIdempotent.ResendRecoveryWithKey(ctx, targetID, actorID, job.Action.Reason, operationID)
			result.Idempotent = true
			return result, err
		}
		if s.ports.Recovery == nil {
			return ActionResult{}, ErrActionUnavailable
		}
		return s.ports.Recovery.ResendRecovery(ctx, targetID, actorID, job.Action.Reason)
	case ActionEmail:
		if s.ports.Email == nil {
			return ActionResult{}, ErrActionUnavailable
		}
		return s.ports.Email.SendCampaignEmail(ctx, targetID, actorID, job.Action)
	case ActionLoginLink:
		if s.ports.LoginLinkIdempotent != nil {
			result, err := s.ports.LoginLinkIdempotent.SendCampaignLoginLinkWithKey(ctx, targetID, actorID, operationID)
			result.Idempotent = true
			return result, err
		}
		if s.ports.LoginLink == nil {
			return ActionResult{}, ErrActionUnavailable
		}
		return s.ports.LoginLink.SendCampaignLoginLink(ctx, targetID, actorID)
	case ActionPush:
		if s.ports.Push == nil {
			return ActionResult{}, ErrActionUnavailable
		}
		return s.ports.Push.SendCampaignPush(ctx, targetID, actorID, job.Action)
	case ActionReportResolve, ActionReportDismiss:
		if s.ports.Report == nil {
			return ActionResult{}, ErrActionUnavailable
		}
		return s.ports.Report.ApplyReportAction(ctx, targetID, actorID, job.Action)
	default:
		return ActionResult{}, ErrInvalidAdminAction
	}
}

// SendTestMessage sends one explicitly selected test message after checking
// the caller and action family. The operation intentionally accepts exactly
// one target and cannot be used to bypass the audience/job binding rules.
func (s *AdminBulkService) SendTestMessage(ctx context.Context, actor AdminActor, targetID uuid.UUID, action AdminAction) (*ActionResult, error) {
	if s == nil {
		return nil, ErrAdminRepositoryAbsent
	}
	if !actor.Valid() {
		return nil, ErrAudienceUnauthorized
	}
	if !actor.Can("messages.test") {
		return nil, ErrAudienceForbidden
	}
	if targetID == uuid.Nil {
		return nil, ErrInvalidJobRequest
	}
	clean, err := action.ValidateAndSanitize()
	if err != nil {
		return nil, err
	}
	if clean.Kind != ActionEmail && clean.Kind != ActionLoginLink && clean.Kind != ActionPush {
		return nil, ErrInvalidAdminAction
	}
	if s.ports.Eligibility == nil {
		return nil, ErrAdminRepositoryAbsent
	}
	eligibility, eligibilityErr := s.ports.Eligibility.CheckRecipient(ctx, targetID, clean)
	if eligibilityErr != nil || !eligibility.Complete {
		return nil, ErrAdminRepositoryAbsent
	}
	if !eligibility.Eligible {
		reason := eligibility.Reason
		if reason == "" {
			reason = "recipient_ineligible"
		}
		return &ActionResult{Outcome: OutcomeSkipped, Reason: reason, DeviceCount: eligibility.DeviceCount}, nil
	}
	if eligibility.IsAdmin && !actor.Can("audience.include_admins") {
		return &ActionResult{Outcome: OutcomeSkipped, Reason: "admin_target_requires_ack", DeviceCount: eligibility.DeviceCount}, nil
	}
	if s.ports.Test == nil {
		return nil, ErrActionUnavailable
	}
	result, err := s.ports.Test.SendTestMessage(ctx, targetID, actor.ID, clean)
	if err != nil {
		return nil, err
	}
	if result.Outcome == "" {
		result.Outcome = OutcomeFailed
	}
	if !validOutcome(result.Outcome) {
		result.Outcome = OutcomeFailed
		result.ErrorCode = "invalid_outcome"
	}
	result.Reason = safeOptionalReason(result.Reason)
	result.ErrorCode = safeErrorCode(result.ErrorCode)
	result.ProviderReference = safeOptionalReason(result.ProviderReference)
	return &result, nil
}

func (s *AdminBulkService) List(ctx context.Context, actor AdminActor, cursor string, limit int, status, action string) (*AdminJobPage, error) {
	if s == nil || s.store == nil {
		return nil, ErrAdminRepositoryAbsent
	}
	if !actor.Valid() {
		return nil, ErrAudienceUnauthorized
	}
	if !actor.Can("jobs.read") {
		return nil, ErrAudienceForbidden
	}
	limit, err := normalizePage(limit)
	if err != nil {
		return nil, err
	}
	if status != "" && status != JobPending && status != JobRunning && status != JobCompleted && status != JobCompletedWithError && status != JobPaused && status != JobCancelled {
		return nil, ErrInvalidJobRequest
	}
	if action != "" && bulkActionCapability(action) == "" {
		return nil, ErrInvalidJobRequest
	}
	page, err := s.store.ListJobs(ctx, cursor, limit, status, action)
	if err != nil {
		return nil, err
	}
	for i := range page.Items {
		page.Items[i].Action, _ = page.Items[i].Action.ValidateAndSanitize()
	}
	return &page, nil
}

func (s *AdminBulkService) Get(ctx context.Context, actor AdminActor, jobID uuid.UUID) (*AdminJob, error) {
	if s == nil || s.store == nil {
		return nil, ErrAdminRepositoryAbsent
	}
	if !actor.Valid() {
		return nil, ErrAudienceUnauthorized
	}
	if !actor.Can("jobs.read") {
		return nil, ErrAudienceForbidden
	}
	job, err := s.store.GetJob(ctx, jobID)
	if err != nil {
		return nil, err
	}
	if job == nil {
		return nil, ErrJobNotFound
	}
	job.Action, _ = job.Action.ValidateAndSanitize()
	return job, nil
}

func (s *AdminBulkService) Recipients(ctx context.Context, actor AdminActor, jobID uuid.UUID, cursor string, limit int) (*AdminJobRecipientPage, error) {
	if s == nil || s.store == nil {
		return nil, ErrAdminRepositoryAbsent
	}
	if !actor.Valid() {
		return nil, ErrAudienceUnauthorized
	}
	if !actor.Can("jobs.read") {
		return nil, ErrAudienceForbidden
	}
	if _, err := s.Get(ctx, actor, jobID); err != nil {
		return nil, err
	}
	limit, err := normalizePage(limit)
	if err != nil {
		return nil, err
	}
	page, err := s.store.ListJobItems(ctx, jobID, cursor, limit)
	if err != nil {
		return nil, err
	}
	return &page, nil
}

func (s *AdminBulkService) Retry(ctx context.Context, actor AdminActor, command AdminJobCommand) (*AdminJob, error) {
	return s.applyCommand(ctx, actor, command, CommandRetry)
}

func (s *AdminBulkService) Cancel(ctx context.Context, actor AdminActor, command AdminJobCommand) (*AdminJob, error) {
	return s.applyCommand(ctx, actor, command, CommandCancel)
}

func (s *AdminBulkService) applyCommand(ctx context.Context, actor AdminActor, command AdminJobCommand, kind string) (*AdminJob, error) {
	if s == nil || s.store == nil {
		return nil, ErrAdminRepositoryAbsent
	}
	if !actor.Valid() {
		return nil, ErrAudienceUnauthorized
	}
	if !actor.Can("jobs.control") {
		return nil, ErrAudienceForbidden
	}
	if command.JobID == uuid.Nil || strings.TrimSpace(command.IdempotencyKey) == "" || len([]byte(command.IdempotencyKey)) > maxCommandKey || !validUTF8(command.IdempotencyKey) {
		return nil, ErrInvalidJobRequest
	}
	job, err := s.store.GetJob(ctx, command.JobID)
	if err != nil {
		return nil, err
	}
	if job == nil {
		return nil, ErrJobNotFound
	}
	if actor.ID != job.ActorID && !actor.Can("jobs.control_all") {
		return nil, ErrAudienceForbidden
	}
	if command.ActorID == uuid.Nil {
		command.ActorID = actor.ID
	}
	if command.ActorID != actor.ID {
		return nil, ErrAudienceForbidden
	}
	if kind == CommandRetry {
		if err := s.authorizeJobCommandActor(ctx, actor, *job); err != nil {
			return nil, err
		}
	}
	command.Kind = kind
	command.Reason = strings.TrimSpace(command.Reason)
	if len([]byte(command.Reason)) > 2_000 || !validUTF8(command.Reason) {
		return nil, ErrInvalidJobRequest
	}
	updated, err := s.store.ApplyJobCommand(ctx, command)
	if err != nil {
		return nil, err
	}
	if updated == nil {
		return nil, ErrJobConflict
	}
	if kind == CommandCancel {
		if err := s.auditSkippedItems(ctx, *updated, actor.ID); err != nil {
			return updated, err
		}
	}
	return updated, nil
}

func (s *AdminBulkService) auditSkippedItems(ctx context.Context, job AdminJob, actorID uuid.UUID) error {
	auditStore, ok := s.store.(AdminJobItemAuditStore)
	if !ok {
		return ErrAdminRepositoryAbsent
	}
	cursor := ""
	for {
		page, err := s.store.ListJobItems(ctx, job.ID, cursor, maxPageLimit)
		if err != nil {
			return err
		}
		for _, item := range page.Items {
			if item.Outcome != OutcomeSkipped {
				continue
			}
			if err := auditStore.RecordJobItemAudit(ctx, AdminJobItemAudit{JobID: job.ID, ItemID: item.ID, OperationID: item.OperationID, ActorID: actorID, TargetID: item.TargetID, Action: job.Action.Kind, Outcome: item.Outcome, Reason: item.Reason, ErrorCode: item.ErrorCode}); err != nil {
				return err
			}
		}
		if page.Next == nil {
			return nil
		}
		cursor = *page.Next
	}
}

func cloneJob(job AdminJob) AdminJob {
	job.Action, _ = job.Action.ValidateAndSanitize()
	job.RecentMFAAt = cloneTime(job.RecentMFAAt)
	return job
}

func cloneJobItems(items []AdminJobItem) []AdminJobItem {
	return append([]AdminJobItem(nil), items...)
}

func (m *MemoryAdminStore) CreateJob(_ context.Context, job AdminJob, items []AdminJobItem) (*AdminJob, error) {
	if m == nil || job.ID == uuid.Nil || job.ActorID == uuid.Nil || job.SnapshotID == uuid.Nil || job.IdempotencyKey == "" || len(items) == 0 {
		return nil, ErrInvalidJobRequest
	}
	clean, err := job.Action.ValidateAndSanitize()
	if err != nil {
		return nil, err
	}
	job.Action = clean
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.Jobs == nil {
		m.Jobs = make(map[uuid.UUID]AdminJob)
	}
	if m.JobItems == nil {
		m.JobItems = make(map[uuid.UUID][]AdminJobItem)
	}
	for _, existing := range m.Jobs {
		if existing.IdempotencyKey == job.IdempotencyKey {
			if existing.ActorID != job.ActorID || existing.SnapshotID != job.SnapshotID || existing.PayloadHash != job.PayloadHash || existing.Action.Kind != job.Action.Kind || !optionalTimeEqual(existing.RecentMFAAt, job.RecentMFAAt) || existing.RecentMFAAction != job.RecentMFAAction {
				return nil, ErrJobConflict
			}
			copy := cloneJob(existing)
			return &copy, nil
		}
	}
	job.CreatedAt = nonZeroTime(job.CreatedAt)
	job.UpdatedAt = nonZeroTime(job.UpdatedAt)
	if job.Status == "" {
		job.Status = JobPending
	}
	operationIDs := make(map[uuid.UUID]struct{}, len(items))
	for i := range items {
		if items[i].ID == uuid.Nil || items[i].JobID != job.ID || items[i].TargetID == uuid.Nil {
			return nil, ErrInvalidJobRequest
		}
		if items[i].OperationID == uuid.Nil {
			items[i].OperationID = uuid.New()
		}
		if _, exists := operationIDs[items[i].OperationID]; exists {
			return nil, ErrInvalidJobRequest
		}
		operationIDs[items[i].OperationID] = struct{}{}
		items[i].Outcome = OutcomeQueued
		items[i].CreatedAt = nonZeroTime(items[i].CreatedAt)
		items[i].UpdatedAt = nonZeroTime(items[i].UpdatedAt)
	}
	m.Jobs[job.ID] = cloneJob(job)
	m.JobItems[job.ID] = cloneJobItems(items)
	copy := cloneJob(job)
	return &copy, nil
}

func nonZeroTime(value time.Time) time.Time {
	if value.IsZero() {
		return time.Now().UTC()
	}
	return value
}

func optionalTimeEqual(a, b *time.Time) bool {
	if a == nil || b == nil {
		return a == nil && b == nil
	}
	return a.Equal(*b)
}

func (m *MemoryAdminStore) GetJob(_ context.Context, id uuid.UUID) (*AdminJob, error) {
	if m == nil {
		return nil, ErrAdminRepositoryAbsent
	}
	m.mu.RLock()
	defer m.mu.RUnlock()
	job, ok := m.Jobs[id]
	if !ok {
		return nil, nil
	}
	copy := cloneJob(job)
	return &copy, nil
}

func (m *MemoryAdminStore) ListJobs(_ context.Context, cursor string, limit int, status, action string) (AdminJobPage, error) {
	if m == nil {
		return AdminJobPage{}, ErrAdminRepositoryAbsent
	}
	if limit <= 0 || limit > maxPageLimit {
		return AdminJobPage{}, ErrInvalidJobRequest
	}
	var after uuid.UUID
	if cursor != "" {
		var err error
		after, err = decodeJobCursor(cursor)
		if err != nil {
			return AdminJobPage{}, err
		}
	}
	m.mu.RLock()
	jobs := make([]AdminJob, 0, len(m.Jobs))
	for _, job := range m.Jobs {
		if (status == "" || job.Status == status) && (action == "" || job.Action.Kind == action) {
			jobs = append(jobs, cloneJob(job))
		}
	}
	m.mu.RUnlock()
	sort.Slice(jobs, func(i, j int) bool {
		if jobs[i].CreatedAt.Equal(jobs[j].CreatedAt) {
			return jobs[i].ID.String() > jobs[j].ID.String()
		}
		return jobs[i].CreatedAt.After(jobs[j].CreatedAt)
	})
	filtered := jobs[:0]
	seen := after == uuid.Nil
	for _, job := range jobs {
		if !seen {
			if job.ID == after {
				seen = true
			}
			continue
		}
		filtered = append(filtered, job)
	}
	page := AdminJobPage{Items: append([]AdminJob(nil), filtered...)}
	if len(page.Items) > limit {
		page.Items = page.Items[:limit]
		value := encodeJobCursor(page.Items[len(page.Items)-1].ID)
		page.Next = &value
	}
	return page, nil
}

func encodeJobCursor(id uuid.UUID) string {
	return encodeOpaqueCursor("j", id)
}

func decodeJobCursor(cursor string) (uuid.UUID, error) {
	return decodeOpaqueCursor("j", cursor, ErrInvalidJobRequest)
}

func encodeOpaqueCursor(prefix string, id uuid.UUID) string {
	return base64.RawURLEncoding.EncodeToString([]byte(prefix + ":" + id.String()))
}

func decodeOpaqueCursor(prefix, cursor string, invalid error) (uuid.UUID, error) {
	b, err := base64.RawURLEncoding.DecodeString(cursor)
	if err != nil || !strings.HasPrefix(string(b), prefix+":") {
		return uuid.Nil, invalid
	}
	id, err := uuid.Parse(strings.TrimPrefix(string(b), prefix+":"))
	if err != nil || id == uuid.Nil {
		return uuid.Nil, invalid
	}
	return id, nil
}

func (m *MemoryAdminStore) ListJobItems(_ context.Context, jobID uuid.UUID, cursor string, limit int) (AdminJobRecipientPage, error) {
	if m == nil {
		return AdminJobRecipientPage{}, ErrAdminRepositoryAbsent
	}
	if limit <= 0 || limit > maxPageLimit {
		return AdminJobRecipientPage{}, ErrInvalidJobRequest
	}
	var after uuid.UUID
	if cursor != "" {
		var err error
		after, err = decodeOpaqueCursor("i", cursor, ErrInvalidJobRequest)
		if err != nil {
			return AdminJobRecipientPage{}, err
		}
	}
	m.mu.RLock()
	items, ok := m.JobItems[jobID]
	items = cloneJobItems(items)
	m.mu.RUnlock()
	if !ok {
		return AdminJobRecipientPage{}, ErrJobNotFound
	}
	sort.Slice(items, func(i, j int) bool {
		if items[i].CreatedAt.Equal(items[j].CreatedAt) {
			return items[i].ID.String() < items[j].ID.String()
		}
		return items[i].CreatedAt.Before(items[j].CreatedAt)
	})
	filtered := make([]AdminJobItem, 0, len(items))
	seen := after == uuid.Nil
	for _, item := range items {
		if !seen {
			if item.ID == after {
				seen = true
			}
			continue
		}
		filtered = append(filtered, item)
	}
	page := AdminJobRecipientPage{Items: append([]AdminJobItem(nil), filtered...)}
	if len(page.Items) > limit {
		page.Items = page.Items[:limit]
		value := encodeOpaqueCursor("i", page.Items[len(page.Items)-1].ID)
		page.Next = &value
	}
	return page, nil
}

func (m *MemoryAdminStore) ClaimJobItem(_ context.Context, jobID, itemID uuid.UUID, _ string) (*AdminJobItem, bool, error) {
	if m == nil {
		return nil, false, ErrAdminRepositoryAbsent
	}
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.claimJobItemLocked(jobID, itemID, false, "", 0)
}

func (m *MemoryAdminStore) ClaimJobItemWithLease(_ context.Context, jobID, itemID uuid.UUID, _ string, ttl time.Duration) (*AdminJobItem, *AdminJobLease, bool, error) {
	if m == nil {
		return nil, nil, false, ErrAdminRepositoryAbsent
	}
	if ttl <= 0 {
		ttl = 5 * time.Minute
	}
	m.mu.Lock()
	defer m.mu.Unlock()
	item, ok, err := m.claimJobItemLocked(jobID, itemID, true, "", ttl)
	if err != nil || !ok {
		return item, nil, ok, err
	}
	lease := &AdminJobLease{Token: item.leaseToken, Fence: item.leaseFence, ExpiresAt: item.leaseExpiresAt}
	return item, lease, true, nil
}

// RenewJobItemLease extends the current fencing proof without changing its
// token or fence. A stale worker or an expired lease cannot renew and therefore
// cannot keep an action alive after another worker has reclaimed the item.
func (m *MemoryAdminStore) RenewJobItemLease(ctx context.Context, itemID uuid.UUID, lease AdminJobLease, ttl time.Duration) (*AdminJobLease, error) {
	if m == nil {
		return nil, ErrAdminRepositoryAbsent
	}
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	if ttl <= 0 {
		ttl = 5 * time.Minute
	}
	m.mu.Lock()
	defer m.mu.Unlock()
	for _, items := range m.JobItems {
		for i := range items {
			item := &items[i]
			if item.ID != itemID {
				continue
			}
			if !item.claimed || item.leaseToken == "" || item.leaseToken != lease.Token || item.leaseFence != lease.Fence || (!item.leaseExpiresAt.IsZero() && !time.Now().UTC().Before(item.leaseExpiresAt)) {
				return nil, ErrJobConflict
			}
			now := time.Now().UTC()
			item.leaseExpiresAt = now.Add(ttl)
			item.UpdatedAt = now
			next := AdminJobLease{Token: item.leaseToken, Fence: item.leaseFence, ExpiresAt: item.leaseExpiresAt}
			return &next, nil
		}
	}
	return nil, ErrJobNotFound
}

func (m *MemoryAdminStore) claimJobItemLocked(jobID, itemID uuid.UUID, fenced bool, _ string, ttl time.Duration) (*AdminJobItem, bool, error) {
	if job, exists := m.Jobs[jobID]; !exists {
		return nil, false, ErrJobNotFound
	} else if job.Status == JobCancelled || job.CancellationRequested {
		if items, ok := m.JobItems[jobID]; ok {
			for i := range items {
				if items[i].ID == itemID {
					copy := items[i]
					return &copy, false, nil
				}
			}
		}
		return nil, false, ErrJobCancelled
	} else if job.Status == JobPaused {
		if items, ok := m.JobItems[jobID]; ok {
			for i := range items {
				if items[i].ID == itemID {
					copy := items[i]
					return &copy, false, nil
				}
			}
		}
		return nil, false, ErrJobConflict
	}
	items, ok := m.JobItems[jobID]
	if !ok {
		return nil, false, ErrJobNotFound
	}
	for i := range items {
		item := &items[i]
		if item.ID != itemID {
			continue
		}
		expiredLease := false
		if item.claimed {
			if !fenced || item.leaseExpiresAt.IsZero() || time.Now().UTC().Before(item.leaseExpiresAt) {
				copy := *item
				return &copy, false, nil
			}
			item.claimed = false
			item.leaseToken = ""
			expiredLease = true
		}
		// A freshly materialized queued item has no attempts. Once a provider
		// accepts it, OutcomeQueued is terminal for this item; replaying the
		// request must return the stored result instead of sending again.
		if item.claimed || (!expiredLease && item.Outcome == OutcomeQueued && item.AttemptCount > 0 && !item.queuedForRetry) || (item.Outcome != OutcomeQueued && item.Outcome != OutcomeFailed && item.Outcome != OutcomeUnknownDelivery) || (item.Outcome == OutcomeFailed && !item.queuedForRetry) || item.Outcome == OutcomeUnknownDelivery {
			copy := *item
			return &copy, false, nil
		}
		item.claimed = true
		item.queuedForRetry = false
		item.AttemptCount++
		now := time.Now().UTC()
		item.LastAttemptAt = &now
		item.UpdatedAt = now
		if item.OperationID == uuid.Nil {
			item.OperationID = uuid.New()
		}
		if fenced {
			item.leaseFence++
			item.leaseToken = uuid.NewString()
			item.leaseExpiresAt = now.Add(ttl)
		}
		copy := *item
		return &copy, true, nil
	}
	return nil, false, ErrJobNotFound
}

func (m *MemoryAdminStore) FinishJobItem(_ context.Context, itemID uuid.UUID, outcome, reason, errorCode, providerReference string) (*AdminJobItem, error) {
	return m.finishJobItem(itemID, uuid.Nil, nil, outcome, reason, errorCode, providerReference, false, false, false, nil)
}

func (m *MemoryAdminStore) FinishJobItemWithState(_ context.Context, itemID, operationID uuid.UUID, outcome, reason, errorCode, providerReference string, retryable, ambiguous bool) (*AdminJobItem, error) {
	return m.finishJobItem(itemID, operationID, nil, outcome, reason, errorCode, providerReference, retryable, ambiguous, true, nil)
}

func (m *MemoryAdminStore) FinishJobItemWithLease(_ context.Context, itemID uuid.UUID, lease AdminJobLease, operationID uuid.UUID, outcome, reason, errorCode, providerReference string, retryable, ambiguous bool) (*AdminJobItem, error) {
	return m.finishJobItem(itemID, operationID, &lease, outcome, reason, errorCode, providerReference, retryable, ambiguous, true, nil)
}

// FinishJobItemWithAudit atomically persists the fenced item outcome and its
// audit/outbox intent under the same store lock. The production DB adapter
// should provide the same transaction boundary.
func (m *MemoryAdminStore) FinishJobItemWithAudit(_ context.Context, itemID uuid.UUID, lease AdminJobLease, operationID uuid.UUID, outcome, reason, errorCode, providerReference string, retryable, ambiguous bool, audit AdminJobItemAudit) (*AdminJobItem, error) {
	return m.finishJobItem(itemID, operationID, &lease, outcome, reason, errorCode, providerReference, retryable, ambiguous, true, &audit)
}

// CommitUnknownDeliveryAfterLeaseLoss is the in-memory implementation of the
// lease-loss terminal boundary. It validates the exact token and monotonic
// fence but intentionally ignores lease expiry: once renewal has been lost,
// the worker still owns the only proof that can safely quarantine the item.
// A different fence, a completed item, or an unclaimed item is a conflict and
// can never be converted into an uncertain outcome by a stale worker.
func (m *MemoryAdminStore) CommitUnknownDeliveryAfterLeaseLoss(_ context.Context, itemID uuid.UUID, lease AdminJobLease, operationID uuid.UUID, audit AdminJobItemAudit) (*AdminJobItem, error) {
	if m == nil {
		return nil, ErrAdminRepositoryAbsent
	}
	if itemID == uuid.Nil || operationID == uuid.Nil || lease.Token == "" || lease.Fence <= 0 || audit.Outcome != OutcomeUnknownDelivery {
		return nil, ErrJobConflict
	}
	m.mu.Lock()
	defer m.mu.Unlock()
	for jobID, items := range m.JobItems {
		for i := range items {
			item := &items[i]
			if item.ID != itemID {
				continue
			}
			if item.Outcome == OutcomeUnknownDelivery && !item.claimed && item.CompletedAt != nil {
				if item.OperationID != operationID || audit.JobID != jobID || audit.ItemID != item.ID || audit.OperationID != item.OperationID || audit.TargetID != item.TargetID {
					return nil, ErrJobConflict
				}
				return cloneJobItem(item), nil
			}
			if !item.claimed || item.leaseToken != lease.Token || item.leaseFence != lease.Fence || item.OperationID != operationID {
				return nil, ErrJobConflict
			}
			if audit.JobID != jobID || audit.ItemID != item.ID || audit.OperationID != item.OperationID || audit.TargetID != item.TargetID || audit.Action == "" {
				return nil, ErrJobConflict
			}
			if err := validateJobItemAudit(audit); err != nil {
				return nil, err
			}
			if err := m.recordJobItemAuditLocked(audit); err != nil {
				return nil, err
			}
			now := time.Now().UTC()
			item.Outcome = OutcomeUnknownDelivery
			item.Reason = "lease_lost"
			item.ErrorCode = "lease_lost"
			item.ProviderReference = ""
			item.Retryable = false
			item.Ambiguous = true
			item.claimed = false
			item.queuedForRetry = false
			item.leaseToken = ""
			item.leaseExpiresAt = time.Time{}
			item.CompletedAt = &now
			item.UpdatedAt = now
			m.JobItems[jobID] = items
			return cloneJobItem(item), nil
		}
	}
	return nil, ErrJobNotFound
}

func (m *MemoryAdminStore) finishJobItem(itemID, operationID uuid.UUID, lease *AdminJobLease, outcome, reason, errorCode, providerReference string, retryable, ambiguous, setRetryState bool, audit *AdminJobItemAudit) (*AdminJobItem, error) {
	if m == nil {
		return nil, ErrAdminRepositoryAbsent
	}
	if !validOutcome(outcome) {
		return nil, ErrInvalidJobRequest
	}
	m.mu.Lock()
	defer m.mu.Unlock()
	for jobID, items := range m.JobItems {
		for i := range items {
			item := &items[i]
			if item.ID != itemID {
				continue
			}
			if lease != nil && (!item.claimed || item.leaseToken == "" || item.leaseToken != lease.Token || item.leaseFence != lease.Fence || (!item.leaseExpiresAt.IsZero() && time.Now().UTC().After(item.leaseExpiresAt))) {
				// A fenced finish is an acknowledgement by the currently
				// claimed worker. Once another worker has completed the item,
				// the old lease must remain a conflict rather than becoming an
				// idempotent success.
				return nil, ErrJobConflict
			}
			if !item.claimed {
				copy := *item
				return &copy, nil
			}
			if operationID != uuid.Nil && item.OperationID != operationID {
				return nil, ErrJobConflict
			}
			if audit != nil {
				if audit.JobID != jobID || audit.ItemID != item.ID || audit.OperationID != item.OperationID || audit.TargetID != item.TargetID || audit.Outcome != outcome {
					return nil, ErrJobConflict
				}
				if auditErr := validateJobItemAudit(*audit); auditErr != nil {
					return nil, auditErr
				}
				if auditErr := m.recordJobItemAuditLocked(*audit); auditErr != nil {
					return nil, auditErr
				}
			}
			item.Outcome, item.Reason, item.ErrorCode, item.ProviderReference = outcome, safeOptionalReason(reason), safeOptionalReason(errorCode), safeOptionalReason(providerReference)
			if setRetryState {
				item.Retryable, item.Ambiguous = retryable, ambiguous
			}
			item.DeviceCount = maxInt32(item.DeviceCount, 0)
			item.claimed = false
			item.leaseToken = ""
			item.leaseExpiresAt = time.Time{}
			now := time.Now().UTC()
			item.UpdatedAt = now
			// Unknown delivery is terminal for scheduling even though its
			// uncertainty is retained in the outcome and job counters.
			item.CompletedAt = &now
			m.JobItems[jobID] = items
			return cloneJobItem(item), nil
		}
	}
	return nil, ErrJobNotFound
}

func cloneJobItem(item *AdminJobItem) *AdminJobItem {
	if item == nil {
		return nil
	}
	copy := *item
	return &copy
}

func maxInt32(value, minimum int32) int32 {
	if value < minimum {
		return minimum
	}
	return value
}

func validOutcome(value string) bool {
	switch value {
	case OutcomeSkipped, OutcomeSecured, OutcomeQueued, OutcomeProviderAccepted, OutcomeFailed, OutcomeUnknownDelivery:
		return true
	default:
		return false
	}
}

func (m *MemoryAdminStore) UpdateJobProgress(_ context.Context, jobID uuid.UUID) error {
	if m == nil {
		return ErrAdminRepositoryAbsent
	}
	m.mu.Lock()
	defer m.mu.Unlock()
	job, ok := m.Jobs[jobID]
	if !ok {
		return ErrJobNotFound
	}
	items := m.JobItems[jobID]
	var completed, failed, uncertain, pending int64
	for _, item := range items {
		switch item.Outcome {
		case OutcomeQueued:
			if item.CompletedAt == nil {
				pending++
			} else {
				completed++
			}
		case OutcomeUnknownDelivery:
			// Unknown delivery is terminal from the job scheduler's point of
			// view. It remains visible as uncertain for operator follow-up but
			// must not keep the job running indefinitely.
			completed++
			uncertain++
		case OutcomeFailed:
			failed++
		default:
			completed++
		}
	}
	job.CompletedCount, job.FailedCount, job.UncertainCount = completed, failed, uncertain
	if job.CancellationRequested {
		job.Status = JobCancelled
	} else if pending > 0 {
		job.Status = JobRunning
	} else if failed > 0 || uncertain > 0 {
		job.Status = JobCompletedWithError
	} else {
		job.Status = JobCompleted
	}
	now := time.Now().UTC()
	job.UpdatedAt = now
	if job.StartedAt == nil {
		job.StartedAt = &now
	}
	if pending == 0 {
		job.CompletedAt = &now
	}
	m.Jobs[jobID] = job
	return nil
}

func (m *MemoryAdminStore) PauseJob(_ context.Context, jobID uuid.UUID, _ string) error {
	if m == nil {
		return ErrAdminRepositoryAbsent
	}
	m.mu.Lock()
	defer m.mu.Unlock()
	job, ok := m.Jobs[jobID]
	if !ok {
		return ErrJobNotFound
	}
	job.Status = JobPaused
	job.UpdatedAt = time.Now().UTC()
	m.Jobs[jobID] = job
	return nil
}

func (m *MemoryAdminStore) ApplyJobCommand(_ context.Context, command AdminJobCommand) (*AdminJob, error) {
	if m == nil {
		return nil, ErrAdminRepositoryAbsent
	}
	if command.JobID == uuid.Nil || command.Kind == "" || command.IdempotencyKey == "" {
		return nil, ErrInvalidJobRequest
	}
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.Commands == nil {
		m.Commands = make(map[string]AdminJobCommand)
	}
	if previous, ok := m.Commands[command.IdempotencyKey]; ok {
		if previous.JobID != command.JobID || previous.Kind != command.Kind || previous.Reason != command.Reason || previous.ActorID != command.ActorID {
			return nil, ErrJobConflict
		}
		job := m.Jobs[command.JobID]
		copy := cloneJob(job)
		return &copy, nil
	}
	job, ok := m.Jobs[command.JobID]
	if !ok {
		return nil, ErrJobNotFound
	}
	switch command.Kind {
	case CommandRetry:
		if job.Status == JobCancelled {
			return nil, ErrJobConflict
		}
		items := m.JobItems[command.JobID]
		retried := false
		for i := range items {
			if items[i].Outcome == OutcomeFailed && items[i].Retryable && !items[i].Ambiguous {
				items[i].Outcome, items[i].Reason, items[i].ErrorCode = OutcomeQueued, "", ""
				items[i].Retryable, items[i].Ambiguous = false, false
				items[i].claimed = false
				items[i].queuedForRetry = true
				retried = true
			}
		}
		if !retried {
			return nil, ErrJobConflict
		}
		m.JobItems[command.JobID] = items
		job.Status, job.CancellationRequested = JobPending, false
	case CommandCancel:
		if job.Status == JobCompleted || job.Status == JobCompletedWithError || job.Status == JobCancelled {
			// Idempotent cancellation of a terminal job returns its current
			// state; it never restores credentials or unsends delivery.
		} else {
			job.CancellationRequested = true
			job.Status = JobCancelled
			items := m.JobItems[command.JobID]
			for i := range items {
				if items[i].Outcome == OutcomeQueued && items[i].AttemptCount == 0 {
					items[i].Outcome, items[i].Reason = OutcomeSkipped, "cancelled"
				}
			}
			m.JobItems[command.JobID] = items
		}
	default:
		return nil, ErrInvalidJobRequest
	}
	job.UpdatedAt = time.Now().UTC()
	m.Jobs[command.JobID] = job
	m.Commands[command.IdempotencyKey] = command
	copy := cloneJob(job)
	return &copy, nil
}
