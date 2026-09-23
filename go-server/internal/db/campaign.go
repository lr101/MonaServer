package db

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	dbgen "github.com/lrprojects/monaserver/internal/gen/db"
)

// Campaign is the persisted content-only campaign record. It deliberately
// excludes audience, provider, queue, recipient, and delivery state.
type Campaign struct {
	ID              uuid.UUID
	Name            string
	Channel         string
	Subject         *string
	Title           *string
	Body            string
	Status          string
	Revision        int64
	CreatedAt       time.Time
	UpdatedAt       time.Time
	CreatedByUserID *uuid.UUID
}

type CampaignParams struct {
	ID              uuid.UUID
	Name            string
	Channel         string
	Subject         *string
	Title           *string
	Body            string
	Status          string
	CreatedByUserID uuid.UUID
}

type CampaignUpdate struct {
	Name    string
	Channel string
	Subject *string
	Title   *string
	Body    string
	Status  string
}

type CampaignQuery struct {
	BeforeCreatedAt *time.Time
	BeforeID        *uuid.UUID
	Limit           int
}

func campaignFromRow(row dbgen.Campaign) Campaign {
	return Campaign{
		ID: goUUID(row.ID), Name: row.Name, Channel: row.Channel, Subject: goText(row.Subject), Title: goText(row.Title), Body: row.Body,
		Status: row.Status, Revision: row.Revision, CreatedAt: timeFromPG(row.CreatedAt), UpdatedAt: timeFromPG(row.UpdatedAt), CreatedByUserID: uuidPtrFromPG(row.CreatedByUserID),
	}
}

func (q *Queries) CreateCampaign(ctx context.Context, params CampaignParams) (*Campaign, error) {
	if params.ID == uuid.Nil || params.CreatedByUserID == uuid.Nil {
		return nil, ErrInvalidJob
	}
	row, err := q.g.CreateCampaign(ctx, dbgen.CreateCampaignParams{
		ID: pgUUID(params.ID), Name: params.Name, Channel: params.Channel, Subject: pgText(params.Subject), Title: pgText(params.Title),
		Body: params.Body, Status: params.Status, CreatedByUserID: pgUUID(params.CreatedByUserID),
	})
	if err != nil {
		return nil, err
	}
	campaign := campaignFromRow(row)
	return &campaign, nil
}

func (q *Queries) GetCampaign(ctx context.Context, id uuid.UUID) (*Campaign, error) {
	if id == uuid.Nil {
		return nil, nil
	}
	row, err := q.g.GetCampaign(ctx, pgUUID(id))
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	campaign := campaignFromRow(row)
	return &campaign, nil
}

func (q *Queries) ListCampaigns(ctx context.Context, query CampaignQuery) ([]Campaign, error) {
	if query.Limit < 1 || (query.BeforeCreatedAt == nil) != (query.BeforeID == nil) {
		return nil, ErrInvalidJob
	}
	rows, err := q.g.ListCampaigns(ctx, dbgen.ListCampaignsParams{
		BeforeCreatedAt: pgTZ(query.BeforeCreatedAt), BeforeID: pgUUIDPtr(query.BeforeID), PageLimit: int32(query.Limit),
	})
	if err != nil {
		return nil, err
	}
	items := make([]Campaign, 0, len(rows))
	for _, row := range rows {
		items = append(items, campaignFromRow(row))
	}
	return items, nil
}

func (q *Queries) UpdateCampaignIfRevision(ctx context.Context, id uuid.UUID, expectedRevision int64, update CampaignUpdate) (*Campaign, bool, error) {
	if id == uuid.Nil || expectedRevision < 1 {
		return nil, false, ErrInvalidJob
	}
	row, err := q.g.UpdateCampaignIfRevision(ctx, dbgen.UpdateCampaignIfRevisionParams{
		ID: pgUUID(id), ExpectedRevision: expectedRevision, Name: update.Name, Channel: update.Channel, Subject: pgText(update.Subject),
		Title: pgText(update.Title), Body: update.Body, Status: update.Status,
	})
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, false, nil
	}
	if err != nil {
		return nil, false, err
	}
	campaign := campaignFromRow(row)
	return &campaign, true, nil
}

func (q *Queries) DeleteCampaignIfRevision(ctx context.Context, id uuid.UUID, expectedRevision int64) (bool, error) {
	if id == uuid.Nil || expectedRevision < 1 {
		return false, ErrInvalidJob
	}
	deleted, err := q.g.DeleteCampaignIfRevision(ctx, dbgen.DeleteCampaignIfRevisionParams{ID: pgUUID(id), ExpectedRevision: expectedRevision})
	if err != nil {
		return false, err
	}
	return deleted == 1, nil
}
