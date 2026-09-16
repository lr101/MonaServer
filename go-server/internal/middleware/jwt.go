package middleware

import (
	"context"
	"net/http"
	"strings"

	"github.com/google/uuid"
	"github.com/lrprojects/monaserver/internal/apperrors"
	"github.com/lrprojects/monaserver/internal/token"
)

// UserLookup returns the user's username for role determination. It is kept
// as the base interface so older service/test doubles remain source
// compatible.
type UserLookup interface {
	GetUsername(ctx context.Context, id uuid.UUID) (string, error)
}

// SecurityLookup is the stronger principal lookup used by generation-aware
// servers. A lookup must read current state from the database; the middleware
// never trusts state copied into a JWT.
type SecurityLookup interface {
	UserLookup
	GetSecurityState(ctx context.Context, id uuid.UUID) (*PrincipalSecurityState, error)
	IsAdmin(ctx context.Context, id uuid.UUID) (bool, error)
}

// PrincipalLookup is an alias retained for callers that describe the same
// dependency in terms of principal loading.
type PrincipalLookup = SecurityLookup

// JWT parses Bearer token, loads user, and injects UserID + Role into context.
// Missing or invalid tokens return 401.
func JWT(tok *token.Helper, lookup UserLookup, adminUsername string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			h := r.Header.Get("Authorization")
			if !strings.HasPrefix(h, "Bearer ") {
				apperrors.WriteJSONError(w, "missing bearer token", http.StatusUnauthorized)
				return
			}
			raw := strings.TrimSpace(strings.TrimPrefix(h, "Bearer "))
			claims, err := tok.ParseAccessTokenClaims(raw)
			if err != nil {
				apperrors.WriteJSONError(w, "invalid token", http.StatusUnauthorized)
				return
			}
			uid := claims.UserID
			_, err = lookup.GetUsername(r.Context(), uid)
			if err != nil {
				apperrors.WriteJSONError(w, "user not found", http.StatusUnauthorized)
				return
			}
			role := RoleUser
			if security, ok := lookup.(SecurityLookup); ok {
				state, err := security.GetSecurityState(r.Context(), uid)
				if err != nil || state == nil || !stateAllowsBearer(state, claims.GenerationPresent, claims.AuthGeneration) {
					apperrors.WriteJSONError(w, "invalid token", http.StatusUnauthorized)
					return
				}
				admin, err := security.IsAdmin(r.Context(), uid)
				if err != nil {
					apperrors.WriteJSONError(w, "invalid token", http.StatusUnauthorized)
					return
				}
				if admin {
					role = RoleAdmin
				}
				ctx := WithUser(r.Context(), uid, role)
				ctx = WithSecurityState(ctx, *state)
				next.ServeHTTP(w, r.WithContext(ctx))
				return
			}
			// Legacy lookup implementations still identify ordinary users by
			// username, but username equality never grants administrator access.
			ctx := WithUser(r.Context(), uid, role)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

func stateAllowsBearer(state *PrincipalSecurityState, generationPresent bool, generation int64) bool {
	if state == nil || state.IsDeleted || state.SecurityState != SecurityStateNormal || state.PasswordDisabled || state.PasswordResetRequired {
		return false
	}
	if generationPresent {
		return generation == state.AuthGeneration
	}
	return state.AuthGeneration == 0
}

// RequireRole enforces that the request has the given role (or ADMIN).
func RequireRole(required string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			role := Role(r.Context())
			if role == "" {
				apperrors.WriteJSONError(w, "unauthorized", http.StatusUnauthorized)
				return
			}
			if required == RoleAdmin && role != RoleAdmin {
				apperrors.WriteJSONError(w, "forbidden", http.StatusForbidden)
				return
			}
			// USER role: both USER and ADMIN pass
			next.ServeHTTP(w, r)
		})
	}
}
