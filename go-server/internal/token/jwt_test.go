package token

import (
	"testing"
	"time"

	"github.com/google/uuid"
)

func TestGenerateAndParse(t *testing.T) {
	h := NewHelper("test-secret", time.Minute)
	uid := uuid.New()
	tok, err := h.GenerateAccessToken(uid)
	if err != nil {
		t.Fatalf("generate: %v", err)
	}
	got, err := h.ParseAccessToken(tok)
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	if got != uid {
		t.Fatalf("got %v want %v", got, uid)
	}
}

func TestParseExpired(t *testing.T) {
	h := NewHelper("test-secret", -time.Minute)
	tok, _ := h.GenerateAccessToken(uuid.New())
	if _, err := h.ParseAccessToken(tok); err == nil {
		t.Fatal("expected expiry error")
	}
}

func TestParseWrongSecret(t *testing.T) {
	h1 := NewHelper("s1", time.Minute)
	h2 := NewHelper("s2", time.Minute)
	tok, _ := h1.GenerateAccessToken(uuid.New())
	if _, err := h2.ParseAccessToken(tok); err == nil {
		t.Fatal("expected signature mismatch error")
	}
}

func TestGenerationClaimRoundTripAndLegacyCompatibility(t *testing.T) {
	h := NewHelper("test-secret", time.Minute)
	uid := uuid.New()
	raw, err := h.GenerateAccessTokenWithGeneration(uid, 7)
	if err != nil {
		t.Fatalf("generate generation token: %v", err)
	}
	claims, err := h.ParseAccessTokenClaims(raw)
	if err != nil {
		t.Fatalf("parse generation token: %v", err)
	}
	if claims.UserID != uid || claims.AuthGeneration != 7 || !claims.GenerationPresent {
		t.Fatalf("claims = %#v, want user=%s generation=7 present", claims, uid)
	}

	legacy, err := h.GenerateAccessToken(uid)
	if err != nil {
		t.Fatalf("generate legacy-shaped token: %v", err)
	}
	legacyClaims, err := h.ParseAccessTokenClaims(legacy)
	if err != nil {
		t.Fatalf("parse legacy-shaped token: %v", err)
	}
	if legacyClaims.UserID != uid || legacyClaims.AuthGeneration != 0 || legacyClaims.GenerationPresent {
		t.Fatalf("legacy claims = %#v, want zero generation absent", legacyClaims)
	}
}
