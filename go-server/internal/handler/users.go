package handler

import (
	"encoding/json"
	"net/http"
	"net/url"
	"strconv"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/lrprojects/monaserver/internal/apperrors"
	"github.com/lrprojects/monaserver/internal/middleware"
	"github.com/lrprojects/monaserver/internal/service"
)

type Users struct{ svc *service.User }

func NewUsers(svc *service.User) *Users { return &Users{svc: svc} }

func pathUUID(r *http.Request, key string) (uuid.UUID, error) {
	return uuid.Parse(chi.URLParam(r, key))
}

func (h *Users) Get(w http.ResponseWriter, r *http.Request) {
	id, err := pathUUID(r, "userId")
	if err != nil {
		apperrors.WriteError(w, apperrors.ErrBadRequest)
		return
	}
	u, err := h.svc.Get(r.Context(), id)
	if err != nil {
		apperrors.WriteError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, service.ToPublicUserInfo(u))
}

func (h *Users) Xp(w http.ResponseWriter, r *http.Request) {
	id, err := pathUUID(r, "userId")
	if err != nil {
		apperrors.WriteError(w, apperrors.ErrBadRequest)
		return
	}
	u, err := h.svc.Get(r.Context(), id)
	if err != nil {
		apperrors.WriteError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"xp": u.XP})
}

func (h *Users) Delete(w http.ResponseWriter, r *http.Request) {
	id, err := pathUUID(r, "userId")
	if err != nil {
		apperrors.WriteError(w, apperrors.ErrBadRequest)
		return
	}
	var code int
	if err := json.NewDecoder(r.Body).Decode(&code); err != nil {
		apperrors.WriteError(w, apperrors.ErrBadRequest)
		return
	}
	if err := h.svc.Delete(r.Context(), id, code); err != nil {
		apperrors.WriteError(w, err)
		return
	}
	w.WriteHeader(http.StatusOK)
}

func (h *Users) Update(w http.ResponseWriter, r *http.Request) {
	id, err := pathUUID(r, "userId")
	if err != nil {
		apperrors.WriteError(w, apperrors.ErrBadRequest)
		return
	}
	var in service.UserUpdateInput
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		apperrors.WriteError(w, apperrors.ErrBadRequest)
		return
	}
	res, err := h.svc.Update(r.Context(), id, in)
	if err != nil {
		apperrors.WriteError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, res)
}

func (h *Users) ProfileImage(small bool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		id, err := pathUUID(r, "userId")
		if err != nil {
			apperrors.WriteError(w, apperrors.ErrBadRequest)
			return
		}
		urlPtr, err := h.svc.ProfileImageURL(r.Context(), id, small)
		if err != nil {
			apperrors.WriteError(w, err)
			return
		}
		if urlPtr == nil {
			w.WriteHeader(http.StatusOK)
			return
		}
		if redirectWanted(r) {
			if _, perr := url.Parse(*urlPtr); perr == nil {
				http.Redirect(w, r, *urlPtr, http.StatusFound)
				return
			}
		}
		writeJSON(w, http.StatusOK, *urlPtr)
	}
}

func redirectWanted(r *http.Request) bool {
	v := r.URL.Query().Get("redirect")
	if v == "" {
		return false
	}
	b, _ := strconv.ParseBool(v)
	return b
}

func (h *Users) Achievements(w http.ResponseWriter, r *http.Request) {
	id, err := pathUUID(r, "userId")
	if err != nil {
		apperrors.WriteError(w, apperrors.ErrBadRequest)
		return
	}
	items, err := h.svc.Achievements(r.Context(), id)
	if err != nil {
		apperrors.WriteError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, items)
}

func (h *Users) ClaimAchievement(w http.ResponseWriter, r *http.Request) {
	id, err := pathUUID(r, "userId")
	if err != nil {
		apperrors.WriteError(w, apperrors.ErrBadRequest)
		return
	}
	aID, err := strconv.Atoi(chi.URLParam(r, "achievementId"))
	if err != nil {
		apperrors.WriteError(w, apperrors.ErrBadRequest)
		return
	}
	if err := h.svc.ClaimAchievement(r.Context(), id, int32(aID)); err != nil {
		apperrors.WriteError(w, err)
		return
	}
	w.WriteHeader(http.StatusOK)
}

func (h *Users) Likes(w http.ResponseWriter, r *http.Request) {
	id, err := pathUUID(r, "userId")
	if err != nil {
		apperrors.WriteError(w, apperrors.ErrBadRequest)
		return
	}
	likes, err := h.svc.LikedPins(r.Context(), id)
	if err != nil {
		apperrors.WriteError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, likes)
}

// ensure we compile-check middleware import (used via routing wire-up in main.go)
var _ = middleware.UserID
