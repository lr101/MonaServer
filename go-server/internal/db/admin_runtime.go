package db

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"

	dbgen "github.com/lrprojects/monaserver/internal/gen/db"
)

// AdminRuntimeAccount is the non-secret account projection used by the
// browser-admin read and audience adapters. All records are selected through
// bounded PostgreSQL queries below.
type AdminRuntimeAccount struct {
	ID                    uuid.UUID
	Username              string
	Email                 *string
	EmailConfirmed        bool
	CreatedAt             time.Time
	SecurityState         string
	AuthGeneration        int64
	PasswordDisabled      bool
	PasswordResetRequired bool
	CompromisedAt         *time.Time
	IsAdmin               bool
	GeneralEmailEnabled   bool
	PushEnabled           bool
	DeviceCount           int32
}

type AdminRuntimeAccountQuery struct {
	AfterID        *uuid.UUID
	SelectedIDs    []uuid.UUID
	Search         string
	Username       string
	Email          string
	IDText         string
	SecurityState  string
	SecurityStates []string
	VerifiedEmail  *bool
	CreatedAfter   *time.Time
	CreatedBefore  *time.Time
	IncludeAdmins  bool
	Offset         int
	Limit          int
}

func adminRuntimeAccountFromRow(row dbgen.ListAdminRuntimeAccountsRow) AdminRuntimeAccount {
	return AdminRuntimeAccount{
		ID:                    goUUID(row.ID),
		Username:              textFromPG(row.Username),
		Email:                 textPtrFromPG(row.Email),
		EmailConfirmed:        row.EmailConfirmed,
		CreatedAt:             timeFromPG(row.CreationDate),
		SecurityState:         row.SecurityState,
		AuthGeneration:        row.AuthGeneration,
		PasswordDisabled:      row.PasswordDisabled,
		PasswordResetRequired: row.PasswordResetRequired,
		CompromisedAt:         timePtrFromPG(row.CompromisedAt),
		IsAdmin:               row.IsAdmin,
		GeneralEmailEnabled:   row.GeneralEmailEnabled,
		PushEnabled:           row.PushEnabled,
		DeviceCount:           row.DeviceCount,
	}
}

func adminRuntimeAccountParams(query AdminRuntimeAccountQuery) (dbgen.ListAdminRuntimeAccountsParams, error) {
	if query.Limit <= 0 || query.Offset < 0 {
		return dbgen.ListAdminRuntimeAccountsParams{}, ErrInvalidJob
	}
	selected := make([]pgtype.UUID, 0, len(query.SelectedIDs))
	for _, id := range query.SelectedIDs {
		if id == uuid.Nil {
			return dbgen.ListAdminRuntimeAccountsParams{}, ErrInvalidJob
		}
		selected = append(selected, pgUUID(id))
	}
	return dbgen.ListAdminRuntimeAccountsParams{
		AfterID:        pgUUIDPtr(query.AfterID),
		SelectedIds:    selected,
		Search:         query.Search,
		Username:       query.Username,
		Email:          query.Email,
		IDText:         query.IDText,
		SecurityState:  query.SecurityState,
		SecurityStates: append([]string(nil), query.SecurityStates...),
		VerifiedEmail:  pgBool(query.VerifiedEmail),
		CreatedAfter:   pgTZ(query.CreatedAfter),
		CreatedBefore:  pgTZ(query.CreatedBefore),
		IncludeAdmins:  query.IncludeAdmins,
		PageOffset:     int32(query.Offset),
		PageLimit:      int32(query.Limit),
	}, nil
}

func (q *Queries) ListAdminRuntimeAccounts(ctx context.Context, query AdminRuntimeAccountQuery) ([]AdminRuntimeAccount, error) {
	params, err := adminRuntimeAccountParams(query)
	if err != nil {
		return nil, err
	}
	rows, err := q.g.ListAdminRuntimeAccounts(ctx, params)
	if err != nil {
		return nil, err
	}
	items := make([]AdminRuntimeAccount, 0, len(rows))
	for _, row := range rows {
		items = append(items, adminRuntimeAccountFromRow(row))
	}
	return items, nil
}

