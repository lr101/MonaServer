package db

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
)

func TestAdminExecutionStoreFencesClaimsAndTerminalizesUnknownDelivery(t *testing.T) {
	q, cleanup := t02Database(t)
	defer cleanup()
	ctx := context.Background()
	actorID := uuid.New()
	if _, err := q.Pool().Exec(ctx, `
		INSERT INTO users (id, username, password, creation_date, update_date)
		VALUES ($1, 'execution-auditor', 'hash', now(), now())`, actorID); err != nil {
		t.Fatalf("create audit actor: %v", err)
	}
	snapshotID := uuid.New()
	if err := q.CreateAudienceSnapshot(ctx, AudienceSnapshotParams{ID: snapshotID, Resource: AudienceResourceAccounts, Action: "email", PayloadHash: []byte("payload"), ExpiresAt: time.Now().Add(time.Hour)}); err != nil {
		t.Fatalf("create snapshot: %v", err)
	}
	job, err := q.CreateAdminJob(ctx, AdminJobParams{ID: uuid.New(), SnapshotID: &snapshotID, Action: "email", PayloadHash: []byte("payload"), IdempotencyKey: uuid.NewString()})
	if err != nil {
		t.Fatalf("create job: %v", err)
	}
	itemID, targetID := uuid.New(), uuid.New()
	if err := q.AddAdminJobItem(ctx, AdminJobItemParams{ID: itemID, JobID: job.ID, TargetID: targetID}); err != nil {
		t.Fatalf("add item: %v", err)
	}
	first, claimed, err := q.ClaimAdminJobItemWithFence(ctx, job.ID, itemID, "worker-a", time.Minute)
	if err != nil || !claimed || first == nil || first.OperationID == uuid.Nil || first.LeaseFence != 1 {
		t.Fatalf("first claim = %#v, claimed=%v, err=%v", first, claimed, err)
	}
	if _, err := q.Pool().Exec(ctx, `UPDATE admin_job_items SET lease_until = clock_timestamp() - interval '1 second' WHERE id = $1`, itemID); err != nil {
		t.Fatalf("expire first lease: %v", err)
	}
	second, claimed, err := q.ClaimAdminJobItemWithFence(ctx, job.ID, itemID, "worker-b", time.Minute)
	if err != nil || !claimed || second == nil || second.LeaseFence <= first.LeaseFence || second.OperationID != first.OperationID {
		t.Fatalf("second claim = %#v, claimed=%v, err=%v", second, claimed, err)
	}
	if _, accepted, err := q.FinishAdminJobItemWithFence(ctx, itemID, first.LeaseToken, first.LeaseFence, first.OperationID, "failed", nil, nil, nil, false, false); err != nil || accepted {
		t.Fatalf("stale finish accepted=%v err=%v", accepted, err)
	}
	if _, err := q.Pool().Exec(ctx, `UPDATE admin_job_items SET lease_until = clock_timestamp() - interval '1 second' WHERE id = $1`, itemID); err != nil {
		t.Fatalf("expire second lease: %v", err)
	}
	audit := AdminJobItemAuditParams{JobID: job.ID, ItemID: itemID, OperationID: second.OperationID, ActorID: actorID, TargetID: targetID, Action: "email", Outcome: "unknown_delivery"}
	unknown, committed, err := q.CommitAdminJobItemUnknownDeliveryAfterLeaseLoss(ctx, itemID, second.LeaseToken, second.LeaseFence, second.OperationID, audit)
	if err != nil || !committed || unknown == nil || unknown.Outcome != "unknown_delivery" || unknown.CompletedAt == nil || !unknown.Ambiguous {
		t.Fatalf("lease-loss commit = %#v, committed=%v, err=%v", unknown, committed, err)
	}
	if _, claimed, err := q.ClaimAdminJobItemWithFence(ctx, job.ID, itemID, "worker-c", time.Minute); err != nil || claimed {
		t.Fatalf("terminal unknown claim=%v err=%v", claimed, err)
	}
	var auditCount int
	if err := q.Pool().QueryRow(ctx, `SELECT count(*) FROM audit_events WHERE admin_job_item_id = $1 AND lease_fence = $2`, itemID, second.LeaseFence).Scan(&auditCount); err != nil || auditCount != 1 {
		t.Fatalf("transition audit count=%d err=%v", auditCount, err)
	}
}
