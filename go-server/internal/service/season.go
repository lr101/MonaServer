package service

import (
	"context"
	"time"

	"github.com/lrprojects/monaserver/internal/db"
)

type Season struct {
	q *db.Queries
}

type SeasonResult struct {
	Number int
	Users  int
	Groups int
}

func NewSeason(q *db.Queries) *Season {
	return &Season{q: q}
}

func (s *Season) CreateMonth(ctx context.Context, month time.Time) (SeasonResult, error) {
	result := SeasonResult{}
	err := s.q.InTx(ctx, func(q *db.Queries) error {
		maxNumber, err := q.GetMaxSeasonNumber(ctx)
		if err != nil {
			return err
		}
		result.Number = maxNumber + 1
		seasonID, err := q.CreateSeason(ctx, result.Number, month.Year(), int(month.Month()))
		if err != nil {
			return err
		}
		since := time.Date(month.Year(), month.Month(), 1, 0, 0, 0, 0, month.Location())
		userRanks, err := q.GetUserRanking(ctx, db.RankingFilter{Since: &since, Limit: -1})
		if err != nil {
			return err
		}
		for i, rank := range userRanks {
			if err := q.CreateUserSeason(ctx, rank.UserID, seasonID, int32(i+1), rank.Points); err != nil {
				return err
			}
		}
		groupRanks, err := q.GetGlobalGroupRanking(ctx, db.RankingFilter{Since: &since, Limit: -1})
		if err != nil {
			return err
		}
		for i, rank := range groupRanks {
			if err := q.CreateGroupSeason(ctx, rank.GroupID, seasonID, int32(i+1), rank.Points); err != nil {
				return err
			}
		}
		result.Users = len(userRanks)
		result.Groups = len(groupRanks)
		return nil
	})
	return result, err
}
