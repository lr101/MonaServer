package middleware

import (
	"context"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/hex"
	"net"
	"net/http"
	"net/url"
	"sort"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/lrprojects/monaserver/internal/apperrors"
)

// AdminPrincipal is the request-time browser-admin identity. It is populated
// from the database on every request; callers must not copy it into a durable
// token or infer membership from a username.
type AdminPrincipal struct {
	SessionID       string
	UserID          string
	Username        string
	AuthGeneration  int64
	State           string
	CSRFHash        []byte
	CSRFToken       string
	Permissions     []string
	Capabilities    []string
	RecentMFAAt     *time.Time
	RecentMFAAction string
	AuthenticatedAt time.Time
	LastActivityAt  time.Time
	IdleExpiresAt   time.Time
}

// AdminSessionValidator is implemented by the admin-auth service. Keeping the
// middleware dependent on this narrow interface avoids coupling route guards
// to database details while still forcing every request through fresh state.
type AdminSessionValidator interface {
	ValidateAdminSession(context.Context, string) (*AdminPrincipal, error)
}

type adminContextKey int

const (
	adminCookieKey adminContextKey = iota
	adminClientIPKey
	adminResponseWriterKey
	adminPrincipalKey
)

// WithAdminSessionCookie carries the raw HttpOnly cookie into the generated
// service boundary. The value is never logged or returned in a DTO.
func WithAdminSessionCookie(ctx context.Context, value string) context.Context {
	return context.WithValue(ctx, adminCookieKey, value)
}

func AdminSessionCookie(ctx context.Context) string {
	v, _ := ctx.Value(adminCookieKey).(string)
	return v
}

func WithAdminClientIP(ctx context.Context, value string) context.Context {
	return context.WithValue(ctx, adminClientIPKey, value)
}

func AdminClientIP(ctx context.Context) string {
	v, _ := ctx.Value(adminClientIPKey).(string)
	return v
}

// WithAdminResponseWriter lets a generated-servicer implementation set and
// clear the browser cookie without changing the generated method signatures.
func WithAdminResponseWriter(ctx context.Context, w http.ResponseWriter) context.Context {
	return context.WithValue(ctx, adminResponseWriterKey, w)
}

func AdminResponseWriter(ctx context.Context) (http.ResponseWriter, bool) {
	w, ok := ctx.Value(adminResponseWriterKey).(http.ResponseWriter)
	return w, ok
}

func WithAdminPrincipal(ctx context.Context, principal AdminPrincipal) context.Context {
	return context.WithValue(ctx, adminPrincipalKey, principal)
}

func AdminPrincipalFromContext(ctx context.Context) (AdminPrincipal, bool) {
	p, ok := ctx.Value(adminPrincipalKey).(AdminPrincipal)
	return p, ok
}

// CaptureAdminRequest carries request metadata into generated handlers. It
// does not inspect or persist credentials.
func CaptureAdminRequest(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ctx := WithAdminResponseWriter(r.Context(), w)
		if cookie, err := r.Cookie("admin_session"); err == nil {
			ctx = WithAdminSessionCookie(ctx, cookie.Value)
		}
		ip := r.RemoteAddr
		if host, _, err := net.SplitHostPort(ip); err == nil {
			ip = host
		}
		if strings.TrimSpace(ip) == "" {
			ip = "unknown"
		}
		ctx = WithAdminClientIP(ctx, ip)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

// AdminSessionGuard authenticates the dedicated browser cookie and injects a
// fresh principal. Bearer headers are deliberately ignored and can never be
// used as an admin-session fallback.
func AdminSessionGuard(validator AdminSessionValidator) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if validator == nil {
				writeAdminError(w, http.StatusServiceUnavailable, "feature_unavailable", "admin authentication is unavailable")
				return
			}
			cookie, err := r.Cookie("admin_session")
			if err != nil || strings.TrimSpace(cookie.Value) == "" {
				writeAdminError(w, http.StatusUnauthorized, "unauthorized", "admin browser session required")
				return
			}
			principal, err := validator.ValidateAdminSession(r.Context(), cookie.Value)
			if err != nil {
				if apperrors.HTTPStatus(err) == http.StatusServiceUnavailable {
					writeAdminError(w, http.StatusServiceUnavailable, "feature_unavailable", "admin authentication is unavailable")
					return
				}
				writeAdminError(w, http.StatusUnauthorized, "unauthorized", "admin browser session required")
				return
			}
			if principal == nil {
				writeAdminError(w, http.StatusUnauthorized, "unauthorized", "admin browser session required")
				return
			}
			ctx := WithAdminSessionCookie(r.Context(), cookie.Value)
			ctx = WithAdminPrincipal(ctx, *principal)
			// Preserve the actor context consumed by existing v2 handlers while
			// deriving it from the freshly validated stable user ID.
			if userID, parseErr := uuid.Parse(principal.UserID); parseErr == nil {
				ctx = WithUser(ctx, userID, RoleAdmin)
			}
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

// AdminPreAuthGuard admits only the short-lived, HMAC-bound pre-auth cookie to
// password and initial-MFA endpoints. Consumer bearer credentials are never a
// substitute for this browser state.
func AdminPreAuthGuard(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		cookie, err := r.Cookie("admin_session")
		if err != nil || !strings.HasPrefix(strings.TrimSpace(cookie.Value), "p.") {
			writeAdminError(w, http.StatusUnauthorized, "unauthorized", "admin pre-authentication is required")
			return
		}
		next.ServeHTTP(w, r)
	})
}

