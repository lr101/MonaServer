package service

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"

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

func TestReportServiceSameIdempotencyKeyIsAtomicAndQuotaNeutral(t *testing.T) {
	_, q := setupPool(t)
	ctx := context.Background()
	if _, err := q.Pool().Exec(ctx, `TRUNCATE TABLE rate_limit_buckets`); err != nil {
		t.Fatalf("truncate quota buckets: %v", err)
	}
	reporterID := uuid.New()
	insertReportTestUser(t, q, reporterID, "concurrent-idempotency-reporter")
	reports := NewReportService(q, ReportServiceConfig{
		HMACKey:           []byte("concurrent-idempotency-key"),
		SubmissionLimit:   1,
		SubmissionIPLimit: 10,
		SubmissionWindow:  time.Hour,
	})
	requestID := "concurrent-report-request"
	const callers = 8
	start := make(chan struct{})
	results := make(chan struct {
		report *db.Report
		err    error
	}, callers)
	var wg sync.WaitGroup
	for i := 0; i < callers; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			<-start
			report, err := reports.Submit(ctx, ReportSubmission{
				ID: reporterID, ReporterID: reporterID, Body: "same concurrent body", RequestID: &requestID,
				ClientIP: "192.0.2.44",
			})
			results <- struct {
				report *db.Report
				err    error
			}{report: report, err: err}
		}()
	}
	close(start)
	wg.Wait()
	close(results)

	var winner *db.Report
	for result := range results {
		if result.err != nil {
			t.Fatalf("concurrent idempotent submission error = %v", result.err)
		}
		if result.report == nil {
			t.Fatal("concurrent idempotent submission returned no report")
		}
		if winner == nil {
			winner = result.report
		} else if result.report.ID != winner.ID {
			t.Fatalf("concurrent idempotent report IDs = %s and %s", winner.ID, result.report.ID)
		}
	}

	var reportCount, quotaHits int
	if err := q.Pool().QueryRow(ctx, `SELECT count(*) FROM reports WHERE request_id = $1`, requestID).Scan(&reportCount); err != nil {
		t.Fatalf("count idempotent reports: %v", err)
	}
	if err := q.Pool().QueryRow(ctx, `SELECT COALESCE(sum(hit_count), 0) FROM rate_limit_buckets WHERE scope = 'report-submit-account'`).Scan(&quotaHits); err != nil {
		t.Fatalf("count idempotent quota hits: %v", err)
	}
	if reportCount != 1 || quotaHits != 1 {
		t.Fatalf("concurrent idempotency rows=%d quota hits=%d, want one row and one quota hit", reportCount, quotaHits)
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

func TestReportServiceAssigneeOmittedPreservesAndExplicitClearRemoves(t *testing.T) {
	_, q := setupPool(t)
	ctx := context.Background()
	reporterID := uuid.New()
	actorID := uuid.New()
	assigneeID := uuid.New()
	insertReportTestUser(t, q, reporterID, "assignee-reporter")
	insertReportTestUser(t, q, actorID, "assignee-actor")
	insertReportTestUser(t, q, assigneeID, "assignee-user")
	reports := NewReportService(q)
	created, err := reports.Submit(ctx, ReportSubmission{ReporterID: reporterID, Body: "assignment"})
	if err != nil {
		t.Fatalf("submit assignment report: %v", err)
	}
	assigned, err := reports.Review(ctx, ReportReviewInput{
		ReportID: created.ID, ActorID: actorID, ExpectedRevision: created.Revision,
		Status: db.ReportStatusOpen, AssigneeUserID: &assigneeID, AssigneeSet: true,
	})
	if err != nil || assigned.AssigneeUserID == nil || *assigned.AssigneeUserID != assigneeID {
		t.Fatalf("assign report = %#v err=%v", assigned, err)
	}
	preserved, err := reports.Review(ctx, ReportReviewInput{
		ReportID: created.ID, ActorID: actorID, ExpectedRevision: assigned.Revision,
		Status: db.ReportStatusOpen,
	})
	if err != nil || preserved.AssigneeUserID == nil || *preserved.AssigneeUserID != assigneeID {
		t.Fatalf("omitted assignee report = %#v err=%v", preserved, err)
	}
	cleared, err := reports.Review(ctx, ReportReviewInput{
		ReportID: created.ID, ActorID: actorID, ExpectedRevision: preserved.Revision,
		Status: db.ReportStatusOpen, AssigneeSet: true,
	})
	if err != nil || cleared.AssigneeUserID != nil {
		t.Fatalf("explicit assignee clear report = %#v err=%v", cleared, err)
	}
}

func TestReportServiceReviewAuditUsesPriorStatusAndChangeMetadata(t *testing.T) {
	_, q := setupPool(t)
	ctx := context.Background()
	reporterID := uuid.New()
	actorID := uuid.New()
	assigneeID := uuid.New()
	insertReportTestUser(t, q, reporterID, "audit-reporter")
	insertReportTestUser(t, q, actorID, "audit-actor")
	insertReportTestUser(t, q, assigneeID, "audit-assignee")
	reports := NewReportService(q)
	created, err := reports.Submit(ctx, ReportSubmission{ReporterID: reporterID, Body: "audit transition"})
	if err != nil {
		t.Fatalf("submit audit report: %v", err)
	}
	note := "handled with assignment"
	resolved, err := reports.Review(ctx, ReportReviewInput{
		ReportID: created.ID, ActorID: actorID, ExpectedRevision: created.Revision,
		Status: db.ReportStatusResolved, AssigneeUserID: &assigneeID, AssigneeSet: true, Note: &note,
	})
	if err != nil {
		t.Fatalf("resolve audit report: %v", err)
	}
	if _, err := reports.Review(ctx, ReportReviewInput{
		ReportID: created.ID, ActorID: actorID, ExpectedRevision: resolved.Revision,
		Status: db.ReportStatusOpen, AssigneeSet: true,
	}); err != nil {
		t.Fatalf("reopen audit report: %v", err)
	}

	events, err := q.ListAuditEvents(ctx, nil, 20)
	if err != nil {
		t.Fatalf("list audit events: %v", err)
	}
	var resolvedEvent, reopenedEvent *db.AuditEvent
	for i := range events {
		event := &events[i]
		switch event.Action {
		case "report_resolve":
			resolvedEvent = event
		case "report_reopen":
			reopenedEvent = event
		}
	}
	if resolvedEvent == nil || reopenedEvent == nil {
		t.Fatalf("report transition events = %#v", events)
	}
	var metadata map[string]string
	if err := json.Unmarshal(resolvedEvent.Metadata, &metadata); err != nil {
		t.Fatalf("decode resolve metadata: %v", err)
	}
	for key, want := range map[string]string{
		"previous_status":    db.ReportStatusOpen,
		"status":             db.ReportStatusResolved,
		"assignee_user_id":   assigneeID.String(),
		"assignment_changed": "true",
		"note_added":         "true",
	} {
		if metadata[key] != want {
			t.Fatalf("resolve metadata[%q] = %q, want %q; metadata=%v", key, metadata[key], want, metadata)
		}
	}
	metadata = nil
	if err := json.Unmarshal(reopenedEvent.Metadata, &metadata); err != nil {
		t.Fatalf("decode reopen metadata: %v", err)
	}
	if metadata["previous_status"] != db.ReportStatusResolved || metadata["status"] != db.ReportStatusOpen {
		t.Fatalf("reopen status metadata = %v", metadata)
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

func TestReportServiceTargetDeletionRaceMarksReportsDeleted(t *testing.T) {
	_, q := setupPool(t)
	ctx := context.Background()
	reporterID := uuid.New()
	targetID := uuid.New()
	insertReportTestUser(t, q, reporterID, "target-race-reporter")
	insertReportTestUser(t, q, targetID, "target-race-user")
	targetKind := "user"
	reports := NewReportService(q)

	const callers = 12
	start := make(chan struct{})
	results := make(chan *db.Report, callers)
	errorsCh := make(chan error, callers)
	var wg sync.WaitGroup
	for i := 0; i < callers; i++ {
		wg.Add(1)
		go func(index int) {
			defer wg.Done()
			<-start
			report, err := reports.Submit(ctx, ReportSubmission{
				ReporterID: reporterID, TargetID: &targetID, TargetKind: &targetKind,
				Body: fmt.Sprintf("target race %d", index),
			})
			if err != nil {
				errorsCh <- err
				return
			}
			results <- report
		}(i)
	}
	deleteDone := make(chan error, 1)
	go func() {
		<-start
		deleteDone <- q.HardDeleteUser(ctx, targetID)
	}()
	close(start)
	wg.Wait()
	if err := <-deleteDone; err != nil {
		t.Fatalf("hard-delete target during submissions: %v", err)
	}
	close(results)
	close(errorsCh)
	for err := range errorsCh {
		t.Fatalf("target race submission error = %v", err)
	}
	var seen int
	for report := range results {
		seen++
		stored, err := q.GetReport(ctx, report.ID)
		if err != nil || stored == nil || !stored.TargetDeleted {
			t.Fatalf("target race report %s was not marked deleted: %#v err=%v", report.ID, stored, err)
		}
	}
	if seen != callers {
		t.Fatalf("target race reports = %d, want %d", seen, callers)
	}
}

func TestReportServiceConcurrentUserDeleteDoesNotDeadlock(t *testing.T) {
	_, q := setupPool(t)
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	reporterID := uuid.New()
	targetID := uuid.New()
	insertReportTestUser(t, q, reporterID, "user-delete-reporter")
	insertReportTestUser(t, q, targetID, "user-delete-target")
	if _, err := q.Pool().Exec(ctx, `
		UPDATE users
		SET code = '001234', code_expiration = NOW() + INTERVAL '5 minutes'
		WHERE id = $1`, targetID); err != nil {
		t.Fatalf("set deletion code: %v", err)
	}

	targetKind := "user"
	reports := NewReportService(q)
	users := NewUser(q, nil, nil, nil, nil)
	start := make(chan struct{})
	reportResult := make(chan struct {
		report *db.Report
		err    error
	}, 1)
	deleteResult := make(chan error, 1)
	go func() {
		<-start
		report, err := reports.Submit(ctx, ReportSubmission{
			ReporterID: reporterID, TargetID: &targetID, TargetKind: &targetKind,
			Body: "report while account is deleted",
		})
		reportResult <- struct {
			report *db.Report
			err    error
		}{report: report, err: err}
	}()
	go func() {
		<-start
		deleteResult <- users.Delete(ctx, targetID, 1234)
	}()
	close(start)

	var report *db.Report
	select {
	case result := <-reportResult:
		if result.err != nil {
			t.Fatalf("concurrent report submission: %v", result.err)
		}
		report = result.report
	case <-ctx.Done():
		t.Fatalf("report submission deadlocked: %v", ctx.Err())
	}
	select {
	case err := <-deleteResult:
		if err != nil {
			t.Fatalf("concurrent user delete: %v", err)
		}
	case <-ctx.Done():
		t.Fatalf("user delete deadlocked: %v", ctx.Err())
	}
	if report == nil {
		t.Fatal("concurrent submission returned nil report")
	}
	stored, err := q.GetReport(context.Background(), report.ID)
	if err != nil || stored == nil || !stored.TargetDeleted {
		t.Fatalf("report target after User.Delete = %#v err=%v, want deleted", stored, err)
	}
}

func TestReportServiceLockOrderAcquiresUserRowBeforeReportAdvisory(t *testing.T) {
	pool, q := setupPool(t)
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	reporterID := uuid.New()
	submitTargetID := uuid.New()
	hardDeleteTargetID := uuid.New()
	userDeleteTargetID := uuid.New()
	insertReportTestUser(t, q, reporterID, "lock-order-reporter")
	insertReportTestUser(t, q, submitTargetID, "lock-order-submit-target")
	insertReportTestUser(t, q, hardDeleteTargetID, "lock-order-hard-delete-target")
	insertReportTestUser(t, q, userDeleteTargetID, "lock-order-user-delete-target")
	if _, err := q.Pool().Exec(ctx, `
		UPDATE users
		SET code = '001234', code_expiration = NOW() + INTERVAL '5 minutes'
		WHERE id = $1`, userDeleteTargetID); err != nil {
		t.Fatalf("set deletion code: %v", err)
	}

	exercise := func(name string, targetID uuid.UUID, operation func(context.Context) error) {
		t.Run(name, func(t *testing.T) {
			blockerConn, err := pool.Acquire(ctx)
			if err != nil {
				t.Fatalf("acquire advisory blocker connection: %v", err)
			}
			defer blockerConn.Release()
			blockerTx, err := blockerConn.Begin(ctx)
			if err != nil {
				t.Fatalf("begin advisory blocker: %v", err)
			}
			defer func() { _ = blockerTx.Rollback(context.Background()) }()
			if _, err := blockerTx.Exec(ctx, `
				SELECT pg_advisory_xact_lock(hashtextextended('report-target:' || $1::text, 0))`, targetID); err != nil {
				t.Fatalf("hold report advisory lock: %v", err)
			}

			result := make(chan error, 1)
			go func() { result <- operation(ctx) }()
			if err := waitForReportTargetAdvisoryWaiter(ctx, pool, targetID); err != nil {
				t.Fatalf("wait for %s advisory waiter: %v", name, err)
			}
			if err := assertUserRowLocked(ctx, pool, targetID); err != nil {
				t.Fatalf("%s lock order: %v", name, err)
			}

			if err := blockerTx.Rollback(ctx); err != nil {
				t.Fatalf("release advisory blocker: %v", err)
			}
			select {
			case err := <-result:
				if err != nil {
					t.Fatalf("%s after lock release: %v", name, err)
				}
			case <-ctx.Done():
				t.Fatalf("%s did not finish after lock release: %v", name, ctx.Err())
			}
		})
	}

	reports := NewReportService(q)
	exercise("Submit", submitTargetID, func(ctx context.Context) error {
		targetKind := "user"
		_, err := reports.Submit(ctx, ReportSubmission{
			ReporterID: reporterID, TargetID: &submitTargetID, TargetKind: &targetKind,
			Body: "deterministic lock-order submission",
		})
		return err
	})
	exercise("HardDeleteUser", hardDeleteTargetID, func(ctx context.Context) error {
		return q.HardDeleteUser(ctx, hardDeleteTargetID)
	})
	exercise("User.Delete", userDeleteTargetID, func(ctx context.Context) error {
		return NewUser(q, nil, nil, nil, nil).Delete(ctx, userDeleteTargetID, 1234)
	})
}

func waitForReportTargetAdvisoryWaiter(ctx context.Context, pool *pgxpool.Pool, targetID uuid.UUID) error {
	const query = `
		SELECT EXISTS (
			SELECT 1
			FROM pg_locks
			WHERE locktype = 'advisory'
			  AND NOT granted
			  AND classid = (((hashtextextended('report-target:' || $1::text, 0) >> 32) & 4294967295)::oid)
			  AND objid = ((hashtextextended('report-target:' || $1::text, 0) & 4294967295)::oid)
			  AND objsubid = 1
		)`
	ticker := time.NewTicker(5 * time.Millisecond)
	defer ticker.Stop()
	for {
		var waiting bool
		if err := pool.QueryRow(ctx, query, targetID).Scan(&waiting); err != nil {
			return err
		}
		if waiting {
			return nil
		}
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-ticker.C:
		}
	}
}

func assertUserRowLocked(ctx context.Context, pool *pgxpool.Pool, targetID uuid.UUID) error {
	var got uuid.UUID
	err := pool.QueryRow(ctx, `SELECT id FROM users WHERE id = $1 FOR UPDATE NOWAIT`, targetID).Scan(&got)
	if err == nil {
		return fmt.Errorf("row lock was available for %s", got)
	}
	var pgErr *pgconn.PgError
	if !errors.As(err, &pgErr) || pgErr.Code != "55P03" {
		return fmt.Errorf("row lock probe error: %w", err)
	}
	return nil
}

func TestReportServiceStructuredTargetReplayIgnoresDerivedSnapshotFields(t *testing.T) {
	_, q := setupPool(t)
	ctx := context.Background()
	reporterID := uuid.New()
	targetID := uuid.New()
	insertReportTestUser(t, q, reporterID, "snapshot-reporter")
	insertReportTestUser(t, q, targetID, "snapshot-target")
	targetKind := "user"
	targetName := "snapshot-target"
	requestID := "structured-replay"
	reports := NewReportService(q)
	first, err := reports.Submit(ctx, ReportSubmission{
		ReporterID: reporterID, TargetID: &targetID, TargetKind: &targetKind,
		TargetName: &targetName, Body: "same payload", RequestID: &requestID,
	})
	if err != nil {
		t.Fatalf("first structured submission: %v", err)
	}
	if err := q.SoftDeleteUser(ctx, targetID); err != nil {
		t.Fatalf("delete structured replay target: %v", err)
	}
	replay, err := reports.Submit(ctx, ReportSubmission{
		ID: uuid.New(), ReporterID: reporterID, TargetID: &targetID, TargetKind: &targetKind,
		TargetName: &targetName, Body: "same payload", RequestID: &requestID,
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

func TestReportServiceNotesCursorExposesAllNotesNewestFirst(t *testing.T) {
	_, q := setupPool(t)
	ctx := context.Background()
	reporterID := uuid.New()
	actorID := uuid.New()
	insertReportTestUser(t, q, reporterID, "notes-reporter")
	insertReportTestUser(t, q, actorID, "notes-actor")
	reports := NewReportService(q)
	created, err := reports.Submit(ctx, ReportSubmission{ReporterID: reporterID, Body: "many notes"})
	if err != nil {
		t.Fatalf("submit notes report: %v", err)
	}
	for i := 0; i < 105; i++ {
		if _, err := reports.AddNote(ctx, ReportNoteInput{ReportID: created.ID, ActorID: actorID, Body: fmt.Sprintf("note-%03d", i)}); err != nil {
			t.Fatalf("add note %d: %v", i, err)
		}
	}
	first, err := reports.ListNotes(ctx, ReportNoteListInput{ReportID: created.ID, Limit: 100})
	if err != nil || len(first.Items) != 100 || first.NextCursor == nil {
		t.Fatalf("first notes page = %#v err=%v", first, err)
	}
	if first.Items[0].Body != "note-104" || first.Items[99].Body != "note-005" {
		t.Fatalf("first notes order = %q ... %q", first.Items[0].Body, first.Items[99].Body)
	}
	second, err := reports.ListNotes(ctx, ReportNoteListInput{ReportID: created.ID, Cursor: *first.NextCursor, Limit: 100})
	if err != nil || len(second.Items) != 5 || second.NextCursor != nil {
		t.Fatalf("second notes page = %#v err=%v", second, err)
	}
	if second.Items[0].Body != "note-004" || second.Items[4].Body != "note-000" {
		t.Fatalf("second notes order = %q ... %q", second.Items[0].Body, second.Items[4].Body)
	}
	if _, err := reports.AddNote(ctx, ReportNoteInput{ReportID: created.ID, ActorID: actorID, Body: "note-105"}); err != nil {
		t.Fatalf("append note: %v", err)
	}
	fresh, err := reports.ListNotes(ctx, ReportNoteListInput{ReportID: created.ID, Limit: 1})
	if err != nil || len(fresh.Items) != 1 || fresh.Items[0].Body != "note-105" {
		t.Fatalf("fresh appended note page = %#v err=%v", fresh, err)
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
