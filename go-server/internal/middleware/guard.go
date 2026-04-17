package middleware

import (
	"context"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
)

// GuardQuery performs the DB reads required by guard checks.
// Mirrors the Kotlin Guard class methods.
type GuardQuery interface {
	IsGroupAdmin(ctx context.Context, groupID, userID uuid.UUID) (bool, error)
	IsGroupMember(ctx context.Context, groupID, userID uuid.UUID) (bool, error)
	IsGroupVisible(ctx context.Context, groupID, userID uuid.UUID) (bool, error)
	IsPinCreator(ctx context.Context, pinID, userID uuid.UUID) (bool, error)
	IsPinGroupAdmin(ctx context.Context, pinID, userID uuid.UUID) (bool, error)
	IsPinPublicOrMember(ctx context.Context, pinID, userID uuid.UUID) (bool, error)
}

type paramFn func(r *http.Request) (uuid.UUID, error)

func pathUUID(param string) paramFn {
	return func(r *http.Request) (uuid.UUID, error) {
		return uuid.Parse(chi.URLParam(r, param))
	}
}

func curUser(ctx context.Context) (uuid.UUID, bool) {
	return UserID(ctx)
}

type checkFn func(ctx context.Context, resourceID, userID uuid.UUID) (bool, error)

func guardMiddleware(getParam paramFn, check checkFn) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if Role(r.Context()) == RoleAdmin {
				next.ServeHTTP(w, r)
				return
			}
			uid, ok := curUser(r.Context())
			if !ok {
				http.Error(w, "unauthorized", http.StatusUnauthorized)
				return
			}
			rid, err := getParam(r)
			if err != nil {
				http.Error(w, "invalid id", http.StatusBadRequest)
				return
			}
			ok, err = check(r.Context(), rid, uid)
			if err != nil {
				http.Error(w, "forbidden", http.StatusForbidden)
				return
			}
			if !ok {
				http.Error(w, "forbidden", http.StatusForbidden)
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}

func RequireGroupAdmin(g GuardQuery, param string) func(http.Handler) http.Handler {
	return guardMiddleware(pathUUID(param), g.IsGroupAdmin)
}
func RequireGroupMember(g GuardQuery, param string) func(http.Handler) http.Handler {
	return guardMiddleware(pathUUID(param), g.IsGroupMember)
}
func RequireGroupVisible(g GuardQuery, param string) func(http.Handler) http.Handler {
	return guardMiddleware(pathUUID(param), g.IsGroupVisible)
}
func RequirePinCreator(g GuardQuery, param string) func(http.Handler) http.Handler {
	return guardMiddleware(pathUUID(param), g.IsPinCreator)
}
func RequirePinGroupAdmin(g GuardQuery, param string) func(http.Handler) http.Handler {
	return guardMiddleware(pathUUID(param), g.IsPinGroupAdmin)
}
func RequirePinPublicOrMember(g GuardQuery, param string) func(http.Handler) http.Handler {
	return guardMiddleware(pathUUID(param), g.IsPinPublicOrMember)
}

// RequireSameUser: authenticated user must match the {userId} path param.
func RequireSameUser(param string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if Role(r.Context()) == RoleAdmin {
				next.ServeHTTP(w, r)
				return
			}
			uid, ok := curUser(r.Context())
			if !ok {
				http.Error(w, "unauthorized", http.StatusUnauthorized)
				return
			}
			target, err := uuid.Parse(chi.URLParam(r, param))
			if err != nil || target != uid {
				http.Error(w, "forbidden", http.StatusForbidden)
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}

// RequireSameUserQuery: like RequireSameUser but reads the target user ID
// from a query parameter instead of a path parameter.
func RequireSameUserQuery(param string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if Role(r.Context()) == RoleAdmin {
				next.ServeHTTP(w, r)
				return
			}
			uid, ok := curUser(r.Context())
			if !ok {
				http.Error(w, "unauthorized", http.StatusUnauthorized)
				return
			}
			target, err := uuid.Parse(r.URL.Query().Get(param))
			if err != nil || target != uid {
				http.Error(w, "forbidden", http.StatusForbidden)
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}

// RequireAny succeeds if any provided middleware allows the request.
// Runs each sub-middleware with a recording ResponseWriter; on first success, replays to downstream.
func RequireAny(guards ...func(http.Handler) http.Handler) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			for _, g := range guards {
				rec := &recorder{ResponseWriter: w}
				passed := false
				final := http.HandlerFunc(func(_ http.ResponseWriter, _ *http.Request) { passed = true })
				g(final).ServeHTTP(rec, r)
				if passed {
					next.ServeHTTP(w, r)
					return
				}
			}
			http.Error(w, "forbidden", http.StatusForbidden)
		})
	}
}

type recorder struct {
	http.ResponseWriter
	status  int
	written bool
}

func (r *recorder) WriteHeader(code int) { r.status = code; r.written = true }
func (r *recorder) Write(b []byte) (int, error) {
	r.written = true
	return len(b), nil
}
