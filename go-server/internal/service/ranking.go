package service

import (
	"context"
	"time"

	"github.com/google/uuid"

	"github.com/lrprojects/monaserver/internal/apperrors"
	"github.com/lrprojects/monaserver/internal/db"
)

// Ranking service — mirrors RankingServiceImpl.
type Ranking struct{ q *db.Queries }

func NewRanking(q *db.Queries) *Ranking { return &Ranking{q: q} }

// UserRankingItem mirrors UserRankingDtoInner.
type UserRankingItem struct {
	RankNr      int        `json:"rankNr"`
	Points      int32      `json:"points"`
	UserID      uuid.UUID  `json:"userId"`
	Username    string     `json:"username"`
	Description *string    `json:"description,omitempty"`
	SelectedBatch *int32   `json:"selectedBatch,omitempty"`
}

// GroupRankingItem mirrors GroupRankingDtoInner.
type GroupRankingItem struct {
	RankNr      int        `json:"rankNr"`
	Points      int32      `json:"points"`
	GroupID     uuid.UUID  `json:"groupId"`
	Name        string     `json:"name"`
	Visibility  int        `json:"visibility"`
	Description *string    `json:"description,omitempty"`
}

// BoundaryItem mirrors RankingSearchDtoInner.
type BoundaryItem struct {
	Level int32  `json:"level"`
	Gid   string `json:"gid"`
	Name  string `json:"name"`
}

// MapInfoItem mirrors MapInfoDto.
type MapInfoItem struct {
	Gid0, Gid1, Gid2   *string `json:"-"`
	Name0, Name1, Name2 *string `json:"-"`
	// Flattened for JSON
	Gid  *string `json:"gid,omitempty"`
	Name *string `json:"name,omitempty"`
}

func (s *Ranking) UserRanking(ctx context.Context, gid0, gid1, gid2 *string, since *time.Time, season bool, page, size int32) ([]UserRankingItem, error) {
	f := db.RankingFilter{
		Gid0: gid0, Gid1: gid1, Gid2: gid2,
		Since: sinceValue(since, season), Limit: size, Offset: page * size,
	}
	rows, err := s.q.GetUserRanking(ctx, f)
	if err != nil {
		return nil, err
	}
	out := make([]UserRankingItem, 0, len(rows))
	for i, r := range rows {
		out = append(out, UserRankingItem{
			RankNr: int(f.Offset) + i + 1, Points: r.Points,
			UserID: r.UserID, Username: r.Username, Description: r.Description,
			SelectedBatch: r.AchievementID,
		})
	}
	return out, nil
}

func (s *Ranking) GroupRanking(ctx context.Context, gid0, gid1, gid2 *string, since *time.Time, season bool, page, size int32) ([]GroupRankingItem, error) {
	f := db.RankingFilter{
		Gid0: gid0, Gid1: gid1, Gid2: gid2,
		Since: sinceValue(since, season), Limit: size, Offset: page * size,
	}
	rows, err := s.q.GetGlobalGroupRanking(ctx, f)
	if err != nil {
		return nil, err
	}
	out := make([]GroupRankingItem, 0, len(rows))
	for i, r := range rows {
		var desc *string
		if r.Visibility == 0 {
			desc = r.Description
		}
		out = append(out, GroupRankingItem{
			RankNr: int(f.Offset) + i + 1, Points: r.Points,
			GroupID: r.GroupID, Name: r.Name, Visibility: r.Visibility, Description: desc,
		})
	}
	return out, nil
}

func (s *Ranking) GeoJson(ctx context.Context, gid0, gid1, gid2 *string) ([]string, error) {
	return s.q.GetGeoJson(ctx, gid0, gid1, gid2)
}

func (s *Ranking) MapInfo(ctx context.Context, lat, lng float64) ([]db.MapInfoRow, error) {
	row, err := s.q.GetMapInfo(ctx, lat, lng)
	if err != nil {
		return nil, err
	}
	if row == nil {
		return []db.MapInfoRow{}, nil
	}
	return []db.MapInfoRow{*row}, nil
}

func (s *Ranking) SearchBoundaries(ctx context.Context, search *string, page, size int32) ([]BoundaryItem, error) {
	rows, err := s.q.SearchBoundaries(ctx, search, size, page*size)
	if err != nil {
		return nil, err
	}
	out := make([]BoundaryItem, 0, len(rows))
	for _, r := range rows {
		out = append(out, BoundaryItem{Level: r.Level, Gid: r.Gid, Name: r.Name})
	}
	return out, nil
}

func sinceValue(since *time.Time, season bool) *time.Time {
	if since != nil {
		return since
	}
	if season {
		now := time.Now()
		t := time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, now.Location())
		return &t
	}
	return nil
}

var _ = apperrors.ErrNotFound
