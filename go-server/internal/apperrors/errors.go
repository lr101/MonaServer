package apperrors

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/http"

	"github.com/jackc/pgx/v5/pgconn"
)

type AppError struct {
	Code    int
	Message string
}

func (e *AppError) Error() string {
	return fmt.Sprintf("%d: %s", e.Code, e.Message)
}

func New(code int, msg string) *AppError {
	return &AppError{Code: code, Message: msg}
}

var (
	ErrNotFound     = &AppError{Code: http.StatusNotFound, Message: "not found"}
	ErrConflict     = &AppError{Code: http.StatusConflict, Message: "conflict"}
	ErrForbidden    = &AppError{Code: http.StatusForbidden, Message: "forbidden"}
	ErrBadRequest   = &AppError{Code: http.StatusBadRequest, Message: "bad request"}
	ErrUnauthorized = &AppError{Code: http.StatusUnauthorized, Message: "unauthorized"}
	ErrInternal     = &AppError{Code: http.StatusInternalServerError, Message: "internal server error"}
	ErrUnavailable  = &AppError{Code: http.StatusServiceUnavailable, Message: "service unavailable"}
)

// HTTPStatus returns the HTTP status code for an error.
func HTTPStatus(err error) int {
	if err == nil {
		return http.StatusOK
	}
	var appErr *AppError
	if errors.As(err, &appErr) {
		return appErr.Code
	}
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) && pgErr.Code == "23505" {
		return http.StatusBadRequest
	}
	return http.StatusInternalServerError
}

// Message extracts a human-readable message from an error for use in JSON responses.
func Message(err error) string {
	if err == nil {
		return ""
	}
	var appErr *AppError
	if errors.As(err, &appErr) {
		return appErr.Message
	}
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) && pgErr.Code == "23505" {
		return "unique constraint violation"
	}
	return "internal server error"
}

// WriteJSONError writes a JSON {"error": msg} response with the given status code.
func WriteJSONError(w http.ResponseWriter, msg string, code int) {
	w.Header().Set("Content-Type", "application/json; charset=UTF-8")
	w.WriteHeader(code)
	_ = json.NewEncoder(w).Encode(map[string]string{"error": msg})
}

// WriteError translates domain errors to JSON HTTP responses.
func WriteError(w http.ResponseWriter, err error) {
	if err == nil {
		return
	}
	WriteJSONError(w, Message(err), HTTPStatus(err))
}
