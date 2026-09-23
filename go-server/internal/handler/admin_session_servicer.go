package handler

import (
	"context"
	"net/http"
	"time"

	"github.com/google/uuid"
	"github.com/lrprojects/monaserver/internal/apperrors"
	genserver "github.com/lrprojects/monaserver/internal/gen/server"
	"github.com/lrprojects/monaserver/internal/middleware"
	"github.com/lrprojects/monaserver/internal/service"
)

// AdminSessionServicer adapts the browser-admin authentication service to the
// generated v3 session contract. Cookie writes happen through request context
// installed by middleware.CaptureAdminRequest.
type AdminSessionServicer struct {
	auth *service.AdminAuth
}

func NewAdminSessionServicer(auth *service.AdminAuth) *AdminSessionServicer {
	return &AdminSessionServicer{auth: auth}
}

// NewAdminAuthServicer is a descriptive alias retained for composition code
// that names handlers after the underlying service.
func NewAdminAuthServicer(auth *service.AdminAuth) *AdminSessionServicer {
	return NewAdminSessionServicer(auth)
}

func (s *AdminSessionServicer) BootstrapAdminSession(ctx context.Context) (genserver.ImplResponse, error) {
	result, err := s.auth.BootstrapAdminSession(ctx)
	if err != nil {
		return adminAuthErrorResponse(ctx, err), nil
	}
	state, _ := genserver.NewAdminSessionStateFromValue(result.SessionState)
	return genserver.Response(http.StatusOK, genserver.AdminSessionBootstrapDto{
		CsrfToken: result.CSRFToken, ExpiresAt: result.ExpiresAt, SessionState: state,
	}), nil
}

func (s *AdminSessionServicer) AdminSessionLogin(ctx context.Context, csrf string, request genserver.AdminSessionLoginRequestDto) (genserver.ImplResponse, error) {
	result, err := s.auth.AdminSessionLogin(ctx, csrf, request.Username, request.Password)
	if err != nil {
		return adminAuthErrorResponse(ctx, err), nil
	}
	return genserver.Response(http.StatusAccepted, genserver.AdminSessionLoginResponseDto{
		ChallengeId: result.ChallengeID, CsrfToken: result.CSRFToken, ExpiresAt: result.ExpiresAt, SessionState: result.SessionState,
	}), nil
}

func (s *AdminSessionServicer) InitialAdminSetup(ctx context.Context, csrf string, request genserver.AdminInitialSetupRequestDto) (genserver.ImplResponse, error) {
	result, err := s.auth.InitialAdminSetup(ctx, csrf, request.Username, request.Password, request.SetupToken)
	if err != nil {
		return adminAuthErrorResponse(ctx, err), nil
	}
	if writer, ok := middleware.AdminResponseWriter(ctx); ok && writer != nil {
		writer.Header().Set("Cache-Control", "no-store")
	}
	return genserver.Response(http.StatusCreated, genserver.AdminInitialSetupResponseDto{
		UserId: result.UserID.String(), TotpSecret: result.Secret,
	}), nil
}

func (s *AdminSessionServicer) CompleteAdminSessionMfa(ctx context.Context, csrf string, request genserver.AdminMfaRequestDto) (genserver.ImplResponse, error) {
	result, err := s.auth.CompleteAdminSessionMFA(ctx, csrf, request.ChallengeId, request.Code)
	if err != nil {
		return adminAuthErrorResponse(ctx, err), nil
	}
	return genserver.Response(http.StatusOK, adminSessionDTO(result)), nil
}

func (s *AdminSessionServicer) ReauthenticateAdminSession(ctx context.Context, csrf string, request genserver.AdminReauthenticateRequestDto) (genserver.ImplResponse, error) {
	result, err := s.auth.ReauthenticateAdminSession(ctx, csrf, string(request.Action), request.Code)
	if err != nil {
		return adminAuthErrorResponse(ctx, err), nil
	}
	return genserver.Response(http.StatusOK, adminSessionDTO(result)), nil
}

func (s *AdminSessionServicer) LogoutAdminSession(ctx context.Context, csrf string) (genserver.ImplResponse, error) {
	if err := s.auth.LogoutAdminSession(ctx, csrf); err != nil {
		return adminAuthErrorResponse(ctx, err), nil
	}
	return genserver.Response(http.StatusNoContent, nil), nil
}

func (s *AdminSessionServicer) GetAdminSession(ctx context.Context) (genserver.ImplResponse, error) {
	result, err := s.auth.GetAdminSession(ctx)
	if err != nil {
		return adminAuthErrorResponse(ctx, err), nil
	}
	return genserver.Response(http.StatusOK, adminSessionDTO(result)), nil
}

func adminSessionDTO(result *service.AdminSessionResult) genserver.AdminSessionDto {
	if result == nil || result.Principal == nil {
		return genserver.AdminSessionDto{}
	}
	p := result.Principal
	userID, _ := uuid.Parse(p.UserID)
	if result.CSRFToken != "" {
		p.CSRFToken = result.CSRFToken
	}
	return genserver.AdminSessionDto{
		AuthenticatedAt: p.AuthenticatedAt,
		Capabilities:    append([]string(nil), p.Capabilities...),
		CsrfToken:       p.CSRFToken,
		IdleExpiresAt:   p.IdleExpiresAt,
		LastActivityAt:  p.LastActivityAt,
		Permissions:     append([]string(nil), p.Permissions...),
		RecentMfaAt:     cloneTime(p.RecentMFAAt),
		SessionId:       p.SessionID,
		SessionState:    p.State,
		UserId:          userID.String(),
		Username:        p.Username,
	}
}

func cloneTime(value *time.Time) *time.Time {
	if value == nil {
		return nil
	}
	copy := *value
	return &copy
}

func adminAuthErrorResponse(ctx context.Context, err error) genserver.ImplResponse {
	status := apperrors.HTTPStatus(err)
	if status < http.StatusBadRequest || status > 599 {
		status = http.StatusServiceUnavailable
	}
	code, message := "internal_error", "admin authentication is unavailable"
	switch status {
	case http.StatusBadRequest:
		code, message = "invalid_request", "request is invalid"
	case http.StatusUnauthorized:
		code, message = "unauthorized", "authentication is required"
	case http.StatusForbidden:
		code, message = "forbidden", "access is forbidden"
	case http.StatusTooManyRequests:
		code, message = "rate_limited", "too many requests"
		if writer, ok := middleware.AdminResponseWriter(ctx); ok && writer != nil {
			writer.Header().Set("Retry-After", "900")
		}
	case http.StatusServiceUnavailable:
		code, message = "feature_unavailable", "this API is not available"
	}
	return genserver.Response(status, genserver.ApiErrorDto{Code: code, Message: message})
}

var _ genserver.AdminSessionAPIServicer = (*AdminSessionServicer)(nil)