func (q *Queries) CountAdminRuntimeAccounts(ctx context.Context, query AdminRuntimeAccountQuery) (int64, error) {
	if query.Limit <= 0 || query.Offset < 0 {
		return 0, ErrInvalidJob
	}
	selected := make([]pgtype.UUID, 0, len(query.SelectedIDs))
	for _, id := range query.SelectedIDs {
		if id == uuid.Nil {
			return 0, ErrInvalidJob
		}
		selected = append(selected, pgUUID(id))
	}
	return q.g.CountAdminRuntimeAccounts(ctx, dbgen.CountAdminRuntimeAccountsParams{
		SelectedIds:    selected,
		Username:       query.Username,
		Email:          query.Email,
		IDText:         query.IDText,
		SecurityState:  query.SecurityState,
		SecurityStates: append([]string(nil), query.SecurityStates...),
		VerifiedEmail:  pgBool(query.VerifiedEmail),
		CreatedAfter:   pgTZ(query.CreatedAfter),
		CreatedBefore:  pgTZ(query.CreatedBefore),
		IncludeAdmins:  query.IncludeAdmins,
	})
}

func (q *Queries) GetAdminRuntimeAccount(ctx context.Context, id uuid.UUID) (*AdminRuntimeAccount, error) {
	if id == uuid.Nil {
		return nil, nil
	}
	row, err := q.g.GetAdminRuntimeAccount(ctx, pgUUID(id))
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	account := AdminRuntimeAccount{
		ID:                    goUUID(row.ID),
		Username:              textFromPG(row.Username),
		Email:                 textPtrFromPG(row.Email),
		EmailConfirmed:        row.EmailConfirmed,
		CreatedAt:             timeFromPG(row.CreationDate),
		SecurityState:         row.SecurityState,
		AuthGeneration:        row.AuthGeneration,
		PasswordDisabled:      row.PasswordDisabled,
		PasswordResetRequired: row.PasswordResetRequired,
		CompromisedAt:         timePtrFromPG(row.CompromisedAt),
		IsAdmin:               row.IsAdmin,
		GeneralEmailEnabled:   row.GeneralEmailEnabled,
		PushEnabled:           row.PushEnabled,
		DeviceCount:           row.DeviceCount,
	}
	return &account, nil
}

type AdminRuntimeReportQuery struct {
	AfterID        *uuid.UUID
	SelectedIDs    []uuid.UUID
	Statuses       []string
	TargetTypes    []string
	AssigneeUserID *uuid.UUID
	Offset         int
	Limit          int
}

type AdminRuntimeReport struct {
	ID             uuid.UUID
	Status         string
	TargetKind     *string
	AssigneeUserID *uuid.UUID
}

func adminRuntimeReportParams(query AdminRuntimeReportQuery) (dbgen.ListAdminRuntimeReportsParams, error) {
	if query.Limit <= 0 || query.Offset < 0 {
		return dbgen.ListAdminRuntimeReportsParams{}, ErrInvalidJob
	}
	selected := make([]pgtype.UUID, 0, len(query.SelectedIDs))
	for _, id := range query.SelectedIDs {
		if id == uuid.Nil {
			return dbgen.ListAdminRuntimeReportsParams{}, ErrInvalidJob
		}
		selected = append(selected, pgUUID(id))
	}
	return dbgen.ListAdminRuntimeReportsParams{
		AfterID:        pgUUIDPtr(query.AfterID),
		SelectedIds:    selected,
		Statuses:       append([]string(nil), query.Statuses...),
		TargetTypes:    append([]string(nil), query.TargetTypes...),
		AssigneeUserID: pgUUIDPtr(query.AssigneeUserID),
		PageOffset:     int32(query.Offset),
		PageLimit:      int32(query.Limit),
	}, nil
}

