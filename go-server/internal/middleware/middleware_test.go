package middleware

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/lrprojects/monaserver/internal/token"
)

type fakeLookup struct {
	usernames map[uuid.UUID]string
}

func (f *fakeLookup) GetUsername(_ context.Context, id uuid.UUID) (string, error) {
	if n, ok := f.usernames[id]; ok {
		return n, nil
	}
	return "", http.ErrAbortHandler
}

type fakeSecurityLookup struct {
	*fakeLookup
	states     map[uuid.UUID]PrincipalSecurityState
	adminUsers map[uuid.UUID]bool
}

func (f *fakeSecurityLookup) GetSecurityState(_ context.Context, id uuid.UUID) (*PrincipalSecurityState, error) {
	state, ok := f.states[id]
	if !ok {
		return nil, http.ErrAbortHandler
	}
	return &state, nil
}

func (f *fakeSecurityLookup) IsAdmin(_ context.Context, id uuid.UUID) (bool, error) {
	return f.adminUsers[id], nil
}

func TestJWTRejectsStaleGenerationAndDisabledPrincipal(t *testing.T) {
	uid := uuid.New()
	tok := token.NewHelper("secret", time.Minute)
	lookup := &fakeSecurityLookup{
		fakeLookup: &fakeLookup{usernames: map[uuid.UUID]string{uid: "alice"}},
		states: map[uuid.UUID]PrincipalSecurityState{uid: {
			AuthGeneration: 2,
			SecurityState:  SecurityStateNormal,
		}},
	}

	call := func(raw string) int {
		h := JWT(tok, lookup, "")(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
			w.WriteHeader(http.StatusOK)
		}))
		req := httptest.NewRequest("GET", "/", nil)
		req.Header.Set("Authorization", "Bearer "+raw)
		rec := httptest.NewRecorder()
		h.ServeHTTP(rec, req)
		return rec.Code
	}

	current, err := tok.GenerateAccessTokenWithGeneration(uid, 2)
	if err != nil {
		t.Fatalf("current token: %v", err)
	}
	if got := call(current); got != http.StatusOK {
		t.Fatalf("current generation status = %d, want 200", got)
	}
	stale, err := tok.GenerateAccessTokenWithGeneration(uid, 1)
	if err != nil {
		t.Fatalf("stale token: %v", err)
	}
	if got := call(stale); got != http.StatusUnauthorized {
		t.Fatalf("stale generation status = %d, want 401", got)
	}
	lookup.states[uid] = PrincipalSecurityState{AuthGeneration: 2, SecurityState: SecurityStateCompromised, PasswordDisabled: true, PasswordResetRequired: true}
	if got := call(current); got != http.StatusUnauthorized {
		t.Fatalf("disabled principal status = %d, want 401", got)
	}
}

func TestJWTAndRole(t *testing.T) {
	uid := uuid.New()
	adminUID := uuid.New()
	tok := token.NewHelper("secret", time.Minute)
	lookup := &fakeSecurityLookup{
		fakeLookup: &fakeLookup{usernames: map[uuid.UUID]string{uid: "alice", adminUID: "root"}},
		states: map[uuid.UUID]PrincipalSecurityState{
			uid:      {AuthGeneration: 0, SecurityState: SecurityStateNormal},
			adminUID: {AuthGeneration: 0, SecurityState: SecurityStateNormal},
		},
		adminUsers: map[uuid.UUID]bool{adminUID: true},
	}

	call := func(role, authHeader string) int {
		h := JWT(tok, lookup, "")(RequireRole(role)(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			w.WriteHeader(http.StatusOK)
		})))
		req := httptest.NewRequest("GET", "/", nil)
		if authHeader != "" {
			req.Header.Set("Authorization", authHeader)
		}
		rec := httptest.NewRecorder()
		h.ServeHTTP(rec, req)
		return rec.Code
	}

	userTok, _ := tok.GenerateAccessToken(uid)
	adminTok, _ := tok.GenerateAccessToken(adminUID)

	if c := call(RoleUser, ""); c != http.StatusUnauthorized {
		t.Fatalf("missing token: got %d", c)
	}
	if c := call(RoleUser, "Bearer "+userTok); c != http.StatusOK {
		t.Fatalf("user→user: got %d", c)
	}
	if c := call(RoleAdmin, "Bearer "+userTok); c != http.StatusForbidden {
		t.Fatalf("user→admin: got %d", c)
	}
	if c := call(RoleAdmin, "Bearer "+adminTok); c != http.StatusOK {
		t.Fatalf("admin→admin: got %d", c)
	}
}

type fakeGuard struct {
	groupAdmin      map[uuid.UUID]uuid.UUID
	pinPublicMember map[uuid.UUID]bool
}

func (f *fakeGuard) IsGroupAdmin(_ context.Context, gid, uid uuid.UUID) (bool, error) {
	return f.groupAdmin[gid] == uid, nil
}
func (f *fakeGuard) IsGroupMember(_ context.Context, _, _ uuid.UUID) (bool, error)  { return false, nil }
func (f *fakeGuard) IsGroupVisible(_ context.Context, _, _ uuid.UUID) (bool, error) { return true, nil }
func (f *fakeGuard) IsPinCreator(_ context.Context, _, _ uuid.UUID) (bool, error)   { return false, nil }
func (f *fakeGuard) IsPinGroupAdmin(_ context.Context, _, _ uuid.UUID) (bool, error) {
	return false, nil
}
func (f *fakeGuard) IsPinPublicOrMember(_ context.Context, pid, _ uuid.UUID) (bool, error) {
	return f.pinPublicMember[pid], nil
}

func TestGuardMiddleware(t *testing.T) {
	gid := uuid.New()
	admin := uuid.New()
	other := uuid.New()
	g := &fakeGuard{groupAdmin: map[uuid.UUID]uuid.UUID{gid: admin}}

	r := chi.NewRouter()
	r.With(func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, req *http.Request) {
			// inject a test user id via role
			uid := admin
			if q := req.URL.Query().Get("as"); q == "other" {
				uid = other
			}
			ctx := WithUser(req.Context(), uid, RoleUser)
			next.ServeHTTP(w, req.WithContext(ctx))
		})
	}, RequireGroupAdmin(g, "groupId")).Delete("/g/{groupId}", func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusNoContent)
	})

	req := httptest.NewRequest("DELETE", "/g/"+gid.String(), nil)
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)
	if rec.Code != http.StatusNoContent {
		t.Fatalf("admin should pass: got %d", rec.Code)
	}

	req = httptest.NewRequest("DELETE", "/g/"+gid.String()+"?as=other", nil)
	rec = httptest.NewRecorder()
	r.ServeHTTP(rec, req)
	if rec.Code != http.StatusForbidden {
		t.Fatalf("non-admin should be forbidden: got %d", rec.Code)
	}
}

func TestRequireAny(t *testing.T) {
	allow := func(next http.Handler) http.Handler { return next }
	deny := func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
			http.Error(w, "nope", http.StatusForbidden)
		})
	}
	terminal := http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusOK) })

	h := RequireAny(deny, allow)(terminal)
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest("GET", "/", nil))
	if rec.Code != http.StatusOK {
		t.Fatalf("RequireAny with one allow should pass: got %d", rec.Code)
	}

	h = RequireAny(deny, deny)(terminal)
	rec = httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest("GET", "/", nil))
	if rec.Code != http.StatusForbidden {
		t.Fatalf("RequireAny with all deny should be forbidden: got %d", rec.Code)
	}
}
