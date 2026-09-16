package service

import (
	"context"
	"errors"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/lrprojects/monaserver/internal/apperrors"
	"github.com/lrprojects/monaserver/internal/db"
)

func insertReportTestUser(t *testing.T, q *db.Queries, id uuid.UUID, username string) {
	t.Helper()
	if _, err := q.Pool().Exec(context.Background(), `
		INSERT INTO users (id, username, password, email_confirmed, creation_date, update_date)
		VALUES ($1, $2, 'hash', FALSE, NOW(), NOW())`, id, username); err != nil {
		t.Fatalf("insert report user: %v", err)
	}
}

func TestReportServiceSubmissionIsAuthenticatedAndIdempotent(t *testing.T) {
	_, q := setupPool(t)
	ctx := context.Background()
	reporterID := uuid.New()
	insertReportTestUser(t, q, reporterID, "reporter")

	reports := NewReportService(q, ReportServiceConfig{
		HMACKey:           []byte("report-idempotency-test-key"),
		SubmissionLimit:   1,
		SubmissionIPLimit: 10,
		SubmissionWindow:  time.Hour,
	})
	legacy := "Bug"
	requestID := "report-request-1"
	first, err := reports.Submit(ctx, ReportSubmission{
		ID: reporterID, ReporterID: reporterID, Body: "details", LegacyText: &legacy, RequestID: &requestID,
	})
	if err != nil {
		t.Fatalf("submit report: %v", err)
	}
	if first == nil || first.ReporterUserID == nil || *first.ReporterUserID != reporterID {
		t.Fatalf("stored reporter = %#v, want %s", first, reporterID)
	}

	replay, err := reports.Submit(ctx, ReportSubmission{
		ID: uuid.New(), ReporterID: reporterID, Body: "details", LegacyText: &legacy, RequestID: &requestID,
	})
	if err != nil || replay == nil || replay.ID != first.ID {
		t.Fatalf("idempotent replay = %#v, err=%v", replay, err)
	}

	_, err = reports.Submit(ctx, ReportSubmission{
		ID: uuid.New(), ReporterID: reporterID, Body: "changed", LegacyText: &legacy, RequestID: &requestID,
	})
	if !errors.Is(err, apperrors.ErrConflict) {
		t.Fatalf("conflicting replay error = %v, want idempotency conflict", err)
	}

	var count int
	if err := q.Pool().QueryRow(ctx, `SELECT count(*) FROM reports WHERE request_id = $1`, requestID).Scan(&count); err != nil {
		t.Fatalf("count reports: %v", err)
	}
	if count != 1 {
		t.Fatalf("report count = %d, want 1", count)
	}
}

func TestReportServiceRejectsUnboundedContent(t *testing.T) {
	_, q := setupPool(t)
	reporterID := uuid.New()
	insertReportTestUser(t, q, reporterID, "bounded-reporter")

	_, err := NewReportService(q).Submit(context.Background(), ReportSubmission{
		ID: reporterID, ReporterID: reporterID, Body: strings.Repeat("x", MaxReportBodyBytes+1),
	})
	if !errors.Is(err, apperrors.ErrBadRequest) {
		t.Fatalf("oversized report error = %v, want bad request", err)
	}
}

func TestReportServiceUsesKeyedSubmissionQuota(t *testing.T) {
	_, q := setupPool(t)
	ctx := context.Background()
	reporterID := uuid.New()
	insertReportTestUser(t, q, reporterID, "quota-reporter")
	reports := NewReportService(q, ReportServiceConfig{
		HMACKey:           []byte("report-quota-test-key"),
		SubmissionLimit:   1,
		SubmissionIPLimit: 10,
		SubmissionWindow:  time.Hour,
	})
	if _, err := reports.Submit(ctx, ReportSubmission{ReporterID: reporterID, Body: "first", ClientIP: "192.0.2.9"}); err != nil {
		t.Fatalf("first quota submission: %v", err)
	}
	if _, err := reports.Submit(ctx, ReportSubmission{ReporterID: reporterID, Body: "second", ClientIP: "192.0.2.9"}); apperrors.HTTPStatus(err) != 429 {
		t.Fatalf("second quota submission error = %v, want 429", err)
	}
	var rawIPCount int
	if err := q.Pool().QueryRow(ctx, `SELECT count(*) FROM rate_limit_buckets WHERE identifier_hmac = $1`, []byte("192.0.2.9")).Scan(&rawIPCount); err != nil {
		t.Fatalf("check raw IP quota value: %v", err)
	}
	if rawIPCount != 0 {
		t.Fatalf("raw IP quota rows = %d, want 0", rawIPCount)
	}
}

