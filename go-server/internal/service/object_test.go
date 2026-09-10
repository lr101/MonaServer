package service

import (
	"bytes"
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"strconv"
	"strings"
	"sync"
	"testing"
	"time"
)

func TestObjectCRUD(t *testing.T) {
	store := &fakeObjectStore{objects: make(map[string][]byte)}
	server := httptest.NewServer(store)
	defer server.Close()

	obj, err := NewObject(server.URL, server.URL, "testkey", "testsecret", "testbucket", false, time.Hour)
	if err != nil {
		t.Fatalf("NewObject: %v", err)
	}

	ctx := context.Background()
	if err := obj.EnsureBucket(ctx); err != nil {
		t.Fatalf("EnsureBucket: %v", err)
	}
	if !store.bucketExists() {
		t.Fatal("EnsureBucket did not create the missing bucket")
	}

	want := []byte("object contents")
	if err := obj.Put(ctx, "pins/test-id.png", want, "image/png"); err != nil {
		t.Fatalf("Put: %v", err)
	}

	got, exists, err := obj.GetIfExists(ctx, "pins/test-id.png")
	if err != nil {
		t.Fatalf("GetIfExists: %v", err)
	}
	if !exists {
		t.Fatal("GetIfExists reported that the stored object was missing")
	}
	if string(got) != string(want) {
		t.Fatalf("GetIfExists returned %q, want %q", got, want)
	}

	if err := obj.Remove(ctx, "pins/test-id.png"); err != nil {
		t.Fatalf("Remove: %v", err)
	}
	if _, exists, err := obj.GetIfExists(ctx, "pins/test-id.png"); err != nil {
		t.Fatalf("GetIfExists after Remove: %v", err)
	} else if exists {
		t.Fatal("GetIfExists reported an object after Remove")
	}
}

func TestObjectAgainstRustFS(t *testing.T) {
	endpoint := os.Getenv("RUSTFS_TEST_ENDPOINT")
	if endpoint == "" {
		t.Skip("RUSTFS_TEST_ENDPOINT not set; skipping RustFS integration test")
	}
	useSSL := false
	var err error
	if raw := os.Getenv("RUSTFS_TEST_USE_SSL"); raw != "" {
		useSSL, err = strconv.ParseBool(raw)
		if err != nil {
			t.Fatalf("parse RUSTFS_TEST_USE_SSL: %v", err)
		}
	}
	externalEndpoint := os.Getenv("RUSTFS_TEST_EXTERNAL_ENDPOINT")
	if externalEndpoint == "" {
		externalEndpoint = endpoint
	}
	bucket := os.Getenv("RUSTFS_TEST_BUCKET")
	if bucket == "" {
		bucket = "monaserver-agent-test"
	}

	obj, err := NewObject(
		endpoint,
		externalEndpoint,
		os.Getenv("RUSTFS_TEST_ACCESS_KEY"),
		os.Getenv("RUSTFS_TEST_SECRET_KEY"),
		bucket,
		useSSL,
		time.Hour,
	)
	if err != nil {
		t.Fatalf("NewObject: %v", err)
	}

	ctx := context.Background()
	if err := obj.EnsureBucket(ctx); err != nil {
		t.Fatalf("EnsureBucket: %v", err)
	}

	key := "tests/object-service-test.bin"
	want := []byte("RustFS object-service integration")
	if err := obj.Put(ctx, key, want, "application/octet-stream"); err != nil {
		t.Fatalf("Put: %v", err)
	}
	t.Cleanup(func() { _ = obj.Remove(ctx, key) })

	got, exists, err := obj.GetIfExists(ctx, key)
	if err != nil {
		t.Fatalf("GetIfExists: %v", err)
	}
	if !exists || !bytes.Equal(got, want) {
		t.Fatalf("GetIfExists returned exists=%t data=%q, want exists=true data=%q", exists, got, want)
	}

	url, err := obj.PresignedGet(ctx, key)
	if err != nil {
		t.Fatalf("PresignedGet: %v", err)
	}
	if !strings.Contains(url, key) {
		t.Fatalf("presigned URL does not contain object key %q: %q", key, url)
	}
}

func TestPresignedGetDoesNotCallExternalEndpoint(t *testing.T) {
	var requests int
	var mu sync.Mutex
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		mu.Lock()
		requests++
		mu.Unlock()
		w.WriteHeader(http.StatusInternalServerError)
	}))
	defer server.Close()

	obj, err := NewObject(
		"http://127.0.0.1:1",
		server.URL,
		"testkey",
		"testsecret",
		"testbucket",
		false,
		time.Hour,
	)
	if err != nil {
		t.Fatalf("NewObject: %v", err)
	}

	url, err := obj.PresignedGet(context.Background(), "pins/test-id.png")
	if err != nil {
		t.Fatalf("PresignedGet returned error: %v", err)
	}
	if url == "" {
		t.Fatal("expected non-empty presigned URL")
	}
	if !strings.HasPrefix(url, server.URL+"/testbucket/") {
		t.Fatalf("presigned URL uses unexpected endpoint or bucket path: %q", url)
	}

	mu.Lock()
	defer mu.Unlock()
	if requests != 0 {
		t.Fatalf("PresignedGet made %d network requests", requests)
	}
}

type fakeObjectStore struct {
	mu      sync.Mutex
	bucket  bool
	objects map[string][]byte
}

func (s *fakeObjectStore) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	parts := strings.SplitN(strings.TrimPrefix(r.URL.Path, "/"), "/", 2)
	if len(parts) == 0 || parts[0] != "testbucket" {
		w.WriteHeader(http.StatusNotFound)
		return
	}

	s.mu.Lock()
	defer s.mu.Unlock()

	if len(parts) == 1 {
		s.handleBucket(w, r)
		return
	}
	if !s.bucket {
		w.WriteHeader(http.StatusNotFound)
		return
	}

	key := parts[1]
	switch r.Method {
	case http.MethodPut:
		data, err := io.ReadAll(r.Body)
		if err != nil {
			w.WriteHeader(http.StatusBadRequest)
			return
		}
		s.objects[key] = data
		w.WriteHeader(http.StatusOK)
	case http.MethodHead:
		if _, ok := s.objects[key]; !ok {
			w.WriteHeader(http.StatusNotFound)
			return
		}
		w.WriteHeader(http.StatusOK)
	case http.MethodGet:
		data, ok := s.objects[key]
		if !ok {
			w.WriteHeader(http.StatusNotFound)
			return
		}
		_, _ = w.Write(data)
	case http.MethodDelete:
		delete(s.objects, key)
		w.WriteHeader(http.StatusNoContent)
	default:
		w.WriteHeader(http.StatusMethodNotAllowed)
	}
}

func (s *fakeObjectStore) handleBucket(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodHead:
		if !s.bucket {
			w.WriteHeader(http.StatusNotFound)
			return
		}
		w.WriteHeader(http.StatusOK)
	case http.MethodPut:
		s.bucket = true
		w.WriteHeader(http.StatusOK)
	default:
		w.WriteHeader(http.StatusMethodNotAllowed)
	}
}

func (s *fakeObjectStore) bucketExists() bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.bucket
}
