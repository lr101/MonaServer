package service

import (
	"context"
	"encoding/base64"
	"net/http"
	"sort"
	"strings"
	"time"

	"github.com/google/uuid"

	"github.com/lrprojects/monaserver/internal/apperrors"
)

var (
	ErrInvalidUserQuery     = apperrors.New(http.StatusBadRequest, "invalid user query")
	ErrUserNotFound         = apperrors.New(http.StatusNotFound, "user was not found")
	ErrUserEmailUnavailable = apperrors.New(http.StatusConflict, "user email cannot be verified")
)

const maxAdminUserSearchBytes = 256

// AdminUser is the safe administrative account projection. It intentionally
// has no password, refresh token, action token, provider token, or delivery
// payload field, so accidental JSON encoding cannot disclose credentials.
type AdminUser struct {
	ID                    uuid.UUID
	Username              string
	Email                 *string
	EmailVerified         bool
	CreatedAt             time.Time
	SecurityState         string
	AuthGeneration        int64
	PasswordDisabled      bool
	PasswordResetRequired bool
	IsAdmin               bool
	CompromisedAt         *time.Time
	EligibilityReasons    []string
	CommunicationOptOut   bool
	PushOptedOut          bool
	RegisteredDeviceCount int32
}

type AdminUserQuery struct {
	Cursor        string
	Limit         int
	Search        string
	SecurityState string
	VerifiedEmail *bool
	CreatedAfter  *time.Time
	CreatedBefore *time.Time
}

// AdminUserListRequest is the handler-facing name used by the users route.
type AdminUserListRequest = AdminUserQuery

type AdminUserPage struct {
	Items []AdminUser
	Next  *string
}

// AdminUserStore is deliberately paginated at the persistence boundary. A
// production implementation must evaluate filters in PostgreSQL and return
// one stable page; it must not load every account into a request handler.
type AdminUserStore interface {
	ListUsers(context.Context, AdminUserQuery) (AdminUserPage, error)
	GetUser(context.Context, uuid.UUID) (*AdminUser, error)
}

type adminUserEmailVerifier interface {
	VerifyUserEmail(context.Context, uuid.UUID, uuid.UUID) (*AdminUser, error)
}

type AdminUserService struct {
	store AdminUserStore
}

func NewAdminUserService(store AdminUserStore) *AdminUserService {
	return &AdminUserService{store: store}
}

func NewAdminUsersService(store AdminUserStore) *AdminUserService {
	return NewAdminUserService(store)
}

func (s *AdminUserService) VerifyEmail(ctx context.Context, actor AdminActor, id uuid.UUID) (*AdminUser, error) {
	if s == nil || s.store == nil {
		return nil, ErrAdminRepositoryAbsent
	}
	if !actor.Valid() {
		return nil, ErrAudienceUnauthorized
	}
	if !actor.Can("users.verify") {
		return nil, ErrAudienceForbidden
	}
	if id == uuid.Nil {
		return nil, ErrInvalidUserQuery
	}
	verifier, ok := s.store.(adminUserEmailVerifier)
	if !ok {
		return nil, ErrAdminRepositoryAbsent
	}
	user, err := verifier.VerifyUserEmail(ctx, actor.ID, id)
	if err != nil {
		return nil, err
	}
	if user == nil {
		return nil, ErrUserNotFound
	}
	clean := sanitizeUser(*user)
	return &clean, nil
}

func normalizeUserQuery(request AdminUserQuery) (AdminUserQuery, error) {
	if request.Limit == 0 {
		request.Limit = defaultPageLimit
	}
	if request.Limit < 1 || request.Limit > maxPageLimit || len([]byte(request.Search)) > maxAdminUserSearchBytes || !hasText(request.Search, maxAdminUserSearchBytes) {
		return AdminUserQuery{}, ErrInvalidUserQuery
	}
	request.Search = strings.TrimSpace(request.Search)
	if request.SecurityState != "" && !validSecurityState(request.SecurityState) {
		return AdminUserQuery{}, ErrInvalidUserQuery
	}
	if request.CreatedAfter != nil && request.CreatedBefore != nil && request.CreatedAfter.After(*request.CreatedBefore) {
		return AdminUserQuery{}, ErrInvalidUserQuery
	}
	if request.Cursor != "" {
		if _, err := decodeUserCursor(request.Cursor); err != nil {
			return AdminUserQuery{}, err
		}
	}
	return request, nil
}

func (s *AdminUserService) List(ctx context.Context, actor AdminActor, request AdminUserQuery) (*AdminUserPage, error) {
	if s == nil || s.store == nil {
		return nil, ErrAdminRepositoryAbsent
	}
	if !actor.Valid() {
		return nil, ErrAudienceUnauthorized
	}
	if !actor.Can("users.read") {
		return nil, ErrAudienceForbidden
	}
	request, err := normalizeUserQuery(request)
	if err != nil {
		return nil, err
	}
	page, err := s.store.ListUsers(ctx, request)
	if err != nil {
		return nil, err
	}
	page.Items = sanitizeUsers(page.Items)
	return &page, nil
}

