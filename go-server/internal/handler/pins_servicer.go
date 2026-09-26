package handler

import (
	"context"
	"encoding/base64"
	"math"
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

func (s *PinsServicer) GetPinImagesByIds(ctx context.Context, ids []string, groupID, userID string, withImage bool, compression, height, page, size int32, updatedAfter, beforeCreationDate time.Time, beforeID string) (genserver.ImplResponse, error) {
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
	var beforeDate *time.Time
	if !beforeCreationDate.IsZero() {
		beforeDate = &beforeCreationDate
	}
	var beforePinID *uuid.UUID
	if beforeID != "" {
		id, err := uuid.Parse(beforeID)
		if err != nil {
			return genserver.Response(http.StatusBadRequest, nil), nil
		}
		beforePinID = &id
	}
	if (beforeDate == nil) != (beforePinID == nil) {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	limit := size
	offset := page * size
	if len(parsedIDs) > 0 {
		limit = 0
		offset = 0
	}
	if beforeDate != nil {
		// Keyset pagination owns the position once a cursor is supplied. The
		// page field remains accepted for older clients and diagnostics, but an
		// offset would reintroduce skips when rows are inserted or deleted.
		offset = 0
	}
	pins, err := s.q.SearchPins(ctx, db.PinSearch{
		CallerID: caller, IDs: parsedIDs, GroupID: gid, CreatorID: creatorID,
		UpdatedAfter: after, BeforeCreationDate: beforeDate, BeforeID: beforePinID,
		Limit: limit, Offset: offset,
	})
	if err != nil {
		return serviceErrResp(ctx, err), nil
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
			return serviceErrResp(ctx, err), nil
		}
		for _, id := range deletedIDs {
			deleted = append(deleted, id.String())
		}
	}
	return genserver.Response(http.StatusOK, genserver.PinsSyncDto{Items: items, Deleted: deleted}), nil
}

func (s *PinsServicer) GetNearbyPins(ctx context.Context, latitude, longitude float64, radiusMeters int32) (genserver.ImplResponse, error) {
	caller, ok := ctxUserID(ctx)
	if !ok {
		return genserver.Response(http.StatusUnauthorized, nil), nil
	}
	if math.IsNaN(latitude) || math.IsInf(latitude, 0) || latitude < -90 || latitude > 90 ||
		math.IsNaN(longitude) || math.IsInf(longitude, 0) || longitude < -180 || longitude > 180 ||
		radiusMeters < 1 || radiusMeters > 1000 {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}

	pins, err := s.q.FindNearbyPins(ctx, caller, latitude, longitude, radiusMeters, 10)
	if err != nil {
		return serviceErrResp(ctx, err), nil
	}
	items := make([]genserver.NearbyPinDto, 0, len(pins))
	for _, nearby := range pins {
		pin := pinToDto(nearby.Pin)
		if imageURL, err := s.pin.LatestImageURL(ctx, nearby.Pin.ID); err == nil && imageURL != nil {
			pin.Image = *imageURL
		}
		items = append(items, genserver.NearbyPinDto{
			Pin: pin, DistanceMeters: nearby.DistanceMeters, GroupName: nearby.GroupName,
		})
	}
	return genserver.Response(http.StatusOK, genserver.NearbyPinsDto{Items: items}), nil
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
		return serviceErrResp(ctx, err), nil
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
		return serviceErrResp(ctx, err), nil
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

func (s *PinsServicer) SetPinPresence(ctx context.Context, pinID string, request genserver.PinPresenceRequestDto) (genserver.ImplResponse, error) {
	id, err := uuid.Parse(pinID)
	if err != nil {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	var isGone bool
	switch request.State {
	case "here":
		isGone = false
	case "gone":
		isGone = true
	default:
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	userID, ok := ctxUserID(ctx)
	if !ok {
		return genserver.Response(http.StatusUnauthorized, nil), nil
	}
	visible, err := s.guard.IsPinPublicOrMember(ctx, id, userID)
	if err != nil {
		return serviceErrResp(ctx, err), nil
	}
	if !visible {
		return genserver.Response(http.StatusForbidden, nil), nil
	}
	if err := s.pin.SetGone(ctx, id, isGone); err != nil {
		return serviceErrResp(ctx, err), nil
	}
	result, err := s.pin.Get(ctx, id)
	if err != nil {
		return serviceErrResp(ctx, err), nil
	}
	return genserver.Response(http.StatusOK, pinDTOtoDto(result)), nil
}

func (s *PinsServicer) GetPinPhotos(ctx context.Context, pinID string) (genserver.ImplResponse, error) {
	id, err := uuid.Parse(pinID)
	if err != nil {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	userID, ok := ctxUserID(ctx)
	if !ok {
		return genserver.Response(http.StatusUnauthorized, nil), nil
	}
	visible, err := s.guard.IsPinPublicOrMember(ctx, id, userID)
	if err != nil {
		return serviceErrResp(ctx, err), nil
	}
	if !visible {
		return genserver.Response(http.StatusForbidden, nil), nil
	}
	photos, err := s.pin.Photos(ctx, id)
	if err != nil {
		return serviceErrResp(ctx, err), nil
	}
	result := make([]genserver.PinPhotoDto, 0, len(photos))
	for i := range photos {
		result = append(result, pinPhotoToDto(photos[i]))
	}
	return genserver.Response(http.StatusOK, result), nil
}

func (s *PinsServicer) AddPinPhoto(ctx context.Context, pinID string, request genserver.PinPhotoRequestDto) (genserver.ImplResponse, error) {
	id, err := uuid.Parse(pinID)
	if err != nil {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	userID, ok := ctxUserID(ctx)
	if !ok {
		return genserver.Response(http.StatusUnauthorized, nil), nil
	}
	visible, err := s.guard.IsPinPublicOrMember(ctx, id, userID)
	if err != nil {
		return serviceErrResp(ctx, err), nil
	}
	if !visible {
		return genserver.Response(http.StatusForbidden, nil), nil
	}
	if len(request.Image) > base64.StdEncoding.EncodedLen(8<<20) {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	imageBytes, err := base64.StdEncoding.DecodeString(request.Image)
	if err != nil {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	idempotencyKey, err := uuid.Parse(request.IdempotencyKey)
	if err != nil || idempotencyKey == uuid.Nil {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	photo, err := s.pin.AddPhoto(ctx, id, userID, service.AddPinPhotoInput{
		Image: imageBytes, IdempotencyKey: idempotencyKey,
		Latitude: float64(request.Latitude), Longitude: float64(request.Longitude),
		AccuracyMeters: float64(request.AccuracyMeters), Caption: request.Caption,
	})
	if err != nil {
		return serviceErrResp(ctx, err), nil
	}
	return genserver.Response(http.StatusCreated, pinPhotoToDto(*photo)), nil
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
		return serviceErrResp(ctx, err), nil
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
		return serviceErrResp(ctx, err), nil
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
		return serviceErrResp(ctx, err), nil
	}
	groupIDs := make([]uuid.UUID, 0, len(groups.Groups))
	for _, g := range groups.Groups {
		groupIDs = append(groupIDs, g.ID)
	}
	deletedPins, err := s.q.ListDeletedPinsAfter(ctx, since)
	if err != nil {
		return serviceErrResp(ctx, err), nil
	}
	deletedStrs := make([]string, 0, len(deletedPins))
	for _, id := range deletedPins {
		deletedStrs = append(deletedStrs, id.String())
	}
	updatedPins, err := s.q.ListUpdatedPinsForGroups(ctx, groupIDs, &since)
	if err != nil {
		return serviceErrResp(ctx, err), nil
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
	isGone := p.IsGone
	return genserver.PinWithOptionalImageDto{
		Id:           p.ID.String(),
		CreationDate: creationDate,
		Latitude:     float32(p.Latitude),
		Longitude:    float32(p.Longitude),
		CreationUser: p.CreatorID.String(),
		GroupId:      p.GroupID.String(),
		Description:  p.Description,
		IsGone:       &isGone,
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
	isGone := p.IsGone
	return genserver.PinWithOptionalImageDto{
		Id:           p.ID.String(),
		CreationDate: creationDate,
		Latitude:     float32(p.Latitude),
		Longitude:    float32(p.Longitude),
		CreationUser: p.UserID.String(),
		GroupId:      p.GroupID.String(),
		Description:  p.Description,
		IsGone:       &isGone,
		Image:        img,
	}
}

func pinPhotoToDto(photo service.PinPhotoDTO) genserver.PinPhotoDto {
	var contributorID *string
	if photo.ContributorID != nil {
		value := photo.ContributorID.String()
		contributorID = &value
	}
	return genserver.PinPhotoDto{
		Id: photo.ID.String(), PinId: photo.PinID.String(),
		ContributorId: contributorID, ContributorUsername: photo.ContributorUsername,
		Image: photo.Image, Caption: photo.Caption,
		ObservedAt: photo.ObservedAt, IsOriginal: photo.IsOriginal,
	}
}
