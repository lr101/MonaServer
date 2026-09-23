package handler

import (
	"context"
	"net/http"

	genserver "github.com/lrprojects/monaserver/internal/gen/server"
	"github.com/lrprojects/monaserver/internal/service"
)

// AdminAuditServicer exposes the append-only audit projection. Redaction is
// performed in the service before this adapter copies metadata into DTOs.
type AdminAuditServicer struct {
	audit *service.AdminAuditService
}

type AdminAuditLogServicer = AdminAuditServicer

func NewAdminAuditServicer(audit *service.AdminAuditService) *AdminAuditServicer {
	return &AdminAuditServicer{audit: audit}
}

func NewAdminAuditLogServicer(audit *service.AdminAuditService) *AdminAuditServicer {
	return NewAdminAuditServicer(audit)
}

func (s *AdminAuditServicer) ListAdminAudit(ctx context.Context, cursor string, limit int32, targetUserID string, action genserver.AdminActionKind) (genserver.ImplResponse, error) {
	if s == nil || s.audit == nil {
		return adminResponse(ctx, service.ErrAdminRepositoryAbsent)
	}
	actor, err := adminActor(ctx)
	if err != nil {
		return adminResponse(ctx, err)
	}
	page, err := s.audit.List(ctx, actor, cursor, int(limit), targetUserID, string(action))
	if err != nil {
		return adminResponse(ctx, err)
	}
	body := genserver.AdminAuditPageDto{Items: make([]genserver.AdminAuditEventDto, 0, len(page.Items)), NextCursor: page.Next}
	for _, event := range page.Items {
		body.Items = append(body.Items, toAdminAudit(event))
	}
	return genserver.Response(http.StatusOK, body), nil
}

var _ genserver.AdminAuditAPIServicer = (*AdminAuditServicer)(nil)
