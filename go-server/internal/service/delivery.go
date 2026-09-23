package service

import (
	"context"
	"errors"
	"fmt"
	"html"
	"net/mail"
	"net/url"
	"strings"
	"unicode/utf8"

	xhtml "golang.org/x/net/html"
	"golang.org/x/net/html/atom"

	"github.com/lrprojects/monaserver/internal/db"
	"github.com/lrprojects/monaserver/internal/jobs"
)

const (
	maxEmailSubjectBytes = 200
	maxEmailTextBytes    = 10_000
	maxEmailHTMLBytes    = 20_000
	maxPushTitleBytes    = 200
	maxPushBodyBytes     = 2_000
)

// Exported aliases let API/admin services share the same bounds without
// copying magic numbers into request validation.
const (
	MaxEmailSubjectBytes = maxEmailSubjectBytes
	MaxEmailTextBytes    = maxEmailTextBytes
	MaxEmailHTMLBytes    = maxEmailHTMLBytes
	MaxPushTitleBytes    = maxPushTitleBytes
	MaxPushBodyBytes     = maxPushBodyBytes
)

var (
	ErrInvalidEmailContent  = errors.New("invalid email content")
	ErrEmailContentTooLarge = errors.New("email content too large")
	ErrInvalidPushContent   = errors.New("invalid push content")
)

// EmailContent is the bounded, transport-independent input to an email
// delivery. HTML is optional and is sanitized before it reaches a provider.
type EmailContent struct {
	To      string
	Subject string
	Body    string
	HTML    string
}

// RenderedEmail is safe to hand to SMTP or a deterministic test provider.
type RenderedEmail struct {
	To      string
	Subject string
	Text    string
	HTML    string
}

// RenderEmail validates recipient/header fields, enforces contract bounds,
// and sanitizes HTML using an allowlist. No caller-supplied markup or URL is
// evaluated by the admin UI or interpolated into an unsanitized template.
func RenderEmail(content EmailContent) (RenderedEmail, error) {
	to := strings.TrimSpace(content.To)
	if !validRecipient(to) || strings.TrimSpace(content.Subject) == "" || strings.TrimSpace(content.Body) == "" {
		return RenderedEmail{}, ErrInvalidEmailContent
	}
	subject := strings.TrimSpace(content.Subject)
	body := content.Body
	if hasControlHeaderByte(to) || hasControlHeaderByte(subject) || len([]byte(subject)) > maxEmailSubjectBytes {
		if len([]byte(subject)) > maxEmailSubjectBytes {
			return RenderedEmail{}, ErrEmailContentTooLarge
		}
		return RenderedEmail{}, ErrInvalidEmailContent
	}
	if len([]byte(body)) > maxEmailTextBytes {
		return RenderedEmail{}, ErrEmailContentTooLarge
	}
	htmlBody, err := SanitizeHTML(content.HTML)
	if err != nil {
		return RenderedEmail{}, err
	}
	if htmlBody == "" {
		htmlBody = plainTextHTML(body)
	}
	return RenderedEmail{To: to, Subject: subject, Text: body, HTML: htmlBody}, nil
}

func validRecipient(to string) bool {
	if to == "" || hasControlHeaderByte(to) {
		return false
	}
	parsed, err := mail.ParseAddress(to)
	if err != nil || parsed.Address == "" {
		return false
	}
	// A test/admin recipient must identify one mailbox. Display names are
	// accepted by net/mail, while comma-separated address lists are not.
	return !strings.ContainsAny(to, ",\n\r")
}

func hasControlHeaderByte(value string) bool {
	return strings.ContainsAny(value, "\r\n\x00")
}

func plainTextHTML(body string) string {
	parts := strings.Split(body, "\n")
	for i := range parts {
		parts[i] = html.EscapeString(parts[i])
	}
	return "<p>" + strings.Join(parts, "<br>") + "</p>"
}

