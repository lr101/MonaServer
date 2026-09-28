package handler

import (
	"context"
	"net/http"

	"github.com/google/uuid"
	"github.com/lrprojects/monaserver/internal/apperrors"
	genserver "github.com/lrprojects/monaserver/internal/gen/server"
	"github.com/lrprojects/monaserver/internal/service"
)

// SessionAuthServicer revokes only the submitted credential owned by the
// authenticated consumer. This is used when an exchanged link cannot be
// admitted into the current Flutter session.
type SessionAuthServicer struct{ security *service.AccountSecurity }

func NewSessionAuthServicer(security *service.AccountSecurity) *SessionAuthServicer {
	return &SessionAuthServicer{security: security}
}

func (s *SessionAuthServicer) RevokeOwnSession(ctx context.Context, request genserver.SessionRevokeRequestDto) (genserver.ImplResponse, error) {
	if s == nil || s.security == nil {
		return publicAuthErrorResponse(service.ErrEmailDeliveryUnavailable)
	}
	caller, ok := ctxUserID(ctx)
	refreshID, err := uuid.Parse(request.RefreshToken)
	if !ok || err != nil {
		return publicAuthErrorResponse(apperrors.ErrBadRequest)
	}
	if err := s.security.RevokeOwnSession(ctx, caller, refreshID); err != nil {
		return publicAuthErrorResponse(err)
	}
	return genserver.Response(http.StatusNoContent, nil), nil
}
