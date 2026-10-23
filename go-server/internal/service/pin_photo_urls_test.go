package service

import (
	"context"
	"net/url"
	"testing"
	"time"

	"github.com/lrprojects/monaserver/internal/db"
)

func TestPhotoDTOKeepsFullAndThumbnailURLsDistinct(t *testing.T) {
	obj, err := NewObject("127.0.0.1:9100", "storage.example.test", "testkey", "testsecret", "photos", false, time.Hour)
	if err != nil {
		t.Fatal(err)
	}
	svc := &Pin{obj: obj}
	blurhash := "already-stored"
	for _, tc := range []struct {
		name          string
		key           string
		fullPath      string
		thumbnailPath string
	}{
		{"original", "pins/original.png", "/photos/pins/original.png", "/photos/pins/original.png.thumbnail.jpg"},
		{"update", "pins/pin/photos/update.jpg", "/photos/pins/pin/photos/update.jpg", "/photos/pins/pin/photos/update.jpg.thumbnail.jpg"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			photo, err := svc.photoDTO(context.Background(), db.PinPhoto{ImageKey: tc.key, ImageBlurhash: &blurhash})
			if err != nil {
				t.Fatal(err)
			}
			for _, variant := range []struct {
				name  string
				value *string
				want  string
			}{
				{"full", photo.Image, tc.fullPath},
				{"thumbnail", photo.ImageThumbnail, tc.thumbnailPath},
			} {
				if variant.value == nil {
					t.Fatalf("%s URL is missing", variant.name)
				}
				parsed, err := url.Parse(*variant.value)
				if err != nil {
					t.Fatal(err)
				}
				if parsed.Path != variant.want {
					t.Errorf("%s object path = %q, want %q", variant.name, parsed.Path, variant.want)
				}
			}
		})
	}
}
