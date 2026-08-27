package config

import "testing"

func TestLoadAcceptsLegacyMinioObjectStorageVariables(t *testing.T) {
	t.Setenv("RUSTFS_ENDPOINT", "")
	t.Setenv("RUSTFS_EXTERNAL_ENDPOINT", "")
	t.Setenv("RUSTFS_ACCESS_KEY", "")
	t.Setenv("RUSTFS_SECRET_KEY", "")
	t.Setenv("MINIO_ENDPOINT", "minio.internal:9000")
	t.Setenv("MINIO_EXTERNAL_ENDPOINT", "objects.example.com")
	t.Setenv("MINIO_ACCESS_KEY", "legacy-access")
	t.Setenv("MINIO_SECRET_KEY", "legacy-secret")

	cfg, err := Load()
	if err != nil {
		t.Fatalf("load config: %v", err)
	}
	if cfg.RustfsEndpoint != "minio.internal:9000" || cfg.RustfsExternalEndpoint != "objects.example.com" || cfg.RustfsAccessKey != "legacy-access" || cfg.RustfsSecretKey != "legacy-secret" {
		t.Fatalf("legacy MINIO variables were not mapped: %+v", cfg)
	}
}
