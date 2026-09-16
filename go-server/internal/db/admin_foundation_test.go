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
			outbox_events, device_registrations, communication_preferences
		CASCADE`); err != nil {
		pool.Close()
		t.Fatalf("truncate: %v", err)
	}
	q := New(pool)
	return q, pool.Close
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
	adminJob, err := q.CreateAdminJob(ctx, AdminJobParams{ID: uuid.New(), SnapshotID: &snapshotID, Action: "lease", PayloadHash: []byte("p"), IdempotencyKey: "admin-lease"})
	if err != nil {
		t.Fatalf("admin job create: %v", err)
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
