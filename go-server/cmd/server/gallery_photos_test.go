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

func TestEndpointLargeUserAndGroupGalleries(t *testing.T) {
	store := &galleryTestStore{memoryPinObjectStore: newMemoryPinObjectStore()}
	srv, q := buildTestServerWithPinStore(t, store)
	defer srv.Close()
	anon := &apiClient{base: srv.URL}
	auth := anon.signup(t, "large_gallery", "pw123")
	owner := &apiClient{base: srv.URL, bearer: auth.AccessToken}
	group := owner.createGroup(t, auth.UserID, "large_gallery_group", 0)
	_, err := q.Pool().Exec(context.Background(), `
        WITH inserted AS (
          INSERT INTO pins (id, latitude, longitude, creation_date, update_date, creator_id, group_id)
          SELECT uuid_generate_v4(), 48.0, 11.0, '2024-01-01'::timestamptz, '2024-01-01'::timestamptz, $1::uuid, $2::uuid
          FROM generate_series(1, 105) RETURNING id, creator_id, creation_date
        )
        INSERT INTO pin_photos (id, pin_id, contributor_id, contributor_username, image_key, observed_at, is_original, image_blurhash)
        SELECT id, id, creator_id, 'large_gallery', 'pins/' || id || '.png', creation_date, TRUE, 'fixture' FROM inserted`, auth.UserID, group)
	if err != nil {
		t.Fatalf("seed gallery: %v", err)
	}
	for _, scope := range []string{"groupId=" + group, "userId=" + auth.UserID} {
		seen := map[string]bool{}
		cursor := ""
		for pages := 0; ; pages++ {
			if pages > 2 {
				t.Fatal("gallery did not terminate")
			}
			path := "/api/v2/gallery/photos?limit=100&" + scope
			if cursor != "" {
				path += "&cursor=" + cursor
			}
			resp := owner.do(t, "GET", path, nil)
			if resp.StatusCode != 200 {
				t.Fatalf("gallery %s: %d", scope, resp.StatusCode)
			}
			var page struct {
				Items []struct {
					Photo struct {
						ID string `json:"id"`
					} `json:"photo"`
				} `json:"items"`
				Next string `json:"nextCursor"`
			}
			decode(t, resp, &page)
			resp.Body.Close()
			for _, item := range page.Items {
				if seen[item.Photo.ID] {
					t.Fatalf("duplicate photo %s", item.Photo.ID)
				}
				seen[item.Photo.ID] = true
			}
			if page.Next == "" {
				break
			}
			cursor = page.Next
		}
		if len(seen) != 105 {
			t.Fatalf("%s returned %d photos, want 105", scope, len(seen))
		}
	}
}
