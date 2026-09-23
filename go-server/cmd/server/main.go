package main

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	chimw "github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"
	"github.com/google/uuid"

	"github.com/lrprojects/monaserver/internal/config"
	"github.com/lrprojects/monaserver/internal/db"
	genapi "github.com/lrprojects/monaserver/internal/gen/api"
	genserver "github.com/lrprojects/monaserver/internal/gen/server"
	"github.com/lrprojects/monaserver/internal/handler"
	"github.com/lrprojects/monaserver/internal/middleware"
	"github.com/lrprojects/monaserver/internal/scheduler"
	"github.com/lrprojects/monaserver/internal/service"
	"github.com/lrprojects/monaserver/internal/token"
)

func main() {
	if len(os.Args) > 1 && os.Args[1] == "healthcheck" {
		if err := runHealthcheck(); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		return
	}

	log := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	slog.SetDefault(log)

	cfg, err := config.Load()
	must(err, "load config")
	reportConfig, err := newReportServiceConfig(cfg)
	must(err, "report config")

	ctx := context.Background()
	if err := db.RunMigrations(cfg.DatabaseURL); err != nil {
		log.Error("migrations", "err", err)
		os.Exit(1)
	}

	pool, err := db.NewPool(ctx, cfg.DatabaseURL)
	must(err, "db pool")
	defer pool.Close()

	q := db.New(pool)
	tok := token.NewHelper(cfg.JWTSecret, cfg.AccessTokenExpiry)
	mailSvc := newMailService(cfg)
	authSvc := service.NewAuth(q, tok, cfg, mailSvc)
	guardSvc := service.NewGuard(q)

	var objSvc *service.Object
	if cfg.RustfsEndpoint != "" {
		o, err := service.NewObject(cfg.RustfsEndpoint, cfg.RustfsExternalEndpoint,
			cfg.RustfsAccessKey, cfg.RustfsSecretKey,
			cfg.RustfsBucket, cfg.RustfsUseSSL, cfg.RustfsURLExpiry)
		if err != nil {
			log.Error("rustfs init", "err", err)
		} else if err := o.EnsureBucket(ctx); err != nil {
			log.Warn("rustfs ensure bucket", "err", err)
		} else {
			log.Info("rustfs ready", "bucket", cfg.RustfsBucket)
			objSvc = o
		}
	}
	notifSvc := service.NewNotification(ctx, cfg.FirebaseConfigPath)

	achMonaGroupID, _ := uuid.Parse(cfg.AchievementMonaGroupID)
	achCreatedBefore, _ := time.Parse(time.RFC3339, cfg.AchievementCreatedBefore)
	achCfg := db.AchievementConfig{MonaGroupID: achMonaGroupID, CreatedBefore: achCreatedBefore}

	userSvc := service.NewUser(q, objSvc, tok, authSvc, mailSvc)
	groupSvc := service.NewGroup(q, objSvc, userSvc)
	pinSvc := service.NewPin(q, objSvc)
	memberSvc := service.NewMember(q, objSvc, groupSvc)
	likeSvc := service.NewLike(q)
	rankSvc := service.NewRanking(q)
	seasonSvc := service.NewSeason(q)

	// Servicers wrapping business logic and implementing genserver interfaces.
	authServicer := handler.NewAuthServicer(authSvc, q, mailSvc)
	groupsServicer := handler.NewGroupsServicer(groupSvc, guardSvc)
	pinsServicer := handler.NewPinsServicer(pinSvc, groupSvc, guardSvc, q)
	membersServicer := handler.NewMembersServicer(memberSvc, guardSvc)
	likesServicer := handler.NewLikesServicer(likeSvc, guardSvc)
	rankingServicer := handler.NewRankingServicer(rankSvc)
	adminServicer := handler.NewAdminServicer(q, mailSvc, notifSvc)
	adminAuthConfig := service.AdminAuthConfig{
		EncryptionKey:      decodeAdminKey(cfg.AdminTOTPEncryptionKey),
		EncryptionKeyID:    cfg.AdminTOTPEncryptionKeyID,
		HMACKey:            decodeAdminKey(cfg.AdminSessionHMACKey),
		HMACKeyID:          cfg.AdminSessionHMACKeyID,
		SessionIdleTTL:     cfg.AdminSessionIdleTTL,
		SessionAbsoluteTTL: cfg.AdminSessionAbsoluteTTL,
		ChallengeTTL:       cfg.AdminChallengeTTL,
		RecentMFATTL:       cfg.AdminRecentMFATTL,
		PreAuthTTL:         cfg.AdminPreAuthTTL,
		LoginFailureLimit:  cfg.AdminLoginFailureLimit,
		LoginIPLimit:       cfg.AdminLoginIPLimit,
		LoginGlobalLimit:   cfg.AdminLoginGlobalLimit,
		AdminOrigin:        cfg.AdminOrigin,
	}
	adminAuth := service.NewAdminAuth(q, adminAuthConfig)
	reportServicer := handler.NewReportServicer(mailSvc, q, reportConfig)
	publicServicer := handler.NewPublicServicer()
	usersServicer := handler.NewUsersServicer(userSvc, guardSvc, q, achCfg)
	batchServicer := handler.NewBatchServicer(pinsServicer, usersServicer, groupsServicer, likesServicer, guardSvc)

	// Generated controllers (handle HTTP param parsing).
	authCtrl := genserver.NewAuthAPIController(authServicer)
	groupsCtrl := genserver.NewGroupsAPIController(groupsServicer)
	pinsCtrl := genserver.NewPinsAPIController(pinsServicer)
	membersCtrl := genserver.NewMembersAPIController(membersServicer)
	likesCtrl := genserver.NewLikesAPIController(likesServicer)
	rankingCtrl := genserver.NewRankingAPIController(rankingServicer)
	adminCtrl := genserver.NewAdminAPIController(adminServicer)
	reportCtrl := genserver.NewReportAPIController(reportServicer)
	publicCtrl := genserver.NewPublicAPIController(publicServicer)
	usersCtrl := genserver.NewUsersAPIController(usersServicer)
	batchCtrl := genserver.NewBatchAPIController(batchServicer, genserver.WithBatchAPIErrorHandler(handler.BatchAPIErrorHandler))

	viewsH := handler.NewViews(q, tok, cfg.RedirectURL)

	sched := scheduler.New()
	_ = sched.AddWeeklyNotification(func(c context.Context) {
		targets, err := q.FindUsersWithNewPins(c)
		if err != nil {
			log.Error("weekly notification query", "err", err)
			return
		}
		for _, t := range targets {
			if err := sendWeeklyNotification(c, notifSvc, q, t); err != nil {
				log.Warn("weekly notification failed; token cleared", "user", t.UserID, "err", err)
			}
		}
		log.Info("weekly notifications sent", "count", len(targets))
	})
	_ = sched.AddMonthlySeason(func(c context.Context) {
		now := time.Now()
		if now.Day() != daysInMonth(now) {
			return
		}
		result, err := seasonSvc.CreateMonth(c, now)
		if err != nil {
			log.Error("season: create", "err", err)
			return
		}
		log.Info("monthly season created", "season", result.Number, "users", result.Users, "groups", result.Groups)
	})
	sched.Start()
	defer sched.Stop()

	r := chi.NewRouter()
	r.Use(chimw.RequestID)
	r.Use(middleware.TrustedRealIP(cfg.TrustedProxyCIDRs))
	r.Use(chimw.Recoverer)
	r.Use(chimw.Timeout(30 * time.Second))
	r.Use(requestLogger(log))
	// Consumer CORS remains permissive, while admin paths are dispatched to
	// the credentialed origin-bound policy before the global handler can emit
	// wildcard headers. The admin dispatch is the passthrough boundary; the
	// consumer handler retains its existing standalone preflight behavior.
	r.Use(globalCORS(cfg.AdminOrigin))

	// OpenAPI spec + Swagger UI.
	r.Get("/public/api-docs", serveOpenAPISpec)
	r.Get("/public/api-docs/", serveOpenAPISpec)
	r.Get("/swagger-ui", serveSwaggerUI)

	// HTML view routes (no auth).
	r.Get("/", viewsH.Root)
	r.Get("/favicon.ico", viewsH.Favicon)
	r.Get("/public/favicon.ico", viewsH.Favicon)
	r.Get("/public/recover/{url}", viewsH.RecoverPassword)
	r.Get("/public/delete-account/code", viewsH.RequestDeleteCode)
	r.Get("/public/delete-account/{url}", viewsH.DeleteAccountView)
	r.Get("/public/email-confirmation/{url}", viewsH.EmailConfirmation)
	r.Get("/public/agb", viewsH.Agb)
	r.Get("/public/privacy-policy", viewsH.PrivacyPolicy)

	// Public routes (no auth): login, signup, refresh, recover, delete-code + public info.
	// Account entry and delete-code workflows are public routes.
	r.Group(func(r chi.Router) {
		registerRoutes(r, authCtrl, isPublicRoute)
		registerRoutes(r, authCtrl, isDeleteCodeRoute)
		registerRoutes(r, publicCtrl, alwaysTrue)
	})

	// Status endpoint — requires valid JWT to confirm token validity.
	registerProtectedStatusRoutes(r, authCtrl, tok, authSvc, cfg.AdminUsername)

	// Authenticated routes: require JWT + USER role.
	r.Group(func(r chi.Router) {
		r.Use(middleware.JWT(tok, authSvc, cfg.AdminUsername))
		r.Use(middleware.RequireRole(middleware.RoleUser))
		r.Use(redirectImageResponses)
		r.Use(requireCompatibilityJSONFields)
		r.Use(validateCoupledQueryParameters)
		r.Use(unpagedWhenPageMissing)
		r.Use(validateBatchReadJSON)

		registerRoutes(r, groupsCtrl, alwaysTrue)
		registerRoutes(r, pinsCtrl, alwaysTrue)
		registerRoutes(r, membersCtrl, alwaysTrue)
		registerRoutes(r, likesCtrl, alwaysTrue)
		registerRoutes(r, rankingCtrl, alwaysTrue)
		// CaptureReportRequest runs after TrustedRealIP (installed on the root
		// router), so the service receives the bounded idempotency key and the
		// trusted client address used by the shared report quota.
		registerRoutes(r.With(handler.CaptureReportRequest), reportCtrl, alwaysTrue)
		registerRoutes(r, usersCtrl, alwaysTrue)
		registerRoutes(r, batchCtrl, alwaysTrue)
	})

	// Admin-only routes.
	registerAdminV2Routes(r, adminCtrl, adminAuth, cfg.AdminOrigin, cfg.WebAdminAPI)

	// New v3 routes are always present in the router so their feature and
	// authentication behavior is observable. With the production database and
	// browser-admin authentication service, the admin operation surfaces use
	// the reviewed bounded runtime adapter.
	registerV3Routes(r, cfg, tok, authSvc, cfg.AdminUsername, adminAuth, q)

	addr := ":" + cfg.Port
	log.Info("server listening", "addr", addr)
	srv := &http.Server{Addr: addr, Handler: r, ReadHeaderTimeout: 10 * time.Second}
	if err := srv.ListenAndServe(); err != nil {
		log.Error("server", "err", err)
		os.Exit(1)
	}
}

