package handler

import (
	"context"
	"encoding/base64"
	"net/http"
	"time"

	"github.com/google/uuid"

	genserver "github.com/lrprojects/monaserver/internal/gen/server"
	"github.com/lrprojects/monaserver/internal/service"
)

// GroupsServicer implements genserver.GroupsAPIServicer.
type GroupsServicer struct {
	group *service.Group
	guard *service.Guard
}

func NewGroupsServicer(group *service.Group, guard *service.Guard) *GroupsServicer {
	return &GroupsServicer{group: group, guard: guard}
}

func (s *GroupsServicer) GetGroupsByIds(ctx context.Context, ids []string, search, userID string, withUser, withImages bool, page, size int32, updatedAfter time.Time) (genserver.ImplResponse, error) {
	parsedIDs := make([]uuid.UUID, 0, len(ids))
	for _, raw := range ids {
		id, err := uuid.Parse(raw)
		if err != nil {
			return genserver.Response(http.StatusBadRequest, nil), nil
		}
		parsedIDs = append(parsedIDs, id)
	}
	var searchPtr *string
	if search != "" {
		searchPtr = &search
	}
	var uidPtr *uuid.UUID
	var withUserPtr *bool
	if userID != "" {
		u, err := uuid.Parse(userID)
		if err != nil {
			return genserver.Response(http.StatusBadRequest, nil), nil
		}
		uidPtr = &u
		withUserPtr = &withUser
	}
	var afterPtr *time.Time
	if !updatedAfter.IsZero() {
		afterPtr = &updatedAfter
	}
	result, err := s.group.Search(ctx, searchPtr, uidPtr, withUserPtr, withImages, page, size, afterPtr, parsedIDs...)
	if err != nil {
		return serviceErrResp(err), nil
	}
	items := make([]genserver.GroupDto, 0, len(result.Groups))
	caller, hasCaller := ctxUserID(ctx)
	for _, g := range result.Groups {
		includePrivate := g.Visibility == 0
		if !includePrivate && hasCaller {
			includePrivate, _ = s.guard.IsGroupMember(ctx, g.ID, caller)
		}
		items = append(items, toGroupDto(g, includePrivate))
	}
	deleted := make([]string, 0, len(result.Deleted))
	for _, id := range result.Deleted {
		deleted = append(deleted, id.String())
	}
	return genserver.Response(http.StatusOK, genserver.GroupsSyncDto{Items: items, Deleted: deleted}), nil
}

