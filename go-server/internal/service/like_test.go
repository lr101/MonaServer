package service

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/lrprojects/monaserver/internal/db"
)

func TestPhotoUpdateLikesBelongToTheSelectedPicture(t *testing.T) {
	q, auth, _, like, pin, group, _, _, _ := setupServices(t)
	ctx := context.Background()
	creator := createTestUser(t, auth, "originalauthor")
	contributor := createTestUser(t, auth, "updateauthor")
	liker := createTestUser(t, auth, "photoliker")
	groupID := createTestGroup(t, group, creator, "photolikegroup")
	pinID := createTestPin(t, pin, creator, groupID)
	photoID := uuid.New()
	if err := q.CreatePinPhoto(ctx, db.PinPhoto{
		ID: photoID, PinID: pinID, ContributorID: &contributor,
		ContributorUsername: "updateauthor", ImageKey: "test/" + photoID.String(),
		ObservedAt: time.Now(),
	}); err != nil {
		t.Fatal(err)
	}
	on := true
	if _, err := like.CreateOrUpdate(ctx, photoID, CreateLikeInput{UserID: liker, Like: &on}); err != nil {
		t.Fatalf("like update: %v", err)
	}
	original, err := like.CountByPin(ctx, pinID, liker)
	if err != nil {
		t.Fatal(err)
	}
	update, err := like.CountByPin(ctx, photoID, liker)
	if err != nil {
		t.Fatal(err)
	}
	if original.LikeCount != 0 || original.LikedByUser || update.LikeCount != 1 || !update.LikedByUser {
		t.Fatalf("original = %+v, update = %+v", original, update)
	}
	creatorLikes, err := like.UserLikes(ctx, creator)
	if err != nil {
		t.Fatal(err)
	}
	contributorLikes, err := like.UserLikes(ctx, contributor)
	if err != nil {
		t.Fatal(err)
	}
	if creatorLikes.LikeCount != 0 || contributorLikes.LikeCount != 1 {
		t.Fatalf("creator likes = %+v, contributor likes = %+v", creatorLikes, contributorLikes)
	}
}

func TestContributorSearchFindsUpdatedLocationWithoutDuplicatingIt(t *testing.T) {
	q, auth, _, _, pin, group, _, _, _ := setupServices(t)
	ctx := context.Background()
	creator := createTestUser(t, auth, "searchcreator")
	contributor := createTestUser(t, auth, "searchupdater")
	groupID := createTestGroup(t, group, creator, "searchgroup")
	pinID := createTestPin(t, pin, creator, groupID)
	photoID := uuid.New()
	if err := q.CreatePinPhoto(ctx, db.PinPhoto{
		ID: photoID, PinID: pinID, ContributorID: &contributor,
		ContributorUsername: "searchupdater", ImageKey: "test/" + photoID.String(),
		ObservedAt: time.Now(),
	}); err != nil {
		t.Fatal(err)
	}
	results, err := q.SearchPins(ctx, db.PinSearch{CallerID: contributor, CreatorID: &contributor, Limit: 20})
	if err != nil {
		t.Fatal(err)
	}
	if len(results) != 1 || results[0].ID != pinID {
		t.Fatalf("contributor search = %+v, want one location %s", results, pinID)
	}
}

func TestMemberSticksCountPicturesFromUpdates(t *testing.T) {
	q, auth, _, _, pin, group, member, _, _ := setupServices(t)
	ctx := context.Background()
	creator := createTestUser(t, auth, "membercreator")
	contributor := createTestUser(t, auth, "memberupdater")
	groupID := createTestGroup(t, group, creator, "memberphotogroup")
	if _, err := member.Join(ctx, groupID, contributor, nil); err != nil {
		t.Fatal(err)
	}
	pinID := createTestPin(t, pin, creator, groupID)
	photoID := uuid.New()
	if err := q.CreatePinPhoto(ctx, db.PinPhoto{
		ID: photoID, PinID: pinID, ContributorID: &contributor,
		ContributorUsername: "memberupdater", ImageKey: "test/" + photoID.String(),
		ObservedAt: time.Now(),
	}); err != nil {
		t.Fatal(err)
	}
	ranking, err := member.Ranking(ctx, groupID)
	if err != nil {
		t.Fatal(err)
	}
	points := map[uuid.UUID]int32{}
	for _, row := range ranking {
		points[row.UserID] = row.Ranking
	}
	if points[creator] != 1 || points[contributor] != 1 {
		t.Fatalf("member sticks = %v, want one original and one update", points)
	}
}

func TestPhotoUpdateAdvancesContributorStickAchievement(t *testing.T) {
	q, auth, _, _, pin, group, _, _, _ := setupServices(t)
	ctx := context.Background()
	creator := createTestUser(t, auth, "stickcreator")
	contributor := createTestUser(t, auth, "stickupdater")
	groupID := createTestGroup(t, group, creator, "stickgroup")
	first := createTestPin(t, pin, contributor, groupID)
	_ = first
	second := createTestPin(t, pin, creator, groupID)
	photoID := uuid.New()
	if err := q.CreatePinPhoto(ctx, db.PinPhoto{
		ID: photoID, PinID: second, ContributorID: &contributor,
		ContributorUsername: "stickupdater", ImageKey: "test/" + photoID.String(),
		ObservedAt: time.Now(),
	}); err != nil {
		t.Fatal(err)
	}
	progress, err := q.GetAchievementProgress(ctx, contributor)
	if err != nil {
		t.Fatal(err)
	}
	sticks := achievementByID(t, progress, 3)
	if sticks.CurrentValue != 2 || !sticks.Claimable {
		t.Fatalf("two sticks after one original and one update = %+v", sticks)
	}
}

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

	t.Run("create like", func(t *testing.T) {
		dto, err := like.CreateOrUpdate(ctx, pid, CreateLikeInput{
			UserID: uid,
			Like:   &likeAll,
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