func runHealthcheck() error {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	return checkHealth(&http.Client{Timeout: 2 * time.Second}, "http://127.0.0.1:"+port+"/public/api-docs")
}

func checkHealth(client *http.Client, target string) error {
	response, err := client.Get(target)
	if err != nil {
		return fmt.Errorf("healthcheck request failed: %w", err)
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		return fmt.Errorf("healthcheck returned %s", response.Status)
	}
	return nil
}

func newMailService(cfg *config.Config) *service.Email {
	if cfg.MailHost == "" {
		return nil
	}
	return service.NewEmail(cfg, nil)
}

// decodeAdminKey accepts the deployment formats used by existing secrets
// managers while keeping malformed values unavailable at request time. The
// service still validates the encryption key length before decrypting.
func decodeAdminKey(raw string) []byte {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return nil
	}
	if decoded, err := hex.DecodeString(raw); err == nil && len(decoded) > 0 {
		return decoded
	}
	if decoded, err := base64.RawStdEncoding.DecodeString(raw); err == nil && len(decoded) > 0 {
		return decoded
	}
	if decoded, err := base64.StdEncoding.DecodeString(raw); err == nil && len(decoded) > 0 {
		return decoded
	}
	return []byte(raw)
}

func newReportServiceConfig(cfg *config.Config) (service.ReportServiceConfig, error) {
	if cfg == nil {
		return service.ReportServiceConfig{}, errors.New("config is nil")
	}
	reportConfig := service.ReportServiceConfig{
		HMACKey:   decodeAdminKey(cfg.AdminSessionHMACKey),
		HMACKeyID: cfg.AdminSessionHMACKeyID,
	}
	if err := reportConfig.Validate(); err != nil {
		return service.ReportServiceConfig{}, err
	}
	return reportConfig, nil
}

