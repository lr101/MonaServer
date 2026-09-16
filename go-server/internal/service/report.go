package service

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"strconv"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/google/uuid"

	"github.com/lrprojects/monaserver/internal/apperrors"
	"github.com/lrprojects/monaserver/internal/db"
)

const (
	// These limits are intentionally at or below the limits in the frozen API
	// DTOs. The service remains safe when called without the generated handler.
	MaxReportBodyBytes          = 10000
	MaxReportLegacyBytes        = 10000
	MaxReportNoteBytes          = 2000
	MaxReportSearchBytes        = 256
	MaxReportCursorBytes        = 512
	MaxReportPageSize           = 100
	MaxLegacyReportTypeBytes    = 256
	MaxLegacyReportMessageBytes = 5000
	maxReportRequestBytes       = 255
)

var (
	ErrReportNotFound      = apperrors.ErrNotFound
	ErrReportUnauthorized  = apperrors.ErrUnauthorized
	ErrReportForbidden     = apperrors.ErrForbidden
	ErrReportConflict      = apperrors.ErrConflict
	ErrReportInvalidCursor = apperrors.ErrBadRequest
)

// ReportSubmission contains the server-owned fields of a legacy report. The
// reporter is supplied by the authenticated request boundary; callers must
// never copy a user id from an untrusted report body into ReporterID.
type ReportSubmission struct {
	ID            uuid.UUID
	ReporterID    uuid.UUID
	TargetID      *uuid.UUID
	TargetKind    *string
	TargetName    *string
	TargetDeleted bool
	Body          string
	LegacyText    *string
	RequestID     *string
	ClientIP      string
}

type ReportReviewInput struct {
	ReportID         uuid.UUID
	ActorID          uuid.UUID
	ExpectedRevision int64
	Status           string
	AssigneeUserID   *uuid.UUID
	Note             *string
}

type ReportNoteInput struct {
	ReportID uuid.UUID
	ActorID  uuid.UUID
	Body     string
}

type ReportListInput struct {
	Cursor string
	Limit  int
	Status string
	Search string
}

type ReportPage struct {
	Items      []db.Report
	NextCursor *string
}

type ReportDetail struct {
	Report *db.Report
	Notes  []db.ReportNote
}

// ReportService owns report persistence and review transitions. SMTP is kept
// outside this service so a provider outage cannot roll back a saved report.
type ReportService struct {
	q   *db.Queries
	cfg ReportServiceConfig
	now func() time.Time
}

type reportRequestIDContextKey struct{}
type reportClientIPContextKey struct{}

// WithReportRequestID lets the HTTP adapter pass an Idempotency-Key through
// the generated service signature. The raw value is used only as a bounded
// database key and is never included in audit metadata or mail.
func WithReportRequestID(ctx context.Context, value string) context.Context {
	return context.WithValue(ctx, reportRequestIDContextKey{}, value)
}

func ReportRequestID(ctx context.Context) string {
	if ctx == nil {
		return ""
	}
	value, _ := ctx.Value(reportRequestIDContextKey{}).(string)
	return strings.TrimSpace(value)
}

func WithReportClientIP(ctx context.Context, value string) context.Context {
	return context.WithValue(ctx, reportClientIPContextKey{}, value)
}

func ReportClientIP(ctx context.Context) string {
	if ctx == nil {
		return ""
	}
	value, _ := ctx.Value(reportClientIPContextKey{}).(string)
	return strings.TrimSpace(value)
}

type ReportServiceConfig struct {
	// HMACKey is optional for local callers. When configured, report submission
	// quotas use keyed identifiers and never persist raw addresses or IPs.
	HMACKey           []byte
	HMACKeyID         string
	SubmissionLimit   int64
	SubmissionIPLimit int64
	SubmissionWindow  time.Duration
}

func NewReportService(q *db.Queries, configs ...ReportServiceConfig) *ReportService {
	cfg := ReportServiceConfig{}
	if len(configs) > 0 {
		cfg = configs[0]
	}
	if cfg.SubmissionLimit <= 0 {
		cfg.SubmissionLimit = 10
	}
	if cfg.SubmissionIPLimit <= 0 {
		cfg.SubmissionIPLimit = 30
	}
	if cfg.SubmissionWindow <= 0 {
		cfg.SubmissionWindow = 15 * time.Minute
	}
	if cfg.HMACKeyID == "" {
		cfg.HMACKeyID = "report-v1"
	}
	return &ReportService{q: q, cfg: cfg, now: time.Now}
}

