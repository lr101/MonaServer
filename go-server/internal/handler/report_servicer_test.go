package handler

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/lrprojects/monaserver/internal/db"
	genserver "github.com/lrprojects/monaserver/internal/gen/server"
	"github.com/lrprojects/monaserver/internal/middleware"
	"github.com/lrprojects/monaserver/internal/service"
)

func setupReportHandlerDB(t *testing.T) (*db.Queries, uuid.UUID, uuid.UUID) {
	t.Helper()
	dsn := testDatabaseURL(t)
	if err := db.RunMigrations(dsn); err != nil {
		t.Fatalf("migrations: %v", err)
	}
	pool, err := db.NewPool(context.Background(), dsn)
	if err != nil {
		t.Fatalf("pool: %v", err)
	}
	t.Cleanup(pool.Close)
	if _, err := pool.Exec(context.Background(), `TRUNCATE TABLE refresh_token, users, seasons CASCADE`); err != nil {
		t.Fatalf("truncate: %v", err)
	}
	q := db.New(pool)
	reporterID := uuid.New()
	adminID := uuid.New()
	for _, user := range []struct {
		id       uuid.UUID
		username string
	}{{reporterID, "handler-reporter"}, {adminID, "handler-reviewer"}} {
		if _, err := pool.Exec(context.Background(), `
			INSERT INTO users (id, username, password, email_confirmed, creation_date, update_date)
			VALUES ($1, $2, 'hash', FALSE, NOW(), NOW())`, user.id, user.username); err != nil {
			t.Fatalf("insert user: %v", err)
		}
	}
	return q, reporterID, adminID
}

func reportAdminContext(adminID uuid.UUID) context.Context {
	principal := middleware.AdminPrincipal{
		UserID: adminID.String(), State: "authenticated",
		Capabilities: []string{"reports.read", "reports.review", "reports.resolve", "reports.dismiss"},
	}
	ctx := middleware.WithAdminPrincipal(context.Background(), principal)
	return middleware.WithUser(ctx, adminID, middleware.RoleAdmin)
}

func TestCreateReportPersistsWithoutSMTPAndRejectsForgedReporter(t *testing.T) {
	q, reporterID, _ := setupReportHandlerDB(t)
	servicer := NewReportServicer(nil, q)
	ctx := middleware.WithUser(context.Background(), reporterID, middleware.RoleUser)

	response, err := servicer.CreateReport(ctx, genserver.ReportDto{UserId: reporterID.String(), Report: "Bug", Message: "details"})
	if err != nil {
		t.Fatalf("create report: %v", err)
	}
	if response.Code != http.StatusCreated {
		t.Fatalf("create report status = %d, want 201", response.Code)
	}
	var count int
	if err := q.Pool().QueryRow(context.Background(), `SELECT count(*) FROM reports WHERE reporter_user_id = $1`, reporterID).Scan(&count); err != nil {
		t.Fatalf("count reports: %v", err)
	}
	if count != 1 {
		t.Fatalf("stored reports = %d, want 1", count)
	}

	forged := uuid.New()
	response, err = servicer.CreateReport(ctx, genserver.ReportDto{UserId: forged.String(), Report: "Bug", Message: "forged"})
	if err != nil {
		t.Fatalf("forged report: %v", err)
	}
	if response.Code != http.StatusForbidden {
		t.Fatalf("forged reporter status = %d, want 403", response.Code)
	}
	unauthenticated, err := servicer.CreateReport(context.Background(), genserver.ReportDto{UserId: reporterID.String(), Report: "Bug", Message: "unauthenticated"})
	if err != nil {
		t.Fatalf("unauthenticated report: %v", err)
	}
	if unauthenticated.Code != http.StatusUnauthorized {
		t.Fatalf("unauthenticated reporter status = %d, want 401", unauthenticated.Code)
	}
	invalid, err := servicer.CreateReport(ctx, genserver.ReportDto{
		UserId: reporterID.String(), Report: "\n", Message: strings.Repeat("x", service.MaxLegacyReportMessageBytes+1),
	})
	if err != nil {
		t.Fatalf("invalid report: %v", err)
	}
	if invalid.Code != http.StatusBadRequest {
		t.Fatalf("invalid report status = %d, want 400", invalid.Code)
	}
}

func TestCreateReportAuthenticatedWithoutRepositoryDoesNotMailOnly(t *testing.T) {
	servicer := NewReportServicer(nil, nil)
	userID := uuid.New()
	response, err := servicer.CreateReport(middleware.WithUser(context.Background(), userID, middleware.RoleUser), genserver.ReportDto{
		UserId: userID.String(), Report: "Bug", Message: "details",
	})
	if err != nil {
		t.Fatalf("repository-unavailable report: %v", err)
	}
	if response.Code != http.StatusServiceUnavailable {
		t.Fatalf("repository-unavailable report status = %d, want 503", response.Code)
	}
}

