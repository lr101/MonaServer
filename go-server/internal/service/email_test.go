package service

import (
	"strings"
	"testing"

	"github.com/lrprojects/monaserver/internal/config"
)

// TestViewLinkNoDoubleDomain guards against the regression where the email link
// was wrapped as "RedirectURL/recover?c=RedirectURL/public/recover/token",
// duplicating the domain. The link must be a single, direct URL.
func TestViewLinkNoDoubleDomain(t *testing.T) {
	cases := []struct {
		redirect, route, token, want string
	}{
		{"https://app.example.com", "/public/recover/", "abc123",
			"https://app.example.com/public/recover/abc123"},
		{"https://app.example.com/", "/public/delete-account/", "tok", // trailing slash trimmed
			"https://app.example.com/public/delete-account/tok"},
		{"https://app.example.com", "/public/email-confirmation/", "xyz",
			"https://app.example.com/public/email-confirmation/xyz"},
	}
	for _, c := range cases {
		e := NewEmail(&config.Config{RedirectURL: c.redirect}, nil)
		got := e.viewLink(c.route, c.token)
		if got != c.want {
			t.Errorf("viewLink(%q, %q) = %q, want %q", c.redirect, c.token, got, c.want)
		}
		if strings.Contains(got, "?c=") {
			t.Errorf("link must not contain the ?c= wrapper: %q", got)
		}
		if strings.Count(got, "://") != 1 {
			t.Errorf("domain must appear exactly once: %q", got)
		}
	}
}

func TestViewLinkUsesPublicAppURL(t *testing.T) {
	e := NewEmail(&config.Config{
		AppURL:      "https://api.example.com",
		RedirectURL: "stickit://app",
	}, nil)
	got := e.viewLink("/public/recover/", "abc123")
	want := "https://api.example.com/public/recover/abc123"
	if got != want {
		t.Fatalf("view link = %q, want %q", got, want)
	}
}

// TestActionEmailRendersDirectLink verifies the branded template embeds the
// direct link (button + fallback) and greets the user, with no ?c= wrapper.
func TestActionEmailRendersDirectLink(t *testing.T) {
	const url = "https://app.example.com/public/recover/tok"
	html := actionEmail(actionEmailData{
		Title: "Reset your password", Heading: "Reset your password", Name: "alice",
		Intro: "intro text", Button: "Reset password", URL: url, Note: "note",
	})
	if !strings.Contains(html, url) {
		t.Fatal("email must contain the direct link")
	}
	if strings.Contains(html, "?c=") {
		t.Fatal("email must not contain the ?c= double-domain wrapper")
	}
	if !strings.Contains(html, "alice") {
		t.Fatal("email must greet the user by name")
	}
	if !strings.Contains(html, "Reset password") {
		t.Fatal("email must contain the call-to-action label")
	}
}

// TestActionEmailDangerAccent checks destructive emails use the red accent and
// can surface an optional code.
func TestActionEmailDangerAccent(t *testing.T) {
	html := actionEmail(actionEmailData{
		Title: "Delete", Heading: "Delete your account", Name: "bob",
		Intro: "intro", Button: "Delete account",
		URL:  "https://app.example.com/public/delete-account/tok",
		Code: "123456", Danger: true, Note: "note",
	})
	if !strings.Contains(html, "#dc2626") {
		t.Fatal("destructive email should use the red accent colour")
	}
	if !strings.Contains(html, "123456") {
		t.Fatal("email should display the provided code")
	}
}