func TestReportServiceReviewRevisionAllowsOneConcurrentWriter(t *testing.T) {
	_, q := setupPool(t)
	ctx := context.Background()
	reporterID := uuid.New()
	actorA := uuid.New()
	actorB := uuid.New()
	insertReportTestUser(t, q, reporterID, "review-reporter")
	insertReportTestUser(t, q, actorA, "review-a")
	insertReportTestUser(t, q, actorB, "review-b")

	reports := NewReportService(q)
	created, err := reports.Submit(ctx, ReportSubmission{ID: uuid.New(), ReporterID: reporterID, Body: "review me"})
	if err != nil {
		t.Fatalf("submit report: %v", err)
	}

	type result struct {
		report *db.Report
		err    error
	}
	results := make(chan result, 2)
	var wg sync.WaitGroup
	for _, actor := range []uuid.UUID{actorA, actorB} {
		actor := actor
		wg.Add(1)
		go func() {
			defer wg.Done()
			updated, err := reports.Review(ctx, ReportReviewInput{
				ReportID: created.ID, ActorID: actor, ExpectedRevision: created.Revision, Status: db.ReportStatusResolved,
			})
			results <- result{report: updated, err: err}
		}()
	}
	wg.Wait()
	close(results)

	var successes, conflicts int
	for item := range results {
		if item.err == nil {
			successes++
			if item.report == nil || item.report.Status != db.ReportStatusResolved {
				t.Fatalf("updated report = %#v, want resolved", item.report)
			}
		} else if errors.Is(item.err, apperrors.ErrConflict) {
			conflicts++
		} else {
			t.Fatalf("concurrent review error = %v", item.err)
		}
	}
	if successes != 1 || conflicts != 1 {
		t.Fatalf("concurrent review results = successes %d conflicts %d, want one each", successes, conflicts)
	}

	events, err := q.ListAuditEvents(ctx, nil, 20)
	if err != nil {
		t.Fatalf("list report audit events: %v", err)
	}
	var reportEvents int
	for _, event := range events {
		if event.Action == "report_resolve" {
			reportEvents++
		}
	}
	if reportEvents != 1 {
		t.Fatalf("report resolve audit events = %d, want 1", reportEvents)
	}
}

func TestReportServiceRetainsStructuredTargetAfterDeletion(t *testing.T) {
	_, q := setupPool(t)
	ctx := context.Background()
	reporterID := uuid.New()
	targetID := uuid.New()
	insertReportTestUser(t, q, reporterID, "target-reporter")
	insertReportTestUser(t, q, targetID, "target-user")

	targetKind := "user"
	created, err := NewReportService(q).Submit(ctx, ReportSubmission{
		ID: reporterID, ReporterID: reporterID, TargetID: &targetID, TargetKind: &targetKind, Body: "target details",
	})
	if err != nil {
		t.Fatalf("submit targeted report: %v", err)
	}
	if created.TargetName == nil || *created.TargetName != "target-user" || created.TargetDeleted {
		t.Fatalf("target snapshot = %#v, want active target-user", created)
	}
	if err := q.SoftDeleteUser(ctx, targetID); err != nil {
		t.Fatalf("delete target: %v", err)
	}
	stored, err := q.GetReport(ctx, created.ID)
	if err != nil || stored == nil || !stored.TargetDeleted || stored.TargetName == nil || *stored.TargetName != "target-user" {
		t.Fatalf("target after deletion = %#v err=%v", stored, err)
	}
	if err := q.HardDeleteUser(ctx, targetID); err != nil {
		t.Fatalf("hard delete target: %v", err)
	}
	stored, err = q.GetReport(ctx, created.ID)
	if err != nil || stored == nil || !stored.TargetDeleted || stored.TargetName == nil || *stored.TargetName != "target-user" {
		t.Fatalf("target after hard deletion = %#v err=%v", stored, err)
	}
}