func (s *AdminUserService) Get(ctx context.Context, actor AdminActor, id uuid.UUID) (*AdminUser, error) {
	if s == nil || s.store == nil {
		return nil, ErrAdminRepositoryAbsent
	}
	if !actor.Valid() {
		return nil, ErrAudienceUnauthorized
	}
	if !actor.Can("users.read") {
		return nil, ErrAudienceForbidden
	}
	if id == uuid.Nil {
		return nil, ErrInvalidUserQuery
	}
	user, err := s.store.GetUser(ctx, id)
	if err != nil {
		return nil, err
	}
	if user == nil {
		return nil, ErrUserNotFound
	}
	clean := sanitizeUser(*user)
	return &clean, nil
}

func sanitizeUsers(users []AdminUser) []AdminUser {
	out := make([]AdminUser, 0, len(users))
	for _, user := range users {
		out = append(out, sanitizeUser(user))
	}
	return out
}

func sanitizeUser(user AdminUser) AdminUser {
	user.Username = strings.TrimSpace(user.Username)
	if user.Email != nil {
		email := strings.TrimSpace(*user.Email)
		user.Email = &email
	}
	user.CompromisedAt = cloneTime(user.CompromisedAt)
	if user.SecurityState == "" {
		user.SecurityState = "normal"
	}
	if user.AuthGeneration < 0 {
		user.AuthGeneration = 0
	}
	if user.RegisteredDeviceCount < 0 {
		user.RegisteredDeviceCount = 0
	}
	reasons := make([]string, 0, len(user.EligibilityReasons))
	seen := make(map[string]struct{}, len(user.EligibilityReasons))
	for _, reason := range user.EligibilityReasons {
		reason = safeReason(reason)
		if reason == "" {
			continue
		}
		if _, ok := seen[reason]; ok {
			continue
		}
		seen[reason] = struct{}{}
		reasons = append(reasons, reason)
	}
	sort.Strings(reasons)
	user.EligibilityReasons = reasons
	return user
}

func encodeUserCursor(id uuid.UUID) string {
	return base64.RawURLEncoding.EncodeToString([]byte("u:" + id.String()))
}

func decodeUserCursor(cursor string) (uuid.UUID, error) {
	b, err := base64.RawURLEncoding.DecodeString(cursor)
	if err != nil || !strings.HasPrefix(string(b), "u:") {
		return uuid.Nil, ErrInvalidUserQuery
	}
	id, err := uuid.Parse(strings.TrimPrefix(string(b), "u:"))
	if err != nil || id == uuid.Nil {
		return uuid.Nil, ErrInvalidUserQuery
	}
	return id, nil
}

func userMatchesQuery(user AdminUser, query AdminUserQuery) bool {
	if query.Search != "" {
		search := strings.ToLower(query.Search)
		if !strings.Contains(strings.ToLower(user.Username), search) && (user.Email == nil || !strings.Contains(strings.ToLower(*user.Email), search)) && !strings.Contains(user.ID.String(), search) {
			return false
		}
	}
	if query.SecurityState != "" && user.SecurityState != query.SecurityState {
		return false
	}
	if query.VerifiedEmail != nil && user.EmailVerified != *query.VerifiedEmail {
		return false
	}
	if query.CreatedAfter != nil && user.CreatedAt.Before(*query.CreatedAfter) {
		return false
	}
	if query.CreatedBefore != nil && !user.CreatedAt.Before(*query.CreatedBefore) {
		return false
	}
	return true
}

func (m *MemoryAdminStore) ListUsers(_ context.Context, query AdminUserQuery) (AdminUserPage, error) {
	if m == nil {
		return AdminUserPage{}, ErrAdminRepositoryAbsent
	}
	query, err := normalizeUserQuery(query)
	if err != nil {
		return AdminUserPage{}, err
	}
	startID := uuid.Nil
	if query.Cursor != "" {
		startID, err = decodeUserCursor(query.Cursor)
		if err != nil {
			return AdminUserPage{}, err
		}
	}
	m.mu.RLock()
	users := append([]AdminUser(nil), m.Users...)
	m.mu.RUnlock()
	users = sanitizeUsers(users)
	sort.Slice(users, func(i, j int) bool { return users[i].ID.String() < users[j].ID.String() })
	filtered := users[:0]
	for _, user := range users {
		if user.ID == uuid.Nil || !userMatchesQuery(user, query) {
			continue
		}
		if startID != uuid.Nil && user.ID.String() <= startID.String() {
			continue
		}
		filtered = append(filtered, user)
	}
	page := AdminUserPage{Items: append([]AdminUser(nil), filtered...)}
	if len(page.Items) > query.Limit {
		page.Items = page.Items[:query.Limit]
		cursor := encodeUserCursor(page.Items[len(page.Items)-1].ID)
		page.Next = &cursor
	}
	return page, nil
}

func (m *MemoryAdminStore) GetUser(_ context.Context, id uuid.UUID) (*AdminUser, error) {
	if m == nil {
		return nil, ErrAdminRepositoryAbsent
	}
	m.mu.RLock()
	defer m.mu.RUnlock()
	for _, user := range m.Users {
		if user.ID == id {
			clean := sanitizeUser(user)
			return &clean, nil
		}
	}
	return nil, nil
}

func (m *MemoryAdminStore) VerifyUserEmail(_ context.Context, _, id uuid.UUID) (*AdminUser, error) {
	if m == nil {
		return nil, ErrAdminRepositoryAbsent
	}
	m.mu.Lock()
	defer m.mu.Unlock()
	for i := range m.Users {
		if m.Users[i].ID == id && m.Users[i].Email != nil {
			m.Users[i].EmailVerified = true
			clean := sanitizeUser(m.Users[i])
			return &clean, nil
		}
	}
	return nil, nil
}
