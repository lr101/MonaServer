package main

import (
	"context"
	"fmt"
	"log/slog"
	"net/http"
	"os"
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
	authSvc := service.NewAuth(q, tok, cfg)
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
	mailSvc := service.NewEmail(cfg, nil)

	achMonaGroupID, _ := uuid.Parse(cfg.AchievementMonaGroupID)
	achCreatedBefore, _ := time.Parse(time.RFC3339, cfg.AchievementCreatedBefore)
	achCfg := db.AchievementConfig{MonaGroupID: achMonaGroupID, CreatedBefore: achCreatedBefore}

	userSvc := service.NewUser(q, objSvc, tok, authSvc, mailSvc)
	groupSvc := service.NewGroup(q, objSvc, userSvc)
	pinSvc := service.NewPin(q, objSvc)
	memberSvc := service.NewMember(q, objSvc, groupSvc)
	likeSvc := service.NewLike(q)
	rankSvc := service.NewRanking(q)

	// Servicers wrapping business logic and implementing genserver interfaces.
	authServicer := handler.NewAuthServicer(authSvc, q, mailSvc, cfg.RustfsExternalEndpoint, cfg.RedirectURL)
	groupsServicer := handler.NewGroupsServicer(groupSvc, guardSvc)
	pinsServicer := handler.NewPinsServicer(pinSvc, groupSvc, guardSvc, q)
	membersServicer := handler.NewMembersServicer(memberSvc, guardSvc)
	likesServicer := handler.NewLikesServicer(likeSvc, guardSvc)
	rankingServicer := handler.NewRankingServicer(rankSvc)
	adminServicer := handler.NewAdminServicer(q, mailSvc, notifSvc)
	reportServicer := handler.NewReportServicer(mailSvc)
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
			body := fmt.Sprintf("You are missing out on %d new post(s) since you were gone!", t.PinCount)
			_ = notifSvc.SendToToken(c, t.FirebaseToken, "See what you have missed", body)
		}
		log.Info("weekly notifications sent", "count", len(targets))
	})
	_ = sched.AddMonthlySeason(func(c context.Context) {
		now := time.Now()
		if now.Day() != daysInMonth(now) {
			return
		}
		maxNum, err := q.GetMaxSeasonNumber(c)
		if err != nil {
			log.Error("season: get max number", "err", err)
			return
		}
		seasonID, err := q.CreateSeason(c, maxNum+1, now.Year(), int(now.Month()))
		if err != nil {
			log.Error("season: create", "err", err)
			return
		}
		since := time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, time.UTC)
		userRanks, err := q.GetUserRanking(c, db.RankingFilter{Since: &since, Limit: 10000})
		if err != nil {
			log.Error("season: user ranking", "err", err)
		}
		for i, r := range userRanks {
			_ = q.CreateUserSeason(c, r.UserID, seasonID, int32(i+1), r.Points)
		}
		groupRanks, err := q.GetGlobalGroupRanking(c, db.RankingFilter{Since: &since, Limit: 10000})
		if err != nil {
			log.Error("season: group ranking", "err", err)
		}
		for i, r := range groupRanks {
			_ = q.CreateGroupSeason(c, r.GroupID, seasonID, int32(i+1), r.Points)
		}
		log.Info("monthly season created", "season", maxNum+1, "users", len(userRanks), "groups", len(groupRanks))
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
	// The original Spring security config makes all of /api/v2/public/** permitAll
	// (matched before the /api/v2/** USER_ROLE rule), so delete-code is public too —
	// despite its OpenAPI `security: token` annotation, which Spring does not enforce.
	r.Group(func(r chi.Router) {
		registerRoutes(r, authCtrl, isPublicRoute)
		registerRoutes(r, authCtrl, isDeleteCodeRoute)
		registerRoutes(r, publicCtrl, alwaysTrue)
	})

	// Status endpoint — requires valid JWT to confirm token validity.
	r.Group(func(r chi.Router) {
		registerRoutes(r, authCtrl, isStatusRoute)
	})

	// Authenticated routes: require JWT + USER role.
	r.Group(func(r chi.Router) {
		r.Use(middleware.JWT(tok, authSvc, cfg.AdminUsername))
		r.Use(middleware.RequireRole(middleware.RoleUser))

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

func isDeleteCodeRoute(pattern string) bool {
	return strings.HasPrefix(pattern, "/api/v2/public/delete-code/")
}

func alwaysTrue(_ string) bool { return true }

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
