package handler

import (
	"context"
	"encoding/base64"
	"net/http"

	"github.com/lrprojects/monaserver/internal/apperrors"
	"github.com/lrprojects/monaserver/internal/db"
	genserver "github.com/lrprojects/monaserver/internal/gen/server"
	"github.com/lrprojects/monaserver/internal/service"
)

// AdminServicer implements genserver.AdminAPIServicer.
type AdminServicer struct {
	q     *db.Queries
	email *service.Email
	notif *service.Notification
}

func NewAdminServicer(q *db.Queries, email *service.Email, notif *service.Notification) *AdminServicer {
	return &AdminServicer{q: q, email: email, notif: notif}
}

func (s *AdminServicer) SendAdminMail(ctx context.Context, dto genserver.AdminMailDto) (genserver.ImplResponse, error) {
	var htmlBody string
	if dto.MessageHtml != nil && *dto.MessageHtml != "" {
		b, err := base64.StdEncoding.DecodeString(*dto.MessageHtml)
		if err != nil {
			return genserver.Response(http.StatusBadRequest, nil), nil
		}
		htmlBody = string(b)
	} else {
		htmlBody = "<p>" + dto.Message + "</p>"
	}
	var recipients []string
	if dto.Mails != nil && len(*dto.Mails) > 0 {
		recipients = *dto.Mails
	} else {
		var err error
		recipients, err = s.q.ListAllUserEmails(ctx)
		if err != nil {
			return genserver.Response(apperrors.HTTPStatus(err), nil), nil
		}
	}
	if err := s.email.SendBulk(ctx, recipients, dto.Subject, htmlBody); err != nil {
		return genserver.Response(apperrors.HTTPStatus(err), nil), nil
	}
	return genserver.Response(http.StatusOK, nil), nil
}

func (s *AdminServicer) SendNotification(ctx context.Context, dto genserver.NotificationDto) (genserver.ImplResponse, error) {
	if err := s.notif.SendToTopic(ctx, dto.Topic, dto.Title, dto.Body); err != nil {
		return genserver.Response(apperrors.HTTPStatus(err), nil), nil
	}
	return genserver.Response(http.StatusCreated, nil), nil
}

// ReportServicer implements genserver.ReportAPIServicer.
type ReportServicer struct {
	email *service.Email
}

func NewReportServicer(email *service.Email) *ReportServicer {
	return &ReportServicer{email: email}
}

func (s *ReportServicer) CreateReport(ctx context.Context, dto genserver.ReportDto) (genserver.ImplResponse, error) {
	body := "<p>Report from user " + dto.UserId + ": " + dto.Report + "</p><p>" + dto.Message + "</p>"
	_ = s.email.SendBulk(ctx, nil, "User Report: "+dto.Report, body)
	return genserver.Response(http.StatusOK, nil), nil
}

// PublicServicer implements genserver.PublicAPIServicer.
type PublicServicer struct{}

func NewPublicServicer() *PublicServicer { return &PublicServicer{} }

func (s *PublicServicer) GetServerInfo(_ context.Context) (genserver.ImplResponse, error) {
	return genserver.Response(http.StatusOK, genserver.InfoDto{}), nil
}