// SanitizeHTML strips scripts, event handlers, remote media, CSS, forms,
// frames, and unsafe links. Text from harmless unknown elements is retained;
// content inside active/dangerous elements is discarded entirely.
func SanitizeHTML(raw string) (string, error) {
	if len([]byte(raw)) > maxEmailHTMLBytes {
		return "", ErrEmailContentTooLarge
	}
	if strings.TrimSpace(raw) == "" {
		return "", nil
	}
	root := &xhtml.Node{Type: xhtml.ElementNode, DataAtom: atom.Div, Data: "div"}
	nodes, err := xhtml.ParseFragment(strings.NewReader(raw), root)
	if err != nil {
		return "", ErrInvalidEmailContent
	}
	var b strings.Builder
	for _, node := range nodes {
		renderSafeNode(&b, node)
	}
	result := strings.TrimSpace(b.String())
	if len([]byte(result)) > maxEmailHTMLBytes {
		return "", ErrEmailContentTooLarge
	}
	return result, nil
}

var allowedHTMLTags = map[string]struct{}{
	"a": {}, "abbr": {}, "b": {}, "blockquote": {}, "br": {}, "code": {},
	"del": {}, "em": {}, "i": {}, "kbd": {}, "li": {}, "mark": {}, "ol": {},
	"p": {}, "pre": {}, "q": {}, "s": {}, "samp": {}, "small": {}, "span": {},
	"strong": {}, "sub": {}, "sup": {}, "u": {}, "ul": {},
}

var blockedHTMLTags = map[string]struct{}{
	"base": {}, "embed": {}, "form": {}, "iframe": {}, "img": {}, "input": {},
	"link": {}, "meta": {}, "object": {}, "script": {}, "style": {}, "textarea": {},
	"title": {}, "video": {}, "audio": {}, "svg": {}, "math": {},
}

func renderSafeNode(b *strings.Builder, node *xhtml.Node) {
	switch node.Type {
	case xhtml.TextNode:
		b.WriteString(html.EscapeString(node.Data))
	case xhtml.ElementNode:
		tag := strings.ToLower(node.Data)
		if _, blocked := blockedHTMLTags[tag]; blocked {
			return
		}
		if _, allowed := allowedHTMLTags[tag]; !allowed {
			for child := node.FirstChild; child != nil; child = child.NextSibling {
				renderSafeNode(b, child)
			}
			return
		}
		b.WriteByte('<')
		b.WriteString(tag)
		if tag == "a" {
			for _, attr := range node.Attr {
				if strings.EqualFold(attr.Key, "href") && safeLink(attr.Val) {
					b.WriteString(` href="`)
					b.WriteString(html.EscapeString(strings.TrimSpace(attr.Val)))
					b.WriteByte('"')
					break
				}
			}
		}
		b.WriteByte('>')
		if tag != "br" {
			for child := node.FirstChild; child != nil; child = child.NextSibling {
				renderSafeNode(b, child)
			}
			b.WriteString("</")
			b.WriteString(tag)
			b.WriteByte('>')
		}
	}
}

func safeLink(raw string) bool {
	parsed, err := url.Parse(strings.TrimSpace(raw))
	if err != nil || parsed.Host == "" {
		return parsed != nil && parsed.Scheme == "mailto" && parsed.Opaque != ""
	}
	scheme := strings.ToLower(parsed.Scheme)
	return scheme == "https" || scheme == "http"
}

// ProviderOutcome is intentionally separate from jobs.Outcome. Providers can
// report disabled/transient/permanent/uncertain states; the worker maps these
// into durable job lifecycle and recipient outcome values.
type ProviderOutcome string

