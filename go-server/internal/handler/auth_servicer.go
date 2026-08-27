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

const accountActionExpiry = 10 * time.Minute

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
	exp := time.Now().Add(accountActionExpiry)
	// The 6-digit code is what the app and the web delete page actually submit
	// (validated in User.Delete); the deletion URL backs the web confirmation page.
	if s.mail == nil {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	if err := s.q.InTx(ctx, func(q *db.Queries) error {
		if err := q.SetUserRecoveryCode(ctx, u.ID, code, exp); err != nil {
			return err
		}
		if err := q.SetUserDeletionUrl(ctx, u.ID, url, exp); err != nil {
			return err
		}
		return s.mail.SendDeleteAccount(ctx, u.Username, *u.Email, url, code)
	}); err != nil {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	return genserver.Response(http.StatusOK, nil), nil
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
		return genserver.Response(http.StatusNotFound, nil), nil
	}
	if u.Email == nil {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	url := randomAlphaStr(32)
	exp := time.Now().Add(accountActionExpiry)
	if s.mail == nil {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	if err := s.q.InTx(ctx, func(q *db.Queries) error {
		if err := q.SetUserResetPasswordUrl(ctx, u.ID, url, exp); err != nil {
			return err
		}
		return s.mail.SendPasswordRecovery(ctx, u.Username, *u.Email, url)
	}); err != nil {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	return genserver.Response(http.StatusOK, nil), nil
}

func (s *AuthServicer) UserLogin(ctx context.Context, req genserver.UserLoginRequest) (genserver.ImplResponse, error) {
	pair, err := s.auth.Login(ctx, req.Username, req.Password)
	if err != nil {
		return serviceErrResp(err), nil
	}
	return genserver.Response(http.StatusOK, toTokenResponseDto(pair)), nil
}

func (s *AuthServicer) CreateUser(ctx context.Context, req genserver.UserRequestDto) (genserver.ImplResponse, error) {
	var email *string
	if req.Email != "" {
		e := req.Email
		email = &e
	}
	pair, err := s.auth.Signup(ctx, req.Name, req.Password, email)
	if err != nil {
		return serviceErrResp(err), nil
	}
	return genserver.Response(http.StatusCreated, toTokenResponseDto(pair)), nil
}

func (s *AuthServicer) RefreshToken(ctx context.Context, req genserver.RefreshTokenRequestDto) (genserver.ImplResponse, error) {
	tok, err := uuid.Parse(req.RefreshToken)
	if err != nil {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	uid, err := uuid.Parse(req.UserId)
	if err != nil {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	pair, err := s.auth.Refresh(ctx, tok, uid)
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
