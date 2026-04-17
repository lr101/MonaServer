package handler

import (
	"encoding/json"
	"net/http"
	"strconv"
	"time"

	"github.com/google/uuid"

	"github.com/lrprojects/monaserver/internal/apperrors"
	"github.com/lrprojects/monaserver/internal/service"
)

type Groups struct{ svc *service.Group }

func NewGroups(svc *service.Group) *Groups { return &Groups{svc: svc} }

func (h *Groups) Create(w http.ResponseWriter, r *http.Request) {
	var in service.CreateGroupInput
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		apperrors.WriteError(w, apperrors.ErrBadRequest)
		return
	}
	dto, err := h.svc.Create(r.Context(), in)
	if err != nil {
		apperrors.WriteError(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, dto)
}

func (h *Groups) Get(w http.ResponseWriter, r *http.Request) {
	id, err := pathUUID(r, "groupId")
	if err != nil {
		apperrors.WriteError(w, apperrors.ErrBadRequest)
		return
	}
	dto, err := h.svc.GetDTO(r.Context(), id)
	if err != nil {
		apperrors.WriteError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, dto)
}

func (h *Groups) Update(w http.ResponseWriter, r *http.Request) {
	id, err := pathUUID(r, "groupId")
	if err != nil {
		apperrors.WriteError(w, apperrors.ErrBadRequest)
		return
	}
	var in service.UpdateGroupInput
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		apperrors.WriteError(w, apperrors.ErrBadRequest)
		return
	}
	dto, err := h.svc.Update(r.Context(), id, in)
	if err != nil {
		apperrors.WriteError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, dto)
}

func (h *Groups) Delete(w http.ResponseWriter, r *http.Request) {
	id, err := pathUUID(r, "groupId")
	if err != nil {
		apperrors.WriteError(w, apperrors.ErrBadRequest)
		return
	}
	if err := h.svc.Delete(r.Context(), id); err != nil {
		apperrors.WriteError(w, err)
		return
	}
	w.WriteHeader(http.StatusOK)
}

func (h *Groups) Search(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	var search *string
	if v := q.Get("search"); v != "" {
		search = &v
	}
	var userID *uuid.UUID
	if v := q.Get("userId"); v != "" {
		if id, err := uuid.Parse(v); err == nil {
			userID = &id
		}
	}
	var withUser *bool
	if v := q.Get("withUser"); v != "" {
		b, err := strconv.ParseBool(v)
		if err == nil {
			withUser = &b
		}
	}
	withImages := true
	if v := q.Get("withImages"); v != "" {
		if b, err := strconv.ParseBool(v); err == nil {
			withImages = b
		}
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
	var after *time.Time
	if v := q.Get("updatedAfter"); v != "" {
		if t, err := time.Parse(time.RFC3339, v); err == nil {
			after = &t
		}
	}
	res, err := h.svc.Search(r.Context(), search, userID, withUser, withImages, page, size, after)
	if err != nil {
		apperrors.WriteError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, res)
}

// single-field read-only endpoints:
func (h *Groups) Admin(w http.ResponseWriter, r *http.Request) {
	id, err := pathUUID(r, "groupId")
	if err != nil {
		apperrors.WriteError(w, apperrors.ErrBadRequest)
		return
	}
	name, err := h.svc.GetAdminUsername(r.Context(), id)
	if err != nil {
		apperrors.WriteError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, name)
}

func (h *Groups) Description(w http.ResponseWriter, r *http.Request) {
	id, err := pathUUID(r, "groupId")
	if err != nil {
		apperrors.WriteError(w, apperrors.ErrBadRequest)
		return
	}
	g, err := h.svc.Get(r.Context(), id)
	if err != nil {
		apperrors.WriteError(w, err)
		return
	}
	desc := ""
	if g.Description != nil {
		desc = *g.Description
	}
	writeJSON(w, http.StatusOK, desc)
}

func (h *Groups) Link(w http.ResponseWriter, r *http.Request) {
	id, err := pathUUID(r, "groupId")
	if err != nil {
		apperrors.WriteError(w, apperrors.ErrBadRequest)
		return
	}
	g, err := h.svc.Get(r.Context(), id)
	if err != nil {
		apperrors.WriteError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, g.Link)
}

func (h *Groups) InviteUrl(w http.ResponseWriter, r *http.Request) {
	id, err := pathUUID(r, "groupId")
	if err != nil {
		apperrors.WriteError(w, apperrors.ErrBadRequest)
		return
	}
	g, err := h.svc.Get(r.Context(), id)
	if err != nil {
		apperrors.WriteError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, g.InviteUrl)
}

func (h *Groups) ProfileImage(small bool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		id, err := pathUUID(r, "groupId")
		if err != nil {
			apperrors.WriteError(w, apperrors.ErrBadRequest)
			return
		}
		u, err := h.svc.ProfileImageURL(r.Context(), id, small)
		if err != nil {
			apperrors.WriteError(w, err)
			return
		}
		if u == nil {
			w.WriteHeader(http.StatusOK)
			return
		}
		if redirectWanted(r) {
			http.Redirect(w, r, *u, http.StatusFound)
			return
		}
		writeJSON(w, http.StatusOK, *u)
	}
}

func (h *Groups) PinImage(w http.ResponseWriter, r *http.Request) {
	id, err := pathUUID(r, "groupId")
	if err != nil {
		apperrors.WriteError(w, apperrors.ErrBadRequest)
		return
	}
	u, err := h.svc.PinImageURL(r.Context(), id)
	if err != nil {
		apperrors.WriteError(w, err)
		return
	}
	if u == nil {
		w.WriteHeader(http.StatusOK)
		return
	}
	if redirectWanted(r) {
		http.Redirect(w, r, *u, http.StatusFound)
		return
	}
	writeJSON(w, http.StatusOK, *u)
}
