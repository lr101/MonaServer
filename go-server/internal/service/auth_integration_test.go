package service

import (
	"bufio"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"net"
	"os"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/lrprojects/monaserver/internal/apperrors"
	"github.com/lrprojects/monaserver/internal/config"
	"github.com/lrprojects/monaserver/internal/db"
	"github.com/lrprojects/monaserver/internal/token"
)

func TestLoginUpgradesLegacyPasswordHash(t *testing.T) {
	q, auth, _, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	pair, err := auth.Signup(ctx, "legacy_password_user", "password123", nil)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}
	sum := sha256.Sum256([]byte("password123"))
	legacy := hex.EncodeToString(sum[:])
	if _, err := q.Pool().Exec(ctx, `UPDATE users SET password = $2 WHERE id = $1`, pair.UserID, legacy); err != nil {
		t.Fatalf("store legacy password: %v", err)
	}
	if _, err := auth.Login(ctx, "legacy_password_user", "password123"); err != nil {
		t.Fatalf("login with legacy password: %v", err)
	}
	stored, err := q.GetUserByID(ctx, pair.UserID)
	if err != nil {
		t.Fatalf("get upgraded user: %v", err)
	}
	if !strings.HasPrefix(stored.Password, "{bcrypt}$2") {
		t.Fatalf("password hash was not upgraded: %q", stored.Password)
	}
}

func testDSN(t *testing.T) string {
	dsn := os.Getenv("TEST_DATABASE_URL")
	if dsn == "" {
		t.Skip("TEST_DATABASE_URL not set; skipping integration test")
	}
	return dsn
}

func setup(t *testing.T) *Auth {
	t.Helper()
	dsn := testDSN(t)
	if err := db.RunMigrations(dsn); err != nil {
		t.Fatalf("migrations: %v", err)
	}
	pool, err := db.NewPool(context.Background(), dsn)
	if err != nil {
		t.Fatalf("pool: %v", err)
	}
	t.Cleanup(pool.Close)
	// reset users/refresh tables between tests
	if _, err := pool.Exec(context.Background(), `TRUNCATE TABLE refresh_token, users CASCADE`); err != nil {
		t.Fatalf("truncate: %v", err)
	}
	q := db.New(pool)
	tok := token.NewHelper("test-secret", time.Minute)
	cfg := &config.Config{MaxLoginAttempts: 5, RefreshTokenExpiry: time.Hour}
	return NewAuth(q, tok, cfg)
}

func TestAuthSignupLoginRefresh(t *testing.T) {
	svc := setup(t)
	ctx := context.Background()

	pair, err := svc.Signup(ctx, "alice", "pw12345", nil)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}
	if pair.AccessToken == "" || pair.RefreshToken.String() == "" {
		t.Fatal("empty tokens")
	}

	// duplicate username -> conflict
	if _, err := svc.Signup(ctx, "alice", "pw", nil); err == nil {
		t.Fatal("expected duplicate username error")
	}

	// login
	lp, err := svc.Login(ctx, "alice", "pw12345")
	if err != nil {
		t.Fatalf("login: %v", err)
	}
	if lp.UserID != pair.UserID {
		t.Fatalf("user id mismatch: %v vs %v", lp.UserID, pair.UserID)
	}

	// wrong password
	if _, err := svc.Login(ctx, "alice", "bad"); err == nil {
		t.Fatal("expected wrong password error")
	}

	// refresh
	rp, err := svc.Refresh(ctx, pair.RefreshToken, pair.UserID)
	if err != nil {
		t.Fatalf("refresh: %v", err)
	}
	if rp.UserID != pair.UserID {
		t.Fatalf("refresh user id mismatch")
	}

	// GetUsername works for JWT middleware path
	name, err := svc.GetUsername(ctx, pair.UserID)
	if err != nil {
		t.Fatalf("getusername: %v", err)
	}
	if name != "alice" {
		t.Fatalf("got %q", name)
	}
}

func TestRefreshTokenSurvivesEphemeralAccessKeyRotation(t *testing.T) {
	_, q := setupPool(t)
	oldKey, err := token.NewEphemeralHelper(time.Minute)
	if err != nil {
		t.Fatalf("generate initial signing key: %v", err)
	}
	newKey, err := token.NewEphemeralHelper(time.Minute)
	if err != nil {
		t.Fatalf("generate restarted signing key: %v", err)
	}
	cfg := &config.Config{MaxLoginAttempts: 5, RefreshTokenExpiry: time.Hour}
	ctx := context.Background()

	beforeRestart := NewAuth(q, oldKey, cfg)
	pair, err := beforeRestart.Signup(ctx, "key_rotation_user", "pw12345", nil)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}
	if _, err := newKey.ParseAccessToken(pair.AccessToken); err == nil {
		t.Fatal("new signing key accepted an access token from before restart")
	}

	afterRestart := NewAuth(q, newKey, cfg)
	refreshed, err := afterRestart.Refresh(ctx, pair.RefreshToken, pair.UserID)
	if err != nil {
		t.Fatalf("refresh with rotated access key: %v", err)
	}
	if refreshed.RefreshToken != pair.RefreshToken {
		t.Fatal("refresh unexpectedly rotated the stored refresh credential")
	}
	if userID, err := newKey.ParseAccessToken(refreshed.AccessToken); err != nil || userID != pair.UserID {
		t.Fatalf("new access token = %v, %v; want user %s", userID, err, pair.UserID)
	}
	if _, err := q.FindRefreshToken(ctx, pair.RefreshToken); err != nil {
		t.Fatalf("refresh token was not retained in the database: %v", err)
	}
}

