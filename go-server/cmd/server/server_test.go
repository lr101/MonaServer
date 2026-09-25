package main

import (
	"bufio"
	"bytes"
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"strconv"
	"strings"
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

const testImageBase64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="

type memoryPinObjectStore struct {
	objects map[string][]byte
}

func newMemoryPinObjectStore() *memoryPinObjectStore {
	return &memoryPinObjectStore{objects: make(map[string][]byte)}
}

func (s *memoryPinObjectStore) Put(_ context.Context, key string, data []byte, _ string) error {
	s.objects[key] = bytes.Clone(data)
	return nil
}

func (s *memoryPinObjectStore) Remove(_ context.Context, key string) error {
	delete(s.objects, key)
	return nil
}

func (s *memoryPinObjectStore) PresignedGet(_ context.Context, key string) (string, error) {
	if _, ok := s.objects[key]; !ok {
		return "", nil
	}
	return "https://objects.test/" + key, nil
}

func TestNewReportServiceConfigRequiresHMACSecret(t *testing.T) {
	if _, err := newReportServiceConfig(&config.Config{}); err == nil {
		t.Fatal("report config accepted an empty HMAC secret")
	}

	reportConfig, err := newReportServiceConfig(&config.Config{AdminSessionHMACKey: "report-secret"})
	if err != nil {
		t.Fatalf("valid report config: %v", err)
	}
	if string(reportConfig.HMACKey) != "report-secret" {
		t.Fatalf("report HMAC key = %q, want report-secret", reportConfig.HMACKey)
	}
}

func testDSN(t *testing.T) string {
	t.Helper()
	dsn := os.Getenv("TEST_DATABASE_URL")
	if dsn == "" {
		t.Skip("TEST_DATABASE_URL not set; skipping integration test")
	}
	return dsn
}

func startTestSMTPServer(t *testing.T) (string, int) {
	t.Helper()
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listen for SMTP: %v", err)
	}
	t.Cleanup(func() { _ = listener.Close() })
	host, portText, err := net.SplitHostPort(listener.Addr().String())
	if err != nil {
		t.Fatalf("split SMTP address: %v", err)
	}
	port, err := strconv.Atoi(portText)
	if err != nil {
		t.Fatalf("parse SMTP port: %v", err)
	}
	go func() {
		for {
			conn, err := listener.Accept()
			if err != nil {
				return
			}
			go serveTestSMTPConnection(conn)
		}
	}()
	return host, port
}

func serveTestSMTPConnection(conn net.Conn) {
	defer conn.Close()
	reader := bufio.NewReader(conn)
	writer := bufio.NewWriter(conn)
	write := func(line string) {
		_, _ = writer.WriteString(line + "\r\n")
		_ = writer.Flush()
	}
	write("220 localhost ESMTP")
	for {
		line, err := reader.ReadString('\n')
		if err != nil {
			return
		}
		command := strings.TrimSpace(line)
		switch {
		case strings.HasPrefix(command, "EHLO"), strings.HasPrefix(command, "HELO"):
			_, _ = writer.WriteString("250-localhost\r\n250 AUTH PLAIN\r\n")
			_ = writer.Flush()
		case strings.HasPrefix(command, "AUTH"):
			write("235 2.7.0 Authentication successful")
		case command == "DATA":
			write("354 End data with <CR><LF>.<CR><LF>")
			for {
				dataLine, err := reader.ReadString('\n')
				if err != nil {
					return
				}
				if strings.TrimSpace(dataLine) == "." {
					break
				}
			}
			write("250 2.0.0 queued")
		case command == "QUIT":
			write("221 2.0.0 bye")
			return
		default:
			write("250 OK")
		}
	}
}

func buildTestServer(t *testing.T) *httptest.Server {
	server, _ := buildTestServerWithQuery(t)
	return server
}

func buildTestServerWithQuery(t *testing.T) (*httptest.Server, *db.Queries) {
	return buildTestServerWithPinStore(t, nil)
}

func buildTestServerWithPinStore(t *testing.T, pinStore service.PinObjectStore) (*httptest.Server, *db.Queries) {
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
		`TRUNCATE TABLE refresh_token, users, groups, pins, likes, members, seasons CASCADE`); err != nil {
		t.Fatalf("truncate: %v", err)
	}

	q := db.New(pool)
	mailHost, mailPort := startTestSMTPServer(t)
	cfg := &config.Config{
		JWTSecret:          "test-secret",
		AccessTokenExpiry:  time.Minute,
		RefreshTokenExpiry: time.Hour,
		MaxLoginAttempts:   10,
		AdminUsername:      "admin",
		WebAdminAPI:        true,
		TrustedProxyCIDRs:  "127.0.0.1/32",
		MailHost:           mailHost,
		MailPort:           mailPort,
		MailUsername:       "mail@test.example",
		MailPassword:       "password",
		MailFrom:           "mail@test.example",
	}
	tok := token.NewHelper(cfg.JWTSecret, cfg.AccessTokenExpiry)
	mailSvc := service.NewEmail(cfg, nil)
	authSvc := service.NewAuth(q, tok, cfg, mailSvc)
	guardSvc := service.NewGuard(q)
	userSvc := service.NewUser(q, nil, tok, authSvc, mailSvc)
	groupSvc := service.NewGroup(q, nil, userSvc)
	pinSvc := service.NewPin(q, pinStore)
	memberSvc := service.NewMember(q, nil, groupSvc)
	likeSvc := service.NewLike(q)
	rankSvc := service.NewRanking(q)
	notifSvc := service.NewNotification(context.Background(), "")
	achCfg := db.AchievementConfig{}

	authServicer := handler.NewAuthServicer(authSvc, q, mailSvc)
	groupsServicer := handler.NewGroupsServicer(groupSvc, guardSvc)
	pinsServicer := handler.NewPinsServicer(pinSvc, groupSvc, guardSvc, q)
	membersServicer := handler.NewMembersServicer(memberSvc, guardSvc)
	likesServicer := handler.NewLikesServicer(likeSvc, guardSvc)
	rankingServicer := handler.NewRankingServicer(rankSvc)
	adminServicer := handler.NewAdminServicer(q, mailSvc, notifSvc)
	adminAuth := service.NewAdminAuth(q, service.AdminAuthConfig{
		EncryptionKey: []byte("0123456789abcdef0123456789abcdef"),
		HMACKey:       []byte("server-test-admin-quota-key"),
	})
	reportServicer := handler.NewReportServicer(mailSvc, q, service.ReportServiceConfig{
		HMACKey:   []byte("server-test-report-quota-key"),
		HMACKeyID: "server-test-report-v1",
	})
	publicServicer := handler.NewPublicServicer()
	usersServicer := handler.NewUsersServicer(userSvc, guardSvc, q, achCfg)
	batchServicer := handler.NewBatchServicer(pinsServicer, usersServicer, groupsServicer, likesServicer, guardSvc)

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

	r := chi.NewRouter()
	r.Use(middleware.TrustedRealIP(cfg.TrustedProxyCIDRs))
	r.Use(chimw.Recoverer)

	// Mirror the route wiring in main.go.
	r.Group(func(r chi.Router) {
		registerRoutes(r, authCtrl, isPublicRoute)
		registerRoutes(r, authCtrl, isDeleteCodeRoute)
		registerRoutes(r, publicCtrl, alwaysTrue)
	})
	registerProtectedStatusRoutes(r, authCtrl, tok, authSvc, cfg.AdminUsername)
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
		registerRoutes(r.With(handler.CaptureReportRequest), reportCtrl, alwaysTrue)
		registerRoutes(r, usersCtrl, alwaysTrue)
		registerRoutes(r, batchCtrl, alwaysTrue)
	})
	registerAdminV2Routes(r, adminCtrl, adminAuth, cfg.WebAdminAPI)
	registerV3Routes(r, cfg, tok, authSvc, cfg.AdminUsername, adminAuth, q)

	return httptest.NewServer(r), q
}

