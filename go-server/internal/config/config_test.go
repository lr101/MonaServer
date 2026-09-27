package config

import (
	"os"
	"testing"
	"time"
)

func TestLoadIgnoresLegacyMinioObjectStorageVariables(t *testing.T) {
	for _, name := range []string{
		"RUSTFS_ENDPOINT",
		"RUSTFS_EXTERNAL_ENDPOINT",
		"RUSTFS_ACCESS_KEY",
		"RUSTFS_SECRET_KEY",
		"RUSTFS_BUCKET",
		"RUSTFS_USE_SSL",
		"RUSTFS_EXTERNAL_USE_SSL",
	} {
		t.Setenv(name, "")
	}
	t.Setenv("MINIO_ENDPOINT", "minio.internal:9000")
	t.Setenv("MINIO_EXTERNAL_ENDPOINT", "objects.example.com")
	t.Setenv("MINIO_ACCESS_KEY", "legacy-access")
	t.Setenv("MINIO_SECRET_KEY", "legacy-secret")
	t.Setenv("MINIO_BUCKET", "legacy-bucket")
	t.Setenv("MINIO_USE_SSL", "true")
	t.Setenv("MINIO_EXTERNAL_USE_SSL", "false")

	cfg, err := Load()
	if err != nil {
		t.Fatalf("load config: %v", err)
	}
	if cfg.RustfsEndpoint != "" || cfg.RustfsExternalEndpoint != "" ||
		cfg.RustfsAccessKey != "" || cfg.RustfsSecretKey != "" || cfg.RustfsBucket != "monaserver" ||
		cfg.RustfsUseSSL || cfg.RustfsExternalUseSSL {
		t.Fatalf("legacy MINIO variables affected RustFS configuration: %+v", cfg)
	}
}

func TestPublicWebURLUsesWebHost(t *testing.T) {
	cases := []struct {
		name string
		host string
		want string
	}{
		{name: "hostname", host: " app.example.com/ ", want: "https://app.example.com"},
		{name: "full URL", host: " http://app.example.com/ ", want: "http://app.example.com"},
		{name: "unset", want: ""},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			cfg := &Config{WebHost: tc.host}
			if got := cfg.PublicWebURL(); got != tc.want {
				t.Fatalf("PublicWebURL() = %q, want %q", got, tc.want)
			}
		})
	}
}

func TestLoadUsesSeparateExternalObjectStorageTLS(t *testing.T) {
	t.Setenv("RUSTFS_USE_SSL", "false")
	t.Setenv("RUSTFS_EXTERNAL_USE_SSL", "true")

	cfg, err := Load()
	if err != nil {
		t.Fatalf("load config: %v", err)
	}
	if cfg.RustfsUseSSL {
		t.Fatal("expected internal RustFS TLS to remain disabled")
	}
	if !cfg.RustfsExternalUseSSL {
		t.Fatal("expected external RustFS TLS to be enabled independently")
	}
}

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

func TestLoadReadsWebHost(t *testing.T) {
	t.Setenv("WEB_HOST", "app.example.com")

	cfg, err := Load()
	if err != nil {
		t.Fatalf("load config: %v", err)
	}
	if cfg.WebHost != "app.example.com" {
		t.Fatalf("WEB_HOST = %q, want app.example.com", cfg.WebHost)
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
	t.Setenv("ADMIN_PREAUTH_TTL", "15m")
	t.Setenv("ADMIN_LOGIN_FAILURE_LIMIT", "7")
	t.Setenv("ADMIN_LOGIN_IP_LIMIT", "8")
	t.Setenv("ADMIN_LOGIN_GLOBAL_LIMIT", "9")

	cfg, err := Load()
	if err != nil {
		t.Fatalf("load config: %v", err)
	}
	if cfg.AdminSessionIdleTTL != 11*time.Minute || cfg.AdminSessionAbsoluteTTL != 12*time.Hour ||
		cfg.AdminChallengeTTL != 13*time.Minute || cfg.AdminPreAuthTTL != 15*time.Minute {
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
