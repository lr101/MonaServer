package handler

import (
	"context"
	"crypto/rand"
	"fmt"
	"math/big"
	"net/http"
	"time"

	"github.com/google/uuid"

	"github.com/lrprojects/monaserver/internal/db"
	genserver "github.com/lrprojects/monaserver/internal/gen/server"
	"github.com/lrprojects/monaserver/internal/service"
)

// AuthServicer implements genserver.AuthAPIServicer.
type AuthServicer struct {
	auth          *service.Auth
	q             *db.Queries
	mail          *service.Email
	minioEndpoint string
}

func NewAuthServicer(auth *service.Auth, q *db.Queries, mail *service.Email, minioEndpoint string) *AuthServicer {
	return &AuthServicer{auth: auth, q: q, mail: mail, minioEndpoint: minioEndpoint}
}

func (s *AuthServicer) GenerateDeleteCode(ctx context.Context, username string) (genserver.ImplResponse, error) {
	u, err := s.q.GetUserByUsername(ctx, username)
	if err != nil || u == nil {
		return genserver.Response(http.StatusNotFound, nil), nil
	}
	if u.Email == nil {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	url := randomAlphaStr(32)
	code := randomDeleteCode()
	exp := time.Now().Add(24 * time.Hour)
	// The 6-digit code is what the app and the web delete page actually submit
	// (validated in User.Delete); the deletion URL backs the web confirmation page.
	if err := s.q.SetUserRecoveryCode(ctx, u.ID, code, exp); err != nil {
		return genserver.Response(http.StatusInternalServerError, nil), nil
	}
	if err := s.q.SetUserDeletionUrl(ctx, u.ID, url, exp); err != nil {
		return genserver.Response(http.StatusInternalServerError, nil), nil
	}
	username, email := u.Username, *u.Email
	sendMailAsync(func(c context.Context) error {
		return s.mail.SendDeleteAccount(c, username, email, url, code)
	})
	return genserver.Response(http.StatusOK, nil), nil
}

// sendMailAsync runs a mail send off the request path so a slow SMTP server
// cannot delay — or time out — the HTTP response. Errors are best-effort,
// matching the previous synchronous behaviour (they were already ignored).
func sendMailAsync(send func(context.Context) error) {
	go func() {
		ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer cancel()
		_ = send(ctx)
	}()
}

// randomDeleteCode returns a cryptographically random 6-digit, zero-padded code.
// The format matches User.Delete's itoaCode comparison.
func randomDeleteCode() string {
	n, err := rand.Int(rand.Reader, big.NewInt(1000000))
	if err != nil {
		return fmt.Sprintf("%06d", time.Now().UnixNano()%1000000)
	}
	return fmt.Sprintf("%06d", n.Int64())
}

func (s *AuthServicer) RequestPasswordRecovery(ctx context.Context, username string) (genserver.ImplResponse, error) {
	u, err := s.q.GetUserByUsername(ctx, username)
	if err != nil || u == nil {
		return genserver.Response(http.StatusOK, nil), nil // silently succeed
	}
	if u.Email == nil {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	url := randomAlphaStr(32)
	exp := time.Now().Add(24 * time.Hour)
	if err := s.q.SetUserResetPasswordUrl(ctx, u.ID, url, exp); err != nil {
		return genserver.Response(http.StatusInternalServerError, nil), nil
	}
	username, email := u.Username, *u.Email
	sendMailAsync(func(c context.Context) error {
		return s.mail.SendPasswordRecovery(c, username, email, url)
	})
	return genserver.Response(http.StatusOK, nil), nil
}

func (s *AuthServicer) UserLogin(_ context.Context, req genserver.UserLoginRequest) (genserver.ImplResponse, error) {
	pair, err := s.auth.Login(context.Background(), req.Username, req.Password)
	if err != nil {
		return serviceErrResp(err), nil
	}
	return genserver.Response(http.StatusOK, toTokenResponseDto(pair)), nil
}

func (s *AuthServicer) CreateUser(_ context.Context, req genserver.UserRequestDto) (genserver.ImplResponse, error) {
	var email *string
	if req.Email != "" {
		e := req.Email
		email = &e
	}
	pair, err := s.auth.Signup(context.Background(), req.Name, req.Password, email)
	if err != nil {
		return serviceErrResp(err), nil
	}
	return genserver.Response(http.StatusCreated, toTokenResponseDto(pair)), nil
}

func (s *AuthServicer) RefreshToken(_ context.Context, req genserver.RefreshTokenRequestDto) (genserver.ImplResponse, error) {
	tok, err := uuid.Parse(req.RefreshToken)
	if err != nil {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	pair, err := s.auth.Refresh(context.Background(), tok)
	if err != nil {
		return serviceErrResp(err), nil
	}
	return genserver.Response(http.StatusOK, toTokenResponseDto(pair)), nil
}

func (s *AuthServicer) GetStatus(_ context.Context) (genserver.ImplResponse, error) {
	return genserver.Response(http.StatusOK, genserver.Status{
		Notifications: []string{},
		MinioEndpoint: s.minioEndpoint,
		TokenValidity: time.Now().Add(time.Hour),
	}), nil
}