func TestUnpagedWhenPageMissing(t *testing.T) {
	tests := []struct {
		rawQuery string
		wantSize string
	}{
		{rawQuery: "", wantSize: "0"},
		{rawQuery: "size=5", wantSize: "0"},
		{rawQuery: "page=2", wantSize: ""},
		{rawQuery: "page=2&size=5", wantSize: "5"},
	}
	for _, tt := range tests {
		t.Run(tt.rawQuery, func(t *testing.T) {
			var got string
			next := http.HandlerFunc(func(_ http.ResponseWriter, r *http.Request) { got = r.URL.Query().Get("size") })
			req := httptest.NewRequest(http.MethodGet, "/api/v2/groups?"+tt.rawQuery, nil)
			unpagedWhenPageMissing(next).ServeHTTP(httptest.NewRecorder(), req)
			if got != tt.wantSize {
				t.Fatalf("size = %q, want %q", got, tt.wantSize)
			}
		})
	}

}

func TestValidateCoupledQueryParameters(t *testing.T) {
	tests := []struct {
		path  string
		query string
		want  int
	}{
		{path: "/api/v2/groups", query: "withUser=true", want: http.StatusBadRequest},
		{path: "/api/v2/groups", query: "userId=00000000-0000-0000-0000-000000000000", want: http.StatusBadRequest},
		{path: "/api/v2/groups", query: "withUser=false&userId=00000000-0000-0000-0000-000000000000", want: http.StatusOK},
		{path: "/api/v2/map", query: "latitude=1", want: http.StatusBadRequest},
		{path: "/api/v2/map", query: "longitude=1", want: http.StatusBadRequest},
		{path: "/api/v2/map", query: "latitude=1&longitude=2", want: http.StatusOK},
		{path: "/api/v2/pins", query: "userId=00000000-0000-0000-0000-000000000000", want: http.StatusOK},
		{path: "/api/v2/pins", query: "beforeCreationDate=2026-01-01T00:00:00Z", want: http.StatusBadRequest},
		{path: "/api/v2/pins", query: "beforeId=00000000-0000-0000-0000-000000000000", want: http.StatusBadRequest},
		{path: "/api/v2/pins", query: "beforeCreationDate=2026-01-01T00:00:00Z&beforeId=00000000-0000-0000-0000-000000000000", want: http.StatusOK},
	}
	for _, tt := range tests {
		t.Run(tt.query, func(t *testing.T) {
			req := httptest.NewRequest(http.MethodGet, tt.path+"?"+tt.query, nil)
			recorder := httptest.NewRecorder()
			validateCoupledQueryParameters(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusOK) })).ServeHTTP(recorder, req)
			if recorder.Code != tt.want {
				t.Fatalf("status = %d, want %d", recorder.Code, tt.want)
			}
		})
	}

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

type testNotificationSender struct{ err error }

func (s testNotificationSender) SendToToken(context.Context, string, string, string) error {
	return s.err
}

type testFirebaseTokenClearer struct {
	userID uuid.UUID
	token  *string
}

func (c *testFirebaseTokenClearer) UpdateUserFirebaseToken(_ context.Context, userID uuid.UUID, token *string) error {
	c.userID = userID
	c.token = token
	return nil
}

func TestFailedWeeklyNotificationClearsInvalidToken(t *testing.T) {
	target := db.NotificationTarget{UserID: uuid.New(), FirebaseToken: "invalid", PinCount: 3}
	clearer := &testFirebaseTokenClearer{}
	err := sendWeeklyNotification(context.Background(), testNotificationSender{err: fmt.Errorf("unregistered")}, clearer, target)
	if err == nil {
		t.Fatal("send failure was not reported")
	}
	if clearer.userID != target.UserID || clearer.token != nil {
		t.Fatalf("cleared user/token = %s/%v, want %s/nil", clearer.userID, clearer.token, target.UserID)
	}
}

func (c *apiClient) do(t *testing.T, method, path string, body any) *http.Response {
	return c.doWithHeaders(t, method, path, body, nil)
}

func (c *apiClient) doWithHeaders(t *testing.T, method, path string, body any, headers map[string]string) *http.Response {
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
	for key, value := range headers {
		req.Header.Set(key, value)
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
		"name": name, "description": "", "profileImage": testImageBase64,
		"visibility": visibility, "groupAdmin": adminID,
	})
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusCreated {
		t.Fatalf("create group %q: expected 201, got %d", name, resp.StatusCode)
	}
	var g map[string]any
	_ = json.NewDecoder(resp.Body).Decode(&g)
	return fmt.Sprintf("%v", g["id"])
}

