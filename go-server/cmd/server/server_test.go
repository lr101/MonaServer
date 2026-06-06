package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"
	chimw "github.com/go-chi/chi/v5/middleware"
	"github.com/google/uuid"

	"github.com/lrprojects/monaserver/internal/config"
	"github.com/lrprojects/monaserver/internal/db"
	genserver "github.com/lrprojects/monaserver/internal/gen/server"
	"github.com/lrprojects/monaserver/internal/handler"
	"github.com/lrprojects/monaserver/internal/middleware"
	"github.com/lrprojects/monaserver/internal/service"
	"github.com/lrprojects/monaserver/internal/token"
)

func testDSN(t *testing.T) string {
	t.Helper()
	dsn := os.Getenv("TEST_DATABASE_URL")
	if dsn == "" {
		t.Skip("TEST_DATABASE_URL not set; skipping integration test")
	}
	return dsn
}

func buildTestServer(t *testing.T) *httptest.Server {
	t.Helper()
	dsn := testDSN(t)

	if err := db.RunMigrations(dsn); err != nil {
		t.Fatalf("migrations: %v", err)
	}
	pool, err := db.NewPool(context.Background(), dsn)
	if err != nil {
		t.Fatalf("db pool: %v", err)
	}
	t.Cleanup(pool.Close)

	if _, err := pool.Exec(context.Background(),
		`TRUNCATE TABLE refresh_token, users, groups, pins, likes, members CASCADE`); err != nil {
		t.Fatalf("truncate: %v", err)
	}

	q := db.New(pool)
	cfg := &config.Config{
		JWTSecret:          "test-secret",
		AccessTokenExpiry:  time.Minute,
		RefreshTokenExpiry: time.Hour,
		MaxLoginAttempts:   10,
		AdminUsername:      "admin",
	}
	tok := token.NewHelper(cfg.JWTSecret, cfg.AccessTokenExpiry)
	authSvc := service.NewAuth(q, tok, cfg)
	guardSvc := service.NewGuard(q)
	userSvc := service.NewUser(q, nil, tok, authSvc, nil)
	groupSvc := service.NewGroup(q, nil, userSvc)
	pinSvc := service.NewPin(q, nil)
	memberSvc := service.NewMember(q, nil, groupSvc)
	likeSvc := service.NewLike(q)
	rankSvc := service.NewRanking(q)
	mailSvc := service.NewEmail(cfg, nil)
	notifSvc := service.NewNotification(context.Background(), "")
	achCfg := db.AchievementConfig{}

	authServicer := handler.NewAuthServicer(authSvc, q, mailSvc, "", "http://localhost")
	groupsServicer := handler.NewGroupsServicer(groupSvc, guardSvc)
	pinsServicer := handler.NewPinsServicer(pinSvc, groupSvc, guardSvc, q)
	membersServicer := handler.NewMembersServicer(memberSvc, guardSvc)
	likesServicer := handler.NewLikesServicer(likeSvc, guardSvc)
	rankingServicer := handler.NewRankingServicer(rankSvc)
	adminServicer := handler.NewAdminServicer(q, mailSvc, notifSvc)
	reportServicer := handler.NewReportServicer(mailSvc)
	publicServicer := handler.NewPublicServicer()
	usersServicer := handler.NewUsersServicer(userSvc, guardSvc, q, achCfg)

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

	r := chi.NewRouter()
	r.Use(chimw.Recoverer)

	// Mirror the route wiring in main.go.
	r.Group(func(r chi.Router) {
		registerRoutes(r, authCtrl, isPublicRoute)
		registerRoutes(r, authCtrl, isDeleteCodeRoute)
		registerRoutes(r, publicCtrl, alwaysTrue)
	})
	r.Group(func(r chi.Router) {
		registerRoutes(r, authCtrl, isStatusRoute)
	})
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
	r.Group(func(r chi.Router) {
		r.Use(middleware.JWT(tok, authSvc, cfg.AdminUsername))
		r.Use(middleware.RequireRole(middleware.RoleAdmin))
		registerRoutes(r, adminCtrl, alwaysTrue)
	})

	return httptest.NewServer(r)
}

// --- helper types ---

type authResp struct {
	AccessToken  string `json:"accessToken"`
	RefreshToken string `json:"refreshToken"`
	UserID       string `json:"userId"`
}

type apiClient struct {
	base   string
	bearer string
}

