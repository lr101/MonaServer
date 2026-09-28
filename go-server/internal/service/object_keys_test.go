package service

import (
	"testing"

	"github.com/google/uuid"
)

func TestObjectKeys(t *testing.T) {
	id := uuid.MustParse("11111111-2222-3333-4444-555555555555")
	photoID := uuid.MustParse("aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")
	cases := map[string]string{
		PinKey(id):                 "pins/11111111-2222-3333-4444-555555555555.png",
		PinPhotoKey(id, photoID):   "pins/11111111-2222-3333-4444-555555555555/photos/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee.jpg",
		GroupPinKey(id):            "groups/11111111-2222-3333-4444-555555555555/group_pin.png",
		GroupProfileKey(id, false): "groups/11111111-2222-3333-4444-555555555555/group_profile.png",
		GroupProfileKey(id, true):  "groups/11111111-2222-3333-4444-555555555555/group_profile_small.png",
		UserProfileKey(id, false):  "users/11111111-2222-3333-4444-555555555555/profile.png",
		UserProfileKey(id, true):   "users/11111111-2222-3333-4444-555555555555/profile_small.png",
	}
	for got, want := range cases {
		if got != want {
			t.Errorf("got %q want %q", got, want)
		}
	}
}
