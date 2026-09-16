package handler

import (
	"context"
	"net/http"
	"time"

	genserver "github.com/lrprojects/monaserver/internal/gen/server"
	"github.com/lrprojects/monaserver/internal/service"
)

// AdminUsersServicer exposes the bounded account projection. The service
// performs filtering at its persistence boundary and this adapter only maps
// the generated query values into that typed request.
type AdminUsersServicer struct {
	users *service.AdminUserService
}

type AdminUserServicer = AdminUsersServicer

func NewAdminUsersServicer(users *service.AdminUserService) *AdminUsersServicer {
	return &AdminUsersServicer{users: users}
}

func NewAdminUserServicer(users *service.AdminUserService) *AdminUsersServicer {
	return NewAdminUsersServicer(users)
}

func (s *AdminUsersServicer) ListAdminUsers(ctx context.Context, cursor string, limit int32, search string, securityState genserver.AdminSecurityState, verifiedEmail bool, createdAfter, createdBefore time.Time) (genserver.ImplResponse, error) {
	if s == nil || s.users == nil {
		return adminResponse(ctx, service.ErrAdminRepositoryAbsent)
	}
	actor, err := adminActor(ctx)
	if err != nil {
		return adminResponse(ctx, err)
	}
	query := service.AdminUserQuery{Cursor: cursor, Limit: int(limit), Search: search, SecurityState: string(securityState)}
	// The generated frozen interface represents an optional boolean as bool.
	// Preserve the contract's omitted/default behavior for false; service
	// callers that need an explicit false use AdminUserQuery directly.
	if verifiedEmail {
		query.VerifiedEmail = &verifiedEmail
	}
	if !createdAfter.IsZero() {
		query.CreatedAfter = &createdAfter
	}
	if !createdBefore.IsZero() {
		query.CreatedBefore = &createdBefore
	}
	page, err := s.users.List(ctx, actor, query)
	if err != nil {
		return adminResponse(ctx, err)
	}
	body := genserver.AdminUserPageDto{Items: make([]genserver.AdminUserDto, 0, len(page.Items)), NextCursor: page.Next}
	for _, user := range page.Items {
		body.Items = append(body.Items, toAdminUser(user))
	}
	return genserver.Response(http.StatusOK, body), nil
}

func (s *AdminUsersServicer) GetAdminUser(ctx context.Context, userID string) (genserver.ImplResponse, error) {
	if s == nil || s.users == nil {
		return adminResponse(ctx, service.ErrAdminRepositoryAbsent)
	}
	actor, err := adminActor(ctx)
	if err != nil {
		return adminResponse(ctx, err)
	}
	id, err := parseAdminUUID(userID)
	if err != nil {
		return adminResponse(ctx, err)
	}
	user, err := s.users.Get(ctx, actor, id)
	if err != nil {
		return adminResponse(ctx, err)
	}
	return genserver.Response(http.StatusOK, toAdminUserDetails(*user)), nil
}

var _ genserver.AdminUsersAPIServicer = (*AdminUsersServicer)(nil)