func TestRequiredCreateFieldsAreValidatedByPresence(t *testing.T) {
	tests := []struct {
		path string
		body string
	}{
		{path: "/api/v2/groups", body: `{"name":"group","groupAdmin":"id","visibility":0,"description":""}`},
		{path: "/api/v2/pins", body: `{"latitude":0,"longitude":0,"userId":"id","groupId":"id"}`},
	}
	for _, tt := range tests {
		t.Run(tt.path, func(t *testing.T) {
			recorder := httptest.NewRecorder()
			req := httptest.NewRequest(http.MethodPost, tt.path, strings.NewReader(tt.body))
			requireCompatibilityJSONFields(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusOK) })).ServeHTTP(recorder, req)
			if recorder.Code != http.StatusBadRequest {
				t.Fatalf("status = %d, want 400", recorder.Code)
			}
		})
	}
}

func TestRedirectImageResponses(t *testing.T) {
	const target = "https://objects.example/image.jpg?signature=test"
	routes := []string{
		"/api/v2/groups/id/profile_image",
		"/api/v2/groups/id/profile_image_small",
		"/api/v2/groups/id/pin_image",
		"/api/v2/pins/id/image",
		"/api/v2/users/id/profile_picture",
		"/api/v2/users/id/profile_picture_small",
	}
	next := http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		_ = json.NewEncoder(w).Encode(target)
	})
	for _, route := range routes {
		t.Run(route, func(t *testing.T) {
			recorder := httptest.NewRecorder()
			request := httptest.NewRequest(http.MethodGet, route+"?redirect=true", nil)
			redirectImageResponses(next).ServeHTTP(recorder, request)
			if recorder.Code != http.StatusMovedPermanently {
				t.Fatalf("status = %d, want 301", recorder.Code)
			}
			if location := recorder.Header().Get("Location"); location != target {
				t.Fatalf("Location = %q, want %q", location, target)
			}
		})
	}

	t.Run("redirect false preserves URL response", func(t *testing.T) {
		recorder := httptest.NewRecorder()
		request := httptest.NewRequest(http.MethodGet, routes[0]+"?redirect=false", nil)
		redirectImageResponses(next).ServeHTTP(recorder, request)
		if recorder.Code != http.StatusOK {
			t.Fatalf("status = %d, want 200", recorder.Code)
		}
	})
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
			"userId":       ar.UserID,
		})
		defer resp.Body.Close()
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("refresh: expected 200, got %d", resp.StatusCode)
		}
	})

	t.Run("status requires authentication", func(t *testing.T) {
		resp := c.do(t, "GET", "/api/v2/status", nil)
		resp.Body.Close()
		if resp.StatusCode != http.StatusUnauthorized {
			t.Fatalf("unauthenticated status: expected 401, got %d", resp.StatusCode)
		}
		ar := c.signup(t, "status_user", "pw123")
		authed := &apiClient{base: srv.URL, bearer: ar.AccessToken}
		resp = authed.do(t, "GET", "/api/v2/status", nil)
		if resp.StatusCode != http.StatusOK {
			resp.Body.Close()
			t.Fatalf("authenticated status: expected 200, got %d", resp.StatusCode)
		}
		body, err := io.ReadAll(resp.Body)
		resp.Body.Close()
		if err != nil {
			t.Fatalf("read authenticated status: %v", err)
		}
		var fields map[string]json.RawMessage
		if err := json.Unmarshal(body, &fields); err != nil {
			t.Fatalf("decode authenticated status: %v", err)
		}
		if len(fields) != 2 {
			t.Fatalf("status response has %d fields, want exactly 2", len(fields))
		}
		for _, field := range []string{"notifications", "token-validity"} {
			if _, ok := fields[field]; !ok {
				t.Fatalf("status response is missing %q", field)
			}
		}
	})

	t.Run("delete-code is public (no bearer token required)", func(t *testing.T) {
		// Requesting a delete code is part of the public account workflow.
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

func TestBatchReadAuthenticationAndValidation(t *testing.T) {
	srv := buildTestServer(t)
	defer srv.Close()

	anon := &apiClient{base: srv.URL}
	auth := anon.signup(t, "batch_validation", "pw123")
	client := &apiClient{base: srv.URL, bearer: auth.AccessToken}
	id := uuid.New().String()

	tests := []struct {
		name   string
		client *apiClient
		body   any
		want   int
	}{
		{name: "authentication required", client: anon, body: map[string]any{"requests": []any{map[string]string{"kind": "user", "id": id}}}, want: http.StatusUnauthorized},
		{name: "empty request rejected", client: client, body: map[string]any{"requests": []any{}}, want: http.StatusBadRequest},
		{name: "missing requests rejected", client: client, body: map[string]any{}, want: http.StatusBadRequest},
		{name: "unknown kind rejected", client: client, body: map[string]any{"requests": []any{map[string]string{"kind": "unknown", "id": id}}}, want: http.StatusBadRequest},
		{name: "malformed id rejected", client: client, body: map[string]any{"requests": []any{map[string]string{"kind": "user", "id": "not-a-uuid"}}}, want: http.StatusBadRequest},
	}
	overLimit := make([]any, 101)
	for i := range overLimit {
		overLimit[i] = map[string]string{"kind": "user", "id": id}
	}
	tests = append(tests, struct {
		name   string
		client *apiClient
		body   any
		want   int
	}{name: "over limit rejected", client: client, body: map[string]any{"requests": overLimit}, want: http.StatusBadRequest})

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resp := tt.client.do(t, http.MethodPost, "/api/v3/batch", tt.body)
			defer resp.Body.Close()
			if resp.StatusCode != tt.want {
				t.Fatalf("status = %d, want %d", resp.StatusCode, tt.want)
			}
		})
	}

	t.Run("trailing JSON rejected", func(t *testing.T) {
		req, err := http.NewRequest(http.MethodPost, srv.URL+"/api/v3/batch", strings.NewReader(`{"requests":[{"kind":"user","id":"`+auth.UserID+`"}]} {}`))
		if err != nil {
			t.Fatalf("create request: %v", err)
		}
		req.Header.Set("Authorization", "Bearer "+auth.AccessToken)
		req.Header.Set("Content-Type", "application/json")
		resp, err := http.DefaultClient.Do(req)
		if err != nil {
			t.Fatalf("batch request: %v", err)
		}
		defer resp.Body.Close()
		if resp.StatusCode != http.StatusBadRequest {
			t.Fatalf("status = %d, want 400", resp.StatusCode)
		}
	})
}

