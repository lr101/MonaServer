package service

import (
	"bytes"
	"context"
	"errors"
	"image"
	"image/color"
	"image/png"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/lrprojects/monaserver/internal/apperrors"
)

type failingGroupObjectStore struct {
	objects map[string][]byte
	failKey string
	failed  bool
}

func (s *failingGroupObjectStore) Put(_ context.Context, key string, data []byte, _ string) error {
	if key == s.failKey && !s.failed {
		s.failed = true
		return errors.New("injected object-store failure")
	}
	s.objects[key] = bytes.Clone(data)
	return nil
}

func (s *failingGroupObjectStore) GetIfExists(_ context.Context, key string) ([]byte, bool, error) {
	data, ok := s.objects[key]
	return bytes.Clone(data), ok, nil
}

func (s *failingGroupObjectStore) Remove(_ context.Context, key string) error {
	delete(s.objects, key)
	return nil
}

func (s *failingGroupObjectStore) PresignedGet(_ context.Context, _ string) (string, error) {
	return "", nil
}

func groupTestPNG() []byte {
	var output bytes.Buffer
	img := image.NewRGBA(image.Rect(0, 0, 2, 2))
	img.Set(0, 0, color.RGBA{R: 255, A: 255})
	_ = png.Encode(&output, img)
	return output.Bytes()
}

func TestGroupCreateGetUpdate(t *testing.T) {
	q, auth, _, _, pin, group, _, _, _ := setupServices(t)
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

	t.Run("invalid replacement image leaves group unchanged", func(t *testing.T) {
		gid := createTestGroup(t, group, uid, "image_update_original")
		newName := "image_update_should_rollback"
		if _, err := group.Update(ctx, gid, UpdateGroupInput{
			Name: &newName, ProfileImage: []byte("not an image"),
		}); !errors.Is(err, apperrors.ErrBadRequest) {
			t.Fatalf("update error = %v, want bad request", err)
		}
		stored, err := group.Get(ctx, gid)
		if err != nil {
			t.Fatalf("get unchanged group: %v", err)
		}
		if stored.Name != "image_update_original" {
			t.Fatalf("name = %q after failed image update, want original", stored.Name)
		}
	})

	t.Run("object failure restores earlier image writes", func(t *testing.T) {
		gid := createTestGroup(t, group, uid, "image_store_rollback")
		oldPin := []byte("old pin")
		oldLarge := []byte("old large")
		oldSmall := []byte("old small")
		store := &failingGroupObjectStore{objects: map[string][]byte{
			GroupPinKey(gid):            bytes.Clone(oldPin),
			GroupProfileKey(gid, false): bytes.Clone(oldLarge),
			GroupProfileKey(gid, true):  bytes.Clone(oldSmall),
		}, failKey: GroupProfileKey(gid, false)}
		group.obj = store

		newName := "image_store_should_rollback"
		if _, err := group.Update(ctx, gid, UpdateGroupInput{Name: &newName, ProfileImage: groupTestPNG()}); err == nil {
			t.Fatal("expected object-store failure")
		}
		for key, want := range map[string][]byte{
			GroupPinKey(gid): oldPin, GroupProfileKey(gid, false): oldLarge, GroupProfileKey(gid, true): oldSmall,
		} {
			if got := store.objects[key]; !bytes.Equal(got, want) {
				t.Fatalf("object %q = %q after rollback, want %q", key, got, want)
			}
		}
		stored, err := group.Get(ctx, gid)
		if err != nil {
			t.Fatalf("get group after storage failure: %v", err)
		}
		if stored.Name != "image_store_rollback" {
			t.Fatalf("name = %q after storage failure, want original", stored.Name)
		}
		group.obj = nil
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
		pid := createTestPin(t, pin, uid, gid)
		if err := group.Delete(ctx, gid); err != nil {
			t.Fatalf("delete: %v", err)
		}
		if _, err := group.Get(ctx, gid); err == nil {
			t.Fatal("expected not-found after delete")
		}
		var pinCount int
		if err := q.Pool().QueryRow(ctx, `SELECT COUNT(*) FROM pins WHERE id = $1`, pid).Scan(&pinCount); err != nil {
			t.Fatalf("count cascaded pin: %v", err)
		}
		if pinCount != 0 {
			t.Fatalf("deleted group left %d pin rows behind", pinCount)
		}
		if _, err := group.Create(ctx, CreateGroupInput{Name: "todeletegrp", Visibility: 0, GroupAdmin: uid}); err != nil {
			t.Fatalf("reuse deleted group name: %v", err)
		}
	})
}

