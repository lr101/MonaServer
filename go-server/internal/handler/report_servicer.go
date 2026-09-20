package handler

import (
	"context"
	"net"
	"net/http"
	"strconv"
	"strings"
	"unicode/utf8"

	"github.com/google/uuid"

	"github.com/lrprojects/monaserver/internal/apperrors"
	"github.com/lrprojects/monaserver/internal/db"
	genserver "github.com/lrprojects/monaserver/internal/gen/server"
	"github.com/lrprojects/monaserver/internal/middleware"
	"github.com/lrprojects/monaserver/internal/service"
)

// ReportServicer implements the legacy authenticated consumer report endpoint.
// Persistence is completed before the optional SMTP notification and the
// notification failure is intentionally ignored.
type ReportServicer struct {
	email   *service.Email
	q       *db.Queries
	reports *service.ReportService
}

const maxLegacyReportHTTPBodyBytes int64 = 16 << 10

type reportResponseWriterContextKey struct{}

func withReportResponseWriter(ctx context.Context, w http.ResponseWriter) context.Context {
	return context.WithValue(ctx, reportResponseWriterContextKey{}, w)
}

func reportResponseWriter(ctx context.Context) (http.ResponseWriter, bool) {
	if ctx == nil {
		return nil, false
	}
	w, ok := ctx.Value(reportResponseWriterContextKey{}).(http.ResponseWriter)
	return w, ok && w != nil
}

func NewReportServicer(email *service.Email, q *db.Queries, configs ...service.ReportServiceConfig) *ReportServicer {
	return &ReportServicer{email: email, q: q, reports: service.NewReportService(q, configs...)}
}