func (c *apiClient) do(t *testing.T, method, path string, body any) *http.Response {
	t.Helper()
	var r io.Reader
	if body != nil {
		b, _ := json.Marshal(body)
		r = bytes.NewReader(b)
	}
	req, _ := http.NewRequest(method, c.base+path, r)
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	if c.bearer != "" {
		req.Header.Set("Authorization", "Bearer "+c.bearer)
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("%s %s: %v", method, path, err)
	}
	return resp
}

func (c *apiClient) signup(t *testing.T, username, password string) authResp {
	t.Helper()
	// UserRequestDto uses "name" for username; email is a required non-empty field.
	resp := c.do(t, "POST", "/api/v2/public/signup", map[string]string{
		"name":     username,
		"email":    username + "@test.example",
		"password": password,
	})
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusCreated {
		t.Fatalf("signup: expected 201, got %d", resp.StatusCode)
	}
	var ar authResp
	_ = json.NewDecoder(resp.Body).Decode(&ar)
	return ar
}

func (c *apiClient) login(t *testing.T, username, password string) authResp {
	t.Helper()
	resp := c.do(t, "POST", "/api/v2/public/login", map[string]string{
		"username": username, "password": password,
	})
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("login: expected 200, got %d", resp.StatusCode)
	}
	var ar authResp
	_ = json.NewDecoder(resp.Body).Decode(&ar)
	return ar
}

// createGroup creates a group administered by the client's own user and returns its id.
func (c *apiClient) createGroup(t *testing.T, adminID, name string, visibility int) string {
	t.Helper()
	resp := c.do(t, "POST", "/api/v2/groups", map[string]any{
		"name":       name,
		"visibility": visibility,
		"groupAdmin": adminID,
	})
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusCreated {
		t.Fatalf("create group %q: expected 201, got %d", name, resp.StatusCode)
	}
	var g map[string]any
	_ = json.NewDecoder(resp.Body).Decode(&g)
	return fmt.Sprintf("%v", g["id"])
}

func decode(t *testing.T, resp *http.Response, v any) {
	t.Helper()
	defer resp.Body.Close()
	if err := json.NewDecoder(resp.Body).Decode(v); err != nil {
		t.Fatalf("decode response: %v", err)
	}
}

// --- tests ---

func TestEndpointAuth(t *testing.T) {
	srv := buildTestServer(t)
	defer srv.Close()
	c := &apiClient{base: srv.URL}

	t.Run("signup", func(t *testing.T) {
		ar := c.signup(t, "alice", "password123")
		if ar.AccessToken == "" {
			t.Fatal("empty access token")
		}
		if ar.UserID == "" {
			t.Fatal("empty user id")
		}
	})

	t.Run("duplicate signup rejected", func(t *testing.T) {
		c.signup(t, "dupuser", "pw123")
		resp := c.do(t, "POST", "/api/v2/public/signup", map[string]string{
			"name": "dupuser", "email": "dupuser@test.example", "password": "pw123",
		})
		resp.Body.Close()
		if resp.StatusCode == http.StatusCreated {
			t.Fatal("expected conflict on duplicate signup")
		}
	})

	t.Run("login", func(t *testing.T) {
		c.signup(t, "bob", "pw123")
		ar := c.login(t, "bob", "pw123")
		if ar.AccessToken == "" {
			t.Fatal("empty access token on login")
		}
	})

	t.Run("wrong password rejected", func(t *testing.T) {
		c.signup(t, "charlie", "correct")
		resp := c.do(t, "POST", "/api/v2/public/login", map[string]string{
			"username": "charlie", "password": "wrong",
		})
		resp.Body.Close()
		if resp.StatusCode == http.StatusOK {
			t.Fatal("expected error on wrong password")
		}
	})

	t.Run("refresh", func(t *testing.T) {
		ar := c.signup(t, "dave", "pw123")
		resp := c.do(t, "POST", "/api/v2/public/refresh", map[string]string{
			"refreshToken": ar.RefreshToken,
		})
		defer resp.Body.Close()
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("refresh: expected 200, got %d", resp.StatusCode)
		}
	})

	t.Run("status returns 200", func(t *testing.T) {
		resp := c.do(t, "GET", "/api/v2/status", nil)
		resp.Body.Close()
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("status: expected 200, got %d", resp.StatusCode)
		}
	})

	t.Run("delete-code is public (no bearer token required)", func(t *testing.T) {
		// Mirrors Spring's /api/v2/public/** permitAll: requesting a delete code
		// must not require authentication.
		c.signup(t, "delcode_user", "pw123")
		resp := c.do(t, "GET", "/api/v2/public/delete-code/delcode_user", nil)
		resp.Body.Close()
		if resp.StatusCode == http.StatusUnauthorized {
			t.Fatalf("delete-code should be public, got 401")
		}
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("delete-code: expected 200, got %d", resp.StatusCode)
		}
	})
}

