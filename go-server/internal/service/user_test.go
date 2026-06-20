package service

import (
	"context"
	"testing"
	"time"
)

func TestUserGetAndUpdate(t *testing.T) {
	q, auth, user, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	uid := createTestUser(t, auth, "bob")

	t.Run("get existing user", func(t *testing.T) {
		u, err := user.Get(ctx, uid)
		if err != nil {
			t.Fatalf("get: %v", err)
		}
		if u.Username != "bob" {
			t.Fatalf("username: got %q", u.Username)
		}
	})

	t.Run("update description", func(t *testing.T) {
		desc := "hello world"
		res, err := user.Update(ctx, uid, UserUpdateInput{Description: &desc})
		if err != nil {
			t.Fatalf("update: %v", err)
		}
		if res.UserInfoDto.Description == nil || *res.UserInfoDto.Description != desc {
			t.Fatalf("description not persisted")
		}
	})

	t.Run("update username", func(t *testing.T) {
		name := "bob2"
		res, err := user.Update(ctx, uid, UserUpdateInput{Username: &name})
		if err != nil {
			t.Fatalf("update username: %v", err)
		}
		if res.UserInfoDto.Username != name {
			t.Fatalf("username mismatch: got %q", res.UserInfoDto.Username)
		}
	})

	t.Run("duplicate username rejected", func(t *testing.T) {
		createTestUser(t, auth, "carol")
		name := "carol"
		if _, err := user.Update(ctx, uid, UserUpdateInput{Username: &name}); err == nil {
			t.Fatal("expected conflict on duplicate username")
		}
	})

	t.Run("profile image url nil without object store", func(t *testing.T) {
		u, err := user.ProfileImageURL(ctx, uid, false)
		if err != nil {
			t.Fatalf("profile image url: %v", err)
		}
		if u != nil {
			t.Fatal("expected nil with no object store")
		}
	})

	t.Run("add xp", func(t *testing.T) {
		before, _ := user.Get(ctx, uid)
		if err := q.AddUserXp(ctx, uid, 15); err != nil {
			t.Fatalf("add xp: %v", err)
		}
		after, _ := user.Get(ctx, uid)
		if after.XP-before.XP != 15 {
			t.Fatalf("xp not incremented: delta=%d", after.XP-before.XP)
		}
	})

	t.Run("achievements no claimed initially", func(t *testing.T) {
		rows, err := user.Achievements(ctx, uid)
		if err != nil {
			t.Fatalf("achievements: %v", err)
		}
		for _, r := range rows {
			if r.Claimed {
				t.Fatalf("unexpected claimed achievement %d", r.AchievementID)
			}
		}
	})
}

func TestUserDelete(t *testing.T) {
	q, auth, user, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	uid := createTestUser(t, auth, "todelete")

	t.Run("delete with no code fails", func(t *testing.T) {
		if err := user.Delete(ctx, uid, 42); err == nil {
			t.Fatal("expected error without a code set")
		}
	})

	t.Run("delete with correct code succeeds", func(t *testing.T) {
		exp := time.Now().Add(time.Hour)
		if err := q.SetUserRecoveryCode(ctx, uid, "000042", exp); err != nil {
			t.Fatalf("set code: %v", err)
		}
		if err := user.Delete(ctx, uid, 42); err != nil {
			t.Fatalf("delete: %v", err)
		}
		// After deletion, user.Get should return not-found.
		if _, err := user.Get(ctx, uid); err == nil {
			t.Fatal("expected not-found after deletion")
		}
	})
}
