package handler

import (
	"context"
	"errors"
	"net/http"
	"strconv"

	"github.com/lrprojects/monaserver/internal/apperrors"
	genserver "github.com/lrprojects/monaserver/internal/gen/server"
	"github.com/lrprojects/monaserver/internal/service"
)

// PublicAuthServicer adapts the public v3 email-link and restricted-recovery
// services to the generated response contract. It never exposes raw action
// tokens or service error text.
type PublicAuthServicer struct {
	login    *service.EmailLogin
	recovery *service.AccountRecovery
}

func NewPublicAuthServicer(login *service.EmailLogin, recovery *service.AccountRecovery) *PublicAuthServicer {
	return &PublicAuthServicer{login: login, recovery: recovery}
}

// NewEmailAuthServicer is an alias that makes the feature boundary explicit
// for composition code.
func NewEmailAuthServicer(login *service.EmailLogin, recovery *service.AccountRecovery) *PublicAuthServicer {
	return NewPublicAuthServicer(login, recovery)
}

func (s *PublicAuthServicer) RequestEmailLink(ctx context.Context, request genserver.EmailLinkRequestDto) (genserver.ImplResponse, error) {
	if s == nil || s.login == nil {
		return publicAuthErrorResponse(service.ErrEmailDeliveryUnavailable)
	}
	_, err := s.login.RequestEmailLink(ctx, service.EmailLoginRequest{
		Email: request.Email, IdentifierType: request.IdentifierType,
		ClientIP: service.EmailLoginClientIPFromContext(ctx),
	})
	if err != nil {
		return publicAuthErrorResponse(err)
	}
	return genserver.Response(http.StatusAccepted, genserver.EmailLinkRequestAcceptedDto{Accepted: true}), nil
}

func (s *PublicAuthServicer) ExchangeEmailLink(ctx context.Context, request genserver.EmailLinkExchangeRequestDto) (genserver.ImplResponse, error) {
	if s == nil || s.login == nil {
		return publicAuthErrorResponse(service.ErrEmailDeliveryUnavailable)
	}
	result, err := s.login.ExchangeEmailLink(ctx, request.Token)
	if err != nil {
		return publicAuthErrorResponse(err)
	}
	if result == nil || result.Pair == nil {
		return publicAuthErrorResponse(service.ErrInvalidEmailLink)
	}
	return genserver.Response(http.StatusOK, genserver.EmailLinkExchangeResponseDto{
		Tokens: toTokenResponseDto(result.Pair), Username: result.Username,
	}), nil
}

func (s *PublicAuthServicer) CompleteRecovery(ctx context.Context, request genserver.RecoveryCompleteRequestDto) (genserver.ImplResponse, error) {
	if s == nil || s.recovery == nil {
		return publicAuthErrorResponse(service.ErrEmailDeliveryUnavailable)
	}
	err := s.recovery.CompleteRecovery(ctx, service.RecoveryCompletionRequest{
		Token: request.Token, Password: request.Password,
	})
	if err != nil {
		return publicAuthErrorResponse(err)
	}
	return genserver.Response(http.StatusNoContent, nil), nil
}

func serviceErrorStatus(err error) int {
	status := apperrors.HTTPStatus(err)
	if status < http.StatusBadRequest || status > 599 {
		return http.StatusInternalServerError
	}
	return status
}

// publicAuthServiceError carries the bounded v3 envelope through the
// generated controller's ErrorHandler. The generated ImplResponse type has no
// header field, so Retry-After is emitted by PublicAuthV3ErrorHandler from the
// same typed error that populated RetryAfterSeconds in the body.
type publicAuthServiceError struct {
	status int
	body   genserver.ApiErrorDto
}

func (e *publicAuthServiceError) Error() string {
	if e == nil {
		return "public auth error"
	}
	return e.body.Message
}

func (e *publicAuthServiceError) RetryAfterSeconds() int32 {
	if e == nil || e.body.RetryAfterSeconds == nil {
		return 0
	}
	return *e.body.RetryAfterSeconds
}

func publicAuthErrorResponse(err error) (genserver.ImplResponse, error) {
	status := serviceErrorStatus(err)
	code, message := v3ErrorMetadata(status)
	body := genserver.ApiErrorDto{Code: code, Message: message}
	if retryAfter, ok := retryAfterSeconds(err); ok {
		body.RetryAfterSeconds = &retryAfter
	}
	serviceErr := &publicAuthServiceError{status: status, body: body}
	return genserver.Response(status, body), serviceErr
}

func retryAfterSeconds(err error) (int32, bool) {
	var provider interface{ RetryAfterSeconds() int32 }
	if !errors.As(err, &provider) {
		return 0, false
	}
	seconds := provider.RetryAfterSeconds()
	if seconds <= 0 {
		return 0, false
	}
	return seconds, true
}

// PublicAuthV3ErrorHandler is the route error handler for the generated
// public-auth controller. Coordinator route registration must install it with
// genserver.WithPublicAuthAPIErrorHandler and put the trusted client IP into
// the request context via service.WithEmailLoginClientIP before dispatch.
func PublicAuthV3ErrorHandler(w http.ResponseWriter, r *http.Request, err error, result *genserver.ImplResponse) {
	var parsingErr *genserver.ParsingError
	var requiredErr *genserver.RequiredError
	if errors.As(err, &parsingErr) || errors.As(err, &requiredErr) {
		WriteV3Error(w, http.StatusBadRequest, "invalid_request", "request is invalid")
		return
	}
	var serviceErr *publicAuthServiceError
	if errors.As(err, &serviceErr) {
		if seconds, ok := retryAfterSeconds(serviceErr); ok {
			w.Header().Set("Retry-After", strconv.FormatInt(int64(seconds), 10))
		}
		_ = genserver.EncodeJSONResponse(serviceErr.body, &serviceErr.status, w)
		return
	}
	status := http.StatusInternalServerError
	if result != nil {
		status = result.Code
	}
	code, message := v3ErrorMetadata(status)
	WriteV3Error(w, status, code, message)
}

// EmailAuthV3ErrorHandler is kept as a descriptive alias for composition
// code that names the feature boundary rather than the generated API.
var EmailAuthV3ErrorHandler = PublicAuthV3ErrorHandler

var _ genserver.PublicAuthAPIServicer = (*PublicAuthServicer)(nil)
