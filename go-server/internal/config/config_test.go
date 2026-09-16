package config

import (
	"os"
	"testing"
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