func TestRefreshRejectsAndDeletesExpiredToken(t *testing.T) {
	q, auth, _, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	pair, err := auth.Signup(ctx, "expired_refresh", "pw12345", nil)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}
	if _, err := q.Pool().Exec(ctx,
		`UPDATE refresh_token SET last_active_date = NOW() - INTERVAL '2 hours' WHERE token = $1`,
		pair.RefreshToken,
	); err != nil {
		t.Fatalf("age refresh token: %v", err)
	}

	if _, err := auth.Refresh(ctx, pair.RefreshToken, pair.UserID); err == nil {
		t.Fatal("expired refresh token should be rejected")
	} else if got := apperrors.HTTPStatus(err); got != 410 {
		t.Fatalf("expired refresh token status = %d, want 410", got)
	} else if got := apperrors.Message(err); got != "refresh token expired" {
		t.Fatalf("expired refresh token message = %q, want token-expired marker", got)
	}
	var count int
	if err := q.Pool().QueryRow(ctx,
		`SELECT COUNT(*) FROM refresh_token WHERE token = $1`, pair.RefreshToken,
	).Scan(&count); err != nil {
		t.Fatalf("count refresh token: %v", err)
	}
	if count != 0 {
		t.Fatalf("expired refresh token still exists, count = %d", count)
	}
}

func TestSignupCreatesEmailConfirmationToken(t *testing.T) {
	q, auth, _, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	email := "new-user@example.com"
	pair, err := auth.Signup(ctx, "confirmation_user", "password123", &email)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}
	user, err := q.GetUserByID(ctx, pair.UserID)
	if err != nil {
		t.Fatalf("get user: %v", err)
	}
	if user.EmailConfirmationUrl == nil || *user.EmailConfirmationUrl == "" {
		t.Fatal("signup did not create an email confirmation token")
	}
	if user.EmailConfirmed {
		t.Fatal("new signup should remain unconfirmed until the confirmation link is used")
	}
}