func TestCaptureReportRequestCarriesIdempotencyAndClientIP(t *testing.T) {
	var requestID, clientIP string
	handler := CaptureReportRequest(http.HandlerFunc(func(_ http.ResponseWriter, request *http.Request) {
		requestID = service.ReportRequestID(request.Context())
		clientIP = service.ReportClientIP(request.Context())
	}))
	request := httptest.NewRequest(http.MethodPost, "/api/v2/report", nil)
	request.RemoteAddr = "192.0.2.50:443"
	request.Header.Set("Idempotency-Key", "report-key")
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)
	if requestID != "report-key" || clientIP != "192.0.2.50" {
		t.Fatalf("captured request id=%q client ip=%q", requestID, clientIP)
	}
	var bodyErr error
	limited := CaptureReportRequest(http.HandlerFunc(func(_ http.ResponseWriter, request *http.Request) {
		_, bodyErr = io.ReadAll(request.Body)
	}))
	oversized := httptest.NewRequest(http.MethodPost, "/api/v2/report", strings.NewReader(strings.Repeat("x", int(maxLegacyReportHTTPBodyBytes)+1)))
	limited.ServeHTTP(httptest.NewRecorder(), oversized)
	if bodyErr == nil {
		t.Fatal("oversized report body was read without a limit error")
	}
}

func TestAdminReportHandlerRequiresCapabilityAndSupportsReviewWorkflow(t *testing.T) {
	q, reporterID, adminID := setupReportHandlerDB(t)
	reports := service.NewReportService(q)
	created, err := reports.Submit(context.Background(), service.ReportSubmission{ReporterID: reporterID, Body: "review details"})
	if err != nil {
		t.Fatalf("submit report: %v", err)
	}
	servicer := NewAdminReportsServicer(q, reports)

	unauthorized, err := servicer.ListAdminReports(context.Background(), "", 25, "", "")
	if err != nil {
		t.Fatalf("unauthorized list: %v", err)
	}
	if unauthorized.Code != http.StatusUnauthorized {
		t.Fatalf("unauthorized list status = %d, want 401", unauthorized.Code)
	}

	ctx := reportAdminContext(adminID)
	listed, err := servicer.ListAdminReports(ctx, "", 25, "", "")
	if err != nil || listed.Code != http.StatusOK {
		t.Fatalf("list reports = %#v err=%v", listed, err)
	}
	page, ok := listed.Body.(genserver.AdminReportPageDto)
	if !ok || len(page.Items) != 1 || page.Items[0].Text != "review details" {
		t.Fatalf("list body = %#v", listed.Body)
	}

	updated, err := servicer.UpdateAdminReport(ctx, created.ID.String(), "", genserver.AdminReportUpdateRequestDto{
		ExpectedRevision: created.Revision, Status: genserver.RESOLVED,
		Note: stringPtr("handled"),
	})
	if err != nil || updated.Code != http.StatusOK {
		t.Fatalf("update report = %#v err=%v", updated, err)
	}
	updatedDTO, ok := updated.Body.(genserver.AdminReportDto)
	if !ok || updatedDTO.Status != genserver.RESOLVED || len(updatedDTO.Notes) != 1 {
		t.Fatalf("updated body = %#v", updated.Body)
	}

	stale, err := servicer.UpdateAdminReport(ctx, created.ID.String(), "", genserver.AdminReportUpdateRequestDto{
		ExpectedRevision: created.Revision, Status: genserver.OPEN,
	})
	if err != nil || stale.Code != http.StatusConflict {
		t.Fatalf("stale update = %#v err=%v", stale, err)
	}

	note, err := servicer.AddAdminReportNote(ctx, created.ID.String(), "", genserver.AdminReportNoteRequestDto{Text: "follow-up"})
	if err != nil || note.Code != http.StatusCreated {
		t.Fatalf("add note = %#v err=%v", note, err)
	}
}