func TestBatchReadResourcesAndPerItemAuthorization(t *testing.T) {
	srv := buildTestServer(t)
	defer srv.Close()

	anon := &apiClient{base: srv.URL}
	owner := anon.signup(t, "batch_owner", "pw123")
	outsider := anon.signup(t, "batch_outsider", "pw123")
	ownerClient := &apiClient{base: srv.URL, bearer: owner.AccessToken}
	outsiderClient := &apiClient{base: srv.URL, bearer: outsider.AccessToken}
	publicGroupID := ownerClient.createGroup(t, owner.UserID, "batch_public", 0)
	privateGroupID := ownerClient.createGroup(t, owner.UserID, "batch_private", 1)

	pinNumber := 0
	createPin := func(groupID string) string {
		pinNumber++
		resp := ownerClient.do(t, http.MethodPost, "/api/v2/pins", map[string]any{
			"image":        testImageBase64,
			"latitude":     48.137 + float64(pinNumber),
			"longitude":    11.576 + float64(pinNumber),
			"creationDate": time.Now().UTC().Format(time.RFC3339),
			"userId":       owner.UserID,
			"groupId":      groupID,
		})
		defer resp.Body.Close()
		if resp.StatusCode != http.StatusCreated {
			t.Fatalf("create pin: status = %d, want 201", resp.StatusCode)
		}
		var pin map[string]any
		decode(t, resp, &pin)
		return fmt.Sprintf("%v", pin["id"])
	}
	publicPinID := createPin(publicGroupID)
	privatePinID := createPin(privateGroupID)

	like := ownerClient.do(t, http.MethodPost, "/api/v2/pins/"+publicPinID+"/likes", map[string]any{
		"like": true, "likeLocation": false, "likePhotography": false, "likeArt": false, "userId": owner.UserID,
	})
	like.Body.Close()
	if like.StatusCode != http.StatusCreated {
		t.Fatalf("create like: status = %d, want 201", like.StatusCode)
	}

	requests := []map[string]string{
		{"kind": "pinImage", "id": publicPinID},
		{"kind": "userImageSmall", "id": owner.UserID},
		{"kind": "userImage", "id": owner.UserID},
		{"kind": "groupImageSmall", "id": publicGroupID},
		{"kind": "groupImage", "id": publicGroupID},
		{"kind": "groupPinImage", "id": publicGroupID},
		{"kind": "user", "id": owner.UserID},
		{"kind": "pinLikes", "id": publicPinID},
		{"kind": "pinImage", "id": privatePinID},
		{"kind": "groupImageSmall", "id": privateGroupID},
		{"kind": "groupImage", "id": privateGroupID},
		{"kind": "groupPinImage", "id": privateGroupID},
		{"kind": "pinLikes", "id": publicPinID},
	}
	response := outsiderClient.do(t, http.MethodPost, "/api/v3/batch", map[string]any{"requests": requests})
	if response.StatusCode != http.StatusOK {
		response.Body.Close()
		t.Fatalf("batch status = %d, want 200", response.StatusCode)
	}
	var body struct {
		Results []struct {
			Kind     string         `json:"kind"`
			ID       string         `json:"id"`
			Status   int            `json:"status"`
			ImageURL *string        `json:"imageUrl"`
			User     map[string]any `json:"user"`
			Likes    map[string]any `json:"likes"`
		} `json:"results"`
	}
	decode(t, response, &body)
	if len(body.Results) != len(requests) {
		t.Fatalf("result count = %d, want %d", len(body.Results), len(requests))
	}
	for i := 0; i < 8; i++ {
		if got := body.Results[i].Status; got != http.StatusOK {
			t.Fatalf("result %d (%s) status = %d, want 200", i, requests[i]["kind"], got)
		}
	}
	for _, i := range []int{8, 9, 10, 11} {
		result := body.Results[i]
		if result.Status != http.StatusForbidden {
			t.Fatalf("result %d (%s) status = %d, want 403", i, requests[i]["kind"], result.Status)
		}
		if result.ImageURL != nil || result.User != nil || result.Likes != nil {
			t.Fatalf("forbidden result %d exposed resource data: %+v", i, result)
		}
	}
	if got := body.Results[6].User["userId"]; got != owner.UserID {
		t.Fatalf("user result id = %v, want %s", got, owner.UserID)
	}
	if got, _ := body.Results[7].Likes["likeCount"].(float64); got != 1 {
		t.Fatalf("outsider like count = %v, want 1", body.Results[7].Likes["likeCount"])
	}
	if liked, _ := body.Results[7].Likes["likedByUser"].(bool); liked {
		t.Fatal("outsider pinLikes result reported another caller's like")
	}
	if fmt.Sprint(body.Results[7].Likes) != fmt.Sprint(body.Results[12].Likes) {
		t.Fatal("duplicate request did not preserve the cached result")
	}

	ownerResponse := ownerClient.do(t, http.MethodPost, "/api/v3/batch", map[string]any{
		"requests": []map[string]string{{"kind": "pinLikes", "id": publicPinID}},
	})
	var ownerBody struct {
		Results []struct {
			Likes map[string]any `json:"likes"`
		} `json:"results"`
	}
	decode(t, ownerResponse, &ownerBody)
	if liked, _ := ownerBody.Results[0].Likes["likedByUser"].(bool); !liked {
		t.Fatal("owner pinLikes result did not include the caller's like")
	}
}

// TestDeleteAccountWithEmailedCode exercises the full account-deletion flow:
// request a delete code (which must store a 6-digit code), then delete the
// account using exactly that code — as both the app and web page do.
func TestDeleteAccountWithEmailedCode(t *testing.T) {
	srv := buildTestServer(t)
	defer srv.Close()

	anon := &apiClient{base: srv.URL}
	ar := anon.signup(t, "delflow", "pw123")
	c := &apiClient{base: srv.URL, bearer: ar.AccessToken}

	// Request the delete code (public endpoint, no auth).
	resp := c.do(t, "GET", "/api/v2/public/delete-code/delflow", nil)
	resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("request delete code: expected 200, got %d", resp.StatusCode)
	}

	// The code is emailed to the user; read it from the DB to act as the user
	// typing it into the app/website.
	pool, err := db.NewPool(context.Background(), os.Getenv("TEST_DATABASE_URL"))
	if err != nil {
		t.Fatalf("pool: %v", err)
	}
	defer pool.Close()
	var code string
	if err := pool.QueryRow(context.Background(),
		`SELECT code FROM users WHERE username = $1`, "delflow").Scan(&code); err != nil {
		t.Fatalf("read stored delete code: %v", err)
	}
	if code == "" {
		t.Fatal("delete code was not stored — the app could not delete the account")
	}
	if len(code) != 6 {
		t.Fatalf("expected a 6-digit code, got %q", code)
	}
	codeInt, err := strconv.Atoi(code)
	if err != nil {
		t.Fatalf("stored code is not numeric: %q", code)
	}

	// Wrong code must be rejected.
	wrong := c.do(t, "DELETE", "/api/v2/users/"+ar.UserID, (codeInt+1)%1000000)
	wrong.Body.Close()
	if wrong.StatusCode == http.StatusOK {
		t.Fatal("deletion succeeded with the wrong code")
	}

	// Correct emailed code deletes the account.
	ok := c.do(t, "DELETE", "/api/v2/users/"+ar.UserID, codeInt)
	ok.Body.Close()
	if ok.StatusCode != http.StatusOK {
		t.Fatalf("delete with emailed code: expected 200, got %d", ok.StatusCode)
	}
}

