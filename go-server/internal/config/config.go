package config

import (
	"time"

	"github.com/spf13/viper"
)

type Config struct {
	// Server
	Port       string `mapstructure:"PORT"`
	AppURL     string `mapstructure:"APP_URL"`
	RedirectURL string `mapstructure:"APP_REDIRECT_URL"`

	// Database
	DatabaseURL string `mapstructure:"DATABASE_URL"`

	// JWT
	JWTSecret             string        `mapstructure:"JWT_SECRET"`
	AccessTokenExpiry     time.Duration `mapstructure:"TOKEN_ACCESS_EXPIRY"`
	RefreshTokenExpiry    time.Duration `mapstructure:"TOKEN_REFRESH_EXPIRY"`
	AdminUsername         string        `mapstructure:"TOKEN_ADMIN_USERNAME"`
	MaxLoginAttempts      int           `mapstructure:"APP_MAX_LOGIN_ATTEMPTS"`

	// MinIO
	MinioEndpoint   string `mapstructure:"MINIO_ENDPOINT"`
	MinioAccessKey  string `mapstructure:"MINIO_ACCESS_KEY"`
	MinioSecretKey  string `mapstructure:"MINIO_SECRET_KEY"`
	MinioBucket     string `mapstructure:"MINIO_BUCKET"`
	MinioUseSSL     bool   `mapstructure:"MINIO_USE_SSL"`
	MinioURLExpiry  time.Duration `mapstructure:"MINIO_URL_EXPIRY"`

	// Mail
	MailHost     string `mapstructure:"MAIL_HOST"`
	MailPort     int    `mapstructure:"MAIL_PORT"`
	MailUsername string `mapstructure:"MAIL_USERNAME"`
	MailPassword string `mapstructure:"MAIL_PASSWORD"`
	MailFrom     string `mapstructure:"MAIL_FROM"`

	// Firebase
	FirebaseConfigPath string `mapstructure:"FIREBASE_CONFIG_PATH"`
}

func Load() (*Config, error) {
	v := viper.New()
	v.AutomaticEnv()

	// Viper's Unmarshal does not consult AutomaticEnv unless keys have been
	// bound or seeded; explicitly bind every tag used below.
	for _, k := range []string{
		"PORT", "APP_URL", "APP_REDIRECT_URL", "DATABASE_URL",
		"JWT_SECRET", "TOKEN_ACCESS_EXPIRY", "TOKEN_REFRESH_EXPIRY",
		"TOKEN_ADMIN_USERNAME", "APP_MAX_LOGIN_ATTEMPTS",
		"MINIO_ENDPOINT", "MINIO_ACCESS_KEY", "MINIO_SECRET_KEY",
		"MINIO_BUCKET", "MINIO_USE_SSL", "MINIO_URL_EXPIRY",
		"MAIL_HOST", "MAIL_PORT", "MAIL_USERNAME", "MAIL_PASSWORD", "MAIL_FROM",
		"FIREBASE_CONFIG_PATH",
	} {
		_ = v.BindEnv(k)
	}

	v.SetDefault("PORT", "8081")
	v.SetDefault("TOKEN_ACCESS_EXPIRY", 15*time.Minute)
	v.SetDefault("TOKEN_REFRESH_EXPIRY", 365*24*time.Hour)
	v.SetDefault("APP_MAX_LOGIN_ATTEMPTS", 10)
	v.SetDefault("MINIO_BUCKET", "monaserver")
	v.SetDefault("MINIO_USE_SSL", false)
	v.SetDefault("MINIO_URL_EXPIRY", 60*time.Minute)
	v.SetDefault("MAIL_PORT", 587)

	var cfg Config
	if err := v.Unmarshal(&cfg); err != nil {
		return nil, err
	}
	return &cfg, nil
}