// AdminCSRFGuard applies the double-submit proof to every authenticated
// browser-admin mutation. Session endpoints perform the same check inside the
// service, while this guard protects legacy v2 and future v3 handlers that do
// not receive CSRF as an explicit generated parameter.
func AdminCSRFGuard(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodGet || r.Method == http.MethodHead || r.Method == http.MethodOptions {
			next.ServeHTTP(w, r)
			return
		}
		principal, ok := AdminPrincipalFromContext(r.Context())
		if !ok {
			writeAdminError(w, http.StatusUnauthorized, "unauthorized", "admin browser session required")
			return
		}
		if !CSRFMatches(principal.CSRFHash, strings.TrimSpace(r.Header.Get("X-CSRF-Token"))) {
			writeAdminError(w, http.StatusForbidden, "invalid_csrf", "invalid csrf token")
			return
		}
		next.ServeHTTP(w, r)
	})
}

// AdminRecentMFAGuard requires a fresh MFA proof for all authenticated admin
// mutations. The route-level boundary intentionally errs on the side of
// requiring step-up for every write; handlers still enforce their capability
// and action-specific checks when the operation is implemented.
func AdminRecentMFAGuard(ttl time.Duration) func(http.Handler) http.Handler {
	if ttl <= 0 {
		ttl = 5 * time.Minute
	}
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if r.Method == http.MethodGet || r.Method == http.MethodHead || r.Method == http.MethodOptions {
				next.ServeHTTP(w, r)
				return
			}
			principal, ok := AdminPrincipalFromContext(r.Context())
			if !ok {
				writeAdminError(w, http.StatusUnauthorized, "unauthorized", "admin browser session required")
				return
			}
			if !RecentMFAAtValid(principal.RecentMFAAt, time.Now().UTC(), ttl) {
				writeAdminError(w, http.StatusForbidden, "recent_mfa_required", "recent mfa is required")
				return
			}
			requiredAction := AdminMutationAction(r.Method, r.URL.Path)
			if !RecentMFAActionMatches(principal.RecentMFAAction, requiredAction) {
				writeAdminError(w, http.StatusForbidden, "recent_mfa_required", "recent mfa is bound to another action")
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}

// RecentMFAAtValid is kept in middleware so guards can be unit-tested without
// importing the service package (which already imports this package).
func RecentMFAAtValid(at *time.Time, now time.Time, ttl time.Duration) bool {
	return at != nil && ttl > 0 && !at.After(now) && now.Sub(*at) < ttl
}

// AdminMutationAction names the action family represented by a route. Empty
// means that the body carries the action union and the route-level guard uses
// the fresh session proof without guessing at its value.
func AdminMutationAction(method, path string) string {
	if method == http.MethodGet || method == http.MethodHead || method == http.MethodOptions {
		return ""
	}
	path = strings.TrimSuffix(path, "/")
	switch {
	case path == "/api/v2/admin/mail":
		return "email"
	case path == "/api/v2/admin/notification":
		return "push"
	case path == "/api/v3/admin/messages/test":
		return "push"
	case path == "/api/v3/admin/audiences/preview":
		return ""
	case strings.HasPrefix(path, "/api/v3/admin/reports/"):
		return ""
	default:
		return ""
	}
}

func RecentMFAActionMatches(stored, required string) bool {
	return strings.TrimSpace(stored) == "" || required == "" || stored == required
}

// AdminCapabilityGuard applies the stable capability matrix to the known
// admin route groups. Unknown admin paths fail closed.
func AdminCapabilityGuard(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		principal, ok := AdminPrincipalFromContext(r.Context())
		if !ok || (principal.State != "" && principal.State != "authenticated") {
			writeAdminError(w, http.StatusUnauthorized, "unauthorized", "admin browser session required")
			return
		}
		required := RequiredAdminCapability(r.Method, r.URL.Path)
		if required == "" || !hasCapability(principal.Capabilities, required) {
			writeAdminError(w, http.StatusForbidden, "forbidden", "admin capability required")
			return
		}
		next.ServeHTTP(w, r)
	})
}

