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