func (s *GroupsServicer) AddGroup(ctx context.Context, dto genserver.CreateGroupDto) (genserver.ImplResponse, error) {
	if dto.ProfileImage == "" {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	uid, ok := ctxUserID(ctx)
	if !ok {
		return genserver.Response(http.StatusUnauthorized, nil), nil
	}
	groupAdminID := uid
	if dto.GroupAdmin != "" {
		id, err := uuid.Parse(dto.GroupAdmin)
		if err != nil {
			return genserver.Response(http.StatusBadRequest, nil), nil
		}
		groupAdminID = id
	}
	// Authorization mirrors Kotlin GroupController.addGroup:
	// hasAuthority('ADMIN') || isSameUser(groupAdmin).
	if !ctxIsAdmin(ctx) && groupAdminID != uid {
		return genserver.Response(http.StatusForbidden, nil), nil
	}
	var imgBytes []byte
	if dto.ProfileImage != "" {
		b, err := base64.StdEncoding.DecodeString(dto.ProfileImage)
		if err != nil {
			return genserver.Response(http.StatusBadRequest, nil), nil
		}
		imgBytes = b
	}
	result, err := s.group.Create(ctx, service.CreateGroupInput{
		Name:         dto.Name,
		Description:  strNilable(dto.Description),
		Link:         strNilable(dto.Link),
		Visibility:   int(dto.Visibility),
		GroupAdmin:   groupAdminID,
		ProfileImage: imgBytes,
	})
	if err != nil {
		return serviceErrResp(err), nil
	}
	return genserver.Response(http.StatusCreated, toGroupDto(result, true)), nil
}

func (s *GroupsServicer) GetGroup(ctx context.Context, groupID string) (genserver.ImplResponse, error) {
	id, err := uuid.Parse(groupID)
	if err != nil {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	dto, err := s.group.GetDTO(ctx, id)
	if err != nil {
		return serviceErrResp(err), nil
	}
	includePrivate := dto.Visibility == 0
	if !includePrivate {
		uid, ok := ctxUserID(ctx)
		if ok {
			includePrivate, _ = s.guard.IsGroupMember(ctx, id, uid)
		}
	}
	return genserver.Response(http.StatusOK, toGroupDto(dto, includePrivate)), nil
}

func (s *GroupsServicer) UpdateGroup(ctx context.Context, groupID string, dto genserver.UpdateGroupDto) (genserver.ImplResponse, error) {
	id, err := uuid.Parse(groupID)
	if err != nil {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	uid, ok := ctxUserID(ctx)
	if !ok {
		return genserver.Response(http.StatusUnauthorized, nil), nil
	}
	if ok2, _ := s.guard.IsGroupAdmin(ctx, id, uid); !ok2 {
		return genserver.Response(http.StatusForbidden, nil), nil
	}
	var adminID *uuid.UUID
	if dto.GroupAdmin != nil {
		a, err := uuid.Parse(*dto.GroupAdmin)
		if err != nil {
			return genserver.Response(http.StatusBadRequest, nil), nil
		}
		adminID = &a
	}
	var imgBytes []byte
	if dto.ProfileImage != nil {
		if *dto.ProfileImage == "" {
			return genserver.Response(http.StatusBadRequest, nil), nil
		}
		b, err := base64.StdEncoding.DecodeString(*dto.ProfileImage)
		if err != nil {
			return genserver.Response(http.StatusBadRequest, nil), nil
		}
		imgBytes = b
	}
	result, err := s.group.Update(ctx, id, service.UpdateGroupInput{
		Name:         dto.Name,
		Description:  dto.Description,
		Link:         dto.Link,
		Visibility:   int32PtrToInt(dto.Visibility),
		GroupAdmin:   adminID,
		ProfileImage: imgBytes,
	})
	if err != nil {
		return serviceErrResp(err), nil
	}
	return genserver.Response(http.StatusOK, toGroupDto(result, true)), nil
}

func (s *GroupsServicer) DeleteGroup(ctx context.Context, groupID string) (genserver.ImplResponse, error) {
	id, err := uuid.Parse(groupID)
	if err != nil {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	uid, ok := ctxUserID(ctx)
	if !ok {
		return genserver.Response(http.StatusUnauthorized, nil), nil
	}
	if ok2, _ := s.guard.IsGroupAdmin(ctx, id, uid); !ok2 {
		return genserver.Response(http.StatusForbidden, nil), nil
	}
	if err := s.group.Delete(ctx, id); err != nil {
		return serviceErrResp(err), nil
	}
	return genserver.Response(http.StatusOK, nil), nil
}

func (s *GroupsServicer) GetGroupProfileImage(ctx context.Context, groupID string, redirect bool) (genserver.ImplResponse, error) {
	id, err := uuid.Parse(groupID)
	if err != nil {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	u, err := s.group.ProfileImageURL(ctx, id, false)
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

func (s *GroupsServicer) GetGroupProfileImageSmall(ctx context.Context, groupID string, redirect bool) (genserver.ImplResponse, error) {
	id, err := uuid.Parse(groupID)
	if err != nil {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	u, err := s.group.ProfileImageURL(ctx, id, true)
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

func (s *GroupsServicer) GetGroupPinImage(ctx context.Context, groupID string, redirect bool) (genserver.ImplResponse, error) {
	id, err := uuid.Parse(groupID)
	if err != nil {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	u, err := s.group.PinImageURL(ctx, id)
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

func (s *GroupsServicer) GetGroupDescription(ctx context.Context, groupID string) (genserver.ImplResponse, error) {
	id, err := uuid.Parse(groupID)
	if err != nil {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	uid, ok := ctxUserID(ctx)
	if !ok {
		return genserver.Response(http.StatusUnauthorized, nil), nil
	}
	if ok2, _ := s.guard.IsGroupVisible(ctx, id, uid); !ok2 {
		return genserver.Response(http.StatusForbidden, nil), nil
	}
	dto, err := s.group.GetDTO(ctx, id)
	if err != nil {
		return serviceErrResp(err), nil
	}
	return genserver.Response(http.StatusOK, []byte(strDeref(dto.Description))), nil
}

func (s *GroupsServicer) GetGroupLink(ctx context.Context, groupID string) (genserver.ImplResponse, error) {
	id, err := uuid.Parse(groupID)
	if err != nil {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	uid, ok := ctxUserID(ctx)
	if !ok {
		return genserver.Response(http.StatusUnauthorized, nil), nil
	}
	if ok2, _ := s.guard.IsGroupVisible(ctx, id, uid); !ok2 {
		return genserver.Response(http.StatusForbidden, nil), nil
	}
	dto, err := s.group.GetDTO(ctx, id)
	if err != nil {
		return serviceErrResp(err), nil
	}
	return genserver.Response(http.StatusOK, []byte(strDeref(dto.Link))), nil
}

func (s *GroupsServicer) GetGroupAdmin(ctx context.Context, groupID string) (genserver.ImplResponse, error) {
	id, err := uuid.Parse(groupID)
	if err != nil {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	uid, ok := ctxUserID(ctx)
	if !ok {
		return genserver.Response(http.StatusUnauthorized, nil), nil
	}
	if ok2, _ := s.guard.IsGroupVisible(ctx, id, uid); !ok2 {
		return genserver.Response(http.StatusForbidden, nil), nil
	}
	admin, err := s.group.GetAdminUsername(ctx, id)
	if err != nil {
		return serviceErrResp(err), nil
	}
	return genserver.Response(http.StatusOK, []byte(admin)), nil
}

func (s *GroupsServicer) GetGroupInviteUrl(ctx context.Context, groupID string) (genserver.ImplResponse, error) {
	id, err := uuid.Parse(groupID)
	if err != nil {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	uid, ok := ctxUserID(ctx)
	if !ok {
		return genserver.Response(http.StatusUnauthorized, nil), nil
	}
	if ok2, _ := s.guard.IsGroupVisible(ctx, id, uid); !ok2 {
		return genserver.Response(http.StatusForbidden, nil), nil
	}
	dto, err := s.group.GetDTO(ctx, id)
	if err != nil {
		return serviceErrResp(err), nil
	}
	return genserver.Response(http.StatusOK, []byte(strDeref(dto.InviteUrl))), nil
}

// strNilable returns nil for empty string, otherwise a pointer to the string.
func strNilable(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}

func int32PtrToInt(n *int32) *int {
	if n == nil {
		return nil
	}
	v := int(*n)
	return &v
}
