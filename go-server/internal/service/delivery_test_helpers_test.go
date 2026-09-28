package service

import (
	"context"
	"time"

	"github.com/google/uuid"

	"github.com/lrprojects/monaserver/internal/db"
)

// fakeJobStore is intentionally local to delivery tests. The dispatcher tests
// call Worker.Process with an already claimed job, so they only need a store
// that acknowledges the worker's lease operations without a database.
type fakeJobStore struct{}

func (*fakeJobStore) ClaimDurableJobs(context.Context, string, int, time.Duration) ([]db.DurableJob, error) {
	return nil, nil
}

func (*fakeJobStore) ClaimDurableJobsByKinds(context.Context, string, []string, int, time.Duration) ([]db.DurableJob, error) {
	return nil, nil
}

func (*fakeJobStore) ExtendDurableJobLease(context.Context, uuid.UUID, string, uuid.UUID, time.Duration) (bool, error) {
	return true, nil
}

func (*fakeJobStore) FinishDurableJob(context.Context, uuid.UUID, string, uuid.UUID, string) (bool, error) {
	return true, nil
}

func (*fakeJobStore) ReleaseDurableJobLease(context.Context, uuid.UUID, string, uuid.UUID, time.Time) (bool, error) {
	return true, nil
}

func deliveryStringPtr(value string) *string { return &value }