func TestPendingSignupAccessAndResendCooldownRotation(t *testing.T) {
	q, _, _, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	host, port := startServiceTestSMTP(t)
	cfg := &config.Config{MailHost: host, MailPort: port, MailUsername: "sender@example.com", MailPassword: "test", MailFrom: "sender@example.com", WebHost: "app.example.com", MaxLoginAttempts: 5, RefreshTokenExpiry: time.Hour}
	tok := token.NewHelper("test-secret", time.Minute)
	auth := NewAuth(q, tok, cfg, NewEmail(cfg, nil))
	originalEmail := "pending@example.com"
	pair, err := auth.Signup(ctx, "pending_signup", "password123", &originalEmail)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}
	if _, err := auth.Login(ctx, "pending_signup", "password123"); err == nil {
		t.Fatal("pending account login should be rejected")
	}
	if _, err := auth.Refresh(ctx, pair.RefreshToken, pair.UserID); err == nil {
		t.Fatal("pending account refresh should be rejected")
	}

	correctedEmail := "corrected@example.com"
	if _, err := auth.Signup(ctx, "pending_signup", "wrong-password", &correctedEmail); err == nil {
		t.Fatal("resend with wrong password should be rejected")
	}
	user, err := q.GetUserByID(ctx, pair.UserID)
	if err != nil {
		t.Fatalf("get user after wrong password: %v", err)
	}
	if user.Email == nil || *user.Email != originalEmail {
		t.Fatalf("email after wrong password = %v, want %q", user.Email, originalEmail)
	}

	if _, err := auth.Signup(ctx, "pending_signup", "password123", &correctedEmail); err == nil {
		t.Fatal("resend during cooldown should be rejected")
	}
	user, err = q.GetUserByID(ctx, pair.UserID)
	if err != nil {
		t.Fatalf("get user during cooldown: %v", err)
	}
	if user.Email == nil || *user.Email != originalEmail {
		t.Fatalf("email during cooldown = %v, want %q", user.Email, originalEmail)
	}
	if _, err := q.FindRefreshToken(ctx, pair.RefreshToken); err != nil {
		t.Fatalf("cooldown changed original refresh token: %v", err)
	}

	if _, err := q.Pool().Exec(ctx, `UPDATE users SET email_confirmation_sent_at = NOW() - INTERVAL '6 minutes' WHERE id = $1`, pair.UserID); err != nil {
		t.Fatalf("age confirmation send timestamp: %v", err)
	}
	rotated, err := auth.Signup(ctx, "pending_signup", "password123", &correctedEmail)
	if err != nil {
		t.Fatalf("resend after cooldown: %v", err)
	}
	if rotated.RefreshToken == pair.RefreshToken {
		t.Fatal("successful resend did not rotate the refresh token")
	}
	if _, err := q.FindRefreshToken(ctx, pair.RefreshToken); err == nil {
		t.Fatal("old refresh token remains valid after resend")
	}
	if _, err := q.FindRefreshToken(ctx, rotated.RefreshToken); err != nil {
		t.Fatalf("new refresh token missing: %v", err)
	}
	var refreshCount int
	if err := q.Pool().QueryRow(ctx, `SELECT COUNT(*) FROM refresh_token WHERE user_id = $1`, pair.UserID).Scan(&refreshCount); err != nil {
		t.Fatalf("count refresh tokens: %v", err)
	}
	if refreshCount != 1 {
		t.Fatalf("refresh token count = %d, want exactly one", refreshCount)
	}
	user, err = q.GetUserByID(ctx, pair.UserID)
	if err != nil {
		t.Fatalf("get user after resend: %v", err)
	}
	if user.Email == nil || *user.Email != correctedEmail {
		t.Fatalf("email after resend = %v, want %q", user.Email, correctedEmail)
	}
	if user.EmailConfirmed {
		t.Fatal("resend should leave account pending confirmation")
	}
	if user.EmailConfirmationUrl == nil || *user.EmailConfirmationUrl == "" {
		t.Fatal("resend did not issue a new confirmation token")
	}
	if _, err := auth.Refresh(ctx, rotated.RefreshToken, rotated.UserID); err == nil {
		t.Fatal("new refresh token should remain blocked until confirmation")
	}
}

func startServiceTestSMTP(t *testing.T) (string, int) {
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
			go func(conn net.Conn) {
				defer conn.Close()
				r, w := bufio.NewReader(conn), bufio.NewWriter(conn)
				write := func(s string) { _, _ = w.WriteString(s + "\r\n"); _ = w.Flush() }
				write("220 localhost ESMTP")
				for {
					line, err := r.ReadString('\n')
					if err != nil {
						return
					}
					command := strings.TrimSpace(line)
					switch {
					case strings.HasPrefix(command, "EHLO"), strings.HasPrefix(command, "HELO"):
						_, _ = w.WriteString("250-localhost\r\n250 AUTH PLAIN\r\n")
						_ = w.Flush()
					case strings.HasPrefix(command, "AUTH"):
						write("235 authenticated")
					case command == "DATA":
						write("354 continue")
						for {
							data, err := r.ReadString('\n')
							if err != nil {
								return
							}
							if strings.TrimSpace(data) == "." {
								break
							}
						}
						write("250 queued")
					case command == "QUIT":
						write("221 bye")
						return
					default:
						write("250 OK")
					}
				}
			}(conn)
		}
	}()
	return host, port
}

func serviceTestEmail(t *testing.T) *Email {
	t.Helper()
	host, port := startServiceTestSMTP(t)
	cfg := &config.Config{MailHost: host, MailPort: port, MailUsername: "sender@example.com", MailPassword: "test", MailFrom: "sender@example.com", WebHost: "app.example.com"}
	return NewEmail(cfg, nil)
}

func TestSignupRollsBackWhenConfirmationMailFails(t *testing.T) {
	q, _, _, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	failingMail := NewEmail(&config.Config{
		MailHost: "127.0.0.1", MailPort: 1, MailUsername: "sender@example.com",
		MailPassword: "password", MailFrom: "sender@example.com", WebHost: "app.example.com",
	}, nil)
	auth := NewAuth(q, token.NewHelper("test-secret", time.Minute), &config.Config{
		MaxLoginAttempts: 5, RefreshTokenExpiry: time.Hour,
	}, failingMail)
	email := "failed-signup@example.com"
	if _, err := auth.Signup(ctx, "failed_signup", "password123", &email); err == nil {
		t.Fatal("signup should fail when the confirmation email cannot be sent")
	}
	stored, err := q.GetUserByUsername(ctx, "failed_signup")
	if err != nil {
		t.Fatalf("look up failed signup: %v", err)
	}
	if stored != nil {
		t.Fatal("failed signup left a user row behind")
	}
}
