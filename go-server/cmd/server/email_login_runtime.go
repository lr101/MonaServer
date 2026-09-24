package main

import (
	"errors"
	"net"
	"net/url"
	"strings"
	"time"

	"github.com/lrprojects/monaserver/internal/config"
	"github.com/lrprojects/monaserver/internal/db"
	"github.com/lrprojects/monaserver/internal/jobs"
	"github.com/lrprojects/monaserver/internal/service"
	"github.com/lrprojects/monaserver/internal/token"
)

// newEmailLoginRuntime installs the public auth service and delivery worker
// together. A disabled feature creates neither; an enabled feature requires
// explicit secrets, callback URL, and SMTP configuration before startup.
func newEmailLoginRuntime(cfg *config.Config, q *db.Queries, security *service.AccountSecurity, tok *token.Helper, mail *service.Email) (*service.EmailLogin, *jobs.Worker, error) {
	if cfg == nil || !cfg.PublicEmailLogin {
		return nil, nil, nil
	}
	if q == nil || security == nil || tok == nil || mail == nil ||
		len(decodeAdminKey(cfg.EmailLoginHMACKey)) < 32 || strings.TrimSpace(cfg.EmailLoginHMACKeyID) == "" ||
		strings.TrimSpace(cfg.EmailDeliveryKeyID) == "" || strings.TrimSpace(cfg.EmailLoginCallbackURL) == "" ||
		strings.TrimSpace(cfg.MailFrom) == "" {
		return nil, nil, errors.New("email login requires database, SMTP, callback URL, and explicit keys")
	}
	callback, err := url.Parse(cfg.EmailLoginCallbackURL)
	if err != nil || callback.Hostname() == "" ||
		(callback.Scheme != "https" && (callback.Scheme != "http" || !isLoopbackHost(callback.Hostname()))) ||
		(callback.Fragment != "/email-login/callback" && callback.Fragment != "/email-login/callback?token=") {
		return nil, nil, errors.New("email login callback URL must be an HTTPS Flutter web callback")
	}
	// Campaign login links live for 24 hours, so encrypted delivery payloads
	// need the same maximum. Public login payloads still expire with their
	// shorter 15-minute action token.
	ring, err := service.NewDeliveryKeyRing(map[string][]byte{
		cfg.EmailDeliveryKeyID: decodeAdminKey(cfg.EmailDeliveryKey),
	}, cfg.EmailDeliveryKeyID, 24*time.Hour)
	if err != nil {
		return nil, nil, err
	}
	login := service.NewEmailLogin(q, security, tok, service.EmailLoginConfig{
		HMACKeyID:       cfg.EmailLoginHMACKeyID,
		HMACKey:         decodeAdminKey(cfg.EmailLoginHMACKey),
		CallbackURL:     cfg.EmailLoginCallbackURL,
		DeliveryKeyRing: ring,
	}, nil)
	attempts := service.NewValidatedDeliveryAttemptStore(q, q, ring, nil)
	dispatcher := service.NewDeliveryDispatcher(attempts, ring, service.NewEmailDelivery(service.NewSMTPEmailProvider(mail)), nil, nil)
	worker := jobs.NewWorker(q, jobs.Config{Kinds: []string{service.KindEmailDelivery}})
	if err := service.RegisterDeliveryHandlers(worker, dispatcher); err != nil {
		return nil, nil, err
	}
	return login, worker, nil
}

func isLoopbackHost(host string) bool {
	return host == "localhost" || (net.ParseIP(host) != nil && net.ParseIP(host).IsLoopback())
}
