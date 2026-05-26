package handler

import (
	"context"
	"net/http"
	"time"

	"github.com/google/uuid"

	"github.com/lrprojects/monaserver/internal/apperrors"
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
	baseURL       string
}

func NewAuthServicer(auth *service.Auth, q *db.Queries, mail *service.Email, minioEndpoint, baseURL string) *AuthServicer {
	return &AuthServicer{auth: auth, q: q, mail: mail, minioEndpoint: minioEndpoint, baseURL: baseURL}
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
	exp := time.Now().Add(24 * time.Hour)
	if err := s.q.SetUserDeletionUrl(ctx, u.ID, url, exp); err != nil {
		return genserver.Response(http.StatusInternalServerError, nil), nil
	}
	deleteURL := s.baseURL + "/public/delete-account/" + url
	_ = s.mail.SendDeleteAccount(ctx, u.Username, *u.Email, deleteURL, "")
	return genserver.Response(http.StatusOK, nil), nil
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
	resetURL := s.baseURL + "/public/recover/" + url
	_ = s.mail.SendPasswordRecovery(ctx, u.Username, *u.Email, resetURL)
	return genserver.Response(http.StatusOK, nil), nil
}

func (s *AuthServicer) UserLogin(_ context.Context, req genserver.UserLoginRequest) (genserver.ImplResponse, error) {
	pair, err := s.auth.Login(context.Background(), req.Username, req.Password)
	if err != nil {
		return genserver.Response(apperrors.HTTPStatus(err), nil), nil
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
		return genserver.Response(apperrors.HTTPStatus(err), nil), nil
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
		return genserver.Response(apperrors.HTTPStatus(err), nil), nil
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
