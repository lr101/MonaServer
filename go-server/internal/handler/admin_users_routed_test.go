package handler

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

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
