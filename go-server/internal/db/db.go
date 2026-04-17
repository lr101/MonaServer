package db

import (
	"context"
	"embed"
	"errors"
	"io/fs"

	"github.com/golang-migrate/migrate/v4"
	"github.com/golang-migrate/migrate/v4/database/pgx/v5"
	"github.com/golang-migrate/migrate/v4/source/iofs"
	"github.com/jackc/pgx/v5/pgxpool"
	_ "github.com/jackc/pgx/v5/stdlib"
)

//go:embed migrations/*.sql
var migrationsFS embed.FS

func NewPool(ctx context.Context, dsn string) (*pgxpool.Pool, error) {
	cfg, err := pgxpool.ParseConfig(dsn)
	if err != nil {
		return nil, err
	}
	return pgxpool.NewWithConfig(ctx, cfg)
}

func RunMigrations(dsn string) error {
	sub, err := fs.Sub(migrationsFS, "migrations")
	if err != nil {
		return err
	}
	src, err := iofs.New(sub, ".")
	if err != nil {
		return err
	}
	// golang-migrate uses scheme "pgx5://" — rewrite a normal postgres URL.
	if len(dsn) > 11 && dsn[:11] == "postgres://" {
		dsn = "pgx5://" + dsn[11:]
	} else if len(dsn) > 14 && dsn[:14] == "postgresql://" {
		dsn = "pgx5://" + dsn[14:]
	}
	m, err := migrate.NewWithSourceInstance("iofs", src, dsn)
	if err != nil {
		return err
	}
	defer m.Close()
	if err := m.Up(); err != nil && !errors.Is(err, migrate.ErrNoChange) {
		return err
	}
	_ = pgx.ErrNilConfig // keep import
	return nil
}
