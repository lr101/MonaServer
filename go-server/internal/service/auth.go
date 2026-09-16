package service

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/lrprojects/monaserver/internal/apperrors"
	"github.com/lrprojects/monaserver/internal/config"
	"github.com/lrprojects/monaserver/internal/db"
	"github.com/lrprojects/monaserver/internal/middleware"
	"github.com/lrprojects/monaserver/internal/password"
	"github.com/lrprojects/monaserver/internal/token"
)

type TokenPair struct {
	AccessToken  string    `json:"accessToken"`
	RefreshToken uuid.UUID `json:"refreshToken"`
	UserID       uuid.UUID `json:"userId"`
}

type Auth struct {
	q        *db.Queries
	tok      *token.Helper
	cfg      *config.Config
	mail     *Email
	security *AccountSecurity
}

func NewAuth(q *db.Queries, tok *token.Helper, cfg *config.Config, mail ...*Email) *Auth {
	var email *Email
	if len(mail) > 0 {
		email = mail[0]
	}
	return &Auth{q: q, tok: tok, cfg: cfg, mail: email, security: NewAccountSecurity(q)}
}

// Security exposes the shared account-security coordinator for composition
// code and services that need to share the same recovery enqueue port.
func (s *Auth) Security() *AccountSecurity {
	if s.security == nil {
		s.security = NewAccountSecurity(s.q)
	}
	return s.security
}

// SetSecurity replaces the coordinator used by all credential flows. It is a
// composition hook for the durable recovery adapter and test doubles.
func (s *Auth) SetSecurity(security *AccountSecurity) {
	if security == nil {
		security = NewAccountSecurity(s.q)
	}
	s.security = security
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
		pair, err = s.Security().IssueTokens(ctx, q, s.tok, uid)
		return err
	}); err != nil {
		return nil, err
	}
	return pair, nil
}

func (s *Auth) Login(ctx context.Context, username, plainPW string) (*TokenPair, error) {
	var pair *TokenPair
	var authErr error
	err := s.q.InTxRetry(ctx, func(q *db.Queries) error {
		candidate, err := q.GetUserByUsername(ctx, username)
		if err != nil {
			return err
		}
		if candidate == nil {
			authErr = apperrors.New(http.StatusBadRequest, "wrong password or user does not exist")
			return nil
		}
		state, err := q.LockUserSecurity(ctx, candidate.ID)
		if err != nil {
			return err
		}
		if state == nil || state.IsDeleted {
			authErr = apperrors.New(http.StatusBadRequest, "wrong password or user does not exist")
			return nil
		}
		// Read the full row after acquiring the lock. The first username read
		// may have used a snapshot from before a concurrent password or
		// containment mutation.
		u, err := q.GetUserByID(ctx, candidate.ID)
		if err != nil {
			return err
		}
		if u == nil {
			authErr = apperrors.New(http.StatusBadRequest, "wrong password or user does not exist")
			return nil
		}
		maxAttempts := 10
		if s.cfg != nil && s.cfg.MaxLoginAttempts > 0 {
			maxAttempts = s.cfg.MaxLoginAttempts
		}
		if u.FailedLoginAttempts >= maxAttempts {
			authErr = apperrors.New(http.StatusForbidden, "account locked")
			return nil
		}
		if u.PasswordDisabled || u.PasswordResetRequired || u.SecurityState != db.SecurityStateNormal {
			authErr = apperrors.New(http.StatusForbidden, "account locked")
			return nil
		}
		if !password.Verify(u.Password, plainPW) {
			if err := q.IncrementFailedLogin(ctx, u.ID); err != nil {
				return err
			}
			authErr = apperrors.New(http.StatusBadRequest, "wrong password")
			return nil
		}
		if password.NeedsUpgrade(u.Password) {
			hash, err := password.Hash(plainPW)
			if err != nil {
				return err
			}
			if err := q.UpdateUserPassword(ctx, u.ID, hash); err != nil {
				return err
			}
		} else if err := q.ResetFailedLogin(ctx, u.ID); err != nil {
			return err
		}
		pair, err = s.Security().IssueTokens(ctx, q, s.tok, u.ID)
		return err
	})
	if err != nil {
		return nil, err
	}
	if authErr != nil {
		return nil, authErr
	}
	return pair, nil
}