// registerRoutes registers controller routes into r, filtered by predicate on the pattern.
func registerRoutes(r chi.Router, ctrl genserver.Router, pred func(string) bool) {
	for _, route := range ctrl.OrderedRoutes() {
		if pred(route.Pattern) {
			r.Method(route.Method, route.Pattern, route.HandlerFunc)
		}
	}
}

// globalCORS keeps the process-wide consumer policy from answering admin
// preflights with Access-Control-Allow-Origin: *. Admin cookies are only
// usable from the configured browser origin, so both admin preflights and
// actual requests pass through the same credentialed policy used by each
// admin route group.
func globalCORS(adminOrigin string) func(http.Handler) http.Handler {
	consumer := cors.Handler(cors.Options{
		AllowedOrigins:   []string{"*"},
		AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"*"},
		AllowCredentials: false,
	})
	admin := middleware.AdminCORS(adminOrigin)
	return func(next http.Handler) http.Handler {
		consumerHandler := consumer(next)
		adminHandler := admin(next)
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if isAdminRequestPath(r.URL.Path) {
				adminHandler.ServeHTTP(w, r)
				return
			}
			consumerHandler.ServeHTTP(w, r)
		})
	}
}

func isAdminRequestPath(path string) bool {
	return path == "/api/v2/admin" || strings.HasPrefix(path, "/api/v2/admin/") ||
		path == "/api/v3/admin" || strings.HasPrefix(path, "/api/v3/admin/")
}