// NewReportReviewService is a descriptive constructor alias for composition
// code that names this service after its administrative use.
func NewReportReviewService(q *db.Queries, configs ...ReportServiceConfig) *ReportService {
	return NewReportService(q, configs...)
}

func (s *ReportService) SetClock(now func() time.Time) {
	if s != nil && now != nil {
		s.now = now
	}
}

func (s *ReportService) Submit(ctx context.Context, input ReportSubmission) (*db.Report, error) {
	if s == nil || s.q == nil {
		return nil, apperrors.ErrUnavailable
	}
	if err := validateReportSubmission(input); err != nil {
		return nil, err
	}
	input = normalizeReportSubmission(input)
	// A replay of the same idempotency key returns the committed row and does
	// not consume another submission quota unit. A changed payload still goes
	// through the transactional conflict check below.
	if input.RequestID == nil {
		if err := s.admitSubmission(ctx, input); err != nil {
			return nil, err
		}
	} else {
		existing, err := s.q.GetReportByRequestID(ctx, *input.RequestID)
		if err != nil {
			return nil, apperrors.ErrUnavailable
		}
		if existing == nil {
			if err := s.admitSubmission(ctx, input); err != nil {
				return nil, err
			}
		}
	}

	if input.ID == uuid.Nil {
		input.ID = uuid.New()
	}
	var stored *db.Report
	err := s.q.InTxRetry(ctx, func(tx *db.Queries) error {
		insert := input
		requestID := ""
		if insert.RequestID != nil {
			requestID = *insert.RequestID
		}
		existing, err := tx.GetReportByRequestID(ctx, requestID)
		if err != nil {
			return err
		}
		// Resolve a target snapshot while the insert transaction is open. This
		// preserves the username/deleted bit if a soft deletion races the
		// submission and keeps review independent of the target account later.
		if existing == nil && insert.TargetID != nil && insert.TargetName == nil && isReportUserTarget(insert.TargetKind) {
			target, err := tx.GetReportTargetSnapshot(ctx, *insert.TargetID)
			if err != nil {
				return err
			}
			if target != nil {
				name := target.Name
				insert.TargetName = &name
				insert.TargetDeleted = target.Deleted
			}
		}
		stored, err = tx.CreateReport(ctx, db.ReportParams{
			ID: insert.ID, ReporterUserID: &insert.ReporterID, TargetID: insert.TargetID,
			TargetKind: insert.TargetKind, TargetName: insert.TargetName, TargetDeleted: insert.TargetDeleted,
			Body: insert.Body, LegacyText: insert.LegacyText, RequestID: insert.RequestID,
		})
		if err != nil {
			return err
		}
		// CreateReport returns the existing row on an idempotent conflict. Avoid
		// a second audit event for both a previously visible and a racing replay.
		if existing != nil || stored.ID != insert.ID {
			return nil
		}
		return createReportAudit(ctx, tx, input.ReporterID, stored, "report_submitted")
	})
	if errors.Is(err, db.ErrIdempotencyConflict) {
		return nil, apperrors.ErrConflict
	}
	if err != nil {
		return nil, mapReportDBError(err)
	}
	return stored, nil
}

func (s *ReportService) List(ctx context.Context, input ReportListInput) (*ReportPage, error) {
	if s == nil || s.q == nil {
		return nil, apperrors.ErrUnavailable
	}
	if input.Limit <= 0 {
		input.Limit = 25
	}
	if input.Limit > MaxReportPageSize {
		return nil, apperrors.ErrBadRequest
	}
	if input.Status != "" && !validReportStatus(input.Status) {
		return nil, apperrors.ErrBadRequest
	}
	input.Search = strings.TrimSpace(input.Search)
	if len([]byte(input.Search)) > MaxReportSearchBytes {
		return nil, apperrors.ErrBadRequest
	}

	var beforeCreated *time.Time
	var beforeID *uuid.UUID
	if strings.TrimSpace(input.Cursor) != "" {
		cursor, err := decodeReportCursor(input.Cursor)
		if err != nil {
			return nil, err
		}
		beforeCreated = &cursor.CreatedAt
		beforeID = &cursor.ID
	}
	rows, err := s.q.ListReportsPage(ctx, input.Status, input.Search, beforeCreated, beforeID, input.Limit+1)
	if err != nil {
		return nil, mapReportDBError(err)
	}
	page := &ReportPage{Items: rows}
	if len(rows) > input.Limit {
		page.Items = rows[:input.Limit]
		cursor, err := encodeReportCursor(reportCursor{CreatedAt: page.Items[len(page.Items)-1].CreatedAt, ID: page.Items[len(page.Items)-1].ID})
		if err != nil {
			return nil, err
		}
		page.NextCursor = &cursor
	}
	if page.Items == nil {
		page.Items = []db.Report{}
	}
	return page, nil
}