func TestReportServiceStructuredTargetReplayIgnoresDerivedSnapshotFields(t *testing.T) {
	_, q := setupPool(t)
	ctx := context.Background()
	reporterID := uuid.New()
	targetID := uuid.New()
	insertReportTestUser(t, q, reporterID, "snapshot-reporter")
	insertReportTestUser(t, q, targetID, "snapshot-target")
	targetKind := "user"
	requestID := "structured-replay"
	reports := NewReportService(q)
	first, err := reports.Submit(ctx, ReportSubmission{
		ReporterID: reporterID, TargetID: &targetID, TargetKind: &targetKind,
		Body: "same payload", RequestID: &requestID,
	})
	if err != nil {
		t.Fatalf("first structured submission: %v", err)
	}
	replay, err := reports.Submit(ctx, ReportSubmission{
		ID: uuid.New(), ReporterID: reporterID, TargetID: &targetID, TargetKind: &targetKind,
		Body: "same payload", RequestID: &requestID,
	})
	if err != nil || replay == nil || replay.ID != first.ID {
		t.Fatalf("structured replay = %#v err=%v, want original report", replay, err)
	}
}

func TestReportServiceListUsesStableCursorAndSearch(t *testing.T) {
	_, q := setupPool(t)
	ctx := context.Background()
	reporterID := uuid.New()
	insertReportTestUser(t, q, reporterID, "cursor-reporter")
	reports := NewReportService(q)
	for _, body := range []string{"first details", "second details", "needle details"} {
		if _, err := reports.Submit(ctx, ReportSubmission{ReporterID: reporterID, Body: body}); err != nil {
			t.Fatalf("submit %q: %v", body, err)
		}
	}
	first, err := reports.List(ctx, ReportListInput{Limit: 1})
	if err != nil || len(first.Items) != 1 || first.NextCursor == nil {
		t.Fatalf("first page = %#v err=%v", first, err)
	}
	second, err := reports.List(ctx, ReportListInput{Limit: 1, Cursor: *first.NextCursor})
	if err != nil || len(second.Items) != 1 || second.Items[0].ID == first.Items[0].ID {
		t.Fatalf("second page = %#v err=%v", second, err)
	}
	search, err := reports.List(ctx, ReportListInput{Limit: 10, Search: "NEEDLE"})
	if err != nil || len(search.Items) != 1 || search.Items[0].Body != "needle details" {
		t.Fatalf("search page = %#v err=%v", search, err)
	}
}

func TestReportCursorRoundTripIsBounded(t *testing.T) {
	id := uuid.New()
	cursor, err := encodeReportCursor(reportCursor{CreatedAt: testReportCursorTime(), ID: id})
	if err != nil {
		t.Fatalf("encode cursor: %v", err)
	}
	decoded, err := decodeReportCursor(cursor)
	if err != nil || decoded.ID != id || !decoded.CreatedAt.Equal(testReportCursorTime()) {
		t.Fatalf("decoded cursor = %#v, err=%v", decoded, err)
	}
	if len(cursor) > MaxReportCursorBytes {
		t.Fatalf("cursor length = %d, max %d", len(cursor), MaxReportCursorBytes)
	}
	if _, err := decodeReportCursor(strings.Repeat("x", MaxReportCursorBytes+1)); !errors.Is(err, apperrors.ErrBadRequest) {
		t.Fatalf("oversized cursor error = %v, want bad request", err)
	}
}

func testReportCursorTime() time.Time {
	return time.Date(2026, 1, 2, 3, 4, 5, 6, time.UTC)
}
