package handler

import (
	"context"
	"net/http"

	genserver "github.com/lrprojects/monaserver/internal/gen/server"
	"github.com/lrprojects/monaserver/internal/service"
)

// AdminMessagesServicer keeps the test-recipient path explicit and bounded;
// the service rejects security/report actions and never creates a broadcast
// job from this endpoint.
type AdminMessagesServicer struct {
	bulk *service.AdminBulkService
}

type AdminMessageServicer = AdminMessagesServicer

func NewAdminMessagesServicer(bulk *service.AdminBulkService) *AdminMessagesServicer {
	return &AdminMessagesServicer{bulk: bulk}
}

func NewAdminMessageServicer(bulk *service.AdminBulkService) *AdminMessagesServicer {
	return NewAdminMessagesServicer(bulk)
}

func (s *AdminMessagesServicer) SendAdminTestMessage(ctx context.Context, csrf string, request genserver.AdminTestMessageRequestDto) (genserver.ImplResponse, error) {
	if s == nil || s.bulk == nil {
		return adminResponse(ctx, service.ErrAdminRepositoryAbsent)
	}
	actor, err := adminMutationActor(ctx, csrf)
	if err != nil {
		return adminResponse(ctx, err)
	}
	targetID, err := parseAdminUUID(request.RecipientUserId)
	if err != nil {
		return adminResponse(ctx, err)
	}
	_, err = s.bulk.SendTestMessage(ctx, actor, targetID, fromAdminAction(request.Action))
	if err != nil {
		return adminResponse(ctx, err)
	}
	return genserver.Response(http.StatusAccepted, genserver.AdminTestMessageAcceptedDto{Accepted: true}), nil
}

var _ genserver.AdminMessagesAPIServicer = (*AdminMessagesServicer)(nil)