func TestEndpointPublic(t *testing.T) {
	srv := buildTestServer(t)
	defer srv.Close()
	c := &apiClient{base: srv.URL}

	t.Run("GET /api/v2/public/infos", func(t *testing.T) {
		resp := c.do(t, "GET", "/api/v2/public/infos", nil)
		resp.Body.Close()
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("expected 200, got %d", resp.StatusCode)
		}
	})
}

func TestEndpointUsers(t *testing.T) {
	srv := buildTestServer(t)
	defer srv.Close()

	anon := &apiClient{base: srv.URL}
	ar := anon.signup(t, "usertest", "pw123")
	c := &apiClient{base: srv.URL, bearer: ar.AccessToken}
	uid := ar.UserID

	t.Run("GET /api/v2/users/{id}", func(t *testing.T) {
		resp := c.do(t, "GET", "/api/v2/users/"+uid, nil)
		defer resp.Body.Close()
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("expected 200, got %d", resp.StatusCode)
		}
		var u map[string]any
		decode(t, resp, &u)
		if u["username"] != "usertest" {
			t.Fatalf("username mismatch: %v", u["username"])
		}
	})

	t.Run("PUT /api/v2/users/{id} — update description", func(t *testing.T) {
		resp := c.do(t, "PUT", "/api/v2/users/"+uid, map[string]string{
			"description": "test bio",
		})
		defer resp.Body.Close()
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("expected 200, got %d", resp.StatusCode)
		}
	})

	t.Run("PUT /api/v2/users/{id} — forbidden for other user", func(t *testing.T) {
		other := anon.signup(t, "other_user_x", "pw123")
		oc := &apiClient{base: srv.URL, bearer: other.AccessToken}
		resp := oc.do(t, "PUT", "/api/v2/users/"+uid, map[string]string{"description": "hack"})
		resp.Body.Close()
		if resp.StatusCode != http.StatusForbidden {
			t.Fatalf("expected 403, got %d", resp.StatusCode)
		}
	})

	t.Run("GET /api/v2/users/{id}/xp", func(t *testing.T) {
		resp := c.do(t, "GET", "/api/v2/users/"+uid+"/xp", nil)
		defer resp.Body.Close()
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("expected 200, got %d", resp.StatusCode)
		}
		var xp map[string]any
		decode(t, resp, &xp)
		if _, ok := xp["totalXp"]; !ok {
			t.Fatal("missing totalXp field")
		}
	})

	t.Run("GET /api/v2/users/{id}/achievements", func(t *testing.T) {
		resp := c.do(t, "GET", "/api/v2/users/"+uid+"/achievements", nil)
		defer resp.Body.Close()
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("expected 200, got %d", resp.StatusCode)
		}
	})

	t.Run("GET /api/v2/users/{id}/profile_picture — returns 200", func(t *testing.T) {
		resp := c.do(t, "GET", "/api/v2/users/"+uid+"/profile_picture", nil)
		resp.Body.Close()
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("expected 200, got %d", resp.StatusCode)
		}
	})
}

