package handler

import (
	"encoding/base64"
	"encoding/json"
	"net/http"

	"github.com/lrprojects/monaserver/internal/apperrors"
	"github.com/lrprojects/monaserver/internal/db"
	"github.com/lrprojects/monaserver/internal/service"
)

type Admin struct {
	q     *db.Queries
	email *service.Email
	notif *service.Notification
}

func NewAdmin(q *db.Queries, email *service.Email, notif *service.Notification) *Admin {
	return &Admin{q: q, email: email, notif: notif}
}

type adminMailInput struct {
	Mails       []string `json:"mails"`
	Subject     string   `json:"subject"`
	Message     string   `json:"message"`
	MessageHTML *string  `json:"messageHtml,omitempty"`
}

func (h *Admin) Mail(w http.ResponseWriter, r *http.Request) {
	var in adminMailInput
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		apperrors.WriteError(w, apperrors.ErrBadRequest)
		return
	}
	var htmlBody string
	if in.MessageHTML != nil {
		b, err := base64.StdEncoding.DecodeString(*in.MessageHTML)
		if err != nil {
			apperrors.WriteError(w, apperrors.ErrBadRequest)
			return
		}
		htmlBody = string(b)
	} else {
		htmlBody = "<p>" + in.Message + "</p>"
	}
	recipients := in.Mails
	if len(recipients) == 0 {
		var err error
		recipients, err = h.q.ListAllUserEmails(r.Context())
		if err != nil {
			apperrors.WriteError(w, err)
			return
		}
	}
	if err := h.email.SendBulk(r.Context(), recipients, in.Subject, htmlBody); err != nil {
		apperrors.WriteError(w, err)
		return
	}
	w.WriteHeader(http.StatusOK)
}

type notifInput struct {
	Title string `json:"title"`
	Body  string `json:"body"`
	Topic string `json:"topic"`
}

func (h *Admin) Notification(w http.ResponseWriter, r *http.Request) {
	var in notifInput
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		apperrors.WriteError(w, apperrors.ErrBadRequest)
		return
	}
	if err := h.notif.SendToTopic(r.Context(), in.Topic, in.Title, in.Body); err != nil {
		apperrors.WriteError(w, err)
		return
	}
	w.WriteHeader(http.StatusCreated)
}

// Report handler — sends a report email to the admin mailbox.
type Report struct {
	q     *db.Queries
	email *service.Email
}

func NewReport(q *db.Queries, email *service.Email) *Report { return &Report{q: q, email: email} }

type reportInput struct {
	UserID  string `json:"userId"`
	Report  string `json:"report"`
	Message string `json:"message"`
}

func (h *Report) Create(w http.ResponseWriter, r *http.Request) {
	var in reportInput
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		apperrors.WriteError(w, apperrors.ErrBadRequest)
		return
	}
	body := "<p>Report from user " + in.UserID + ": " + in.Report + "</p><p>" + in.Message + "</p>"
	_ = h.email.SendBulk(r.Context(), nil, "User Report: "+in.Report, body)
	w.WriteHeader(http.StatusOK)
}
