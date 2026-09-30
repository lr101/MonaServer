package main

import (
	"net/url"
	"strings"
	"testing"
)

func TestParseCommandRequiresExplicitOperatorOperation(t *testing.T) {
	if _, err := parseAdminAuthCommand(nil); err == nil {
		t.Fatal("empty command unexpectedly succeeded")
	}
	if _, err := parseAdminAuthCommand([]string{"--username", "operator"}); err == nil {
		t.Fatal("missing operation unexpectedly succeeded")
	}
}

func TestParseCommandBoundsAndNormalizesEnrollment(t *testing.T) {
	options, err := parseAdminAuthCommand([]string{
		"enroll", "--username", " operator ", "--permissions", "users.read, security.revoke,users.read",
	})
	if err != nil {
		t.Fatalf("parse command: %v", err)
	}
	if options.operation != "enroll" || options.username != "operator" {
		t.Fatalf("options = %#v", options)
	}
	if got := strings.Join(options.permissions, ","); got != "security.revoke,users.read" {
		t.Fatalf("permissions = %q", got)
	}
}

func TestParseCommandRequiresPermissionsForBootstrapAndEnrollment(t *testing.T) {
	for _, operation := range []string{"bootstrap", "enroll"} {
		if _, err := parseAdminAuthCommand([]string{operation, "--username", "operator"}); err == nil {
			t.Fatalf("%s without permissions unexpectedly succeeded", operation)
		}
	}
	if _, err := parseAdminAuthCommand([]string{"recover-mfa", "--username", "operator"}); err == nil {
		t.Fatal("recover-mfa without actor unexpectedly succeeded")
	}
}

func TestParseCommandRequiresNonNilActorForRecovery(t *testing.T) {
	options, err := parseAdminAuthCommand([]string{
		"recover-mfa", "--username", "operator", "--actor-id", "11111111-1111-1111-1111-111111111111",
	})
	if err != nil {
		t.Fatalf("parse recover-mfa: %v", err)
	}
	if options.actorID == nil || options.actorID.String() != "11111111-1111-1111-1111-111111111111" {
		t.Fatalf("recover actor = %#v", options.actorID)
	}
	if _, err := parseAdminAuthCommand([]string{
		"recover-mfa", "--username", "operator", "--actor-id", "00000000-0000-0000-0000-000000000000",
	}); err == nil {
		t.Fatal("nil recovery actor unexpectedly succeeded")
	}
}

func TestAdminAuthDatabaseURLUsesComposePostgresEnvironment(t *testing.T) {
	t.Setenv("DATABASE_URL", "")
	t.Setenv("POSTGRES_USER", "operator")
	t.Setenv("POSTGRES_PASSWORD", "p@ss:word")
	t.Setenv("POSTGRES_HOST", "")
	t.Setenv("POSTGRES_PORT", "")
	t.Setenv("POSTGRES_DB", "")

	raw, err := adminAuthDatabaseURL()
	if err != nil {
		t.Fatalf("admin-auth database URL: %v", err)
	}
	dsn, err := url.Parse(raw)
	if err != nil {
		t.Fatalf("parse admin-auth database URL: %v", err)
	}
	username := dsn.User.Username()
	password, ok := dsn.User.Password()
	if !ok || username != "operator" || password != "p@ss:word" {
		t.Fatal("database credentials did not round-trip")
	}
	if dsn.Host != "db:5432" || dsn.Path != "/monaserver" || dsn.Query().Get("sslmode") != "disable" {
		t.Fatal("compose database URL has unexpected host, database, or SSL mode")
	}
}

func TestAdminAuthDatabaseURLPrefersExplicitDSN(t *testing.T) {
	want := "postgres://configured:secret@db.internal:5544/custom?sslmode=require"
	t.Setenv("DATABASE_URL", want)
	t.Setenv("POSTGRES_USER", "")
	t.Setenv("POSTGRES_PASSWORD", "")

	dsn, err := adminAuthDatabaseURL()
	if err != nil {
		t.Fatalf("admin-auth database URL: %v", err)
	}
	if dsn != want {
		t.Fatal("explicit DATABASE_URL was not preserved")
	}
}
