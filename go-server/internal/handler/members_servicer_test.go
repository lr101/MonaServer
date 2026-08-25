package handler

import (
	"context"
	"testing"

	genserver "github.com/lrprojects/monaserver/internal/gen/server"
	"github.com/lrprojects/monaserver/internal/middleware"
	"github.com/lrprojects/monaserver/internal/service"
)

func TestGroupMembersIncludeSelectedAchievement(t *testing.T) {
	authHandler, auth := setupAuthServicer(t)
	q := authHandler.q
	userSvc := service.NewUser(q, nil, nil, auth, nil)
	groupSvc := service.NewGroup(q, nil, userSvc)
	memberSvc := service.NewMember(q, nil, groupSvc)
	servicer := NewMembersServicer(memberSvc, service.NewGuard(q))
	ctx := context.Background()
	user, err := auth.Signup(ctx, "member_badge_user", "password123", nil)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}
	group, err := groupSvc.Create(ctx, service.CreateGroupInput{
		Name: "member_badge_group", Visibility: 0, GroupAdmin: user.UserID,
	})
	if err != nil {
		t.Fatalf("create group: %v", err)
	}
	if err := userSvc.ClaimAchievement(ctx, user.UserID, 4); err != nil {
		t.Fatalf("claim achievement: %v", err)
	}
	rowID, err := q.GetUserAchievementRow(ctx, user.UserID, 4)
	if err != nil || rowID == nil {
		t.Fatalf("get achievement row: %v", err)
	}
	if err := q.SetUserSelectedBatch(ctx, user.UserID, *rowID); err != nil {
		t.Fatalf("select achievement: %v", err)
	}

	userCtx := middleware.WithUser(ctx, user.UserID, middleware.RoleUser)
	resp, err := servicer.GetGroupMembers(userCtx, group.ID.String())
	if err != nil {
		t.Fatalf("get members: %v", err)
	}
	members, ok := resp.Body.([]genserver.MemberResponseDto)
	if !ok {
		t.Fatalf("response body type = %T", resp.Body)
	}
	if len(members) != 1 || members[0].SelectedBatch == nil || *members[0].SelectedBatch != 4 {
		t.Fatalf("members response = %+v, want selectedBatch 4", members)
	}
}