// registerAdminV2Routes retires the legacy username/JWT admin boundary. The
// v2 payloads remain wire-compatible, but an opaque browser session and the
// same origin/CSRF/capability policy as v3 are now required.
// The optional flag preserves compatibility with older in-package test
// fixtures; the production call always supplies cfg.WebAdminAPI.
func registerAdminV2Routes(r chi.Router, ctrl genserver.Router, auth *service.AdminAuth, origin string, enabled ...bool) {
	adminEnabled := true
	if len(enabled) > 0 {
		adminEnabled = enabled[0]
	}
	r.Group(func(r chi.Router) {
		r.Use(v3FeatureFlag(adminEnabled))
		r.Use(middleware.CaptureAdminRequest)
		r.Use(middleware.AdminCORS(origin))
		r.Use(middleware.AdminSessionGuard(auth))
		r.Use(middleware.AdminOriginGuard(origin))
		r.Use(middleware.AdminCSRFGuard)
		r.Use(middleware.AdminRecentMFAGuard(adminRecentMFATTL(auth)))
		r.Use(middleware.AdminCapabilityGuard)
		registerRoutes(r, ctrl, alwaysTrue)
	})
}

func adminRecentMFATTL(auth *service.AdminAuth) time.Duration {
	return auth.RecentMFATTL()
}

type v3AdminServicers struct {
	users     genserver.AdminUsersAPIServicer
	campaigns genserver.AdminCampaignsAPIServicer
	audiences genserver.AdminAudiencesAPIServicer
	jobs      genserver.AdminJobsAPIServicer
	messages  genserver.AdminMessagesAPIServicer
	reports   genserver.AdminReportsAPIServicer
	audit     genserver.AdminAuditAPIServicer
}

// newV3AdminServicers keeps the production assembly separate from route
// middleware. The unavailable set is deliberately retained for the no-DB
// compatibility seam; a supplied database and browser-admin auth service get
// the concrete, bounded adapters together.
func newV3AdminServicers(queries *db.Queries, auth *service.AdminAuth) v3AdminServicers {
	unavailable := handler.NewUnavailableV3Servicer()
	servicers := v3AdminServicers{
		users: unavailable, campaigns: unavailable, audiences: unavailable, jobs: unavailable,
		messages: unavailable, reports: unavailable, audit: unavailable,
	}
	if queries == nil || auth == nil {
		return servicers
	}
	store := service.NewProductionAdminStore(queries)
	audiences := service.NewAdminAudienceService(store)
	jobs := service.NewAdminBulkService(store, audiences, nil, auth)
	servicers.users = handler.NewAdminUsersServicer(service.NewAdminUserService(store))
	servicers.campaigns = handler.NewAdminCampaignsServicer(service.NewCampaignService(service.NewProductionCampaignStore(queries)))
	servicers.audiences = handler.NewAdminAudienceServicer(audiences)
	servicers.jobs = handler.NewAdminJobsServicer(jobs)
	servicers.messages = handler.NewAdminMessagesServicer(jobs)
	servicers.reports = handler.NewAdminReportsServicer(queries)
	servicers.audit = handler.NewAdminAuditServicer(service.NewAdminAuditService(store))
	return servicers
}

