package middleware

import (
	"context"
	"net/http"
	"strings"

	"github.com/google/uuid"
	"github.com/lrprojects/monaserver/internal/apperrors"
	"github.com/lrprojects/monaserver/internal/token"
)

// UserLookup returns the user's username for role determination.
type UserLookup interface {
	GetUsername(ctx context.Context, id uuid.UUID) (string, error)
}

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
			raw := strings.TrimPrefix(h, "Bearer ")
			uid, err := tok.ParseAccessToken(raw)
			if err != nil {
				apperrors.WriteJSONError(w, "invalid token", http.StatusUnauthorized)
				return
			}
			username, err := lookup.GetUsername(r.Context(), uid)
			if err != nil {
				apperrors.WriteJSONError(w, "user not found", http.StatusUnauthorized)
				return
			}
			role := RoleUser
			if adminUsername != "" && username == adminUsername {
				role = RoleAdmin
			}
			ctx := WithUser(r.Context(), uid, role)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
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
