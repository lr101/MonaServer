package service

import (
	"context"
	"encoding/base64"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/lrprojects/monaserver/internal/db"
)

type pinPhotoTestObjectStore struct {
	objects        map[string][]byte
	failRemoveKey  string
	removeErr      error
	cancelOnRemove context.CancelFunc
}

func (s *pinPhotoTestObjectStore) Put(_ context.Context, key string, data []byte, _ string) error {
	s.objects[key] = append([]byte(nil), data...)
	return nil
}

func (s *pinPhotoTestObjectStore) Remove(ctx context.Context, key string) error {
	if err := ctx.Err(); err != nil {
		return err
	}
	if s.cancelOnRemove != nil {
		cancel := s.cancelOnRemove
		s.cancelOnRemove = nil
		cancel()
		return ctx.Err()
	}
	if key == s.failRemoveKey {
		return s.removeErr
	}
	delete(s.objects, key)
	return nil
}

func (s *pinPhotoTestObjectStore) GetIfExists(_ context.Context, key string) ([]byte, bool, error) {
	data, exists := s.objects[key]
	return append([]byte(nil), data...), exists, nil
}

func createPhotoUpdatedTestPin(t *testing.T, ctx context.Context, auth *Auth, pin *Pin, group *Group, store *pinPhotoTestObjectStore, usernamePrefix string) (uuid.UUID, uuid.UUID, uuid.UUID, string) {
	t.Helper()
	userID := createTestUser(t, auth, usernamePrefix+"_user")
	groupID := createTestGroup(t, group, userID, usernamePrefix+"_group")
	pin.obj = store
	group.obj = store
	imageBytes, err := base64.StdEncoding.DecodeString(
		"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=",
	)
	if err != nil {
		t.Fatalf("decode test image: %v", err)
	}
	created, err := pin.Create(ctx, CreatePinInput{
		Latitude: 48.1, Longitude: 11.6, CreationDate: time.Now().UTC(),
		UserID: userID, GroupID: groupID, Image: imageBytes,
	})
	if err != nil {
		t.Fatalf("create pin: %v", err)
	}
	photo, err := pin.AddPhoto(ctx, created.ID, userID, AddPinPhotoInput{
		Image: imageBytes, IdempotencyKey: uuid.New(),
		Latitude: 48.1, Longitude: 11.6, AccuracyMeters: 5,
	})
	if err != nil {
		t.Fatalf("add photo update: %v", err)
	}
	return userID, groupID, created.ID, PinPhotoKey(created.ID, photo.ID)
}

func assertObjectCleanupQueued(t *testing.T, q *db.Queries, key string) {
	t.Helper()
	var queued int
	if err := q.Pool().QueryRow(context.Background(), `SELECT count(*) FROM object_cleanup_queue WHERE object_key = $1`, key).Scan(&queued); err != nil {
		t.Fatalf("read pending object cleanup for %s: %v", key, err)
	}
	if queued != 1 {
		t.Fatalf("pending cleanup rows for %s = %d, want 1", key, queued)
	}
}

func TestDeletingPinKeepsFailedPhotoCleanupQueued(t *testing.T) {
	q, auth, _, _, pin, group, _, _, _ := setupServices(t)
	ctx := context.Background()
	userID := createTestUser(t, auth, "pin_photo_cleanup_retry_user")
	groupID := createTestGroup(t, group, userID, "pin_photo_cleanup_retry_group")
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
	photo, err := pin.AddPhoto(ctx, created.ID, userID, AddPinPhotoInput{
		Image: imageBytes, IdempotencyKey: uuid.New(),
		Latitude: 48.1, Longitude: 11.6, AccuracyMeters: 5,
	})
	if err != nil {
		t.Fatalf("add photo update: %v", err)
	}
	updateKey := PinPhotoKey(created.ID, photo.ID)
	store.failRemoveKey = updateKey
	store.removeErr = errors.New("temporary object store failure")

	if err := pin.Delete(ctx, created.ID); err != nil {
		t.Fatalf("delete pin: %v", err)
	}
	if _, exists := store.objects[updateKey]; !exists {
		t.Fatal("failed photo removal unexpectedly deleted its object")
	}
	var queued int
	if err := q.Pool().QueryRow(ctx, `SELECT count(*) FROM object_cleanup_queue WHERE object_key = $1`, updateKey).Scan(&queued); err != nil {
		t.Fatalf("read pending object cleanup: %v", err)
	}
	if queued != 1 {
		t.Fatalf("pending cleanup rows = %d, want photo object retained for retry", queued)
	}

	store.failRemoveKey = ""
	if err := NewObjectCleanup(q, store).RunOnce(ctx); err != nil {
		t.Fatalf("retry object cleanup: %v", err)
	}
	if _, exists := store.objects[updateKey]; exists {
		t.Fatal("photo update object remains after successful cleanup retry")
	}
	if err := q.Pool().QueryRow(ctx, `SELECT count(*) FROM object_cleanup_queue WHERE object_key = $1`, updateKey).Scan(&queued); err != nil {
		t.Fatalf("read retried object cleanup: %v", err)
	}
	if queued != 0 {
		t.Fatalf("pending cleanup rows after retry = %d, want 0", queued)
	}
}

func TestGroupDeleteKeepsFailedPinPhotoCleanupQueued(t *testing.T) {
	q, auth, _, _, pin, group, _, _, _ := setupServices(t)
	ctx := context.Background()
	store := &pinPhotoTestObjectStore{objects: make(map[string][]byte)}
	_, groupID, _, updateKey := createPhotoUpdatedTestPin(t, ctx, auth, pin, group, store, "group_photo_cleanup")
	store.failRemoveKey = updateKey
	store.removeErr = errors.New("temporary object store failure")

	if err := group.Delete(ctx, groupID); err != nil {
		t.Fatalf("delete group: %v", err)
	}
	assertObjectCleanupQueued(t, q, updateKey)
}

func TestUserDeleteKeepsFailedPinPhotoCleanupQueued(t *testing.T) {
	q, auth, user, _, pin, group, _, _, _ := setupServices(t)
	ctx := context.Background()
	store := &pinPhotoTestObjectStore{objects: make(map[string][]byte)}
	userID, _, _, updateKey := createPhotoUpdatedTestPin(t, ctx, auth, pin, group, store, "user_photo_cleanup")
	user.obj = store
	store.failRemoveKey = updateKey
	store.removeErr = errors.New("temporary object store failure")
	if err := q.SetUserRecoveryCode(ctx, userID, "000042", time.Now().Add(time.Hour)); err != nil {
		t.Fatalf("set deletion code: %v", err)
	}

	if err := user.Delete(ctx, userID, 42); err != nil {
		t.Fatalf("delete user: %v", err)
	}
	assertObjectCleanupQueued(t, q, updateKey)
}

func TestCancelledPinDeleteCleanupLeavesKeysForBackgroundRetry(t *testing.T) {
	q, auth, _, _, pin, group, _, _, _ := setupServices(t)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	store := &pinPhotoTestObjectStore{objects: make(map[string][]byte)}
	_, _, pinID, updateKey := createPhotoUpdatedTestPin(t, ctx, auth, pin, group, store, "cancel_photo_cleanup")
	store.cancelOnRemove = cancel

	if err := pin.Delete(ctx, pinID); err != nil {
		t.Fatalf("delete pin: %v", err)
	}
	assertObjectCleanupQueued(t, q, updateKey)
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

func TestNewObjectCleanupTreatsTypedNilObjectStoreAsUnavailable(t *testing.T) {
	var object *Object
	cleanup := NewObjectCleanup(nil, object)
	if cleanup.obj != nil {
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