// registerV3Routes installs the additive v3 surfaces behind their independent
// feature flags. Options may include the browser-admin service and the shared
// report repository. Keeping the options variadic preserves the compatibility
// test seam that exercises the unavailable scaffold without a database.
func registerV3Routes(r chi.Router, cfg *config.Config, tok *token.Helper, lookup middleware.UserLookup, adminUsername string, options ...interface{}) {
	if cfg == nil {
		cfg = &config.Config{}
	}
	var adminAuth *service.AdminAuth
	var reportQueries *db.Queries
	for _, option := range options {
		switch value := option.(type) {
		case *service.AdminAuth:
			adminAuth = value
		case *db.Queries:
			reportQueries = value
		}
	}

	servicer := handler.NewUnavailableV3Servicer()
	publicAuthCtrl := genserver.NewPublicAuthAPIController(servicer, genserver.WithPublicAuthAPIErrorHandler(handler.V3ErrorHandler))
	sessionAuthCtrl := genserver.NewSessionAuthAPIController(servicer, genserver.WithSessionAuthAPIErrorHandler(handler.V3ErrorHandler))
	adminServicers := newV3AdminServicers(reportQueries, adminAuth)
	adminUsersCtrl := genserver.NewAdminUsersAPIController(adminServicers.users, genserver.WithAdminUsersAPIErrorHandler(handler.V3ErrorHandler))
	adminCampaignsCtrl := genserver.NewAdminCampaignsAPIController(adminServicers.campaigns, genserver.WithAdminCampaignsAPIErrorHandler(handler.V3ErrorHandler))
	adminAudiencesCtrl := genserver.NewAdminAudiencesAPIController(adminServicers.audiences, genserver.WithAdminAudiencesAPIErrorHandler(handler.V3ErrorHandler))
	adminJobsCtrl := genserver.NewAdminJobsAPIController(adminServicers.jobs, genserver.WithAdminJobsAPIErrorHandler(handler.V3ErrorHandler))
	adminMessagesCtrl := genserver.NewAdminMessagesAPIController(adminServicers.messages, genserver.WithAdminMessagesAPIErrorHandler(handler.V3ErrorHandler))
	adminReportsCtrl := genserver.NewAdminReportsAPIController(adminServicers.reports, genserver.WithAdminReportsAPIErrorHandler(handler.V3ErrorHandler))
	adminAuditCtrl := genserver.NewAdminAuditAPIController(adminServicers.audit, genserver.WithAdminAuditAPIErrorHandler(handler.V3ErrorHandler))

	// Public email-link and recovery endpoints are intentionally public, but
	// remain unavailable while PUBLIC_EMAIL_LOGIN is false.
	r.Group(func(r chi.Router) {
		r.Use(v3FeatureFlag(cfg.PublicEmailLogin))
		registerRoutes(r, publicAuthCtrl, alwaysTrue)
	})

	// Own-session revoke is the one new endpoint that uses a consumer Bearer
	// credential. It is independent from the browser-admin session transport.
	r.Group(func(r chi.Router) {
		r.Use(v3FeatureFlag(cfg.PublicEmailLogin))
		r.Use(middleware.JWT(tok, lookup, adminUsername))
		r.Use(middleware.RequireRole(middleware.RoleUser))
		registerRoutes(r, sessionAuthCtrl, alwaysTrue)
	})

	// Bootstrap is the only public admin-session endpoint. It still receives
	// origin/CORS protection because it sets a credentialed browser cookie.
	var adminSessionCtrl *genserver.AdminSessionAPIController
	if adminAuth != nil {
		adminSessionServicer := handler.NewAdminSessionServicer(adminAuth)
		adminSessionCtrl = genserver.NewAdminSessionAPIController(adminSessionServicer, genserver.WithAdminSessionAPIErrorHandler(handler.V3ErrorHandler))
	} else {
		adminSessionCtrl = genserver.NewAdminSessionAPIController(servicer, genserver.WithAdminSessionAPIErrorHandler(handler.V3ErrorHandler))
	}
	r.Group(func(r chi.Router) {
		r.Use(v3FeatureFlag(cfg.WebAdminAPI))
		if adminAuth != nil {
			r.Use(middleware.CaptureAdminRequest)
			r.Use(middleware.AdminCORS(cfg.AdminOrigin))
			r.Use(middleware.AdminOriginGuard(cfg.AdminOrigin))
		}
		registerRoutes(r, adminSessionCtrl, isAdminBootstrapRoute)
	})

	if adminAuth == nil {
		// Compatibility scaffold: reject every bearer-only request and only let a
		// request carrying a cookie reach the unavailable adapter.
		r.Group(func(r chi.Router) {
			r.Use(v3FeatureFlag(cfg.WebAdminAPI))
			r.Use(requireAdminBrowserSession)
			registerRoutes(r, adminSessionCtrl, isNonBootstrapAdminRoute)
			registerRoutes(r.With(handler.CaptureAdminUsersQuery), adminUsersCtrl, alwaysTrue)
			registerRoutes(r, adminCampaignsCtrl, alwaysTrue)
			registerRoutes(r, adminAudiencesCtrl, alwaysTrue)
			registerRoutes(r, adminJobsCtrl, alwaysTrue)
			registerRoutes(r, adminMessagesCtrl, alwaysTrue)
			registerRoutes(r, adminReportsCtrl, alwaysTrue)
			registerRoutes(r, adminAuditCtrl, alwaysTrue)
		})
		return
	}

	// Password and initial-MFA challenges use only a pre-auth envelope. They do
	// not pass through the authenticated CSRF/recent-MFA guards below; the
	// generated service receives and verifies their explicit CSRF header.
	r.Group(func(r chi.Router) {
		r.Use(v3FeatureFlag(cfg.WebAdminAPI))
		r.Use(middleware.CaptureAdminRequest)
		r.Use(middleware.AdminCORS(cfg.AdminOrigin))
		r.Use(middleware.AdminOriginGuard(cfg.AdminOrigin))
		r.Use(middleware.AdminPreAuthGuard)
		registerRoutes(r, adminSessionCtrl, isAdminPreAuthSessionRoute)
	})

	// Session restoration and reauthentication/logout use the authenticated
	// cookie; reauthentication performs the action-bound TOTP proof in the
	// service and rotates CSRF before returning.
	r.Group(func(r chi.Router) {
		r.Use(v3FeatureFlag(cfg.WebAdminAPI))
		r.Use(middleware.CaptureAdminRequest)
		r.Use(middleware.AdminCORS(cfg.AdminOrigin))
		r.Use(middleware.AdminSessionGuard(adminAuth))
		r.Use(middleware.AdminOriginGuard(cfg.AdminOrigin))
		r.Use(middleware.AdminCSRFGuard)
		registerRoutes(r, adminSessionCtrl, isAdminAuthenticatedSessionRoute)
	})

	// Every implemented admin surface is request-time authenticated and
	// capability checked. Mutations also require the current CSRF token and a
	// recent MFA proof, including v2 payloads mounted above.
	r.Group(func(r chi.Router) {
		r.Use(v3FeatureFlag(cfg.WebAdminAPI))
		r.Use(middleware.CaptureAdminRequest)
		r.Use(middleware.AdminCORS(cfg.AdminOrigin))
		r.Use(middleware.AdminSessionGuard(adminAuth))
		r.Use(middleware.AdminOriginGuard(cfg.AdminOrigin))
		r.Use(middleware.AdminCSRFGuard)
		r.Use(middleware.AdminRecentMFAGuard(adminRecentMFATTL(adminAuth)))
		r.Use(middleware.AdminCapabilityGuard)
		registerRoutes(r.With(handler.CaptureAdminUsersQuery), adminUsersCtrl, alwaysTrue)
		registerRoutes(r, adminCampaignsCtrl, alwaysTrue)
		registerRoutes(r, adminAudiencesCtrl, alwaysTrue)
		registerRoutes(r, adminJobsCtrl, alwaysTrue)
		registerRoutes(r, adminMessagesCtrl, alwaysTrue)
		registerRoutes(r, adminReportsCtrl, alwaysTrue)
		registerRoutes(r, adminAuditCtrl, alwaysTrue)
	})
}