func TestEndpointGroups(t *testing.T) {
	srv := buildTestServer(t)
	defer srv.Close()

	anon := &apiClient{base: srv.URL}
	ar := anon.signup(t, "grouper", "pw123")
	c := &apiClient{base: srv.URL, bearer: ar.AccessToken}

	gid := c.createGroup(t, ar.UserID, "testgroup", 0)

	t.Run("GET /api/v2/groups/{id}", func(t *testing.T) {
		resp := c.do(t, "GET", "/api/v2/groups/"+gid, nil)
		defer resp.Body.Close()
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("expected 200, got %d", resp.StatusCode)
		}
		var g map[string]any
		decode(t, resp, &g)
		if g["name"] != "testgroup" {
			t.Fatalf("name mismatch: %v", g["name"])
		}
	})

	t.Run("GET /api/v2/groups — search", func(t *testing.T) {
		resp := c.do(t, "GET", "/api/v2/groups?search=testgroup&page=0&size=10", nil)
		defer resp.Body.Close()
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("expected 200, got %d", resp.StatusCode)
		}
	})

	t.Run("PUT /api/v2/groups/{id}", func(t *testing.T) {
		resp := c.do(t, "PUT", "/api/v2/groups/"+gid, map[string]any{
			"name":       "testgroup_renamed",
			"visibility": 0,
		})
		defer resp.Body.Close()
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("expected 200, got %d", resp.StatusCode)
		}
	})

	t.Run("DELETE /api/v2/groups/{id}", func(t *testing.T) {
		dgid := c.createGroup(t, ar.UserID, "todelete_group", 0)
		resp := c.do(t, "DELETE", "/api/v2/groups/"+dgid, nil)
		resp.Body.Close()
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("delete group: expected 200, got %d", resp.StatusCode)
		}
	})

	t.Run("GET /api/v2/groups/{id}/profile_image — no image returns 200", func(t *testing.T) {
		resp := c.do(t, "GET", "/api/v2/groups/"+gid+"/profile_image", nil)
		resp.Body.Close()
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("expected 200, got %d", resp.StatusCode)
		}
	})

	t.Run("GET /api/v2/groups/{id}/invite_url", func(t *testing.T) {
		// Make group private first so an invite URL is generated.
		c.do(t, "PUT", "/api/v2/groups/"+gid, map[string]any{"visibility": 1}).Body.Close()
		resp := c.do(t, "GET", "/api/v2/groups/"+gid+"/invite_url", nil)
		resp.Body.Close()
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("expected 200, got %d", resp.StatusCode)
		}
	})
}

// TestGroupCreateAuthorization verifies the AddGroup authorization fix:
// a non-admin caller may only create a group whose groupAdmin is themselves.
func TestGroupCreateAuthorization(t *testing.T) {
	srv := buildTestServer(t)
	defer srv.Close()

	anon := &apiClient{base: srv.URL}
	a := anon.signup(t, "ga_owner", "pw123")
	b := anon.signup(t, "ga_other", "pw123")
	bc := &apiClient{base: srv.URL, bearer: b.AccessToken}

	t.Run("forbidden when setting another user as groupAdmin", func(t *testing.T) {
		resp := bc.do(t, "POST", "/api/v2/groups", map[string]any{
			"name":       "spoofed_group",
			"visibility": 0,
			"groupAdmin": a.UserID, // not the caller
		})
		resp.Body.Close()
		if resp.StatusCode != http.StatusForbidden {
			t.Fatalf("expected 403, got %d", resp.StatusCode)
		}
	})

	t.Run("allowed when groupAdmin is the caller", func(t *testing.T) {
		resp := bc.do(t, "POST", "/api/v2/groups", map[string]any{
			"name":       "own_group",
			"visibility": 0,
			"groupAdmin": b.UserID,
		})
		resp.Body.Close()
		if resp.StatusCode != http.StatusCreated {
			t.Fatalf("expected 201, got %d", resp.StatusCode)
		}
	})
}

func TestEndpointMembers(t *testing.T) {
	srv := buildTestServer(t)
	defer srv.Close()

	anon := &apiClient{base: srv.URL}
	adminAR := anon.signup(t, "madmin", "pw123")
	memberAR := anon.signup(t, "mmember", "pw123")
	admin := &apiClient{base: srv.URL, bearer: adminAR.AccessToken}
	member := &apiClient{base: srv.URL, bearer: memberAR.AccessToken}

	gid := admin.createGroup(t, adminAR.UserID, "membertest_group", 0)

	t.Run("GET /api/v2/groups/{id}/members — list members", func(t *testing.T) {
		resp := admin.do(t, "GET", "/api/v2/groups/"+gid+"/members", nil)
		defer resp.Body.Close()
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("expected 200, got %d", resp.StatusCode)
		}
	})

	t.Run("POST /api/v2/groups/{id}/members — join", func(t *testing.T) {
		resp := member.do(t, "POST",
			"/api/v2/groups/"+gid+"/members?userId="+memberAR.UserID, nil)
		defer resp.Body.Close()
		if resp.StatusCode != http.StatusCreated {
			t.Fatalf("join: expected 201, got %d", resp.StatusCode)
		}
	})

	t.Run("DELETE /api/v2/groups/{id}/members — leave", func(t *testing.T) {
		resp := member.do(t, "DELETE",
			"/api/v2/groups/"+gid+"/members?userId="+memberAR.UserID, nil)
		resp.Body.Close()
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("leave: expected 200, got %d", resp.StatusCode)
		}
	})
}