// TestGroupCreateSideEffects verifies automatic side-effects of group creation:
// admin is enrolled as a member, XP is awarded, and visibility controls invite URL.
func TestGroupCreateSideEffects(t *testing.T) {
	q, auth, _, _, _, group, _, _, guard := setupServices(t)
	ctx := context.Background()

	adminID := createTestUser(t, auth, "sideeffect_admin")

	t.Run("creator is automatically a member", func(t *testing.T) {
		gid := createTestGroup(t, group, adminID, "membercheck")
		ok, err := guard.IsGroupMember(ctx, gid, adminID)
		if err != nil {
			t.Fatalf("guard: %v", err)
		}
		if !ok {
			t.Fatal("admin should be a member immediately after create")
		}
	})

	t.Run("member count is 1 after create", func(t *testing.T) {
		gid := createTestGroup(t, group, adminID, "countcheck")
		dto, err := group.GetDTO(ctx, gid)
		if err != nil {
			t.Fatalf("get dto: %v", err)
		}
		if dto.Members != 1 {
			t.Fatalf("expected 1 member, got %d", dto.Members)
		}
	})

	t.Run("xp awarded to admin on create", func(t *testing.T) {
		before, err := q.GetUserByID(ctx, adminID)
		if err != nil || before == nil {
			t.Fatalf("get user before: %v", err)
		}
		createTestGroup(t, group, adminID, "xpcheck")
		after, err := q.GetUserByID(ctx, adminID)
		if err != nil || after == nil {
			t.Fatalf("get user after: %v", err)
		}
		if after.XP-before.XP != CreateGroupXP {
			t.Fatalf("expected xp delta %d, got %d", CreateGroupXP, after.XP-before.XP)
		}
	})

	t.Run("public group has no invite url", func(t *testing.T) {
		g, err := group.Create(ctx, CreateGroupInput{
			Name:       "publicnourl",
			Visibility: 0,
			GroupAdmin: adminID,
		})
		if err != nil {
			t.Fatalf("create: %v", err)
		}
		if g.InviteUrl != nil {
			t.Fatalf("public group should have no invite url, got %q", *g.InviteUrl)
		}
	})

	t.Run("private group gets invite url", func(t *testing.T) {
		g, err := group.Create(ctx, CreateGroupInput{
			Name:       "privatehasurl",
			Visibility: 1,
			GroupAdmin: adminID,
		})
		if err != nil {
			t.Fatalf("create: %v", err)
		}
		if g.InviteUrl == nil || *g.InviteUrl == "" {
			t.Fatal("private group should have a non-empty invite url")
		}
	})

	t.Run("description and link stored on create", func(t *testing.T) {
		desc := "my description"
		link := "https://example.com"
		g, err := group.Create(ctx, CreateGroupInput{
			Name:        "withfields",
			Visibility:  0,
			GroupAdmin:  adminID,
			Description: &desc,
			Link:        &link,
		})
		if err != nil {
			t.Fatalf("create: %v", err)
		}
		if g.Description == nil || *g.Description != desc {
			t.Fatalf("description not stored: %v", g.Description)
		}
		if g.Link == nil || *g.Link != link {
			t.Fatalf("link not stored: %v", g.Link)
		}
	})

	t.Run("non-existent admin rejected", func(t *testing.T) {
		fakeID := adminID // valid uuid shape but wrong id — reuse to get a uuid
		// overwrite last byte so it differs from any real user
		fakeID[15] ^= 0xFF
		if _, err := group.Create(ctx, CreateGroupInput{
			Name:       "badadmin",
			Visibility: 0,
			GroupAdmin: fakeID,
		}); err == nil {
			t.Fatal("expected error for non-existent admin")
		}
	})
}

