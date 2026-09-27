package main

import (
	"context"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/lrprojects/monaserver/internal/config"
	"github.com/lrprojects/monaserver/internal/service"
)

func TestInitialRustFSProbeDoesNotBlockServerStartup(t *testing.T) {
	probeStarted := make(chan struct{})
	probeCanceled := make(chan struct{})
	var probeStartedOnce, probeCanceledOnce sync.Once
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodHead {
			probeStartedOnce.Do(func() { close(probeStarted) })
			<-r.Context().Done()
			probeCanceledOnce.Do(func() { close(probeCanceled) })
			return
		}
		w.WriteHeader(http.StatusServiceUnavailable)
	}))
	defer server.Close()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	result := make(chan *service.Object, 1)
	started := time.Now()
	go func() {
		result <- initObjectService(ctx, &config.Config{
			RustfsEndpoint: server.URL, RustfsExternalEndpoint: server.URL,
			RustfsAccessKey: "key", RustfsSecretKey: "secret", RustfsBucket: "testbucket",
		}, slog.New(slog.NewTextHandler(io.Discard, nil)), 10*time.Millisecond)
	}()

	select {
	case obj := <-result:
		if obj == nil {
			t.Fatal("transient RustFS probe disabled the object service")
		}
		if elapsed := time.Since(started); elapsed > 100*time.Millisecond {
			t.Fatalf("initial RustFS probe delayed startup by %s", elapsed)
		}
	case <-time.After(100 * time.Millisecond):
		cancel()
		select {
		case <-result:
		case <-time.After(time.Second):
			t.Fatal("startup remained blocked after its context was canceled")
		}
		t.Fatal("initial RustFS probe blocked server startup")
	}

	select {
	case <-probeStarted:
	case <-time.After(time.Second):
		t.Fatal("background RustFS probe did not start")
	}
	cancel()
	select {
	case <-probeCanceled:
	case <-time.After(time.Second):
		t.Fatal("RustFS probe did not stop after its context was canceled")
	}
}

func TestObjectServiceRecoversAfterRustFSStartup503(t *testing.T) {
	var ready, bucketCreated atomic.Bool
	probeStarted := make(chan struct{})
	var probeStartedOnce sync.Once
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !ready.Load() {
			probeStartedOnce.Do(func() { close(probeStarted) })
			w.WriteHeader(http.StatusServiceUnavailable)
			return
		}
		switch {
		case r.Method == http.MethodHead && r.URL.Path == "/testbucket":
			if !bucketCreated.Load() {
				w.WriteHeader(http.StatusNotFound)
			}
		case r.Method == http.MethodPut && r.URL.Path == "/testbucket":
			bucketCreated.Store(true)
		case r.Method == http.MethodGet && r.URL.Path == "/testbucket/pins/photo.png" && bucketCreated.Load():
			_, _ = w.Write([]byte("image data"))
		default:
			w.WriteHeader(http.StatusNotFound)
		}
	}))
	defer server.Close()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	obj := initObjectService(ctx, &config.Config{
		RustfsEndpoint:         server.URL,
		RustfsExternalEndpoint: server.URL,
		RustfsAccessKey:        "key",
		RustfsSecretKey:        "secret",
		RustfsBucket:           "testbucket",
	}, slog.New(slog.NewTextHandler(io.Discard, nil)), 10*time.Millisecond)
	if obj == nil {
		t.Fatal("transient RustFS 503 disabled the object service")
	}

	select {
	case <-probeStarted:
	case <-time.After(time.Second):
		t.Fatal("initial RustFS probe did not return the expected 503")
	}
	ready.Store(true)
	deadline := time.After(3 * time.Second)
	for !bucketCreated.Load() {
		select {
		case <-deadline:
			t.Fatal("bucket was not ensured after RustFS became ready")
		case <-time.After(10 * time.Millisecond):
		}
	}
	image, err := obj.Get(ctx, "pins/photo.png")
	if err != nil || string(image) != "image data" {
		t.Fatalf("Get after RustFS recovered = %q, %v", image, err)
	}
}
