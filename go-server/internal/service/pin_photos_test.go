package service

import (
	"context"
	"encoding/base64"
	"errors"
	"fmt"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/lrprojects/monaserver/internal/db"
)

type pinPhotoTestObjectStore struct {
	mu               sync.Mutex
	objects          map[string][]byte
	lastPutKey       string
	failRemoveAll    bool
	failRemoveKey    string
	failRemovePrefix string
	removeErr        error
	cancelOnPut      context.CancelFunc
	cancelOnRemove   context.CancelFunc
}

func (s *pinPhotoTestObjectStore) Put(_ context.Context, key string, data []byte, _ string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.lastPutKey = key
	s.objects[key] = append([]byte(nil), data...)
	if s.cancelOnPut != nil {
		cancel := s.cancelOnPut
		s.cancelOnPut = nil
		cancel()
	}
	return nil
}

func (s *pinPhotoTestObjectStore) Remove(ctx context.Context, key string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if err := ctx.Err(); err != nil {
		return err
	}
	if s.cancelOnRemove != nil {
		cancel := s.cancelOnRemove
		s.cancelOnRemove = nil
		cancel()
		return ctx.Err()
	}
	if s.failRemoveAll {
		return s.removeErr
	}
	if key == s.failRemoveKey {
		return s.removeErr
	}
	if s.failRemovePrefix != "" && strings.HasPrefix(key, s.failRemovePrefix) {
		return s.removeErr
	}
	delete(s.objects, key)
	return nil
}