// TestGroupUpdateFields verifies that each updatable field is persisted and that
// visibility transitions correctly manage the invite URL.
func TestGroupUpdateFields(t *testing.T) {
	_, auth, _, _, _, group, _, _, _ := setupServices(t)
	ctx := context.Background()

	adminID := createTestUser(t, auth, "update_admin")
	newAdminID := createTestUser(t, auth, "update_newadmin")

	t.Run("update description", func(t *testing.T) {
		gid := createTestGroup(t, group, adminID, "upd_desc")
		desc := "updated description"
		dto, err := group.Update(ctx, gid, UpdateGroupInput{Description: &desc})
		if err != nil {
			t.Fatalf("update: %v", err)
		}
		if dto.Description == nil || *dto.Description != desc {
			t.Fatalf("description not updated: %v", dto.Description)
		}
	})

	t.Run("update link", func(t *testing.T) {
		gid := createTestGroup(t, group, adminID, "upd_link")
		link := "https://updated.example.com"
		dto, err := group.Update(ctx, gid, UpdateGroupInput{Link: &link})
		if err != nil {
			t.Fatalf("update: %v", err)
		}
		if dto.Link == nil || *dto.Link != link {
			t.Fatalf("link not updated: %v", dto.Link)
		}
	})

	t.Run("transfer admin", func(t *testing.T) {
		gid := createTestGroup(t, group, adminID, "upd_admin")
		dto, err := group.Update(ctx, gid, UpdateGroupInput{GroupAdmin: &newAdminID})
		if err != nil {
			t.Fatalf("update: %v", err)
		}
		if dto.AdminID != newAdminID {
			t.Fatalf("admin not transferred: got %v", dto.AdminID)
		}
	})

	t.Run("visibility 0 to 1 generates invite url", func(t *testing.T) {
		gid := createTestGroup(t, group, adminID, "vis_01")
		vis := 1
		dto, err := group.Update(ctx, gid, UpdateGroupInput{Visibility: &vis})
		if err != nil {
			t.Fatalf("update: %v", err)
		}
		if dto.InviteUrl == nil || *dto.InviteUrl == "" {
			t.Fatal("expected invite url after switching to private")
		}
	})

	t.Run("visibility 1 to 0 clears invite url", func(t *testing.T) {
		// Create private, then flip to public.
		g, err := group.Create(ctx, CreateGroupInput{
			Name:       "vis_10",
			Visibility: 1,
			GroupAdmin: adminID,
		})
		if err != nil {
			t.Fatalf("create private: %v", err)
		}
		if g.InviteUrl == nil || *g.InviteUrl == "" {
			t.Fatal("expected invite url on private group")
		}
		vis := 0
		dto, err := group.Update(ctx, g.ID, UpdateGroupInput{Visibility: &vis})
		if err != nil {
			t.Fatalf("update: %v", err)
		}
		if dto.InviteUrl != nil && *dto.InviteUrl != "" {
			t.Fatalf("invite url should be cleared after switching to public, got %q", *dto.InviteUrl)
		}
	})

	t.Run("update non-existent group fails", func(t *testing.T) {
		name := "ghost"
		if _, err := group.Update(ctx, adminID, UpdateGroupInput{Name: &name}); err == nil {
			t.Fatal("expected not-found for non-existent group")
		}
	})
}

