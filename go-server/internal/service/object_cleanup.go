package service

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"reflect"
	"time"

	"github.com/lrprojects/monaserver/internal/db"
)

const objectCleanupBatchLimit = 200

type ObjectRemover interface {
	Remove(context.Context, string) error
}

// ObjectCleanup retries durable object-store deletions left by entity removal.
type ObjectCleanup struct {
	q   *db.Queries
	obj ObjectRemover
}

func NewObjectCleanup(q *db.Queries, obj ObjectRemover) *ObjectCleanup {
	if obj != nil {
		value := reflect.ValueOf(obj)
		if (value.Kind() == reflect.Pointer || value.Kind() == reflect.Interface) && value.IsNil() {
			obj = nil
		}
	}
	return &ObjectCleanup{q: q, obj: obj}
}

func (s *ObjectCleanup) RunOnce(ctx context.Context) error {
	if s == nil || s.q == nil || s.obj == nil {
		return nil
	}
	var failures []error
	skippedKeys := make([]string, 0)
	for range objectCleanupBatchLimit {
		var key string
		var found bool
		err := s.q.InTx(ctx, func(q *db.Queries) error {
			var err error
			key, found, err = q.ClaimPendingObjectCleanup(ctx, skippedKeys)
			if err != nil || !found {
				return err
			}
			if err := s.obj.Remove(ctx, key); err != nil {
				return fmt.Errorf("remove object %q: %w", key, err)
			}
			return q.DeletePendingObjectCleanup(ctx, key)
		})
		if err != nil {
			failures = append(failures, err)
			if !found {
				break
			}
			skippedKeys = append(skippedKeys, key)
			continue
		}
		if !found {
			break
		}
	}
	return errors.Join(failures...)
}

// Run drains pending deletions immediately and then retries them at intervals.
func (s *ObjectCleanup) Run(ctx context.Context, interval time.Duration) {
	if interval <= 0 {
		interval = time.Minute
	}
	ticker := time.NewTicker(interval)
	defer ticker.Stop()
	for {
		if err := s.RunOnce(ctx); err != nil {
			slog.WarnContext(ctx, "object cleanup deferred", "err", err)
		}
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
		}
	}
}

func tryObjectCleanup(ctx context.Context, q *db.Queries, obj ObjectRemover) {
	if obj == nil {
		return
	}
	if err := NewObjectCleanup(q, obj).RunOnce(ctx); err != nil {
		slog.WarnContext(ctx, "object cleanup deferred", "err", err)
	}
}