func TestEndpointPublic(t *testing.T) {
	srv := buildTestServer(t)
	defer srv.Close()
	c := &apiClient{base: srv.URL}

	t.Run("GET /api/v2/public/infos", func(t *testing.T) {
		resp := c.do(t, "GET", "/api/v2/public/infos", nil)
		if resp.StatusCode != http.StatusOK {
			resp.Body.Close()
			t.Fatalf("expected 200, got %d", resp.StatusCode)
		}
		var infos []genserver.InfoDto
		decode(t, resp, &infos)
		if len(infos) != 0 {
			t.Fatalf("public infos = %+v, want an empty list", infos)
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

	t.Run("GET /api/v2/groups/{id}/progression requires auth and reports group level", func(t *testing.T) {
		path := "/api/v2/groups/" + gid + "/progression"
		unauthorized := anon.do(t, "GET", path, nil)
		unauthorized.Body.Close()
		if unauthorized.StatusCode != http.StatusUnauthorized {
			t.Fatalf("unauthenticated progression status = %d, want %d", unauthorized.StatusCode, http.StatusUnauthorized)
		}

		resp := c.do(t, "GET", path, nil)
		defer resp.Body.Close()
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("progression status = %d, want %d", resp.StatusCode, http.StatusOK)
		}
		var progress map[string]any
		decode(t, resp, &progress)
		if progress["groupId"] != gid || progress["totalXp"] != float64(0) ||
			progress["currentLevel"] != float64(1) || progress["currentLevelXp"] != float64(0) ||
			progress["nextLevelXp"] != float64(50) {
			t.Fatalf("group progression = %+v, want level 1 at 0/50 XP", progress)
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

	t.Run("group description is raw text", func(t *testing.T) {
		update := c.do(t, "PUT", "/api/v2/groups/"+gid, map[string]any{"description": "plain description"})
		update.Body.Close()
		if update.StatusCode != http.StatusOK {
			t.Fatalf("update description: expected 200, got %d", update.StatusCode)
		}
		resp := c.do(t, "GET", "/api/v2/groups/"+gid+"/description", nil)
		defer resp.Body.Close()
		body, err := io.ReadAll(resp.Body)
		if err != nil {
			t.Fatalf("read description: %v", err)
		}
		if got := string(body); got != "plain description" {
			t.Fatalf("description body = %q, want raw text", got)
		}
		if contentType := resp.Header.Get("Content-Type"); !strings.HasPrefix(contentType, "text/plain") {
			t.Fatalf("description content type = %q, want text/plain", contentType)
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
			"name": "spoofed_group", "description": "", "profileImage": testImageBase64,
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
			"name": "own_group", "description": "", "profileImage": testImageBase64,
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
	srv, _ := buildTestServerWithQuery(t)
	defer srv.Close()

	anon := &apiClient{base: srv.URL}
	ar := anon.signup(t, "pinner", "pw123")
	c := &apiClient{base: srv.URL, bearer: ar.AccessToken}

	gid := c.createGroup(t, ar.UserID, "pintest_group", 0)

	var pid string
	var syncWatermark time.Time

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
			"image":        testImageBase64,
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
		syncWatermark = time.Now().UTC()
	})

	t.Run("POST /api/v2/pins/{id}/presence — mark gone and restore", func(t *testing.T) {
		resp := c.do(t, "GET", "/api/v3/sync?lastSeen="+syncWatermark.Format(time.RFC3339Nano), nil)
		if resp.StatusCode != http.StatusOK {
			resp.Body.Close()
			t.Fatalf("sync before presence update: expected 200, got %d", resp.StatusCode)
		}
		var initialSync struct {
			GroupUpdates []struct {
				PinsAdded []map[string]any `json:"pinsAdded"`
			} `json:"groupUpdates"`
		}
		decode(t, resp, &initialSync)
		resp.Body.Close()
		for _, groupUpdate := range initialSync.GroupUpdates {
			for _, syncedPin := range groupUpdate.PinsAdded {
				if syncedPin["id"] == pid {
					t.Fatalf("pin %s appeared in sync before presence update", pid)
				}
			}
		}

		resp = c.do(t, "POST", "/api/v2/pins/"+pid+"/presence", map[string]any{
			"state": "gone",
		})
		if resp.StatusCode != http.StatusOK {
			resp.Body.Close()
			t.Fatalf("mark gone: expected 200, got %d", resp.StatusCode)
		}
		var gone map[string]any
		decode(t, resp, &gone)
		if gone["isGone"] != true {
			t.Fatalf("presence response isGone = %v, want true", gone["isGone"])
		}

		resp = c.do(t, "GET", "/api/v2/pins?groupId="+gid+"&withImage=false", nil)
		if resp.StatusCode != http.StatusOK {
			resp.Body.Close()
			t.Fatalf("list after gone report: expected 200, got %d", resp.StatusCode)
		}
		var pins struct {
			Items []map[string]any `json:"items"`
		}
		decode(t, resp, &pins)
		if len(pins.Items) != 1 || pins.Items[0]["id"] != pid || pins.Items[0]["isGone"] != true {
			t.Fatalf("listed pins = %+v, want the same pin retained and marked gone", pins.Items)
		}

		resp = c.do(t, "GET", "/api/v3/sync?lastSeen="+syncWatermark.Format(time.RFC3339Nano), nil)
		if resp.StatusCode != http.StatusOK {
			resp.Body.Close()
			t.Fatalf("sync after gone report: expected 200, got %d", resp.StatusCode)
		}
		var syncState struct {
			GroupUpdates []struct {
				PinsAdded []map[string]any `json:"pinsAdded"`
			} `json:"groupUpdates"`
		}
		decode(t, resp, &syncState)
		foundGonePin := false
		for _, groupUpdate := range syncState.GroupUpdates {
			for _, syncedPin := range groupUpdate.PinsAdded {
				if syncedPin["id"] == pid && syncedPin["isGone"] == true {
					foundGonePin = true
				}
			}
		}
		if !foundGonePin {
			t.Fatalf("sync updates = %+v, want pin %s marked gone", syncState.GroupUpdates, pid)
		}

		resp = c.do(t, "POST", "/api/v2/pins/"+pid+"/presence", map[string]any{
			"state": "here",
		})
		if resp.StatusCode != http.StatusOK {
			resp.Body.Close()
			t.Fatalf("mark here: expected 200, got %d", resp.StatusCode)
		}
		var restored map[string]any
		decode(t, resp, &restored)
		if restored["isGone"] != false {
			t.Fatalf("restored response isGone = %v, want false", restored["isGone"])
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

func TestEndpointPinPhotosIncludesOriginalImage(t *testing.T) {
	srv, _ := buildTestServerWithPinStore(t, newMemoryPinObjectStore())
	defer srv.Close()

	anon := &apiClient{base: srv.URL}
	auth := anon.signup(t, "pin_photo_api_user", "pw123")
	client := &apiClient{base: srv.URL, bearer: auth.AccessToken}
	groupID := client.createGroup(t, auth.UserID, "pin_photo_api_group", 0)

	resp := client.do(t, "POST", "/api/v2/pins", map[string]any{
		"image":        testImageBase64,
		"latitude":     48.137,
		"longitude":    11.576,
		"creationDate": time.Now().UTC().Format(time.RFC3339),
		"userId":       auth.UserID,
		"groupId":      groupID,
	})
	if resp.StatusCode != http.StatusCreated {
		resp.Body.Close()
		t.Fatalf("create pin: expected 201, got %d", resp.StatusCode)
	}
	var pin map[string]any
	decode(t, resp, &pin)
	resp.Body.Close()
	pinID := fmt.Sprintf("%v", pin["id"])

	resp = anon.do(t, "GET", "/api/v2/pins/"+pinID+"/photos", nil)
	resp.Body.Close()
	if resp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("unauthenticated photo history: expected 401, got %d", resp.StatusCode)
	}

	resp = client.do(t, "POST", "/api/v2/pins/"+pinID+"/presence", map[string]string{"state": "gone"})
	if resp.StatusCode != http.StatusOK {
		resp.Body.Close()
		t.Fatalf("mark pin gone: expected 200, got %d", resp.StatusCode)
	}
	resp.Body.Close()

	resp = client.do(t, "GET", "/api/v2/pins/"+pinID+"/photos", nil)
	if resp.StatusCode != http.StatusOK {
		resp.Body.Close()
		t.Fatalf("get pin photo history: expected 200, got %d", resp.StatusCode)
	}
	var photos []map[string]any
	decode(t, resp, &photos)
	resp.Body.Close()
	if len(photos) != 1 || photos[0]["isOriginal"] != true {
		t.Fatalf("pin photo history = %+v, want its original photo", photos)
	}
	if photos[0]["contributorUsername"] != "pin_photo_api_user" {
		t.Fatalf("original contributor = %v, want pin_photo_api_user", photos[0]["contributorUsername"])
	}

	photoRequest := map[string]any{
		"image":          testImageBase64,
		"idempotencyKey": uuid.NewString(),
		"latitude":       48.137,
		"longitude":      11.576,
		"accuracyMeters": 0,
		"caption":        "Still here after the rain",
	}
	incompletePhotoRequest := map[string]any{
		"image":          testImageBase64,
		"idempotencyKey": uuid.NewString(),
		"latitude":       48.137,
		"accuracyMeters": 5,
	}
	resp = client.do(t, "POST", "/api/v2/pins/"+pinID+"/photos", incompletePhotoRequest)
	resp.Body.Close()
	if resp.StatusCode != http.StatusUnprocessableEntity {
		t.Fatalf("photo upload without longitude: expected 422, got %d", resp.StatusCode)
	}
	resp = client.do(t, "POST", "/api/v2/pins/"+pinID+"/photos", photoRequest)
	if resp.StatusCode != http.StatusCreated {
		resp.Body.Close()
		t.Fatalf("add pin photo: expected 201, got %d", resp.StatusCode)
	}
	var added map[string]any
	decode(t, resp, &added)
	resp.Body.Close()
	if added["isOriginal"] != false || added["caption"] != "Still here after the rain" {
		t.Fatalf("added photo = %+v, want a later captioned photo", added)
	}
	firstPhotoID := added["id"]

	farPhotoRequest := map[string]any{
		"image":          testImageBase64,
		"idempotencyKey": uuid.NewString(),
		"latitude":       48.138,
		"longitude":      11.576,
		"accuracyMeters": 5,
	}
	resp = client.do(t, "POST", "/api/v2/pins/"+pinID+"/photos", farPhotoRequest)
	resp.Body.Close()
	if resp.StatusCode != http.StatusForbidden {
		t.Fatalf("photo upload from farther than 50 m: expected 403, got %d", resp.StatusCode)
	}

	resp = client.do(t, "POST", "/api/v2/pins/"+pinID+"/photos", photoRequest)
	if resp.StatusCode != http.StatusCreated {
		resp.Body.Close()
		t.Fatalf("retry photo upload: expected 201, got %d", resp.StatusCode)
	}
	var retried map[string]any
	decode(t, resp, &retried)
	resp.Body.Close()
	if retried["id"] != firstPhotoID {
		t.Fatalf("idempotent retry returned photo %v, want %v", retried["id"], firstPhotoID)
	}

	resp = client.do(t, "GET", "/api/v2/pins/"+pinID, nil)
	if resp.StatusCode != http.StatusOK {
		resp.Body.Close()
		t.Fatalf("get pin after photo update: expected 200, got %d", resp.StatusCode)
	}
	var pinAfterUpdate map[string]any
	decode(t, resp, &pinAfterUpdate)
	resp.Body.Close()
	if pinAfterUpdate["isGone"] != true {
		t.Fatalf("photo update changed pin presence: isGone = %v, want true", pinAfterUpdate["isGone"])
	}

	resp = client.do(t, "GET", "/api/v2/pins/"+pinID+"/photos", nil)
	if resp.StatusCode != http.StatusOK {
		resp.Body.Close()
		t.Fatalf("get updated pin photo history: expected 200, got %d", resp.StatusCode)
	}
	photos = nil
	decode(t, resp, &photos)
	resp.Body.Close()
	if len(photos) != 2 || photos[0]["isOriginal"] != true || photos[1]["isOriginal"] != false {
		t.Fatalf("updated pin photo history = %+v, want original then new photo", photos)
	}
}

func TestPinPresenceRejectsFormerPrivateGroupMember(t *testing.T) {
	srv, q := buildTestServerWithQuery(t)
	defer srv.Close()

	anon := &apiClient{base: srv.URL}
	owner := anon.signup(t, "presence_private_owner", "pw123")
	formerMember := anon.signup(t, "presence_former_member", "pw123")
	ownerClient := &apiClient{base: srv.URL, bearer: owner.AccessToken}
	memberClient := &apiClient{base: srv.URL, bearer: formerMember.AccessToken}

	groupID := ownerClient.createGroup(t, owner.UserID, "presence_private_group", 1)
	groupUUID, err := uuid.Parse(groupID)
	if err != nil {
		t.Fatalf("parse group id: %v", err)
	}
	ownerUUID, err := uuid.Parse(owner.UserID)
	if err != nil {
		t.Fatalf("parse owner id: %v", err)
	}
	memberUUID, err := uuid.Parse(formerMember.UserID)
	if err != nil {
		t.Fatalf("parse former member id: %v", err)
	}
	ctx := context.Background()
	if err := q.AddMember(ctx, groupUUID, ownerUUID); err != nil {
		t.Fatalf("ensure group owner membership: %v", err)
	}
	if err := q.AddMember(ctx, groupUUID, memberUUID); err != nil {
		t.Fatalf("add private group member: %v", err)
	}

	resp := ownerClient.do(t, "POST", "/api/v2/pins", map[string]any{
		"image":        testImageBase64,
		"latitude":     48.137,
		"longitude":    11.576,
		"creationDate": time.Now().UTC().Format(time.RFC3339),
		"userId":       owner.UserID,
		"groupId":      groupID,
	})
	if resp.StatusCode != http.StatusCreated {
		resp.Body.Close()
		t.Fatalf("create private pin: expected 201, got %d", resp.StatusCode)
	}
	var pin map[string]any
	decode(t, resp, &pin)
	resp.Body.Close()
	pinID := fmt.Sprintf("%v", pin["id"])

	if _, err := q.Pool().Exec(ctx,
		`UPDATE members SET is_deleted = TRUE WHERE group_id = $1 AND user_id = $2`,
		groupUUID, memberUUID,
	); err != nil {
		t.Fatalf("soft-delete former membership: %v", err)
	}

	resp = memberClient.do(t, "POST", "/api/v2/pins/"+pinID+"/presence", map[string]any{
		"state": "gone",
	})
	resp.Body.Close()
	if resp.StatusCode != http.StatusForbidden {
		t.Fatalf("former private group member could update pin presence: expected 403, got %d", resp.StatusCode)
	}
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
			"image":        testImageBase64,
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
		"image":        testImageBase64,
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
	srv, q := buildTestServerWithQuery(t)
	defer srv.Close()
	if _, err := q.Pool().Exec(context.Background(), `TRUNCATE TABLE rate_limit_buckets`); err != nil {
		t.Fatalf("truncate report quota buckets: %v", err)
	}

	anon := &apiClient{base: srv.URL}
	ar := anon.signup(t, "reporter", "pw123")
	c := &apiClient{base: srv.URL, bearer: ar.AccessToken}

	t.Run("POST /api/v2/report", func(t *testing.T) {
		const reportQuotaKey = "server-test-report-quota-key"
		const reportQuotaKeyID = "server-test-report-v1"
		const forwardedIP = "198.51.100.7"
		body := map[string]any{
			"userId":  ar.UserID,
			"report":  "spam",
			"message": "test report",
		}
		headers := map[string]string{
			"Idempotency-Key": "routed-report-key",
			"X-Forwarded-For": forwardedIP + ", 127.0.0.1",
		}
		resp := c.doWithHeaders(t, "POST", "/api/v2/report", body, headers)
		resp.Body.Close()
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("report status = %d, want 200", resp.StatusCode)
		}
		replay := c.doWithHeaders(t, "POST", "/api/v2/report", body, headers)
		replay.Body.Close()
		if replay.StatusCode != http.StatusOK {
			t.Fatalf("report replay status = %d, want 200", replay.StatusCode)
		}
		var count int
		if err := q.Pool().QueryRow(context.Background(), `SELECT count(*) FROM reports WHERE reporter_user_id = $1`, ar.UserID).Scan(&count); err != nil {
			t.Fatalf("count routed reports: %v", err)
		}
		if count != 1 {
			t.Fatalf("routed reports = %d, want exactly one idempotent row", count)
		}
		accountHMAC := reportQuotaIdentifierHMAC([]byte(reportQuotaKey), "report-submit-account", ar.UserID)
		ipHMAC := reportQuotaIdentifierHMAC([]byte(reportQuotaKey), "report-submit-ip", forwardedIP)
		var accountHits, ipHits int64
		if err := q.Pool().QueryRow(context.Background(), `
			SELECT hit_count FROM rate_limit_buckets
			WHERE scope = 'report-submit-account' AND identifier_hmac = $1 AND key_id = $2`, accountHMAC, reportQuotaKeyID).Scan(&accountHits); err != nil {
			t.Fatalf("read routed account quota bucket: %v", err)
		}
		if err := q.Pool().QueryRow(context.Background(), `
			SELECT hit_count FROM rate_limit_buckets
			WHERE scope = 'report-submit-ip' AND identifier_hmac = $1 AND key_id = $2`, ipHMAC, reportQuotaKeyID).Scan(&ipHits); err != nil {
			t.Fatalf("read routed IP quota bucket: %v", err)
		}
		if accountHits != 1 || ipHits != 1 {
			t.Fatalf("routed quota hits account=%d ip=%d, want one keyed hit each", accountHits, ipHits)
		}
	})

	t.Run("POST /api/v2/report quota response", func(t *testing.T) {
		ar := anon.signup(t, "report-quota", "pw123")
		c := &apiClient{base: srv.URL, bearer: ar.AccessToken}
		const forwardedIP = "203.0.113.42"
		for i := 0; i < 10; i++ {
			resp := c.doWithHeaders(t, "POST", "/api/v2/report", map[string]any{
				"userId": ar.UserID, "report": "spam", "message": fmt.Sprintf("quota report %d", i),
			}, map[string]string{
				"Idempotency-Key": fmt.Sprintf("quota-report-%d", i),
				"X-Forwarded-For": forwardedIP + ", 127.0.0.1",
			})
			resp.Body.Close()
			if resp.StatusCode != http.StatusOK {
				t.Fatalf("quota fill request %d status = %d, want 200", i, resp.StatusCode)
			}
		}

		limited := c.doWithHeaders(t, "POST", "/api/v2/report", map[string]any{
			"userId": ar.UserID, "report": "spam", "message": "quota exhausted",
		}, map[string]string{
			"Idempotency-Key": "quota-report-limited",
			"X-Forwarded-For": forwardedIP + ", 127.0.0.1",
		})
		defer limited.Body.Close()
		if limited.StatusCode != http.StatusTooManyRequests {
			t.Fatalf("quota exhausted status = %d, want 429", limited.StatusCode)
		}
		var body genserver.ApiErrorDto
		if err := json.NewDecoder(limited.Body).Decode(&body); err != nil {
			t.Fatalf("decode quota error: %v", err)
		}
		if body.Code != "rate_limited" || body.RetryAfterSeconds == nil || *body.RetryAfterSeconds <= 0 {
			t.Fatalf("quota error body = %#v, want rate_limited with retry seconds", body)
		}
		retryAfter, err := strconv.Atoi(limited.Header.Get("Retry-After"))
		if err != nil || retryAfter <= 0 {
			t.Fatalf("Retry-After = %q, want positive integer", limited.Header.Get("Retry-After"))
		}
		if retryAfter != int(*body.RetryAfterSeconds) {
			t.Fatalf("Retry-After = %d, body retry seconds = %d", retryAfter, *body.RetryAfterSeconds)
		}
	})
}

func TestEndpointReportTargetFieldsRoute(t *testing.T) {
	srv, q := buildTestServerWithQuery(t)
	defer srv.Close()
	if _, err := q.Pool().Exec(context.Background(), `TRUNCATE TABLE rate_limit_buckets`); err != nil {
		t.Fatalf("truncate report quota buckets: %v", err)
	}

	anon := &apiClient{base: srv.URL}
	ar := anon.signup(t, "report-target-route", "pw123")
	reporterID := uuid.MustParse(ar.UserID)
	client := &apiClient{base: srv.URL, bearer: ar.AccessToken}
	targetID := reporterID
	explicitKind := "user"

	tests := []struct {
		name           string
		targetFields   map[string]any
		bodyUserID     string
		wantStatus     int
		wantStored     bool
		wantTargetID   *uuid.UUID
		wantTargetKind *string
	}{
		{name: "omitted", wantStatus: http.StatusOK, wantStored: true},
		{name: "explicit null", targetFields: map[string]any{"targetId": nil, "targetKind": nil}, wantStatus: http.StatusOK, wantStored: true},
		{name: "target id uses user default", targetFields: map[string]any{"targetId": ar.UserID}, wantStatus: http.StatusOK, wantStored: true, wantTargetID: &targetID},
		{name: "target id and kind", targetFields: map[string]any{"targetId": ar.UserID, "targetKind": explicitKind}, wantStatus: http.StatusOK, wantStored: true, wantTargetID: &targetID, wantTargetKind: &explicitKind},
		{name: "malformed target id", targetFields: map[string]any{"targetId": "not-a-uuid"}, wantStatus: http.StatusBadRequest},
		{name: "kind without target id", targetFields: map[string]any{"targetKind": explicitKind}, wantStatus: http.StatusBadRequest},
		{name: "control character target kind", targetFields: map[string]any{"targetId": ar.UserID, "targetKind": "pin\t"}, wantStatus: http.StatusBadRequest},
		{name: "forged body reporter", targetFields: map[string]any{"targetId": ar.UserID, "targetKind": explicitKind}, bodyUserID: uuid.NewString(), wantStatus: http.StatusForbidden},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			requestID := "route-target-" + strings.ReplaceAll(test.name, " ", "-")
			body := map[string]any{
				"userId":  ar.UserID,
				"report":  "route target report",
				"message": "route target details",
			}
			if test.bodyUserID != "" {
				body["userId"] = test.bodyUserID
			}
			for key, value := range test.targetFields {
				body[key] = value
			}

			resp := client.doWithHeaders(t, http.MethodPost, "/api/v2/report", body, map[string]string{"Idempotency-Key": requestID})
			resp.Body.Close()
			if resp.StatusCode != test.wantStatus {
				t.Fatalf("report status = %d, want %d", resp.StatusCode, test.wantStatus)
			}

			stored, err := q.GetReportByRequestID(context.Background(), requestID)
			if err != nil {
				t.Fatalf("get routed report: %v", err)
			}
			if !test.wantStored {
				if stored != nil {
					t.Fatalf("stored report = %#v, want no row", stored)
				}
				return
			}
			if stored == nil {
				t.Fatal("stored report is nil")
			}
			if stored.ReporterUserID == nil || *stored.ReporterUserID != reporterID {
				t.Fatalf("stored reporter = %#v, want authenticated user %s", stored.ReporterUserID, reporterID)
			}
			if test.wantTargetID == nil {
				if stored.TargetID != nil {
					t.Fatalf("stored target id = %v, want nil", stored.TargetID)
				}
			} else if stored.TargetID == nil || *stored.TargetID != *test.wantTargetID {
				t.Fatalf("stored target id = %v, want %s", stored.TargetID, *test.wantTargetID)
			}
			if test.wantTargetKind == nil {
				if stored.TargetKind != nil {
					t.Fatalf("stored target kind = %v, want nil", stored.TargetKind)
				}
			} else if stored.TargetKind == nil || *stored.TargetKind != *test.wantTargetKind {
				t.Fatalf("stored target kind = %v, want %q", stored.TargetKind, *test.wantTargetKind)
			}
		})
	}
}

func reportQuotaIdentifierHMAC(key []byte, scope, value string) []byte {
	h := hmac.New(sha256.New, key)
	_, _ = h.Write([]byte(scope + "\x00" + value))
	return h.Sum(nil)
}
