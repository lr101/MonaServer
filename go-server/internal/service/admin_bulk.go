package service

import (
	"context"
	"encoding/base64"
	"errors"
	"net/http"
	"sort"
	"strings"
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

	CommandRetry  = "retry"
	CommandCancel = "cancel"
	maxCommandKey = 255
)

var (
	ErrInvalidJobRequest = apperrors.New(http.StatusBadRequest, "invalid job request")
	ErrJobNotFound       = apperrors.New(http.StatusNotFound, "job was not found")
	ErrJobConflict       = apperrors.New(http.StatusConflict, "job command conflicts with current state")
	ErrJobCancelled      = apperrors.New(http.StatusConflict, "job has been cancelled")
	ErrActionUnavailable = apperrors.New(http.StatusServiceUnavailable, "action delivery is unavailable")
)

type AdminJob struct {
	ID                    uuid.UUID
	ActorID               uuid.UUID
	SnapshotID            uuid.UUID
	Action                AdminAction
	PayloadHash           string
	IdempotencyKey        string
	Status                string
	AccountCount          int64
	EligibleCount         int64
	DeviceCount           int64
	CompletedCount        int64
	FailedCount           int64
	Reason                string
	CancellationRequested bool
	CreatedAt             time.Time
	UpdatedAt             time.Time
	StartedAt             *time.Time
	CompletedAt           *time.Time
}

type AdminJobItem struct {
	ID                uuid.UUID
	JobID             uuid.UUID
	TargetID          uuid.UUID
	DeviceID          *uuid.UUID
	Outcome           string
	Reason            string
	ErrorCode         string
	ProviderReference string
	AttemptCount      int32
	DeviceCount       int32
	LastAttemptAt     *time.Time
	CompletedAt       *time.Time
	CreatedAt         time.Time
	UpdatedAt         time.Time
	claimed           bool
	queuedForRetry    bool
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
// CreateJob must commit the job and all recipient items atomically. Claim and
// Finish must use a lease or equivalent compare-and-set so stale workers
// cannot acknowledge another worker's item.
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
}

type AdminActionExecutor interface {
	Execute(context.Context, AdminAction, uuid.UUID, uuid.UUID, uuid.UUID) (ActionResult, error)
}

