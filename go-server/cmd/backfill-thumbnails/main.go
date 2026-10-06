package main

import (
	"context"
	"errors"
	"fmt"
	"os"
	"os/signal"
	"syscall"

	"github.com/google/uuid"

	"github.com/lrprojects/monaserver/internal/config"
	"github.com/lrprojects/monaserver/internal/db"
	"github.com/lrprojects/monaserver/internal/service"
)

const batchSize = 500

type imageRecord struct {
	pinID    uuid.UUID
	imageKey string
}

type backfillStats struct {
	scanned  int
	created  int
	existing int
	missing  int
	failed   int
}

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func run() error {
	cfg, err := config.Load()
	if err != nil {
		return fmt.Errorf("load config: %w", err)
	}
	if cfg.DatabaseURL == "" {
		return errors.New("DATABASE_URL must be set")
	}
	if cfg.RustfsEndpoint == "" {
		return errors.New("RUSTFS_ENDPOINT must be set")
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	pool, err := db.NewPool(ctx, cfg.DatabaseURL)
	if err != nil {
		return fmt.Errorf("create database pool: %w", err)
	}
	defer pool.Close()
	if err := pool.Ping(ctx); err != nil {
		return fmt.Errorf("connect to database: %w", err)
	}

	objects, err := service.NewObjectWithExternalSSL(
		cfg.RustfsEndpoint,
		cfg.RustfsExternalEndpoint,
		cfg.RustfsAccessKey,
		cfg.RustfsSecretKey,
		cfg.RustfsBucket,
		cfg.RustfsUseSSL,
		cfg.RustfsExternalUseSSL,
		cfg.RustfsURLExpiry,
	)
	if err != nil {
		return fmt.Errorf("create object store client: %w", err)
	}
	if err := objects.EnsureBucket(ctx); err != nil {
		return fmt.Errorf("ensure object store bucket: %w", err)
	}

	pins := service.NewPin(db.New(pool), objects)
	stats := backfillStats{}
	lastKey := ""
	for {
		rows, err := pool.Query(ctx, `
			SELECT pp.pin_id::text, pp.image_key
			FROM pin_photos pp
			JOIN pins p ON p.id = pp.pin_id
			WHERE p.is_deleted = FALSE AND pp.image_key > $1
			ORDER BY pp.image_key
			LIMIT $2`, lastKey, batchSize)
		if err != nil {
			return fmt.Errorf("list pin images: %w", err)
		}

		batch := make([]imageRecord, 0, batchSize)
		for rows.Next() {
			var pinIDText, imageKey string
			if err := rows.Scan(&pinIDText, &imageKey); err != nil {
				rows.Close()
				return fmt.Errorf("read pin image: %w", err)
			}
			pinID, err := uuid.Parse(pinIDText)
			if err != nil {
				rows.Close()
				return fmt.Errorf("parse pin ID %q: %w", pinIDText, err)
			}
			batch = append(batch, imageRecord{pinID: pinID, imageKey: imageKey})
			lastKey = imageKey
		}
		queryErr := rows.Err()
		rows.Close()
		if queryErr != nil {
			return fmt.Errorf("read pin images: %w", queryErr)
		}
		if len(batch) == 0 {
			break
		}

		for _, record := range batch {
			if err := ctx.Err(); err != nil {
				printStats(stats)
				return fmt.Errorf("thumbnail backfill interrupted: %w", err)
			}
			stats.scanned++
			created, available, err := pins.BackfillThumbnail(ctx, record.pinID, record.imageKey)
			if err != nil {
				stats.failed++
				fmt.Fprintf(os.Stderr, "thumbnail backfill failed for %s: %v\n", record.imageKey, err)
				continue
			}
			switch {
			case created:
				stats.created++
			case available:
				stats.existing++
			default:
				stats.missing++
			}
		}
	}

	printStats(stats)
	if stats.failed > 0 {
		return fmt.Errorf("thumbnail backfill finished with %d failure(s)", stats.failed)
	}
	return nil
}

func printStats(stats backfillStats) {
	fmt.Printf("pin thumbnail backfill: scanned=%d created=%d existing=%d missing-original=%d failed=%d\n",
		stats.scanned, stats.created, stats.existing, stats.missing, stats.failed)
}