const (
	ProviderAccepted         ProviderOutcome = "accepted"
	ProviderTransientFailure ProviderOutcome = "transient_failure"
	ProviderPermanentFailure ProviderOutcome = "permanent_failure"
	ProviderDisabled         ProviderOutcome = "disabled"
	ProviderUnknownDelivery  ProviderOutcome = "unknown_delivery"

	// Compatibility aliases for callers that prefer the longer names.
	ProviderOutcomeAccepted         = ProviderAccepted
	ProviderOutcomeTransientFailure = ProviderTransientFailure
	ProviderOutcomePermanentFailure = ProviderPermanentFailure
	ProviderOutcomeDisabled         = ProviderDisabled
	ProviderOutcomeUnknownDelivery  = ProviderUnknownDelivery
)

type ProviderResult struct {
	Outcome   ProviderOutcome
	Reference string
	ErrorCode string
}

func (r ProviderResult) SafeErrorCode() string { return safeProviderCode(r.ErrorCode) }

func (r ProviderResult) JobResult() jobs.Result {
	errorCode := r.SafeErrorCode()
	switch r.Outcome {
	case ProviderAccepted:
		return jobs.Result{Status: jobs.StatusCompleted, Outcome: jobs.OutcomeProviderAccepted, ErrorCode: errorCode}
	case ProviderTransientFailure:
		return jobs.Result{Retry: true, Outcome: jobs.OutcomeUnknownDelivery, ErrorCode: errorCode}
	case ProviderUnknownDelivery:
		return jobs.Result{Retry: true, Outcome: jobs.OutcomeUnknownDelivery, ErrorCode: errorCode}
	case ProviderDisabled:
		if errorCode == "" {
			errorCode = "provider_disabled"
		}
		return jobs.Result{Status: jobs.StatusFailed, Outcome: jobs.OutcomeFailed, ErrorCode: errorCode}
	case ProviderPermanentFailure:
		return jobs.Result{Status: jobs.StatusFailed, Outcome: jobs.OutcomeFailed, ErrorCode: errorCode}
	default:
		return jobs.Result{Status: jobs.StatusFailed, Outcome: jobs.OutcomeFailed, ErrorCode: "provider_invalid_outcome"}
	}
}

// EmailProvider and PushProvider are deterministic, transport-independent
// seams. Production SMTP/FCM wrappers and tests implement the same methods.
type EmailProvider interface {
	SendEmail(context.Context, RenderedEmail) ProviderResult
}

type PushMessage struct {
	Token string
	Title string
	Body  string
}

type PushProvider interface {
	SendPush(context.Context, PushMessage) ProviderResult
}

type EmailDelivery struct{ provider EmailProvider }

func NewEmailDelivery(provider EmailProvider) *EmailDelivery {
	return &EmailDelivery{provider: provider}
}

func (d *EmailDelivery) Send(ctx context.Context, content EmailContent) ProviderResult {
	if d == nil || d.provider == nil {
		return ProviderResult{Outcome: ProviderDisabled, ErrorCode: "provider_disabled"}
	}
	rendered, err := RenderEmail(content)
	if err != nil {
		return ProviderResult{Outcome: ProviderPermanentFailure, ErrorCode: emailContentErrorCode(err)}
	}
	return d.provider.SendEmail(ctx, rendered)
}

// SendTest requires exactly one explicit recipient. It never falls back to a
// configured list or an implicit all-recipient audience.
func (d *EmailDelivery) SendTest(ctx context.Context, recipient string, content EmailContent) ProviderResult {
	if strings.TrimSpace(recipient) == "" {
		return ProviderResult{Outcome: ProviderPermanentFailure, ErrorCode: "test_recipient_required"}
	}
	content.To = recipient
	return d.Send(ctx, content)
}

type PushDelivery struct{ provider PushProvider }

func NewPushDelivery(provider PushProvider) *PushDelivery { return &PushDelivery{provider: provider} }