// RecipientEligibility is evaluated immediately before an item is sent. A
// preview is an immutable scope, while preferences, email ownership, device
// registration, and account state may only make that scope smaller later.
type RecipientEligibility struct {
	Eligible    bool
	Reason      string
	DeviceCount int32
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

type CampaignEmailSender interface {
	SendCampaignEmail(context.Context, uuid.UUID, uuid.UUID, AdminAction) (ActionResult, error)
}

type CampaignLoginLinkSender interface {
	SendCampaignLoginLink(context.Context, uuid.UUID, uuid.UUID) (ActionResult, error)
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
	Executor       AdminActionExecutor
	Eligibility    RecipientEligibilityChecker
	DeviceRemover  InvalidDeviceTokenRemover
	SessionRevoker SessionRevoker
	Compromiser    AccountCompromiser
	Recovery       RecoveryResender
	Email          CampaignEmailSender
	LoginLink      CampaignLoginLinkSender
	Push           CampaignPushSender
	Test           AdminTestMessageSender
	Report         ReportActioner
}

type AdminBulkService struct {
	store    AdminJobStore
	aud      *AdminAudienceService
	ports    AdminActionPorts
	clock    func() time.Time
	worker   string
	maxItems int
}

func NewAdminBulkService(store AdminJobStore, audience *AdminAudienceService, ports *AdminActionPorts) *AdminBulkService {
	var configured AdminActionPorts
	if ports != nil {
		configured = *ports
	}
	return &AdminBulkService{store: store, aud: audience, ports: configured, clock: time.Now, maxItems: defaultMaterializeLimit, worker: uuid.NewString()}
}

func NewAdminBulkActionService(store AdminJobStore, audience *AdminAudienceService, ports *AdminActionPorts) *AdminBulkService {
	return NewAdminBulkService(store, audience, ports)
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
	job := AdminJob{
		ID: uuid.New(), ActorID: actor.ID, SnapshotID: snapshot.ID, Action: clean, PayloadHash: clean.PayloadHash(),
		IdempotencyKey: strings.TrimSpace(request.IdempotencyKey), Status: JobPending, AccountCount: snapshot.AccountCount,
		EligibleCount: int64(len(eligible)), DeviceCount: snapshot.DeviceCount, Reason: clean.Reason,
		CreatedAt: now, UpdatedAt: now,
	}
	items := make([]AdminJobItem, 0, len(eligible))
	for _, member := range eligible {
		items = append(items, AdminJobItem{ID: uuid.New(), JobID: job.ID, TargetID: member.ResourceID, Outcome: OutcomeQueued, DeviceCount: int32(maxInt64Local(member.DeviceCount, 0)), CreatedAt: now, UpdatedAt: now})
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
		all = append(all, page...)
		if len(all) > s.maxItems {
			return nil, ErrAudienceTooLarge
		}
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
	job, err := s.getExecutableJob(ctx, actor, jobID)
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
			if _, err := s.processItemWithJob(ctx, actor, *job, item.ID); err != nil {
				if errors.Is(err, ErrAudienceForbidden) || errors.Is(err, ErrRecentMFARequired) {
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
	if !actor.Valid() {
		return nil, ErrAudienceUnauthorized
	}
	job, err := s.store.GetJob(ctx, jobID)
	if err != nil {
		return nil, err
	}
	if job == nil {
		return nil, ErrJobNotFound
	}
	if actor.ID != job.ActorID && !actor.Can("jobs.execute_all") {
		return nil, ErrAudienceForbidden
	}
	if job.Status == JobCancelled {
		return nil, ErrJobCancelled
	}
	if job.Status == JobPaused && actor.ID == job.ActorID && !actor.Can("jobs.execute_all") {
		return nil, ErrJobConflict
	}
	recentMFATTL := 5 * time.Minute
	if s.aud != nil && s.aud.recentMFATTL > 0 {
		recentMFATTL = s.aud.recentMFATTL
	}
	if err := actorCanPerform(actor, job.Action.Kind, s.now(), recentMFATTL); err != nil {
		_ = s.store.PauseJob(ctx, jobID, "actor_capability_revoked")
		return nil, err
	}
	return job, nil
}

func (s *AdminBulkService) ProcessItem(ctx context.Context, actor AdminActor, jobID, itemID uuid.UUID) (*AdminJobItem, error) {
	job, err := s.getExecutableJob(ctx, actor, jobID)
	if err != nil {
		return nil, err
	}
	return s.processItemWithJob(ctx, actor, *job, itemID)
}

func (s *AdminBulkService) processItemWithJob(ctx context.Context, actor AdminActor, job AdminJob, itemID uuid.UUID) (*AdminJobItem, error) {
	if itemID == uuid.Nil {
		return nil, ErrInvalidJobRequest
	}
	claimed, ok, err := s.store.ClaimJobItem(ctx, job.ID, itemID, s.worker)
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
	var result ActionResult
	var executeErr error
	if s.ports.Eligibility != nil {
		var eligibility RecipientEligibility
		eligibility, executeErr = s.ports.Eligibility.CheckRecipient(ctx, claimed.TargetID, job.Action)
		if executeErr == nil {
			result.DeviceCount = eligibility.DeviceCount
			if !eligibility.Eligible {
				result.Outcome = OutcomeSkipped
				result.Reason = eligibility.Reason
			} else {
				result, executeErr = s.executeAction(ctx, job, claimed.TargetID, actor.ID)
			}
		}
	} else {
		result, executeErr = s.executeAction(ctx, job, claimed.TargetID, actor.ID)
	}
	if executeErr != nil {
		result = ActionResult{Outcome: OutcomeFailed, ErrorCode: "action_failed", Retryable: true}
	}
	if result.Outcome == "" {
		result.Outcome = OutcomeFailed
	}
	if !validOutcome(result.Outcome) {
		result.Outcome = OutcomeFailed
		result.ErrorCode = "invalid_outcome"
	}
	if s.ports.DeviceRemover != nil && len(result.InvalidDeviceIDs) <= 100 {
		for _, deviceID := range result.InvalidDeviceIDs {
			if deviceID != uuid.Nil {
				_ = s.ports.DeviceRemover.RemoveInvalidDeviceToken(ctx, claimed.TargetID, deviceID, actor.ID)
			}
		}
	}
	result.InvalidDeviceIDs = nil
	result.Reason = safeOptionalReason(result.Reason)
	result.ErrorCode = safeOptionalReason(result.ErrorCode)
	result.ProviderReference = safeOptionalReason(result.ProviderReference)
	updated, err := s.store.FinishJobItem(ctx, itemID, result.Outcome, result.Reason, result.ErrorCode, result.ProviderReference)
	if err != nil {
		return nil, err
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

func (s *AdminBulkService) executeAction(ctx context.Context, job AdminJob, targetID, actorID uuid.UUID) (ActionResult, error) {
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
	result.ErrorCode = safeOptionalReason(result.ErrorCode)
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
	return updated, nil
}

func cloneJob(job AdminJob) AdminJob {
	job.Action, _ = job.Action.ValidateAndSanitize()
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
			if existing.ActorID != job.ActorID || existing.SnapshotID != job.SnapshotID || existing.PayloadHash != job.PayloadHash || existing.Action.Kind != job.Action.Kind {
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
	for i := range items {
		if items[i].ID == uuid.Nil || items[i].JobID != job.ID || items[i].TargetID == uuid.Nil {
			return nil, ErrInvalidJobRequest
		}
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
		// A freshly materialized queued item has no attempts. Once a provider
		// accepts it, OutcomeQueued is terminal for this item; replaying the
		// request must return the stored result instead of sending again.
		if item.claimed || (item.Outcome == OutcomeQueued && item.AttemptCount > 0 && !item.queuedForRetry) || (item.Outcome != OutcomeQueued && item.Outcome != OutcomeFailed && item.Outcome != OutcomeUnknownDelivery) || (item.Outcome == OutcomeFailed && !item.queuedForRetry) || item.Outcome == OutcomeUnknownDelivery {
			copy := *item
			return &copy, false, nil
		}
		item.claimed = true
		item.queuedForRetry = false
		item.AttemptCount++
		now := time.Now().UTC()
		item.LastAttemptAt = &now
		item.UpdatedAt = now
		copy := *item
		return &copy, true, nil
	}
	return nil, false, ErrJobNotFound
}

func (m *MemoryAdminStore) FinishJobItem(_ context.Context, itemID uuid.UUID, outcome, reason, errorCode, providerReference string) (*AdminJobItem, error) {
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
			if !item.claimed {
				copy := *item
				return &copy, nil
			}
			item.Outcome, item.Reason, item.ErrorCode, item.ProviderReference = outcome, safeOptionalReason(reason), safeOptionalReason(errorCode), safeOptionalReason(providerReference)
			item.DeviceCount = maxInt32(item.DeviceCount, 0)
			item.claimed = false
			now := time.Now().UTC()
			item.UpdatedAt = now
			if outcome != OutcomeUnknownDelivery {
				item.CompletedAt = &now
			}
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
	var completed, failed, pending int64
	for _, item := range items {
		switch item.Outcome {
		case OutcomeQueued:
			if item.AttemptCount == 0 {
				pending++
			} else {
				completed++
			}
		case OutcomeUnknownDelivery:
			pending++
		case OutcomeFailed:
			failed++
		default:
			completed++
		}
	}
	job.CompletedCount, job.FailedCount = completed, failed
	if job.CancellationRequested {
		job.Status = JobCancelled
	} else if pending > 0 {
		job.Status = JobRunning
	} else if failed > 0 {
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
			if items[i].Outcome == OutcomeFailed {
				items[i].Outcome, items[i].Reason, items[i].ErrorCode = OutcomeQueued, "", ""
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
