package handler

import (
	"context"
	"net/http"
	"strconv"
	"time"

	genserver "github.com/lrprojects/monaserver/internal/gen/server"
	"github.com/lrprojects/monaserver/internal/service"
)

// AdminUsersServicer exposes the bounded account projection. The service
// performs filtering at its persistence boundary and this adapter only maps
// the generated query values into that typed request.
type AdminUsersServicer struct {
	users      *service.AdminUserService
	emailLogin *service.EmailLogin
}

type AdminUserServicer = AdminUsersServicer

type adminUsersQueryKey struct{}

// WithAdminUsersVerifiedEmailPresence carries the generated parser's query
// presence bit across the frozen bool-only service signature. The value is
// deliberately request-scoped and never enters a durable model.
func WithAdminUsersVerifiedEmailPresence(ctx context.Context, verified bool) context.Context {
	return context.WithValue(ctx, adminUsersQueryKey{}, verified)
}

func adminUsersVerifiedEmailPresence(ctx context.Context) (bool, bool) {
	value, ok := ctx.Value(adminUsersQueryKey{}).(bool)
	return value, ok
}

// CaptureAdminUsersQuery must wrap the generated users controller route. The
// generated controller parses optional booleans into a plain bool, so this
// adapter records presence before invoking it and preserves an explicit
// verifiedEmail=false for the service layer.
func CaptureAdminUsersQuery(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if raw, ok := r.URL.Query()["verifiedEmail"]; ok && len(raw) > 0 {
			if value, err := strconv.ParseBool(raw[0]); err == nil {
				r = r.WithContext(WithAdminUsersVerifiedEmailPresence(r.Context(), value))
			}
		}
		next.ServeHTTP(w, r)
	})
}

func NewAdminUsersServicer(users *service.AdminUserService, login ...*service.EmailLogin) *AdminUsersServicer {
	servicer := &AdminUsersServicer{users: users}
	if len(login) > 0 {
		servicer.emailLogin = login[0]
	}
	return servicer
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
	if value, present := adminUsersVerifiedEmailPresence(ctx); present {
		query.VerifiedEmail = &value
	} else if verifiedEmail {
		// Direct generated callers can still express true without the
		// presence middleware; false remains the omitted default in that
		// compatibility path.
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

func (s *AdminUsersServicer) VerifyAdminUserEmail(ctx context.Context, userID, _ string) (genserver.ImplResponse, error) {
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
	user, err := s.users.VerifyEmail(ctx, actor, id)
	if err != nil {
		return adminResponse(ctx, err)
	}
	return genserver.Response(http.StatusOK, toAdminUserDetails(*user)), nil
}

func (s *AdminUsersServicer) SendAdminUserLoginLink(ctx context.Context, userID, _ string) (genserver.ImplResponse, error) {
	if s == nil || s.emailLogin == nil {
		return adminResponse(ctx, service.ErrAdminRepositoryAbsent)
	}
	actor, err := adminActor(ctx)
	if err != nil {
		return adminResponse(ctx, err)
	}
	if !actor.Can("campaign.login_link") {
		return adminResponse(ctx, service.ErrAudienceForbidden)
	}
	id, err := parseAdminUUID(userID)
	if err != nil {
		return adminResponse(ctx, err)
	}
	result, err := s.emailLogin.IssueLoginLink(ctx, service.LoginLinkIssueRequest{AccountID: id, ActorID: &actor.ID})
	if err != nil {
		return adminResponse(ctx, err)
	}
	if result == nil || !result.Issued {
		return adminResponse(ctx, service.ErrUserEmailUnavailable)
	}
	return genserver.Response(http.StatusAccepted, nil), nil
}

var _ genserver.AdminUsersAPIServicer = (*AdminUsersServicer)(nil)