func (d *PushDelivery) Send(ctx context.Context, message PushMessage) ProviderResult {
	if strings.TrimSpace(message.Token) == "" || strings.TrimSpace(message.Title) == "" || strings.TrimSpace(message.Body) == "" {
		return ProviderResult{Outcome: ProviderPermanentFailure, ErrorCode: "invalid_push_message"}
	}
	if len([]byte(message.Title)) > maxPushTitleBytes || len([]byte(message.Body)) > maxPushBodyBytes {
		return ProviderResult{Outcome: ProviderPermanentFailure, ErrorCode: "push_content_too_large"}
	}
	if d == nil || d.provider == nil {
		return ProviderResult{Outcome: ProviderDisabled, ErrorCode: "provider_disabled"}
	}
	return d.provider.SendPush(ctx, message)
}

type EmailCategory string

const (
	EmailCategorySecurity EmailCategory = "security"
	EmailCategoryGeneral  EmailCategory = "general"
)

func EligibleForEmail(prefs *db.CommunicationPreferences, category EmailCategory) bool {
	if prefs == nil {
		return true
	}
	if category == EmailCategorySecurity {
		return prefs.SecurityEmailEnabled
	}
	return prefs.GeneralEmailEnabled
}

func EligiblePushDevices(prefs *db.CommunicationPreferences, devices []db.DeviceRegistration) []db.DeviceRegistration {
	if prefs != nil && !prefs.PushEnabled {
		return nil
	}
	eligible := make([]db.DeviceRegistration, 0, len(devices))
	for _, device := range devices {
		if device.Enabled && strings.TrimSpace(device.DeviceToken) != "" {
			eligible = append(eligible, device)
		}
	}
	return eligible
}

func IsInvalidDeviceToken(result ProviderResult) bool {
	if result.Outcome != ProviderPermanentFailure {
		return false
	}
	switch safeProviderCode(result.ErrorCode) {
	case "invalid_token", "invalid_registration_token", "registration_token_not_registered", "unregistered":
		return true
	default:
		return false
	}
}

func safeProviderCode(code string) string {
	code = strings.ToLower(strings.TrimSpace(code))
	if code == "" {
		return ""
	}
	if strings.Contains(code, "token") || strings.Contains(code, "secret") || strings.Contains(code, "password") || strings.Contains(code, "bearer") || strings.Contains(code, "authorization") {
		if strings.Contains(code, "invalid") || strings.Contains(code, "unregister") || strings.Contains(code, "not_registered") {
			return "invalid_token"
		}
		return "provider_error"
	}
	var b strings.Builder
	for _, r := range code {
		if (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') || r == '_' || r == '-' || r == '.' {
			b.WriteRune(r)
		}
		if b.Len() == 64 {
			break
		}
	}
	if b.Len() == 0 {
		return "provider_error"
	}
	return b.String()
}

// RedactProviderError returns a bounded classification, never the provider's
// original text. It is safe for logs and structured job/audit metadata.
func RedactProviderError(err error) string {
	if err == nil {
		return ""
	}
	text := strings.ToLower(err.Error())
	switch {
	case strings.Contains(text, "deadline"), strings.Contains(text, "timeout"):
		return "timeout"
	case strings.Contains(text, "invalid") && strings.Contains(text, "token"):
		return "invalid_token"
	case strings.Contains(text, "unauthoriz"), strings.Contains(text, "forbidden"):
		return "provider_unauthorized"
	case strings.Contains(text, "unavailable"), strings.Contains(text, "connection"), strings.Contains(text, "temporary"):
		return "provider_unavailable"
	default:
		return "provider_error"
	}
}

func emailContentErrorCode(err error) string {
	if errors.Is(err, ErrEmailContentTooLarge) {
		return "email_content_too_large"
	}
	return "invalid_email_content"
}

// Keep utf8 imported deliberately: bounds are byte-based for storage, while
// malformed UTF-8 must still be rejected before rendering.
func validUTF8(value string) bool { return utf8.ValidString(value) }

func (m PushMessage) String() string {
	return fmt.Sprintf("push message title=%d body=%d", len(m.Title), len(m.Body))
}
