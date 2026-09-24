package config

import (
	"time"

	"github.com/spf13/viper"
)

type Config struct {
	// Server
	Port        string `mapstructure:"PORT"`
	AppURL      string `mapstructure:"APP_URL"`
	RedirectURL string `mapstructure:"APP_REDIRECT_URL"`

	// Database
	DatabaseURL string `mapstructure:"DATABASE_URL"`

	// JWT
	JWTSecret          string        `mapstructure:"JWT_SECRET"`
	AccessTokenExpiry  time.Duration `mapstructure:"TOKEN_ACCESS_EXPIRY"`
	RefreshTokenExpiry time.Duration `mapstructure:"TOKEN_REFRESH_EXPIRY"`
	AdminUsername      string        `mapstructure:"TOKEN_ADMIN_USERNAME"`
	MaxLoginAttempts   int           `mapstructure:"APP_MAX_LOGIN_ATTEMPTS"`
	PublicEmailLogin   bool          `mapstructure:"PUBLIC_EMAIL_LOGIN"`
	WebAdminAPI        bool          `mapstructure:"WEB_ADMIN_API"`

	// Browser-admin authentication. Keys are supplied as hex, base64, or raw
	// bytes by deployment configuration and are never generated at startup.
	AdminTOTPEncryptionKey   string        `mapstructure:"ADMIN_TOTP_ENCRYPTION_KEY"`
	AdminTOTPEncryptionKeyID string        `mapstructure:"ADMIN_TOTP_ENCRYPTION_KEY_ID"`
	AdminSessionHMACKey      string        `mapstructure:"ADMIN_SESSION_HMAC_KEY"`
	AdminSessionHMACKeyID    string        `mapstructure:"ADMIN_SESSION_HMAC_KEY_ID"`
	AdminFirstRunToken       string        `mapstructure:"ADMIN_FIRST_RUN_TOKEN"`
	AdminBootstrapUsername   string        `mapstructure:"ADMIN_BOOTSTRAP_USERNAME"`
	AdminBootstrapPassword   string        `mapstructure:"ADMIN_BOOTSTRAP_PASSWORD"`
	AdminBootstrapTOTPSecret string        `mapstructure:"ADMIN_BOOTSTRAP_TOTP_SECRET"`
	AdminOrigin              string        `mapstructure:"ADMIN_ORIGIN"`
	TrustedProxyCIDRs        string        `mapstructure:"TRUSTED_PROXY_CIDRS"`
	AdminSessionIdleTTL      time.Duration `mapstructure:"ADMIN_SESSION_IDLE_TTL"`
	AdminSessionAbsoluteTTL  time.Duration `mapstructure:"ADMIN_SESSION_ABSOLUTE_TTL"`
	AdminChallengeTTL        time.Duration `mapstructure:"ADMIN_CHALLENGE_TTL"`
	AdminRecentMFATTL        time.Duration `mapstructure:"ADMIN_RECENT_MFA_TTL"`
	AdminPreAuthTTL          time.Duration `mapstructure:"ADMIN_PREAUTH_TTL"`
	AdminLoginFailureLimit   int64         `mapstructure:"ADMIN_LOGIN_FAILURE_LIMIT"`
	AdminLoginIPLimit        int64         `mapstructure:"ADMIN_LOGIN_IP_LIMIT"`
	AdminLoginGlobalLimit    int64         `mapstructure:"ADMIN_LOGIN_GLOBAL_LIMIT"`

	// RustFS / object storage
	RustfsEndpoint         string        `mapstructure:"RUSTFS_ENDPOINT"`
	RustfsExternalEndpoint string        `mapstructure:"RUSTFS_EXTERNAL_ENDPOINT"`
	RustfsAccessKey        string        `mapstructure:"RUSTFS_ACCESS_KEY"`
	RustfsSecretKey        string        `mapstructure:"RUSTFS_SECRET_KEY"`
	RustfsBucket           string        `mapstructure:"RUSTFS_BUCKET"`
	RustfsUseSSL           bool          `mapstructure:"RUSTFS_USE_SSL"`
	RustfsURLExpiry        time.Duration `mapstructure:"RUSTFS_URL_EXPIRY"`

	// Mail
	MailHost     string `mapstructure:"MAIL_HOST"`
	MailPort     int    `mapstructure:"MAIL_PORT"`
	MailUsername string `mapstructure:"MAIL_USERNAME"`
	MailPassword string `mapstructure:"MAIL_PASSWORD"`
	MailFrom     string `mapstructure:"MAIL_FROM"`

	// Firebase
	FirebaseConfigPath string `mapstructure:"FIREBASE_CONFIG_PATH"`

	// Achievements
	AchievementMonaGroupID   string `mapstructure:"ACHIEVEMENT_MONA_GROUP_ID"`
	AchievementCreatedBefore string `mapstructure:"ACHIEVEMENT_CREATED_BEFORE"`
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
		"PUBLIC_EMAIL_LOGIN", "WEB_ADMIN_API",
		"ADMIN_TOTP_ENCRYPTION_KEY", "ADMIN_TOTP_ENCRYPTION_KEY_ID",
		"ADMIN_SESSION_HMAC_KEY", "ADMIN_SESSION_HMAC_KEY_ID", "ADMIN_FIRST_RUN_TOKEN",
		"ADMIN_BOOTSTRAP_USERNAME", "ADMIN_BOOTSTRAP_PASSWORD", "ADMIN_BOOTSTRAP_TOTP_SECRET",
		"ADMIN_ORIGIN", "TRUSTED_PROXY_CIDRS",
		"ADMIN_SESSION_IDLE_TTL", "ADMIN_SESSION_ABSOLUTE_TTL", "ADMIN_CHALLENGE_TTL",
		"ADMIN_RECENT_MFA_TTL", "ADMIN_PREAUTH_TTL", "ADMIN_LOGIN_FAILURE_LIMIT",
		"ADMIN_LOGIN_IP_LIMIT", "ADMIN_LOGIN_GLOBAL_LIMIT",
		"RUSTFS_ENDPOINT", "RUSTFS_EXTERNAL_ENDPOINT",
		"RUSTFS_ACCESS_KEY", "RUSTFS_SECRET_KEY",
		"RUSTFS_BUCKET", "RUSTFS_USE_SSL", "RUSTFS_URL_EXPIRY",
		"MAIL_HOST", "MAIL_PORT", "MAIL_USERNAME", "MAIL_PASSWORD", "MAIL_FROM",
		"FIREBASE_CONFIG_PATH",
		"ACHIEVEMENT_MONA_GROUP_ID", "ACHIEVEMENT_CREATED_BEFORE",
	} {
		_ = v.BindEnv(k)
	}

	v.SetDefault("PORT", "8080")
	v.SetDefault("TOKEN_ACCESS_EXPIRY", 15*time.Minute)
	v.SetDefault("TOKEN_REFRESH_EXPIRY", 365*24*time.Hour)
	v.SetDefault("APP_MAX_LOGIN_ATTEMPTS", 10)
	v.SetDefault("PUBLIC_EMAIL_LOGIN", false)
	// Browser sessions are the authentication boundary for the v2 admin
	// routes as well as v3. Keep the session bootstrap/login endpoints
	// available after an upgrade unless an operator explicitly disables the
	// feature; missing key material still fails closed as unavailable.
	v.SetDefault("WEB_ADMIN_API", true)
	v.SetDefault("ADMIN_SESSION_IDLE_TTL", 30*time.Minute)
	v.SetDefault("ADMIN_SESSION_ABSOLUTE_TTL", 8*time.Hour)
	v.SetDefault("ADMIN_CHALLENGE_TTL", 5*time.Minute)
	v.SetDefault("ADMIN_RECENT_MFA_TTL", 5*time.Minute)
	v.SetDefault("ADMIN_PREAUTH_TTL", 10*time.Minute)
	v.SetDefault("ADMIN_LOGIN_FAILURE_LIMIT", int64(5))
	v.SetDefault("ADMIN_LOGIN_IP_LIMIT", int64(100))
	v.SetDefault("ADMIN_LOGIN_GLOBAL_LIMIT", int64(1000))
	v.SetDefault("RUSTFS_BUCKET", "monaserver")
	v.SetDefault("RUSTFS_USE_SSL", false)
	v.SetDefault("RUSTFS_URL_EXPIRY", 60*time.Minute)
	v.SetDefault("MAIL_PORT", 587)

	var cfg Config
	if err := v.Unmarshal(&cfg); err != nil {
		return nil, err
	}
	return &cfg, nil
}
