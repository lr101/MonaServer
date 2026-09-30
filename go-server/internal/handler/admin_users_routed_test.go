package handler

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	genserver "github.com/lrprojects/monaserver/internal/gen/server"
	"github.com/lrprojects/monaserver/internal/middleware"
	"github.com/lrprojects/monaserver/internal/service"
)

func TestRoutedAdminUsersPreservesExplicitFalseVerifiedEmailFilter(t *testing.T) {
	store := service.NewMemoryAdminStore()
	verifiedEmail := "verified@example.com"
	unverifiedEmail := "unverified@example.com"
	store.Users = append(store.Users,
		service.AdminUser{ID: uuid.New(), Username: "verified", Email: &verifiedEmail, EmailVerified: true},
		service.AdminUser{ID: uuid.New(), Username: "unverified", Email: &unverifiedEmail, EmailVerified: false},
	)
	actor := uuid.New()
	ctx := middleware.WithAdminPrincipal(t.Context(), middleware.AdminPrincipal{UserID: actor.String(), State: "authenticated", Capabilities: []string{"users.read"}})
	controller := genserver.NewAdminUsersAPIController(NewAdminUsersServicer(service.NewAdminUserService(store)))
	routed := CaptureAdminUsersQuery(http.HandlerFunc(controller.ListAdminUsers))

	request := httptest.NewRequest("GET", "/api/v3/admin/users?verifiedEmail=false", nil).WithContext(ctx)
	response := httptest.NewRecorder()
	routed.ServeHTTP(response, request)
	if response.Code != 200 {
		t.Fatalf("explicit false status = %d, body=%s", response.Code, response.Body.String())
	}
	var falsePage genserver.AdminUserPageDto
	if err := json.Unmarshal(response.Body.Bytes(), &falsePage); err != nil {
		t.Fatalf("decode explicit false response: %v", err)
	}
	if len(falsePage.Items) != 1 || falsePage.Items[0].EmailVerified {
		t.Fatalf("explicit false page = %#v, want only unverified user", falsePage)
	}

	request = httptest.NewRequest("GET", "/api/v3/admin/users", nil).WithContext(ctx)
	response = httptest.NewRecorder()
	routed.ServeHTTP(response, request)
	if response.Code != 200 {
		t.Fatalf("omitted filter status = %d, body=%s", response.Code, response.Body.String())
	}
	var omittedPage genserver.AdminUserPageDto
	if err := json.Unmarshal(response.Body.Bytes(), &omittedPage); err != nil {
		t.Fatalf("decode omitted response: %v", err)
	}
	if len(omittedPage.Items) != 2 {
		t.Fatalf("omitted filter page = %#v, want both users", omittedPage)
	}
}

func TestRoutedAdminUserUpdateChangesEditableFieldsAndKeepsID(t *testing.T) {
	store := service.NewMemoryAdminStore()
	userID := uuid.New()
	oldEmail := "old@example.com"
	store.Users = append(store.Users, service.AdminUser{
		ID: userID, Username: "alice", Email: &oldEmail, EmailVerified: true,
		AccountActivated: true, SecurityState: "normal",
	})
	csrf := "test-csrf-token"
	now := time.Now().UTC()
	ctx := middleware.WithAdminPrincipal(t.Context(), middleware.AdminPrincipal{
		UserID: uuid.NewString(), State: "authenticated", CSRFHash: middleware.CSRFHash(csrf),
		Capabilities: []string{"users.write"}, RecentMFAAt: &now, RecentMFAAction: "users.write",
	})
	controller := genserver.NewAdminUsersAPIController(NewAdminUsersServicer(service.NewAdminUserService(store)))
	router := chi.NewRouter()
	router.Patch("/api/v3/admin/users/{userId}", controller.UpdateAdminUser)
	body := `{"expectedAuthGeneration":0,"username":"alice-renamed","email":"new@example.com","securityState":"normal","communicationOptOut":true,"pushOptedOut":true}`
	request := httptest.NewRequest(http.MethodPatch, "/api/v3/admin/users/"+userID.String(), strings.NewReader(body)).WithContext(ctx)
	request.Header.Set("X-CSRF-Token", csrf)
	response := httptest.NewRecorder()
	router.ServeHTTP(response, request)
	if response.Code != http.StatusOK {
		t.Fatalf("update status = %d, body=%s", response.Code, response.Body.String())
	}
	var updated genserver.AdminUserDetailsDto
	if err := json.Unmarshal(response.Body.Bytes(), &updated); err != nil {
		t.Fatalf("decode updated user: %v", err)
	}
	if updated.Id != userID.String() || updated.Username != "alice-renamed" || updated.Email == nil || *updated.Email != "new@example.com" || updated.EmailVerified {
		t.Fatalf("updated profile = %#v", updated)
	}
	if !updated.CommunicationOptOut || !updated.PushOptedOut {
		t.Fatalf("updated preferences = %#v", updated)
	}
}

func TestRoutedAdminUserUpdateCanClearAdminPermissions(t *testing.T) {
	store := service.NewMemoryAdminStore()
	userID := uuid.New()
	store.Users = append(store.Users, service.AdminUser{
		ID: userID, Username: "operator", IsAdmin: true, AdminPermissions: []string{"users.read"},
	})
	csrf := "test-csrf-token"
	now := time.Now().UTC()
	ctx := middleware.WithAdminPrincipal(t.Context(), middleware.AdminPrincipal{
		UserID: uuid.NewString(), State: "authenticated", CSRFHash: middleware.CSRFHash(csrf),
		Capabilities: []string{"superadmin"}, RecentMFAAt: &now, RecentMFAAction: "users.write",
	})
	controller := genserver.NewAdminUsersAPIController(NewAdminUsersServicer(service.NewAdminUserService(store)))
	router := chi.NewRouter()
	router.Patch("/api/v3/admin/users/{userId}", controller.UpdateAdminUser)
	request := httptest.NewRequest(http.MethodPatch, "/api/v3/admin/users/"+userID.String(), strings.NewReader(`{"expectedAuthGeneration":0,"adminPermissions":[]}`)).WithContext(ctx)
	request.Header.Set("X-CSRF-Token", csrf)
	response := httptest.NewRecorder()
	router.ServeHTTP(response, request)
	if response.Code != http.StatusOK {
		t.Fatalf("clear permissions status = %d, body=%s", response.Code, response.Body.String())
	}
	updated, err := store.GetUser(t.Context(), userID)
	if err != nil || updated == nil || !updated.IsAdmin || len(updated.AdminPermissions) != 0 {
		t.Fatalf("cleared membership = %#v, %v", updated, err)
	}
}
