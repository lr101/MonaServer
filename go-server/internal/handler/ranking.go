package handler

import (
	"net/http"
	"strconv"
	"time"

	"github.com/lrprojects/monaserver/internal/apperrors"
	"github.com/lrprojects/monaserver/internal/service"
)

type RankingHandler struct{ svc *service.Ranking }

func NewRanking(svc *service.Ranking) *RankingHandler { return &RankingHandler{svc: svc} }

func (h *RankingHandler) UserRanking(w http.ResponseWriter, r *http.Request) {
	gid0, gid1, gid2, since, season, page, size := parseRankingParams(r)
	out, err := h.svc.UserRanking(r.Context(), gid0, gid1, gid2, since, season, page, size)
	if err != nil {
		apperrors.WriteError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, out)
}

func (h *RankingHandler) GroupRanking(w http.ResponseWriter, r *http.Request) {
	gid0, gid1, gid2, since, season, page, size := parseRankingParams(r)
	out, err := h.svc.GroupRanking(r.Context(), gid0, gid1, gid2, since, season, page, size)
	if err != nil {
		apperrors.WriteError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, out)
}

func (h *RankingHandler) SearchRanking(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	var search *string
	if v := q.Get("search"); v != "" {
		search = &v
	}
	var page, size int32 = 0, 20
	if v := q.Get("page"); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			page = int32(n)
		}
	}
	if v := q.Get("size"); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			size = int32(n)
		}
	}
	out, err := h.svc.SearchBoundaries(r.Context(), search, page, size)
	if err != nil {
		apperrors.WriteError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, out)
}

func (h *RankingHandler) GeoJson(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	gid0 := optStr(q.Get("gid0"))
	gid1 := optStr(q.Get("gid1"))
	gid2 := optStr(q.Get("gid2"))
	out, err := h.svc.GeoJson(r.Context(), gid0, gid1, gid2)
	if err != nil {
		apperrors.WriteError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, out)
}

func (h *RankingHandler) MapInfo(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	lat, errLat := strconv.ParseFloat(q.Get("latitude"), 64)
	lng, errLng := strconv.ParseFloat(q.Get("longitude"), 64)
	if errLat != nil || errLng != nil {
		apperrors.WriteError(w, apperrors.ErrBadRequest)
		return
	}
	out, err := h.svc.MapInfo(r.Context(), lat, lng)
	if err != nil {
		apperrors.WriteError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, out)
}

func parseRankingParams(r *http.Request) (gid0, gid1, gid2 *string, since *time.Time, season bool, page, size int32) {
	q := r.URL.Query()
	gid0 = optStr(q.Get("gid0"))
	gid1 = optStr(q.Get("gid1"))
	gid2 = optStr(q.Get("gid2"))
	if v := q.Get("since"); v != "" {
		if t, err := time.Parse(time.RFC3339, v); err == nil {
			since = &t
		}
	}
	season, _ = strconv.ParseBool(q.Get("season"))
	page, size = 0, 20
	if v := q.Get("page"); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			page = int32(n)
		}
	}
	if v := q.Get("size"); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			size = int32(n)
		}
	}
	return
}

func optStr(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}
