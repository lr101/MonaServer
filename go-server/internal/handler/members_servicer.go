package handler

import (
	"context"
	"net/http"

	"github.com/google/uuid"

	"github.com/lrprojects/monaserver/internal/apperrors"
	genserver "github.com/lrprojects/monaserver/internal/gen/server"
	"github.com/lrprojects/monaserver/internal/service"
)

// MembersServicer implements genserver.MembersAPIServicer.
type MembersServicer struct {
	member *service.Member
	guard  *service.Guard
}

func NewMembersServicer(member *service.Member, guard *service.Guard) *MembersServicer {
	return &MembersServicer{member: member, guard: guard}
}

func (s *MembersServicer) GetGroupMembers(ctx context.Context, groupID string) (genserver.ImplResponse, error) {
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
	members, err := s.member.Ranking(ctx, id)
	if err != nil {
		return genserver.Response(apperrors.HTTPStatus(err), nil), nil
	}
	dtos := make([]genserver.MemberResponseDto, 0, len(members))
	for _, m := range members {
		dto := genserver.MemberResponseDto{
			UserId:   m.UserID.String(),
			Username: m.Username,
			Ranking:  int32(m.Ranking),
		}
		if m.ProfileImageSmall != nil {
			dto.ProfileImageSmall = *m.ProfileImageSmall
		}
		dtos = append(dtos, dto)
	}
	return genserver.Response(http.StatusOK, dtos), nil
}

func (s *MembersServicer) JoinGroup(ctx context.Context, groupID, userID, inviteURL string) (genserver.ImplResponse, error) {
	gid, err := uuid.Parse(groupID)
	if err != nil {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	uid, err := uuid.Parse(userID)
	if err != nil {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	var invitePtr *string
	if inviteURL != "" {
		invitePtr = &inviteURL
	}
	dto, err := s.member.Join(ctx, gid, uid, invitePtr)
	if err != nil {
		return genserver.Response(apperrors.HTTPStatus(err), nil), nil
	}
	return genserver.Response(http.StatusOK, toGroupDto(dto)), nil
}

func (s *MembersServicer) DeleteMemberFromGroup(ctx context.Context, groupID, userID string) (genserver.ImplResponse, error) {
	gid, err := uuid.Parse(groupID)
	if err != nil {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	target, err := uuid.Parse(userID)
	if err != nil {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	caller, ok := ctxUserID(ctx)
	if !ok {
		return genserver.Response(http.StatusUnauthorized, nil), nil
	}
	isSelf := caller == target
	isAdmin, _ := s.guard.IsGroupAdmin(ctx, gid, caller)
	if !isSelf && !isAdmin {
		return genserver.Response(http.StatusForbidden, nil), nil
	}
	if err := s.member.Leave(ctx, gid, target); err != nil {
		return genserver.Response(apperrors.HTTPStatus(err), nil), nil
	}
	return genserver.Response(http.StatusOK, nil), nil
}
