package main

import (
	"context"
	"errors"
	"fmt"
	"github.com/google/uuid"
	"testing"
	"time"
)

func TestEndpointGalleryPhotos(t *testing.T) {
	store := &galleryTestStore{memoryPinObjectStore: newMemoryPinObjectStore()}
	srv, _ := buildTestServerWithPinStore(t, store)
	defer srv.Close()
	anon := &apiClient{base: srv.URL}
	auth := anon.signup(t, "gallery_owner", "pw123")
	owner := &apiClient{base: srv.URL, bearer: auth.AccessToken}
	otherAuth := anon.signup(t, "gallery_viewer", "pw123")
	viewer := &apiClient{base: srv.URL, bearer: otherAuth.AccessToken}
	group := owner.createGroup(t, auth.UserID, "gallery_private", 1)
	resp := owner.do(t, "POST", "/api/v2/pins", map[string]any{"image": testImageBase64, "latitude": 48.137, "longitude": 11.576, "creationDate": time.Now().UTC().Format(time.RFC3339), "userId": auth.UserID, "groupId": group})
	if resp.StatusCode != 201 {
		t.Fatalf("create: %d", resp.StatusCode)
	}
	var pin map[string]any
	decode(t, resp, &pin)
	resp.Body.Close()
	pinID := fmt.Sprint(pin["id"])
	resp = owner.do(t, "POST", "/api/v2/pins/"+pinID+"/photos", map[string]any{"image": testImageBase64, "idempotencyKey": uuid.NewString(), "latitude": 48.137, "longitude": 11.576, "accuracyMeters": 0})
	if resp.StatusCode != 201 {
		t.Fatalf("update: %d", resp.StatusCode)
	}
	var update map[string]any
	decode(t, resp, &update)
	resp.Body.Close()
	path := "/api/v2/gallery/photos?groupId=" + group + "&limit=1"
	resp = anon.do(t, "GET", path, nil)
	resp.Body.Close()
	if resp.StatusCode != 401 {
		t.Fatalf("anonymous: %d", resp.StatusCode)
	}
	resp = owner.do(t, "GET", path, nil)
	if resp.StatusCode != 200 {
		t.Fatalf("gallery: %d", resp.StatusCode)
	}
	var first struct {
		Items []struct {
			Photo map[string]any `json:"photo"`
		} `json:"items"`
		NextCursor string `json:"nextCursor"`
	}
	decode(t, resp, &first)
	resp.Body.Close()
	if len(first.Items) != 1 || first.Items[0].Photo["id"] != update["id"] || first.NextCursor == "" {
		t.Fatalf("first page: %+v", first)
	}
	for _, invalid := range []string{"/api/v2/gallery/photos", path + "&userId=" + auth.UserID, "/api/v2/gallery/photos?groupId=" + group + "&limit=101", "/api/v2/gallery/photos?userId=" + auth.UserID + "&cursor=" + first.NextCursor} {
		bad := owner.do(t, "GET", invalid, nil)
		bad.Body.Close()
		if bad.StatusCode != 400 {
			t.Fatalf("invalid gallery query %s: %d", invalid, bad.StatusCode)
		}
	}
	unauthorized := anon.do(t, "POST", "/api/v2/photos/resolve", map[string]any{"photoIds": []string{fmt.Sprint(update["id"])}})
	unauthorized.Body.Close()
	if unauthorized.StatusCode != 401 {
		t.Fatalf("anonymous resolve: %d", unauthorized.StatusCode)
	}
	resp = owner.do(t, "GET", path+"&cursor="+first.NextCursor, nil)
	var second struct {
		Items []struct {
			Photo map[string]any `json:"photo"`
		} `json:"items"`
		NextCursor string `json:"nextCursor"`
	}
	decode(t, resp, &second)
	resp.Body.Close()
	if len(second.Items) != 1 || second.Items[0].Photo["isOriginal"] != true || second.NextCursor != "" {
		t.Fatalf("second page: %+v", second)
	}
	for _, client := range []*apiClient{owner, viewer} {
		resp = client.do(t, "POST", "/api/v2/photos/resolve", map[string]any{"photoIds": []string{fmt.Sprint(update["id"]), uuid.NewString()}})
		if resp.StatusCode != 200 {
			t.Fatalf("resolve: %d", resp.StatusCode)
		}
		var batch struct {
			Items []struct {
				Status int            `json:"status"`
				Photo  map[string]any `json:"photo"`
			} `json:"items"`
		}
		decode(t, resp, &batch)
		resp.Body.Close()
		want := 200
		if client == viewer {
			want = 404
		}
		if len(batch.Items) != 2 || batch.Items[0].Status != want || batch.Items[1].Status != 404 {
			t.Fatalf("batch: %+v", batch)
		}
	}
	resp = viewer.do(t, "GET", path, nil)
	resp.Body.Close()
	if resp.StatusCode != 403 {
		t.Fatalf("private gallery: %d", resp.StatusCode)
	}
	resp = owner.do(t, "GET", "/api/v2/gallery/photos?userId="+auth.UserID, nil)
	var all struct {
		Items []any `json:"items"`
	}
	decode(t, resp, &all)
	resp.Body.Close()
	if len(all.Items) != 2 {
		t.Fatalf("contribution gallery: %+v", all)
	}
	store.failSigning = true
	resp = owner.do(t, "POST", "/api/v2/photos/resolve", map[string]any{"photoIds": []string{fmt.Sprint(update["id"])}})
	var failed struct {
		Items []struct {
			Status int `json:"status"`
		} `json:"items"`
	}
	decode(t, resp, &failed)
	resp.Body.Close()
	if len(failed.Items) != 1 || failed.Items[0].Status != 503 {
		t.Fatalf("signer failure should be retryable: %+v", failed)
	}
	store.failSigning = false
	resp = owner.do(t, "DELETE", "/api/v2/pins/"+pinID, nil)
	resp.Body.Close()
	resp = owner.do(t, "GET", path, nil)
	decode(t, resp, &all)
	resp.Body.Close()
	if len(all.Items) != 0 {
		t.Fatalf("deleted photo leaked: %+v", all)
	}
}

type galleryTestStore struct {
	*memoryPinObjectStore
	failSigning bool
}

func (s *galleryTestStore) PresignedGet(ctx context.Context, key string) (string, error) {
	if s.failSigning {
		return "", errors.New("signer unavailable")
	}
	return s.memoryPinObjectStore.PresignedGet(ctx, key)
}
