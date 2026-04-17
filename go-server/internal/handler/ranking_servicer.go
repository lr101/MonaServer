package handler

import (
	"context"
	"net/http"
	"time"

	"github.com/lrprojects/monaserver/internal/apperrors"
	genserver "github.com/lrprojects/monaserver/internal/gen/server"
	"github.com/lrprojects/monaserver/internal/service"
)

// RankingServicer implements genserver.RankingAPIServicer.
type RankingServicer struct {
	svc *service.Ranking
}

func NewRankingServicer(svc *service.Ranking) *RankingServicer {
	return &RankingServicer{svc: svc}
}

func (s *RankingServicer) GroupRanking(ctx context.Context, gid0, gid1, gid2 string, since time.Time, season bool, page, size int32) (genserver.ImplResponse, error) {
	var sincePtr *time.Time
	if !since.IsZero() {
		sincePtr = &since
	}
	out, err := s.svc.GroupRanking(ctx, optStr(gid0), optStr(gid1), optStr(gid2), sincePtr, season, page, size)
	if err != nil {
		return genserver.Response(apperrors.HTTPStatus(err), nil), nil
	}
	items := make([]genserver.GroupRankingDtoInner, 0, len(out))
	for _, r := range out {
		items = append(items, genserver.GroupRankingDtoInner{
			GroupInfoDto: genserver.GroupDto{
				Id:         r.GroupID.String(),
				Name:       r.Name,
				Visibility: int32(r.Visibility),
				Description: strDeref(r.Description),
			},
			RankNr: int32(r.RankNr),
			Points: r.Points,
		})
	}
	return genserver.Response(http.StatusOK, items), nil
}

func (s *RankingServicer) UserRanking(ctx context.Context, gid0, gid1, gid2 string, since time.Time, season bool, page, size int32) (genserver.ImplResponse, error) {
	var sincePtr *time.Time
	if !since.IsZero() {
		sincePtr = &since
	}
	out, err := s.svc.UserRanking(ctx, optStr(gid0), optStr(gid1), optStr(gid2), sincePtr, season, page, size)
	if err != nil {
		return genserver.Response(apperrors.HTTPStatus(err), nil), nil
	}
	items := make([]genserver.UserRankingDtoInner, 0, len(out))
	for _, r := range out {
		items = append(items, genserver.UserRankingDtoInner{
			UserInfoDto: genserver.UserInfoDto{
				UserId:      r.UserID.String(),
				Username:    r.Username,
				Description: strDeref(r.Description),
			},
			RankNr: int32(r.RankNr),
			Points: r.Points,
		})
	}
	return genserver.Response(http.StatusOK, items), nil
}

func (s *RankingServicer) SearchRanking(ctx context.Context, search string, page, size int32) (genserver.ImplResponse, error) {
	out, err := s.svc.SearchBoundaries(ctx, optStr(search), page, size)
	if err != nil {
		return genserver.Response(apperrors.HTTPStatus(err), nil), nil
	}
	items := make([]genserver.RankingSearchDtoInner, 0, len(out))
	for _, r := range out {
		items = append(items, genserver.RankingSearchDtoInner{
			AdminLevel: r.Level,
			Name:       r.Name,
			Gid:        r.Gid,
		})
	}
	return genserver.Response(http.StatusOK, items), nil
}

func (s *RankingServicer) GetMapInfo(ctx context.Context, lat, lng float32) (genserver.ImplResponse, error) {
	rows, err := s.svc.MapInfo(ctx, float64(lat), float64(lng))
	if err != nil {
		return genserver.Response(apperrors.HTTPStatus(err), nil), nil
	}
	items := make([]genserver.MapInfoDto, 0, len(rows))
	for _, r := range rows {
		items = append(items, genserver.MapInfoDto{
			Id:    r.ID.String(),
			Gid0:  r.Gid0,
			Name0: r.Name0,
			Gid1:  r.Gid1,
			Name1: r.Name1,
			Gid2:  r.Gid2,
			Name2: r.Name2,
		})
	}
	return genserver.Response(http.StatusOK, items), nil
}

func (s *RankingServicer) GetGeoJson(ctx context.Context, gid0, gid1, gid2 string) (genserver.ImplResponse, error) {
	out, err := s.svc.GeoJson(ctx, optStr(gid0), optStr(gid1), optStr(gid2))
	if err != nil {
		return genserver.Response(apperrors.HTTPStatus(err), nil), nil
	}
	return genserver.Response(http.StatusOK, out), nil
}
