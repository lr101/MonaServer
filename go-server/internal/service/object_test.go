package service

import (
	"context"
	"strings"
	"testing"
	"time"
)

// TestPresignedGetNoNetworkCall verifies that PresignedGet completes instantly
// even when the external endpoint is unreachable (as it is from inside Docker).
//
// minio-go calls GetBucketLocation before every presign operation unless Region
// is configured. That call goes to the external endpoint (10.0.2.2:9000), which
// is only reachable by mobile clients, not by the server container — causing a
// 30-second TCP timeout per request. Setting Region in minio.Options bypasses
// the network lookup entirely (pure HMAC computation).
func TestPresignedGetNoNetworkCall(t *testing.T) {
	// 192.0.2.1 is RFC 5737 TEST-NET — packets are guaranteed to be black-holed,
	// so any network call to this address will hang until the OS TCP timeout fires.
	const unreachableExternal = "192.0.2.1:9000"

	obj, err := NewObject(
		"localhost:9999",    // internal endpoint (not used by PresignedGet)
		unreachableExternal, // external endpoint — unreachable from server
		"testkey",
		"testsecret",
		"testbucket",
		false,
		time.Hour,
	)
	if err != nil {
		t.Fatalf("NewObject: %v", err)
	}

	start := time.Now()
	ctx := context.Background()
	url, err := obj.PresignedGet(ctx, "pins/test-id.png")
	elapsed := time.Since(start)

	if err != nil {
		t.Fatalf("PresignedGet returned error: %v", err)
	}
	if url == "" {
		t.Fatal("expected non-empty presigned URL")
	}
	if !strings.Contains(url, "testbucket") {
		t.Fatalf("presigned URL missing bucket name: %q", url)
	}
	if elapsed > 2*time.Second {
		t.Fatalf("PresignedGet took %v — expected <2s (no network call should be made)", elapsed)
	}
}
