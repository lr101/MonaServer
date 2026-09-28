package handler

import (
	"context"
	"fmt"
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
	for i := 2; i <= 25; i++ {
		if _, err := groupSvc.Create(ctx, service.CreateGroupInput{
			Name:       fmt.Sprintf("member_badge_group_%d", i),
			Visibility: 0, GroupAdmin: user.UserID,
		}); err != nil {
			t.Fatalf("create qualifying group %d: %v", i, err)
		}
	}
	if err := userSvc.ClaimAchievement(ctx, user.UserID, 21); err != nil {
		t.Fatalf("claim achievement: %v", err)
	}
	rowID, err := q.GetUserAchievementRow(ctx, user.UserID, 21)
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
	if len(members) != 1 || members[0].SelectedBatch == nil || *members[0].SelectedBatch != 21 {
		t.Fatalf("members response = %+v, want selectedBatch 21", members)
	}
}
