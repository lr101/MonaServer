package config

import (
	"os"
	"testing"
	"time"
)

func TestLoadReadsRustfsObjectStorageVariables(t *testing.T) {
	t.Setenv("RUSTFS_ENDPOINT", "rustfs.internal:9000")
	t.Setenv("RUSTFS_EXTERNAL_ENDPOINT", "objects.example.com")
	t.Setenv("RUSTFS_ACCESS_KEY", "access")
	t.Setenv("RUSTFS_SECRET_KEY", "secret")
	t.Setenv("RUSTFS_BUCKET", "bucket")
	t.Setenv("RUSTFS_USE_SSL", "true")

	cfg, err := Load()
	if err != nil {
		t.Fatalf("load config: %v", err)
	}
	if cfg.RustfsEndpoint != "rustfs.internal:9000" || cfg.RustfsExternalEndpoint != "objects.example.com" || cfg.RustfsAccessKey != "access" || cfg.RustfsSecretKey != "secret" || cfg.RustfsBucket != "bucket" || !cfg.RustfsUseSSL {
		t.Fatalf("RustFS variables were not loaded: %+v", cfg)
	}
}

func TestLoadReadsV3FeatureFlags(t *testing.T) {
	t.Setenv("PUBLIC_EMAIL_LOGIN", "true")
	t.Setenv("WEB_ADMIN_API", "true")

	cfg, err := Load()
	if err != nil {
		t.Fatalf("load config: %v", err)
	}
	if !cfg.PublicEmailLogin || !cfg.WebAdminAPI {
		t.Fatalf("v3 feature flags were not loaded: %+v", cfg)
	}
}

func TestLoadDisablesWebAdminAPIFromEnvironment(t *testing.T) {
	t.Setenv("WEB_ADMIN_API", "false")

	cfg, err := Load()
	if err != nil {
		t.Fatalf("load config: %v", err)
	}
	if cfg.WebAdminAPI {
		t.Fatal("WEB_ADMIN_API=false was not preserved")
	}
}

func TestLoadEnablesAdminSessionRoutesByDefault(t *testing.T) {
	previous, present := os.LookupEnv("WEB_ADMIN_API")
	if err := os.Unsetenv("WEB_ADMIN_API"); err != nil {
		t.Fatalf("unset WEB_ADMIN_API: %v", err)
	}
	t.Cleanup(func() {
		if present {
			_ = os.Setenv("WEB_ADMIN_API", previous)
		} else {
			_ = os.Unsetenv("WEB_ADMIN_API")
		}
	})

	cfg, err := Load()
	if err != nil {
		t.Fatalf("load config: %v", err)
	}
	if !cfg.WebAdminAPI {
		t.Fatal("WEB_ADMIN_API default disabled the browser session bootstrap")
	}
}

func TestLoadReadsAdminAuthDurationsAndQuotaLimits(t *testing.T) {
	t.Setenv("ADMIN_SESSION_IDLE_TTL", "11m")
	t.Setenv("ADMIN_SESSION_ABSOLUTE_TTL", "12h")
	t.Setenv("ADMIN_CHALLENGE_TTL", "13m")
	t.Setenv("ADMIN_RECENT_MFA_TTL", "14m")
	t.Setenv("ADMIN_PREAUTH_TTL", "15m")
	t.Setenv("ADMIN_LOGIN_FAILURE_LIMIT", "7")
	t.Setenv("ADMIN_LOGIN_IP_LIMIT", "8")
	t.Setenv("ADMIN_LOGIN_GLOBAL_LIMIT", "9")

	cfg, err := Load()
	if err != nil {
		t.Fatalf("load config: %v", err)
	}
	if cfg.AdminSessionIdleTTL != 11*time.Minute || cfg.AdminSessionAbsoluteTTL != 12*time.Hour ||
		cfg.AdminChallengeTTL != 13*time.Minute || cfg.AdminRecentMFATTL != 14*time.Minute || cfg.AdminPreAuthTTL != 15*time.Minute {
		t.Fatalf("admin auth durations were not loaded: %+v", cfg)
	}
	if cfg.AdminLoginFailureLimit != 7 || cfg.AdminLoginIPLimit != 8 || cfg.AdminLoginGlobalLimit != 9 {
		t.Fatalf("admin auth limits were not loaded: %+v", cfg)
	}
}

func TestLoadReadsInitialAdminBootstrapCredentials(t *testing.T) {
	t.Setenv("ADMIN_BOOTSTRAP_USERNAME", "env-operator")
	t.Setenv("ADMIN_BOOTSTRAP_PASSWORD", "initial-password-123")
	t.Setenv("ADMIN_BOOTSTRAP_TOTP_SECRET", "example-seed")
	cfg, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	if cfg.AdminBootstrapUsername != "env-operator" || cfg.AdminBootstrapPassword != "initial-password-123" ||
		cfg.AdminBootstrapTOTPSecret != "example-seed" {
		t.Fatal("initial admin bootstrap credentials were not loaded")
	}
}
