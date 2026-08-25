package service

import (
	"context"
	"fmt"
	"net/http"
	"time"

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
	q    *db.Queries
	tok  *token.Helper
	cfg  *config.Config
	mail *Email
}

func NewAuth(q *db.Queries, tok *token.Helper, cfg *config.Config, mail ...*Email) *Auth {
	var email *Email
	if len(mail) > 0 {
		email = mail[0]
	}
	return &Auth{q: q, tok: tok, cfg: cfg, mail: email}
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
	var confirmationURL *string
	if email != nil {
		url := randomAlpha(32)
		confirmationURL = &url
	}
	var pair *TokenPair
	if err := s.q.InTx(ctx, func(q *db.Queries) error {
		uid, err := q.CreateUser(ctx, username, hash, email, confirmationURL)
		if err != nil {
			return err
		}
		if s.mail != nil && email != nil && confirmationURL != nil {
			if err := s.mail.SendEmailConfirmation(ctx, username, *email, *confirmationURL); err != nil {
				return err
			}
		}
		pair, err = s.issueTokensWithQueries(ctx, q, uid)
		return err
	}); err != nil {
		return nil, err
	}
	return pair, nil
}

func (s *Auth) Login(ctx context.Context, username, plainPW string) (*TokenPair, error) {
	u, err := s.q.GetUserByUsername(ctx, username)
	if err != nil {
		return nil, err
	}
	if u == nil {
		return nil, apperrors.New(http.StatusBadRequest, "wrong password or user does not exist")
	}
	if u.FailedLoginAttempts >= s.cfg.MaxLoginAttempts {
		return nil, apperrors.New(403, "account locked")
	}
	if !password.Verify(u.Password, plainPW) {
		_ = s.q.IncrementFailedLogin(ctx, u.ID)
		return nil, apperrors.New(400, "wrong password")
	}
	if password.NeedsUpgrade(u.Password) {
		hash, err := password.Hash(plainPW)
		if err != nil {
			return nil, err
		}
		if err := s.q.UpdateUserPassword(ctx, u.ID, hash); err != nil {
			return nil, err
		}
	} else if err := s.q.ResetFailedLogin(ctx, u.ID); err != nil {
		return nil, err
	}
	return s.issueTokens(ctx, u.ID)
}

func (s *Auth) Refresh(ctx context.Context, refresh, userID uuid.UUID) (*TokenPair, error) {
	stored, err := s.q.FindRefreshToken(ctx, refresh)
	if err != nil {
		return nil, apperrors.ErrBadRequest
	}
	if stored.UserID != userID {
		return nil, apperrors.ErrBadRequest
	}
	expiry := s.cfg.RefreshTokenExpiry
	if expiry <= 0 {
		expiry = 365 * 24 * time.Hour
	}
	if stored.LastActiveDate.Add(expiry).Before(time.Now()) {
		if err := s.q.DeleteRefreshToken(ctx, refresh); err != nil {
			return nil, err
		}
		return nil, apperrors.New(http.StatusBadRequest, "refresh token expired")
	}
	if err := s.q.TouchRefreshToken(ctx, refresh); err != nil {
		return nil, err
	}
	access, err := s.tok.GenerateAccessToken(stored.UserID)
	if err != nil {
		return nil, err
	}
	return &TokenPair{AccessToken: access, RefreshToken: refresh, UserID: stored.UserID}, nil
}

func (s *Auth) issueTokens(ctx context.Context, uid uuid.UUID) (*TokenPair, error) {
	return s.issueTokensWithQueries(ctx, s.q, uid)
}

func (s *Auth) issueTokensWithQueries(ctx context.Context, q *db.Queries, uid uuid.UUID) (*TokenPair, error) {
	access, err := s.tok.GenerateAccessToken(uid)
	if err != nil {
		return nil, fmt.Errorf("sign: %w", err)
	}
	refresh, err := q.CreateRefreshToken(ctx, uid)
	if err != nil {
		return nil, err
	}
	return &TokenPair{AccessToken: access, RefreshToken: refresh, UserID: uid}, nil
}

// GetUsername implements middleware.UserLookup.
func (s *Auth) GetUsername(ctx context.Context, id uuid.UUID) (string, error) {
	return s.q.GetUsernameByID(ctx, id)
}
