package handler

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"testing"

	chimw "github.com/go-chi/chi/v5/middleware"

	"github.com/lrprojects/monaserver/internal/apperrors"
)

func TestServiceErrorResponsesUsePlainTextBody(t *testing.T) {
	resp := serviceErrResp(context.Background(), apperrors.New(409, "already exists"))
	body, ok := resp.Body.([]byte)
	if !ok {
		t.Fatalf("error body type = %T, want []byte", resp.Body)
	}
	if string(body) != "already exists" {
		t.Fatalf("error body = %q", body)
	}
}

func TestServiceErrorResponseLogsInternalError(t *testing.T) {
	var output bytes.Buffer
	originalLogger := slog.Default()
	slog.SetDefault(slog.New(slog.NewJSONHandler(&output, nil)))
	t.Cleanup(func() { slog.SetDefault(originalLogger) })

	ctx := contextWithRequestID(t)
	resp := serviceErrResp(ctx, errors.New("database connection failed"))
	if resp.Code != 500 {
		t.Fatalf("status code = %d, want 500", resp.Code)
	}
	body, ok := resp.Body.([]byte)
	if !ok || string(body) != "internal server error" {
		t.Fatalf("response body = %q (%T), want generic internal server error", body, resp.Body)
	}

	var entry map[string]any
	if err := json.Unmarshal(output.Bytes(), &entry); err != nil {
		t.Fatalf("decode log entry: %v; output = %q", err, output.String())
	}
	if entry["level"] != "ERROR" {
		t.Errorf("log level = %v, want ERROR", entry["level"])
	}
	if entry["msg"] != "request failed" {
		t.Errorf("log message = %v, want request failed", entry["msg"])
	}
	if entry["status"] != float64(500) {
		t.Errorf("logged status = %v, want 500", entry["status"])
	}
	if entry["err"] != "database connection failed" {
		t.Errorf("logged error = %v, want underlying error", entry["err"])
	}
	if entry["request_id"] != chimw.GetReqID(ctx) {
		t.Errorf("logged request ID = %v, want %q", entry["request_id"], chimw.GetReqID(ctx))
	}
}

func TestServiceErrorResponseDoesNotLogClientError(t *testing.T) {
	var output bytes.Buffer
	originalLogger := slog.Default()
	slog.SetDefault(slog.New(slog.NewJSONHandler(&output, nil)))
	t.Cleanup(func() { slog.SetDefault(originalLogger) })

	resp := serviceErrResp(context.Background(), apperrors.New(409, "already exists"))
	if resp.Code != 409 {
		t.Fatalf("status code = %d, want 409", resp.Code)
	}
	if output.Len() != 0 {
		t.Fatalf("unexpected log output for client error: %q", output.String())
	}
}

func contextWithRequestID(t *testing.T) context.Context {
	t.Helper()
	var ctx context.Context
	handler := chimw.RequestID(http.HandlerFunc(func(_ http.ResponseWriter, r *http.Request) {
		ctx = r.Context()
	}))
	handler.ServeHTTP(httptest.NewRecorder(), httptest.NewRequest(http.MethodGet, "/test", nil))
	if chimw.GetReqID(ctx) == "" {
		t.Fatal("request middleware did not assign an ID")
	}
	return ctx
}
