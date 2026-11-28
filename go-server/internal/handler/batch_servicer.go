package handler

import (
	"context"
	"errors"
	"net/http"
	"sync"

	"github.com/google/uuid"

	genserver "github.com/lrprojects/monaserver/internal/gen/server"
	"github.com/lrprojects/monaserver/internal/service"
)

const (
	maxBatchReadRequests    = 100
	maxBatchReadConcurrency = 8
)

var batchReadKinds = map[string]struct{}{
	"pinImage":          {},
	"pinImageThumbnail": {},
	"userImageSmall":    {},
	"userImage":         {},
	"groupImageSmall":   {},
	"groupImage":        {},
	"groupPinImage":     {},
	"user":              {},
	"pinLikes":          {},
	"userProgression":   {},
	"groupProgression":  {},
}

// BatchServicer composes existing read servicers without making loopback HTTP calls.
type BatchServicer struct {
	pins   *PinsServicer
	users  *UsersServicer
	groups *GroupsServicer
	likes  *LikesServicer
	guard  *service.Guard
}

func NewBatchServicer(pins *PinsServicer, users *UsersServicer, groups *GroupsServicer, likes *LikesServicer, guard *service.Guard) *BatchServicer {
	return &BatchServicer{pins: pins, users: users, groups: groups, likes: likes, guard: guard}
}

// BatchAPIErrorHandler maps generated request parsing and required-field errors to 400.
func BatchAPIErrorHandler(w http.ResponseWriter, r *http.Request, err error, result *genserver.ImplResponse) {
	if result == nil {
		code := http.StatusBadRequest
		_ = genserver.EncodeJSONResponse(err.Error(), &code, w)
		return
	}
	genserver.DefaultErrorHandler(w, r, err, result)
}

