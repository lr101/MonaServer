package main

import (
	"context"
	"log/slog"
	"net/http"
	"os"
	"time"

	"github.com/go-chi/chi/v5"
	chimw "github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"

	"github.com/lrprojects/monaserver/internal/config"
	"github.com/lrprojects/monaserver/internal/db"
	genapi "github.com/lrprojects/monaserver/internal/gen/api"
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

	authH := handler.NewAuth(authSvc)

	// Optional integrations — initialize only if configured.
	var objSvc *service.Object
	if cfg.MinioEndpoint != "" {
		o, err := service.NewObject(cfg.MinioEndpoint, cfg.MinioAccessKey, cfg.MinioSecretKey,
			cfg.MinioBucket, cfg.MinioUseSSL, cfg.MinioURLExpiry)
		if err != nil {
			log.Error("minio init", "err", err)
		} else if err := o.EnsureBucket(ctx); err != nil {
			log.Warn("minio ensure bucket", "err", err)
		} else {
			log.Info("minio ready", "bucket", cfg.MinioBucket)
			objSvc = o
		}
	}
	notifSvc := service.NewNotification(ctx, cfg.FirebaseConfigPath)
	_ = notifSvc

	mailSvc := service.NewEmail(cfg, nil)
	userSvc := service.NewUser(q, objSvc, tok, authSvc, mailSvc)
	usersH := handler.NewUsers(userSvc)
	groupSvc := service.NewGroup(q, objSvc, userSvc)
	groupsH := handler.NewGroups(groupSvc)

	sched := scheduler.New()
	_ = sched.AddWeeklyNotification(func(c context.Context) { log.Info("weekly notification tick") })
	_ = sched.AddMonthlySeason(func(c context.Context) { log.Info("season tick") })
	sched.Start()
	defer sched.Stop()

	r := chi.NewRouter()
	r.Use(chimw.RequestID)
	r.Use(chimw.RealIP)
	r.Use(chimw.Recoverer)
	r.Use(chimw.Timeout(30 * time.Second))
	r.Use(cors.Handler(cors.Options{
		AllowedOrigins:   []string{"*"},
		AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"*"},
		AllowCredentials: false,
	}))

	// OpenAPI spec — served at the same path as SpringDoc exposes it in the
	// Kotlin build, plus a Swagger-UI CDN page so it's browsable.
	r.Get("/public/api-docs", serveOpenAPISpec)
	r.Get("/public/api-docs/", serveOpenAPISpec)
	r.Get("/swagger-ui", serveSwaggerUI)

	// Public routes (no auth).
	r.Route("/api/v2/public", func(r chi.Router) {
		r.Post("/signup", authH.Signup)
		r.Post("/login", authH.Login)
		r.Post("/refresh", authH.Refresh)
		r.Get("/recover", handler.NotImplemented)
		r.Get("/infos", handler.NotImplemented)
	})

	// Authenticated routes: require JWT + USER role.
	r.Group(func(r chi.Router) {
		r.Use(middleware.JWT(tok, authSvc, cfg.AdminUsername))
		r.Use(middleware.RequireRole(middleware.RoleUser))

		r.Route("/api/v2", func(r chi.Router) {
			// Users
			r.Route("/users/{userId}", func(r chi.Router) {
				r.Get("/", usersH.Get)
				r.With(middleware.RequireSameUser("userId")).Put("/", usersH.Update)
				r.With(middleware.RequireSameUser("userId")).Delete("/", usersH.Delete)
				r.Get("/profile_picture", usersH.ProfileImage(false))
				r.Get("/profile_picture_small", usersH.ProfileImage(true))
				r.With(middleware.RequireSameUser("userId")).Get("/xp", usersH.Xp)
				r.With(middleware.RequireSameUser("userId")).Get("/achievements", usersH.Achievements)
				r.With(middleware.RequireSameUser("userId")).Post("/achievements/{achievementId}", usersH.ClaimAchievement)
				r.Get("/likes", usersH.Likes)
			})

			// Groups
			r.Route("/groups", func(r chi.Router) {
				r.Get("/", groupsH.Search)
				r.Post("/", groupsH.Create)
				r.Route("/{groupId}", func(r chi.Router) {
					r.Get("/", groupsH.Get)
					r.With(middleware.RequireGroupAdmin(guardSvc, "groupId")).Put("/", groupsH.Update)
					r.With(middleware.RequireGroupAdmin(guardSvc, "groupId")).Delete("/", groupsH.Delete)
					r.With(middleware.RequireGroupVisible(guardSvc, "groupId")).Get("/admin", groupsH.Admin)
					r.With(middleware.RequireGroupVisible(guardSvc, "groupId")).Get("/description", groupsH.Description)
					r.With(middleware.RequireGroupVisible(guardSvc, "groupId")).Get("/link", groupsH.Link)
					r.With(middleware.RequireGroupVisible(guardSvc, "groupId")).Get("/invite_url", groupsH.InviteUrl)
					r.Get("/profile_image", groupsH.ProfileImage(false))
					r.Get("/profile_image_small", groupsH.ProfileImage(true))
					r.Get("/pin_image", groupsH.PinImage)
					r.With(middleware.RequireGroupVisible(guardSvc, "groupId")).Get("/members", handler.NotImplemented)
					r.Post("/members", handler.NotImplemented)
					r.Delete("/members", handler.NotImplemented) // internally RequireSameUser OR RequireGroupAdmin
				})
			})

			// Pins
			r.Route("/pins", func(r chi.Router) {
				r.Get("/", handler.NotImplemented)
				r.Post("/", handler.NotImplemented)
				r.Route("/{pinId}", func(r chi.Router) {
					r.With(middleware.RequirePinPublicOrMember(guardSvc, "pinId")).Get("/", handler.NotImplemented)
					r.With(middleware.RequireAny(
						middleware.RequirePinCreator(guardSvc, "pinId"),
						middleware.RequirePinGroupAdmin(guardSvc, "pinId"),
					)).Delete("/", handler.NotImplemented)
					r.With(middleware.RequirePinPublicOrMember(guardSvc, "pinId")).Get("/image", handler.NotImplemented)
					r.With(middleware.RequirePinPublicOrMember(guardSvc, "pinId")).Get("/likes", handler.NotImplemented)
					r.With(middleware.RequirePinPublicOrMember(guardSvc, "pinId")).Post("/likes", handler.NotImplemented)
				})
			})

			// Ranking + map
			r.Get("/ranking/group", handler.NotImplemented)
			r.Get("/ranking/user", handler.NotImplemented)
			r.Get("/ranking/search", handler.NotImplemented)
			r.Get("/map", handler.NotImplemented)
			r.Get("/map/geojson", handler.NotImplemented)

			r.Post("/report", handler.NotImplemented)
		})

		// v3 sync
		r.Get("/api/v3/sync", handler.NotImplemented)
	})

	// Admin-only routes.
	r.Group(func(r chi.Router) {
		r.Use(middleware.JWT(tok, authSvc, cfg.AdminUsername))
		r.Use(middleware.RequireRole(middleware.RoleAdmin))
		r.Post("/api/v2/admin/mail", handler.NotImplemented)
		r.Post("/api/v2/admin/notification", handler.NotImplemented)
	})

	addr := ":" + cfg.Port
	log.Info("server listening", "addr", addr)
	srv := &http.Server{Addr: addr, Handler: r, ReadHeaderTimeout: 10 * time.Second}
	if err := srv.ListenAndServe(); err != nil {
		log.Error("server", "err", err)
		os.Exit(1)
	}
}

// serveOpenAPISpec writes the embedded OpenAPI 3.0.3 spec as JSON. The spec is
// compiled into the binary by oapi-codegen's embedded-spec generator.
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

// serveSwaggerUI returns a minimal Swagger-UI HTML page pointing at /public/api-docs.
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

func must(err error, context string) {
	if err != nil {
		slog.Error(context, "err", err)
		os.Exit(1)
	}
}
