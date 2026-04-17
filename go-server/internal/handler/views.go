package handler

import (
	"embed"
	"html/template"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/lrprojects/monaserver/internal/apperrors"
	"github.com/lrprojects/monaserver/internal/db"
	"github.com/lrprojects/monaserver/internal/token"
)

//go:embed templates/*.html
var tmplFS embed.FS

var templates = template.Must(template.ParseFS(tmplFS, "templates/*.html"))

type Views struct {
	q   *db.Queries
	tok *token.Helper
	redirectURL string
}

func NewViews(q *db.Queries, tok *token.Helper, redirectURL string) *Views {
	return &Views{q: q, tok: tok, redirectURL: redirectURL}
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
	tok, _ := v.tok.GenerateAccessToken(u.ID)
	renderTemplate(w, "recover-view.html", map[string]any{"UserID": u.ID, "Token": tok})
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
	tok, _ := v.tok.GenerateAccessToken(u.ID)
	renderTemplate(w, "delete-view.html", map[string]any{"UserID": u.ID, "Username": u.Username, "Token": tok})
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

func renderTemplate(w http.ResponseWriter, name string, data any) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	if err := templates.ExecuteTemplate(w, name, data); err != nil {
		apperrors.WriteError(w, apperrors.ErrInternal)
	}
}
