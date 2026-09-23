package service

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
)

func TestAudienceValidationRejectsEmptySelectionAndMismatchedFilter(t *testing.T) {
	if err := (Audience{Kind: AudienceSelected, Resource: AudienceAccounts}).Validate(); err == nil {
		t.Fatal("empty selected audience was accepted")
	}
	if err := (Audience{
		Kind: AudienceFilterKind, Resource: AudienceReports,
		Filter: &AudienceFilter{Resource: AudienceAccounts},
	}).Validate(); err == nil {
		t.Fatal("filter resource mismatch was accepted")
	}
}

func TestActionValidationSanitizesHTMLAndBindsPayloadHash(t *testing.T) {
	action := AdminAction{Kind: ActionEmail, Subject: "Notice", Body: "Hello", MessageHTML: "<p>Hello</p><script>steal()</script>"}
	clean, err := action.ValidateAndSanitize()
	if err != nil {
		t.Fatalf("validate action: %v", err)
	}
	if clean.MessageHTML == action.MessageHTML || clean.MessageHTML == "" {
		t.Fatalf("message html was not sanitized: %q", clean.MessageHTML)
	}
	if got := clean.PayloadHash(); got == "" {
		t.Fatal("payload hash is empty")
	}
	if got := clean.PayloadHash(); got != clean.PayloadHash() {
		t.Fatal("payload hash is not deterministic")
	}
	if _, err := (AdminAction{Kind: ActionEmail, Subject: "Notice", Body: "Hello"}).ValidateAndSanitize(); err != nil {
		t.Fatalf("optional html was rejected: %v", err)
	}
	if _, err := (AdminAction{Kind: ActionLoginLink}).ValidateAndSanitize(); err != nil {
		t.Fatalf("optional login-link reason was rejected: %v", err)
	}
}

func TestAudiencePreviewPersistsImmutableActorBoundSnapshot(t *testing.T) {
	actorID := uuid.New()
	store := NewMemoryAdminStore()
	store.Users = append(store.Users, AdminUser{ID: uuid.New(), Username: "alice", Email: stringPtr("alice@example.com"), EmailVerified: true})
	svc := NewAdminAudienceService(store)
	preview, err := svc.Preview(context.Background(), AdminActor{ID: actorID, Capabilities: []string{"audience.preview", "campaign.email"}}, AudiencePreviewRequest{
		Audience: Audience{Kind: AudienceSelected, Resource: AudienceAccounts, IDs: []uuid.UUID{store.Users[0].ID}},
		Action:   AdminAction{Kind: ActionEmail, Subject: "Notice", Body: "Hello"},
	})
	if err != nil {
		t.Fatalf("preview: %v", err)
	}
	if preview.SnapshotID == uuid.Nil || preview.ActorID != actorID || preview.AccountCount != 1 || preview.EligibleCount != 1 {
		t.Fatalf("unexpected preview: %#v", preview)
	}
	if err := svc.CommitCheck(context.Background(), AdminActor{ID: actorID, Capabilities: []string{"jobs.create", "campaign.email"}}, preview.SnapshotID, preview.PayloadHash, preview.Action); err != nil {
		t.Fatalf("commit check: %v", err)
	}
	if err := svc.CommitCheck(context.Background(), AdminActor{ID: uuid.New(), Capabilities: []string{"jobs.create", "campaign.email"}}, preview.SnapshotID, preview.PayloadHash, preview.Action); err == nil {
		t.Fatal("different actor was allowed to commit snapshot")
	}
}

func TestAudiencePreviewShrinksRecipientsForEmailAndPushEligibility(t *testing.T) {
	store := NewMemoryAdminStore()
	email := "alice@example.com"
	store.Users = append(store.Users,
		AdminUser{ID: uuid.New(), Username: "alice", Email: &email, EmailVerified: true, RegisteredDeviceCount: 1},
		AdminUser{ID: uuid.New(), Username: "opted-out", Email: &email, EmailVerified: true, RegisteredDeviceCount: 1, CommunicationOptOut: true},
		AdminUser{ID: uuid.New(), Username: "no-device", Email: &email, EmailVerified: true},
	)
	actor := AdminActor{ID: uuid.New(), Capabilities: []string{"audience.preview", "campaign.email", "campaign.push"}, RecentMFAAt: ptrTimeForAudienceTest(time.Now().UTC()), RecentMFAAction: ActionEmail}
	svc := NewAdminAudienceService(store)
	all := Audience{Kind: AudienceAll, Resource: AudienceAccounts}
	emailPreview, err := svc.Preview(context.Background(), actor, AudiencePreviewRequest{Audience: all, Action: AdminAction{Kind: ActionEmail, Subject: "Notice", Body: "Hello"}})
	if err != nil {
		t.Fatalf("email preview: %v", err)
	}
	if emailPreview.EligibleCount != 2 || emailPreview.ExclusionCount != 1 {
		t.Fatalf("email eligibility counts = eligible %d excluded %d", emailPreview.EligibleCount, emailPreview.ExclusionCount)
	}
	actor.RecentMFAAction = ActionPush
	pushPreview, err := svc.Preview(context.Background(), actor, AudiencePreviewRequest{Audience: all, Action: AdminAction{Kind: ActionPush, Title: "Notice", Body: "Hello"}})
	if err != nil {
		t.Fatalf("push preview: %v", err)
	}
	if pushPreview.EligibleCount != 1 || pushPreview.ExclusionCount != 2 {
		t.Fatalf("push eligibility counts = eligible %d excluded %d", pushPreview.EligibleCount, pushPreview.ExclusionCount)
	}
}

