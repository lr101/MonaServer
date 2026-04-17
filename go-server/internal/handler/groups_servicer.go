package handler

import (
	"context"
	"net/http"
	"time"

	"github.com/google/uuid"

	"github.com/lrprojects/monaserver/internal/apperrors"
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
	result, err := s.group.Search(ctx, searchPtr, uidPtr, withUserPtr, withImages, page, size, afterPtr)
	if err != nil {
		return genserver.Response(apperrors.HTTPStatus(err), nil), nil
	}
	items := make([]genserver.GroupDto, 0, len(result.Groups))
	for _, g := range result.Groups {
		items = append(items, toGroupDto(g))
	}
	deleted := make([]string, 0, len(result.Deleted))
	for _, id := range result.Deleted {
		deleted = append(deleted, id.String())
	}
	return genserver.Response(http.StatusOK, genserver.GroupsSyncDto{Items: items, Deleted: deleted}), nil
}

func (s *GroupsServicer) AddGroup(ctx context.Context, dto genserver.CreateGroupDto) (genserver.ImplResponse, error) {
	uid, ok := ctxUserID(ctx)
	if !ok {
		return genserver.Response(http.StatusUnauthorized, nil), nil
	}
	groupAdminID := uid
	if dto.GroupAdmin != "" {
		if id, err := uuid.Parse(dto.GroupAdmin); err == nil {
			groupAdminID = id
		}
	}
	result, err := s.group.Create(ctx, service.CreateGroupInput{
		Name:        dto.Name,
		Description: strNilable(dto.Description),
		Link:        strNilable(dto.Link),
		Visibility:  int(dto.Visibility),
		GroupAdmin:  groupAdminID,
	})
	if err != nil {
		return genserver.Response(apperrors.HTTPStatus(err), nil), nil
	}
	return genserver.Response(http.StatusCreated, toGroupDto(result)), nil
}

func (s *GroupsServicer) GetGroup(ctx context.Context, groupID string) (genserver.ImplResponse, error) {
	id, err := uuid.Parse(groupID)
	if err != nil {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	dto, err := s.group.GetDTO(ctx, id)
	if err != nil {
		return genserver.Response(apperrors.HTTPStatus(err), nil), nil
	}
	return genserver.Response(http.StatusOK, toGroupDto(dto)), nil
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
	if dto.GroupAdmin != "" {
		if a, err2 := uuid.Parse(dto.GroupAdmin); err2 == nil {
			adminID = &a
		}
	}
	result, err := s.group.Update(ctx, id, service.UpdateGroupInput{
		Name:        strNilable(dto.Name),
		Description: strNilable(dto.Description),
		Link:        strNilable(dto.Link),
		Visibility:  intNilable(int(dto.Visibility)),
		GroupAdmin:  adminID,
	})
	if err != nil {
		return genserver.Response(apperrors.HTTPStatus(err), nil), nil
	}
	return genserver.Response(http.StatusOK, toGroupDto(result)), nil
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
		return genserver.Response(apperrors.HTTPStatus(err), nil), nil
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

func (s *GroupsServicer) GetGroupProfileImageSmall(ctx context.Context, groupID string, redirect bool) (genserver.ImplResponse, error) {
	id, err := uuid.Parse(groupID)
	if err != nil {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	u, err := s.group.ProfileImageURL(ctx, id, true)
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

func (s *GroupsServicer) GetGroupPinImage(ctx context.Context, groupID string, redirect bool) (genserver.ImplResponse, error) {
	id, err := uuid.Parse(groupID)
	if err != nil {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	u, err := s.group.PinImageURL(ctx, id)
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
		return genserver.Response(apperrors.HTTPStatus(err), nil), nil
	}
	return genserver.Response(http.StatusOK, strDeref(dto.Description)), nil
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
		return genserver.Response(apperrors.HTTPStatus(err), nil), nil
	}
	return genserver.Response(http.StatusOK, strDeref(dto.Link)), nil
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
		return genserver.Response(apperrors.HTTPStatus(err), nil), nil
	}
	return genserver.Response(http.StatusOK, admin), nil
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
		return genserver.Response(apperrors.HTTPStatus(err), nil), nil
	}
	return genserver.Response(http.StatusOK, strDeref(dto.InviteUrl)), nil
}

// strNilable returns nil for empty string, otherwise a pointer to the string.
func strNilable(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}

// intNilable returns nil for zero, otherwise a pointer to the int.
func intNilable(n int) *int {
	if n == 0 {
		return nil
	}
	return &n
}
