package handler

import (
	"embed"
	"html/template"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/lrprojects/monaserver/internal/apperrors"
	"github.com/lrprojects/monaserver/internal/db"
	"github.com/lrprojects/monaserver/internal/service"
	"github.com/lrprojects/monaserver/internal/token"
)

//go:embed templates/*.html
var tmplFS embed.FS

//go:embed static/favicon.ico
var faviconBytes []byte

var templates = template.Must(template.ParseFS(tmplFS, "templates/*.html"))

type Views struct {
	q           *db.Queries
	tok         *token.Helper
	security    *service.AccountSecurity
	redirectURL string
}

func NewViews(q *db.Queries, tok *token.Helper, redirectURL string, security ...*service.AccountSecurity) *Views {
	var coordinator *service.AccountSecurity
	if len(security) > 0 {
		coordinator = security[0]
	}
	if coordinator == nil {
		coordinator = service.NewAccountSecurity(q)
	}
	return &Views{q: q, tok: tok, security: coordinator, redirectURL: redirectURL}
}

func (v *Views) RecoverPassword(w http.ResponseWriter, r *http.Request) {
	url := chi.URLParam(r, "url")
	u, err := v.q.GetUserByResetPasswordUrl(r.Context(), url)
	if err != nil || u == nil {
		renderTemplate(w, "404.html", nil)
		return
	}
	if u.Expiration != nil && time.Now().After(*u.Expiration) {
		renderTemplate(w, "time-expired.html", nil)
		return
	}
	// The legacy reset URL predates the purpose-bound action token. Once an
	// account is contained, that old URL must not mint a fresh recovery
	// capability; only a recovery token queued for the current generation may
	// be redeemed by the restricted endpoint.
	state, err := v.security.GetSecurityState(r.Context(), u.ID)
	if err != nil || state == nil || state.IsDeleted || state.SecurityState != db.SecurityStateNormal || state.PasswordDisabled || state.PasswordResetRequired {
		renderTemplate(w, "404.html", nil)
		return
	}
	// A legacy reset URL is only a lookup handle. The page receives a
	// purpose-bound opaque action token and submits it to the restricted
	// recovery endpoint; it never receives a normal consumer JWT.
	action, err := v.security.IssueActionToken(r.Context(), nil, u.ID, db.ActionTokenPurposeRecovery, nil, 10*time.Minute)
	if err != nil || action == nil {
		renderTemplate(w, "404.html", nil)
		return
	}
	renderTemplate(w, "recover-view.html", map[string]any{"UserID": u.ID, "Token": action.Token})
}

func (v *Views) DeleteAccountView(w http.ResponseWriter, r *http.Request) {
	url := chi.URLParam(r, "url")
	u, err := v.q.GetUserByDeletionUrl(r.Context(), url)
	if err != nil || u == nil {
		renderTemplate(w, "404.html", nil)
		return
	}
	if u.Expiration != nil && time.Now().After(*u.Expiration) {
		renderTemplate(w, "time-expired.html", nil)
		return
	}
	action, err := v.security.IssueActionToken(r.Context(), nil, u.ID, db.ActionTokenPurposeDeleteAccount, nil, 10*time.Minute)
	if err != nil || action == nil {
		renderTemplate(w, "404.html", nil)
		return
	}
	renderTemplate(w, "delete-view.html", map[string]any{"UserID": u.ID, "Username": u.Username, "Token": action.Token})
}

func (v *Views) EmailConfirmation(w http.ResponseWriter, r *http.Request) {
	url := chi.URLParam(r, "url")
	u, err := v.q.GetUserByEmailConfirmationUrl(r.Context(), url)
	if err != nil || u == nil {
		renderTemplate(w, "404.html", nil)
		return
	}
	_ = v.q.ConfirmUserEmail(r.Context(), u.ID)
	renderTemplate(w, "email-confirmation-view.html", map[string]any{"Username": u.Username})
}

func (v *Views) RequestDeleteCode(w http.ResponseWriter, r *http.Request) {
	renderTemplate(w, "request-delete-view.html", nil)
}

func (v *Views) Root(w http.ResponseWriter, r *http.Request) {
	http.Redirect(w, r, v.redirectURL, http.StatusPermanentRedirect)
}

func (v *Views) Agb(w http.ResponseWriter, r *http.Request) {
	renderTemplate(w, "agb.html", nil)
}

func (v *Views) PrivacyPolicy(w http.ResponseWriter, r *http.Request) {
	renderTemplate(w, "privacy-policy.html", nil)
}

func (v *Views) Favicon(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "image/x-icon")
	_, _ = w.Write(faviconBytes)
}

func renderTemplate(w http.ResponseWriter, name string, data any) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	if err := templates.ExecuteTemplate(w, name, data); err != nil {
		apperrors.WriteError(w, apperrors.ErrInternal)
	}
}
