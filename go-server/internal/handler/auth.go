package handler

import (
	"encoding/json"
	"net/http"

	"github.com/google/uuid"
	"github.com/lrprojects/monaserver/internal/apperrors"
	"github.com/lrprojects/monaserver/internal/service"
)

type Auth struct{ svc *service.Auth }

func NewAuth(svc *service.Auth) *Auth { return &Auth{svc: svc} }

type signupReq struct {
	Username string  `json:"username"`
	Password string  `json:"password"`
	Email    *string `json:"email,omitempty"`
}

type loginReq struct {
	Username string `json:"username"`
	Password string `json:"password"`
}

type refreshReq struct {
	RefreshToken string `json:"refreshToken"`
}

func (h *Auth) Signup(w http.ResponseWriter, r *http.Request) {
	var req signupReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		apperrors.WriteError(w, apperrors.ErrBadRequest)
		return
	}
	pair, err := h.svc.Signup(r.Context(), req.Username, req.Password, req.Email)
	if err != nil {
		apperrors.WriteError(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, pair)
}

func (h *Auth) Login(w http.ResponseWriter, r *http.Request) {
	var req loginReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		apperrors.WriteError(w, apperrors.ErrBadRequest)
		return
	}
	pair, err := h.svc.Login(r.Context(), req.Username, req.Password)
	if err != nil {
		apperrors.WriteError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, pair)
}

func (h *Auth) Refresh(w http.ResponseWriter, r *http.Request) {
	var req refreshReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		apperrors.WriteError(w, apperrors.ErrBadRequest)
		return
	}
	tok, err := uuid.Parse(req.RefreshToken)
	if err != nil {
		apperrors.WriteError(w, apperrors.ErrBadRequest)
		return
	}
	pair, err := h.svc.Refresh(r.Context(), tok)
	if err != nil {
		apperrors.WriteError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, pair)
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}
