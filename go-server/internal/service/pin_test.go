package service

import (
	"context"
	"testing"
	"time"
)

func TestPinCreateGetDelete(t *testing.T) {
	_, auth, _, _, pin, group, _, _, _ := setupServices(t)
	ctx := context.Background()

	uid := createTestUser(t, auth, "pinner")
	gid := createTestGroup(t, group, uid, "pingroup")

	t.Run("create pin", func(t *testing.T) {
		dto, err := pin.Create(ctx, CreatePinInput{
			Latitude:     52.5,
			Longitude:    13.4,
			CreationDate: time.Now(),
			UserID:       uid,
			GroupID:      gid,
		})
		if err != nil {
			t.Fatalf("create: %v", err)
		}
		if dto.ID.String() == "" {
			t.Fatal("empty pin id")
		}
		if dto.UserID != uid {
			t.Fatalf("creator mismatch")
		}
	})

	t.Run("duplicate pin at same location+time rejected", func(t *testing.T) {
		now := time.Now()
		in := CreatePinInput{
			Latitude:     48.1,
			Longitude:    16.3,
			CreationDate: now,
			UserID:       uid,
			GroupID:      gid,
		}
		if _, err := pin.Create(ctx, in); err != nil {
			t.Fatalf("first create: %v", err)
		}
		if _, err := pin.Create(ctx, in); err == nil {
			t.Fatal("expected conflict on duplicate pin")
		}
	})

	t.Run("get pin", func(t *testing.T) {
		pid := createTestPin(t, pin, uid, gid)
		dto, err := pin.Get(ctx, pid)
		if err != nil {
			t.Fatalf("get: %v", err)
		}
		if dto.ID != pid {
			t.Fatalf("id mismatch")
		}
	})

	t.Run("delete pin", func(t *testing.T) {
		pid := createTestPin(t, pin, uid, gid)
		if err := pin.Delete(ctx, pid); err != nil {
			t.Fatalf("delete: %v", err)
		}
		if _, err := pin.Get(ctx, pid); err == nil {
			t.Fatal("expected not-found after delete")
		}
	})

	t.Run("delete non-existent pin fails", func(t *testing.T) {
		if err := pin.Delete(ctx, uid); err == nil { // reuse uid as bogus pin id
			t.Fatal("expected error for non-existent pin")
		}
	})

	t.Run("image url nil without object store", func(t *testing.T) {
		pid := createTestPin(t, pin, uid, gid)
		u, err := pin.ImageURL(ctx, pid)
		if err != nil {
			t.Fatalf("image url: %v", err)
		}
		if u != nil {
			t.Fatal("expected nil url without object store")
		}
	})
}
