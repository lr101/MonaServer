package service

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"
)

func TestAdminUserServiceBoundsAndOmitsCredentialMaterial(t *testing.T) {
	store := NewMemoryAdminStore()
	userID := uuid.New()
	store.Users = append(store.Users, AdminUser{ID: userID, Username: "alice", Email: stringPtr("ALICE@example.com"), EmailVerified: true, CreatedAt: time.Unix(100, 0), AuthGeneration: 2})
	service := NewAdminUserService(store)
	actor := AdminActor{ID: uuid.New(), Capabilities: []string{"users.read"}}
	page, err := service.List(context.Background(), actor, AdminUserListRequest{Limit: 25})
	if err != nil || len(page.Items) != 1 {
		t.Fatalf("list = %#v, %v", page, err)
	}
	if page.Items[0].Email == nil || page.Items[0].ID != userID || page.Items[0].AuthGeneration != 2 {
		t.Fatalf("unexpected safe user: %#v", page.Items[0])
	}
	verified := false
	unverified, err := service.List(context.Background(), actor, AdminUserListRequest{Limit: 25, VerifiedEmail: &verified})
	if err != nil || len(unverified.Items) != 0 {
		t.Fatalf("verified=false filter = %#v, %v", unverified, err)
	}
	if _, err := service.List(context.Background(), actor, AdminUserListRequest{Limit: 101}); !errors.Is(err, ErrInvalidUserQuery) {
		t.Fatalf("oversized page error = %v", err)
	}
	if _, err := service.Get(context.Background(), AdminActor{ID: uuid.New()}, userID); !errors.Is(err, ErrAudienceForbidden) {
		t.Fatalf("missing capability error = %v", err)
	}
}

func TestAdminUserServicePaginationIsStable(t *testing.T) {
	store := NewMemoryAdminStore()
	for i := 0; i < 2; i++ {
		email := "user" + string(rune('a'+i)) + "@example.com"
		store.Users = append(store.Users, AdminUser{ID: uuid.New(), Username: email, Email: &email, EmailVerified: true})
	}
	service := NewAdminUserService(store)
	actor := AdminActor{ID: uuid.New(), Capabilities: []string{"users.read"}}
	first, err := service.List(context.Background(), actor, AdminUserListRequest{Limit: 1})
	if err != nil || len(first.Items) != 1 || first.Next == nil {
		t.Fatalf("first page = %#v, %v", first, err)
	}
	second, err := service.List(context.Background(), actor, AdminUserListRequest{Limit: 1, Cursor: *first.Next})
	if err != nil || len(second.Items) != 1 || second.Items[0].ID == first.Items[0].ID {
		t.Fatalf("second page = %#v, %v", second, err)
	}
}

func TestAdminUserVerifyEmailRequiresCapability(t *testing.T) {
	store := NewMemoryAdminStore()
	id := uuid.New()
	email := "alice@example.com"
	store.Users = append(store.Users, AdminUser{ID: id, Username: "alice", Email: &email})
	users := NewAdminUserService(store)
	if _, err := users.VerifyEmail(context.Background(), AdminActor{ID: uuid.New(), Capabilities: []string{"users.read"}}, id); !errors.Is(err, ErrAudienceForbidden) {
		t.Fatalf("verification without capability = %v", err)
	}
	verified, err := users.VerifyEmail(context.Background(), AdminActor{ID: uuid.New(), Capabilities: []string{"users.verify"}}, id)
	if err != nil || verified == nil || !verified.EmailVerified {
		t.Fatalf("verified user = %#v, %v", verified, err)
	}
}

func TestAdminUserServiceUpdateRequiresCapabilityAndRecentMFA(t *testing.T) {
	store := NewMemoryAdminStore()
	id := uuid.New()
	oldEmail := "alice@example.com"
	store.Users = append(store.Users, AdminUser{
		ID: id, Username: "alice", Email: &oldEmail, EmailVerified: true,
		SecurityState: "normal", CommunicationOptOut: false,
	})
	users := NewAdminUserService(store)
	users.SetRecentMFATTL(5 * time.Minute)
	expectedAuthGeneration := int64(0)
	update := AdminUserUpdate{
		ExpectedAuthGeneration: &expectedAuthGeneration,
		Username:               stringPtr("alice-renamed"),
		Email:                  stringPtr("new-alice@example.com"),
		SecurityState:          stringPtr("password_disabled"),
		CommunicationOptOut:    adminUserBoolPtr(true),
		PushOptedOut:           adminUserBoolPtr(true),
	}
	actor := AdminActor{ID: uuid.New(), Capabilities: []string{"users.write"}}
	if _, err := users.Update(context.Background(), actor, id, update); !errors.Is(err, ErrRecentMFARequired) {
		t.Fatalf("update without recent MFA = %v", err)
	}
	actor.RecentMFAAt = adminUserTimePtr(time.Now().UTC())
	actor.RecentMFAAction = "users.write"
	actor.Capabilities = []string{"users.read"}
	if _, err := users.Update(context.Background(), actor, id, update); !errors.Is(err, ErrAudienceForbidden) {
		t.Fatalf("update without users.write = %v", err)
	}
	actor.Capabilities = []string{"users.verify"}
	if _, err := users.Update(context.Background(), actor, id, update); !errors.Is(err, ErrAudienceForbidden) {
		t.Fatalf("update with users.verify only = %v", err)
	}
	actor.Capabilities = []string{"users.write"}
	updated, err := users.Update(context.Background(), actor, id, update)
	if err != nil {
		t.Fatalf("update user: %v", err)
	}
	if updated.ID != id || updated.Username != "alice-renamed" || updated.Email == nil || *updated.Email != "new-alice@example.com" || updated.EmailVerified {
		t.Fatalf("updated profile = %#v", updated)
	}
	if updated.SecurityState != "password_disabled" || !updated.PasswordDisabled || !updated.PasswordResetRequired || !updated.CommunicationOptOut || !updated.PushOptedOut {
		t.Fatalf("updated account state = %#v", updated)
	}
}

func adminUserBoolPtr(value bool) *bool { return &value }

func adminUserTimePtr(value time.Time) *time.Time { return &value }
