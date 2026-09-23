package service

import (
	"context"

	"github.com/google/uuid"

	"github.com/lrprojects/monaserver/internal/db"
)

// ProductionCampaignStore adapts the bounded campaign facade to the service
// boundary. It does not add delivery behavior or any cross-resource work.
type ProductionCampaignStore struct {
	queries *db.Queries
}

func NewProductionCampaignStore(queries *db.Queries) *ProductionCampaignStore {
	return &ProductionCampaignStore{queries: queries}
}

func (s *ProductionCampaignStore) ListCampaigns(ctx context.Context, query CampaignListQuery) ([]Campaign, error) {
	if s == nil || s.queries == nil {
		return nil, ErrAdminRepositoryAbsent
	}
	rows, err := s.queries.ListCampaigns(ctx, db.CampaignQuery{BeforeCreatedAt: query.BeforeCreatedAt, BeforeID: query.BeforeID, Limit: query.Limit})
	if err != nil {
		return nil, err
	}
	items := make([]Campaign, 0, len(rows))
	for _, row := range rows {
		items = append(items, *campaignFromDB(row))
	}
	return items, nil
}

func (s *ProductionCampaignStore) GetCampaign(ctx context.Context, id uuid.UUID) (*Campaign, error) {
	if s == nil || s.queries == nil {
		return nil, ErrAdminRepositoryAbsent
	}
	row, err := s.queries.GetCampaign(ctx, id)
	if err != nil || row == nil {
		return nil, err
	}
	return campaignFromDB(*row), nil
}

func (s *ProductionCampaignStore) CreateCampaign(ctx context.Context, campaign Campaign) (*Campaign, error) {
	if s == nil || s.queries == nil {
		return nil, ErrAdminRepositoryAbsent
	}
	row, err := s.queries.CreateCampaign(ctx, db.CampaignParams{
		ID: campaign.ID, Name: campaign.Name, Channel: string(campaign.Channel), Subject: campaign.Subject, Title: campaign.Title,
		Body: campaign.Body, Status: string(campaign.Status), CreatedByUserID: campaign.CreatedByUserID,
	})
	if err != nil {
		return nil, err
	}
	return campaignFromDB(*row), nil
}

func (s *ProductionCampaignStore) UpdateCampaignIfRevision(ctx context.Context, campaign Campaign, expectedRevision int64) (*Campaign, bool, error) {
	if s == nil || s.queries == nil {
		return nil, false, ErrAdminRepositoryAbsent
	}
	row, ok, err := s.queries.UpdateCampaignIfRevision(ctx, campaign.ID, expectedRevision, db.CampaignUpdate{
		Name: campaign.Name, Channel: string(campaign.Channel), Subject: campaign.Subject, Title: campaign.Title, Body: campaign.Body, Status: string(campaign.Status),
	})
	if err != nil || !ok {
		return nil, ok, err
	}
	return campaignFromDB(*row), true, nil
}

func (s *ProductionCampaignStore) DeleteCampaignIfRevision(ctx context.Context, id uuid.UUID, expectedRevision int64) (bool, error) {
	if s == nil || s.queries == nil {
		return false, ErrAdminRepositoryAbsent
	}
	return s.queries.DeleteCampaignIfRevision(ctx, id, expectedRevision)
}

func campaignFromDB(row db.Campaign) *Campaign {
	return &Campaign{
		ID: row.ID, Name: row.Name, Channel: CampaignChannel(row.Channel), Subject: cloneCampaignString(row.Subject), Title: cloneCampaignString(row.Title),
		Body: row.Body, Status: CampaignStatus(row.Status), Revision: row.Revision, CreatedAt: row.CreatedAt, UpdatedAt: row.UpdatedAt, CreatedByUserID: row.CreatedByUserID,
	}
}

var _ CampaignStore = (*ProductionCampaignStore)(nil)