func hasCapability(capabilities []string, required string) bool {
	for _, capability := range capabilities {
		if capability == required {
			return true
		}
	}
	return false
}

func RequiredAdminCapability(method, path string) string {
	path = strings.TrimSuffix(path, "/")
	switch {
	case path == "/api/v2/admin/mail":
		return "campaign.email"
	case path == "/api/v2/admin/notification":
		return "campaign.push"
	case path == "/api/v3/admin/users" || strings.HasPrefix(path, "/api/v3/admin/users/"):
		return "users.read"
	case path == "/api/v3/admin/audiences/preview":
		return "audience.preview"
	case strings.HasPrefix(path, "/api/v3/admin/audiences/"):
		return "audience.read"
	case path == "/api/v3/admin/jobs":
		if method == http.MethodGet {
			return "jobs.read"
		}
		return "jobs.create"
	case strings.HasPrefix(path, "/api/v3/admin/jobs/"):
		if strings.HasSuffix(path, "/retry") || strings.HasSuffix(path, "/cancel") {
			return "jobs.control"
		}
		return "jobs.read"
	case path == "/api/v3/admin/messages/test":
		return "messages.test"
	case path == "/api/v3/admin/reports" || strings.HasPrefix(path, "/api/v3/admin/reports/"):
		if method == http.MethodGet {
			return "reports.read"
		}
		return "reports.review"
	case path == "/api/v3/admin/audit":
		return "audit.read"
	default:
		return ""
	}
}

// AdminOriginGuard enforces same-site origin/referrer checks for every state
// changing admin request. Read requests are safe without an Origin header.
func AdminOriginGuard(allowedOrigin string) func(http.Handler) http.Handler {
	allowedOrigin = normalizeOrigin(allowedOrigin)
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if r.Method == http.MethodGet || r.Method == http.MethodHead || r.Method == http.MethodOptions {
				next.ServeHTTP(w, r)
				return
			}
			origin := normalizeOrigin(r.Header.Get("Origin"))
			if origin == "" {
				origin = refererOrigin(r.Header.Get("Referer"))
			}
			if origin == "" || allowedOrigin == "" || origin != allowedOrigin {
				writeAdminError(w, http.StatusForbidden, "forbidden", "same-site origin required")
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}

// AdminCORS allows credentialed requests only from the configured admin
// origin. It intentionally does not emit wildcard credentialed CORS headers.
func AdminCORS(allowedOrigin string) func(http.Handler) http.Handler {
	allowedOrigin = normalizeOrigin(allowedOrigin)
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			// The process-wide consumer CORS middleware runs outside this guard.
			// Remove its wildcard headers before deciding whether this request is
			// allowed to carry browser-admin credentials.
			w.Header().Del("Access-Control-Allow-Origin")
			w.Header().Del("Access-Control-Allow-Credentials")
			w.Header().Del("Access-Control-Allow-Headers")
			w.Header().Del("Access-Control-Allow-Methods")
			origin := normalizeOrigin(r.Header.Get("Origin"))
			if origin != "" && origin == allowedOrigin {
				w.Header().Set("Access-Control-Allow-Origin", allowedOrigin)
				w.Header().Set("Access-Control-Allow-Credentials", "true")
				w.Header().Add("Vary", "Origin")
				w.Header().Set("Access-Control-Allow-Headers", "Content-Type, X-CSRF-Token, Idempotency-Key")
				w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PATCH, OPTIONS")
			}
			if r.Method == http.MethodOptions {
				if origin == "" || origin != allowedOrigin {
					writeAdminError(w, http.StatusForbidden, "forbidden", "admin origin is not allowed")
					return
				}
				w.WriteHeader(http.StatusNoContent)
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}

// TrustedRealIP normalizes RemoteAddr only when the direct peer is in the
// configured proxy networks. Forwarded headers from an untrusted peer are
// ignored, so an attacker cannot choose the per-IP authentication quota key.
// TRUSTED_PROXY_CIDRS is a comma-separated list of CIDR blocks.
func TrustedRealIP(cidrs string) func(http.Handler) http.Handler {
	trusted := parseTrustedNetworks(cidrs)
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			peer := remoteHost(r.RemoteAddr)
			client := peer
			if ip := net.ParseIP(peer); ip != nil && ipInNetworks(ip, trusted) {
				if forwarded := forwardedClientIP(r, trusted); forwarded != "" {
					client = forwarded
				}
			}
			if parsed := net.ParseIP(client); parsed != nil {
				port := ""
				if _, p, err := net.SplitHostPort(r.RemoteAddr); err == nil {
					port = p
				}
				if port != "" {
					r.RemoteAddr = net.JoinHostPort(parsed.String(), port)
				} else {
					r.RemoteAddr = parsed.String()
				}
			}
			next.ServeHTTP(w, r)
		})
	}
}

