package handler

import (
	"context"
	"encoding/base64"
	"net/http"
	"time"

	"github.com/google/uuid"

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
	caller, ok := ctxUserID(ctx)
	if !ok {
		return genserver.Response(http.StatusUnauthorized, nil), nil
	}
	parsedIDs := make([]uuid.UUID, 0, len(ids))
	for _, raw := range ids {
		id, err := uuid.Parse(raw)
		if err != nil {
			return genserver.Response(http.StatusBadRequest, nil), nil
		}
		parsedIDs = append(parsedIDs, id)
	}
	var gid *uuid.UUID
	if groupID != "" {
		id, err := uuid.Parse(groupID)
		if err != nil {
			return genserver.Response(http.StatusBadRequest, nil), nil
		}
		gid = &id
	}
	var creatorID *uuid.UUID
	if userID != "" {
		id, err := uuid.Parse(userID)
		if err != nil {
			return genserver.Response(http.StatusBadRequest, nil), nil
		}
		creatorID = &id
	}
	var after *time.Time
	if !updatedAfter.IsZero() {
		after = &updatedAfter
	}
	limit := size
	offset := page * size
	if len(parsedIDs) > 0 {
		limit = 0
		offset = 0
	}
	pins, err := s.q.SearchPins(ctx, db.PinSearch{
		CallerID: caller, IDs: parsedIDs, GroupID: gid, CreatorID: creatorID,
		UpdatedAfter: after, Limit: limit, Offset: offset,
	})
	if err != nil {
		return serviceErrResp(err), nil
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
	deleted := []string{}
	if after != nil {
		deletedIDs, err := s.q.ListDeletedPinsAfter(ctx, *after)
		if err != nil {
			return serviceErrResp(err), nil
		}
		for _, id := range deletedIDs {
			deleted = append(deleted, id.String())
		}
	}
	return genserver.Response(http.StatusOK, genserver.PinsSyncDto{Items: items, Deleted: deleted}), nil
}

func (s *PinsServicer) CreatePin(ctx context.Context, dto genserver.PinRequestDto) (genserver.ImplResponse, error) {
	if dto.Image == "" {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	uid, err := uuid.Parse(dto.UserId)
	if err != nil {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	gid, err := uuid.Parse(dto.GroupId)
	if err != nil {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	// Authorization mirrors Kotlin PinController.createPin:
	// hasAuthority('ADMIN') || (isGroupMember(groupId) && isSameUser(userId)).
	caller, ok := ctxUserID(ctx)
	if !ok {
		return genserver.Response(http.StatusUnauthorized, nil), nil
	}
	if !ctxIsAdmin(ctx) {
		isMember, _ := s.guard.IsGroupMember(ctx, gid, caller)
		if !isMember || caller != uid {
			return genserver.Response(http.StatusForbidden, nil), nil
		}
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
		return serviceErrResp(err), nil
	}
	return genserver.Response(http.StatusCreated, pinDTOtoDto(result)), nil
}

func (s *PinsServicer) GetPin(ctx context.Context, pinID string, withImage bool) (genserver.ImplResponse, error) {
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
		return serviceErrResp(err), nil
	}
	result := pinDTOtoDto(dto)
	if !withImage {
		result.Image = ""
	} else {
		imgURL, _ := s.pin.ImageURL(ctx, id)
		if imgURL != nil {
			result.Image = *imgURL
		}
	}
	return genserver.Response(http.StatusOK, result), nil
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
		return serviceErrResp(err), nil
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
		return serviceErrResp(err), nil
	}
	if u == nil {
		return genserver.Response(http.StatusOK, nil), nil
	}
	if redirect {
		return genserver.Response(http.StatusOK, *u), nil
	}
	return genserver.Response(http.StatusOK, []byte(*u)), nil
}

func (s *PinsServicer) Sync(ctx context.Context, since time.Time) (genserver.ImplResponse, error) {
	uid, ok := ctxUserID(ctx)
	if !ok {
		return genserver.Response(http.StatusUnauthorized, nil), nil
	}
	withUser := true
	// The client uses this membership snapshot to remove groups that are no
	// longer joined, so it must not be truncated by the paginated group API.
	groups, err := s.group.Search(ctx, nil, &uid, &withUser, true, 0, 0, nil)
	if err != nil {
		return serviceErrResp(err), nil
	}
	groupIDs := make([]uuid.UUID, 0, len(groups.Groups))
	for _, g := range groups.Groups {
		groupIDs = append(groupIDs, g.ID)
	}
	deletedPins, err := s.q.ListDeletedPinsAfter(ctx, since)
	if err != nil {
		return serviceErrResp(err), nil
	}
	deletedStrs := make([]string, 0, len(deletedPins))
	for _, id := range deletedPins {
		deletedStrs = append(deletedStrs, id.String())
	}
	updatedPins, err := s.q.ListUpdatedPinsForGroups(ctx, groupIDs, &since)
	if err != nil {
		return serviceErrResp(err), nil
	}
	pinsByGroup := make(map[uuid.UUID][]genserver.PinWithOptionalImageDto)
	for _, p := range updatedPins {
		dto := pinToDto(p)
		if imgURL, _ := s.pin.ImageURL(ctx, p.ID); imgURL != nil {
			dto.Image = *imgURL
		}
		pinsByGroup[p.GroupID] = append(pinsByGroup[p.GroupID], dto)
	}
	groupUpdates := make([]genserver.SyncDtoGroupUpdatesInner, 0, len(groups.Groups))
	for _, g := range groups.Groups {
		dto := toGroupDto(g, true)
		pins := pinsByGroup[g.ID]
		if pins == nil {
			pins = make([]genserver.PinWithOptionalImageDto, 0)
		}
		groupUpdates = append(groupUpdates, genserver.SyncDtoGroupUpdatesInner{
			Group:     dto,
			PinsAdded: pins,
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
