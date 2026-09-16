package service

import (
	"context"
	"errors"
	"net"
	"strings"

	"firebase.google.com/go/v4/messaging"
	"github.com/wneessen/go-mail"
)

// SMTPEmailProvider adapts the existing Email transport to the structured
// delivery seam. A missing Email/config is reported as disabled instead of a
// false success.
type SMTPEmailProvider struct{ email *Email }

func NewSMTPEmailProvider(email *Email) *SMTPEmailProvider { return &SMTPEmailProvider{email: email} }

func (p *SMTPEmailProvider) SendEmail(ctx context.Context, message RenderedEmail) ProviderResult {
	if p == nil || p.email == nil || p.email.cfg == nil || strings.TrimSpace(p.email.cfg.MailHost) == "" {
		return ProviderResult{Outcome: ProviderDisabled, ErrorCode: "provider_disabled"}
	}
	if !validRecipient(message.To) || hasControlHeaderByte(message.Subject) {
		return ProviderResult{Outcome: ProviderPermanentFailure, ErrorCode: "invalid_email_message"}
	}
	msg := mail.NewMsg()
	if err := msg.From(p.email.cfg.MailFrom); err != nil {
		return ProviderResult{Outcome: ProviderPermanentFailure, ErrorCode: "invalid_sender"}
	}
	if err := msg.To(message.To); err != nil {
		return ProviderResult{Outcome: ProviderPermanentFailure, ErrorCode: "invalid_recipient"}
	}
	msg.Subject(message.Subject)
	msg.SetBodyString(mail.TypeTextPlain, message.Text)
	if message.HTML != "" {
		msg.AddAlternativeString(mail.TypeTextHTML, message.HTML)
	}
	client, err := p.email.client()
	if err != nil {
		return ProviderResult{Outcome: ProviderPermanentFailure, ErrorCode: "smtp_configuration"}
	}
	if err := client.DialAndSendWithContext(ctx, msg); err != nil {
		return classifySMTPError(ctx, err)
	}
	return ProviderResult{Outcome: ProviderAccepted}
}

func classifySMTPError(ctx context.Context, err error) ProviderResult {
	if err == nil {
		return ProviderResult{Outcome: ProviderAccepted}
	}
	if ctx != nil && ctx.Err() != nil {
		// Once SMTP has begun, cancellation cannot prove whether the server
		// accepted the message. Preserve uncertainty for bounded retry policy.
		return ProviderResult{Outcome: ProviderUnknownDelivery, ErrorCode: "ack_timeout"}
	}
	var netErr net.Error
	if errors.As(err, &netErr) && (netErr.Timeout() || netErr.Temporary()) {
		return ProviderResult{Outcome: ProviderTransientFailure, ErrorCode: "smtp_timeout"}
	}
	text := strings.ToLower(err.Error())
	if strings.Contains(text, "timeout") || strings.Contains(text, "temporar") || strings.Contains(text, "connection") || strings.Contains(text, "unavailable") || strings.Contains(text, "try again") {
		return ProviderResult{Outcome: ProviderTransientFailure, ErrorCode: RedactProviderError(err)}
	}
	if strings.Contains(text, "mailbox") || strings.Contains(text, "recipient") || strings.Contains(text, "address") || strings.Contains(text, "5.") {
		return ProviderResult{Outcome: ProviderPermanentFailure, ErrorCode: "smtp_rejected"}
	}
	return ProviderResult{Outcome: ProviderUnknownDelivery, ErrorCode: "smtp_unknown"}
}

// FirebasePushProvider adapts the existing FCM client. Disabled/unavailable
// configuration is explicit; it is never represented as provider acceptance.
type FirebasePushProvider struct{ notification *Notification }

func NewFirebasePushProvider(notification *Notification) *FirebasePushProvider {
	return &FirebasePushProvider{notification: notification}
}

func (p *FirebasePushProvider) SendPush(ctx context.Context, message PushMessage) ProviderResult {
	if p == nil || p.notification == nil || !p.notification.enabled || p.notification.client == nil {
		return ProviderResult{Outcome: ProviderDisabled, ErrorCode: "provider_disabled"}
	}
	if strings.TrimSpace(message.Token) == "" {
		return ProviderResult{Outcome: ProviderPermanentFailure, ErrorCode: "invalid_token"}
	}
	ref, err := p.notification.client.Send(ctx, &messaging.Message{
		Token:        message.Token,
		Notification: &messaging.Notification{Title: message.Title, Body: message.Body},
	})
	if err != nil {
		return classifyFCMError(ctx, err)
	}
	return ProviderResult{Outcome: ProviderAccepted, Reference: ref}
}

func classifyFCMError(ctx context.Context, err error) ProviderResult {
	if err == nil {
		return ProviderResult{Outcome: ProviderAccepted}
	}
	if ctx != nil && ctx.Err() != nil {
		return ProviderResult{Outcome: ProviderUnknownDelivery, ErrorCode: "ack_timeout"}
	}
	text := strings.ToLower(err.Error())
	if strings.Contains(text, "registration-token-not-registered") || strings.Contains(text, "invalid-registration-token") || strings.Contains(text, "not registered") {
		return ProviderResult{Outcome: ProviderPermanentFailure, ErrorCode: "invalid_registration_token"}
	}
	if strings.Contains(text, "deadline") || strings.Contains(text, "timeout") || strings.Contains(text, "unavailable") || strings.Contains(text, "temporar") || strings.Contains(text, "connection") || strings.Contains(text, "resource exhausted") {
		return ProviderResult{Outcome: ProviderTransientFailure, ErrorCode: RedactProviderError(err)}
	}
	if strings.Contains(text, "invalid argument") || strings.Contains(text, "invalid request") || strings.Contains(text, "malformed") || strings.Contains(text, "sender id mismatch") {
		return ProviderResult{Outcome: ProviderPermanentFailure, ErrorCode: "provider_rejected"}
	}
	// An unrecognized Firebase response cannot prove that the provider did not
	// accept the message. Preserve uncertainty so the bounded retry path can
	// make the duplicate/ack-loss tradeoff explicitly.
	return ProviderResult{Outcome: ProviderUnknownDelivery, ErrorCode: "provider_unknown"}
}
