package middleware

import (
	"context"

	"github.com/google/uuid"
)

type ctxKey int

const (
	keyUserID ctxKey = iota
	keyRole
)

const (
	RoleUser  = "USER"
	RoleAdmin = "ADMIN"

	SecurityStateNormal                = "normal"
	SecurityStatePasswordDisabled      = "password_disabled"
	SecurityStateCompromised           = "compromised"
	SecurityStateSecuredManualRecovery = "secured_manual_recovery_required"
	SecurityStateDeleted               = "deleted"
)

// PrincipalSecurityState is the security data a JWT request must be checked
// against at request time. It deliberately excludes passwords and tokens.
type PrincipalSecurityState struct {
	AuthGeneration        int64
	SecurityState         string
	PasswordDisabled      bool
	PasswordResetRequired bool
	IsDeleted             bool
}

func WithUser(ctx context.Context, id uuid.UUID, role string) context.Context {
	ctx = context.WithValue(ctx, keyUserID, id)
	return context.WithValue(ctx, keyRole, role)
}

type securityStateKey struct{}

// WithSecurityState adds the state observed by the authentication middleware.
// Existing callers that only need UserID/Role remain compatible with
// WithUser.
func WithSecurityState(ctx context.Context, state PrincipalSecurityState) context.Context {
	return context.WithValue(ctx, securityStateKey{}, state)
}

func SecurityState(ctx context.Context) (PrincipalSecurityState, bool) {
	state, ok := ctx.Value(securityStateKey{}).(PrincipalSecurityState)
	return state, ok
}

func UserID(ctx context.Context) (uuid.UUID, bool) {
	v, ok := ctx.Value(keyUserID).(uuid.UUID)
	return v, ok
}

func Role(ctx context.Context) string {
	if v, ok := ctx.Value(keyRole).(string); ok {
		return v
	}
	return ""
}
