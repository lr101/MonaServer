package main

import (
	"bytes"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestRequestLoggerRedactsLegacyActionSlugs(t *testing.T) {
	var logs bytes.Buffer
	logger := slog.New(slog.NewTextHandler(&logs, nil))
	h := requestLogger(logger)(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusNoContent)
	}))
	rawPaths := []string{
		"/public/recover/recovery-secret",
		"/public/delete-account/delete-secret",
		"/public/email-confirmation/confirmation-secret",
	}
	for _, path := range rawPaths {
		req := httptest.NewRequest(http.MethodGet, path, nil)
		h.ServeHTTP(httptest.NewRecorder(), req)
	}
	for _, secret := range []string{"recovery-secret", "delete-secret", "confirmation-secret"} {
		if strings.Contains(logs.String(), secret) {
			t.Fatalf("request log contains raw action slug %q: %s", secret, logs.String())
		}
	}
	if !strings.Contains(logs.String(), "/public/recover/[redacted]") ||
		!strings.Contains(logs.String(), "/public/delete-account/[redacted]") ||
		!strings.Contains(logs.String(), "/public/email-confirmation/[redacted]") {
		t.Fatalf("redacted action paths missing from request log: %s", logs.String())
	}
}
