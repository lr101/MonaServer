// Command admin-auth performs explicit local operator enrollment and MFA
// recovery. It is intentionally separate from the HTTP server: browser
// requests and consumer credentials can never grant an admin membership.
package main

import (
	"context"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"strings"

	"github.com/google/uuid"
	"github.com/lrprojects/monaserver/internal/db"
	"github.com/lrprojects/monaserver/internal/service"
)

type adminAuthCommandOptions struct {
	operation   string
	username    string
	permissions []string
	actorID     *uuid.UUID
}

func main() {
	if err := runAdminAuthCommand(os.Args[1:], os.Stdout, os.Stderr); err != nil {
		fmt.Fprintln(os.Stderr, "admin-auth:", err)
		os.Exit(1)
	}
}

func parseAdminAuthCommand(args []string) (adminAuthCommandOptions, error) {
	if len(args) == 0 {
		return adminAuthCommandOptions{}, errors.New("operation is required (bootstrap, enroll, or recover-mfa)")
	}
	operation := strings.TrimSpace(args[0])
	if operation != "bootstrap" && operation != "enroll" && operation != "recover-mfa" {
		return adminAuthCommandOptions{}, fmt.Errorf("unknown operation %q", operation)
	}
	flags := flag.NewFlagSet("admin-auth "+operation, flag.ContinueOnError)
	flags.SetOutput(io.Discard)
	username := flags.String("username", "", "existing user account to enroll or recover")
	permissionText := flags.String("permissions", "", "comma-separated stable admin capabilities")
	actorText := flags.String("actor-id", "", "auditing actor UUID for break-glass recovery")
	if err := flags.Parse(args[1:]); err != nil {
		return adminAuthCommandOptions{}, err
	}
	if flags.NArg() != 0 {
		return adminAuthCommandOptions{}, fmt.Errorf("unexpected arguments: %s", strings.Join(flags.Args(), " "))
	}
	usernameValue := strings.TrimSpace(*username)
	if usernameValue == "" {
		return adminAuthCommandOptions{}, errors.New("--username is required")
	}
	permissions := normalizePermissions(*permissionText)
	if (operation == "bootstrap" || operation == "enroll") && len(permissions) == 0 {
		return adminAuthCommandOptions{}, errors.New("--permissions is required for bootstrap/enroll")
	}
	var actorID *uuid.UUID
	if actorTextValue := strings.TrimSpace(*actorText); actorTextValue != "" {
		parsed, err := uuid.Parse(actorTextValue)
		if err != nil {
			return adminAuthCommandOptions{}, errors.New("--actor-id must be a UUID")
		}
		actorID = &parsed
	}
	if operation != "recover-mfa" && actorID != nil {
		return adminAuthCommandOptions{}, errors.New("--actor-id is only valid with recover-mfa")
	}
	return adminAuthCommandOptions{operation: operation, username: usernameValue, permissions: permissions, actorID: actorID}, nil
}

func normalizePermissions(raw string) []string {
	if strings.TrimSpace(raw) == "" {
		return nil
	}
	parts := strings.Split(raw, ",")
	return service.CapabilitiesForPermissions(parts)
}

func runAdminAuthCommand(args []string, stdout, stderr io.Writer) error {
	options, err := parseAdminAuthCommand(args)
	if err != nil {
		return err
	}
	dsn := strings.TrimSpace(os.Getenv("DATABASE_URL"))
	if dsn == "" {
		return errors.New("DATABASE_URL is required")
	}
	encryptionKey, err := keyFromEnv("ADMIN_TOTP_ENCRYPTION_KEY", true)
	if err != nil {
		return err
	}
	hmacKey, err := keyFromEnv("ADMIN_SESSION_HMAC_KEY", false)
	if err != nil {
		return err
	}
	if err := db.RunMigrations(dsn); err != nil {
		return errors.New("database migrations failed")
	}
	ctx := context.Background()
	pool, err := db.NewPool(ctx, dsn)
	if err != nil {
		return errors.New("database connection failed")
	}
	defer pool.Close()
	auth := service.NewAdminAuth(db.New(pool), service.AdminAuthConfig{
		EncryptionKey:   encryptionKey,
		EncryptionKeyID: strings.TrimSpace(os.Getenv("ADMIN_TOTP_ENCRYPTION_KEY_ID")),
		HMACKey:         hmacKey,
		HMACKeyID:       strings.TrimSpace(os.Getenv("ADMIN_SESSION_HMAC_KEY_ID")),
	})
	switch options.operation {
	case "bootstrap", "enroll":
		result, err := auth.EnrollAdminOperator(ctx, options.username, options.permissions)
		if err != nil {
			return err
		}
		if result.AlreadyEnrolled {
			_, _ = fmt.Fprintf(stdout, "operator=%s\nstatus=already_enrolled\n", result.UserID)
			return nil
		}
		// The secret is the deliberate one-time operator handoff. It is never
		// emitted by the HTTP API, logs, audit rows, or error strings.
		_, _ = fmt.Fprintf(stdout, "operator=%s\nstatus=enrolled\ntotp_secret=%s\n", result.UserID, result.Secret)
		return nil
	case "recover-mfa":
		result, err := auth.BreakGlassRecoverAdminMFA(ctx, options.username, options.actorID)
		if err != nil {
			return err
		}
		_, _ = fmt.Fprintf(stdout, "operator=%s\nstatus=mfa_recovered\ntotp_secret=%s\n", result.UserID, result.Secret)
		return nil
	default:
		return errors.New("unsupported operation")
	}
}

func keyFromEnv(name string, encryption bool) ([]byte, error) {
	raw := strings.TrimSpace(os.Getenv(name))
	if raw == "" {
		return nil, fmt.Errorf("%s is required", name)
	}
	// Deployment values may be supplied as hex or standard/raw base64. A
	// printable raw value remains supported for local-only environments.
	if decoded, err := hex.DecodeString(raw); err == nil && len(decoded) > 0 {
		raw = string(decoded)
	} else if decoded, err := base64.RawStdEncoding.DecodeString(raw); err == nil && len(decoded) > 0 {
		raw = string(decoded)
	} else if decoded, err := base64.StdEncoding.DecodeString(raw); err == nil && len(decoded) > 0 {
		raw = string(decoded)
	}
	key := []byte(raw)
	if encryption {
		switch len(key) {
		case 16, 24, 32:
		default:
			return nil, fmt.Errorf("%s must decode to 16, 24, or 32 bytes", name)
		}
	}
	if len(key) < 16 {
		return nil, fmt.Errorf("%s must be at least 16 bytes", name)
	}
	return key, nil
}