func (s *ReportService) Get(ctx context.Context, id uuid.UUID, noteLimit int) (*ReportDetail, error) {
	if s == nil || s.q == nil {
		return nil, apperrors.ErrUnavailable
	}
	if id == uuid.Nil {
		return nil, apperrors.ErrBadRequest
	}
	if noteLimit <= 0 {
		noteLimit = 100
	}
	if noteLimit > 100 {
		noteLimit = 100
	}
	report, err := s.q.GetReport(ctx, id)
	if err != nil {
		return nil, mapReportDBError(err)
	}
	if report == nil {
		return nil, apperrors.ErrNotFound
	}
	notes, err := s.q.ListReportNotes(ctx, id, noteLimit)
	if err != nil {
		return nil, mapReportDBError(err)
	}
	if notes == nil {
		notes = []db.ReportNote{}
	}
	return &ReportDetail{Report: report, Notes: notes}, nil
}

func (s *ReportService) Review(ctx context.Context, input ReportReviewInput) (*db.Report, error) {
	if s == nil || s.q == nil {
		return nil, apperrors.ErrUnavailable
	}
	if input.ReportID == uuid.Nil || input.ActorID == uuid.Nil || input.ExpectedRevision <= 0 || !validReportStatus(input.Status) {
		return nil, apperrors.ErrBadRequest
	}
	if input.Note != nil {
		value := strings.TrimSpace(*input.Note)
		if value == "" || len([]byte(value)) > MaxReportNoteBytes || strings.IndexByte(value, 0) >= 0 || !utf8.ValidString(value) {
			return nil, apperrors.ErrBadRequest
		}
		input.Note = &value
	}
	if input.AssigneeUserID != nil && *input.AssigneeUserID == uuid.Nil {
		return nil, apperrors.ErrBadRequest
	}

	var updated *db.Report
	err := s.q.InTxRetry(ctx, func(tx *db.Queries) error {
		before, err := tx.GetReport(ctx, input.ReportID)
		if err != nil {
			return err
		}
		if before == nil {
			return apperrors.ErrNotFound
		}
		if before.Revision != input.ExpectedRevision {
			return apperrors.ErrConflict
		}
		if input.AssigneeUserID != nil {
			assignee, err := tx.GetUserByID(ctx, *input.AssigneeUserID)
			if err != nil {
				return err
			}
			if assignee == nil {
				return apperrors.ErrNotFound
			}
		}
		var ok bool
		updated, ok, err = tx.UpdateReportIfRevision(ctx, input.ReportID, input.ExpectedRevision, input.Status, input.AssigneeUserID)
		if err != nil {
			return err
		}
		if !ok || updated == nil {
			return apperrors.ErrConflict
		}
		if input.Note != nil {
			if _, err := tx.CreateReportNote(ctx, db.ReportNoteParams{ID: uuid.New(), ReportID: input.ReportID, AuthorUserID: &input.ActorID, Body: *input.Note}); err != nil {
				return err
			}
		}
		return createReportAudit(ctx, tx, input.ActorID, updated, reportActionForStatus(input.Status))
	})
	if err != nil {
		return nil, mapReportDBError(err)
	}
	return updated, nil
}

