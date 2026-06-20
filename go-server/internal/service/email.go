package service

import (
	"bytes"
	"context"
	"fmt"
	"html/template"
	"strings"

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

// viewLink builds a direct link to a public view route from a bare token.
// It uses RedirectURL as the single origin, so the domain is never duplicated.
func (e *Email) viewLink(route, token string) string {
	return strings.TrimRight(e.cfg.RedirectURL, "/") + route + token
}

// SendEmailConfirmation emails a direct link to confirm the user's address.
// token is the bare email_confirmation_url value.
func (e *Email) SendEmailConfirmation(ctx context.Context, username, to, token string) error {
	html := actionEmail(actionEmailData{
		Title:    "Confirm your email",
		Heading:  "Confirm your email",
		Name:     username,
		Intro:    "Thanks for joining Stick-It! Please confirm your email address to finish setting up your account.",
		Button:   "Confirm email",
		URL:      e.viewLink("/public/email-confirmation/", token),
		Note:     "If you didn’t create a Stick-It account, you can safely ignore this email.",
	})
	return e.SendHTML(ctx, to, "Confirm your email", html)
}

// SendPasswordRecovery emails a direct link to reset the user's password.
// token is the bare reset_password_url value.
func (e *Email) SendPasswordRecovery(ctx context.Context, username, to, token string) error {
	html := actionEmail(actionEmailData{
		Title:    "Reset your password",
		Heading:  "Reset your password",
		Name:     username,
		Intro:    "We received a request to reset your Stick-It password. Click the button below to choose a new one. This link expires in 24 hours.",
		Button:   "Reset password",
		URL:      e.viewLink("/public/recover/", token),
		Note:     "If you didn’t request this, you can safely ignore this email — your password won’t change.",
	})
	return e.SendHTML(ctx, to, "Password recovery", html)
}

// SendDeleteAccount emails a direct link to confirm account deletion.
// token is the bare deletion_url value; code, when set, is shown to the user.
func (e *Email) SendDeleteAccount(ctx context.Context, username, to, token, code string) error {
	html := actionEmail(actionEmailData{
		Title:    "Delete your account",
		Heading:  "Delete your account",
		Name:     username,
		Intro:    "We received a request to delete your Stick-It account. Enter the code below in the app, or use the button to confirm on the web. The code and link expire in 24 hours.",
		Button:   "Delete account",
		URL:      e.viewLink("/public/delete-account/", token),
		Code:     code,
		Danger:   true,
		Note:     "If you didn’t request this, please ignore this email and your account will stay active.",
	})
	return e.SendHTML(ctx, to, "Delete your account", html)
}

// actionEmailData is the data for a single call-to-action transactional email.
type actionEmailData struct {
	Title   string // <title> + preheader
	Heading string // main heading inside the card
	Name    string // recipient's username, used in the greeting
	Intro   string // paragraph above the button
	Button  string // call-to-action label
	URL     string // call-to-action link (also shown as a fallback)
	Code    string // optional code to highlight (delete flow)
	Note    string // small print below the button
	Danger  bool   // red accent for destructive actions
}

// accent returns the brand accent colour, red for destructive actions.
func (d actionEmailData) Accent() string {
	if d.Danger {
		return "#dc2626"
	}
	return "#4f46e5"
}

var actionEmailTmpl = template.Must(template.New("email").Parse(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="color-scheme" content="light">
  <title>{{.Title}}</title>
</head>
<body style="margin:0;padding:0;background-color:#f3f4f6;">
  <span style="display:none;max-height:0;overflow:hidden;opacity:0;">{{.Title}}</span>
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#f3f4f6;padding:24px 0;">
    <tr>
      <td align="center">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:480px;background-color:#ffffff;border-radius:12px;overflow:hidden;box-shadow:0 1px 3px rgba(0,0,0,0.08);font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
          <tr>
            <td style="background-color:{{.Accent}};padding:20px 32px;">
              <span style="color:#ffffff;font-size:20px;font-weight:700;letter-spacing:0.5px;">Stick-It</span>
            </td>
          </tr>
          <tr>
            <td style="padding:32px;">
              <h1 style="margin:0 0 16px;font-size:22px;color:#111827;">{{.Heading}}</h1>
              <p style="margin:0 0 12px;font-size:15px;line-height:1.6;color:#374151;">Hi {{.Name}},</p>
              <p style="margin:0 0 24px;font-size:15px;line-height:1.6;color:#374151;">{{.Intro}}</p>
              {{if .Code}}
              <p style="margin:0 0 24px;text-align:center;">
                <span style="display:inline-block;font-size:28px;font-weight:700;letter-spacing:6px;color:#111827;background-color:#f3f4f6;border-radius:8px;padding:12px 20px;">{{.Code}}</span>
              </p>
              {{end}}
              <table role="presentation" cellpadding="0" cellspacing="0" style="margin:0 auto 24px;">
                <tr>
                  <td align="center" style="border-radius:8px;background-color:{{.Accent}};">
                    <a href="{{.URL}}" style="display:inline-block;padding:13px 28px;font-size:15px;font-weight:600;color:#ffffff;text-decoration:none;border-radius:8px;">{{.Button}}</a>
                  </td>
                </tr>
              </table>
              <p style="margin:0 0 8px;font-size:13px;line-height:1.6;color:#6b7280;">If the button doesn’t work, copy and paste this link into your browser:</p>
              <p style="margin:0 0 24px;font-size:13px;line-height:1.6;word-break:break-all;"><a href="{{.URL}}" style="color:{{.Accent}};">{{.URL}}</a></p>
              <p style="margin:0;font-size:13px;line-height:1.6;color:#9ca3af;">{{.Note}}</p>
            </td>
          </tr>
          <tr>
            <td style="padding:20px 32px;background-color:#f9fafb;border-top:1px solid #f0f0f0;">
              <p style="margin:0;font-size:12px;color:#9ca3af;">© Stick-It · This is an automated message, please don’t reply.</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`))

// actionEmail renders the branded call-to-action email. On the unlikely event
// of a template error it falls back to a minimal but valid HTML body.
func actionEmail(d actionEmailData) string {
	var buf bytes.Buffer
	if err := actionEmailTmpl.Execute(&buf, d); err != nil {
		return fmt.Sprintf(`<p>Hi %s,</p><p>%s</p><p><a href="%s">%s</a></p>`,
			template.HTMLEscapeString(d.Name), template.HTMLEscapeString(d.Intro), d.URL, template.HTMLEscapeString(d.Button))
	}
	return buf.String()
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
