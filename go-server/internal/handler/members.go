package handler

import (
	"net/http"

	"github.com/google/uuid"

	"github.com/lrprojects/monaserver/internal/apperrors"
	"github.com/lrprojects/monaserver/internal/service"
)

type Members struct{ svc *service.Member }

func NewMembers(svc *service.Member) *Members { return &Members{svc: svc} }

func (h *Members) Join(w http.ResponseWriter, r *http.Request) {
	groupID, err := pathUUID(r, "groupId")
	if err != nil {
		apperrors.WriteError(w, apperrors.ErrBadRequest)
		return
	}
	q := r.URL.Query()
	userID, err := uuid.Parse(q.Get("userId"))
	if err != nil {
		apperrors.WriteError(w, apperrors.ErrBadRequest)
		return
	}
	var invite *string
	if v := q.Get("inviteUrl"); v != "" {
		invite = &v
	}
	dto, err := h.svc.Join(r.Context(), groupID, userID, invite)
	if err != nil {
		apperrors.WriteError(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, dto)
}

func (h *Members) Leave(w http.ResponseWriter, r *http.Request) {
	groupID, err := pathUUID(r, "groupId")
	if err != nil {
		apperrors.WriteError(w, apperrors.ErrBadRequest)
		return
	}
	userID, err := uuid.Parse(r.URL.Query().Get("userId"))
	if err != nil {
		apperrors.WriteError(w, apperrors.ErrBadRequest)
		return
	}
	if err := h.svc.Leave(r.Context(), groupID, userID); err != nil {
		apperrors.WriteError(w, err)
		return
	}
	w.WriteHeader(http.StatusOK)
}

func (h *Members) Ranking(w http.ResponseWriter, r *http.Request) {
	groupID, err := pathUUID(r, "groupId")
	if err != nil {
		apperrors.WriteError(w, apperrors.ErrBadRequest)
		return
	}
	res, err := h.svc.Ranking(r.Context(), groupID)
	if err != nil {
		apperrors.WriteError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, res)
}
