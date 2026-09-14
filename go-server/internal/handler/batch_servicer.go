package handler

import (
	"context"
	"errors"
	"net/http"

	"github.com/google/uuid"

	genserver "github.com/lrprojects/monaserver/internal/gen/server"
	"github.com/lrprojects/monaserver/internal/service"
)

const maxBatchReadRequests = 100

var batchReadKinds = map[string]struct{}{
	"pinImage":        {},
	"userImageSmall":  {},
	"userImage":       {},
	"groupImageSmall": {},
	"groupImage":      {},
	"groupPinImage":   {},
	"user":            {},
	"pinLikes":        {},
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
	if _, ok := ctxUserID(ctx); !ok {
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

	results := make([]genserver.BatchReadResult, 0, len(request.Requests))
	cache := make(map[string]genserver.BatchReadResult, len(request.Requests))
	for _, item := range request.Requests {
		if err := ctx.Err(); err != nil {
			return serviceErrResp(ctx, err), nil
		}
		key := item.Kind + "\x00" + item.Id
		result, ok := cache[key]
		if !ok {
			result = s.readOne(ctx, item)
			cache[key] = result
		}
		results = append(results, result)
	}
	return genserver.Response(http.StatusOK, genserver.BatchReadResponse{Results: results}), nil
}

func (s *BatchServicer) readOne(ctx context.Context, item genserver.BatchReadItem) genserver.BatchReadResult {
	result := genserver.BatchReadResult{Kind: item.Kind, Id: item.Id}
	var response genserver.ImplResponse
	var err error

	switch item.Kind {
	case "pinImage":
		response, err = s.pins.GetPinImage(ctx, item.Id, false)
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
	case "pinImage", "userImageSmall", "userImage", "groupImageSmall", "groupImage", "groupPinImage":
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
