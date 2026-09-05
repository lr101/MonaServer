package main

import (
	"bytes"
	"context"
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
	log := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	slog.SetDefault(log)

	cfg, err := config.Load()
	must(err, "load config")

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
	authServicer := handler.NewAuthServicer(authSvc, q, mailSvc, cfg.RustfsExternalEndpoint)
	groupsServicer := handler.NewGroupsServicer(groupSvc, guardSvc)
	pinsServicer := handler.NewPinsServicer(pinSvc, groupSvc, guardSvc, q)
	membersServicer := handler.NewMembersServicer(memberSvc, guardSvc)
	likesServicer := handler.NewLikesServicer(likeSvc, guardSvc)
	rankingServicer := handler.NewRankingServicer(rankSvc)
	adminServicer := handler.NewAdminServicer(q, mailSvc, notifSvc)
	reportServicer := handler.NewReportServicer(mailSvc, q)
	publicServicer := handler.NewPublicServicer()
	usersServicer := handler.NewUsersServicer(userSvc, guardSvc, q, achCfg)

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
	r.Use(chimw.RealIP)
	r.Use(chimw.Recoverer)
	r.Use(chimw.Timeout(30 * time.Second))
	r.Use(requestLogger(log))
	r.Use(cors.Handler(cors.Options{
		AllowedOrigins:   []string{"*"},
		AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"*"},
		AllowCredentials: false,
	}))

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

		registerRoutes(r, groupsCtrl, alwaysTrue)
		registerRoutes(r, pinsCtrl, alwaysTrue)
		registerRoutes(r, membersCtrl, alwaysTrue)
		registerRoutes(r, likesCtrl, alwaysTrue)
		registerRoutes(r, rankingCtrl, alwaysTrue)
		registerRoutes(r, reportCtrl, alwaysTrue)
		registerRoutes(r, usersCtrl, alwaysTrue)
	})

	// Admin-only routes.
	r.Group(func(r chi.Router) {
		r.Use(middleware.JWT(tok, authSvc, cfg.AdminUsername))
		r.Use(middleware.RequireRole(middleware.RoleAdmin))
		registerRoutes(r, adminCtrl, alwaysTrue)
	})

	addr := ":" + cfg.Port
	log.Info("server listening", "addr", addr)
	srv := &http.Server{Addr: addr, Handler: r, ReadHeaderTimeout: 10 * time.Second}
	if err := srv.ListenAndServe(); err != nil {
		log.Error("server", "err", err)
		os.Exit(1)
	}
}

func newMailService(cfg *config.Config) *service.Email {
	if cfg.MailHost == "" {
		return nil
	}
	return service.NewEmail(cfg, nil)
}

// registerRoutes registers controller routes into r, filtered by predicate on the pattern.
func registerRoutes(r chi.Router, ctrl genserver.Router, pred func(string) bool) {
	for _, route := range ctrl.OrderedRoutes() {
		if pred(route.Pattern) {
			r.Method(route.Method, route.Pattern, route.HandlerFunc)
		}
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
		if invalidGroupFilter || invalidMapPoint {
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
func requestLogger(log *slog.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			start := time.Now()
			ww := &statusWriter{ResponseWriter: w, status: http.StatusOK}
			next.ServeHTTP(ww, r)
			log.Info("request",
				"method", r.Method,
				"path", r.URL.Path,
				"status", ww.status,
				"duration_ms", time.Since(start).Milliseconds(),
				"request_id", chimw.GetReqID(r.Context()),
			)
		})
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