func TestAllAudienceRequiresActionBoundRecentMFA(t *testing.T) {
	store := NewMemoryAdminStore()
	email := "alice@example.com"
	store.Users = append(store.Users, AdminUser{ID: uuid.New(), Username: "alice", Email: &email, EmailVerified: true})
	actor := AdminActor{ID: uuid.New(), Capabilities: []string{"audience.preview", "campaign.email"}}
	request := AudiencePreviewRequest{Audience: Audience{Kind: AudienceAll, Resource: AudienceAccounts}, Action: AdminAction{Kind: ActionEmail, Subject: "A", Body: "B"}}
	if _, err := NewAdminAudienceService(store).Preview(context.Background(), actor, request); err != ErrRecentMFARequired {
		t.Fatalf("missing all-audience mfa error = %v, want recent mfa", err)
	}
}

func TestFilteredAudienceShowsAdminExclusionWithoutBroadcasting(t *testing.T) {
	store := NewMemoryAdminStore()
	email := "admin@example.com"
	adminID := uuid.New()
	store.Users = append(store.Users, AdminUser{ID: adminID, Username: "admin", Email: &email, EmailVerified: true, IsAdmin: true})
	actor := AdminActor{ID: uuid.New(), Capabilities: []string{"audience.preview", "campaign.email"}}
	filter := &AudienceFilter{Resource: AudienceAccounts, Username: stringPtr("admin")}
	preview, err := NewAdminAudienceService(store).Preview(context.Background(), actor, AudiencePreviewRequest{Audience: Audience{Kind: AudienceFilterKind, Resource: AudienceAccounts, Filter: filter}, Action: AdminAction{Kind: ActionEmail, Subject: "Notice", Body: "Hello"}})
	if err != nil {
		t.Fatalf("preview: %v", err)
	}
	if preview.AccountCount != 1 || preview.EligibleCount != 0 || preview.ExclusionCount != 1 || len(preview.Exclusions) != 1 {
		t.Fatalf("admin exclusion = %#v", preview)
	}
}

func TestAudienceSnapshotCopiesFilterCriteria(t *testing.T) {
	store := NewMemoryAdminStore()
	email := "alice@example.com"
	userID := uuid.New()
	store.Users = append(store.Users, AdminUser{ID: userID, Username: "alice", Email: &email, EmailVerified: true})
	username := "alice"
	audience := Audience{Kind: AudienceFilterKind, Resource: AudienceAccounts, Filter: &AudienceFilter{Resource: AudienceAccounts, Username: &username}}
	actor := AdminActor{ID: uuid.New(), Capabilities: []string{"audience.preview", "campaign.email"}}
	preview, err := NewAdminAudienceService(store).Preview(context.Background(), actor, AudiencePreviewRequest{Audience: audience, Action: AdminAction{Kind: ActionEmail, Subject: "A", Body: "B"}})
	if err != nil {
		t.Fatalf("preview: %v", err)
	}
	username = "changed"
	snapshot, err := store.GetAudienceSnapshot(context.Background(), preview.SnapshotID)
	if err != nil || snapshot.Audience.Filter == nil || snapshot.Audience.Filter.Username == nil || *snapshot.Audience.Filter.Username != "alice" {
		t.Fatalf("snapshot criteria changed with caller input: %#v, %v", snapshot, err)
	}
}

func TestAudienceSnapshotPaginationUsesStableOrdinalCursor(t *testing.T) {
	store := NewMemoryAdminStore()
	ids := make([]uuid.UUID, 0, 3)
	for i := 0; i < 3; i++ {
		id := uuid.New()
		ids = append(ids, id)
		email := "user" + string(rune('a'+i)) + "@example.com"
		store.Users = append(store.Users, AdminUser{ID: id, Username: email, Email: &email, EmailVerified: true})
	}
	actor := AdminActor{ID: uuid.New(), Capabilities: []string{"audience.preview", "audience.read", "campaign.email"}}
	svc := NewAdminAudienceService(store)
	preview, err := svc.Preview(context.Background(), actor, AudiencePreviewRequest{Audience: Audience{Kind: AudienceSelected, Resource: AudienceAccounts, IDs: ids}, Action: AdminAction{Kind: ActionEmail, Subject: "A", Body: "B"}})
	if err != nil {
		t.Fatalf("preview: %v", err)
	}
	first, err := svc.Get(context.Background(), actor, preview.SnapshotID, "", 1)
	if err != nil || len(first.Items) != 1 || first.Next == nil {
		t.Fatalf("first page = %#v, %v", first, err)
	}
	second, err := svc.Get(context.Background(), actor, preview.SnapshotID, *first.Next, 1)
	if err != nil || len(second.Items) != 1 || second.Items[0].ResourceID == first.Items[0].ResourceID {
		t.Fatalf("second page = %#v, %v", second, err)
	}
}

func ptrTimeForAudienceTest(value time.Time) *time.Time { return &value }