func parseTrustedNetworks(raw string) []*net.IPNet {
	var networks []*net.IPNet
	for _, value := range strings.Split(raw, ",") {
		value = strings.TrimSpace(value)
		if value == "" {
			continue
		}
		if _, network, err := net.ParseCIDR(value); err == nil {
			networks = append(networks, network)
		}
	}
	return networks
}

func ipInNetworks(ip net.IP, networks []*net.IPNet) bool {
	for _, network := range networks {
		if network.Contains(ip) {
			return true
		}
	}
	return false
}

func remoteHost(remote string) string {
	if host, _, err := net.SplitHostPort(strings.TrimSpace(remote)); err == nil {
		return host
	}
	return strings.TrimSpace(remote)
}

func forwardedClientIP(r *http.Request, trusted []*net.IPNet) string {
	// X-Forwarded-For is a right-to-left chain. Select the first valid address
	// that is not itself a configured trusted proxy; malformed values cause us
	// to fall back to the direct peer instead of trusting attacker input.
	parts := strings.Split(r.Header.Get("X-Forwarded-For"), ",")
	for i := len(parts) - 1; i >= 0; i-- {
		ip := net.ParseIP(strings.TrimSpace(parts[i]))
		if ip == nil {
			return ""
		}
		if !ipInNetworks(ip, trusted) {
			return ip.String()
		}
	}
	if ip := net.ParseIP(strings.TrimSpace(r.Header.Get("X-Real-IP"))); ip != nil {
		return ip.String()
	}
	return ""
}

func normalizeOrigin(raw string) string {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return ""
	}
	u, err := url.Parse(raw)
	if err != nil || u.Scheme == "" || u.Host == "" || u.User != nil || u.Path != "" || u.RawQuery != "" || u.Fragment != "" {
		return ""
	}
	return strings.ToLower(u.Scheme) + "://" + strings.ToLower(u.Host)
}

func refererOrigin(raw string) string {
	u, err := url.Parse(strings.TrimSpace(raw))
	if err != nil || u.Scheme == "" || u.Host == "" {
		return ""
	}
	return normalizeOrigin(u.Scheme + "://" + u.Host)
}

func writeAdminError(w http.ResponseWriter, status int, code, message string) {
	w.Header().Set("Content-Type", "application/json; charset=UTF-8")
	w.WriteHeader(status)
	_, _ = w.Write([]byte(`{"code":"` + code + `","message":"` + message + `"}`))
}

// CSRFHash and CSRFMatches are shared by the service and middleware. Hashing
// keeps the submitted value out of database rows and comparisons constant-time.
func CSRFHash(token string) []byte {
	sum := sha256.Sum256([]byte(token))
	return sum[:]
}

func CSRFMatches(hash []byte, token string) bool {
	expected := CSRFHash(token)
	return len(hash) == len(expected) && subtle.ConstantTimeCompare(hash, expected) == 1
}

func EncodeHash(hash []byte) string { return hex.EncodeToString(hash) }

func SortStrings(values []string) []string {
	result := append([]string(nil), values...)
	sort.Strings(result)
	return result
}
