package service

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/lrprojects/monaserver/internal/db"
)

func TestProductionAdminUserUpdateChangesEmailAndSecurityState(t *testing.T) {
	q, auth, _, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	pair, err := auth.Signup(ctx, "admin_edit_target", "password123", nil)
	if err != nil {
		t.Fatal(err)
	}
	actorID := createTestUser(t, auth, "admin_edit_actor")
	store := NewProductionAdminStore(q, serviceTestEmail(t))
	users := NewAdminUserService(store)
	users.SetRecentMFATTL(5 * time.Minute)
	actor := AdminActor{
		ID: actorID, Capabilities: []string{"users.write"},
		RecentMFAAt: timePtrForAdminUserTest(time.Now().UTC()), RecentMFAAction: "users.write",
	}
	initial, err := q.GetAdminRuntimeAccount(ctx, pair.UserID)
	if err != nil || initial == nil {
		t.Fatalf("load initial target: %#v, err=%v", initial, err)
	}
	expectedAuthGeneration := initial.AuthGeneration

	newEmail := "admin-edit-target@example.com"
	newUsername := "admin_edit_target_renamed"
	optOut := true
	updated, err := users.Update(ctx, actor, pair.UserID, AdminUserUpdate{
		ExpectedAuthGeneration: &expectedAuthGeneration,
		Username:               &newUsername, Email: &newEmail, CommunicationOptOut: &optOut,
	})
	if err != nil {
		t.Fatalf("update profile: %v", err)
	}
	if updated.Username != newUsername || updated.Email == nil || *updated.Email != newEmail || updated.EmailVerified || !updated.CommunicationOptOut {
		t.Fatalf("updated profile = %#v", updated)
	}
	expectedAuthGeneration = updated.AuthGeneration
	stored, err := q.GetUserByID(ctx, pair.UserID)
	if err != nil || stored == nil || stored.EmailConfirmationUrl == nil || stored.AuthGeneration < 1 {
		t.Fatalf("stored email confirmation/generation = %#v, err=%v", stored, err)
	}

	compromised := "compromised"
	updated, err = users.Update(ctx, actor, pair.UserID, AdminUserUpdate{ExpectedAuthGeneration: &expectedAuthGeneration, SecurityState: &compromised})
	if err != nil {
		t.Fatalf("update security state: %v", err)
	}
	if updated.SecurityState != compromised || !updated.PasswordDisabled || !updated.PasswordResetRequired || updated.CompromisedAt == nil {
		t.Fatalf("updated security state = %#v", updated)
	}
	security, err := q.GetUserSecurityState(ctx, pair.UserID)
	if err != nil || security == nil || security.AuthGeneration < 2 {
		t.Fatalf("stored security generation = %#v, err=%v", security, err)
	}
	audit, err := q.ListAuditEvents(ctx, nil, 10)
	if err != nil {
		t.Fatal(err)
	}
	updatedEvents := 0
	for _, event := range audit {
		if event.Action == "admin_user_updated" && event.TargetAccountID != nil && *event.TargetAccountID == pair.UserID {
			updatedEvents++
		}
	}
	if updatedEvents != 2 {
		t.Fatalf("admin user update audit events = %d, want 2", updatedEvents)
	}
}

