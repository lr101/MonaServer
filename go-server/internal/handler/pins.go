package handler

import (
	"encoding/json"
	"net/http"

	"github.com/lrprojects/monaserver/internal/apperrors"
	"github.com/lrprojects/monaserver/internal/service"
)

type Pins struct{ svc *service.Pin }

func NewPins(svc *service.Pin) *Pins { return &Pins{svc: svc} }

func (h *Pins) Create(w http.ResponseWriter, r *http.Request) {
	var in service.CreatePinInput
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

func (h *Pins) Get(w http.ResponseWriter, r *http.Request) {
	id, err := pathUUID(r, "pinId")
	if err != nil {
		apperrors.WriteError(w, apperrors.ErrBadRequest)
		return
	}
	dto, err := h.svc.Get(r.Context(), id)
	if err != nil {
		apperrors.WriteError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, dto)
}

func (h *Pins) Delete(w http.ResponseWriter, r *http.Request) {
	id, err := pathUUID(r, "pinId")
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

func (h *Pins) Image(w http.ResponseWriter, r *http.Request) {
	id, err := pathUUID(r, "pinId")
	if err != nil {
		apperrors.WriteError(w, apperrors.ErrBadRequest)
		return
	}
	u, err := h.svc.ImageURL(r.Context(), id)
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