func TestEndpointPins(t *testing.T) {
	srv := buildTestServer(t)
	defer srv.Close()

	anon := &apiClient{base: srv.URL}
	ar := anon.signup(t, "pinner", "pw123")
	c := &apiClient{base: srv.URL, bearer: ar.AccessToken}

	gid := c.createGroup(t, ar.UserID, "pintest_group", 0)

	var pid string

	t.Run("GET /api/v2/pins — list group pins (sync)", func(t *testing.T) {
		resp := c.do(t, "GET", "/api/v2/pins?groupId="+gid+"&withImage=false", nil)
		defer resp.Body.Close()
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("pins by group: expected 200, got %d", resp.StatusCode)
		}
	})

	t.Run("GET /api/v3/sync", func(t *testing.T) {
		resp := c.do(t, "GET", "/api/v3/sync?lastSeen=2020-01-01T00:00:00Z", nil)
		resp.Body.Close()
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("sync: expected 200, got %d", resp.StatusCode)
		}
	})

	t.Run("POST /api/v2/pins — create single pin", func(t *testing.T) {
		resp := c.do(t, "POST", "/api/v2/pins", map[string]any{
			"latitude":     48.137,
			"longitude":    11.576,
			"creationDate": time.Now().UTC().Format(time.RFC3339),
			"userId":       ar.UserID,
			"groupId":      gid,
		})
		defer resp.Body.Close()
		if resp.StatusCode != http.StatusCreated {
			t.Fatalf("create pin: expected 201, got %d", resp.StatusCode)
		}
		var p map[string]any
		decode(t, resp, &p)
		pid = fmt.Sprintf("%v", p["id"])
		if pid == "" || pid == "<nil>" {
			t.Fatalf("empty pin id: %v", p)
		}
	})

	t.Run("GET /api/v2/pins/{id}", func(t *testing.T) {
		resp := c.do(t, "GET", "/api/v2/pins/"+pid, nil)
		defer resp.Body.Close()
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("expected 200, got %d", resp.StatusCode)
		}
	})

	t.Run("DELETE /api/v2/pins/{id}", func(t *testing.T) {
		resp := c.do(t, "DELETE", "/api/v2/pins/"+pid, nil)
		resp.Body.Close()
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("expected 200, got %d", resp.StatusCode)
		}
	})
}

// TestPinCreateAuthorization verifies the CreatePin authorization fix:
// a caller must be a member of the target group AND the pin's userId.
func TestPinCreateAuthorization(t *testing.T) {
	srv := buildTestServer(t)
	defer srv.Close()

	anon := &apiClient{base: srv.URL}
	owner := anon.signup(t, "pin_owner", "pw123")
	stranger := anon.signup(t, "pin_stranger", "pw123")
	oc := &apiClient{base: srv.URL, bearer: owner.AccessToken}
	sc := &apiClient{base: srv.URL, bearer: stranger.AccessToken}

	gid := oc.createGroup(t, owner.UserID, "authpin_group", 0)

	pinBody := func(userID string) map[string]any {
		return map[string]any{
			"latitude":     48.1,
			"longitude":    11.6,
			"creationDate": time.Now().UTC().Format(time.RFC3339),
			"userId":       userID,
			"groupId":      gid,
		}
	}

	t.Run("non-member forbidden", func(t *testing.T) {
		resp := sc.do(t, "POST", "/api/v2/pins", pinBody(stranger.UserID))
		resp.Body.Close()
		if resp.StatusCode != http.StatusForbidden {
			t.Fatalf("expected 403 for non-member, got %d", resp.StatusCode)
		}
	})

	t.Run("spoofing another user's id forbidden", func(t *testing.T) {
		// stranger is not a member and also tries to post as the owner.
		resp := sc.do(t, "POST", "/api/v2/pins", pinBody(owner.UserID))
		resp.Body.Close()
		if resp.StatusCode != http.StatusForbidden {
			t.Fatalf("expected 403 for user spoofing, got %d", resp.StatusCode)
		}
	})

	t.Run("member creating own pin allowed", func(t *testing.T) {
		resp := oc.do(t, "POST", "/api/v2/pins", pinBody(owner.UserID))
		resp.Body.Close()
		if resp.StatusCode != http.StatusCreated {
			t.Fatalf("expected 201 for group member, got %d", resp.StatusCode)
		}
	})
}