func v3FeatureFlag(enabled bool) func(http.Handler) http.Handler {
	if enabled {
		return func(next http.Handler) http.Handler { return next }
	}
	return handler.UnavailableV3Middleware
}

const adminSessionCookieName = "admin_session"

func requireAdminBrowserSession(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		cookie, err := r.Cookie(adminSessionCookieName)
		if err != nil || strings.TrimSpace(cookie.Value) == "" {
			if strings.TrimSpace(r.Header.Get("Authorization")) != "" {
				handler.WriteV3Error(w, http.StatusForbidden, "forbidden", "admin browser session required")
				return
			}
			handler.WriteV3Error(w, http.StatusUnauthorized, "unauthorized", "admin browser session required")
			return
		}
		next.ServeHTTP(w, r)
	})
}

func isAdminBootstrapRoute(pattern string) bool {
	return pattern == "/api/v3/admin/session/bootstrap"
}

func isNonBootstrapAdminRoute(pattern string) bool {
	return !isAdminBootstrapRoute(pattern)
}

func isAdminPreAuthSessionRoute(pattern string) bool {
	switch pattern {
	case "/api/v3/admin/session/login", "/api/v3/admin/session/mfa":
		return true
	default:
		return false
	}
}

func isAdminAuthenticatedSessionRoute(pattern string) bool {
	switch pattern {
	case "/api/v3/admin/session/reauthenticate", "/api/v3/admin/session/logout", "/api/v3/admin/session":
		return true
	default:
		return false
	}
}

