package service

import (
	"bytes"
	"regexp"
	"strings"
	"testing"
	"time"
)

func TestGeneratedEmailLoginCodesContainSixAlphanumericCharacters(t *testing.T) {
	for i := 0; i < 20; i++ {
		code, err := generateEmailLoginCode()
		if err != nil {
			t.Fatalf("generate sign-in code: %v", err)
		}
		if !regexp.MustCompile(`^[A-Z0-9]{6}$`).MatchString(code) {
			t.Fatalf("generated code = %q, want six uppercase letters or numbers", code)
		}
	}
}

func TestEmailLoginCodeNormalizationAcceptsOnlyASCIIAlphanumeric(t *testing.T) {
	if code, ok := normalizeEmailLoginCode(" a2b4c6 "); !ok || code != "A2B4C6" {
		t.Fatalf("normalize lowercase code = %q, %v; want A2B4C6, true", code, ok)
	}
	if code, ok := normalizeEmailLoginCode("ſ2345a"); ok {
		t.Fatalf("normalize non-ASCII code = %q, true; want rejection", code)
	}
}

func TestEmailLoginCodeHashBindsTheAddress(t *testing.T) {
	login := &EmailLogin{cfg: EmailLoginConfig{
		HMACKeyID: "test-v1",
		HMACKey:   []byte("email-login-test-secret"),
	}}
	first := login.loginCodeHashes("A2B4C6", "first@example.com")
	second := login.loginCodeHashes("A2B4C6", "second@example.com")
	if len(first) != 1 || len(second) != 1 || bytes.Equal(first[0], second[0]) {
		t.Fatalf("same code hashed identically across email addresses: first=%x second=%x", first, second)
	}
}

func TestLoginLinkEmailTemplateAcceptsCodePlaceholder(t *testing.T) {
	template := &LoginLinkEmailTemplate{
		Subject: "Sign in to {{app_name}}",
		Body:    "Use code {{login_code}} or open {{login_link}}.",
	}
	if err := validateLoginLinkEmailTemplate(template); err != nil {
		t.Fatalf("template with a sign-in code was rejected: %v", err)
	}
	_, body, htmlBody, err := renderLoginLinkEmailContent(
		template, "alice", "alice@example.com", "https://app.example/#/email-login/callback?token=opaque", "A2B4C6", "15 minutes",
	)
	if err != nil {
		t.Fatalf("render template: %v", err)
	}
	if !strings.Contains(body, "A2B4C6") || !strings.Contains(htmlBody, "A2B4C6") {
		t.Fatalf("rendered message omitted code: body=%q html=%q", body, htmlBody)
	}
	if !strings.Contains(htmlBody, `<a href="https://app.example/#/email-login/callback?token=opaque">Sign in</a>`) {
		t.Fatalf("HTML message omitted its sign-in link: %q", htmlBody)
	}
}

func TestLegacyLoginLinkEmailTemplateGetsCodeAppended(t *testing.T) {
	template := &LoginLinkEmailTemplate{
		Subject: "Sign in",
		Body:    "Open {{login_link}} to sign in.",
	}
	_, body, _, err := renderLoginLinkEmailContent(
		template, "alice", "alice@example.com", "https://app.example/login", "Q7R2W9", "15 minutes",
	)
	if err != nil {
		t.Fatalf("render legacy template: %v", err)
	}
	if !strings.Contains(body, "Sign-in code: Q7R2W9") {
		t.Fatalf("legacy campaign did not receive its code: %q", body)
	}
}

func TestStandardLoginLinkEmailIncludesCodeAndSecondaryLink(t *testing.T) {
	content := loginLinkEmailContent(
		"alice", "alice@example.com", "opaque-token", "https://app.example/#/email-login/callback?token=", "A2B4C6", 15*time.Minute,
	)
	if !strings.Contains(content.Body, "A2B4C6") || !strings.Contains(content.Body, "https://app.example/#/email-login/callback?token=opaque-token") {
		t.Fatalf("standard email omitted code or link: %q", content.Body)
	}
	if !strings.Contains(content.HTML, "A2B4C6") || !strings.Contains(content.HTML, "https://app.example/#/email-login/callback?token=opaque-token") {
		t.Fatalf("standard HTML email omitted code or link: %q", content.HTML)
	}
}