func (s *Auth) Refresh(ctx context.Context, refresh, userID uuid.UUID) (*TokenPair, error) {
	if userID == uuid.Nil || refresh == uuid.Nil {
		return nil, apperrors.ErrBadRequest
	}
	var pair *TokenPair
	var refreshErr error
	err := s.q.InTxRetry(ctx, func(q *db.Queries) error {
		state, err := q.LockUserSecurity(ctx, userID)
		if err != nil {
			return err
		}
		if state == nil || state.IsDeleted || state.PasswordDisabled || state.PasswordResetRequired || state.SecurityState != db.SecurityStateNormal {
			refreshErr = apperrors.ErrBadRequest
			return nil
		}
		stored, err := q.FindRefreshToken(ctx, refresh)
		if err != nil {
			if mapped, handled := classifyRefreshLookupError(err); handled {
				refreshErr = mapped
				return nil
			}
			return err
		}
		if stored == nil || stored.UserID != userID {
			refreshErr = apperrors.ErrBadRequest
			return nil
		}
		expiry := 365 * 24 * time.Hour
		if s.cfg != nil && s.cfg.RefreshTokenExpiry > 0 {
			expiry = s.cfg.RefreshTokenExpiry
		}
		now := time.Now()
		if stored.LastActiveDate.Add(expiry).Before(now) {
			if err := q.DeleteRefreshToken(ctx, refresh); err != nil {
				return err
			}
			refreshErr = apperrors.New(http.StatusBadRequest, "refresh token expired")
			return nil
		}
		if err := q.TouchRefreshToken(ctx, refresh); err != nil {
			return err
		}
		access, err := s.tok.GenerateAccessTokenWithGeneration(userID, state.AuthGeneration)
		if err != nil {
			return err
		}
		pair = &TokenPair{AccessToken: access, RefreshToken: refresh, UserID: userID}
		return nil
	})
	if err != nil {
		return nil, err
	}
	if refreshErr != nil {
		return nil, refreshErr
	}
	return pair, nil
}

// classifyRefreshLookupError preserves the v2 compatibility response only for
// an absent credential. Infrastructure and transaction errors must propagate so
// callers do not misreport an unavailable database as malformed input.
func classifyRefreshLookupError(err error) (error, bool) {
	if errors.Is(err, pgx.ErrNoRows) {
		return apperrors.ErrBadRequest, true
	}
	return err, false
}

func (s *Auth) issueTokens(ctx context.Context, uid uuid.UUID) (*TokenPair, error) {
	return s.issueTokensWithQueries(ctx, s.q, uid)
}

func (s *Auth) issueTokensWithQueries(ctx context.Context, q *db.Queries, uid uuid.UUID) (*TokenPair, error) {
	pair, err := s.Security().IssueTokens(ctx, q, s.tok, uid)
	if err != nil {
		return nil, fmt.Errorf("issue tokens: %w", err)
	}
	return pair, nil
}

// GetUsername implements middleware.UserLookup.
func (s *Auth) GetUsername(ctx context.Context, id uuid.UUID) (string, error) {
	return s.q.GetUsernameByID(ctx, id)
}

// GetSecurityState implements middleware.SecurityLookup. The conversion keeps
// the middleware independent of the database facade's internal types.
func (s *Auth) GetSecurityState(ctx context.Context, id uuid.UUID) (*middleware.PrincipalSecurityState, error) {
	state, err := s.Security().GetSecurityState(ctx, id)
	if err != nil || state == nil {
		return nil, err
	}
	return &middleware.PrincipalSecurityState{
		AuthGeneration: state.AuthGeneration, SecurityState: state.SecurityState,
		PasswordDisabled: state.PasswordDisabled, PasswordResetRequired: state.PasswordResetRequired,
		IsDeleted: state.IsDeleted,
	}, nil
}

// IsAdmin resolves role membership by stable user ID. A configured username is
// never an authorization grant; ordinary legacy users remain USER principals.
func (s *Auth) IsAdmin(ctx context.Context, id uuid.UUID) (bool, error) {
	membership, err := s.q.GetAdminMembership(ctx, id)
	if err != nil {
		return false, err
	}
	if membership != nil {
		return membership.Active && membership.RevokedAt == nil, nil
	}
	return false, nil
}
