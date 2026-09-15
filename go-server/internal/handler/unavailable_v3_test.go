package handler

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	genserver "github.com/lrprojects/monaserver/internal/gen/server"
)

func TestUnavailableV3ServicerDoesNotReturnPlaceholderSuccess(t *testing.T) {
	servicer := NewUnavailableV3Servicer()

	t.Run("admin session read", func(t *testing.T) {
		controller := genserver.NewAdminSessionAPIController(servicer)
		recorder := httptest.NewRecorder()
		request := httptest.NewRequest(http.MethodGet, "/api/v3/admin/session", nil)

		controller.GetAdminSession(recorder, request)
		assertUnavailableResponse(t, recorder)
	})

	t.Run("public login request", func(t *testing.T) {
		controller := genserver.NewPublicAuthAPIController(servicer)
		recorder := httptest.NewRecorder()
		request := httptest.NewRequest(
			http.MethodPost,
			"/api/v3/public/auth/email-link/request",
			strings.NewReader(`{"email":"person@example.com"}`),
		)

		controller.RequestEmailLink(recorder, request)
		assertUnavailableResponse(t, recorder)
	})
}

func assertUnavailableResponse(t *testing.T, recorder *httptest.ResponseRecorder) {
	t.Helper()
	if recorder.Code != http.StatusServiceUnavailable {
		t.Fatalf("status = %d, want %d", recorder.Code, http.StatusServiceUnavailable)
	}
	var body genserver.ApiErrorDto
	if err := json.NewDecoder(recorder.Body).Decode(&body); err != nil {
		t.Fatalf("decode unavailable response: %v", err)
	}
	if body.Code != "feature_unavailable" {
		t.Fatalf("error code = %q, want feature_unavailable", body.Code)
	}
}
