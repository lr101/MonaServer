package scheduler

import (
	"context"
	"log/slog"

	"github.com/robfig/cron/v3"
)

// Scheduler owns the cron jobs (notification Sunday 14:00, season last-day-of-month 23:59).
type Scheduler struct {
	c *cron.Cron
}

func New() *Scheduler {
	return &Scheduler{c: cron.New(cron.WithSeconds())}
}

// AddWeeklyNotification schedules a job every Sunday at 14:00.
func (s *Scheduler) AddWeeklyNotification(fn func(ctx context.Context)) error {
	_, err := s.c.AddFunc("0 0 14 * * SUN", func() { fn(context.Background()) })
	return err
}

// AddMonthlySeason schedules a job on the last day of each month at 23:59.
// robfig/cron does not support the `L` (last) specifier natively, so we run daily
// at 23:59 and let the job itself decide whether today is the last day.
func (s *Scheduler) AddMonthlySeason(fn func(ctx context.Context)) error {
	_, err := s.c.AddFunc("0 59 23 * * *", func() { fn(context.Background()) })
	return err
}

func (s *Scheduler) Start() {
	s.c.Start()
	slog.Info("scheduler started")
}

func (s *Scheduler) Stop() { _ = s.c.Stop() }
