package service

import (
	"bytes"
	"context"
	"fmt"
	"html/template"

	"github.com/lrprojects/monaserver/internal/config"
	"github.com/wneessen/go-mail"
)

// Email sends transactional + bulk mail. Mirrors the Kotlin EmailService:
//   - recovery, delete, email confirmation, welcome messages
//   - bulk admin mail with per-recipient templating
type Email struct {
	cfg  *config.Config
	tmpl *template.Template
}

func NewEmail(cfg *config.Config, tmpl *template.Template) *Email {
	return &Email{cfg: cfg, tmpl: tmpl}
}

// client builds an SMTP client honoring the port convention from Kotlin MailHelper:
// 465 → SSL on-connect, 587 → STARTTLS, else plain.
func (e *Email) client() (*mail.Client, error) {
	opts := []mail.Option{
		mail.WithPort(e.cfg.MailPort),
		mail.WithUsername(e.cfg.MailUsername),
		mail.WithPassword(e.cfg.MailPassword),
		mail.WithSMTPAuth(mail.SMTPAuthPlain),
	}
	switch e.cfg.MailPort {
	case 465:
		opts = append(opts, mail.WithSSLPort(false))
	case 587:
		opts = append(opts, mail.WithTLSPortPolicy(mail.TLSMandatory))
	}
	return mail.NewClient(e.cfg.MailHost, opts...)
}

// SendHTML sends a single HTML email.
func (e *Email) SendHTML(ctx context.Context, to, subject, htmlBody string) error {
	m := mail.NewMsg()
	if err := m.From(e.cfg.MailFrom); err != nil {
		return err
	}
	if err := m.To(to); err != nil {
		return err
	}
	m.Subject(subject)
	m.SetBodyString(mail.TypeTextHTML, htmlBody)
	c, err := e.client()
	if err != nil {
		return err
	}
	return c.DialAndSendWithContext(ctx, m)
}

// SendTemplated renders a named template with vars and sends the result.
func (e *Email) SendTemplated(ctx context.Context, to, subject, tmplName string, vars any) error {
	if e.tmpl == nil {
		return fmt.Errorf("no templates loaded")
	}
	var buf bytes.Buffer
	if err := e.tmpl.ExecuteTemplate(&buf, tmplName, vars); err != nil {
		return err
	}
	return e.SendHTML(ctx, to, subject, buf.String())
}

// SendEmailConfirmation mirrors EmailServiceImpl.sendEmailConfirmation.
func (e *Email) SendEmailConfirmation(ctx context.Context, username, to, confirmationUrl string) error {
	link := fmt.Sprintf("%s/confirm-email?c=%s", e.cfg.RedirectURL, confirmationUrl)
	body := fmt.Sprintf(`<p>Hi %s, please confirm your email: <a href="%s">%s</a></p>`, username, link, link)
	return e.SendHTML(ctx, to, "Confirm your email", body)
}

// SendPasswordRecovery mirrors EmailServiceImpl.sendPasswordRecovery.
func (e *Email) SendPasswordRecovery(ctx context.Context, username, to, resetUrl string) error {
	link := fmt.Sprintf("%s/recover?c=%s", e.cfg.RedirectURL, resetUrl)
	body := fmt.Sprintf(`<p>Hi %s, reset your password: <a href="%s">%s</a></p>`, username, link, link)
	return e.SendHTML(ctx, to, "Password recovery", body)
}

// SendDeleteAccount mirrors EmailServiceImpl.sendDeleteAccount.
func (e *Email) SendDeleteAccount(ctx context.Context, username, to, deleteUrl, code string) error {
	link := fmt.Sprintf("%s/delete-account?c=%s", e.cfg.RedirectURL, deleteUrl)
	body := fmt.Sprintf(`<p>Hi %s, confirm account deletion with code <b>%s</b> or use <a href="%s">%s</a></p>`, username, code, link, link)
	return e.SendHTML(ctx, to, "Delete your account", body)
}

// SendBulk sends the same subject+html to many recipients. Used by AdminController.
func (e *Email) SendBulk(ctx context.Context, recipients []string, subject, htmlBody string) error {
	for _, to := range recipients {
		if err := e.SendHTML(ctx, to, subject, htmlBody); err != nil {
			return fmt.Errorf("send to %s: %w", to, err)
		}
	}
	return nil
}
