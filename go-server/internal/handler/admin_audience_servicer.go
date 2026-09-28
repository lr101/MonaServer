package handler

import (
	"context"
	"net/http"

	genserver "github.com/lrprojects/monaserver/internal/gen/server"
	"github.com/lrprojects/monaserver/internal/service"
)

// AdminAudienceServicer adapts immutable audience snapshots to the generated
// v3 contract. Every mutation is checked against the browser-admin CSRF proof
// before the service resolves or persists a snapshot.
type AdminAudienceServicer struct {
	audiences *service.AdminAudienceService
}

type AdminAudiencesServicer = AdminAudienceServicer

func NewAdminAudienceServicer(audiences *service.AdminAudienceService) *AdminAudienceServicer {
	return &AdminAudienceServicer{audiences: audiences}
}

func NewAdminAudiencesServicer(audiences *service.AdminAudienceService) *AdminAudienceServicer {
	return NewAdminAudienceServicer(audiences)
}

func (s *AdminAudienceServicer) PreviewAdminAudience(ctx context.Context, csrf string, request genserver.AdminAudiencePreviewRequestDto) (genserver.ImplResponse, error) {
	if s == nil || s.audiences == nil {
		return adminResponse(ctx, service.ErrAdminRepositoryAbsent)
	}
	actor, err := adminMutationActor(ctx, csrf)
	if err != nil {
		return adminResponse(ctx, err)
	}
	audience, err := fromAdminAudience(request.Audience)
	if err != nil {
		return adminResponse(ctx, err)
	}
	preview, err := s.audiences.Preview(ctx, actor, service.AudiencePreviewRequest{Audience: audience, Action: fromAdminAction(request.Action)})
	if err != nil {
		return adminResponse(ctx, err)
	}
	status := http.StatusOK
	if preview.Status == service.AudienceSnapshotPending {
		status = http.StatusAccepted
	}
	return genserver.Response(status, toAudiencePreview(preview)), nil
}

func (s *AdminAudienceServicer) GetAdminAudience(ctx context.Context, audienceID, cursor string, limit int32) (genserver.ImplResponse, error) {
	if s == nil || s.audiences == nil {
		return adminResponse(ctx, service.ErrAdminRepositoryAbsent)
	}
	actor, err := adminActor(ctx)
	if err != nil {
		return adminResponse(ctx, err)
	}
	id, err := parseAdminUUID(audienceID)
	if err != nil {
		return adminResponse(ctx, err)
	}
	page, err := s.audiences.Get(ctx, actor, id, cursor, int(limit))
	if err != nil {
		return adminResponse(ctx, err)
	}
	return genserver.Response(http.StatusOK, toAudiencePage(page)), nil
}

var _ genserver.AdminAudiencesAPIServicer = (*AdminAudienceServicer)(nil)