func (s *ReportService) AddNote(ctx context.Context, input ReportNoteInput) (*db.ReportNote, error) {
	if s == nil || s.q == nil {
		return nil, apperrors.ErrUnavailable
	}
	if input.ReportID == uuid.Nil || input.ActorID == uuid.Nil {
		return nil, apperrors.ErrBadRequest
	}
	input.Body = strings.TrimSpace(input.Body)
	if input.Body == "" || len([]byte(input.Body)) > MaxReportNoteBytes || strings.IndexByte(input.Body, 0) >= 0 || !utf8.ValidString(input.Body) {
		return nil, apperrors.ErrBadRequest
	}
	var note *db.ReportNote
	err := s.q.InTxRetry(ctx, func(tx *db.Queries) error {
		report, err := tx.GetReport(ctx, input.ReportID)
		if err != nil {
			return err
		}
		if report == nil {
			return apperrors.ErrNotFound
		}
		note, err = tx.CreateReportNote(ctx, db.ReportNoteParams{ID: uuid.New(), ReportID: input.ReportID, AuthorUserID: &input.ActorID, Body: input.Body})
		if err != nil {
			return err
		}
		return createReportAudit(ctx, tx, input.ActorID, report, "report_note")
	})
	if err != nil {
		return nil, mapReportDBError(err)
	}
	return note, nil
}

func validateReportSubmission(input ReportSubmission) error {
	if input.ReporterID == uuid.Nil || strings.TrimSpace(input.Body) == "" || len([]byte(input.Body)) > MaxReportBodyBytes || strings.IndexByte(input.Body, 0) >= 0 || !utf8.ValidString(input.Body) {
		return apperrors.ErrBadRequest
	}
	if input.LegacyText != nil && (len([]byte(*input.LegacyText)) > MaxReportLegacyBytes || strings.IndexByte(*input.LegacyText, 0) >= 0 || !utf8.ValidString(*input.LegacyText)) {
		return apperrors.ErrBadRequest
	}
	if input.RequestID != nil {
		value := strings.TrimSpace(*input.RequestID)
		if value == "" || len([]byte(value)) > maxReportRequestBytes || strings.IndexByte(value, 0) >= 0 || !utf8.ValidString(value) {
			return apperrors.ErrBadRequest
		}
		input.RequestID = &value
	}
	if input.TargetKind != nil {
		value := strings.TrimSpace(*input.TargetKind)
		if value == "" || len([]byte(value)) > 32 || strings.IndexByte(value, 0) >= 0 || !utf8.ValidString(value) {
			return apperrors.ErrBadRequest
		}
	}
	if input.TargetName != nil {
		value := strings.TrimSpace(*input.TargetName)
		if value == "" || len([]byte(value)) > 255 || strings.IndexByte(value, 0) >= 0 || !utf8.ValidString(value) {
			return apperrors.ErrBadRequest
		}
	}
	return nil
}

func normalizeReportSubmission(input ReportSubmission) ReportSubmission {
	if input.RequestID != nil {
		value := strings.TrimSpace(*input.RequestID)
		input.RequestID = &value
	}
	if input.TargetKind != nil {
		value := strings.TrimSpace(*input.TargetKind)
		input.TargetKind = &value
	}
	if input.TargetName != nil {
		value := strings.TrimSpace(*input.TargetName)
		input.TargetName = &value
	}
	return input
}

func validReportStatus(value string) bool {
	return value == db.ReportStatusOpen || value == db.ReportStatusResolved || value == db.ReportStatusDismissed
}

func isReportUserTarget(kind *string) bool {
	return kind == nil || *kind == "user" || *kind == "account"
}

func reportActionForStatus(status string) string {
	switch status {
	case db.ReportStatusResolved:
		return "report_resolve"
	case db.ReportStatusDismissed:
		return "report_dismiss"
	default:
		return "report_reopen"
	}
}

func createReportAudit(ctx context.Context, q *db.Queries, actor uuid.UUID, report *db.Report, action string) error {
	if q == nil || report == nil || actor == uuid.Nil || action == "" {
		return apperrors.ErrBadRequest
	}
	metadata, err := json.Marshal(map[string]string{
		"report_id": report.ID.String(),
		"status":    report.Status,
		"revision":  formatInt(report.Revision),
	})
	if err != nil {
		return err
	}
	var target *uuid.UUID
	if report.TargetID != nil && isReportUserTarget(report.TargetKind) {
		target = report.TargetID
	}
	return q.CreateAuditEvent(ctx, db.AuditEventParams{ID: uuid.New(), ActorID: &actor, TargetAccountID: target, Action: action, Metadata: metadata})
}

