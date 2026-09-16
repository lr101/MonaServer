package handler

import (
	"context"
	"net/http"

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
		return genserver.Response(http.StatusServiceUnavailable, nil), nil
	}
	_, err := s.login.RequestEmailLink(ctx, service.EmailLoginRequest{
		Email: request.Email, ClientIP: service.EmailLoginClientIPFromContext(ctx),
	})
	if err != nil {
		return genserver.Response(serviceErrorStatus(err), nil), nil
	}
	return genserver.Response(http.StatusAccepted, genserver.EmailLinkRequestAcceptedDto{Accepted: true}), nil
}

func (s *PublicAuthServicer) ExchangeEmailLink(ctx context.Context, request genserver.EmailLinkExchangeRequestDto) (genserver.ImplResponse, error) {
	if s == nil || s.login == nil {
		return genserver.Response(http.StatusServiceUnavailable, nil), nil
	}
	result, err := s.login.ExchangeEmailLink(ctx, request.Token)
	if err != nil {
		return genserver.Response(serviceErrorStatus(err), nil), nil
	}
	if result == nil || result.Pair == nil {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	return genserver.Response(http.StatusOK, genserver.EmailLinkExchangeResponseDto{
		Tokens: toTokenResponseDto(result.Pair), Username: result.Username,
	}), nil
}

func (s *PublicAuthServicer) CompleteRecovery(ctx context.Context, request genserver.RecoveryCompleteRequestDto) (genserver.ImplResponse, error) {
	if s == nil || s.recovery == nil {
		return genserver.Response(http.StatusServiceUnavailable, nil), nil
	}
	err := s.recovery.CompleteRecovery(ctx, service.RecoveryCompletionRequest{
		Token: request.Token, Password: request.Password,
	})
	if err != nil {
		return genserver.Response(serviceErrorStatus(err), nil), nil
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

var _ genserver.PublicAuthAPIServicer = (*PublicAuthServicer)(nil)
