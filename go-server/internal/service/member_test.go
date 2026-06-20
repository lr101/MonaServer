package service

import (
	"context"
	"testing"
)

func TestMemberJoinAndLeave(t *testing.T) {
	_, auth, _, _, _, group, member, _, guard := setupServices(t)
	ctx := context.Background()

	adminID := createTestUser(t, auth, "groupowner")
	memberID := createTestUser(t, auth, "newmember")
	gid := createTestGroup(t, group, adminID, "opengroup")

	t.Run("join public group", func(t *testing.T) {
		dto, err := member.Join(ctx, gid, memberID, nil)
		if err != nil {
			t.Fatalf("join: %v", err)
		}
		if dto.ID != gid {
			t.Fatalf("returned wrong group")
		}
	})

	t.Run("join twice rejected", func(t *testing.T) {
		if _, err := member.Join(ctx, gid, memberID, nil); err == nil {
			t.Fatal("expected conflict on double-join")
		}
	})

	t.Run("guard IsGroupMember returns true", func(t *testing.T) {
		ok, err := guard.IsGroupMember(ctx, gid, memberID)
		if err != nil {
			t.Fatalf("guard: %v", err)
		}
		if !ok {
			t.Fatal("expected IsMember=true after join")
		}
	})

	t.Run("member ranking", func(t *testing.T) {
		members, err := member.Ranking(ctx, gid)
		if err != nil {
			t.Fatalf("ranking: %v", err)
		}
		ids := make(map[string]bool)
		for _, m := range members {
			ids[m.UserID.String()] = true
		}
		if !ids[adminID.String()] {
			t.Fatal("admin not in member ranking")
		}
		if !ids[memberID.String()] {
			t.Fatal("member not in member ranking")
		}
	})

	t.Run("non-admin member can leave", func(t *testing.T) {
		if err := member.Leave(ctx, gid, memberID); err != nil {
			t.Fatalf("leave: %v", err)
		}
		ok, _ := guard.IsGroupMember(ctx, gid, memberID)
		if ok {
			t.Fatal("expected IsMember=false after leave")
		}
	})

	t.Run("admin cannot leave non-empty group", func(t *testing.T) {
		uid2 := createTestUser(t, auth, "secondmember")
		if _, err := member.Join(ctx, gid, uid2, nil); err != nil {
			t.Fatalf("join uid2: %v", err)
		}
		if err := member.Leave(ctx, gid, adminID); err == nil {
			t.Fatal("expected error: admin cannot leave with other members")
		}
	})
}

func TestMemberPrivateGroupInvite(t *testing.T) {
	_, auth, _, _, _, group, member, _, _ := setupServices(t)
	ctx := context.Background()

	adminID := createTestUser(t, auth, "privateadmin")
	userID := createTestUser(t, auth, "privatejoin")

	vis := 1
	g, err := group.Create(ctx, CreateGroupInput{
		Name:       "privategroup",
		Visibility: vis,
		GroupAdmin: adminID,
	})
	if err != nil {
		t.Fatalf("create private group: %v", err)
	}

	t.Run("join private group without invite url fails", func(t *testing.T) {
		if _, err := member.Join(ctx, g.ID, userID, nil); err == nil {
			t.Fatal("expected error joining private group without invite")
		}
	})

	t.Run("join private group with invite url succeeds", func(t *testing.T) {
		if _, err := member.Join(ctx, g.ID, userID, g.InviteUrl); err != nil {
			t.Fatalf("join with invite: %v", err)
		}
	})
}
