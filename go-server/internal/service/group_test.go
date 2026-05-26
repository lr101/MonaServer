package service

import (
	"context"
	"testing"
)

func TestGroupCreateGetUpdate(t *testing.T) {
	_, auth, _, _, _, group, _, _, _ := setupServices(t)
	ctx := context.Background()

	uid := createTestUser(t, auth, "groupadmin")

	t.Run("create public group", func(t *testing.T) {
		gid := createTestGroup(t, group, uid, "myfirstgroup")
		g, err := group.Get(ctx, gid)
		if err != nil {
			t.Fatalf("get: %v", err)
		}
		if g.Name != "myfirstgroup" {
			t.Fatalf("name mismatch: %q", g.Name)
		}
		if g.AdminID != uid {
			t.Fatalf("admin mismatch")
		}
	})

	t.Run("duplicate group name rejected", func(t *testing.T) {
		createTestGroup(t, group, uid, "duplicatename")
		if _, err := group.Create(ctx, CreateGroupInput{
			Name:       "duplicatename",
			Visibility: 0,
			GroupAdmin: uid,
		}); err == nil {
			t.Fatal("expected conflict on duplicate name")
		}
	})

	t.Run("get dto", func(t *testing.T) {
		gid := createTestGroup(t, group, uid, "dtogrouptest")
		dto, err := group.GetDTO(ctx, gid)
		if err != nil {
			t.Fatalf("get dto: %v", err)
		}
		if dto.ID != gid {
			t.Fatalf("id mismatch")
		}
	})

	t.Run("update group name", func(t *testing.T) {
		gid := createTestGroup(t, group, uid, "oldname")
		newName := "newname"
		dto, err := group.Update(ctx, gid, UpdateGroupInput{Name: &newName})
		if err != nil {
			t.Fatalf("update: %v", err)
		}
		if dto.Name != newName {
			t.Fatalf("name not updated: %q", dto.Name)
		}
	})

	t.Run("get admin username", func(t *testing.T) {
		gid := createTestGroup(t, group, uid, "admintest")
		name, err := group.GetAdminUsername(ctx, gid)
		if err != nil {
			t.Fatalf("get admin username: %v", err)
		}
		if name != "groupadmin" {
			t.Fatalf("got %q", name)
		}
	})

	t.Run("search by name", func(t *testing.T) {
		gid := createTestGroup(t, group, uid, "searchable_group")
		s := "searchable"
		result, err := group.Search(ctx, &s, nil, nil, false, 0, 10, nil)
		if err != nil {
			t.Fatalf("search: %v", err)
		}
		found := false
		for _, g := range result.Groups {
			if g.ID == gid {
				found = true
			}
		}
		if !found {
			t.Fatalf("created group not found in search results")
		}
	})

	t.Run("delete group", func(t *testing.T) {
		gid := createTestGroup(t, group, uid, "todeletegrp")
		if err := group.Delete(ctx, gid); err != nil {
			t.Fatalf("delete: %v", err)
		}
		if _, err := group.Get(ctx, gid); err == nil {
			t.Fatal("expected not-found after delete")
		}
	})
}