// CaptureReportRequest carries the normalized client address through the
// generated consumer-servicer signature and retains the response writer for
// quota headers. Mount it around the legacy report route after the
// trusted-real-IP middleware. The generated controller passes Idempotency-Key
// explicitly; the context value remains a compatibility fallback for direct
// callers.
func CaptureReportRequest(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Body != nil && r.Body != http.NoBody {
			r.Body = http.MaxBytesReader(w, r.Body, maxLegacyReportHTTPBodyBytes)
		}
		ctx := withReportResponseWriter(r.Context(), w)
		ctx = service.WithReportRequestID(ctx, strings.TrimSpace(r.Header.Get("Idempotency-Key")))
		clientIP := strings.TrimSpace(r.RemoteAddr)
		if host, _, err := net.SplitHostPort(clientIP); err == nil {
			clientIP = host
		}
		ctx = service.WithReportClientIP(ctx, clientIP)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

func (s *ReportServicer) CreateReport(ctx context.Context, dto genserver.ReportDto, idempotencyKey string) (genserver.ImplResponse, error) {
	if !validLegacyReportFields(dto.Report, dto.Message) {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	targetID, targetKind, err := reportTargetFromDTO(dto)
	if err != nil {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	// Keep the old direct, mail-only adapter behavior for deployments and unit
	// callers that have not wired the additive report repository yet. Routed
	// production calls always have q and an authenticated user context.
	if s == nil || s.q == nil {
		if caller, ok := ctxUserID(ctx); ok {
			dtoUserID, err := uuid.Parse(strings.TrimSpace(dto.UserId))
			if err != nil {
				return genserver.Response(http.StatusBadRequest, nil), nil
			}
			if dtoUserID != caller {
				return genserver.Response(http.StatusForbidden, nil), nil
			}
			// An authenticated request must never fall back to mail-only
			// delivery when the report repository is unavailable.
			return genserver.Response(http.StatusServiceUnavailable, nil), nil
		}
		if s == nil || s.email == nil {
			return genserver.Response(http.StatusServiceUnavailable, nil), nil
		}
		if err := s.email.SendReport(ctx, dto.UserId, dto.Report, dto.Message); err != nil {
			return serviceErrResp(ctx, err), nil
		}
		return genserver.Response(http.StatusOK, nil), nil
	}

	reporterID, authenticated := ctxUserID(ctx)
	dtoUserID, err := uuid.Parse(strings.TrimSpace(dto.UserId))
	if err != nil {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	if authenticated {
		if dtoUserID != reporterID {
			return genserver.Response(http.StatusForbidden, nil), nil
		}
	} else {
		// Preserve the old unknown-user response for direct generated-servicer
		// callers, but require an authenticated identity before accepting a valid
		// report. The routed endpoint always takes the authenticated branch.
		candidate, lookupErr := s.q.GetUserByID(ctx, dtoUserID)
		if lookupErr != nil {
			return serviceErrResp(ctx, lookupErr), nil
		}
		if candidate == nil {
			return genserver.Response(http.StatusNotFound, nil), nil
		}
		return genserver.Response(http.StatusUnauthorized, nil), nil
	}
	user, err := s.q.GetUserByID(ctx, reporterID)
	if err != nil {
		return serviceErrResp(ctx, err), nil
	}
	if user == nil {
		return genserver.Response(http.StatusNotFound, nil), nil
	}
	if s.reports == nil {
		return genserver.Response(http.StatusServiceUnavailable, nil), nil
	}
	legacy := dto.Report
	request := strings.TrimSpace(idempotencyKey)
	if request == "" {
		request = service.ReportRequestID(ctx)
	}
	var requestID *string
	if request != "" {
		requestID = &request
	}
	stored, err := s.reports.Submit(ctx, service.ReportSubmission{
		ReporterID: reporterID, TargetID: targetID, TargetKind: targetKind, Body: dto.Message,
		LegacyText: &legacy, RequestID: requestID, ClientIP: service.ReportClientIP(ctx),
	})
	if err != nil {
		return reportErrorResponse(ctx, err), nil
	}
	if s.email != nil {
		// The report is already durable. SMTP availability must not change the
		// successful persistence result or cause a retry to duplicate it.
		_ = s.email.SendReport(ctx, user.Username, dto.Report, dto.Message)
	}
	_ = stored
	return genserver.Response(http.StatusOK, nil), nil
}

// reportTargetFromDTO parses only client-supplied target identity. The report
// service owns the target snapshot and deletion state once the submission is
// persisted.
func reportTargetFromDTO(dto genserver.ReportDto) (*uuid.UUID, *string, error) {
	if dto.TargetId == nil {
		if dto.TargetKind != nil {
			return nil, nil, apperrors.ErrBadRequest
		}
		return nil, nil, nil
	}

	targetIDText := *dto.TargetId
	if targetIDText != strings.TrimSpace(targetIDText) || strings.ContainsAny(targetIDText, "\x00\r\n") {
		return nil, nil, apperrors.ErrBadRequest
	}
	targetID, err := uuid.Parse(targetIDText)
	if err != nil || targetID == uuid.Nil {
		return nil, nil, apperrors.ErrBadRequest
	}
	if dto.TargetKind == nil {
		return &targetID, nil, nil
	}

	targetKindText := *dto.TargetKind
	targetKind := strings.TrimSpace(targetKindText)
	if targetKind == "" || len([]byte(targetKindText)) > 32 || strings.ContainsAny(targetKindText, "\x00\r\n") || !utf8.ValidString(targetKindText) {
		return nil, nil, apperrors.ErrBadRequest
	}
	return &targetID, &targetKind, nil
}

func validLegacyReportFields(report, message string) bool {
	return strings.TrimSpace(report) != "" &&
		len([]byte(report)) <= service.MaxLegacyReportTypeBytes &&
		strings.IndexByte(report, 0) < 0 && utf8.ValidString(report) &&
		strings.IndexByte(report, '\r') < 0 && strings.IndexByte(report, '\n') < 0 &&
		len([]byte(message)) <= service.MaxLegacyReportMessageBytes &&
		strings.IndexByte(message, 0) < 0 && utf8.ValidString(message)
}

// AdminReportsServicer implements the v3 report inbox and review workflow.
// The middleware normally supplies the capability-checked admin principal;
// the explicit checks here keep direct servicer use fail-closed as well.
type AdminReportsServicer struct {
	q       *db.Queries
	reports *service.ReportService
}

func NewAdminReportsServicer(q *db.Queries, reports ...*service.ReportService) *AdminReportsServicer {
	var reportService *service.ReportService
	if len(reports) > 0 {
		reportService = reports[0]
	}
	if reportService == nil {
		reportService = service.NewReportService(q)
	}
	return &AdminReportsServicer{q: q, reports: reportService}
}

// NewAdminReportServicer is retained for composition code using a singular
// resource name.
func NewAdminReportServicer(q *db.Queries, reports ...*service.ReportService) *AdminReportsServicer {
	return NewAdminReportsServicer(q, reports...)
}

func (s *AdminReportsServicer) ListAdminReports(ctx context.Context, cursor string, limit int32, status genserver.AdminReportStatus, search string) (genserver.ImplResponse, error) {
	if _, err := requireReportAdmin(ctx, "reports.read"); err != nil {
		return reportErrorResponse(ctx, err), nil
	}
	if s == nil || s.reports == nil {
		return reportErrorResponse(ctx, service.ErrAdminUnavailable), nil
	}
	if limit <= 0 {
		limit = 25
	}
	page, err := s.reports.List(ctx, service.ReportListInput{Cursor: cursor, Limit: int(limit), Status: string(status), Search: search})
	if err != nil {
		return reportErrorResponse(ctx, err), nil
	}
	items := make([]genserver.AdminReportDto, 0, len(page.Items))
	for i := range page.Items {
		items = append(items, s.reportDTO(ctx, &page.Items[i], nil))
	}
	return genserver.Response(http.StatusOK, genserver.AdminReportPageDto{Items: items, NextCursor: page.NextCursor}), nil
}

func (s *AdminReportsServicer) GetAdminReport(ctx context.Context, reportID string, _ int64) (genserver.ImplResponse, error) {
	if _, err := requireReportAdmin(ctx, "reports.read"); err != nil {
		return reportErrorResponse(ctx, err), nil
	}
	if s == nil || s.reports == nil {
		return reportErrorResponse(ctx, service.ErrAdminUnavailable), nil
	}
	id, err := uuid.Parse(strings.TrimSpace(reportID))
	if err != nil {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	detail, err := s.reports.Get(ctx, id, 100)
	if err != nil {
		return reportErrorResponse(ctx, err), nil
	}
	return genserver.Response(http.StatusOK, s.reportDTO(ctx, detail.Report, detail.Notes)), nil
}

func (s *AdminReportsServicer) ListAdminReportNotes(ctx context.Context, reportID, cursor string, limit int32) (genserver.ImplResponse, error) {
	if _, err := requireReportAdmin(ctx, "reports.read"); err != nil {
		return reportErrorResponse(ctx, err), nil
	}
	if s == nil || s.reports == nil {
		return reportErrorResponse(ctx, service.ErrAdminUnavailable), nil
	}
	id, err := uuid.Parse(strings.TrimSpace(reportID))
	if err != nil {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	page, err := s.reports.ListNotes(ctx, service.ReportNoteListInput{ReportID: id, Cursor: cursor, Limit: int(limit)})
	if err != nil {
		return reportErrorResponse(ctx, err), nil
	}
	items := make([]genserver.AdminReportNoteDto, 0, len(page.Items))
	for i := range page.Items {
		items = append(items, s.noteDTO(&page.Items[i]))
	}
	return genserver.Response(http.StatusOK, genserver.AdminReportNotePageDto{Items: items, NextCursor: page.NextCursor}), nil
}

func (s *AdminReportsServicer) UpdateAdminReport(ctx context.Context, reportID, csrf string, request genserver.AdminReportUpdateRequestDto) (genserver.ImplResponse, error) {
	actor, err := requireReportAdmin(ctx, "reports.review")
	if err != nil {
		return reportErrorResponse(ctx, err), nil
	}
	if s == nil || s.reports == nil {
		return reportErrorResponse(ctx, service.ErrAdminUnavailable), nil
	}
	if csrf != "" {
		if principal, ok := middleware.AdminPrincipalFromContext(ctx); !ok || !middleware.CSRFMatches(principal.CSRFHash, csrf) {
			return reportErrorResponse(ctx, service.ErrAdminInvalidCSRF), nil
		}
	}
	id, err := uuid.Parse(strings.TrimSpace(reportID))
	if err != nil {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	var assignee *uuid.UUID
	assigneeSet := request.AssigneeUserIDPresent()
	if request.AssigneeUserId != nil {
		value, parseErr := uuid.Parse(strings.TrimSpace(*request.AssigneeUserId))
		if parseErr != nil {
			return genserver.Response(http.StatusBadRequest, nil), nil
		}
		assignee = &value
	}
	updated, err := s.reports.Review(ctx, service.ReportReviewInput{
		ReportID: id, ActorID: actor, ExpectedRevision: request.ExpectedRevision,
		Status: string(request.Status), AssigneeUserID: assignee, AssigneeSet: assigneeSet, Note: request.Note,
	})
	if err != nil {
		return reportErrorResponse(ctx, err), nil
	}
	detail, err := s.reports.Get(ctx, updated.ID, 100)
	if err != nil {
		return reportErrorResponse(ctx, err), nil
	}
	return genserver.Response(http.StatusOK, s.reportDTO(ctx, detail.Report, detail.Notes)), nil
}

func (s *AdminReportsServicer) AddAdminReportNote(ctx context.Context, reportID, csrf string, request genserver.AdminReportNoteRequestDto) (genserver.ImplResponse, error) {
	actor, err := requireReportAdmin(ctx, "reports.review")
	if err != nil {
		return reportErrorResponse(ctx, err), nil
	}
	if s == nil || s.reports == nil {
		return reportErrorResponse(ctx, service.ErrAdminUnavailable), nil
	}
	if csrf != "" {
		if principal, ok := middleware.AdminPrincipalFromContext(ctx); !ok || !middleware.CSRFMatches(principal.CSRFHash, csrf) {
			return reportErrorResponse(ctx, service.ErrAdminInvalidCSRF), nil
		}
	}
	id, err := uuid.Parse(strings.TrimSpace(reportID))
	if err != nil {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	note, err := s.reports.AddNote(ctx, service.ReportNoteInput{ReportID: id, ActorID: actor, Body: request.Text})
	if err != nil {
		return reportErrorResponse(ctx, err), nil
	}
	return genserver.Response(http.StatusCreated, s.noteDTO(note)), nil
}

func (s *AdminReportsServicer) reportDTO(ctx context.Context, report *db.Report, notes []db.ReportNote) genserver.AdminReportDto {
	dto := genserver.AdminReportDto{
		Id: report.ID.String(), CreatedAt: report.CreatedAt, UpdatedAt: report.UpdatedAt,
		Revision: report.Revision, Status: genserver.AdminReportStatus(report.Status), Text: report.Body,
		ReporterUserId: uuid.Nil.String(),
		Notes:          make([]genserver.AdminReportNoteDto, 0, len(notes)),
		Target:         genserver.AdminReportTargetDto{Deleted: report.TargetDeleted},
	}
	if report.ReporterUserID != nil {
		dto.ReporterUserId = report.ReporterUserID.String()
		if s.q != nil {
			if user, err := s.q.GetUserByID(ctx, *report.ReporterUserID); err == nil && user != nil {
				dto.ReporterUsername = &user.Username
			}
		}
	}
	if report.AssigneeUserID != nil {
		value := report.AssigneeUserID.String()
		dto.AssigneeUserId = &value
	}
	if report.LegacyText != nil {
		value := *report.LegacyText
		dto.LegacyMessage = &value
	}
	if report.TargetID != nil && (report.TargetKind == nil || *report.TargetKind == "user" || *report.TargetKind == "account") {
		value := report.TargetID.String()
		dto.Target.UserId = &value
	}
	if report.TargetName != nil {
		value := *report.TargetName
		dto.Target.Username = &value
	}
	for i := range notes {
		dto.Notes = append(dto.Notes, s.noteDTO(&notes[i]))
	}
	return dto
}

func (s *AdminReportsServicer) noteDTO(note *db.ReportNote) genserver.AdminReportNoteDto {
	actor := uuid.Nil.String()
	if note.AuthorUserID != nil {
		actor = note.AuthorUserID.String()
	}
	return genserver.AdminReportNoteDto{Id: note.ID.String(), ActorUserId: actor, CreatedAt: note.CreatedAt, Text: note.Body}
}

func requireReportAdmin(ctx context.Context, capability string) (uuid.UUID, error) {
	principal, ok := middleware.AdminPrincipalFromContext(ctx)
	if !ok || strings.TrimSpace(principal.UserID) == "" || (principal.State != "" && principal.State != "authenticated") {
		return uuid.Nil, service.ErrAdminUnauthorized
	}
	actor, err := uuid.Parse(principal.UserID)
	if err != nil || actor == uuid.Nil {
		return uuid.Nil, service.ErrAdminUnauthorized
	}
	if current, present := ctxUserID(ctx); present && current != actor {
		return uuid.Nil, service.ErrAdminForbidden
	}
	for _, value := range principal.Capabilities {
		if value == capability {
			return actor, nil
		}
	}
	return uuid.Nil, service.ErrAdminForbidden
}

func reportErrorResponse(ctx context.Context, err error) genserver.ImplResponse {
	status := apperrors.HTTPStatus(err)
	if status < http.StatusBadRequest || status > 599 {
		status = http.StatusServiceUnavailable
	}
	code, message := "internal_error", "report service is unavailable"
	switch status {
	case http.StatusBadRequest:
		code, message = "invalid_request", "request is invalid"
	case http.StatusUnauthorized:
		code, message = "unauthorized", "authentication is required"
	case http.StatusForbidden:
		code, message = "forbidden", "access is forbidden"
	case http.StatusNotFound:
		code, message = "not_found", "report was not found"
	case http.StatusConflict:
		code, message = "conflict", "request conflicts with current report revision"
	case http.StatusTooManyRequests:
		code, message = "rate_limited", "too many reports"
	case http.StatusServiceUnavailable:
		code, message = "feature_unavailable", "report service is not available"
	}
	body := genserver.ApiErrorDto{Code: code, Message: message}
	if retryAfter, ok := retryAfterSeconds(err); ok {
		body.RetryAfterSeconds = &retryAfter
		if writer, ok := reportResponseWriter(ctx); ok {
			writer.Header().Set("Retry-After", strconv.FormatInt(int64(retryAfter), 10))
		}
	}
	return genserver.Response(status, body)
}

var _ genserver.ReportAPIServicer = (*ReportServicer)(nil)
var _ genserver.AdminReportsAPIServicer = (*AdminReportsServicer)(nil)