func (s *BatchServicer) BatchRead(ctx context.Context, request genserver.BatchReadRequest) (genserver.ImplResponse, error) {
	viewerID, ok := ctxUserID(ctx)
	if !ok {
		return genserver.Response(http.StatusUnauthorized, nil), nil
	}
	if len(request.Requests) < 1 || len(request.Requests) > maxBatchReadRequests {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	for _, item := range request.Requests {
		if _, ok := batchReadKinds[item.Kind]; !ok {
			return genserver.Response(http.StatusBadRequest, nil), nil
		}
		if _, err := uuid.Parse(item.Id); err != nil {
			return genserver.Response(http.StatusBadRequest, nil), nil
		}
	}

	userIDs := batchItemIDs(request.Requests, "userProgression")
	userProgressions := make(map[uuid.UUID]service.AvatarLevelProgression, len(userIDs))
	if len(userIDs) > 0 {
		loaded, err := s.users.user.AvatarProgressions(ctx, userIDs)
		if err != nil {
			return serviceErrResp(ctx, err), nil
		}
		userProgressions = loaded
	}
	groupIDs := batchItemIDs(request.Requests, "groupProgression")
	groupProgressions := make(map[uuid.UUID]service.GroupAvatarProgression, len(groupIDs))
	if len(groupIDs) > 0 {
		loaded, err := s.groups.group.AvatarProgressions(ctx, viewerID, groupIDs)
		if err != nil {
			return serviceErrResp(ctx, err), nil
		}
		groupProgressions = loaded
	}

	cache := make(map[string]genserver.BatchReadResult, len(request.Requests))
	uniqueItems := make([]genserver.BatchReadItem, 0, len(request.Requests))
	uniqueKeys := make([]string, 0, len(request.Requests))
	uniqueSeen := make(map[string]struct{}, len(request.Requests))
	for _, item := range request.Requests {
		key := item.Kind + "\x00" + item.Id
		switch item.Kind {
		case "userProgression":
			if _, ok := cache[key]; !ok {
				cache[key] = readUserProgression(item, userProgressions)
			}
		case "groupProgression":
			if _, ok := cache[key]; !ok {
				cache[key] = readGroupProgression(item, groupProgressions)
			}
		default:
			if _, ok := uniqueSeen[key]; !ok {
				uniqueSeen[key] = struct{}{}
				uniqueItems = append(uniqueItems, item)
				uniqueKeys = append(uniqueKeys, key)
			}
		}
	}

	if err := ctx.Err(); err != nil {
		return serviceErrResp(ctx, err), nil
	}

	if len(uniqueItems) == 1 {
		cache[uniqueKeys[0]] = s.readOne(ctx, uniqueItems[0])
	} else if len(uniqueItems) > 1 {
		uniqueResults := make([]genserver.BatchReadResult, len(uniqueItems))
		workers := maxBatchReadConcurrency
		if len(uniqueItems) < workers {
			workers = len(uniqueItems)
		}
		jobs := make(chan int, len(uniqueItems))
		for idx := range uniqueItems {
			jobs <- idx
		}
		close(jobs)

		var wg sync.WaitGroup
		wg.Add(workers)
		for range workers {
			go func() {
				defer wg.Done()
				for idx := range jobs {
					if ctx.Err() != nil {
						return
					}
					uniqueResults[idx] = s.readOne(ctx, uniqueItems[idx])
				}
			}()
		}
		wg.Wait()
		if err := ctx.Err(); err != nil {
			return serviceErrResp(ctx, err), nil
		}
		for idx, key := range uniqueKeys {
			cache[key] = uniqueResults[idx]
		}
	}

	if err := ctx.Err(); err != nil {
		return serviceErrResp(ctx, err), nil
	}

	results := make([]genserver.BatchReadResult, 0, len(request.Requests))
	for _, item := range request.Requests {
		key := item.Kind + "\x00" + item.Id
		results = append(results, cache[key])
	}
	return genserver.Response(http.StatusOK, genserver.BatchReadResponse{Results: results}), nil
}

func batchItemIDs(items []genserver.BatchReadItem, kind string) []uuid.UUID {
	ids := make([]uuid.UUID, 0)
	seen := make(map[uuid.UUID]struct{})
	for _, item := range items {
		if item.Kind != kind {
			continue
		}
		id, _ := uuid.Parse(item.Id)
		if _, ok := seen[id]; ok {
			continue
		}
		seen[id] = struct{}{}
		ids = append(ids, id)
	}
	return ids
}

func readUserProgression(item genserver.BatchReadItem, progressions map[uuid.UUID]service.AvatarLevelProgression) genserver.BatchReadResult {
	result := genserver.BatchReadResult{Kind: item.Kind, Id: item.Id}
	id, _ := uuid.Parse(item.Id)
	progression, ok := progressions[id]
	if !ok {
		result.Status = http.StatusNotFound
		return result
	}
	result.Status = http.StatusOK
	result.Progression = progressionDto(progression)
	return result
}

func readGroupProgression(item genserver.BatchReadItem, progressions map[uuid.UUID]service.GroupAvatarProgression) genserver.BatchReadResult {
	result := genserver.BatchReadResult{Kind: item.Kind, Id: item.Id}
	id, _ := uuid.Parse(item.Id)
	groupProgression, ok := progressions[id]
	if !ok {
		result.Status = http.StatusNotFound
		return result
	}
	if !groupProgression.Visible {
		result.Status = http.StatusForbidden
		return result
	}
	result.Status = http.StatusOK
	result.Progression = progressionDto(groupProgression.Progression)
	return result
}

func progressionDto(progression service.AvatarLevelProgression) *genserver.ProfileProgressionDto {
	return &genserver.ProfileProgressionDto{
		Level:    progression.Level,
		Fraction: progression.Fraction,
	}
}

func (s *BatchServicer) readOne(ctx context.Context, item genserver.BatchReadItem) genserver.BatchReadResult {
	result := genserver.BatchReadResult{Kind: item.Kind, Id: item.Id}
	var response genserver.ImplResponse
	var err error

	switch item.Kind {
	case "pinImage":
		response, err = s.pins.GetPinImage(ctx, item.Id, false)
	case "pinImageThumbnail":
		response, err = s.pins.GetPinImageThumbnail(ctx, item.Id)
	case "userImageSmall":
		response, err = s.users.GetUserProfileImageSmall(ctx, item.Id, false)
	case "userImage":
		response, err = s.users.GetUserProfileImage(ctx, item.Id, false)
	case "groupImageSmall", "groupImage", "groupPinImage":
		response = s.readGroupImage(ctx, item)
	case "user":
		response, err = s.users.GetUser(ctx, item.Id)
	case "pinLikes":
		response, err = s.likes.GetPinLikes(ctx, item.Id)
	}
	if err != nil {
		response = serviceErrResp(ctx, err)
	}
	result.Status = int32(response.Code)
	if response.Code != http.StatusOK || response.Body == nil {
		return result
	}

	switch item.Kind {
	case "pinImage", "pinImageThumbnail", "userImageSmall", "userImage", "groupImageSmall", "groupImage", "groupPinImage":
		if image, ok := response.Body.([]byte); ok {
			result.ImageUrl = string(image)
		}
	case "user":
		if user, ok := response.Body.(genserver.UserInfoDto); ok {
			result.User = &user
		}
	case "pinLikes":
		if likes, ok := response.Body.(genserver.PinLikeDto); ok {
			result.Likes = &likes
		}
	}
	return result
}

func (s *BatchServicer) readGroupImage(ctx context.Context, item genserver.BatchReadItem) genserver.ImplResponse {
	groupID, _ := uuid.Parse(item.Id)
	userID, ok := ctxUserID(ctx)
	if !ok {
		return genserver.Response(http.StatusUnauthorized, nil)
	}
	visible, err := s.guard.IsGroupVisible(ctx, groupID, userID)
	if err != nil {
		return serviceErrResp(ctx, err)
	}
	if !visible {
		return genserver.Response(http.StatusForbidden, nil)
	}

	switch item.Kind {
	case "groupImageSmall":
		response, err := s.groups.GetGroupProfileImageSmall(ctx, item.Id, false)
		if err != nil {
			return serviceErrResp(ctx, err)
		}
		return response
	case "groupImage":
		response, err := s.groups.GetGroupProfileImage(ctx, item.Id, false)
		if err != nil {
			return serviceErrResp(ctx, err)
		}
		return response
	case "groupPinImage":
		response, err := s.groups.GetGroupPinImage(ctx, item.Id, false)
		if err != nil {
			return serviceErrResp(ctx, err)
		}
		return response
	default:
		return serviceErrResp(ctx, errors.New("unsupported batch resource kind"))
	}
}
