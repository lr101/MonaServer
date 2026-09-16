package handler

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strconv"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/lrprojects/monaserver/internal/db"
	genserver "github.com/lrprojects/monaserver/internal/gen/server"
	"github.com/lrprojects/monaserver/internal/service"
	"github.com/lrprojects/monaserver/internal/token"
)

type handlerLoginLinkEnqueuer struct{}

func (handlerLoginLinkEnqueuer) EnqueueLoginLink(context.Context, *db.Queries, service.LoginLinkDeliveryRequest) (*uuid.UUID, error) {
	id := uuid.New()
	return &id, nil
}

func TestPublicAuthServicerMapsRequestExchangeAndRecovery(t *testing.T) {
	base, auth := setupAuthServicer(t)
	q := base.q
	ctx := context.Background()
	email := "handler@example.com"
	pair, err := auth.Signup(ctx, "handler_owner", "password123", &email)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}
	if err := q.ConfirmUserEmail(ctx, pair.UserID); err != nil {
		t.Fatalf("confirm: %v", err)
	}
	login := service.NewEmailLogin(q, auth.Security(), token.NewHelper("test-secret", time.Minute), service.EmailLoginConfig{
		HMACKeyID: "handler-v1", HMACKey: []byte("handler-v1-" + uuid.NewString()),
	}, handlerLoginLinkEnqueuer{})
	recovery := service.NewAccountRecovery(q, auth.Security())
	servicer := NewPublicAuthServicer(login, recovery)

	requestResponse, err := servicer.RequestEmailLink(ctx, genserver.EmailLinkRequestDto{Email: email})
	if err != nil || requestResponse.Code != 202 {
		t.Fatalf("request response = %#v, err=%v", requestResponse, err)
	}
	if body, ok := requestResponse.Body.(genserver.EmailLinkRequestAcceptedDto); !ok || !bool(body.Accepted) {
		t.Fatalf("request body = %#v, want generic accepted", requestResponse.Body)
	}

	// Obtain a token through the service boundary to exercise the handler's
	// response conversion without exposing it from the public request body.
	issued, err := login.RequestEmailLink(ctx, service.EmailLoginRequest{Email: email, ClientIP: "192.0.2.100"})
	if err != nil || issued.Action == nil {
		t.Fatalf("issue test token = %#v, err=%v", issued, err)
	}
	exchangeResponse, err := servicer.ExchangeEmailLink(ctx, genserver.EmailLinkExchangeRequestDto{Token: issued.Action.Token})
	if err != nil || exchangeResponse.Code != 200 {
		t.Fatalf("exchange response = %#v, err=%v", exchangeResponse, err)
	}
	exchange, ok := exchangeResponse.Body.(genserver.EmailLinkExchangeResponseDto)
	if !ok || exchange.Username != "handler_owner" || exchange.Tokens.UserId != pair.UserID.String() {
		t.Fatalf("exchange body = %#v, want canonical username and user id", exchangeResponse.Body)
	}

	badRecovery, err := servicer.CompleteRecovery(ctx, genserver.RecoveryCompleteRequestDto{Token: "random", Password: "new-password"})
	if err == nil || badRecovery.Code != 400 {
		t.Fatalf("invalid recovery response = %#v, err=%v", badRecovery, err)
	}
}

func TestPublicAuthServicerReturnsUnavailableWhenDependenciesMissing(t *testing.T) {
	servicer := NewPublicAuthServicer(nil, nil)
	response, err := servicer.RequestEmailLink(context.Background(), genserver.EmailLinkRequestDto{Email: "person@example.com"})
	if err == nil || response.Code != 503 {
		t.Fatalf("missing dependency response = %#v, err=%v, want typed 503", response, err)
	}
	if body, ok := response.Body.(genserver.ApiErrorDto); !ok || body.Code != "feature_unavailable" {
		t.Fatalf("missing dependency body = %#v, want v3 envelope", response.Body)
	}
}

func TestPublicAuthV3ErrorHandlerWritesEnvelopeAndRetryAfter(t *testing.T) {
	base, auth := setupAuthServicer(t)
	q := base.q
	ctx := context.Background()
	email := "handler-rate@example.com"
	pair, err := auth.Signup(ctx, "handler_rate_owner", "password123", &email)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}
	if err := q.ConfirmUserEmail(ctx, pair.UserID); err != nil {
		t.Fatalf("confirm: %v", err)
	}
	login := service.NewEmailLogin(q, auth.Security(), token.NewHelper("test-secret", time.Minute), service.EmailLoginConfig{
		HMACKeyID: "handler-rate-v1", HMACKey: []byte("handler-rate-" + uuid.NewString()), IPLimit: 1,
	}, handlerLoginLinkEnqueuer{})
	controller := genserver.NewPublicAuthAPIController(
		NewPublicAuthServicer(login, service.NewAccountRecovery(q, auth.Security())),
		genserver.WithPublicAuthAPIErrorHandler(PublicAuthV3ErrorHandler),
	)

	first := httptest.NewRecorder()
	firstRequest := httptest.NewRequest(http.MethodPost, "/api/v3/public/auth/email-link/request", bytes.NewBufferString(`{"email":"unknown-handler-rate@example.com"}`))
	firstRequest = firstRequest.WithContext(service.WithEmailLoginClientIP(firstRequest.Context(), "198.51.100.10"))
	controller.RequestEmailLink(first, firstRequest)
	if first.Code != http.StatusAccepted {
		t.Fatalf("first response status = %d, want 202", first.Code)
	}
	second := httptest.NewRecorder()
	secondRequest := httptest.NewRequest(http.MethodPost, "/api/v3/public/auth/email-link/request", bytes.NewBufferString(`{"email":"another-handler-rate@example.com"}`))
	secondRequest = secondRequest.WithContext(service.WithEmailLoginClientIP(secondRequest.Context(), "198.51.100.10"))
	controller.RequestEmailLink(second, secondRequest)
	if second.Code != http.StatusTooManyRequests {
		t.Fatalf("second response status = %d, want 429", second.Code)
	}
	if second.Header().Get("Retry-After") == "" {
		t.Fatal("second response has no Retry-After header")
	}
	var body genserver.ApiErrorDto
	if err := json.NewDecoder(second.Body).Decode(&body); err != nil {
		t.Fatalf("decode v3 error body: %v", err)
	}
	if body.Code != "rate_limited" || body.Message != "too many requests" || body.RetryAfterSeconds == nil || *body.RetryAfterSeconds <= 0 {
		t.Fatalf("v3 error body = %#v, want bounded rate limit envelope", body)
	}
	if second.Header().Get("Retry-After") != strconv.FormatInt(int64(*body.RetryAfterSeconds), 10) {
		t.Fatalf("Retry-After = %q, body seconds = %d", second.Header().Get("Retry-After"), *body.RetryAfterSeconds)
	}
}
