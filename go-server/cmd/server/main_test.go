package main

import (
	"testing"

	"github.com/lrprojects/monaserver/internal/config"
)

func TestNewMailServiceRequiresSMTPHost(t *testing.T) {
	if got := newMailService(&config.Config{}); got != nil {
		t.Fatal("mail service should be disabled when MAIL_HOST is unset")
	}

	if got := newMailService(&config.Config{MailHost: "127.0.0.1"}); got == nil {
		t.Fatal("mail service should be enabled when MAIL_HOST is configured")
	}
}
