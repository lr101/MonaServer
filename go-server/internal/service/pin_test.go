package service

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
)

func TestPinUsesNearestBoundaryWhenPointIsOutsideAllPolygons(t *testing.T) {
	q, auth, _, _, pin, group, _, _, _ := setupServices(t)
	ctx := context.Background()
	if _, err := q.Pool().Exec(ctx, `DELETE FROM admin2_boundaries WHERE gid_0 = 'NEAR'`); err != nil {
		t.Fatalf("clear prior test boundaries: %v", err)
	}
	boundaryID := uuid.New()
	if _, err := q.Pool().Exec(ctx, `
		INSERT INTO admin2_boundaries (id, gid_0, name_0, gid_1, name_1, gid_2, name_2, geom)
		VALUES ($1, 'NEAR', 'Nearest', 'NEAR.1', 'Nearest One', 'NEAR.1.1', 'Nearest Two',
		        ST_GeomFromText('MULTIPOLYGON(((10 10, 10 11, 11 11, 11 10, 10 10)))', 4326))`, boundaryID,
	); err != nil {
		t.Fatalf("insert boundary: %v", err)
	}
	t.Cleanup(func() {
		_, _ = q.Pool().Exec(context.Background(), `DELETE FROM pins WHERE state_province_id = $1`, boundaryID)
		_, _ = q.Pool().Exec(context.Background(), `DELETE FROM admin2_boundaries WHERE id = $1`, boundaryID)
	})
	uid := createTestUser(t, auth, "nearest_boundary_user")
	gid := createTestGroup(t, group, uid, "nearest_boundary_group")

	created, err := pin.Create(ctx, CreatePinInput{
		Latitude: 10.5, Longitude: 11.1, CreationDate: time.Now(), UserID: uid, GroupID: gid,
	})
	if err != nil {
		t.Fatalf("create pin: %v", err)
	}
	stored, err := q.GetPinByID(ctx, created.ID)
	if err != nil {
		t.Fatalf("get stored pin: %v", err)
	}
	if stored.StateProvinceID == nil || *stored.StateProvinceID != boundaryID {
		t.Fatalf("boundary = %v, want nearest boundary %s", stored.StateProvinceID, boundaryID)
	}
}

func TestPinCreateGetDelete(t *testing.T) {
	q, auth, _, _, pin, group, _, _, _ := setupServices(t)
	ctx := context.Background()

	uid := createTestUser(t, auth, "pinner")
	gid := createTestGroup(t, group, uid, "pingroup")

	t.Run("create pin", func(t *testing.T) {
		before, err := q.GetUserByID(ctx, uid)
		if err != nil {
			t.Fatalf("get user before pin: %v", err)
		}
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
		after, err := q.GetUserByID(ctx, uid)
		if err != nil {
			t.Fatalf("get user after pin: %v", err)
		}
		if after.XP-before.XP != 5 {
			t.Fatalf("pin XP delta = %d, want 5", after.XP-before.XP)
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
