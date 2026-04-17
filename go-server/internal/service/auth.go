package service

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/lrprojects/monaserver/internal/apperrors"
	"github.com/lrprojects/monaserver/internal/config"
	"github.com/lrprojects/monaserver/internal/db"
	"github.com/lrprojects/monaserver/internal/password"
	"github.com/lrprojects/monaserver/internal/token"
)

type TokenPair struct {
	AccessToken  string    `json:"accessToken"`
	RefreshToken uuid.UUID `json:"refreshToken"`
	UserID       uuid.UUID `json:"userId"`
}

type Auth struct {
	q   *db.Queries
	tok *token.Helper
	cfg *config.Config
}

func NewAuth(q *db.Queries, tok *token.Helper, cfg *config.Config) *Auth {
	return &Auth{q: q, tok: tok, cfg: cfg}
}

func (s *Auth) Signup(ctx context.Context, username, plainPW string, email *string) (*TokenPair, error) {
	existing, err := s.q.GetUserByUsername(ctx, username)
	if err != nil {
		return nil, err
	}
	if existing != nil {
		return nil, apperrors.New(409, "username already exists")
	}
	hash, err := password.Hash(plainPW)
	if err != nil {
		return nil, err
	}
	uid, err := s.q.CreateUser(ctx, username, hash, email)
	if err != nil {
		return nil, err
	}
	return s.issueTokens(ctx, uid)
}

func (s *Auth) Login(ctx context.Context, username, plainPW string) (*TokenPair, error) {
	u, err := s.q.GetUserByUsername(ctx, username)
	if err != nil {
		return nil, err
	}
	if u == nil {
		return nil, apperrors.ErrNotFound
	}
	if u.FailedLoginAttempts >= s.cfg.MaxLoginAttempts {
		return nil, apperrors.New(403, "account locked")
	}
	if !password.Verify(u.Password, plainPW) {
		_ = s.q.IncrementFailedLogin(ctx, u.ID)
		return nil, apperrors.New(400, "wrong password")
	}
	_ = s.q.ResetFailedLogin(ctx, u.ID)
	return s.issueTokens(ctx, u.ID)
}

func (s *Auth) Refresh(ctx context.Context, refresh uuid.UUID) (*TokenPair, error) {
	uid, err := s.q.FindRefreshToken(ctx, refresh)
	if err != nil {
		return nil, apperrors.ErrUnauthorized
	}
	if err := s.q.TouchRefreshToken(ctx, refresh); err != nil {
		return nil, err
	}
	access, err := s.tok.GenerateAccessToken(uid)
	if err != nil {
		return nil, err
	}
	return &TokenPair{AccessToken: access, RefreshToken: refresh, UserID: uid}, nil
}

func (s *Auth) issueTokens(ctx context.Context, uid uuid.UUID) (*TokenPair, error) {
	access, err := s.tok.GenerateAccessToken(uid)
	if err != nil {
		return nil, fmt.Errorf("sign: %w", err)
	}
	refresh, err := s.q.CreateRefreshToken(ctx, uid)
	if err != nil {
		return nil, err
	}
	return &TokenPair{AccessToken: access, RefreshToken: refresh, UserID: uid}, nil
}

// GetUsername implements middleware.UserLookup.
func (s *Auth) GetUsername(ctx context.Context, id uuid.UUID) (string, error) {
	return s.q.GetUsernameByID(ctx, id)
}
