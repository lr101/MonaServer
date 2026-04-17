package apperrors

import (
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
	ErrNotFound      = &AppError{Code: http.StatusNotFound, Message: "not found"}
	ErrConflict      = &AppError{Code: http.StatusConflict, Message: "conflict"}
	ErrForbidden     = &AppError{Code: http.StatusForbidden, Message: "forbidden"}
	ErrBadRequest    = &AppError{Code: http.StatusBadRequest, Message: "bad request"}
	ErrUnauthorized  = &AppError{Code: http.StatusUnauthorized, Message: "unauthorized"}
	ErrInternal      = &AppError{Code: http.StatusInternalServerError, Message: "internal server error"}
	ErrUnavailable   = &AppError{Code: http.StatusServiceUnavailable, Message: "service unavailable"}
)

// WriteError translates domain errors to HTTP responses. Replaces @ControllerAdvice.
func WriteError(w http.ResponseWriter, err error) {
	if err == nil {
		return
	}
	var appErr *AppError
	if errors.As(err, &appErr) {
		http.Error(w, appErr.Message, appErr.Code)
		return
	}
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) && pgErr.Code == "23505" {
		http.Error(w, "unique constraint violation", http.StatusBadRequest)
		return
	}
	http.Error(w, "internal server error", http.StatusInternalServerError)
}
