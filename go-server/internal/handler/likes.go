package handler

import (
	"encoding/json"
	"net/http"

	"github.com/lrprojects/monaserver/internal/apperrors"
	"github.com/lrprojects/monaserver/internal/middleware"
	"github.com/lrprojects/monaserver/internal/service"
)

type Likes struct{ svc *service.Like }

func NewLikes(svc *service.Like) *Likes { return &Likes{svc: svc} }

func (h *Likes) CreateOrUpdate(w http.ResponseWriter, r *http.Request) {
	pinID, err := pathUUID(r, "pinId")
	if err != nil {
		apperrors.WriteError(w, apperrors.ErrBadRequest)
		return
	}
	var in service.CreateLikeInput
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		apperrors.WriteError(w, apperrors.ErrBadRequest)
		return
	}
	if uid, ok := middleware.UserID(r.Context()); ok && middleware.Role(r.Context()) != middleware.RoleAdmin && uid != in.UserID {
		apperrors.WriteError(w, apperrors.ErrForbidden)
		return
	}
	dto, err := h.svc.CreateOrUpdate(r.Context(), pinID, in)
	if err != nil {
		apperrors.WriteError(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, dto)
}

func (h *Likes) PinLikes(w http.ResponseWriter, r *http.Request) {
	pinID, err := pathUUID(r, "pinId")
	if err != nil {
		apperrors.WriteError(w, apperrors.ErrBadRequest)
		return
	}
	uid, _ := middleware.UserID(r.Context())
	dto, err := h.svc.CountByPin(r.Context(), pinID, uid)
	if err != nil {
		apperrors.WriteError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, dto)
}

func (h *Likes) UserLikes(w http.ResponseWriter, r *http.Request) {
	userID, err := pathUUID(r, "userId")
	if err != nil {
		apperrors.WriteError(w, apperrors.ErrBadRequest)
		return
	}
	dto, err := h.svc.UserLikes(r.Context(), userID)
	if err != nil {
		apperrors.WriteError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, dto)
}
