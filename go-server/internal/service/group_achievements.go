package service

import (
	"context"

	"github.com/google/uuid"

	"github.com/lrprojects/monaserver/internal/apperrors"
	"github.com/lrprojects/monaserver/internal/db"
)

type GroupAchievementProgress struct {
	ID             int32
	Name           string
	Description    string
	Difficulty     string
	CurrentValue   int32
	Threshold      int32
	Claimed        bool
	Claimable      bool
	RewardPinStyle string
}

func (s *Group) AchievementProgress(ctx context.Context, id uuid.UUID) ([]GroupAchievementProgress, error) {
	if _, err := s.Get(ctx, id); err != nil {
		return nil, err
	}
	items, err := s.q.GetGroupAchievementProgress(ctx, id)
	if err != nil {
		return nil, err
	}
	progress := make([]GroupAchievementProgress, 0, len(items))
	for _, item := range items {
		progress = append(progress, GroupAchievementProgress{
			ID: item.ID, Name: item.Name, Description: item.Description,
			Difficulty: item.Difficulty, CurrentValue: item.CurrentValue,
			Threshold: item.Threshold, Claimed: item.Claimed,
			Claimable: item.Claimable, RewardPinStyle: item.RewardPinStyle,
		})
	}
	return progress, nil
}

func (s *Group) ClaimAchievement(ctx context.Context, groupID, memberID uuid.UUID, achievementID int32) error {
	if _, err := s.Get(ctx, groupID); err != nil {
		return err
	}
	if _, ok := db.GroupAchievementDefinition(achievementID); !ok {
		return apperrors.ErrForbidden
	}
	progress, err := s.q.GetGroupAchievementProgress(ctx, groupID)
	if err != nil {
		return err
	}
	for _, item := range progress {
		if item.ID != achievementID {
			continue
		}
		if item.Claimed {
			return nil
		}
		if !item.Claimable {
			return apperrors.ErrForbidden
		}
		claimed, err := s.q.ClaimGroupAchievementReward(ctx, groupID, memberID, achievementID)
		if err != nil {
			return err
		}
		if claimed {
			return nil
		}
		// A concurrent member may have claimed it after the initial progress read.
		latest, err := s.q.ListGroupAchievementClaims(ctx, groupID)
		if err != nil {
			return err
		}
		for _, claimedID := range latest {
			if claimedID == achievementID {
				return nil
			}
		}
		return apperrors.ErrForbidden
	}
	return apperrors.ErrForbidden
}
