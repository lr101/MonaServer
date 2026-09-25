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
	keys, err := s.q.ListPendingObjectCleanup(ctx, objectCleanupBatchLimit)
	if err != nil {
		return err
	}
	var failures []error
	for _, key := range keys {
		if err := s.obj.Remove(ctx, key); err != nil {
			failures = append(failures, fmt.Errorf("remove object %q: %w", key, err))
			continue
		}
		if err := s.q.DeletePendingObjectCleanup(ctx, key); err != nil {
			failures = append(failures, fmt.Errorf("acknowledge object cleanup %q: %w", key, err))
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
