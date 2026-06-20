package service

import (
	"context"
	"testing"
)

func TestLikeCreateOrUpdateAndCount(t *testing.T) {
	_, auth, _, like, pin, group, _, _, _ := setupServices(t)
	ctx := context.Background()

	uid := createTestUser(t, auth, "liker")
	gid := createTestGroup(t, group, uid, "likegroup")
	pid := createTestPin(t, pin, uid, gid)

	t.Run("initial counts are zero", func(t *testing.T) {
		dto, err := like.CountByPin(ctx, pid, uid)
		if err != nil {
			t.Fatalf("count: %v", err)
		}
		if dto.LikeCount != 0 {
			t.Fatalf("expected 0 likes, got %d", dto.LikeCount)
		}
		if dto.LikedByUser {
			t.Fatal("expected LikedByUser=false")
		}
	})

	likeAll := true
	likeLoc := false
	likePhoto := true
	likeArt := false

	t.Run("create like", func(t *testing.T) {
		dto, err := like.CreateOrUpdate(ctx, pid, CreateLikeInput{
			UserID:          uid,
			Like:            &likeAll,
			LikeLocation:    &likeLoc,
			LikePhotography: &likePhoto,
			LikeArt:         &likeArt,
		})
		if err != nil {
			t.Fatalf("create or update: %v", err)
		}
		if dto.LikeCount != 1 {
			t.Fatalf("expected 1 like, got %d", dto.LikeCount)
		}
		if !dto.LikedByUser {
			t.Fatal("expected LikedByUser=true")
		}
		if dto.LikePhotographyCount != 1 {
			t.Fatalf("expected 1 photography like, got %d", dto.LikePhotographyCount)
		}
	})

	t.Run("update like — toggle off", func(t *testing.T) {
		off := false
		dto, err := like.CreateOrUpdate(ctx, pid, CreateLikeInput{
			UserID: uid, Like: &off,
		})
		if err != nil {
			t.Fatalf("update: %v", err)
		}
		if dto.LikedByUser {
			t.Fatal("expected LikedByUser=false after toggle off")
		}
	})

	t.Run("user likes aggregation", func(t *testing.T) {
		// Re-enable a like so aggregation has data.
		on := true
		if _, err := like.CreateOrUpdate(ctx, pid, CreateLikeInput{
			UserID: uid, Like: &on,
		}); err != nil {
			t.Fatalf("re-enable like: %v", err)
		}
		counts, err := like.UserLikes(ctx, uid)
		if err != nil {
			t.Fatalf("user likes: %v", err)
		}
		if counts.LikeCount != 1 {
			t.Fatalf("expected 1 user like, got %d", counts.LikeCount)
		}
	})
}
