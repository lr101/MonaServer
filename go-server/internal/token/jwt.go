package token

import (
	"errors"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

type Helper struct {
	secret    []byte
	accessTTL time.Duration
}

// AccessTokenClaims is the small, validated identity envelope used by the
// Bearer middleware. GenerationPresent distinguishes a token minted by a
// generation-aware server from a legacy token whose omitted claim means
// generation zero only.
type AccessTokenClaims struct {
	UserID            uuid.UUID
	AuthGeneration    int64
	GenerationPresent bool
	IssuedAt          time.Time
	ExpiresAt         time.Time
}

type accessClaims struct {
	jwt.RegisteredClaims
	AuthGeneration *int64 `json:"auth_generation,omitempty"`
}

func NewHelper(secret string, accessTTL time.Duration) *Helper {
	return &Helper{secret: []byte(secret), accessTTL: accessTTL}
}

// GenerateAccessToken preserves the legacy no-generation shape when called
// without a generation. New callers should pass the current generation (or
// use GenerateAccessTokenWithGeneration) so containment can fence the token.
func (h *Helper) GenerateAccessToken(userID uuid.UUID, generation ...int64) (string, error) {
	claims := accessClaims{RegisteredClaims: jwt.RegisteredClaims{
		Subject:   userID.String(),
		IssuedAt:  jwt.NewNumericDate(time.Now()),
		ExpiresAt: jwt.NewNumericDate(time.Now().Add(h.accessTTL)),
	}}
	if len(generation) > 1 || (len(generation) == 1 && generation[0] < 0) {
		return "", errors.New("invalid auth generation")
	}
	if len(generation) == 1 {
		claims.AuthGeneration = &generation[0]
	}
	tok := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return tok.SignedString(h.secret)
}

// GenerateAccessTokenWithGeneration emits a token bound to the account's
// current authentication generation, including generation zero.
func (h *Helper) GenerateAccessTokenWithGeneration(userID uuid.UUID, generation int64) (string, error) {
	return h.GenerateAccessToken(userID, generation)
}

func (h *Helper) ParseAccessToken(raw string) (uuid.UUID, error) {
	claims, err := h.ParseAccessTokenClaims(raw)
	if err != nil {
		return uuid.Nil, err
	}
	return claims.UserID, nil
}

// ParseAccessTokenClaims validates signature, expiry, subject, and the
// optional non-negative generation claim. A missing claim is represented as
// GenerationPresent=false for legacy generation-zero compatibility.
func (h *Helper) ParseAccessTokenClaims(raw string) (*AccessTokenClaims, error) {
	var parsed accessClaims
	tok, err := jwt.ParseWithClaims(raw, &parsed, func(t *jwt.Token) (any, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, errors.New("unexpected signing method")
		}
		return h.secret, nil
	})
	if err != nil || !tok.Valid {
		return nil, errors.New("invalid token")
	}
	uid, err := uuid.Parse(parsed.Subject)
	if err != nil || uid == uuid.Nil {
		return nil, errors.New("invalid token subject")
	}
	result := &AccessTokenClaims{
		UserID:    uid,
		IssuedAt:  time.Time{},
		ExpiresAt: time.Time{},
	}
	if parsed.IssuedAt != nil {
		result.IssuedAt = parsed.IssuedAt.Time
	}
	if parsed.ExpiresAt != nil {
		result.ExpiresAt = parsed.ExpiresAt.Time
	}
	if parsed.AuthGeneration != nil {
		if *parsed.AuthGeneration < 0 {
			return nil, errors.New("invalid auth generation")
		}
		result.AuthGeneration = *parsed.AuthGeneration
		result.GenerationPresent = true
	}
	return result, nil
}
