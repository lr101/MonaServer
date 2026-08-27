package service

import (
	"context"

	"github.com/google/uuid"
	"github.com/lrprojects/monaserver/internal/db"
)

// Guard adapts *db.Queries to the middleware.GuardQuery interface.
type Guard struct{ q *db.Queries }

func NewGuard(q *db.Queries) *Guard { return &Guard{q: q} }

func (g *Guard) IsGroupAdmin(ctx context.Context, gid, uid uuid.UUID) (bool, error) {
	return g.q.IsGroupAdmin(ctx, gid, uid)
}
func (g *Guard) IsGroupMember(ctx context.Context, gid, uid uuid.UUID) (bool, error) {
	return g.q.IsGroupMember(ctx, gid, uid)
}
func (g *Guard) IsGroupVisible(ctx context.Context, gid, uid uuid.UUID) (bool, error) {
	return g.q.IsGroupVisible(ctx, gid, uid)
}
func (g *Guard) IsPinCreator(ctx context.Context, pid, uid uuid.UUID) (bool, error) {
	return g.q.IsPinCreator(ctx, pid, uid)
}
func (g *Guard) IsPinGroupAdmin(ctx context.Context, pid, uid uuid.UUID) (bool, error) {
	return g.q.IsPinGroupAdmin(ctx, pid, uid)
}
func (g *Guard) IsPinPublicOrMember(ctx context.Context, pid, uid uuid.UUID) (bool, error) {
	return g.q.IsPinPublicOrMember(ctx, pid, uid)
}
