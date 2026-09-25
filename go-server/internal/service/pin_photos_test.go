package service

import (
	"context"
	"encoding/base64"
	"testing"
	"time"

	"github.com/google/uuid"
)

type pinPhotoTestObjectStore struct {
	objects map[string][]byte
}

func (s *pinPhotoTestObjectStore) Put(_ context.Context, key string, data []byte, _ string) error {
	s.objects[key] = append([]byte(nil), data...)
	return nil
}

func (s *pinPhotoTestObjectStore) Remove(_ context.Context, key string) error {
	delete(s.objects, key)
	return nil
}

func (s *pinPhotoTestObjectStore) PresignedGet(_ context.Context, key string) (string, error) {
	if _, ok := s.objects[key]; !ok {
		return "", nil
	}
	return "https://objects.test/" + key, nil
}

func TestNewPinTreatsTypedNilObjectStoreAsUnavailable(t *testing.T) {
	var object *Object
	pin := NewPin(nil, object)
	if pin.obj != nil {
		t.Fatal("typed nil object store should be treated as unavailable")
	}
}

func TestCreatePinRecordsOriginalPhotoInHistory(t *testing.T) {
	q, auth, _, _, pin, group, _, _, _ := setupServices(t)
	ctx := context.Background()
	userID := createTestUser(t, auth, "pin_photo_original_user")
	groupID := createTestGroup(t, group, userID, "pin_photo_original_group")
	originalImage, err := base64.StdEncoding.DecodeString(
		"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=",
	)
	if err != nil {
		t.Fatalf("decode original test image: %v", err)
	}

	created, err := pin.Create(ctx, CreatePinInput{
		Latitude:     48.1,
		Longitude:    11.6,
		CreationDate: time.Now().UTC(),
		UserID:       userID,
		GroupID:      groupID,
		Image:        originalImage,
	})
	if err != nil {
		t.Fatalf("create pin: %v", err)
	}

	var originalCount int
	if err := q.Pool().QueryRow(ctx, `
		SELECT count(*) FROM pin_photos
		WHERE pin_id = $1 AND is_original = TRUE`, created.ID,
	).Scan(&originalCount); err != nil {
		t.Fatalf("count original photo history: %v", err)
	}
	if originalCount != 1 {
		t.Fatalf("original photo history count = %d, want 1", originalCount)
	}
}

func TestDeletingPinRemovesItsPhotoUpdateObjects(t *testing.T) {
	_, auth, _, _, pin, group, _, _, _ := setupServices(t)
	ctx := context.Background()
	userID := createTestUser(t, auth, "pin_photo_cleanup_user")
	groupID := createTestGroup(t, group, userID, "pin_photo_cleanup_group")
	imageBytes, err := base64.StdEncoding.DecodeString(
		"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=",
	)
	if err != nil {
		t.Fatalf("decode test image: %v", err)
	}
	store := &pinPhotoTestObjectStore{objects: make(map[string][]byte)}
	pin.obj = store
	created, err := pin.Create(ctx, CreatePinInput{
		Latitude: 48.1, Longitude: 11.6, CreationDate: time.Now().UTC(),
		UserID: userID, GroupID: groupID, Image: imageBytes,
	})
	if err != nil {
		t.Fatalf("create pin: %v", err)
	}
	if _, err := pin.AddPhoto(ctx, created.ID, userID, AddPinPhotoInput{
		Image: imageBytes, IdempotencyKey: uuid.New(),
		Latitude: 48.1, Longitude: 11.6, AccuracyMeters: 5,
	}); err != nil {
		t.Fatalf("add photo update: %v", err)
	}
	if len(store.objects) != 2 {
		t.Fatalf("stored pin photo objects = %d, want original plus update", len(store.objects))
	}
	if err := pin.Delete(ctx, created.ID); err != nil {
		t.Fatalf("delete pin: %v", err)
	}
	if len(store.objects) != 0 {
		t.Fatalf("stored objects after deleting pin = %v, want none", store.objects)
	}
}
