package service

import (
	"context"
	"log/slog"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/messaging"
	"google.golang.org/api/option"
)

// Notification wraps Firebase Cloud Messaging. Optional: if configPath is empty
// or init fails, the service is still usable but sends become no-ops (matches
// the Kotlin FirebaseConfig fallback).
type Notification struct {
	client  *messaging.Client
	enabled bool
}

func NewNotification(ctx context.Context, configPath string) *Notification {
	if configPath == "" {
		slog.Warn("firebase config path empty; notifications disabled")
		return &Notification{enabled: false}
	}
	app, err := firebase.NewApp(ctx, nil, option.WithCredentialsFile(configPath))
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