func isPublicRoute(pattern string) bool {
	switch pattern {
	case "/api/v2/public/login",
		"/api/v2/public/signup",
		"/api/v2/public/refresh",
		"/api/v2/public/recover":
		return true
	}
	return false
}

func isStatusRoute(pattern string) bool {
	return pattern == "/api/v2/status"
}

func registerProtectedStatusRoutes(r chi.Router, ctrl genserver.Router, tok *token.Helper, auth *service.Auth, adminUsername string) {
	r.Group(func(r chi.Router) {
		r.Use(middleware.JWT(tok, auth, adminUsername))
		r.Use(middleware.RequireRole(middleware.RoleUser))
		registerRoutes(r, ctrl, isStatusRoute)
	})
}

func isDeleteCodeRoute(pattern string) bool {
	return strings.HasPrefix(pattern, "/api/v2/public/delete-code/")
}

func alwaysTrue(_ string) bool { return true }

func validateBatchReadJSON(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost || r.URL.Path != "/api/v3/batch" {
			next.ServeHTTP(w, r)
			return
		}
		body, err := io.ReadAll(http.MaxBytesReader(w, r.Body, 1<<20))
		if err != nil || !json.Valid(body) {
			http.Error(w, http.StatusText(http.StatusBadRequest), http.StatusBadRequest)
			return
		}
		r.Body = io.NopCloser(bytes.NewReader(body))
		next.ServeHTTP(w, r)
	})
}

// redirectImageResponses translates the generated controllers' URL response
// into the 301 response documented by the image endpoints.
func redirectImageResponses(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		redirect, err := strconv.ParseBool(r.URL.Query().Get("redirect"))
		if err != nil || !redirect || !isImageRoute(r.URL.Path) {
			next.ServeHTTP(w, r)
			return
		}

		buffered := newBufferedResponse()
		next.ServeHTTP(buffered, r)
		if buffered.status != http.StatusOK {
			buffered.writeTo(w)
			return
		}
		var target string
		if err := json.Unmarshal(buffered.body.Bytes(), &target); err != nil || target == "" {
			buffered.writeTo(w)
			return
		}
		w.Header().Set("Location", target)
		w.WriteHeader(http.StatusMovedPermanently)
	})
}

func isImageRoute(path string) bool {
	parts := strings.Split(strings.Trim(path, "/"), "/")
	if len(parts) != 5 || parts[0] != "api" || parts[1] != "v2" {
		return false
	}
	switch parts[2] {
	case "groups":
		return parts[4] == "profile_image" || parts[4] == "profile_image_small" || parts[4] == "pin_image"
	case "pins":
		return parts[4] == "image"
	case "users":
		return parts[4] == "profile_picture" || parts[4] == "profile_picture_small"
	default:
		return false
	}
}

type bufferedResponse struct {
	header http.Header
	body   bytes.Buffer
	status int
}

func newBufferedResponse() *bufferedResponse {
	return &bufferedResponse{header: make(http.Header), status: http.StatusOK}
}

func (w *bufferedResponse) Header() http.Header { return w.header }

func (w *bufferedResponse) WriteHeader(status int) { w.status = status }

func (w *bufferedResponse) Write(p []byte) (int, error) { return w.body.Write(p) }

func (w *bufferedResponse) writeTo(target http.ResponseWriter) {
	for key, values := range w.header {
		for _, value := range values {
			target.Header().Add(key, value)
		}
	}
	target.WriteHeader(w.status)
	_, _ = target.Write(w.body.Bytes())
}

func unpagedWhenPageMissing(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		query := r.URL.Query()
		if !query.Has("page") {
			query.Set("size", "0")
			r.URL.RawQuery = query.Encode()
		}
		next.ServeHTTP(w, r)
	})
}

func validateCoupledQueryParameters(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		query := r.URL.Query()
		invalidGroupFilter := r.URL.Path == "/api/v2/groups" && query.Has("withUser") != query.Has("userId")
		invalidMapPoint := r.URL.Path == "/api/v2/map" && query.Has("latitude") != query.Has("longitude")
		invalidPinCursor := r.URL.Path == "/api/v2/pins" &&
			query.Has("beforeCreationDate") != query.Has("beforeId")
		if invalidGroupFilter || invalidMapPoint || invalidPinCursor {
			http.Error(w, "coupled query parameters must be provided together", http.StatusBadRequest)
			return
		}
		next.ServeHTTP(w, r)
	})
}

