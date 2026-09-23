package handler

import (
	"context"
	"net/http"

	genserver "github.com/lrprojects/monaserver/internal/gen/server"
	"github.com/lrprojects/monaserver/internal/service"
)

// AdminCampaignsServicer adapts the content-only campaign service to the
// browser-admin contract. Authorization and CSRF middleware remain mandatory
// at routing time; direct calls are also checked so they fail closed.
type AdminCampaignsServicer struct {
	campaigns *service.CampaignService
}

func NewAdminCampaignsServicer(campaigns *service.CampaignService) *AdminCampaignsServicer {
	return &AdminCampaignsServicer{campaigns: campaigns}
}

func (s *AdminCampaignsServicer) ListAdminCampaigns(ctx context.Context, cursor string, limit int32) (genserver.ImplResponse, error) {
	if s == nil || s.campaigns == nil {
		return adminResponse(ctx, service.ErrAdminRepositoryAbsent)
	}
	actor, err := adminActor(ctx)
	if err != nil {
		return adminResponse(ctx, err)
	}
	page, err := s.campaigns.List(ctx, actor, service.CampaignListRequest{Cursor: cursor, Limit: int(limit)})
	if err != nil {
		return adminResponse(ctx, err)
	}
	items := make([]genserver.AdminCampaignDto, 0, len(page.Items))
	for _, campaign := range page.Items {
		items = append(items, toAdminCampaign(campaign))
	}
	return genserver.Response(http.StatusOK, genserver.AdminCampaignPageDto{Items: items, NextCursor: page.NextCursor}), nil
}

func (s *AdminCampaignsServicer) CreateAdminCampaign(ctx context.Context, csrf string, request genserver.AdminCampaignCreateRequestDto) (genserver.ImplResponse, error) {
	actor, err := s.mutationActor(ctx, csrf)
	if err != nil {
		return adminResponse(ctx, err)
	}
	campaign, err := s.campaigns.Create(ctx, actor, service.CampaignCreateInput{
		Name: request.Name, Channel: service.CampaignChannel(request.Channel), Subject: cloneStringValue(request.Subject), Title: cloneStringValue(request.Title), Body: request.Body, Status: service.CampaignStatus(request.Status),
	})
	if err != nil {
		return adminResponse(ctx, err)
	}
	return genserver.Response(http.StatusCreated, toAdminCampaign(*campaign)), nil
}

func (s *AdminCampaignsServicer) GetAdminCampaign(ctx context.Context, campaignID string) (genserver.ImplResponse, error) {
	if s == nil || s.campaigns == nil {
		return adminResponse(ctx, service.ErrAdminRepositoryAbsent)
	}
	actor, err := adminActor(ctx)
	if err != nil {
		return adminResponse(ctx, err)
	}
	id, err := parseAdminUUID(campaignID)
	if err != nil {
		return adminResponse(ctx, err)
	}
	campaign, err := s.campaigns.Get(ctx, actor, id)
	if err != nil {
		return adminResponse(ctx, err)
	}
	return genserver.Response(http.StatusOK, toAdminCampaign(*campaign)), nil
}

func (s *AdminCampaignsServicer) UpdateAdminCampaign(ctx context.Context, campaignID, csrf string, request genserver.AdminCampaignUpdateRequestDto) (genserver.ImplResponse, error) {
	actor, err := s.mutationActor(ctx, csrf)
	if err != nil {
		return adminResponse(ctx, err)
	}
	id, err := parseAdminUUID(campaignID)
	if err != nil {
		return adminResponse(ctx, err)
	}
	campaign, err := s.campaigns.Update(ctx, actor, service.CampaignUpdateInput{
		CampaignID: id, ExpectedRevision: request.ExpectedRevision, Name: request.Name, Channel: service.CampaignChannel(request.Channel),
		Subject: cloneStringValue(request.Subject), Title: cloneStringValue(request.Title), Body: request.Body, Status: service.CampaignStatus(request.Status),
	})
	if err != nil {
		return adminResponse(ctx, err)
	}
	return genserver.Response(http.StatusOK, toAdminCampaign(*campaign)), nil
}

func (s *AdminCampaignsServicer) ArchiveAdminCampaign(ctx context.Context, campaignID, csrf string, request genserver.AdminCampaignRevisionRequestDto) (genserver.ImplResponse, error) {
	actor, err := s.mutationActor(ctx, csrf)
	if err != nil {
		return adminResponse(ctx, err)
	}
	id, err := parseAdminUUID(campaignID)
	if err != nil {
		return adminResponse(ctx, err)
	}
	campaign, err := s.campaigns.Archive(ctx, actor, service.CampaignRevisionInput{CampaignID: id, ExpectedRevision: request.ExpectedRevision})
	if err != nil {
		return adminResponse(ctx, err)
	}
	return genserver.Response(http.StatusOK, toAdminCampaign(*campaign)), nil
}

func (s *AdminCampaignsServicer) DeleteAdminCampaign(ctx context.Context, campaignID, csrf string, request genserver.AdminCampaignRevisionRequestDto) (genserver.ImplResponse, error) {
	actor, err := s.mutationActor(ctx, csrf)
	if err != nil {
		return adminResponse(ctx, err)
	}
	id, err := parseAdminUUID(campaignID)
	if err != nil {
		return adminResponse(ctx, err)
	}
	if err := s.campaigns.Delete(ctx, actor, service.CampaignRevisionInput{CampaignID: id, ExpectedRevision: request.ExpectedRevision}); err != nil {
		return adminResponse(ctx, err)
	}
	return genserver.Response(http.StatusNoContent, nil), nil
}

func (s *AdminCampaignsServicer) mutationActor(ctx context.Context, csrf string) (service.AdminActor, error) {
	if s == nil || s.campaigns == nil {
		return service.AdminActor{}, service.ErrAdminRepositoryAbsent
	}
	return adminMutationActor(ctx, csrf)
}

func toAdminCampaign(campaign service.Campaign) genserver.AdminCampaignDto {
	return genserver.AdminCampaignDto{
		Id: campaign.ID.String(), Name: campaign.Name, Channel: genserver.AdminCampaignChannel(campaign.Channel), Subject: cloneStringValue(campaign.Subject),
		Title: cloneStringValue(campaign.Title), Body: campaign.Body, Status: genserver.AdminCampaignStatus(campaign.Status), Revision: campaign.Revision,
		CreatedAt: campaign.CreatedAt, UpdatedAt: campaign.UpdatedAt, CreatedByUserId: uuidStringPtr(campaign.CreatedByUserID),
	}
}

var _ genserver.AdminCampaignsAPIServicer = (*AdminCampaignsServicer)(nil)