func (q *Queries) ListAdminRuntimeReports(ctx context.Context, query AdminRuntimeReportQuery) ([]AdminRuntimeReport, error) {
	params, err := adminRuntimeReportParams(query)
	if err != nil {
		return nil, err
	}
	rows, err := q.g.ListAdminRuntimeReports(ctx, params)
	if err != nil {
		return nil, err
	}
	items := make([]AdminRuntimeReport, 0, len(rows))
	for _, row := range rows {
		items = append(items, AdminRuntimeReport{ID: goUUID(row.ID), Status: row.Status, TargetKind: textPtrFromPG(row.TargetKind), AssigneeUserID: uuidPtrFromPG(row.AssigneeUserID)})
	}
	return items, nil
}

func (q *Queries) CountAdminRuntimeReports(ctx context.Context, query AdminRuntimeReportQuery) (int64, error) {
	if query.Limit <= 0 || query.Offset < 0 {
		return 0, ErrInvalidJob
	}
	selected := make([]pgtype.UUID, 0, len(query.SelectedIDs))
	for _, id := range query.SelectedIDs {
		if id == uuid.Nil {
			return 0, ErrInvalidJob
		}
		selected = append(selected, pgUUID(id))
	}
	return q.g.CountAdminRuntimeReports(ctx, dbgen.CountAdminRuntimeReportsParams{SelectedIds: selected, Statuses: append([]string(nil), query.Statuses...), TargetTypes: append([]string(nil), query.TargetTypes...), AssigneeUserID: pgUUIDPtr(query.AssigneeUserID)})
}

type AdminRuntimeAuditQuery struct {
	AfterID         *uuid.UUID
	TargetAccountID *uuid.UUID
	Action          string
	Limit           int
}

func (q *Queries) ListAdminRuntimeAuditEvents(ctx context.Context, query AdminRuntimeAuditQuery) ([]AuditEvent, error) {
	if query.Limit <= 0 {
		return nil, ErrInvalidJob
	}
	rows, err := q.g.ListAdminRuntimeAuditEvents(ctx, dbgen.ListAdminRuntimeAuditEventsParams{AfterID: pgUUIDPtr(query.AfterID), TargetAccountID: pgUUIDPtr(query.TargetAccountID), ActionFilter: query.Action, PageLimit: int32(query.Limit)})
	if err != nil {
		return nil, err
	}
	items := make([]AuditEvent, 0, len(rows))
	for _, row := range rows {
		items = append(items, auditEventFromRow(row))
	}
	return items, nil
}

func (q *Queries) ListAdminRuntimeJobs(ctx context.Context, afterID *uuid.UUID, limit int, status, action string) ([]AdminJob, error) {
	if limit <= 0 {
		return nil, ErrInvalidJob
	}
	rows, err := q.g.ListAdminRuntimeJobs(ctx, dbgen.ListAdminRuntimeJobsParams{AfterID: pgUUIDPtr(afterID), StatusFilter: status, ActionFilter: action, PageLimit: int32(limit)})
	if err != nil {
		return nil, err
	}
	items := make([]AdminJob, 0, len(rows))
	for _, row := range rows {
		items = append(items, adminJobFromRow(row))
	}
	return items, nil
}

func (q *Queries) ListAdminRuntimeJobItems(ctx context.Context, jobID uuid.UUID, afterID *uuid.UUID, limit int) ([]AdminJobItem, error) {
	if jobID == uuid.Nil || limit <= 0 {
		return nil, ErrInvalidJob
	}
	rows, err := q.g.ListAdminRuntimeJobItems(ctx, dbgen.ListAdminRuntimeJobItemsParams{JobID: pgUUID(jobID), AfterID: pgUUIDPtr(afterID), PageLimit: int32(limit)})
	if err != nil {
		return nil, err
	}
	items := make([]AdminJobItem, 0, len(rows))
	for _, row := range rows {
		items = append(items, adminJobItemFromRow(row))
	}
	return items, nil
}

func pgBool(value *bool) pgtype.Bool {
	if value == nil {
		return pgtype.Bool{}
	}
	return pgtype.Bool{Bool: *value, Valid: true}
}