func TestAdminReportUpdateUsesReviewCapabilityAndExplicitNullClearsAssignee(t *testing.T) {
	q, reporterID, adminID := setupReportHandlerDB(t)
	reports := service.NewReportService(q)
	created, err := reports.Submit(context.Background(), service.ReportSubmission{ReporterID: reporterID, Body: "assignment clear"})
	if err != nil {
		t.Fatalf("submit report: %v", err)
	}
	assigneeID := uuid.New()
	if _, err := q.Pool().Exec(context.Background(), `
		INSERT INTO users (id, username, password, email_confirmed, creation_date, update_date)
		VALUES ($1, 'handler-assignee', 'hash', FALSE, NOW(), NOW())`, assigneeID); err != nil {
		t.Fatalf("insert assignee: %v", err)
	}
	servicer := NewAdminReportsServicer(q, reports)
	assigned, err := servicer.UpdateAdminReport(reportAdminContext(adminID), created.ID.String(), "", genserver.AdminReportUpdateRequestDto{
		ExpectedRevision: created.Revision, Status: genserver.OPEN, AssigneeUserId: stringPtr(assigneeID.String()),
	})
	if err != nil || assigned.Code != http.StatusOK {
		t.Fatalf("assign report = %#v err=%v", assigned, err)
	}
	reviewOnly := middleware.WithAdminPrincipal(context.Background(), middleware.AdminPrincipal{
		UserID: adminID.String(), State: "authenticated", Capabilities: []string{"reports.read", "reports.review"},
	})
	reviewOnly = middleware.WithUser(reviewOnly, adminID, middleware.RoleAdmin)
	controller := genserver.NewAdminReportsAPIController(servicer)
	router := chi.NewRouter()
	for _, route := range controller.OrderedRoutes() {
		router.Method(route.Method, route.Pattern, route.HandlerFunc)
	}
	omitted := httptest.NewRequest(http.MethodPatch, "/api/v3/admin/reports/"+created.ID.String(), strings.NewReader(`{"expectedRevision":2,"status":"open"}`))
	omitted = omitted.WithContext(reviewOnly)
	omittedRecorder := httptest.NewRecorder()
	router.ServeHTTP(omittedRecorder, omitted)
	if omittedRecorder.Code != http.StatusOK {
		t.Fatalf("review-only omitted assignee status = %d, body=%s", omittedRecorder.Code, omittedRecorder.Body.String())
	}
	stored, err := q.GetReport(context.Background(), created.ID)
	if err != nil || stored == nil || stored.AssigneeUserID == nil || *stored.AssigneeUserID != assigneeID {
		t.Fatalf("omitted assignee = %#v err=%v", stored, err)
	}
	request := httptest.NewRequest(http.MethodPatch, "/api/v3/admin/reports/"+created.ID.String(), strings.NewReader(`{"expectedRevision":3,"status":"dismissed","assigneeUserId":null}`))
	request = request.WithContext(reviewOnly)
	recorder := httptest.NewRecorder()
	router.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusOK {
		t.Fatalf("review-only explicit clear status = %d, body=%s", recorder.Code, recorder.Body.String())
	}
	stored, err = q.GetReport(context.Background(), created.ID)
	if err != nil || stored == nil || stored.Status != db.ReportStatusDismissed || stored.AssigneeUserID != nil {
		t.Fatalf("explicit null assignee = %#v err=%v", stored, err)
	}
}

func TestAdminReportGeneratedControllerBindsCursorAndPath(t *testing.T) {
	q, reporterID, adminID := setupReportHandlerDB(t)
	created, err := service.NewReportService(q).Submit(context.Background(), service.ReportSubmission{ReporterID: reporterID, Body: "controller details"})
	if err != nil {
		t.Fatalf("submit report: %v", err)
	}
	if _, err := service.NewReportService(q).AddNote(reportAdminContext(adminID), service.ReportNoteInput{ReportID: created.ID, ActorID: adminID, Body: "history note"}); err != nil {
		t.Fatalf("add history note: %v", err)
	}
	controller := genserver.NewAdminReportsAPIController(NewAdminReportsServicer(q))
	router := chi.NewRouter()
	for _, route := range controller.OrderedRoutes() {
		router.Method(route.Method, route.Pattern, route.HandlerFunc)
	}
	request := httptest.NewRequest(http.MethodGet, "/api/v3/admin/reports?limit=1", nil)
	request = request.WithContext(reportAdminContext(adminID))
	recorder := httptest.NewRecorder()
	router.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusOK {
		t.Fatalf("controller list status = %d, body=%s", recorder.Code, recorder.Body.String())
	}
	var body genserver.AdminReportPageDto
	if err := json.NewDecoder(strings.NewReader(recorder.Body.String())).Decode(&body); err != nil {
		t.Fatalf("decode controller body: %v", err)
	}
	if len(body.Items) != 1 {
		t.Fatalf("controller items = %d, want 1", len(body.Items))
	}
	notesRequest := httptest.NewRequest(http.MethodGet, "/api/v3/admin/reports/"+created.ID.String()+"/notes?limit=1", nil)
	notesRequest = notesRequest.WithContext(reportAdminContext(adminID))
	notesRecorder := httptest.NewRecorder()
	router.ServeHTTP(notesRecorder, notesRequest)
	if notesRecorder.Code != http.StatusOK {
		t.Fatalf("controller notes status = %d, body=%s", notesRecorder.Code, notesRecorder.Body.String())
	}
	var notesBody genserver.AdminReportNotePageDto
	if err := json.NewDecoder(strings.NewReader(notesRecorder.Body.String())).Decode(&notesBody); err != nil {
		t.Fatalf("decode controller notes body: %v", err)
	}
	if len(notesBody.Items) != 1 || notesBody.Items[0].Text != "history note" {
		t.Fatalf("controller notes body = %#v", notesBody)
	}
}

func stringPtr(value string) *string { return &value }
