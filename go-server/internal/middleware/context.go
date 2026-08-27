package middleware

import (
	"context"

	"github.com/google/uuid"
)

type ctxKey int

const (
	keyUserID ctxKey = iota
	keyRole
)

const (
	RoleUser  = "USER"
	RoleAdmin = "ADMIN"
)

func WithUser(ctx context.Context, id uuid.UUID, role string) context.Context {
	ctx = context.WithValue(ctx, keyUserID, id)
	return context.WithValue(ctx, keyRole, role)
}

func UserID(ctx context.Context) (uuid.UUID, bool) {
	v, ok := ctx.Value(keyUserID).(uuid.UUID)
	return v, ok
}

func Role(ctx context.Context) string {
	if v, ok := ctx.Value(keyRole).(string); ok {
		return v
	}
	return ""
}
