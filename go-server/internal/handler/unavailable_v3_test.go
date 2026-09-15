package handler

import (
	"encoding/json"
	"errors"
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

func TestV3ErrorHandlerSanitizesServiceErrors(t *testing.T) {
	tests := []struct {
		name       string
		result     *genserver.ImplResponse
		wantStatus int
		wantCode   string
	}{
		{
			name:       "unprocessable result is normalized to bad request",
			result:     responsePtr(genserver.Response(http.StatusUnprocessableEntity, nil)),
			wantStatus: http.StatusBadRequest,
			wantCode:   "invalid_request",
		},
		{
			name:       "conflict result uses bounded metadata",
			result:     responsePtr(genserver.Response(http.StatusConflict, nil)),
			wantStatus: http.StatusConflict,
			wantCode:   "conflict",
		},
		{
			name:       "missing result uses internal error",
			wantStatus: http.StatusInternalServerError,
			wantCode:   "internal_error",
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			recorder := httptest.NewRecorder()
			V3ErrorHandler(recorder, httptest.NewRequest(http.MethodGet, "/api/v3/admin/users", nil), errors.New("provider secret raw-token"), tt.result)
			if recorder.Code != tt.wantStatus {
				t.Fatalf("status = %d, want %d", recorder.Code, tt.wantStatus)
			}
			var body genserver.ApiErrorDto
			if err := json.NewDecoder(recorder.Body).Decode(&body); err != nil {
				t.Fatalf("decode v3 error: %v", err)
			}
			if body.Code != tt.wantCode {
				t.Fatalf("error code = %q, want %q", body.Code, tt.wantCode)
			}
			if body.Message == "provider secret raw-token" || body.Message == "" {
				t.Fatalf("unsafe v3 error message = %q", body.Message)
			}
		})
	}
}

func responsePtr(response genserver.ImplResponse) *genserver.ImplResponse {
	return &response
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
