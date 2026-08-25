package service

import (
	"context"
	"log/slog"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/messaging"
	"google.golang.org/api/option"
)

// Notification wraps Firebase Cloud Messaging. If explicit credentials are not
// configured, Firebase uses Application Default Credentials.
type Notification struct {
	client  *messaging.Client
	enabled bool
}

func NewNotification(ctx context.Context, configPath string) *Notification {
	app, err := firebase.NewApp(ctx, nil, firebaseOptions(configPath)...)
	if err != nil {
		slog.Warn("firebase init failed; notifications disabled", "err", err)
		return &Notification{enabled: false}
	}
	c, err := app.Messaging(ctx)
	if err != nil {
		slog.Warn("firebase messaging init failed", "err", err)
		return &Notification{enabled: false}
	}
	return &Notification{client: c, enabled: true}
}

func firebaseOptions(configPath string) []option.ClientOption {
	if configPath == "" {
		return nil
	}
	return []option.ClientOption{option.WithCredentialsFile(configPath)}
}

// SendToToken sends a push to a single device token.
func (n *Notification) SendToToken(ctx context.Context, token, title, body string) error {
	if !n.enabled {
		return nil
	}
	_, err := n.client.Send(ctx, &messaging.Message{
		Token:        token,
		Notification: &messaging.Notification{Title: title, Body: body},
	})
	return err
}

// SendToTopic sends a push to all subscribers of a topic (used by AdminController).
func (n *Notification) SendToTopic(ctx context.Context, topic, title, body string) error {
	if !n.enabled {
		return nil
	}
	_, err := n.client.Send(ctx, &messaging.Message{
		Topic:        topic,
		Notification: &messaging.Notification{Title: title, Body: body},
	})
	return err
}
