package handler

import (
	"context"
	"encoding/base64"
	"net/http"
	"time"

	"github.com/google/uuid"

	"github.com/lrprojects/monaserver/internal/apperrors"
	"github.com/lrprojects/monaserver/internal/db"
	genserver "github.com/lrprojects/monaserver/internal/gen/server"
	"github.com/lrprojects/monaserver/internal/service"
)

// PinsServicer implements genserver.PinsAPIServicer.
type PinsServicer struct {
	pin   *service.Pin
	group *service.Group
	guard *service.Guard
	q     *db.Queries
}

func NewPinsServicer(pin *service.Pin, group *service.Group, guard *service.Guard, q *db.Queries) *PinsServicer {
	return &PinsServicer{pin: pin, group: group, guard: guard, q: q}
}

func (s *PinsServicer) GetPinImagesByIds(ctx context.Context, ids []string, groupID, userID string, withImage bool, compression, height, page, size int32, updatedAfter time.Time) (genserver.ImplResponse, error) {
	// This endpoint is essentially GetGroupsByIds for pins (v2 sync).
	// Return updated pins for the given group since updatedAfter.
	gid, err := uuid.Parse(groupID)
	if err != nil {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	var after *time.Time
	if !updatedAfter.IsZero() {
		after = &updatedAfter
	}
	pins, err := s.q.ListUpdatedPinsForGroups(ctx, []uuid.UUID{gid}, after)
	if err != nil {
		return genserver.Response(apperrors.HTTPStatus(err), nil), nil
	}
	items := make([]genserver.PinWithOptionalImageDto, 0, len(pins))
	for _, p := range pins {
		dto := pinToDto(p)
		if withImage {
			imgURL, _ := s.pin.ImageURL(ctx, p.ID)
			if imgURL != nil {
				dto.Image = *imgURL
			}
		}
		items = append(items, dto)
	}
	return genserver.Response(http.StatusOK, genserver.PinsSyncDto{Items: items, Deleted: []string{}}), nil
}

func (s *PinsServicer) CreatePin(ctx context.Context, dto genserver.PinRequestDto) (genserver.ImplResponse, error) {
	uid, err := uuid.Parse(dto.UserId)
	if err != nil {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	gid, err := uuid.Parse(dto.GroupId)
	if err != nil {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	imgBytes, err := base64.StdEncoding.DecodeString(dto.Image)
	if err != nil {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	result, err := s.pin.Create(ctx, service.CreatePinInput{
		Latitude:     float64(dto.Latitude),
		Longitude:    float64(dto.Longitude),
		CreationDate: dto.CreationDate,
		Description:  dto.Description,
		UserID:       uid,
		GroupID:      gid,
		Image:        imgBytes,
	})
	if err != nil {
		return genserver.Response(apperrors.HTTPStatus(err), nil), nil
	}
	return genserver.Response(http.StatusCreated, pinDTOtoDto(result)), nil
}

func (s *PinsServicer) GetPin(ctx context.Context, pinID string, redirect bool) (genserver.ImplResponse, error) {
	id, err := uuid.Parse(pinID)
	if err != nil {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	uid, ok := ctxUserID(ctx)
	if !ok {
		return genserver.Response(http.StatusUnauthorized, nil), nil
	}
	if ok2, _ := s.guard.IsPinPublicOrMember(ctx, id, uid); !ok2 {
		return genserver.Response(http.StatusForbidden, nil), nil
	}
	dto, err := s.pin.Get(ctx, id)
	if err != nil {
		return genserver.Response(apperrors.HTTPStatus(err), nil), nil
	}
	return genserver.Response(http.StatusOK, pinDTOtoDto(dto)), nil
}

func (s *PinsServicer) DeletePin(ctx context.Context, pinID string) (genserver.ImplResponse, error) {
	id, err := uuid.Parse(pinID)
	if err != nil {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	uid, ok := ctxUserID(ctx)
	if !ok {
		return genserver.Response(http.StatusUnauthorized, nil), nil
	}
	isCreator, _ := s.guard.IsPinCreator(ctx, id, uid)
	isGroupAdmin, _ := s.guard.IsPinGroupAdmin(ctx, id, uid)
	if !isCreator && !isGroupAdmin {
		return genserver.Response(http.StatusForbidden, nil), nil
	}
	if err := s.pin.Delete(ctx, id); err != nil {
		return genserver.Response(apperrors.HTTPStatus(err), nil), nil
	}
	return genserver.Response(http.StatusOK, nil), nil
}

func (s *PinsServicer) GetPinImage(ctx context.Context, pinID string, redirect bool) (genserver.ImplResponse, error) {
	id, err := uuid.Parse(pinID)
	if err != nil {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	uid, ok := ctxUserID(ctx)
	if !ok {
		return genserver.Response(http.StatusUnauthorized, nil), nil
	}
	if ok2, _ := s.guard.IsPinPublicOrMember(ctx, id, uid); !ok2 {
		return genserver.Response(http.StatusForbidden, nil), nil
	}
	u, err := s.pin.ImageURL(ctx, id)
	if err != nil {
		return genserver.Response(apperrors.HTTPStatus(err), nil), nil
	}
	if u == nil {
		return genserver.Response(http.StatusOK, nil), nil
	}
	if redirect {
		return genserver.Response(http.StatusOK, *u), nil
	}
	return genserver.Response(http.StatusOK, *u), nil
}

func (s *PinsServicer) Sync(ctx context.Context, since time.Time) (genserver.ImplResponse, error) {
	uid, ok := ctxUserID(ctx)
	if !ok {
		return genserver.Response(http.StatusUnauthorized, nil), nil
	}
	withUser := true
	groups, err := s.group.Search(ctx, nil, &uid, &withUser, false, 0, 1000, nil)
	if err != nil {
		return genserver.Response(apperrors.HTTPStatus(err), nil), nil
	}
	groupIDs := make([]uuid.UUID, 0, len(groups.Groups))
	for _, g := range groups.Groups {
		groupIDs = append(groupIDs, g.ID)
	}
	deletedPins, err := s.q.ListDeletedPinsAfter(ctx, since)
	if err != nil {
		return genserver.Response(apperrors.HTTPStatus(err), nil), nil
	}
	deletedStrs := make([]string, 0, len(deletedPins))
	for _, id := range deletedPins {
		deletedStrs = append(deletedStrs, id.String())
	}
	updatedPins, err := s.q.ListUpdatedPinsForGroups(ctx, groupIDs, &since)
	if err != nil {
		return genserver.Response(apperrors.HTTPStatus(err), nil), nil
	}
	// Group pins by group
	pinsByGroup := make(map[uuid.UUID][]genserver.PinWithOptionalImageDto)
	for _, p := range updatedPins {
		pinsByGroup[p.GroupID] = append(pinsByGroup[p.GroupID], pinToDto(p))
	}
	groupUpdates := make([]genserver.SyncDtoGroupUpdatesInner, 0, len(groups.Groups))
	for _, g := range groups.Groups {
		dto := toGroupDto(g)
		groupUpdates = append(groupUpdates, genserver.SyncDtoGroupUpdatesInner{
			Group:     dto,
			PinsAdded: pinsByGroup[g.ID],
		})
	}
	return genserver.Response(http.StatusOK, genserver.SyncDto{
		DeletedPins:  deletedStrs,
		GroupUpdates: groupUpdates,
	}), nil
}

func pinToDto(p db.Pin) genserver.PinWithOptionalImageDto {
	var creationDate time.Time
	if p.CreationDate != nil {
		creationDate = *p.CreationDate
	}
	return genserver.PinWithOptionalImageDto{
		Id:           p.ID.String(),
		CreationDate: creationDate,
		Latitude:     float32(p.Latitude),
		Longitude:    float32(p.Longitude),
		CreationUser: p.CreatorID.String(),
		GroupId:      p.GroupID.String(),
		Description:  p.Description,
	}
}

func pinDTOtoDto(p *service.PinDTO) genserver.PinWithOptionalImageDto {
	var creationDate time.Time
	if p.CreationDate != nil {
		creationDate = *p.CreationDate
	}
	img := ""
	if p.Image != nil {
		img = *p.Image
	}
	return genserver.PinWithOptionalImageDto{
		Id:           p.ID.String(),
		CreationDate: creationDate,
		Latitude:     float32(p.Latitude),
		Longitude:    float32(p.Longitude),
		CreationUser: p.UserID.String(),
		GroupId:      p.GroupID.String(),
		Description:  p.Description,
		Image:        img,
	}
}
