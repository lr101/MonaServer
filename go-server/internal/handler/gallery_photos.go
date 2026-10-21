package handler

import (
	"context"
	"github.com/google/uuid"
	"github.com/lrprojects/monaserver/internal/db"
	genserver "github.com/lrprojects/monaserver/internal/gen/server"
)

func (s *PinsServicer) GetGalleryPhotos(ctx context.Context, userID, groupID, cursor string, limit int32) (genserver.ImplResponse, error) {
	caller, ok := ctxUserID(ctx)
	if !ok {
		return genserver.Response(401, nil), nil
	}
	in := db.GalleryPhotoSearch{CallerID: caller, Limit: limit}
	if (userID == "") == (groupID == "") {
		return genserver.Response(400, nil), nil
	}
	scope := "user:" + userID
	if userID != "" {
		id, err := uuid.Parse(userID)
		if err != nil {
			return genserver.Response(400, nil), nil
		}
		in.ContributorID = &id
	}
	if groupID != "" {
		id, err := uuid.Parse(groupID)
		if err != nil {
			return genserver.Response(400, nil), nil
		}
		in.GroupID = &id
		scope = "group:" + groupID
		visible, err := s.guard.IsGroupVisible(ctx, id, caller)
		if err != nil {
			return serviceErrResp(ctx, err), nil
		}
		if !visible {
			return genserver.Response(403, nil), nil
		}
	}
	photos, next, err := s.pin.Gallery(ctx, in, cursor, scope)
	if err != nil {
		return serviceErrResp(ctx, err), nil
	}
	result := genserver.GalleryPhotoPageDto{Items: make([]genserver.GalleryPhotoDto, 0, len(photos)), NextCursor: next}
	for _, item := range photos {
		result.Items = append(result.Items, genserver.GalleryPhotoDto{Pin: pinToDto(item.Pin), Photo: pinPhotoToDto(item.Photo)})
	}
	return genserver.Response(200, result), nil
}
func (s *PinsServicer) ResolvePhotos(ctx context.Context, request genserver.PhotoResolveRequestDto) (genserver.ImplResponse, error) {
	caller, ok := ctxUserID(ctx)
	if !ok {
		return genserver.Response(401, nil), nil
	}
	if len(request.PhotoIds) < 1 || len(request.PhotoIds) > 100 {
		return genserver.Response(400, nil), nil
	}
	ids := make([]uuid.UUID, 0, len(request.PhotoIds))
	for _, raw := range request.PhotoIds {
		if id, err := uuid.Parse(raw); err == nil {
			ids = append(ids, id)
		}
	}
	result := genserver.PhotoResolveResponseDto{Items: make([]genserver.PhotoResolveItemDto, 0, len(request.PhotoIds))}
	// An all-invalid batch must not turn into the query's unrestricted discovery.
	if len(ids) == 0 {
		for _, raw := range request.PhotoIds {
			result.Items = append(result.Items, genserver.PhotoResolveItemDto{PhotoId: raw, Status: 400})
		}
		return genserver.Response(200, result), nil
	}
	photos, err := s.pin.ResolvePhotoURLs(ctx, caller, ids)
	if err != nil {
		return serviceErrResp(ctx, err), nil
	}
	for _, raw := range request.PhotoIds {
		item := genserver.PhotoResolveItemDto{PhotoId: raw, Status: 404}
		id, err := uuid.Parse(raw)
		if err != nil {
			item.Status = 400
		} else if photo, ok := photos[id]; ok {
			if photo == nil {
				item.Status = 503
			} else {
				item.Status = 200
				item.Photo = pinPhotoToDto(*photo)
			}
		}
		result.Items = append(result.Items, item)
	}
	return genserver.Response(200, result), nil
}