// TestGroupSyncAndDeletion verifies that deleted groups appear in the sync deleted
// list and that pagination works.
func TestGroupSyncAndDeletion(t *testing.T) {
	_, auth, _, _, _, group, _, _, _ := setupServices(t)
	ctx := context.Background()

	adminID := createTestUser(t, auth, "sync_admin")

	t.Run("deleted group appears in sync deleted list", func(t *testing.T) {
		gid := createTestGroup(t, group, adminID, "sync_del")
		before := time.Now()
		if err := group.Delete(ctx, gid); err != nil {
			t.Fatalf("delete: %v", err)
		}
		result, err := group.Search(ctx, nil, nil, nil, false, 0, 100, &before)
		if err != nil {
			t.Fatalf("search: %v", err)
		}
		found := false
		for _, id := range result.Deleted {
			if id == gid {
				found = true
			}
		}
		if !found {
			t.Fatal("deleted group not in sync deleted list")
		}
	})

	t.Run("deleted group not returned in items", func(t *testing.T) {
		gid := createTestGroup(t, group, adminID, "sync_del2")
		if err := group.Delete(ctx, gid); err != nil {
			t.Fatalf("delete: %v", err)
		}
		name := "sync_del2"
		result, err := group.Search(ctx, &name, nil, nil, false, 0, 100, nil)
		if err != nil {
			t.Fatalf("search: %v", err)
		}
		for _, g := range result.Groups {
			if g.ID == gid {
				t.Fatal("deleted group should not appear in items")
			}
		}
	})

	t.Run("search by user returns groups the user belongs to", func(t *testing.T) {
		memberID := createTestUser(t, auth, "sync_member")
		gid := createTestGroup(t, group, memberID, "sync_usergrp")
		withUser := true
		result, err := group.Search(ctx, nil, &memberID, &withUser, false, 0, 100, nil)
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
			t.Fatal("group not returned when searching by member")
		}
	})

	t.Run("search without user excludes user's groups", func(t *testing.T) {
		// withUser=false returns groups the user is NOT a member of
		// (mirrors Kotlin searchInNotUserGroup). The user is the admin —
		// and therefore a member — of this group, so it must be excluded.
		memberID := createTestUser(t, auth, "sync_excl_member")
		gid := createTestGroup(t, group, memberID, "sync_excl")
		withUser := false
		result, err := group.Search(ctx, nil, &memberID, &withUser, false, 0, 100, nil)
		if err != nil {
			t.Fatalf("search: %v", err)
		}
		for _, g := range result.Groups {
			if g.ID == gid {
				t.Fatal("group the user belongs to should not appear with withUser=false")
			}
		}
	})

	t.Run("pagination limits results", func(t *testing.T) {
		for i := range 5 {
			createTestGroup(t, group, adminID, pagGroupName(i))
		}
		result, err := group.Search(ctx, nil, nil, nil, false, 0, 2, nil)
		if err != nil {
			t.Fatalf("search: %v", err)
		}
		if len(result.Groups) > 2 {
			t.Fatalf("page size not respected: got %d", len(result.Groups))
		}
	})
}

// TestGroupImageURLs verifies image URL behaviour at the service level.
func TestGroupImageURLs(t *testing.T) {
	_, auth, _, _, _, group, _, _, _ := setupServices(t)
	ctx := context.Background()

	adminID := createTestUser(t, auth, "imgurl_admin")
	gid := createTestGroup(t, group, adminID, "imgurl_grp")

	t.Run("profile image url nil without object store", func(t *testing.T) {
		u, err := group.ProfileImageURL(ctx, gid, false)
		if err != nil {
			t.Fatalf("profile image url: %v", err)
		}
		if u != nil {
			t.Fatal("expected nil without object store")
		}
	})

	t.Run("profile image small url nil without object store", func(t *testing.T) {
		u, err := group.ProfileImageURL(ctx, gid, true)
		if err != nil {
			t.Fatalf("profile image small url: %v", err)
		}
		if u != nil {
			t.Fatal("expected nil without object store")
		}
	})

	t.Run("pin image url nil without object store", func(t *testing.T) {
		u, err := group.PinImageURL(ctx, gid)
		if err != nil {
			t.Fatalf("pin image url: %v", err)
		}
		if u != nil {
			t.Fatal("expected nil without object store")
		}
	})

	t.Run("missing group image urls return not found", func(t *testing.T) {
		missingID := uuid.New()
		if _, err := group.ProfileImageURL(ctx, missingID, false); !errors.Is(err, apperrors.ErrNotFound) {
			t.Fatalf("profile image error = %v, want not found", err)
		}
		if _, err := group.PinImageURL(ctx, missingID); !errors.Is(err, apperrors.ErrNotFound) {
			t.Fatalf("pin image error = %v, want not found", err)
		}
	})

	t.Run("dto profile and pin image fields nil without object store", func(t *testing.T) {
		dto, err := group.GetDTO(ctx, gid)
		if err != nil {
			t.Fatalf("get dto: %v", err)
		}
		if dto.ProfileImage != nil {
			t.Fatal("dto ProfileImage should be nil without object store")
		}
		if dto.ProfileSmall != nil {
			t.Fatal("dto ProfileSmall should be nil without object store")
		}
		if dto.PinImage != nil {
			t.Fatal("dto PinImage should be nil without object store")
		}
	})
}

func pagGroupName(i int) string {
	names := [5]string{"pag_a", "pag_b", "pag_c", "pag_d", "pag_e"}
	return names[i]
}