func TestProductionAdminUserPermissionUpdatePersistsAndRevokesSessions(t *testing.T) {
	q, auth, _, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	pair, err := auth.Signup(ctx, "admin_permission_target", "password123", nil)
	if err != nil {
		t.Fatal(err)
	}
	keyID := "test-admin-key"
	enrolledAt := time.Now().UTC()
	if err := q.UpsertAdminMembership(ctx, db.AdminMembershipParams{
		ID: uuid.New(), UserID: pair.UserID, Permissions: []string{"users.read"}, Active: true,
		TotpSecretCiphertext: []byte("encrypted-totp"), TotpKeyID: &keyID, TotpEnrolledAt: &enrolledAt,
	}); err != nil {
		t.Fatalf("seed admin membership: %v", err)
	}
	membershipBefore, err := q.GetAdminMembership(ctx, pair.UserID)
	if err != nil || membershipBefore == nil {
		t.Fatalf("load seeded membership: %#v, err=%v", membershipBefore, err)
	}
	sessionHash := []byte("admin-permission-session-hash")
	now := time.Now().UTC()
	if err := q.CreateAdminSession(ctx, db.AdminSessionParams{
		ID: uuid.New(), SessionHash: sessionHash, UserID: pair.UserID, CSRFHash: []byte("csrf-hash"),
		State: "authenticated", AuthGeneration: 0, IdleExpiresAt: now.Add(time.Minute), AbsoluteExpiresAt: now.Add(time.Hour),
	}); err != nil {
		t.Fatalf("seed admin session: %v", err)
	}
	actorID := createTestUser(t, auth, "admin_permission_actor")
	users := NewAdminUserService(NewProductionAdminStore(q))
	users.SetRecentMFATTL(5 * time.Minute)
	actor := AdminActor{
		ID: actorID, Capabilities: []string{"superadmin"}, RecentMFAAt: timePtrForAdminUserTest(now), RecentMFAAction: "users.write",
	}
	expectedAuthGeneration := int64(0)
	permissions := []string{"superadmin"}
	updated, err := users.Update(ctx, actor, pair.UserID, AdminUserUpdate{
		ExpectedAuthGeneration: &expectedAuthGeneration, AdminPermissions: &permissions,
	})
	if err != nil {
		t.Fatalf("update admin permissions: %v", err)
	}
	if !updated.IsAdmin || len(updated.AdminPermissions) != 1 || updated.AdminPermissions[0] != "superadmin" {
		t.Fatalf("updated membership projection = %#v", updated)
	}
	optOut := true
	updated, err = users.Update(ctx, actor, pair.UserID, AdminUserUpdate{
		ExpectedAuthGeneration: &expectedAuthGeneration, PushOptedOut: &optOut,
	})
	if err != nil || len(updated.AdminPermissions) != 1 || updated.AdminPermissions[0] != "superadmin" {
		t.Fatalf("ordinary user edit lost permission projection: %#v, err=%v", updated, err)
	}
	regularActor := actor
	regularActor.Capabilities = []string{"users.write"}
	updated, err = users.Update(ctx, regularActor, pair.UserID, AdminUserUpdate{
		ExpectedAuthGeneration: &expectedAuthGeneration, CommunicationOptOut: adminUserBoolPtr(true),
	})
	if err != nil || updated.AdminPermissions != nil {
		t.Fatalf("regular admin update response exposed permissions: %#v, err=%v", updated, err)
	}
	membership, err := q.GetAdminMembership(ctx, pair.UserID)
	if err != nil || membership == nil || len(membership.Permissions) != 1 || membership.Permissions[0] != "superadmin" {
		t.Fatalf("stored membership = %#v, err=%v", membership, err)
	}
	if string(membership.TotpSecretCiphertext) != string(membershipBefore.TotpSecretCiphertext) || membership.TotpKeyID == nil || *membership.TotpKeyID != keyID {
		t.Fatalf("permission update changed MFA enrollment: before=%#v after=%#v", membershipBefore, membership)
	}
	session, err := q.GetAdminSessionByHash(ctx, sessionHash)
	if err != nil || session == nil || session.RevokedAt == nil {
		t.Fatalf("permission-edited session = %#v, err=%v; want revoked", session, err)
	}
	adminPermissionsVisible, err := users.Get(ctx, actor, pair.UserID)
	if err != nil || adminPermissionsVisible == nil || len(adminPermissionsVisible.AdminPermissions) != 1 {
		t.Fatalf("superadmin read-back = %#v, err=%v", adminPermissionsVisible, err)
	}
	permissionsHidden, err := users.Get(ctx, AdminActor{ID: actorID, Capabilities: []string{"users.read"}}, pair.UserID)
	if err != nil || permissionsHidden == nil || permissionsHidden.AdminPermissions != nil {
		t.Fatalf("ordinary admin read-back = %#v, err=%v; permissions should be redacted", permissionsHidden, err)
	}
}

func timePtrForAdminUserTest(value time.Time) *time.Time { return &value }
