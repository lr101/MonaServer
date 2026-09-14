package config

import "testing"

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