func formatInt(value int64) string {
	return strconv.FormatInt(value, 10)
}

func mapReportDBError(err error) error {
	if err == nil {
		return nil
	}
	if errors.Is(err, apperrors.ErrNotFound) || errors.Is(err, apperrors.ErrConflict) || errors.Is(err, apperrors.ErrBadRequest) {
		return err
	}
	if errors.Is(err, db.ErrIdempotencyConflict) {
		return apperrors.ErrConflict
	}
	return apperrors.ErrUnavailable
}

type reportCursor struct {
	CreatedAt time.Time
	ID        uuid.UUID
}

type reportCursorWire struct {
	Version   int    `json:"v"`
	CreatedAt string `json:"createdAt"`
	ID        string `json:"id"`
}

func encodeReportCursor(cursor reportCursor) (string, error) {
	if cursor.ID == uuid.Nil || cursor.CreatedAt.IsZero() {
		return "", apperrors.ErrBadRequest
	}
	payload, err := json.Marshal(reportCursorWire{Version: 1, CreatedAt: cursor.CreatedAt.UTC().Format(time.RFC3339Nano), ID: cursor.ID.String()})
	if err != nil {
		return "", err
	}
	value := base64.RawURLEncoding.EncodeToString(payload)
	if len(value) > MaxReportCursorBytes {
		return "", apperrors.ErrBadRequest
	}
	return value, nil
}

func decodeReportCursor(value string) (reportCursor, error) {
	if len(value) == 0 || len(value) > MaxReportCursorBytes {
		return reportCursor{}, apperrors.ErrBadRequest
	}
	payload, err := base64.RawURLEncoding.DecodeString(value)
	if err != nil || len(payload) > MaxReportCursorBytes {
		return reportCursor{}, apperrors.ErrBadRequest
	}
	var wire reportCursorWire
	decoder := json.NewDecoder(strings.NewReader(string(payload)))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&wire); err != nil || wire.Version != 1 {
		return reportCursor{}, apperrors.ErrBadRequest
	}
	var extra interface{}
	if err := decoder.Decode(&extra); !errors.Is(err, io.EOF) {
		return reportCursor{}, apperrors.ErrBadRequest
	}
	id, err := uuid.Parse(wire.ID)
	if err != nil {
		return reportCursor{}, apperrors.ErrBadRequest
	}
	created, err := time.Parse(time.RFC3339Nano, wire.CreatedAt)
	if err != nil || created.IsZero() {
		return reportCursor{}, apperrors.ErrBadRequest
	}
	return reportCursor{CreatedAt: created, ID: id}, nil
}

func (s *ReportService) admitSubmission(ctx context.Context, input ReportSubmission) error {
	if len(s.cfg.HMACKey) == 0 {
		return nil
	}
	now := time.Now()
	if s.now != nil {
		now = s.now()
	}
	now = now.UTC()
	start := now.Truncate(s.cfg.SubmissionWindow)
	end := start.Add(s.cfg.SubmissionWindow)
	checks := []struct {
		scope string
		value string
		limit int64
	}{
		{scope: "report-submit-account", value: input.ReporterID.String(), limit: s.cfg.SubmissionLimit},
	}
	if strings.TrimSpace(input.ClientIP) != "" {
		checks = append(checks, struct {
			scope string
			value string
			limit int64
		}{scope: "report-submit-ip", value: strings.TrimSpace(input.ClientIP), limit: s.cfg.SubmissionIPLimit})
	}
	for _, check := range checks {
		h := hmac.New(sha256.New, s.cfg.HMACKey)
		_, _ = h.Write([]byte(check.scope + "\x00" + check.value))
		decision, err := s.q.AcquireSharedQuota(ctx, []db.SharedQuotaKey{{
			Scope: check.scope, IdentifierHMAC: h.Sum(nil), KeyID: s.cfg.HMACKeyID,
			WindowStart: start, WindowEnd: end, Limit: check.limit,
		}}, 1)
		if err != nil {
			return apperrors.ErrUnavailable
		}
		if !decision.Allowed {
			return apperrors.New(http.StatusTooManyRequests, "too many reports")
		}
	}
	return nil
}
