package main

import (
	"context"
	"encoding/base32"
	"os"
	"testing"

	"github.com/lrprojects/monaserver/internal/config"
	"github.com/lrprojects/monaserver/internal/db"
	"github.com/lrprojects/monaserver/internal/service"
)

func TestConfiguredAdminBootstrapCreatesAccountBeforeServing(t *testing.T) {
	dsn := os.Getenv("TEST_DATABASE_URL")
	if dsn == "" {
		t.Skip("TEST_DATABASE_URL not set")
	}
	if err := db.RunMigrations(dsn); err != nil {
		t.Fatal(err)
	}
	pool, err := db.NewPool(context.Background(), dsn)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(pool.Close)
	ctx := context.Background()
	if _, err := pool.Exec(ctx, `TRUNCATE TABLE admin_initial_setup_claims, users CASCADE`); err != nil {
		t.Fatal(err)
	}
	q := db.New(pool)
	admin := service.NewAdminAuth(q, service.AdminAuthConfig{
		EncryptionKey: []byte("0123456789abcdef0123456789abcdef"),
		HMACKey:       []byte("bootstrap-quota-key-32-bytes-long!!"),
	})
	cfg := &config.Config{
		AdminBootstrapUsername:   "startup-operator",
		AdminBootstrapPassword:   "startup-password-123",
		AdminBootstrapTOTPSecret: base32.StdEncoding.WithPadding(base32.NoPadding).EncodeToString([]byte("12345678901234567890")),
	}
	created, err := bootstrapConfiguredAdmin(ctx, admin, cfg)
	if err != nil || !created {
		t.Fatalf("startup bootstrap created = %v, err = %v", created, err)
	}
	user, err := q.GetUserByUsername(ctx, "startup-operator")
	if err != nil || user == nil {
		t.Fatalf("startup account = %#v, err = %v", user, err)
	}
	if membership, err := q.GetAdminMembership(ctx, user.ID); err != nil || membership == nil || !membership.Active {
		t.Fatalf("startup membership = %#v, err = %v", membership, err)
	}
}