func (s *pinPhotoTestObjectStore) GetIfExists(_ context.Context, key string) ([]byte, bool, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
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

func makeObjectCleanupEligible(t *testing.T, q *db.Queries, key string) {
	t.Helper()
	if _, err := q.Pool().Exec(context.Background(), `UPDATE object_cleanup_queue SET next_attempt_at = NOW() WHERE object_key = $1`, key); err != nil {
		t.Fatalf("make object cleanup eligible for %s: %v", key, err)
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
	makeObjectCleanupEligible(t, q, updateKey)
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

func TestObjectCleanupFailureDoesNotStarveLaterKeys(t *testing.T) {
	q, _, _, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	const failedKey = "a-permanently-failing-photo"
	const laterKey = "z-photo-that-can-be-removed"
	store := &pinPhotoTestObjectStore{
		objects:       map[string][]byte{failedKey: []byte("failed"), laterKey: []byte("later")},
		failRemoveKey: failedKey,
		removeErr:     errors.New("permanent object storage failure"),
	}
	if err := q.EnqueueObjectCleanup(ctx, []string{failedKey, laterKey}); err != nil {
		t.Fatalf("enqueue cleanup keys: %v", err)
	}
	err := NewObjectCleanup(q, store).RunOnce(ctx)
	if err == nil {
		t.Fatal("cleanup succeeded despite the permanent storage failure")
	}
	if store.objectCount() != 1 {
		t.Fatalf("objects after partial cleanup = %d, want only the failed key", store.objectCount())
	}
	assertObjectCleanupQueued(t, q, failedKey)
	var laterQueued int
	if err := q.Pool().QueryRow(ctx, `SELECT count(*) FROM object_cleanup_queue WHERE object_key = $1`, laterKey).Scan(&laterQueued); err != nil {
		t.Fatalf("read later cleanup row: %v", err)
	}
	if laterQueued != 0 {
		t.Fatalf("later cleanup row count = %d, want 0 after the successful removal", laterQueued)
	}

	store.failRemoveKey = ""
	makeObjectCleanupEligible(t, q, failedKey)
	if err := NewObjectCleanup(q, store).RunOnce(ctx); err != nil {
		t.Fatalf("retry failed cleanup: %v", err)
	}
	if store.objectCount() != 0 {
		t.Fatalf("objects after retry = %d, want none", store.objectCount())
	}
}

func TestObjectCleanupRetriesBeyondPersistentFailuresAcrossBatches(t *testing.T) {
	q, _, _, _, _, _, _, _, _ := setupServices(t)
	ctx := context.Background()
	const healthyKey = "z-photo-that-can-be-removed-after-a-large-failure-batch"
	failedKeys := make([]string, objectCleanupBatchLimit+1)
	objects := make(map[string][]byte, len(failedKeys)+1)
	for i := range failedKeys {
		failedKeys[i] = fmt.Sprintf("a-persistently-failing-photo-%03d", i)
		objects[failedKeys[i]] = []byte("failed")
	}
	objects[healthyKey] = []byte("healthy")
	queuedKeys := append(append([]string(nil), failedKeys...), healthyKey)
	store := &pinPhotoTestObjectStore{
		objects:          objects,
		failRemovePrefix: "a-persistently-failing-photo-",
		removeErr:        errors.New("persistent object storage failure"),
	}
	if err := q.EnqueueObjectCleanup(ctx, queuedKeys); err != nil {
		t.Fatalf("enqueue cleanup keys: %v", err)
	}
	cleanup := NewObjectCleanup(q, store)

	for run := 0; run < 2; run++ {
		if err := cleanup.RunOnce(ctx); err == nil {
			t.Fatalf("cleanup run %d succeeded despite persistent removal failures", run+1)
		}
	}

	if _, exists := store.objects[healthyKey]; exists {
		t.Fatal("healthy photo was starved by persistent failures across cleanup batches")
	}
	assertObjectCleanupQueued(t, q, failedKeys[0])
	var failedCount int
	if err := q.Pool().QueryRow(ctx, `SELECT count(*) FROM object_cleanup_queue WHERE object_key = ANY($1::text[])`, failedKeys).Scan(&failedCount); err != nil {
		t.Fatalf("count remaining failed cleanup rows: %v", err)
	}
	if failedCount != len(failedKeys) {
		t.Fatalf("remaining failed cleanup rows = %d, want %d", failedCount, len(failedKeys))
	}
	var delayedFailedCount int
	if err := q.Pool().QueryRow(ctx, `SELECT count(*) FROM object_cleanup_queue WHERE object_key = ANY($1::text[]) AND next_attempt_at > NOW()`, failedKeys).Scan(&delayedFailedCount); err != nil {
		t.Fatalf("count delayed failed cleanup rows: %v", err)
	}
	if delayedFailedCount != len(failedKeys) {
		t.Fatalf("delayed failed cleanup rows = %d, want %d", delayedFailedCount, len(failedKeys))
	}
	var healthyCount int
	if err := q.Pool().QueryRow(ctx, `SELECT count(*) FROM object_cleanup_queue WHERE object_key = $1`, healthyKey).Scan(&healthyCount); err != nil {
		t.Fatalf("read healthy cleanup row: %v", err)
	}
	if healthyCount != 0 {
		t.Fatalf("healthy cleanup rows = %d, want 0 after cleanup", healthyCount)
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

func TestCancelledPinPhotoCreateKeepsUploadedObjectQueuedForRetry(t *testing.T) {
	q, auth, _, _, pin, group, _, _, _ := setupServices(t)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	userID := createTestUser(t, auth, "cancel_photo_create_user")
	groupID := createTestGroup(t, group, userID, "cancel_photo_create_group")
	created, err := pin.Create(context.Background(), CreatePinInput{
		Latitude: 48.1, Longitude: 11.6, CreationDate: time.Now().UTC(),
		UserID: userID, GroupID: groupID,
	})
	if err != nil {
		t.Fatalf("create pin: %v", err)
	}
	imageBytes, err := base64.StdEncoding.DecodeString(
		"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=",
	)
	if err != nil {
		t.Fatalf("decode test image: %v", err)
	}
	store := &pinPhotoTestObjectStore{
		objects: make(map[string][]byte), cancelOnPut: cancel,
		failRemoveAll: true, removeErr: errors.New("temporary object store failure"),
	}
	pin.obj = store

	_, err = pin.AddPhoto(ctx, created.ID, userID, AddPinPhotoInput{
		Image: imageBytes, IdempotencyKey: uuid.New(),
		Latitude: 48.1, Longitude: 11.6, AccuracyMeters: 5,
	})
	if err == nil {
		t.Fatal("add photo update succeeded after its upload cancelled the request")
	}
	if len(store.objects) != 1 {
		t.Fatalf("stored objects after cancelled photo create = %d, want uploaded object retained for retry", len(store.objects))
	}
	key := store.lastPutKey
	if key == "" {
		t.Fatal("photo upload did not reach object storage")
	}
	assertObjectCleanupQueued(t, q, key)

	store.failRemoveAll = false
	makeObjectCleanupEligible(t, q, key)
	if err := NewObjectCleanup(q, store).RunOnce(context.Background()); err != nil {
		t.Fatalf("retry object cleanup: %v", err)
	}
	if _, exists := store.objects[key]; exists {
		t.Fatal("uploaded photo object remains after successful cleanup retry")
	}
}

func TestCancelledOriginalPinPhotoCreateKeepsUploadedObjectQueuedForRetry(t *testing.T) {
	q, auth, _, _, pin, group, _, _, _ := setupServices(t)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	userID := createTestUser(t, auth, "cancel_original_photo_user")
	groupID := createTestGroup(t, group, userID, "cancel_original_photo_group")
	imageBytes, err := base64.StdEncoding.DecodeString(
		"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=",
	)
	if err != nil {
		t.Fatalf("decode test image: %v", err)
	}
	store := &pinPhotoTestObjectStore{
		objects: make(map[string][]byte), cancelOnPut: cancel,
		failRemoveAll: true, removeErr: errors.New("temporary object store failure"),
	}
	pin.obj = store

	_, err = pin.Create(ctx, CreatePinInput{
		Latitude: 48.1, Longitude: 11.6, CreationDate: time.Now().UTC(),
		UserID: userID, GroupID: groupID, Image: imageBytes,
	})
	if err == nil {
		t.Fatal("pin creation succeeded after its original photo upload cancelled the request")
	}
	key := store.lastPutKey
	if key == "" || store.objectCount() != 1 {
		t.Fatalf("original photo upload key %q, stored object count %d; want one uploaded object", key, store.objectCount())
	}
	assertObjectCleanupQueued(t, q, key)

	store.failRemoveAll = false
	makeObjectCleanupEligible(t, q, key)
	if err := NewObjectCleanup(q, store).RunOnce(context.Background()); err != nil {
		t.Fatalf("retry original photo object cleanup: %v", err)
	}
	if store.objectCount() != 0 {
		t.Fatal("original photo object remains after successful cleanup retry")
	}
}

func (s *pinPhotoTestObjectStore) PresignedGet(_ context.Context, key string) (string, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if _, ok := s.objects[key]; !ok {
		return "", nil
	}
	return "https://objects.test/" + key, nil
}

func (s *pinPhotoTestObjectStore) objectCount() int {
	s.mu.Lock()
	defer s.mu.Unlock()
	return len(s.objects)
}

func TestConcurrentPinPhotoUploadAndDeleteDoesNotOrphanPhoto(t *testing.T) {
	for _, deletion := range []string{"pin", "group", "user"} {
		t.Run(deletion, func(t *testing.T) {
			q, auth, user, _, pin, group, _, _, _ := setupServices(t)
			ctx := context.Background()
			userID := createTestUser(t, auth, "photo_delete_race_"+deletion)
			groupID := createTestGroup(t, group, userID, "photo_delete_race_group_"+deletion)
			created, err := pin.Create(ctx, CreatePinInput{
				Latitude: 48.1, Longitude: 11.6, CreationDate: time.Now().UTC(),
				UserID: userID, GroupID: groupID,
			})
			if err != nil {
				t.Fatalf("create pin: %v", err)
			}
			store := &pinPhotoTestObjectStore{objects: make(map[string][]byte)}
			pin.obj = store
			group.obj = store
			user.obj = store
			imageBytes, err := base64.StdEncoding.DecodeString(
				"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=",
			)
			if err != nil {
				t.Fatalf("decode test image: %v", err)
			}
			pausePhotoInsertForPin(t, q, created.ID)
			photoDone := make(chan error, 1)
			go func() {
				_, err := pin.AddPhoto(ctx, created.ID, userID, AddPinPhotoInput{
					Image: imageBytes, IdempotencyKey: uuid.New(),
					Latitude: 48.1, Longitude: 11.6, AccuracyMeters: 5,
				})
				photoDone <- err
			}()
			waitForPausedPhotoInsert(t, q)

			deleteDone := make(chan error, 1)
			go func() {
				var err error
				switch deletion {
				case "pin":
					err = pin.Delete(ctx, created.ID)
				case "group":
					err = group.Delete(ctx, groupID)
				case "user":
					if err = q.SetUserRecoveryCode(ctx, userID, "000042", time.Now().Add(time.Hour)); err == nil {
						err = user.Delete(ctx, userID, 42)
					}
				}
				deleteDone <- err
			}()

			select {
			case err := <-photoDone:
				if err != nil && deletion != "user" {
					t.Fatalf("photo upload failed while deletion waited on pin: %v", err)
				}
			case <-time.After(10 * time.Second):
				t.Fatal("photo upload did not finish")
			}
			select {
			case err := <-deleteDone:
				if err != nil {
					t.Fatalf("delete %s: %v", deletion, err)
				}
			case <-time.After(10 * time.Second):
				t.Fatalf("%s deletion did not finish", deletion)
			}
			if count := store.objectCount(); count != 0 {
				t.Fatalf("objects after concurrent %s deletion = %d, want none", deletion, count)
			}
		})
	}
}

func pausePhotoInsertForPin(t *testing.T, q *db.Queries, pinID uuid.UUID) {
	t.Helper()
	ctx := context.Background()
	function := fmt.Sprintf(`
CREATE OR REPLACE FUNCTION test_pause_pin_photo_insert() RETURNS trigger AS $$
BEGIN
  IF NEW.pin_id = '%s'::uuid THEN
    PERFORM pg_sleep(1.5);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;`, pinID)
	if _, err := q.Pool().Exec(ctx, `DROP TRIGGER IF EXISTS test_pause_pin_photo_insert ON pin_photos`); err != nil {
		t.Fatalf("drop old test trigger: %v", err)
	}
	if _, err := q.Pool().Exec(ctx, function); err != nil {
		t.Fatalf("create test trigger function: %v", err)
	}
	if _, err := q.Pool().Exec(ctx, `CREATE TRIGGER test_pause_pin_photo_insert BEFORE INSERT ON pin_photos FOR EACH ROW EXECUTE FUNCTION test_pause_pin_photo_insert()`); err != nil {
		t.Fatalf("create test trigger: %v", err)
	}
	t.Cleanup(func() {
		_, _ = q.Pool().Exec(context.Background(), `DROP TRIGGER IF EXISTS test_pause_pin_photo_insert ON pin_photos`)
		_, _ = q.Pool().Exec(context.Background(), `DROP FUNCTION IF EXISTS test_pause_pin_photo_insert()`)
	})
}

func waitForPausedPhotoInsert(t *testing.T, q *db.Queries) {
	t.Helper()
	deadline := time.Now().Add(5 * time.Second)
	for time.Now().Before(deadline) {
		var paused bool
		err := q.Pool().QueryRow(context.Background(), `
SELECT EXISTS (
  SELECT 1 FROM pg_stat_activity
  WHERE pid <> pg_backend_pid()
    AND datname = current_database()
    AND usename = current_user
    AND state = 'active'
    AND query ILIKE '%INSERT INTO pin_photos%'
    AND wait_event = 'PgSleep'
)`).Scan(&paused)
		if err != nil {
			t.Fatalf("wait for paused photo insert: %v", err)
		}
		if paused {
			return
		}
		time.Sleep(10 * time.Millisecond)
	}
	t.Fatal("photo insert did not reach the concurrency gate")
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
