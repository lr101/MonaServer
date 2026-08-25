package service

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/lrprojects/monaserver/internal/config"
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

func TestUserUpdateRollsBackEarlierFieldsWhenLaterValidationFails(t *testing.T) {
	_, auth, user, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	userID := createTestUser(t, auth, "atomic_update_user")
	createTestUser(t, auth, "atomic_update_conflict")
	description := "must roll back"
	conflictingUsername := "atomic_update_conflict"
	if _, err := user.Update(ctx, userID, UserUpdateInput{Description: &description, Username: &conflictingUsername}); err == nil {
		t.Fatal("update should fail on duplicate username")
	}
	stored, err := user.Get(ctx, userID)
	if err != nil {
		t.Fatalf("get user: %v", err)
	}
	if stored.Description != nil {
		t.Fatalf("failed update persisted description %q", *stored.Description)
	}
}

func TestUserUpdateRejectsUnknownSelectedAchievement(t *testing.T) {
	_, auth, user, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	userID := createTestUser(t, auth, "unknown_selected_achievement")
	achievementID := int32(999)
	if _, err := user.Update(ctx, userID, UserUpdateInput{SelectedBatch: &achievementID}); err == nil {
		t.Fatal("selecting an unknown achievement should fail")
	}
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
		if _, err := auth.Signup(ctx, "todelete", "password123", nil); err != nil {
			t.Fatalf("reuse deleted username: %v", err)
		}
	})
}

func TestClaimAchievementCreatesRowAwardsXpOnceAndRejectsDuplicate(t *testing.T) {
	q, auth, user, _, _, group, _, _, _ := setupServices(t)
	ctx := context.Background()
	uid := createTestUser(t, auth, "achievement_claimant")
	createTestGroup(t, group, uid, "achievement_group")

	before, err := user.Get(ctx, uid)
	if err != nil {
		t.Fatalf("get user before claim: %v", err)
	}
	if err := user.ClaimAchievement(ctx, uid, 4); err != nil {
		t.Fatalf("first claim: %v", err)
	}

	var claimed bool
	if err := q.Pool().QueryRow(ctx,
		`SELECT claimed FROM user_achievement WHERE user_id = $1 AND achievement_id = 4`, uid,
	).Scan(&claimed); err != nil {
		t.Fatalf("read claimed achievement: %v", err)
	}
	if !claimed {
		t.Fatal("new achievement row was not marked claimed")
	}
	afterFirst, err := user.Get(ctx, uid)
	if err != nil {
		t.Fatalf("get user after first claim: %v", err)
	}
	if got := afterFirst.XP - before.XP; got != 20 {
		t.Fatalf("first claim XP delta = %d, want 20", got)
	}

	if err := user.ClaimAchievement(ctx, uid, 4); err == nil {
		t.Fatal("duplicate claim should return a conflict")
	}
	afterSecond, err := user.Get(ctx, uid)
	if err != nil {
		t.Fatalf("get user after duplicate claim: %v", err)
	}
	if afterSecond.XP != afterFirst.XP {
		t.Fatalf("duplicate claim changed XP from %d to %d", afterFirst.XP, afterSecond.XP)
	}
}

func TestDeletionLogUsesCompatibleEntityOrdinals(t *testing.T) {
	q, auth, user, _, pin, group, _, _, _ := setupServices(t)
	ctx := context.Background()
	uid := createTestUser(t, auth, "delete_log_user")
	gid := createTestGroup(t, group, uid, "delete_log_group")
	pid := createTestPin(t, pin, uid, gid)

	if err := pin.Delete(ctx, pid); err != nil {
		t.Fatalf("delete pin: %v", err)
	}
	if err := group.Delete(ctx, gid); err != nil {
		t.Fatalf("delete group: %v", err)
	}
	exp := time.Now().Add(time.Hour)
	if err := q.SetUserRecoveryCode(ctx, uid, "000042", exp); err != nil {
		t.Fatalf("set deletion code: %v", err)
	}
	if err := user.Delete(ctx, uid, 42); err != nil {
		t.Fatalf("delete user: %v", err)
	}

	wants := map[uuid.UUID]int16{gid: 0, pid: 1, uid: 2}
	for id, want := range wants {
		var got int16
		if err := q.Pool().QueryRow(ctx,
			`SELECT deleted_entity_type FROM delete_log WHERE deleted_entity_id = $1`, id,
		).Scan(&got); err != nil {
			t.Fatalf("read deletion log for %s: %v", id, err)
		}
		if got != want {
			t.Fatalf("deletion log type for %s = %d, want %d", id, got, want)
		}
	}
}

func TestEmailUpdateRollsBackWhenConfirmationMailFails(t *testing.T) {
	q, auth, _, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	oldEmail := "old-email@example.com"
	pair, err := auth.Signup(ctx, "email_rollback_user", "password123", &oldEmail)
	if err != nil {
		t.Fatalf("signup: %v", err)
	}
	if err := q.ConfirmUserEmail(ctx, pair.UserID); err != nil {
		t.Fatalf("confirm initial email: %v", err)
	}
	failingMail := NewEmail(&config.Config{
		MailHost: "127.0.0.1", MailPort: 1, MailUsername: "sender@example.com",
		MailPassword: "password", MailFrom: "sender@example.com", AppURL: "https://api.example.com",
	}, nil)
	userSvc := NewUser(q, nil, nil, auth, failingMail)
	newEmail := "new-email@example.com"
	if _, err := userSvc.Update(ctx, pair.UserID, UserUpdateInput{Email: &newEmail}); err == nil {
		t.Fatal("email update should fail when the confirmation email cannot be sent")
	}
	stored, err := q.GetUserByID(ctx, pair.UserID)
	if err != nil {
		t.Fatalf("get user after failed update: %v", err)
	}
	if stored.Email == nil || *stored.Email != oldEmail || !stored.EmailConfirmed {
		t.Fatalf("failed email update was not rolled back: email=%v confirmed=%v", stored.Email, stored.EmailConfirmed)
	}
}