func requireCompatibilityJSONFields(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var required []string
		if r.Method == http.MethodPost {
			switch r.URL.Path {
			case "/api/v2/groups":
				required = []string{"description", "name", "groupAdmin", "profileImage", "visibility"}
			case "/api/v2/pins":
				required = []string{"image", "latitude", "longitude", "userId", "groupId"}
			}
		}
		if len(required) == 0 {
			next.ServeHTTP(w, r)
			return
		}
		body, err := io.ReadAll(r.Body)
		if err != nil {
			http.Error(w, "invalid request body", http.StatusBadRequest)
			return
		}
		r.Body = io.NopCloser(bytes.NewReader(body))
		var fields map[string]json.RawMessage
		if err := json.Unmarshal(body, &fields); err != nil {
			next.ServeHTTP(w, r)
			return
		}
		for _, field := range required {
			if _, ok := fields[field]; !ok {
				http.Error(w, "required field is missing: "+field, http.StatusBadRequest)
				return
			}
		}
		next.ServeHTTP(w, r)
	})
}

type notificationSender interface {
	SendToToken(context.Context, string, string, string) error
}

type firebaseTokenClearer interface {
	UpdateUserFirebaseToken(context.Context, uuid.UUID, *string) error
}

func sendWeeklyNotification(ctx context.Context, sender notificationSender, clearer firebaseTokenClearer, target db.NotificationTarget) error {
	body := fmt.Sprintf("You are missing out on %d new post(s) since you were gone!", target.PinCount)
	if err := sender.SendToToken(ctx, target.FirebaseToken, "See what you have missed", body); err != nil {
		return errors.Join(err, clearer.UpdateUserFirebaseToken(ctx, target.UserID, nil))
	}
	return nil
}

func serveOpenAPISpec(w http.ResponseWriter, _ *http.Request) {
	spec, err := genapi.GetSwagger()
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	buf, err := spec.MarshalJSON()
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	_, _ = w.Write(buf)
}

func serveSwaggerUI(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	_, _ = w.Write([]byte(`<!DOCTYPE html>
<html><head><title>Stick-It API</title>
<link rel="stylesheet" href="https://unpkg.com/swagger-ui-dist@5/swagger-ui.css">
</head><body>
<div id="swagger-ui"></div>
<script src="https://unpkg.com/swagger-ui-dist@5/swagger-ui-bundle.js"></script>
<script>
  window.ui = SwaggerUIBundle({ url: "/public/api-docs", dom_id: "#swagger-ui" });
</script>
</body></html>`))
}

func daysInMonth(t time.Time) int {
	return time.Date(t.Year(), t.Month()+1, 0, 0, 0, 0, 0, t.Location()).Day()
}

func must(err error, context string) {
	if err != nil {
		slog.Error(context, "err", err)
		os.Exit(1)
	}
}

// requestLogger logs method, path, status code, and duration for every request.
// Legacy action links carry their bearer-equivalent secret in the path. Keep
// the public route shape while replacing that segment before structured logs
// are emitted. Reverse proxies should apply the same rules to
// /public/recover/*, /public/delete-account/* (except /code), and
// /public/email-confirmation/* before forwarding access logs.
func requestLogger(log *slog.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			start := time.Now()
			ww := &statusWriter{ResponseWriter: w, status: http.StatusOK}
			next.ServeHTTP(ww, r)
			log.Info("request",
				"method", r.Method,
				"path", redactLegacyActionPath(r.URL.Path),
				"status", ww.status,
				"duration_ms", time.Since(start).Milliseconds(),
				"request_id", chimw.GetReqID(r.Context()),
			)
		})
	}
}

func redactLegacyActionPath(path string) string {
	switch {
	case strings.HasPrefix(path, "/public/recover/"):
		return "/public/recover/[redacted]"
	case strings.HasPrefix(path, "/public/delete-account/") && path != "/public/delete-account/code":
		return "/public/delete-account/[redacted]"
	case strings.HasPrefix(path, "/public/email-confirmation/"):
		return "/public/email-confirmation/[redacted]"
	default:
		return path
	}
}

type statusWriter struct {
	http.ResponseWriter
	status int
}

func (sw *statusWriter) WriteHeader(code int) {
	sw.status = code
	sw.ResponseWriter.WriteHeader(code)
}
