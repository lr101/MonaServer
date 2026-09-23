package db

import (
	"context"
	"crypto/sha256"
	"errors"
	"os"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

func t02Database(t *testing.T) (*Queries, func()) {
	t.Helper()
	dsn := os.Getenv("TEST_DATABASE_URL")
	if dsn == "" {
		t.Skip("TEST_DATABASE_URL not set; skipping T02 integration test")
	}
	if err := RunMigrations(dsn); err != nil {
		t.Fatalf("migrations: %v", err)
	}
	pool, err := NewPool(context.Background(), dsn)
	if err != nil {
		t.Fatalf("pool: %v", err)
	}
	if _, err := pool.Exec(context.Background(), `
		TRUNCATE TABLE
			users, email_login_claims, delivery_attempts, account_action_tokens,
			admin_memberships, admin_sessions, admin_login_challenges,
			admin_mfa_replay_counters, security_incidents, audit_events,
			rate_limit_buckets, reports, report_notes, audience_snapshots,
			audience_snapshot_members, admin_jobs, admin_job_items, durable_jobs,
			outbox_events, device_registrations, communication_preferences, campaigns
		CASCADE`); err != nil {
		pool.Close()
		t.Fatalf("truncate: %v", err)
	}
	q := New(pool)
	return q, pool.Close
}

func TestCampaignFacadeUsesRevisionAndDraftDeletePredicates(t *testing.T) {
	q, cleanup := t02Database(t)
	defer cleanup()
	ctx := context.Background()
	creator := uuid.New()
	if _, err := q.Pool().Exec(ctx, `
		INSERT INTO users (id, username, password, email_confirmed, creation_date, update_date)
		VALUES ($1, 'campaign-facade-user', 'hash', FALSE, NOW(), NOW())`, creator); err != nil {
		t.Fatalf("insert campaign creator: %v", err)
	}
	subject := "September"
	created, err := q.CreateCampaign(ctx, CampaignParams{
		ID: uuid.New(), Name: "Newsletter", Channel: "email", Subject: &subject,
		Body: "Hello", Status: "draft", CreatedByUserID: creator,
	})
	if err != nil {
		t.Fatalf("create campaign: %v", err)
	}
	if created.Revision != 1 || created.CreatedByUserID == nil || *created.CreatedByUserID != creator {
		t.Fatalf("created campaign = %#v, want revision one and creator", created)
	}
	if err := q.HardDeleteUser(ctx, creator); err != nil {
		t.Fatalf("hard delete campaign creator: %v", err)
	}
	var creatorAfterDelete *uuid.UUID
	if err := q.Pool().QueryRow(ctx, `SELECT created_by_user_id FROM campaigns WHERE id = $1`, created.ID).Scan(&creatorAfterDelete); err != nil {
		t.Fatalf("read campaign creator after delete: %v", err)
	}
	if creatorAfterDelete != nil {
		t.Fatalf("campaign creator after account deletion = %v, want nil", creatorAfterDelete)
	}

	page, err := q.ListCampaigns(ctx, CampaignQuery{Limit: 1})
	if err != nil || len(page) != 1 || page[0].ID != created.ID {
		t.Fatalf("list campaigns = %#v, %v", page, err)
	}
	updated, ok, err := q.UpdateCampaignIfRevision(ctx, created.ID, created.Revision, CampaignUpdate{
		Name: "Newsletter revised", Channel: "email", Subject: &subject, Body: "Updated", Status: "active",
	})
	if err != nil || !ok || updated.Revision != 2 || updated.Status != "active" {
		t.Fatalf("update campaign = %#v, ok=%t, err=%v", updated, ok, err)
	}
	if _, ok, err := q.UpdateCampaignIfRevision(ctx, created.ID, created.Revision, CampaignUpdate{Name: "stale", Channel: "email", Subject: &subject, Body: "Updated", Status: "active"}); err != nil || ok {
		t.Fatalf("stale update ok=%t, err=%v, want false nil", ok, err)
	}
	if deleted, err := q.DeleteCampaignIfRevision(ctx, created.ID, updated.Revision); err != nil || deleted {
		t.Fatalf("delete active campaign = %t, %v; want false nil", deleted, err)
	}
	if _, ok, err := q.UpdateCampaignIfRevision(ctx, created.ID, updated.Revision, CampaignUpdate{Name: updated.Name, Channel: updated.Channel, Subject: updated.Subject, Title: updated.Title, Body: updated.Body, Status: "draft"}); err != nil || !ok {
		t.Fatalf("return campaign to draft ok=%t, err=%v", ok, err)
	}
	if deleted, err := q.DeleteCampaignIfRevision(ctx, created.ID, 3); err != nil || !deleted {
		t.Fatalf("delete draft campaign = %t, %v; want true nil", deleted, err)
	}
}

func TestT02BackfillsCanonicalEmailClaimsWithoutChoosingDuplicateOwner(t *testing.T) {
	q, cleanup := t02Database(t)
	defer cleanup()
	ctx := context.Background()
	first := uuid.New()
	second := uuid.New()
	third := uuid.New()
	for _, user := range []struct {
		id       uuid.UUID
		username string
		email    string
	}{
		{first, "first", " Alice@example.test "},
		{second, "second", "alice@EXAMPLE.test"},
		{third, "third", "Unique@example.test"},
	} {
		if _, err := q.Pool().Exec(ctx, `
			INSERT INTO users (id, username, email, password, email_confirmed, creation_date, update_date)
			VALUES ($1, $2, $3, 'hash', TRUE, NOW(), NOW())`, user.id, user.username, user.email); err != nil {
			t.Fatalf("insert user: %v", err)
		}
	}
	if err := q.BackfillEmailLoginClaims(ctx); err != nil {
		t.Fatalf("backfill claims: %v", err)
	}
	duplicate, err := q.GetEmailLoginClaim(ctx, "ALICE@example.test")
	if err != nil {
		t.Fatalf("duplicate claim: %v", err)
	}
	if duplicate == nil || duplicate.State != EmailClaimBlocked || duplicate.OwnerUserID != nil {
		t.Fatalf("duplicate claim = %#v, want blocked without owner", duplicate)
	}
	unique, err := q.GetEmailLoginClaim(ctx, " unique@example.test ")
	if err != nil {
		t.Fatalf("unique claim: %v", err)
	}
	if unique == nil || unique.State != EmailClaimOwned || unique.OwnerUserID == nil || *unique.OwnerUserID != third {
		t.Fatalf("unique claim = %#v, want owner %s", unique, third)
	}
}

func TestT02ConcurrentEmailConfirmationHasOneClaimOwner(t *testing.T) {
	q, cleanup := t02Database(t)
	defer cleanup()
	ctx := context.Background()
	first, second := uuid.New(), uuid.New()
	for i, user := range []struct {
		id uuid.UUID
	}{
		{first}, {second},
	} {
		if _, err := q.Pool().Exec(ctx, `
			INSERT INTO users (id, username, email, password, email_confirmed, creation_date, update_date)
			VALUES ($1, $2, 'same@example.test', 'hash', FALSE, NOW(), NOW())`, user.id, string(rune('a'+i))); err != nil {
			t.Fatalf("insert user: %v", err)
		}
	}
	results := make(chan bool, 2)
	var wg sync.WaitGroup
	for _, id := range []uuid.UUID{first, second} {
		wg.Add(1)
		go func(id uuid.UUID) {
			defer wg.Done()
			ok, err := q.ConfirmUserEmailWithClaim(ctx, id)
			if err != nil {
				t.Errorf("confirm %s: %v", id, err)
			}
			results <- ok
		}(id)
	}
	wg.Wait()
	close(results)
	var successes int
	for ok := range results {
		if ok {
			successes++
		}
	}
	if successes != 1 {
		t.Fatalf("successful confirmations = %d, want one", successes)
	}
	claim, err := q.GetEmailLoginClaim(ctx, "same@example.test")
	if err != nil {
		t.Fatalf("read claim: %v", err)
	}
	if claim == nil || claim.State != EmailClaimOwned || claim.OwnerUserID == nil {
		t.Fatalf("claim = %#v, want one owner", claim)
	}
}

func TestT02ActionTokenConsumeIsSingleUse(t *testing.T) {
	q, cleanup := t02Database(t)
	defer cleanup()
	ctx := context.Background()
	accountID := uuid.New()
	if _, err := q.Pool().Exec(ctx, `
		INSERT INTO users (id, username, password, email_confirmed, creation_date, update_date)
		VALUES ($1, 'token-user', 'hash', FALSE, NOW(), NOW())`, accountID); err != nil {
		t.Fatalf("insert user: %v", err)
	}
	secretHash := sha256.Sum256([]byte("opaque-token"))
	tokenID := uuid.New()
	if err := q.CreateAccountActionToken(ctx, AccountActionTokenParams{
		ID: tokenID, AccountID: accountID, TokenHash: secretHash[:], Purpose: ActionTokenPurposeLoginLink,
		AuthGeneration: 0, ExpiresAt: time.Now().Add(time.Hour),
	}); err != nil {
		t.Fatalf("create token: %v", err)
	}
	otherHash := sha256.Sum256([]byte("other-opaque-token"))
	if err := q.CreateAccountActionToken(ctx, AccountActionTokenParams{
		ID: uuid.New(), AccountID: accountID, TokenHash: otherHash[:], Purpose: ActionTokenPurposeLoginLink,
		AuthGeneration: 0, ExpiresAt: time.Now().Add(time.Hour),
	}); err != nil {
		t.Fatalf("create sibling token: %v", err)
	}
	results := make(chan bool, 2)
	var wg sync.WaitGroup
	for range 2 {
		wg.Add(1)
		go func() {
			defer wg.Done()
			_, consumed, err := q.ConsumeAccountActionToken(ctx, secretHash[:], ActionTokenPurposeLoginLink, time.Now())
			if err != nil {
				t.Errorf("consume token: %v", err)
			}
			results <- consumed
		}()
	}
	wg.Wait()
	close(results)
	var consumed int
	for ok := range results {
		if ok {
			consumed++
		}
	}
	if consumed != 1 {
		t.Fatalf("consumers = %d, want one", consumed)
	}
	sibling, err := q.GetAccountActionTokenByHash(ctx, otherHash[:])
	if err != nil || sibling == nil || sibling.RevokedAt == nil {
		t.Fatalf("sibling token after successful login = %#v err=%v", sibling, err)
	}
}

func TestT02RecoveryTokenCanBeConsumedForCompromisedAccount(t *testing.T) {
	q, cleanup := t02Database(t)
	defer cleanup()
	ctx := context.Background()
	accountID := uuid.New()
	if _, err := q.Pool().Exec(ctx, `
		INSERT INTO users
			(id, username, password, email, email_confirmed, auth_generation,
			 security_state, password_disabled, password_reset_required,
			 creation_date, update_date)
		VALUES ($1, 'restricted-recovery-user', 'hash', 'recovery@example.test', TRUE, 1,
				'compromised', TRUE, TRUE, NOW(), NOW())`, accountID); err != nil {
		t.Fatalf("insert restricted user: %v", err)
	}
	hash := sha256.Sum256([]byte("restricted-recovery-token"))
	if err := q.CreateAccountActionToken(ctx, AccountActionTokenParams{
		ID: uuid.New(), AccountID: accountID, TokenHash: hash[:], Purpose: ActionTokenPurposeRecovery,
		AuthGeneration: 1, EmailBinding: strptr("recovery@example.test"), ExpiresAt: time.Now().Add(time.Minute),
	}); err != nil {
		t.Fatalf("create recovery token: %v", err)
	}

	token, consumed, err := q.ConsumeAccountActionToken(ctx, hash[:], ActionTokenPurposeRecovery, time.Now())
	if err != nil {
		t.Fatalf("consume recovery token: %v", err)
	}
	if !consumed || token == nil || token.Purpose != ActionTokenPurposeRecovery {
		t.Fatalf("recovery token = %#v, consumed=%v; want consumed recovery token", token, consumed)
	}
}

func TestT02SnapshotCursorDistinguishesInitialFromOrdinalZero(t *testing.T) {
	q, cleanup := t02Database(t)
	defer cleanup()
	ctx := context.Background()
	snapshotID := uuid.New()
	firstID, secondID := uuid.New(), uuid.New()
	if err := q.CreateAudienceSnapshot(ctx, AudienceSnapshotParams{
		ID: snapshotID, Resource: AudienceResourceAccounts, Action: "cursor",
		PayloadHash: []byte("cursor"), ExpiresAt: time.Now().Add(time.Hour),
	}); err != nil {
		t.Fatalf("create snapshot: %v", err)
	}
	if err := q.AddAudienceSnapshotMember(ctx, snapshotID, 0, firstID, true, nil); err != nil {
		t.Fatalf("add first member: %v", err)
	}
	if err := q.AddAudienceSnapshotMember(ctx, snapshotID, 1, secondID, true, nil); err != nil {
		t.Fatalf("add second member: %v", err)
	}

	initial, err := q.ListAudienceSnapshotMembers(ctx, snapshotID, 1, -1)
	if err != nil {
		t.Fatalf("list initial page: %v", err)
	}
	if len(initial) != 1 || initial[0].Ordinal != 0 || initial[0].ResourceID != firstID {
		t.Fatalf("initial page = %#v, want ordinal zero", initial)
	}
	afterZero, err := q.ListAudienceSnapshotMembers(ctx, snapshotID, 1, 0)
	if err != nil {
		t.Fatalf("list after ordinal zero: %v", err)
	}
	if len(afterZero) != 1 || afterZero[0].Ordinal != 1 || afterZero[0].ResourceID != secondID {
		t.Fatalf("page after ordinal zero = %#v, want ordinal one", afterZero)
	}
}

func TestT02SnapshotOrdinalIsUniquePerSnapshot(t *testing.T) {
	q, cleanup := t02Database(t)
	defer cleanup()
	ctx := context.Background()
	snapshotID := uuid.New()
	if err := q.CreateAudienceSnapshot(ctx, AudienceSnapshotParams{
		ID: snapshotID, Resource: AudienceResourceAccounts, Action: "ordinal",
		PayloadHash: []byte("ordinal"), ExpiresAt: time.Now().Add(time.Hour),
	}); err != nil {
		t.Fatalf("create snapshot: %v", err)
	}
	if err := q.AddAudienceSnapshotMember(ctx, snapshotID, 0, uuid.New(), true, nil); err != nil {
		t.Fatalf("add first member: %v", err)
	}
	if err := q.AddAudienceSnapshotMember(ctx, snapshotID, 0, uuid.New(), true, nil); err == nil {
		t.Fatal("duplicate snapshot ordinal was accepted")
	}
}

func TestT02TouchAdminSessionCapsIdleExpiryAtAbsoluteExpiry(t *testing.T) {
	q, cleanup := t02Database(t)
	defer cleanup()
	ctx := context.Background()
	userID := uuid.New()
	if _, err := q.Pool().Exec(ctx, `
		INSERT INTO users (id, username, password, email_confirmed, creation_date, update_date)
		VALUES ($1, 'session-bound-user', 'hash', FALSE, NOW(), NOW())`, userID); err != nil {
		t.Fatalf("insert session user: %v", err)
	}
	now := time.Now().UTC()
	abs := now.Add(2 * time.Minute)
	if err := q.CreateAdminSession(ctx, AdminSessionParams{
		ID: uuid.New(), SessionHash: []byte("absolute-session"), UserID: userID,
		CSRFHash: []byte("csrf"), State: "authenticated", IdleExpiresAt: now.Add(time.Minute),
		AbsoluteExpiresAt: abs,
	}); err != nil {
		t.Fatalf("create admin session: %v", err)
	}
	if err := q.TouchAdminSession(ctx, []byte("absolute-session"), abs.Add(time.Hour)); err != nil {
		t.Fatalf("touch admin session: %v", err)
	}
	session, err := q.GetAdminSessionByHash(ctx, []byte("absolute-session"))
	if err != nil {
		t.Fatalf("read admin session: %v", err)
	}
	if session == nil || !session.IdleExpiresAt.Equal(session.AbsoluteExpiresAt) {
		t.Fatalf("session after touch = %#v, want idle expiry capped at absolute expiry", session)
	}
}

func TestT02TransactionFacadeDoesNotExposePool(t *testing.T) {
	q, cleanup := t02Database(t)
	defer cleanup()
	ctx := context.Background()
	if q.Pool() == nil {
		t.Fatal("root query facade lost its pool")
	}
	if err := q.InTx(ctx, func(tx *Queries) error {
		if tx.Pool() != nil {
			return errors.New("transaction facade exposes root pool")
		}
		return nil
	}); err != nil {
		t.Fatalf("transaction facade pool exposure: %v", err)
	}
}

func TestT02DurableLeaseRejectsStaleAcknowledgement(t *testing.T) {
	q, cleanup := t02Database(t)
	defer cleanup()
	ctx := context.Background()
	jobID := uuid.New()
	if err := q.CreateDurableJob(ctx, DurableJobParams{
		ID: jobID, Kind: "test", IdempotencyKey: "lease-test", Payload: []byte(`{"ok":true}`),
		AvailableAt: time.Now().Add(-time.Second), MaxAttempts: 3,
	}); err != nil {
		t.Fatalf("create durable job: %v", err)
	}
	first, err := q.ClaimDurableJobs(ctx, "worker-a", 1, time.Minute)
	if err != nil {
		t.Fatalf("first claim: %v", err)
	}
	second, err := q.ClaimDurableJobs(ctx, "worker-b", 1, time.Minute)
	if err != nil {
		t.Fatalf("second claim: %v", err)
	}
	if len(first) != 1 || len(second) != 0 {
		t.Fatalf("claims = %d and %d, want one owner", len(first), len(second))
	}
	if ok, err := q.FinishDurableJob(ctx, jobID, "worker-b", first[0].LeaseToken, DurableJobCompleted); err != nil {
		t.Fatalf("stale finish: %v", err)
	} else if ok {
		t.Fatal("stale worker acknowledged another worker's lease")
	}
	if ok, err := q.FinishDurableJob(ctx, jobID, "worker-a", first[0].LeaseToken, DurableJobCompleted); err != nil {
		t.Fatalf("finish: %v", err)
	} else if !ok {
		t.Fatal("lease owner could not finish job")
	}
}

func TestT02DurableClaimByKindsKeepsQueueFamiliesIsolated(t *testing.T) {
	q, cleanup := t02Database(t)
	defer cleanup()
	ctx := context.Background()
	now := time.Now().UTC().Add(-time.Second)
	authID, bulkID := uuid.New(), uuid.New()
	if err := q.CreateDurableJob(ctx, DurableJobParams{
		ID: authID, Kind: "auth.email", IdempotencyKey: "auth-lane", Payload: []byte(`{"lane":"auth"}`),
		AvailableAt: now, MaxAttempts: 3,
	}); err != nil {
		t.Fatalf("create auth job: %v", err)
	}
	if err := q.CreateDurableJob(ctx, DurableJobParams{
		ID: bulkID, Kind: "bulk.email", IdempotencyKey: "bulk-lane", Payload: []byte(`{"lane":"bulk"}`),
		AvailableAt: now, MaxAttempts: 3,
	}); err != nil {
		t.Fatalf("create bulk job: %v", err)
	}

	authClaims, err := q.ClaimDurableJobsByKinds(ctx, "auth-worker", []string{"auth.email"}, 2, time.Minute)
	if err != nil {
		t.Fatalf("claim auth lane: %v", err)
	}
	if len(authClaims) != 1 || authClaims[0].ID != authID || authClaims[0].Kind != "auth.email" {
		t.Fatalf("auth claims = %#v, want only auth job", authClaims)
	}
	if authClaims[0].LeaseOwner == nil || *authClaims[0].LeaseOwner != "auth-worker" || authClaims[0].LeaseToken == uuid.Nil || authClaims[0].LeaseUntil == nil {
		t.Fatalf("auth claim lease = %#v, want owner/token/expiry", authClaims[0])
	}

	bulkClaims, err := q.ClaimDurableJobsByKinds(ctx, "bulk-worker", []string{"bulk.email"}, 2, time.Minute)
	if err != nil {
		t.Fatalf("claim bulk lane: %v", err)
	}
	if len(bulkClaims) != 1 || bulkClaims[0].ID != bulkID || bulkClaims[0].Kind != "bulk.email" {
		t.Fatalf("bulk claims = %#v, want only bulk job", bulkClaims)
	}
	if bulkClaims[0].LeaseOwner == nil || *bulkClaims[0].LeaseOwner != "bulk-worker" || bulkClaims[0].LeaseToken == uuid.Nil || bulkClaims[0].LeaseUntil == nil {
		t.Fatalf("bulk claim lease = %#v, want owner/token/expiry", bulkClaims[0])
	}
}

func TestT02DeliveryPayloadClearsOnlyTerminalOutcomes(t *testing.T) {
	q, cleanup := t02Database(t)
	defer cleanup()
	ctx := context.Background()
	now := time.Now().UTC()
	newAttempt := func(t *testing.T, id uuid.UUID, status string, expiresAt time.Time) {
		t.Helper()
		if err := q.CreateDeliveryAttempt(ctx, DeliveryAttemptParams{
			ID: id, Channel: "email", Status: status, AttemptNumber: 0,
			EncryptedPayload: []byte("ciphertext-" + id.String()), DeliveryKeyID: strptr("delivery-key"),
			PayloadExpiresAt: timePtr(expiresAt),
		}); err != nil {
			t.Fatalf("create delivery attempt %s: %v", id, err)
		}
	}

	acceptedID := uuid.New()
	newAttempt(t, acceptedID, "pending", now.Add(time.Hour))
	acceptedAt := now
	if err := q.UpdateDeliveryAttemptOutcome(ctx, acceptedID, "accepted", strptr("provider-accepted"), strptr("accepted"), nil, &acceptedAt); err != nil {
		t.Fatalf("record accepted outcome: %v", err)
	}
	cleared, err := q.ClearDeliveryAttemptPayload(ctx, acceptedID, now)
	if err != nil || !cleared {
		t.Fatalf("clear accepted payload = %t, err=%v; want true", cleared, err)
	}
	accepted, err := q.GetDeliveryAttempt(ctx, acceptedID)
	if err != nil || accepted == nil || accepted.EncryptedPayload != nil || accepted.DeliveryKeyID != nil {
		t.Fatalf("accepted attempt = %#v, err=%v; want payload and key cleared", accepted, err)
	}

	failedID := uuid.New()
	newAttempt(t, failedID, "pending", now.Add(time.Hour))
	if err := q.UpdateDeliveryAttemptOutcome(ctx, failedID, "failed", nil, strptr("failed"), strptr("permanent"), nil); err != nil {
		t.Fatalf("record terminal failure: %v", err)
	}
	cleared, err = q.ClearDeliveryAttemptPayload(ctx, failedID, now)
	if err != nil || !cleared {
		t.Fatalf("clear failed payload = %t, err=%v; want true", cleared, err)
	}

	transientID := uuid.New()
	newAttempt(t, transientID, "pending", now.Add(time.Hour))
	if err := q.UpdateDeliveryAttemptOutcome(ctx, transientID, "unknown_delivery", nil, strptr("transient"), strptr("provider_unavailable"), nil); err != nil {
		t.Fatalf("record transient outcome: %v", err)
	}
	cleared, err = q.ClearDeliveryAttemptPayload(ctx, transientID, now)
	if err != nil || cleared {
		t.Fatalf("clear transient payload = %t, err=%v; want false", cleared, err)
	}
	transient, err := q.GetDeliveryAttempt(ctx, transientID)
	if err != nil || transient == nil || len(transient.EncryptedPayload) == 0 || transient.DeliveryKeyID == nil {
		t.Fatalf("transient attempt = %#v, err=%v; want retry payload retained", transient, err)
	}

	expiredID := uuid.New()
	newAttempt(t, expiredID, "unknown_delivery", now.Add(-time.Second))
	cleared, err = q.ClearDeliveryAttemptPayload(ctx, expiredID, now)
	if err != nil || !cleared {
		t.Fatalf("clear expired payload = %t, err=%v; want true", cleared, err)
	}
	expired, err := q.GetDeliveryAttempt(ctx, expiredID)
	if err != nil || expired == nil || expired.EncryptedPayload != nil || expired.DeliveryKeyID != nil {
		t.Fatalf("expired attempt = %#v, err=%v; want payload and key cleared", expired, err)
	}
}

func TestT02RotatedQuotaKeysShareOneWindow(t *testing.T) {
	q, cleanup := t02Database(t)
	defer cleanup()
	ctx := context.Background()
	now := time.Now().UTC().Truncate(time.Minute)
	keys := []SharedQuotaKey{
		{Scope: "public-email", IdentifierHMAC: []byte("old-key-hmac"), KeyID: "old", WindowStart: now, WindowEnd: now.Add(time.Hour), Limit: 3},
		{Scope: "public-email", IdentifierHMAC: []byte("new-key-hmac"), KeyID: "new", WindowStart: now, WindowEnd: now.Add(time.Hour), Limit: 3},
	}
	for i := int64(0); i < 3; i++ {
		decision, err := q.AcquireSharedQuota(ctx, keys, 1)
		if err != nil {
			t.Fatalf("quota acquire %d: %v", i, err)
		}
		if !decision.Allowed {
			t.Fatalf("quota acquire %d denied before limit: %#v", i, decision)
		}
	}
	decision, err := q.AcquireSharedQuota(ctx, keys, 1)
	if err != nil {
		t.Fatalf("quota over-limit acquire: %v", err)
	}
	if decision.Allowed {
		t.Fatal("rotated quota keys bypassed shared limit")
	}
}

func TestT02SnapshotMembersRemainStableAfterSourceChanges(t *testing.T) {
	q, cleanup := t02Database(t)
	defer cleanup()
	ctx := context.Background()
	first, second := uuid.New(), uuid.New()
	snapshotID := uuid.New()
	if err := q.CreateAudienceSnapshot(ctx, AudienceSnapshotParams{
		ID: snapshotID, ActorID: uuid.Nil, Resource: AudienceResourceAccounts, Action: "email",
		PayloadHash: []byte("payload"), ExpiresAt: time.Now().Add(time.Hour),
	}); err != nil {
		t.Fatalf("create snapshot: %v", err)
	}
	if err := q.AddAudienceSnapshotMembers(ctx, snapshotID, []uuid.UUID{first, second}); err != nil {
		t.Fatalf("add members: %v", err)
	}
	if err := q.AddAudienceSnapshotMembers(ctx, snapshotID, []uuid.UUID{first}); err != nil {
		t.Fatalf("idempotent member insert: %v", err)
	}
	members, err := q.ListAudienceSnapshotMembers(ctx, snapshotID, 10, InitialAudienceSnapshotOrdinal)
	if err != nil {
		t.Fatalf("list members: %v", err)
	}
	if len(members) != 2 || members[0].ResourceID != first || members[1].ResourceID != second {
		t.Fatalf("members = %#v, want stable two-member order", members)
	}
}

func TestT02EmailChangeAndDeletionFenceAllCredentials(t *testing.T) {
	q, cleanup := t02Database(t)
	defer cleanup()
	ctx := context.Background()
	userID := uuid.New()
	if _, err := q.Pool().Exec(ctx, `
		INSERT INTO users (id, username, email, password, email_confirmed, creation_date, update_date)
		VALUES ($1, 'lifecycle-user', 'old@example.test', 'hash', FALSE, NOW(), NOW())`, userID); err != nil {
		t.Fatalf("insert user: %v", err)
	}
	if ok, err := q.ConfirmUserEmailWithClaim(ctx, userID); err != nil || !ok {
		t.Fatalf("confirm initial address: ok=%v err=%v", ok, err)
	}
	oldClaim, err := q.GetEmailLoginClaim(ctx, "old@example.test")
	if err != nil || oldClaim == nil || oldClaim.State != EmailClaimOwned {
		t.Fatalf("initial claim = %#v err=%v", oldClaim, err)
	}
	hash := sha256.Sum256([]byte("lifecycle-token"))
	tokenID := uuid.New()
	if err := q.CreateAccountActionToken(ctx, AccountActionTokenParams{
		ID: tokenID, AccountID: userID, TokenHash: hash[:], Purpose: ActionTokenPurposeLoginLink,
		AuthGeneration: 0, EmailBinding: strptr("old@example.test"), ExpiresAt: time.Now().Add(time.Hour),
	}); err != nil {
		t.Fatalf("create action token: %v", err)
	}
	newEmail := "new@example.test"
	if err := q.ChangeUserEmail(ctx, userID, &newEmail, nil); err != nil {
		t.Fatalf("change email: %v", err)
	}
	oldClaim, err = q.GetEmailLoginClaim(ctx, "old@example.test")
	if err != nil || oldClaim == nil || oldClaim.State != EmailClaimAvailable || oldClaim.OwnerUserID != nil {
		t.Fatalf("old claim after change = %#v err=%v", oldClaim, err)
	}
	updated, err := q.GetUserByID(ctx, userID)
	if err != nil || updated == nil || updated.Email == nil || *updated.Email != newEmail || updated.EmailConfirmed {
		t.Fatalf("user after change = %#v err=%v", updated, err)
	}
	storedToken, err := q.GetAccountActionTokenByHash(ctx, hash[:])
	if err != nil || storedToken == nil || storedToken.RevokedAt == nil {
		t.Fatalf("old action token after change = %#v err=%v", storedToken, err)
	}
	if ok, err := q.ConfirmUserEmailWithClaim(ctx, userID); err != nil || !ok {
		t.Fatalf("confirm new address: ok=%v err=%v", ok, err)
	}
	if err := q.CreateSecurityIncident(ctx, SecurityIncidentParams{
		ID: uuid.New(), AccountID: userID, Reason: "test containment", NewState: SecurityStateDeleted,
		AuthGeneration: 1,
	}); err != nil {
		t.Fatalf("create incident: %v", err)
	}
	refreshToken, err := q.CreateRefreshToken(ctx, userID)
	if err != nil {
		t.Fatalf("create refresh token: %v", err)
	}
	adminSessionHash := []byte("session-hash")
	now := time.Now()
	if err := q.UpsertAdminMembership(ctx, AdminMembershipParams{ID: uuid.New(), UserID: userID, Active: true}); err != nil {
		t.Fatalf("membership: %v", err)
	}
	if err := q.CreateAdminSession(ctx, AdminSessionParams{
		ID: uuid.New(), SessionHash: adminSessionHash, UserID: userID, CSRFHash: []byte("csrf"),
		State: "authenticated", AuthGeneration: 1, IdleExpiresAt: now.Add(time.Minute), AbsoluteExpiresAt: now.Add(time.Hour),
	}); err != nil {
		t.Fatalf("session: %v", err)
	}
	challengeID := uuid.New()
	if err := q.CreateAdminLoginChallenge(ctx, AdminLoginChallengeParams{
		ID: challengeID, ChallengeHash: []byte("challenge"), UserID: &userID, AuthGeneration: 1, ExpiresAt: now.Add(time.Minute),
	}); err != nil {
		t.Fatalf("challenge: %v", err)
	}
	if err := q.SoftDeleteUser(ctx, userID); err != nil {
		t.Fatalf("soft delete: %v", err)
	}
	state, err := q.GetUserSecurityState(ctx, userID)
	if err != nil || state == nil || !state.IsDeleted || state.SecurityState != SecurityStateDeleted || !state.PasswordDisabled || !state.PasswordResetRequired || state.AuthGeneration != 1 {
		t.Fatalf("security state after delete = %#v err=%v", state, err)
	}
	claim, err := q.GetEmailLoginClaim(ctx, newEmail)
	if err != nil || claim == nil || claim.State != EmailClaimAvailable || claim.OwnerUserID != nil {
		t.Fatalf("new claim after delete = %#v err=%v", claim, err)
	}
	var refreshCount int
	if err := q.Pool().QueryRow(ctx, `SELECT count(*) FROM refresh_token WHERE token = $1`, refreshToken).Scan(&refreshCount); err != nil {
		t.Fatalf("count refresh tokens: %v", err)
	}
	if refreshCount != 0 {
		t.Fatalf("refresh token count after delete = %d", refreshCount)
	}
	session, err := q.GetAdminSessionByHash(ctx, adminSessionHash)
	if err != nil || session == nil || session.RevokedAt == nil {
		t.Fatalf("session after delete = %#v err=%v", session, err)
	}
	membership, err := q.GetAdminMembership(ctx, userID)
	if err != nil || membership == nil || membership.Active || membership.RevokedAt == nil {
		t.Fatalf("membership after delete = %#v err=%v", membership, err)
	}
	if challenge, consumed, err := q.ConsumeAdminLoginChallenge(ctx, challengeID, time.Now()); err != nil || consumed || challenge != nil {
		t.Fatalf("deleted challenge consume = %#v consumed=%v err=%v", challenge, consumed, err)
	}
	if err := q.HardDeleteUser(ctx, userID); err != nil {
		t.Fatalf("hard delete: %v", err)
	}
	deleted, err := q.GetUserByID(ctx, userID)
	if err != nil || deleted != nil {
		t.Fatalf("hard deleted user = %#v err=%v", deleted, err)
	}
	var incidents int
	if err := q.Pool().QueryRow(ctx, `SELECT count(*) FROM security_incidents WHERE account_id = $1`, userID).Scan(&incidents); err != nil {
		t.Fatalf("incident retention: %v", err)
	}
	if incidents != 1 {
		t.Fatalf("retained incidents = %d, want one", incidents)
	}
}

func TestT02QuotaIsAtomicAcrossConcurrentCallers(t *testing.T) {
	q, cleanup := t02Database(t)
	defer cleanup()
	ctx := context.Background()
	now := time.Now().UTC().Truncate(time.Minute)
	keys := []SharedQuotaKey{
		{Scope: "public-email", IdentifierHMAC: []byte("old"), KeyID: "old", WindowStart: now, WindowEnd: now.Add(time.Hour), Limit: 3},
		{Scope: "public-email", IdentifierHMAC: []byte("new"), KeyID: "new", WindowStart: now, WindowEnd: now.Add(time.Hour), Limit: 3},
	}
	results := make(chan bool, 12)
	var wg sync.WaitGroup
	for range 12 {
		wg.Add(1)
		go func() {
			defer wg.Done()
			decision, err := q.AcquireSharedQuota(ctx, keys, 1)
			if err != nil {
				t.Errorf("quota acquire: %v", err)
				return
			}
			results <- decision.Allowed
		}()
	}
	wg.Wait()
	close(results)
	allowed := 0
	for ok := range results {
		if ok {
			allowed++
		}
	}
	if allowed != 3 {
		t.Fatalf("concurrent quota grants = %d, want three", allowed)
	}
}

func TestT02AllLeaseKindsRejectExpiredWorkers(t *testing.T) {
	q, cleanup := t02Database(t)
	defer cleanup()
	ctx := context.Background()
	lease := 40 * time.Millisecond
	jobID := uuid.New()
	if err := q.CreateDurableJob(ctx, DurableJobParams{ID: jobID, Kind: "lease", IdempotencyKey: "durable", AvailableAt: time.Now().Add(-time.Second), MaxAttempts: 4}); err != nil {
		t.Fatalf("durable create: %v", err)
	}
	first, err := q.ClaimDurableJobs(ctx, "worker-a", 1, lease)
	if err != nil || len(first) != 1 {
		t.Fatalf("durable first claim = %#v err=%v", first, err)
	}
	time.Sleep(lease + 30*time.Millisecond)
	second, err := q.ClaimDurableJobs(ctx, "worker-b", 1, time.Minute)
	if err != nil || len(second) != 1 || second[0].LeaseToken == first[0].LeaseToken {
		t.Fatalf("durable second claim = %#v err=%v", second, err)
	}
	if ok, err := q.FinishDurableJob(ctx, jobID, "worker-a", first[0].LeaseToken, DurableJobCompleted); err != nil || ok {
		t.Fatalf("stale durable finish: ok=%v err=%v", ok, err)
	}
	if ok, err := q.FinishDurableJob(ctx, jobID, "worker-b", second[0].LeaseToken, DurableJobCompleted); err != nil || !ok {
		t.Fatalf("fresh durable finish: ok=%v err=%v", ok, err)
	}

	snapshotID := uuid.New()
	if err := q.CreateAudienceSnapshot(ctx, AudienceSnapshotParams{ID: snapshotID, Resource: AudienceResourceAccounts, Action: "lease", PayloadHash: []byte("p"), ExpiresAt: time.Now().Add(time.Hour)}); err != nil {
		t.Fatalf("snapshot create: %v", err)
	}
	recentMFAAt := time.Now().UTC().Truncate(time.Microsecond)
	recentMFAAction := "revoke_sessions"
	adminJob, err := q.CreateAdminJob(ctx, AdminJobParams{ID: uuid.New(), SnapshotID: &snapshotID, Action: "lease", PayloadHash: []byte("p"), IdempotencyKey: "admin-lease", RecentMFAAt: &recentMFAAt, RecentMFAAction: &recentMFAAction})
	if err != nil {
		t.Fatalf("admin job create: %v", err)
	}
	if adminJob.RecentMFAAt == nil || !adminJob.RecentMFAAt.Equal(recentMFAAt) || adminJob.RecentMFAAction == nil || *adminJob.RecentMFAAction != recentMFAAction {
		t.Fatalf("admin job MFA proof = %#v, %#v; want durable action-bound proof", adminJob.RecentMFAAt, adminJob.RecentMFAAction)
	}
	loadedJob, err := q.GetAdminJob(ctx, adminJob.ID)
	if err != nil || loadedJob == nil || loadedJob.RecentMFAAt == nil || !loadedJob.RecentMFAAt.Equal(recentMFAAt) || loadedJob.RecentMFAAction == nil || *loadedJob.RecentMFAAction != recentMFAAction {
		t.Fatalf("loaded admin job MFA proof = %#v, err=%v; want durable action-bound proof", loadedJob, err)
	}
	listedJobs, err := q.ListAdminJobs(ctx, "pending", nil, 10)
	if err != nil || len(listedJobs) != 1 || listedJobs[0].RecentMFAAt == nil || !listedJobs[0].RecentMFAAt.Equal(recentMFAAt) || listedJobs[0].RecentMFAAction == nil || *listedJobs[0].RecentMFAAction != recentMFAAction {
		t.Fatalf("listed admin job MFA proof = %#v, err=%v; want durable action-bound proof", listedJobs, err)
	}
	itemID := uuid.New()
	if err := q.AddAdminJobItem(ctx, AdminJobItemParams{ID: itemID, JobID: adminJob.ID, TargetID: uuid.New()}); err != nil {
		t.Fatalf("item create: %v", err)
	}
	claimedItem, err := q.ClaimAdminJobItems(ctx, adminJob.ID, "worker-a", 1, lease)
	if err != nil || len(claimedItem) != 1 {
		t.Fatalf("item first claim = %#v err=%v", claimedItem, err)
	}
	time.Sleep(lease + 30*time.Millisecond)
	reclaimedItem, err := q.ClaimAdminJobItems(ctx, adminJob.ID, "worker-b", 1, time.Minute)
	if err != nil || len(reclaimedItem) != 1 || reclaimedItem[0].LeaseToken == claimedItem[0].LeaseToken {
		t.Fatalf("item second claim = %#v err=%v", reclaimedItem, err)
	}
	if ok, err := q.FinishAdminJobItem(ctx, itemID, "worker-a", claimedItem[0].LeaseToken, "failed", nil, nil); err != nil || ok {
		t.Fatalf("stale item finish: ok=%v err=%v", ok, err)
	}
	if ok, err := q.FinishAdminJobItem(ctx, itemID, "worker-b", reclaimedItem[0].LeaseToken, "provider_accepted", nil, nil); err != nil || !ok {
		t.Fatalf("fresh item finish: ok=%v err=%v", ok, err)
	}

	outboxID := uuid.New()
	if err := q.CreateOutboxEvent(ctx, OutboxEventParams{ID: outboxID, Topic: "lease", IdempotencyKey: "outbox-lease", AvailableAt: time.Now().Add(-time.Second)}); err != nil {
		t.Fatalf("outbox create: %v", err)
	}
	claimedOutbox, err := q.ClaimOutboxEvents(ctx, "worker-a", 1, lease)
	if err != nil || len(claimedOutbox) != 1 {
		t.Fatalf("outbox first claim = %#v err=%v", claimedOutbox, err)
	}
	time.Sleep(lease + 30*time.Millisecond)
	reclaimedOutbox, err := q.ClaimOutboxEvents(ctx, "worker-b", 1, time.Minute)
	if err != nil || len(reclaimedOutbox) != 1 || reclaimedOutbox[0].LeaseToken == claimedOutbox[0].LeaseToken {
		t.Fatalf("outbox second claim = %#v err=%v", reclaimedOutbox, err)
	}
	if ok, err := q.FinishOutboxEvent(ctx, outboxID, "worker-a", claimedOutbox[0].LeaseToken, "accepted"); err != nil || ok {
		t.Fatalf("stale outbox finish: ok=%v err=%v", ok, err)
	}
	if ok, err := q.FinishOutboxEvent(ctx, outboxID, "worker-b", reclaimedOutbox[0].LeaseToken, "accepted"); err != nil || !ok {
		t.Fatalf("fresh outbox finish: ok=%v err=%v", ok, err)
	}
}

func TestT02AdminJobItemClaimFenceRejectsStaleWorkerAcknowledgements(t *testing.T) {
	q, cleanup := t02Database(t)
	defer cleanup()
	ctx := context.Background()

	snapshotID := uuid.New()
	if err := q.CreateAudienceSnapshot(ctx, AudienceSnapshotParams{
		ID: snapshotID, Resource: AudienceResourceAccounts, Action: "lease-fence",
		PayloadHash: []byte("payload"), ExpiresAt: time.Now().Add(time.Hour),
	}); err != nil {
		t.Fatalf("snapshot create: %v", err)
	}
	adminJob, err := q.CreateAdminJob(ctx, AdminJobParams{
		ID: uuid.New(), SnapshotID: &snapshotID, Action: "lease-fence",
		PayloadHash: []byte("payload"), IdempotencyKey: "admin-item-lease-fence",
	})
	if err != nil {
		t.Fatalf("admin job create: %v", err)
	}
	itemID := uuid.New()
	if err := q.AddAdminJobItem(ctx, AdminJobItemParams{
		ID: itemID, JobID: adminJob.ID, TargetID: uuid.New(),
	}); err != nil {
		t.Fatalf("item create: %v", err)
	}

	first, claimed, err := q.ClaimJobItem(ctx, adminJob.ID, itemID, "worker-a", time.Minute)
	if err != nil {
		t.Fatalf("first item claim: %v", err)
	}
	if !claimed || first == nil || first.LeaseToken == uuid.Nil || first.LeaseOwner == nil || *first.LeaseOwner != "worker-a" {
		t.Fatalf("first item claim = %#v, claimed=%v; want worker-bound token", first, claimed)
	}
	if first.LeaseUntil == nil {
		t.Fatal("first item claim has no lease expiry")
	}

	if _, claimed, err := q.ClaimJobItem(ctx, adminJob.ID, itemID, "worker-b", time.Minute); err != nil {
		t.Fatalf("active item reclaim: %v", err)
	} else if claimed {
		t.Fatal("active item was reclaimed before its lease expired")
	}
	if ok, err := q.HeartbeatJobItem(ctx, itemID, "worker-b", first.LeaseToken, time.Minute); err != nil || ok {
		t.Fatalf("wrong-worker heartbeat: ok=%v err=%v; lease token must remain worker-bound", ok, err)
	}

	// Force expiry in the database so reclaim behavior is deterministic and
	// does not depend on a wall-clock sleep in the test.
	if _, err := q.Pool().Exec(ctx, `
		UPDATE admin_job_items
		SET lease_until = NOW() - interval '1 second'
		WHERE id = $1`, itemID); err != nil {
		t.Fatalf("expire first lease: %v", err)
	}
	second, claimed, err := q.ClaimJobItem(ctx, adminJob.ID, itemID, "worker-b", time.Minute)
	if err != nil {
		t.Fatalf("reclaim item: %v", err)
	}
	if !claimed || second == nil || second.LeaseToken == uuid.Nil || second.LeaseToken == first.LeaseToken {
		t.Fatalf("reclaimed item = %#v, claimed=%v; want a fresh fence token", second, claimed)
	}

	if ok, err := q.FinishJobItem(ctx, itemID, "worker-a", first.LeaseToken, "failed", nil, nil); err != nil || ok {
		t.Fatalf("stale finish: ok=%v err=%v; stale worker must be fenced", ok, err)
	}
	if ok, err := q.HeartbeatJobItem(ctx, itemID, "worker-a", first.LeaseToken, time.Minute); err != nil || ok {
		t.Fatalf("stale heartbeat: ok=%v err=%v; stale worker must be fenced", ok, err)
	}
	if ok, err := q.RetryJobItem(ctx, itemID, "worker-a", first.LeaseToken); err != nil || ok {
		t.Fatalf("stale retry acceptance: ok=%v err=%v; stale worker must be fenced", ok, err)
	}

	if ok, err := q.HeartbeatJobItem(ctx, itemID, "worker-b", second.LeaseToken, time.Minute); err != nil || !ok {
		t.Fatalf("fresh heartbeat: ok=%v err=%v; current worker must retain lease", ok, err)
	}
	if ok, err := q.FinishJobItem(ctx, itemID, "worker-b", second.LeaseToken, "provider_accepted", nil, nil); err != nil || !ok {
		t.Fatalf("fresh finish: ok=%v err=%v", ok, err)
	}
	stored, err := q.GetAdminJobItem(ctx, itemID)
	if err != nil {
		t.Fatalf("read finished item: %v", err)
	}
	if stored == nil || stored.Outcome != "provider_accepted" || stored.LeaseOwner != nil || stored.LeaseToken != uuid.Nil {
		t.Fatalf("finished item = %#v; want terminal outcome with cleared lease", stored)
	}
	if _, err := q.Pool().Exec(ctx, `
		UPDATE admin_job_items
		SET lease_token = $2
		WHERE id = $1`, itemID, uuid.New()); err == nil {
		t.Fatal("database accepted a lease token without its worker and expiry fence")
	}
}

func createAdminLeaseTestItem(t *testing.T, q *Queries, suffix string) (uuid.UUID, uuid.UUID) {
	t.Helper()
	ctx := context.Background()
	snapshotID := uuid.New()
	payload := []byte("payload-" + suffix)
	if err := q.CreateAudienceSnapshot(ctx, AudienceSnapshotParams{
		ID: snapshotID, Resource: AudienceResourceAccounts, Action: "lease-race-" + suffix,
		PayloadHash: payload, ExpiresAt: time.Now().Add(time.Hour),
	}); err != nil {
		t.Fatalf("snapshot create: %v", err)
	}
	adminJob, err := q.CreateAdminJob(ctx, AdminJobParams{
		ID: uuid.New(), SnapshotID: &snapshotID, Action: "lease-race-" + suffix,
		PayloadHash: payload, IdempotencyKey: "admin-item-lease-race-" + uuid.NewString(),
	})
	if err != nil {
		t.Fatalf("admin job create: %v", err)
	}
	itemID := uuid.New()
	if err := q.AddAdminJobItem(ctx, AdminJobItemParams{
		ID: itemID, JobID: adminJob.ID, TargetID: uuid.New(),
	}); err != nil {
		t.Fatalf("item create: %v", err)
	}
	return adminJob.ID, itemID
}

// holdAdminJobItemLock keeps the item tuple locked from a separate connection.
// The lease tests use this to prove that competing statements reached the
// database and queued behind the same row before the lock is released.
func holdAdminJobItemLock(t *testing.T, q *Queries, itemID uuid.UUID) pgx.Tx {
	t.Helper()
	ctx := context.Background()
	tx, err := q.Pool().Begin(ctx)
	if err != nil {
		t.Fatalf("begin item lock: %v", err)
	}
	var lockedID uuid.UUID
	if err := tx.QueryRow(ctx, `
		SELECT id
		FROM admin_job_items
		WHERE id = $1
		FOR UPDATE`, itemID).Scan(&lockedID); err != nil {
		_ = tx.Rollback(ctx)
		t.Fatalf("lock item: %v", err)
	}
	if lockedID != itemID {
		_ = tx.Rollback(ctx)
		t.Fatalf("locked item = %s, want %s", lockedID, itemID)
	}
	return tx
}

func waitForAdminJobItemLockWaiters(t *testing.T, q *Queries, want int) {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	observer, err := pgx.ConnectConfig(ctx, q.Pool().Config().ConnConfig.Copy())
	if err != nil {
		t.Fatalf("connect lock observer: %v", err)
	}
	defer observer.Close(context.Background())
	for {
		var got int
		err := observer.QueryRow(ctx, `
			SELECT count(DISTINCT l.pid)::int
			FROM pg_locks l
			JOIN pg_stat_activity a ON a.pid = l.pid
			WHERE NOT l.granted
			  AND l.pid <> pg_backend_pid()
			  AND a.datname = current_database()
			  AND a.query LIKE '%admin_job_items%'`).Scan(&got)
		if err != nil {
			t.Fatalf("inspect item lock waiters: %v", err)
		}
		if got >= want {
			return
		}
		select {
		case <-ctx.Done():
			t.Fatalf("admin item lock waiters = %d, want at least %d", got, want)
		default:
			time.Sleep(5 * time.Millisecond)
		}
	}
}

func waitForAdminJobItemLeaseExpiry(t *testing.T, q *Queries, itemID uuid.UUID) {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	observer, err := pgx.ConnectConfig(ctx, q.Pool().Config().ConnConfig.Copy())
	if err != nil {
		t.Fatalf("connect lease observer: %v", err)
	}
	defer observer.Close(context.Background())
	for {
		var expired bool
		err := observer.QueryRow(ctx, `
			SELECT lease_until IS NOT NULL AND lease_until <= clock_timestamp()
			FROM admin_job_items
			WHERE id = $1`, itemID).Scan(&expired)
		if err != nil {
			t.Fatalf("inspect item lease expiry: %v", err)
		}
		if expired {
			return
		}
		select {
		case <-ctx.Done():
			t.Fatalf("admin item lease did not expire before timeout")
		default:
			time.Sleep(5 * time.Millisecond)
		}
	}
}

func TestT02AdminJobItemConcurrentClaimsHaveOneWinner(t *testing.T) {
	q, cleanup := t02Database(t)
	defer cleanup()
	ctx := context.Background()
	jobID, itemID := createAdminLeaseTestItem(t, q, "claim")
	holder := holdAdminJobItemLock(t, q, itemID)
	lockReleased := false
	defer func() {
		if !lockReleased {
			_ = holder.Rollback(ctx)
		}
	}()

	type claimResult struct {
		worker  string
		item    *AdminJobItem
		claimed bool
		err     error
	}
	workers := []string{"worker-a", "worker-b"}
	ready := make(chan struct{}, len(workers))
	start := make(chan struct{})
	results := make(chan claimResult, len(workers))
	var wg sync.WaitGroup
	for _, worker := range workers {
		worker := worker
		wg.Add(1)
		go func() {
			defer wg.Done()
			ready <- struct{}{}
			<-start
			item, claimed, err := q.ClaimJobItem(ctx, jobID, itemID, worker, time.Minute)
			results <- claimResult{worker: worker, item: item, claimed: claimed, err: err}
		}()
	}
	for range workers {
		select {
		case <-ready:
		case <-time.After(5 * time.Second):
			t.Fatal("concurrent claim workers did not reach the start barrier")
		}
	}
	close(start)
	waitForAdminJobItemLockWaiters(t, q, len(workers))
	if err := holder.Commit(ctx); err != nil {
		t.Fatalf("release item lock: %v", err)
	}
	lockReleased = true
	wg.Wait()
	close(results)

	var winner claimResult
	winners := 0
	for result := range results {
		if result.err != nil {
			t.Fatalf("%s claim: %v", result.worker, result.err)
		}
		if result.claimed {
			winners++
			winner = result
			continue
		}
		if result.item != nil {
			t.Fatalf("losing claim returned item %#v", result.item)
		}
	}
	if winners != 1 {
		t.Fatalf("concurrent claim winners = %d, want exactly one", winners)
	}
	if winner.item == nil || winner.item.LeaseToken == uuid.Nil || winner.item.LeaseOwner == nil || *winner.item.LeaseOwner != winner.worker {
		t.Fatalf("winning claim = %#v, want worker-bound fence", winner.item)
	}
	stored, err := q.GetAdminJobItem(ctx, itemID)
	if err != nil {
		t.Fatalf("read concurrently claimed item: %v", err)
	}
	if stored == nil || stored.LeaseToken != winner.item.LeaseToken || stored.LeaseOwner == nil || *stored.LeaseOwner != winner.worker {
		t.Fatalf("stored concurrent claim = %#v, want the sole winner's lease", stored)
	}
}

func TestT02AdminJobItemReclaimFencesOverlappingStaleAcknowledgements(t *testing.T) {
	tests := []struct {
		name       string
		stale      func(context.Context, *Queries, uuid.UUID, string, uuid.UUID) (bool, error)
		freshCheck func(*testing.T, context.Context, *Queries, uuid.UUID, string, uuid.UUID)
	}{
		{
			name: "finish",
			stale: func(ctx context.Context, q *Queries, itemID uuid.UUID, worker string, token uuid.UUID) (bool, error) {
				return q.FinishJobItem(ctx, itemID, worker, token, "failed", nil, nil)
			},
			freshCheck: func(t *testing.T, ctx context.Context, q *Queries, itemID uuid.UUID, worker string, token uuid.UUID) {
				t.Helper()
				if ok, err := q.FinishJobItem(ctx, itemID, worker, token, "provider_accepted", nil, nil); err != nil || !ok {
					t.Fatalf("fresh finish: ok=%v err=%v", ok, err)
				}
			},
		},
		{
			name: "heartbeat",
			stale: func(ctx context.Context, q *Queries, itemID uuid.UUID, worker string, token uuid.UUID) (bool, error) {
				return q.HeartbeatJobItem(ctx, itemID, worker, token, time.Minute)
			},
			freshCheck: func(t *testing.T, ctx context.Context, q *Queries, itemID uuid.UUID, worker string, token uuid.UUID) {
				t.Helper()
				if ok, err := q.HeartbeatJobItem(ctx, itemID, worker, token, time.Minute); err != nil || !ok {
					t.Fatalf("fresh heartbeat: ok=%v err=%v", ok, err)
				}
				if ok, err := q.FinishJobItem(ctx, itemID, worker, token, "provider_accepted", nil, nil); err != nil || !ok {
					t.Fatalf("finish after fresh heartbeat: ok=%v err=%v", ok, err)
				}
			},
		},
		{
			name: "retry",
			stale: func(ctx context.Context, q *Queries, itemID uuid.UUID, worker string, token uuid.UUID) (bool, error) {
				return q.RetryJobItem(ctx, itemID, worker, token)
			},
			freshCheck: func(t *testing.T, ctx context.Context, q *Queries, itemID uuid.UUID, worker string, token uuid.UUID) {
				t.Helper()
				if ok, err := q.RetryJobItem(ctx, itemID, worker, token); err != nil || !ok {
					t.Fatalf("fresh retry: ok=%v err=%v", ok, err)
				}
				stored, err := q.GetAdminJobItem(ctx, itemID)
				if err != nil {
					t.Fatalf("read retried item: %v", err)
				}
				if stored == nil || stored.Outcome != "unknown_delivery" || stored.LeaseOwner != nil || stored.LeaseToken != uuid.Nil {
					t.Fatalf("retried item = %#v, want released retry outcome", stored)
				}
			},
		},
	}

	for _, test := range tests {
		test := test
		t.Run(test.name, func(t *testing.T) {
			q, cleanup := t02Database(t)
			defer cleanup()
			ctx := context.Background()
			jobID, itemID := createAdminLeaseTestItem(t, q, "reclaim-"+test.name)
			first, claimed, err := q.ClaimJobItem(ctx, jobID, itemID, "worker-a", time.Second)
			if err != nil {
				t.Fatalf("first claim: %v", err)
			}
			if !claimed || first == nil || first.LeaseToken == uuid.Nil {
				t.Fatalf("first claim = %#v, claimed=%v", first, claimed)
			}

			holder := holdAdminJobItemLock(t, q, itemID)
			lockReleased := false
			defer func() {
				if !lockReleased {
					_ = holder.Rollback(ctx)
				}
			}()
			type callResult struct {
				item    *AdminJobItem
				claimed bool
				ok      bool
				err     error
				txErr   error
			}
			reclaimResult := make(chan callResult, 1)
			staleResult := make(chan callResult, 1)
			var wg sync.WaitGroup
			staleTxStarted := make(chan error, 1)
			allowStaleAck := make(chan struct{})
			// Start the stale worker's transaction while the original lease is
			// still valid, then queue its acknowledgement behind the row lock.
			wg.Add(1)
			go func() {
				defer wg.Done()
				var result callResult
				result.txErr = q.InTx(ctx, func(txQ *Queries) error {
					var validAtStart bool
					if err := txQ.runner.QueryRow(ctx, `
						SELECT lease_until > clock_timestamp()
						FROM admin_job_items
						WHERE id = $1`, itemID).Scan(&validAtStart); err != nil {
						staleTxStarted <- err
						return err
					}
					if !validAtStart {
						err := errors.New("stale acknowledgement transaction did not start with an active lease")
						staleTxStarted <- err
						return err
					}
					staleTxStarted <- nil
					<-allowStaleAck
					result.ok, result.err = test.stale(ctx, txQ, itemID, "worker-a", first.LeaseToken)
					return result.err
				})
				staleResult <- result
			}()
			select {
			case err := <-staleTxStarted:
				if err != nil {
					t.Fatalf("start stale acknowledgement transaction: %v", err)
				}
			case <-time.After(5 * time.Second):
				t.Fatal("stale acknowledgement transaction did not start")
			}
			waitForAdminJobItemLeaseExpiry(t, q, itemID)

			reclaimReachedDB := make(chan struct{})
			wg.Add(1)
			go func() {
				defer wg.Done()
				close(reclaimReachedDB)
				item, reclaimed, err := q.ClaimJobItem(ctx, jobID, itemID, "worker-b", time.Minute)
				reclaimResult <- callResult{item: item, claimed: reclaimed, err: err}
			}()
			select {
			case <-reclaimReachedDB:
			case <-time.After(5 * time.Second):
				t.Fatal("reclaim worker did not start")
			}
			// Wait for the reclaim statement to queue behind the held tuple before
			// starting the stale acknowledgement.  This makes the database ordering
			// observable and ensures reclaim installs the fresh lease first.
			waitForAdminJobItemLockWaiters(t, q, 1)
			close(allowStaleAck)
			waitForAdminJobItemLockWaiters(t, q, 2)
			if err := holder.Commit(ctx); err != nil {
				t.Fatalf("release item lock: %v", err)
			}
			lockReleased = true
			wg.Wait()
			reclaimed := <-reclaimResult
			stale := <-staleResult
			if reclaimed.err != nil {
				t.Fatalf("reclaim: %v", reclaimed.err)
			}
			if !reclaimed.claimed || reclaimed.item == nil || reclaimed.item.LeaseToken == uuid.Nil || reclaimed.item.LeaseToken == first.LeaseToken {
				t.Fatalf("reclaim = %#v, claimed=%v; want fresh lease fence", reclaimed.item, reclaimed.claimed)
			}
			if reclaimed.item.LeaseUntil == nil || !reclaimed.item.LeaseUntil.After(time.Now()) {
				t.Fatalf("reclaimed lease_until = %#v, want an unexpired lease while stale acknowledgement is evaluated", reclaimed.item.LeaseUntil)
			}
			if stale.err != nil {
				t.Fatalf("stale %s acknowledgement: %v", test.name, stale.err)
			}
			if stale.txErr != nil {
				t.Fatalf("stale %s transaction: %v", test.name, stale.txErr)
			}
			if stale.ok {
				t.Fatalf("stale %s acknowledgement was accepted", test.name)
			}
			if reclaimed.item.LeaseOwner == nil || *reclaimed.item.LeaseOwner != "worker-b" {
				t.Fatalf("reclaimed lease owner = %#v, want worker-b", reclaimed.item.LeaseOwner)
			}
			test.freshCheck(t, ctx, q, itemID, "worker-b", reclaimed.item.LeaseToken)
		})
	}
}

func TestT02AdminJobItemRejectsWrongTokenWhileLeaseIsValid(t *testing.T) {
	q, cleanup := t02Database(t)
	defer cleanup()
	ctx := context.Background()
	jobID, itemID := createAdminLeaseTestItem(t, q, "wrong-token")
	claimed, ok, err := q.ClaimJobItem(ctx, jobID, itemID, "worker-a", time.Minute)
	if err != nil {
		t.Fatalf("claim: %v", err)
	}
	if !ok || claimed == nil || claimed.LeaseToken == uuid.Nil || claimed.LeaseUntil == nil {
		t.Fatalf("claim = %#v, claimed=%v; want an active lease", claimed, ok)
	}
	if !claimed.LeaseUntil.After(time.Now()) {
		t.Fatalf("claim lease_until = %s, want a future expiry", claimed.LeaseUntil)
	}

	wrongToken := uuid.New()
	if wrongToken == claimed.LeaseToken {
		t.Fatal("test token unexpectedly matched claim token")
	}
	if accepted, err := q.FinishJobItem(ctx, itemID, "worker-a", wrongToken, "failed", nil, nil); err != nil || accepted {
		t.Fatalf("wrong-token finish: accepted=%v err=%v; active lease must require its exact token", accepted, err)
	}
	if accepted, err := q.HeartbeatJobItem(ctx, itemID, "worker-a", wrongToken, time.Minute); err != nil || accepted {
		t.Fatalf("wrong-token heartbeat: accepted=%v err=%v; active lease must require its exact token", accepted, err)
	}
	if accepted, err := q.RetryJobItem(ctx, itemID, "worker-a", wrongToken); err != nil || accepted {
		t.Fatalf("wrong-token retry: accepted=%v err=%v; active lease must require its exact token", accepted, err)
	}

	stored, err := q.GetAdminJobItem(ctx, itemID)
	if err != nil {
		t.Fatalf("read after wrong-token acknowledgements: %v", err)
	}
	if stored == nil || stored.Outcome != "queued" || stored.LeaseOwner == nil || *stored.LeaseOwner != "worker-a" || stored.LeaseToken != claimed.LeaseToken || stored.LeaseUntil == nil || !stored.LeaseUntil.After(time.Now()) {
		t.Fatalf("item after wrong-token acknowledgements = %#v; want the original unexpired lease", stored)
	}
}

func TestT02AdminJobItemAcknowledgementRejectsAfterRealExpiryWithoutReclaim(t *testing.T) {
	q, cleanup := t02Database(t)
	defer cleanup()
	ctx := context.Background()
	jobID, itemID := createAdminLeaseTestItem(t, q, "real-expiry")
	claimed, ok, err := q.ClaimJobItem(ctx, jobID, itemID, "worker-a", 100*time.Millisecond)
	if err != nil {
		t.Fatalf("claim: %v", err)
	}
	if !ok || claimed == nil || claimed.LeaseToken == uuid.Nil || claimed.LeaseUntil == nil {
		t.Fatalf("claim = %#v, claimed=%v; want an active lease", claimed, ok)
	}

	holder := holdAdminJobItemLock(t, q, itemID)
	lockReleased := false
	defer func() {
		if !lockReleased {
			_ = holder.Rollback(ctx)
		}
	}()

	type finishResult struct {
		accepted bool
		err      error
		txErr    error
	}
	started := make(chan struct{})
	results := make(chan finishResult, 1)
	go func() {
		var result finishResult
		result.txErr = q.InTx(ctx, func(txQ *Queries) error {
			close(started)
			result.accepted, result.err = txQ.FinishJobItem(ctx, itemID, "worker-a", claimed.LeaseToken, "provider_accepted", nil, nil)
			return result.err
		})
		results <- result
	}()
	select {
	case <-started:
	case <-time.After(5 * time.Second):
		t.Fatal("finish transaction did not start")
	}
	waitForAdminJobItemLockWaiters(t, q, 1)
	waitForAdminJobItemLeaseExpiry(t, q, itemID)
	if err := holder.Commit(ctx); err != nil {
		t.Fatalf("release item lock: %v", err)
	}
	lockReleased = true

	result := <-results
	if result.txErr != nil {
		t.Fatalf("finish transaction: %v", result.txErr)
	}
	if result.err != nil {
		t.Fatalf("finish acknowledgement: %v", result.err)
	}
	if result.accepted {
		t.Fatal("finish acknowledged an expired lease without a reclaim")
	}
	stored, err := q.GetAdminJobItem(ctx, itemID)
	if err != nil {
		t.Fatalf("read expired item: %v", err)
	}
	if stored == nil || stored.Outcome != "queued" || stored.LeaseOwner == nil || *stored.LeaseOwner != "worker-a" || stored.LeaseToken != claimed.LeaseToken {
		t.Fatalf("expired item = %#v; want unchanged lease after rejected acknowledgement", stored)
	}
}

func TestT02AdminJobItemClaimDeadlineUsesWallClockAfterLockWait(t *testing.T) {
	q, cleanup := t02Database(t)
	defer cleanup()
	ctx := context.Background()
	jobID, itemID := createAdminLeaseTestItem(t, q, "claim-deadline")
	holder := holdAdminJobItemLock(t, q, itemID)
	lockReleased := false
	defer func() {
		if !lockReleased {
			_ = holder.Rollback(ctx)
		}
	}()

	type claimResult struct {
		item    *AdminJobItem
		claimed bool
		err     error
	}
	started := make(chan struct{})
	results := make(chan claimResult, 1)
	go func() {
		close(started)
		item, claimed, err := q.ClaimJobItem(ctx, jobID, itemID, "worker-a", 100*time.Millisecond)
		results <- claimResult{item: item, claimed: claimed, err: err}
	}()
	select {
	case <-started:
	case <-time.After(5 * time.Second):
		t.Fatal("claim did not start")
	}
	waitForAdminJobItemLockWaiters(t, q, 1)
	time.Sleep(250 * time.Millisecond)
	if err := holder.Commit(ctx); err != nil {
		t.Fatalf("release item lock: %v", err)
	}
	lockReleased = true

	result := <-results
	if result.err != nil {
		t.Fatalf("claim after lock wait: %v", result.err)
	}
	if !result.claimed || result.item == nil || result.item.LeaseToken == uuid.Nil || result.item.LeaseUntil == nil {
		t.Fatalf("claim after lock wait = %#v, claimed=%v; want a fresh lease", result.item, result.claimed)
	}
	if !result.item.LeaseUntil.After(time.Now()) {
		t.Fatalf("claim lease_until = %s, want a future wall-clock deadline", result.item.LeaseUntil)
	}
}

func TestT02SnapshotAppendAndReportRevisionAreStable(t *testing.T) {
	q, cleanup := t02Database(t)
	defer cleanup()
	ctx := context.Background()
	snapshotID := uuid.New()
	if err := q.CreateAudienceSnapshot(ctx, AudienceSnapshotParams{ID: snapshotID, Resource: AudienceResourceAccounts, Action: "snapshot", PayloadHash: []byte("p"), ExpiresAt: time.Now().Add(time.Hour)}); err != nil {
		t.Fatalf("snapshot create: %v", err)
	}
	ids := make([]uuid.UUID, 20)
	for i := range ids {
		ids[i] = uuid.New()
	}
	var wg sync.WaitGroup
	for _, batch := range [][]uuid.UUID{ids[:10], ids[5:15], ids[15:]} {
		batch := batch
		wg.Add(1)
		go func() {
			defer wg.Done()
			if err := q.AddAudienceSnapshotMembers(ctx, snapshotID, batch); err != nil {
				t.Errorf("append snapshot members: %v", err)
			}
		}()
	}
	wg.Wait()
	members, err := q.ListAudienceSnapshotMembers(ctx, snapshotID, 100, InitialAudienceSnapshotOrdinal)
	if err != nil || len(members) != 20 {
		t.Fatalf("snapshot members = %d err=%v", len(members), err)
	}
	seenOrdinals := make(map[int64]bool, len(members))
	for _, member := range members {
		if member.Ordinal < 0 || member.Ordinal >= int64(len(members)) || seenOrdinals[member.Ordinal] {
			t.Fatalf("unstable member ordinal: %#v", member)
		}
		seenOrdinals[member.Ordinal] = true
	}
	page, err := q.ListAudienceSnapshotMembers(ctx, snapshotID, 5, members[4].Ordinal)
	if err != nil || len(page) != 5 || page[0].Ordinal != 5 {
		t.Fatalf("snapshot page = %#v err=%v", page, err)
	}

	reporterID := uuid.New()
	if _, err := q.Pool().Exec(ctx, `
		INSERT INTO users (id, username, password, email_confirmed, creation_date, update_date)
		VALUES ($1, 'reporter', 'hash', FALSE, NOW(), NOW())`, reporterID); err != nil {
		t.Fatalf("reporter: %v", err)
	}
	requestID := "request-1"
	report, err := q.CreateReport(ctx, ReportParams{ID: uuid.New(), ReporterUserID: &reporterID, Body: "body", RequestID: &requestID})
	if err != nil {
		t.Fatalf("create report: %v", err)
	}
	replay, err := q.CreateReport(ctx, ReportParams{ID: uuid.New(), ReporterUserID: &reporterID, Body: "body", RequestID: &requestID})
	if err != nil || replay == nil || replay.ID != report.ID {
		t.Fatalf("idempotent report = %#v err=%v", replay, err)
	}
	if _, err := q.CreateReport(ctx, ReportParams{ID: uuid.New(), ReporterUserID: &reporterID, Body: "different", RequestID: &requestID}); !errors.Is(err, ErrIdempotencyConflict) {
		t.Fatalf("report conflict err=%v", err)
	}
	updated, ok, err := q.UpdateReportIfRevision(ctx, report.ID, 1, "resolved", nil)
	if err != nil || !ok || updated == nil || updated.Status != "resolved" || updated.Revision != 2 {
		t.Fatalf("report update = %#v ok=%v err=%v", updated, ok, err)
	}
	if _, ok, err := q.UpdateReportIfRevision(ctx, report.ID, 1, "dismissed", nil); err != nil || ok {
		t.Fatalf("stale report update ok=%v err=%v", ok, err)
	}
	if _, err := q.CreateReportNote(ctx, ReportNoteParams{ID: uuid.New(), ReportID: report.ID, AuthorUserID: &reporterID, Body: "note"}); err != nil {
		t.Fatalf("report note: %v", err)
	}
	notes, err := q.ListReportNotes(ctx, report.ID, 10)
	if err != nil || len(notes) != 1 {
		t.Fatalf("report notes = %#v err=%v", notes, err)
	}
}

func TestT02DeliveryDevicesAndPreferencesRoundTrip(t *testing.T) {
	q, cleanup := t02Database(t)
	defer cleanup()
	ctx := context.Background()
	userID := uuid.New()
	if _, err := q.Pool().Exec(ctx, `
		INSERT INTO users (id, username, password, email_confirmed, creation_date, update_date)
		VALUES ($1, 'device-user', 'hash', FALSE, NOW(), NOW())`, userID); err != nil {
		t.Fatalf("user: %v", err)
	}
	device, err := q.UpsertDeviceRegistration(ctx, DeviceRegistrationParams{ID: uuid.New(), UserID: userID, Provider: "firebase", DeviceToken: "device-token", TokenHash: []byte("hash"), Enabled: true})
	if err != nil || device == nil {
		t.Fatalf("device upsert = %#v err=%v", device, err)
	}
	if _, err := q.UpsertCommunicationPreferences(ctx, userID, false, true, false); err != nil {
		t.Fatalf("preferences upsert: %v", err)
	}
	prefs, err := q.GetCommunicationPreferences(ctx, userID)
	if err != nil || prefs == nil || prefs.SecurityEmailEnabled || !prefs.GeneralEmailEnabled || prefs.PushEnabled {
		t.Fatalf("preferences = %#v err=%v", prefs, err)
	}
	devices, err := q.ListDeviceRegistrations(ctx, userID)
	if err != nil || len(devices) != 1 {
		t.Fatalf("devices = %#v err=%v", devices, err)
	}
	if err := q.DisableDeviceRegistration(ctx, device.ID, userID); err != nil {
		t.Fatalf("disable device: %v", err)
	}
	devices, err = q.ListDeviceRegistrations(ctx, userID)
	if err != nil || len(devices) != 0 {
		t.Fatalf("disabled devices = %#v err=%v", devices, err)
	}
	attemptID := uuid.New()
	if err := q.CreateDeliveryAttempt(ctx, DeliveryAttemptParams{ID: attemptID, Channel: "email", Status: "pending", AttemptNumber: 0, EncryptedPayload: []byte("secret"), DeliveryKeyID: strptr("key"), PayloadExpiresAt: timePtr(time.Now().Add(-time.Minute))}); err != nil {
		t.Fatalf("delivery attempt: %v", err)
	}
	if err := q.UpdateDeliveryAttemptOutcome(ctx, attemptID, "accepted", strptr("provider"), strptr("accepted"), nil, timePtr(time.Now())); err != nil {
		t.Fatalf("delivery outcome: %v", err)
	}
	if err := q.ClearExpiredDeliveryPayloads(ctx, time.Now(), time.Now().Add(time.Hour)); err != nil {
		t.Fatalf("clear delivery payload: %v", err)
	}
	attempt, err := q.GetDeliveryAttempt(ctx, attemptID)
	if err != nil || attempt == nil || attempt.EncryptedPayload != nil || attempt.ProviderReference == nil || *attempt.ProviderReference != "provider" {
		t.Fatalf("delivery attempt = %#v err=%v", attempt, err)
	}
}

func strptr(value string) *string { return &value }

func timePtr(value time.Time) *time.Time { return &value }