func TestEndpointLikes(t *testing.T) {
	srv := buildTestServer(t)
	defer srv.Close()

	anon := &apiClient{base: srv.URL}
	ar := anon.signup(t, "liker_ep", "pw123")
	c := &apiClient{base: srv.URL, bearer: ar.AccessToken}

	gid := c.createGroup(t, ar.UserID, "liketest_group", 0)

	pinResp := c.do(t, "POST", "/api/v2/pins", map[string]any{
		"latitude":     52.5,
		"longitude":    13.4,
		"creationDate": time.Now().UTC().Format(time.RFC3339),
		"userId":       ar.UserID,
		"groupId":      gid,
	})
	var p map[string]any
	decode(t, pinResp, &p)
	pid := fmt.Sprintf("%v", p["id"])
	if pid == "" || pid == "<nil>" {
		t.Fatalf("could not create pin to test likes endpoint: %v", p)
	}

	t.Run("GET /api/v2/pins/{id}/likes — initial zero likes", func(t *testing.T) {
		resp := c.do(t, "GET", "/api/v2/pins/"+pid+"/likes", nil)
		defer resp.Body.Close()
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("expected 200, got %d", resp.StatusCode)
		}
		var l map[string]any
		decode(t, resp, &l)
		// likeCount is omitted when 0 (omitempty), so nil means 0.
		if v, ok := l["likeCount"]; ok && v.(float64) != 0 {
			t.Fatalf("expected 0 likes, got %v", v)
		}
	})

	t.Run("POST /api/v2/pins/{id}/likes — like pin", func(t *testing.T) {
		resp := c.do(t, "POST", "/api/v2/pins/"+pid+"/likes", map[string]any{
			"like": true, "likeLocation": false, "likePhotography": false, "likeArt": false,
			"userId": ar.UserID,
		})
		defer resp.Body.Close()
		if resp.StatusCode != http.StatusCreated {
			t.Fatalf("expected 201, got %d", resp.StatusCode)
		}
		var l map[string]any
		decode(t, resp, &l)
		if v, _ := l["likeCount"].(float64); v != 1 {
			t.Fatalf("expected 1 like, got %v", l["likeCount"])
		}
	})

	t.Run("GET /api/v2/users/{id}/likes", func(t *testing.T) {
		resp := c.do(t, "GET", "/api/v2/users/"+ar.UserID+"/likes", nil)
		defer resp.Body.Close()
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("expected 200, got %d", resp.StatusCode)
		}
	})
}

func TestEndpointRanking(t *testing.T) {
	srv := buildTestServer(t)
	defer srv.Close()

	anon := &apiClient{base: srv.URL}
	ar := anon.signup(t, "rank_ep", "pw123")
	c := &apiClient{base: srv.URL, bearer: ar.AccessToken}

	t.Run("GET /api/v2/ranking/user", func(t *testing.T) {
		resp := c.do(t, "GET", "/api/v2/ranking/user?page=0&size=10", nil)
		defer resp.Body.Close()
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("expected 200, got %d", resp.StatusCode)
		}
	})

	t.Run("GET /api/v2/ranking/group", func(t *testing.T) {
		resp := c.do(t, "GET", "/api/v2/ranking/group?page=0&size=10", nil)
		defer resp.Body.Close()
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("expected 200, got %d", resp.StatusCode)
		}
	})

	t.Run("GET /api/v2/map — map info", func(t *testing.T) {
		resp := c.do(t, "GET", "/api/v2/map?latitude=48.1&longitude=11.6", nil)
		defer resp.Body.Close()
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("expected 200, got %d", resp.StatusCode)
		}
	})
}

func TestEndpointReport(t *testing.T) {
	srv := buildTestServer(t)
	defer srv.Close()

	anon := &apiClient{base: srv.URL}
	ar := anon.signup(t, "reporter", "pw123")
	c := &apiClient{base: srv.URL, bearer: ar.AccessToken}

	t.Run("POST /api/v2/report", func(t *testing.T) {
		resp := c.do(t, "POST", "/api/v2/report", map[string]any{
			"userId":  uuid.New().String(),
			"report":  "spam",
			"message": "test report",
		})
		resp.Body.Close()
		// 200 if mail is not configured, still expect non-5xx.
		if resp.StatusCode >= 500 {
			t.Fatalf("unexpected server error: %d", resp.StatusCode)
		}
	})
}
