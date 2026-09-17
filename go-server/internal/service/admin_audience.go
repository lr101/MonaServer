package service

// This file owns the domain boundary for administrator audiences.  The API
// models are intentionally converted at the handler edge: the service never
// trusts a client-side page or re-runs an audience after a preview has been
// committed.

import (
	"context"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"
	"unicode/utf8"

	"github.com/google/uuid"

	"github.com/lrprojects/monaserver/internal/apperrors"
	"github.com/lrprojects/monaserver/internal/middleware"
)

const (
	AudienceSelected   AudienceKind = "selected"
	AudienceFilterKind AudienceKind = "filter"
	AudienceAll        AudienceKind = "all"

	AudienceAccounts AudienceResource = "accounts"
	AudienceReports  AudienceResource = "reports"

	ActionEmail           = "email"
	ActionLoginLink       = "login_link"
	ActionPush            = "push"
	ActionRevokeSessions  = "revoke_sessions"
	ActionMarkCompromised = "mark_compromised"
	ActionRecoveryResend  = "recovery_resend"
	ActionReportResolve   = "report_resolve"
	ActionReportDismiss   = "report_dismiss"

	AudienceSnapshotReady   = "ready"
	AudienceSnapshotPending = "pending"
	AudienceSnapshotFailed  = "failed"

	maxAudienceIDs          = 10_000
	maxAudienceTextBytes    = 320
	maxAudienceTypes        = 100
	maxAudienceExclusions   = 1_000
	defaultSnapshotTTL      = 15 * time.Minute
	defaultMaterializeLimit = 100_000
	defaultPageLimit        = 25
	maxPageLimit            = 100
)

var (
	ErrInvalidAudience       = apperrors.New(http.StatusBadRequest, "invalid audience")
	ErrEmptyAudience         = apperrors.New(http.StatusBadRequest, "audience is empty")
	ErrInvalidAdminAction    = apperrors.New(http.StatusBadRequest, "invalid admin action")
	ErrAudienceForbidden     = apperrors.New(http.StatusForbidden, "admin capability is required")
	ErrAudienceUnauthorized  = apperrors.New(http.StatusUnauthorized, "admin authentication is required")
	ErrSnapshotNotFound      = apperrors.New(http.StatusNotFound, "audience snapshot was not found")
	ErrSnapshotExpired       = apperrors.New(http.StatusConflict, "audience snapshot has expired")
	ErrSnapshotBinding       = apperrors.New(http.StatusConflict, "audience snapshot binding does not match")
	ErrAudienceTooLarge      = apperrors.New(http.StatusBadRequest, "audience is too large")
	ErrAdminRepositoryAbsent = apperrors.New(http.StatusServiceUnavailable, "admin storage is unavailable")
	ErrRecentMFARequired     = apperrors.New(http.StatusForbidden, "recent mfa is required")
)

// AudienceKind and AudienceResource are deliberately string types so callers
// outside HTTP can use the exact wire vocabulary without importing generated
// server models.
type AudienceKind string
type AudienceResource string

// AudienceFilter contains only the criteria supported by the frozen v3
// contract.  The resource tag is checked before any criteria are evaluated.
type AudienceFilter struct {
	Resource         AudienceResource
	Username         *string
	Email            *string
	ID               *string
	IncludeAdmins    bool
	VerifiedEmail    *bool
	SecurityStatuses []string
	CreatedAfter     *time.Time
	CreatedBefore    *time.Time

	AssigneeUserID *uuid.UUID
	Statuses       []string
	Types          []string
}

type Audience struct {
	Kind     AudienceKind
	Resource AudienceResource
	IDs      []uuid.UUID
	Filter   *AudienceFilter
}

// Normalize trims user-entered filter values and turns a filter that contains
// no effective criterion into the explicit all-audience variant. Keeping this
// normalization in the service makes the authorization consequence visible:
// an empty filter receives the same action-bound MFA requirement as all.
func (a Audience) Normalize() Audience {
	return normalizeAudience(a)
}

func normalizeAudience(audience Audience) Audience {
	out := cloneAudience(audience)
	if out.Kind != AudienceFilterKind || out.Filter == nil {
		return out
	}
	filter := out.Filter
	filter.Username = trimAudienceText(filter.Username)
	filter.Email = trimAudienceText(filter.Email)
	filter.ID = trimAudienceText(filter.ID)
	filter.SecurityStatuses = trimAudienceValues(filter.SecurityStatuses)
	filter.Statuses = trimAudienceValues(filter.Statuses)
	filter.Types = trimAudienceValues(filter.Types)
	if filter.Resource == out.Resource && filterCriteriaEmpty(*filter) && !filter.IncludeAdmins {
		out.Kind = AudienceAll
		out.Filter = nil
	}
	return out
}

func filterCriteriaEmpty(filter AudienceFilter) bool {
	return trimAudienceText(filter.Username) == nil && trimAudienceText(filter.Email) == nil && trimAudienceText(filter.ID) == nil && filter.VerifiedEmail == nil && len(trimAudienceValues(filter.SecurityStatuses)) == 0 && filter.CreatedAfter == nil && filter.CreatedBefore == nil && filter.AssigneeUserID == nil && len(trimAudienceValues(filter.Statuses)) == 0 && len(trimAudienceValues(filter.Types)) == 0
}

func trimAudienceText(value *string) *string {
	if value == nil {
		return nil
	}
	trimmed := strings.TrimSpace(*value)
	if trimmed == "" {
		return nil
	}
	return &trimmed
}

func trimAudienceValues(values []string) []string {
	if len(values) == 0 {
		return nil
	}
	out := make([]string, 0, len(values))
	for _, value := range values {
		if value = strings.TrimSpace(value); value != "" {
			out = append(out, value)
		}
	}
	if len(out) == 0 {
		return nil
	}
	return out
}

// AdminAction is the transport-independent closed action union.  Fields not
// belonging to Kind are rejected by ValidateAndSanitize, preventing a caller
// from changing the payload hash by adding ignored JSON fields.
type AdminAction struct {
	Kind        string
	Subject     string
	Body        string
	MessageHTML string
	Reason      string
	Title       string
	Note        string
}

type AdminActor struct {
	ID              uuid.UUID
	Username        string
	State           string
	AuthGeneration  int64
	Capabilities    []string
	Permissions     []string
	RecentMFAAt     *time.Time
	RecentMFAAction string
}

func AdminActorFromContext(ctx context.Context) (AdminActor, bool) {
	principal, ok := middleware.AdminPrincipalFromContext(ctx)
	if !ok {
		return AdminActor{}, false
	}
	id, err := uuid.Parse(principal.UserID)
	if err != nil || id == uuid.Nil {
		return AdminActor{}, false
	}
	return AdminActor{
		ID: principalIDOrNil(id), Username: principal.Username, State: principal.State,
		AuthGeneration: principal.AuthGeneration, Capabilities: append([]string(nil), principal.Capabilities...),
		Permissions: append([]string(nil), principal.Permissions...), RecentMFAAt: cloneTime(principal.RecentMFAAt),
		RecentMFAAction: principal.RecentMFAAction,
	}, true
}

func principalIDOrNil(id uuid.UUID) uuid.UUID { return id }

func (a AdminActor) Can(capability string) bool {
	if a.ID == uuid.Nil || strings.TrimSpace(capability) == "" {
		return false
	}
	for _, value := range a.Capabilities {
		if value == capability {
			return true
		}
	}
	return false
}

func (a AdminActor) Valid() bool {
	return a.ID != uuid.Nil && (a.State == "" || a.State == "authenticated")
}

func isSecurityAction(action string) bool {
	return action == ActionRevokeSessions || action == ActionMarkCompromised || action == ActionRecoveryResend
}

func bulkActionCapability(action string) string {
	switch action {
	case ActionEmail:
		return "campaign.email"
	case ActionLoginLink:
		return "campaign.login_link"
	case ActionPush:
		return "campaign.push"
	case ActionRevokeSessions:
		return "security.revoke"
	case ActionMarkCompromised:
		return "security.compromise"
	case ActionRecoveryResend:
		return "security.recovery_resend"
	case ActionReportResolve:
		return "reports.resolve"
	case ActionReportDismiss:
		return "reports.dismiss"
	default:
		return ""
	}
}

func actionResource(action string) AudienceResource {
	if action == ActionReportResolve || action == ActionReportDismiss {
		return AudienceReports
	}
	return AudienceAccounts
}

func hasText(value string, max int) bool {
	return utf8.ValidString(value) && len([]byte(value)) <= max
}

func nonEmptyText(value string, max int) bool {
	return strings.TrimSpace(value) != "" && hasText(value, max)
}

func actionTextValid(value string, max int, allowNewlines bool) bool {
	if !hasText(value, max) {
		return false
	}
	if strings.ContainsRune(value, '\x00') {
		return false
	}
	if !allowNewlines && strings.ContainsAny(value, "\r\n") {
		return false
	}
	return true
}

// Validate checks the discriminated audience union independently of a store.
func (a Audience) Validate() error {
	if a.Resource != AudienceAccounts && a.Resource != AudienceReports {
		return ErrInvalidAudience
	}
	switch a.Kind {
	case AudienceSelected:
		if len(a.IDs) == 0 || len(a.IDs) > maxAudienceIDs || a.Filter != nil {
			return ErrInvalidAudience
		}
		seen := make(map[uuid.UUID]struct{}, len(a.IDs))
		for _, id := range a.IDs {
			if id == uuid.Nil {
				return ErrInvalidAudience
			}
			if _, exists := seen[id]; exists {
				return ErrInvalidAudience
			}
			seen[id] = struct{}{}
		}
	case AudienceFilterKind:
		if a.Filter == nil || len(a.IDs) != 0 || a.Filter.Resource != a.Resource {
			return ErrInvalidAudience
		}
		if filterCriteriaEmpty(*a.Filter) && !a.Filter.IncludeAdmins {
			return ErrInvalidAudience
		}
		if err := a.Filter.validate(); err != nil {
			return err
		}
	case AudienceAll:
		if a.Filter != nil || len(a.IDs) != 0 {
			return ErrInvalidAudience
		}
	default:
		return ErrInvalidAudience
	}
	return nil
}

func (f AudienceFilter) validate() error {
	if f.Resource != AudienceAccounts && f.Resource != AudienceReports {
		return ErrInvalidAudience
	}
	if f.CreatedAfter != nil && f.CreatedBefore != nil && f.CreatedAfter.After(*f.CreatedBefore) {
		return ErrInvalidAudience
	}
	for _, value := range []*string{f.Username, f.Email, f.ID} {
		if value != nil && !hasText(*value, maxAudienceTextBytes) {
			return ErrInvalidAudience
		}
	}
	if len(f.Types) > maxAudienceTypes || len(f.Statuses) > maxAudienceTypes || len(f.SecurityStatuses) > maxAudienceTypes {
		return ErrInvalidAudience
	}
	if f.Resource == AudienceAccounts {
		if f.AssigneeUserID != nil || len(f.Statuses) != 0 || len(f.Types) != 0 {
			return ErrInvalidAudience
		}
		for _, state := range f.SecurityStatuses {
			if !validSecurityState(state) {
				return ErrInvalidAudience
			}
		}
	} else {
		if f.Username != nil || f.Email != nil || f.ID != nil || f.VerifiedEmail != nil || f.IncludeAdmins || len(f.SecurityStatuses) != 0 {
			return ErrInvalidAudience
		}
		if f.AssigneeUserID != nil && *f.AssigneeUserID == uuid.Nil {
			return ErrInvalidAudience
		}
		for _, status := range f.Statuses {
			if status != "open" && status != "resolved" && status != "dismissed" {
				return ErrInvalidAudience
			}
		}
	}
	return nil
}

func validSecurityState(value string) bool {
	switch value {
	case "normal", "password_disabled", "compromised", "secured_manual_recovery_required", "deleted":
		return true
	default:
		return false
	}
}

func (a Audience) canonicalJSON() ([]byte, error) {
	a = normalizeAudience(a)
	if err := a.Validate(); err != nil {
		return nil, err
	}
	type canonicalFilter struct {
		Resource         AudienceResource `json:"resource"`
		Username         *string          `json:"username,omitempty"`
		Email            *string          `json:"email,omitempty"`
		ID               *string          `json:"id,omitempty"`
		IncludeAdmins    bool             `json:"includeAdmins,omitempty"`
		VerifiedEmail    *bool            `json:"verifiedEmail,omitempty"`
		SecurityStatuses []string         `json:"securityStatuses,omitempty"`
		CreatedAfter     *time.Time       `json:"createdAfter,omitempty"`
		CreatedBefore    *time.Time       `json:"createdBefore,omitempty"`
		AssigneeUserID   *uuid.UUID       `json:"assigneeUserId,omitempty"`
		Statuses         []string         `json:"statuses,omitempty"`
		Types            []string         `json:"types,omitempty"`
	}
	type canonicalAudience struct {
		Kind     AudienceKind     `json:"kind"`
		Resource AudienceResource `json:"resource"`
		IDs      []uuid.UUID      `json:"ids,omitempty"`
		Filter   *canonicalFilter `json:"filter,omitempty"`
	}
	out := canonicalAudience{Kind: a.Kind, Resource: a.Resource}
	if len(a.IDs) > 0 {
		out.IDs = append([]uuid.UUID(nil), a.IDs...)
		sort.Slice(out.IDs, func(i, j int) bool { return out.IDs[i].String() < out.IDs[j].String() })
	}
	if a.Filter != nil {
		f := a.Filter
		out.Filter = &canonicalFilter{
			Resource: f.Resource, Username: cloneString(f.Username), Email: cloneString(f.Email), ID: cloneString(f.ID),
			IncludeAdmins: f.IncludeAdmins, VerifiedEmail: cloneBool(f.VerifiedEmail),
			SecurityStatuses: sortedStrings(f.SecurityStatuses), CreatedAfter: cloneTime(f.CreatedAfter), CreatedBefore: cloneTime(f.CreatedBefore),
			AssigneeUserID: cloneUUID(f.AssigneeUserID), Statuses: sortedStrings(f.Statuses), Types: sortedStrings(f.Types),
		}
	}
	return json.Marshal(out)
}

func cloneString(value *string) *string {
	if value == nil {
		return nil
	}
	v := *value
	return &v
}

func cloneBool(value *bool) *bool {
	if value == nil {
		return nil
	}
	v := *value
	return &v
}

func cloneUUID(value *uuid.UUID) *uuid.UUID {
	if value == nil {
		return nil
	}
	v := *value
	return &v
}

func cloneAudience(audience Audience) Audience {
	copy := audience
	copy.IDs = append([]uuid.UUID(nil), audience.IDs...)
	if audience.Filter != nil {
		filter := *audience.Filter
		filter.Username = cloneString(filter.Username)
		filter.Email = cloneString(filter.Email)
		filter.ID = cloneString(filter.ID)
		filter.VerifiedEmail = cloneBool(filter.VerifiedEmail)
		filter.CreatedAfter = cloneTime(filter.CreatedAfter)
		filter.CreatedBefore = cloneTime(filter.CreatedBefore)
		filter.AssigneeUserID = cloneUUID(filter.AssigneeUserID)
		filter.SecurityStatuses = append([]string(nil), audience.Filter.SecurityStatuses...)
		filter.Statuses = append([]string(nil), audience.Filter.Statuses...)
		filter.Types = append([]string(nil), audience.Filter.Types...)
		copy.Filter = &filter
	}
	return copy
}

func sortedStrings(values []string) []string {
	if len(values) == 0 {
		return nil
	}
	out := append([]string(nil), values...)
	sort.Strings(out)
	return out
}

func (a Audience) CanonicalJSON() ([]byte, error) { return a.canonicalJSON() }

func (a Audience) PayloadHash() (string, error) {
	b, err := a.canonicalJSON()
	if err != nil {
		return "", err
	}
	h := sha256.Sum256(b)
	return hex.EncodeToString(h[:]), nil
}

// ValidateAndSanitize applies the server-side content policy once, before the
// payload hash is calculated. The sanitized value is what is persisted in the
// job payload and shown in previews.
func (a AdminAction) ValidateAndSanitize() (AdminAction, error) {
	if bulkActionCapability(a.Kind) == "" {
		return AdminAction{}, ErrInvalidAdminAction
	}
	if !utf8.ValidString(a.Kind) {
		return AdminAction{}, ErrInvalidAdminAction
	}
	reject := func(ok bool) (AdminAction, error) {
		if !ok {
			return AdminAction{}, ErrInvalidAdminAction
		}
		return a, nil
	}
	switch a.Kind {
	case ActionEmail:
		if !nonEmptyText(a.Subject, MaxEmailSubjectBytes) || !nonEmptyText(a.Body, MaxEmailTextBytes) || !actionTextValid(a.Subject, MaxEmailSubjectBytes, false) || !actionTextValid(a.Body, MaxEmailTextBytes, true) || a.Reason != "" || a.Title != "" || a.Note != "" {
			return reject(false)
		}
		if !actionTextValid(a.MessageHTML, MaxEmailHTMLBytes, true) {
			return reject(false)
		}
		if a.MessageHTML != "" {
			clean, err := SanitizeHTML(a.MessageHTML)
			if err != nil {
				return AdminAction{}, ErrInvalidAdminAction
			}
			a.MessageHTML = clean
		}
		a.Subject = strings.TrimSpace(a.Subject)
	case ActionLoginLink:
		if a.Body != "" || a.MessageHTML != "" || a.Subject != "" || a.Title != "" || a.Note != "" || (a.Reason != "" && (!nonEmptyText(a.Reason, 512) || !actionTextValid(a.Reason, 512, false))) {
			return reject(false)
		}
		a.Reason = strings.TrimSpace(a.Reason)
	case ActionPush:
		if !nonEmptyText(a.Title, MaxPushTitleBytes) || !nonEmptyText(a.Body, MaxPushBodyBytes) || !actionTextValid(a.Title, MaxPushTitleBytes, false) || !actionTextValid(a.Body, MaxPushBodyBytes, true) || a.Subject != "" || a.MessageHTML != "" || a.Reason != "" || a.Note != "" {
			return reject(false)
		}
		a.Title = strings.TrimSpace(a.Title)
	case ActionRevokeSessions, ActionMarkCompromised, ActionRecoveryResend:
		if !nonEmptyText(a.Reason, 512) || !actionTextValid(a.Reason, 512, false) || a.Subject != "" || a.Body != "" || a.MessageHTML != "" || a.Title != "" || a.Note != "" {
			return reject(false)
		}
		a.Reason = strings.TrimSpace(a.Reason)
	case ActionReportResolve, ActionReportDismiss:
		if a.Subject != "" || a.Body != "" || a.MessageHTML != "" || a.Title != "" || a.Reason != "" || !actionTextValid(a.Note, 2_000, false) {
			return reject(false)
		}
	default:
		return AdminAction{}, ErrInvalidAdminAction
	}
	return a, nil
}

func (a AdminAction) canonicalJSON() ([]byte, error) {
	a, err := a.ValidateAndSanitize()
	if err != nil {
		return nil, err
	}
	type canonicalAction struct {
		Action      string `json:"action"`
		Body        string `json:"body,omitempty"`
		MessageHTML string `json:"messageHtml,omitempty"`
		Subject     string `json:"subject,omitempty"`
		Reason      string `json:"reason,omitempty"`
		Title       string `json:"title,omitempty"`
		Note        string `json:"note,omitempty"`
	}
	out := canonicalAction{Action: a.Kind}
	switch a.Kind {
	case ActionEmail:
		out.Body, out.MessageHTML, out.Subject = a.Body, a.MessageHTML, a.Subject
	case ActionLoginLink:
		out.Reason = a.Reason
	case ActionPush:
		out.Body, out.Title = a.Body, a.Title
	case ActionRevokeSessions, ActionMarkCompromised, ActionRecoveryResend:
		out.Reason = a.Reason
	case ActionReportResolve, ActionReportDismiss:
		out.Note = a.Note
	}
	return json.Marshal(out)
}

func (a AdminAction) CanonicalJSON() ([]byte, error) { return a.canonicalJSON() }

func (a AdminAction) PayloadHashChecked() (string, error) {
	b, err := a.canonicalJSON()
	if err != nil {
		return "", err
	}
	h := sha256.Sum256(b)
	return hex.EncodeToString(h[:]), nil
}

// PayloadHash is the stable hash used in preview/commit bindings. Callers
// should validate the action first; invalid actions return an empty hash.
func (a AdminAction) PayloadHash() string {
	hash, _ := a.PayloadHashChecked()
	return hash
}

func requiresRecentMFA(action string) bool {
	return isSecurityAction(action) || action == ActionReportResolve || action == ActionReportDismiss
}

func actorCanPerform(actor AdminActor, action string, now time.Time, recentMFATTL time.Duration) error {
	if !actor.Valid() {
		return ErrAudienceUnauthorized
	}
	capability := bulkActionCapability(action)
	if capability == "" || !actor.Can(capability) {
		return ErrAudienceForbidden
	}
	if requiresRecentMFA(action) {
		if !RecentMFAValid(actor.RecentMFAAt, now, recentMFATTL) || actor.RecentMFAAction != action {
			return ErrRecentMFARequired
		}
	}
	return nil
}

func allAudienceMFAValid(actor AdminActor, action string, now time.Time, recentMFATTL time.Duration) bool {
	return RecentMFAValid(actor.RecentMFAAt, now, recentMFATTL) && actor.RecentMFAAction == action
}

func audienceIsUnconstrained(audience Audience) bool {
	if audience.Kind == AudienceAll {
		return true
	}
	if audience.Kind != AudienceFilterKind || audience.Filter == nil {
		return false
	}
	filter := audience.Filter
	// IncludeAdmins is an acknowledgement modifier, not a narrowing
	// criterion. A filter containing only that modifier still spans the full
	// resource and therefore receives the all-audience MFA proof.
	return filterCriteriaEmpty(*filter)
}

// AudienceMember is a stable target in a preview. ResourceID is a user ID for
// accounts and a report ID for reports. ExclusionCode is safe enum-like text;
// it must never contain provider or credential data.
type AudienceMember struct {
	ResourceID            uuid.UUID
	Resource              AudienceResource
	Eligible              bool
	ExclusionCode         string
	DeviceCount           int64
	IsAdmin               bool
	EmailEligible         bool
	EmailOptedOut         bool
	PushEligible          bool
	PushOptedOut          bool
	EmailEligibilityKnown bool
	PushEligibilityKnown  bool
	// Ordinal is assigned when a snapshot is materialized and is used only
	// for the opaque snapshot-member cursor.
	Ordinal int64
}

type AudienceSnapshot struct {
	ID             uuid.UUID
	ActorID        uuid.UUID
	Resource       AudienceResource
	Action         AdminAction
	PayloadHash    string
	Audience       Audience
	Status         string
	AccountCount   int64
	EligibleCount  int64
	DeviceCount    int64
	ExclusionCount int64
	ExpiresAt      time.Time
	CreatedAt      time.Time
	UpdatedAt      time.Time
	Members        []AudienceMember
	Exclusions     []AudienceMember
	PendingJobID   uuid.UUID
}

// AudienceSnapshotStore is deliberately count/page based. Implementations
// must evaluate filters in storage and return bounded pages; a full-slice
// ResolveAudience method is intentionally not part of this contract.
type AudienceSnapshotStore interface {
	CountAudience(context.Context, Audience) (int64, error)
	ListAudienceMembers(context.Context, Audience, int64, int) ([]AudienceMember, error)
	SaveAudienceSnapshot(context.Context, AudienceSnapshot) error
	GetAudienceSnapshot(context.Context, uuid.UUID) (*AudienceSnapshot, error)
	ListAudienceSnapshotMembers(context.Context, uuid.UUID, int, int64) ([]AudienceMember, error)
}

type AsyncAudienceMaterializer interface {
	QueueAudienceMaterialization(context.Context, AudienceSnapshot) (uuid.UUID, error)
}

type AudiencePreviewRequest struct {
	Audience Audience
	Action   AdminAction
}

type AudiencePreview struct {
	SnapshotID     uuid.UUID
	ActorID        uuid.UUID
	Resource       AudienceResource
	Action         AdminAction
	PayloadHash    string
	Status         string
	ExpiresAt      time.Time
	AccountCount   int64
	EligibleCount  int64
	DeviceCount    int64
	ExclusionCount int64
	Exclusions     []AudienceMember
	PendingJobID   uuid.UUID
}

type AudiencePage struct {
	Snapshot AudienceSnapshot
	Items    []AudienceMember
	Next     *string
}

type AdminAudienceService struct {
	store            AudienceSnapshotStore
	clock            func() time.Time
	snapshotTTL      time.Duration
	recentMFATTL     time.Duration
	materializeLimit int
}

func NewAdminAudienceService(store AudienceSnapshotStore) *AdminAudienceService {
	return &AdminAudienceService{store: store, clock: time.Now, snapshotTTL: defaultSnapshotTTL, recentMFATTL: 5 * time.Minute, materializeLimit: defaultMaterializeLimit}
}

func NewAdminAudienceServiceWithStore(store AudienceSnapshotStore) *AdminAudienceService {
	return NewAdminAudienceService(store)
}

func (s *AdminAudienceService) SetClock(clock func() time.Time) {
	if s != nil && clock != nil {
		s.clock = clock
	}
}

func (s *AdminAudienceService) SetSnapshotTTL(ttl time.Duration) {
	if s != nil && ttl > 0 {
		s.snapshotTTL = ttl
	}
}

func (s *AdminAudienceService) SetRecentMFATTL(ttl time.Duration) {
	if s != nil && ttl > 0 {
		s.recentMFATTL = ttl
	}
}

func (s *AdminAudienceService) SetMaterializeLimit(limit int) {
	if s != nil && limit > 0 {
		s.materializeLimit = limit
	}
}

func (s *AdminAudienceService) now() time.Time {
	if s == nil || s.clock == nil {
		return time.Now().UTC()
	}
	now := s.clock()
	if now.IsZero() {
		return time.Now().UTC()
	}
	return now.UTC()
}

func (s *AdminAudienceService) resolveBoundedAudience(ctx context.Context, audience Audience) ([]AudienceMember, int64, error) {
	count, err := s.store.CountAudience(ctx, audience)
	if err != nil {
		return nil, 0, err
	}
	if count < 0 {
		return nil, 0, ErrInvalidAudience
	}
	if count == 0 || count > int64(s.materializeLimit) {
		return nil, count, nil
	}
	capacity := int(count)
	members := make([]AudienceMember, 0, capacity)
	var ordinal int64 = -1
	for len(members) < capacity {
		remaining := capacity - len(members)
		pageLimit := minInt(remaining, maxPageLimit)
		page, pageErr := s.store.ListAudienceMembers(ctx, audience, ordinal, pageLimit)
		if pageErr != nil {
			return nil, 0, pageErr
		}
		if len(page) == 0 {
			break
		}
		if len(page) > remaining {
			// A changing resolver must never cause the service to grow beyond
			// its configured materialization bound.
			return nil, 0, ErrAudienceTooLarge
		}
		members = append(members, page...)
		ordinal += int64(len(page))
		if len(page) < pageLimit {
			break
		}
	}
	if int64(len(members)) != count {
		// The count/page pair changed while resolving. Treat it as an unsafe
		// materialization instead of creating a partial immutable snapshot.
		return nil, 0, ErrAudienceTooLarge
	}
	return members, count, nil
}

func (s *AdminAudienceService) Preview(ctx context.Context, actor AdminActor, request AudiencePreviewRequest) (*AudiencePreview, error) {
	if s == nil || s.store == nil {
		return nil, ErrAdminRepositoryAbsent
	}
	request.Audience = request.Audience.Normalize()
	if err := request.Audience.Validate(); err != nil {
		return nil, err
	}
	action, err := request.Action.ValidateAndSanitize()
	if err != nil {
		return nil, err
	}
	if expected := actionResource(action.Kind); expected != request.Audience.Resource {
		return nil, ErrInvalidAudience
	}
	now := s.now()
	if !actor.Valid() {
		return nil, ErrAudienceUnauthorized
	}
	if !actor.Can("audience.preview") {
		return nil, ErrAudienceForbidden
	}
	if err := actorCanPerform(actor, action.Kind, now, s.recentMFATTL); err != nil {
		return nil, err
	}
	if audienceIsUnconstrained(request.Audience) && !allAudienceMFAValid(actor, action.Kind, now, s.recentMFATTL) {
		return nil, ErrRecentMFARequired
	}
	if request.Audience.Filter != nil && request.Audience.Filter.IncludeAdmins && !actor.Can("audience.include_admins") {
		return nil, ErrAudienceForbidden
	}
	members, audienceCount, err := s.resolveBoundedAudience(ctx, request.Audience)
	if err != nil {
		return nil, err
	}
	if audienceCount == 0 {
		return nil, ErrEmptyAudience
	}
	if audienceCount > int64(s.materializeLimit) {
		pending := AudienceSnapshot{ID: uuid.New(), ActorID: actor.ID, Resource: request.Audience.Resource, Action: action, PayloadHash: mustActionHash(action), Audience: cloneAudience(request.Audience), Status: AudienceSnapshotPending, AccountCount: audienceCount, ExpiresAt: now.Add(s.snapshotTTL), CreatedAt: now, UpdatedAt: now}
		async, ok := s.store.(AsyncAudienceMaterializer)
		if !ok {
			return nil, ErrAudienceTooLarge
		}
		jobID, err := async.QueueAudienceMaterialization(ctx, pending)
		if err != nil {
			return nil, err
		}
		pending.PendingJobID = jobID
		return snapshotToPreview(pending, nil), nil
	}
	if len(members) == 0 {
		return nil, ErrEmptyAudience
	}

	// Recheck administrator targets after resolution. A filter/all request may
	// intentionally omit admins; a selected admin requires both capability and
	// acknowledgement and is rejected before a snapshot can be committed.
	includeAdmins := request.Audience.Filter != nil && request.Audience.Filter.IncludeAdmins
	for i := range members {
		if members[i].ResourceID == uuid.Nil || members[i].Resource != request.Audience.Resource {
			return nil, ErrInvalidAudience
		}
		if request.Audience.Resource == AudienceAccounts && members[i].IsAdmin {
			if !includeAdmins {
				if request.Audience.Kind == AudienceSelected {
					return nil, ErrAudienceForbidden
				}
				members[i].Eligible = false
				members[i].ExclusionCode = "admin_target_requires_ack"
			}
			if includeAdmins && !actor.Can("audience.include_admins") {
				return nil, ErrAudienceForbidden
			}
		}
		if request.Audience.Resource == AudienceAccounts && members[i].Eligible {
			switch action.Kind {
			case ActionEmail, ActionLoginLink, ActionRecoveryResend:
				if members[i].EmailOptedOut || (members[i].EmailEligibilityKnown && !members[i].EmailEligible) {
					members[i].Eligible = false
					if members[i].EmailOptedOut {
						members[i].ExclusionCode = "email_opted_out"
					} else {
						members[i].ExclusionCode = "email_ineligible"
					}
				}
			case ActionPush:
				if members[i].PushOptedOut || (members[i].PushEligibilityKnown && !members[i].PushEligible) {
					members[i].Eligible = false
					if members[i].PushOptedOut {
						members[i].ExclusionCode = "push_opted_out"
					} else {
						members[i].ExclusionCode = "push_no_device"
					}
				}
			}
		}
		if !members[i].Eligible && members[i].ExclusionCode == "" {
			members[i].ExclusionCode = "ineligible"
		}
	}
	payloadHash := mustActionHash(action)
	var eligibleCount, deviceCount, exclusionCount int64
	for _, member := range members {
		if member.Eligible {
			eligibleCount++
			if member.DeviceCount > 0 {
				deviceCount += member.DeviceCount
			}
		} else {
			exclusionCount++
		}
	}
	snapshot := AudienceSnapshot{
		ID: uuid.New(), ActorID: actor.ID, Resource: request.Audience.Resource, Action: action,
		PayloadHash: payloadHash, Audience: cloneAudience(request.Audience), Status: AudienceSnapshotReady,
		AccountCount: int64(len(members)), EligibleCount: eligibleCount, DeviceCount: deviceCount,
		ExclusionCount: exclusionCount, ExpiresAt: now.Add(s.snapshotTTL), CreatedAt: now, UpdatedAt: now,
		Members: cloneAudienceMembers(members), Exclusions: cloneAudienceMembers(snapshotExclusions(members)),
	}
	if err := s.store.SaveAudienceSnapshot(ctx, snapshot); err != nil {
		return nil, err
	}
	return snapshotToPreview(snapshot, members), nil
}

func mustActionHash(action AdminAction) string {
	return action.PayloadHash()
}

func cloneAudienceMembers(members []AudienceMember) []AudienceMember {
	return append([]AudienceMember(nil), members...)
}

func snapshotExclusions(members []AudienceMember) []AudienceMember {
	out := make([]AudienceMember, 0, minInt(len(members), maxAudienceExclusions))
	for _, member := range members {
		if member.Eligible {
			continue
		}
		if len(out) == maxAudienceExclusions {
			break
		}
		out = append(out, member)
	}
	return out
}

func minInt(a, b int) int {
	if a < b {
		return a
	}
	return b
}

func snapshotToPreview(snapshot AudienceSnapshot, members []AudienceMember) *AudiencePreview {
	preview := &AudiencePreview{
		SnapshotID: snapshot.ID, ActorID: snapshot.ActorID, Resource: snapshot.Resource, Action: snapshot.Action,
		PayloadHash: snapshot.PayloadHash, Status: snapshot.Status, ExpiresAt: snapshot.ExpiresAt,
		AccountCount: snapshot.AccountCount, EligibleCount: snapshot.EligibleCount, DeviceCount: snapshot.DeviceCount,
		ExclusionCount: snapshot.ExclusionCount, PendingJobID: snapshot.PendingJobID,
	}
	for _, member := range members {
		if !member.Eligible && len(preview.Exclusions) < maxAudienceExclusions {
			preview.Exclusions = append(preview.Exclusions, member)
		}
	}
	return preview
}

func (s *AdminAudienceService) CommitCheck(ctx context.Context, actor AdminActor, snapshotID uuid.UUID, payloadHash string, action AdminAction) error {
	if s == nil || s.store == nil {
		return ErrAdminRepositoryAbsent
	}
	if snapshotID == uuid.Nil || strings.TrimSpace(payloadHash) == "" {
		return ErrSnapshotBinding
	}
	clean, err := action.ValidateAndSanitize()
	if err != nil {
		return err
	}
	now := s.now()
	if !actor.Can("jobs.create") {
		return ErrAudienceForbidden
	}
	if err := actorCanPerform(actor, clean.Kind, now, s.recentMFATTL); err != nil {
		return err
	}
	snapshot, err := s.store.GetAudienceSnapshot(ctx, snapshotID)
	if err != nil {
		return err
	}
	if snapshot == nil {
		return ErrSnapshotNotFound
	}
	if snapshot.ActorID != actor.ID || snapshot.Resource != actionResource(clean.Kind) || snapshot.Status != AudienceSnapshotReady {
		return ErrSnapshotBinding
	}
	if audienceIsUnconstrained(snapshot.Audience) && !allAudienceMFAValid(actor, clean.Kind, now, s.recentMFATTL) {
		return ErrRecentMFARequired
	}
	if !snapshot.ExpiresAt.After(now) {
		return ErrSnapshotExpired
	}
	hash := clean.PayloadHash()
	if hash == "" || !strings.EqualFold(hash, payloadHash) || !strings.EqualFold(hash, snapshot.PayloadHash) || clean.Kind != snapshot.Action.Kind {
		return ErrSnapshotBinding
	}
	return nil
}

func encodeAudienceCursor(ordinal int64) string {
	return base64.RawURLEncoding.EncodeToString([]byte("o:" + strconv.FormatInt(ordinal, 10)))
}

func decodeAudienceCursor(cursor string) (int64, error) {
	if strings.TrimSpace(cursor) == "" {
		return -1, nil
	}
	b, err := base64.RawURLEncoding.DecodeString(cursor)
	if err != nil || !strings.HasPrefix(string(b), "o:") {
		return 0, ErrInvalidAudience
	}
	value, err := strconv.ParseInt(strings.TrimPrefix(string(b), "o:"), 10, 64)
	if err != nil || value < -1 {
		return 0, ErrInvalidAudience
	}
	return value, nil
}

func normalizePage(limit int) (int, error) {
	if limit == 0 {
		return defaultPageLimit, nil
	}
	if limit < 1 || limit > maxPageLimit {
		return 0, ErrInvalidAudience
	}
	return limit, nil
}

func (s *AdminAudienceService) Get(ctx context.Context, actor AdminActor, snapshotID uuid.UUID, cursor string, limit int) (*AudiencePage, error) {
	if s == nil || s.store == nil {
		return nil, ErrAdminRepositoryAbsent
	}
	if !actor.Valid() {
		return nil, ErrAudienceUnauthorized
	}
	if !actor.Can("audience.read") && !actor.Can("audience.read_all") {
		return nil, ErrAudienceForbidden
	}
	limit, err := normalizePage(limit)
	if err != nil {
		return nil, err
	}
	ordinal, err := decodeAudienceCursor(cursor)
	if err != nil {
		return nil, err
	}
	snapshot, err := s.store.GetAudienceSnapshot(ctx, snapshotID)
	if err != nil {
		return nil, err
	}
	if snapshot == nil {
		return nil, ErrSnapshotNotFound
	}
	if snapshot.ActorID != actor.ID && !actor.Can("audience.read_all") {
		return nil, ErrAudienceForbidden
	}
	if !snapshot.ExpiresAt.After(s.now()) {
		return nil, ErrSnapshotExpired
	}
	items, err := s.store.ListAudienceSnapshotMembers(ctx, snapshotID, limit+1, ordinal)
	if err != nil {
		return nil, err
	}
	var next *string
	if len(items) > limit {
		items = items[:limit]
		if len(items) > 0 {
			// Snapshot stores return the contiguous ordinal page after the
			// requested ordinal. Deriving the cursor from the request keeps the
			// wire contract stable even when a DB adapter omits the internal
			// ordinal from its transport projection.
			value := encodeAudienceCursor(ordinal + int64(len(items)))
			next = &value
		}
	}
	return &AudiencePage{Snapshot: *snapshot, Items: items, Next: next}, nil
}

// MemoryAdminStore is a deterministic test and local-development store. It
// implements the same immutable snapshot semantics expected from the DB
// adapter. Production composition can provide a PostgreSQL implementation
// through AudienceSnapshotStore without changing this service.
type MemoryAdminStore struct {
	mu           sync.RWMutex
	Users        []AdminUser
	Reports      []AudienceRecord
	Snapshots    map[uuid.UUID]AudienceSnapshot
	Jobs         map[uuid.UUID]AdminJob
	JobItems     map[uuid.UUID][]AdminJobItem
	Audit        []AdminAuditEvent
	Commands     map[string]AdminJobCommand
	jobAuditKeys map[string]struct{}
}

type AudienceRecord struct {
	ID             uuid.UUID
	Resource       AudienceResource
	Username       string
	Email          *string
	EmailVerified  bool
	SecurityState  string
	CreatedAt      time.Time
	IsAdmin        bool
	Eligible       bool
	ExclusionCode  string
	DeviceCount    int64
	EmailOptedOut  bool
	PushOptedOut   bool
	AssigneeUserID *uuid.UUID
	ReportStatus   string
	ReportType     string
}

func NewMemoryAdminStore() *MemoryAdminStore {
	return &MemoryAdminStore{Snapshots: make(map[uuid.UUID]AudienceSnapshot), Jobs: make(map[uuid.UUID]AdminJob), JobItems: make(map[uuid.UUID][]AdminJobItem), Commands: make(map[string]AdminJobCommand), jobAuditKeys: make(map[string]struct{})}
}

func memoryAudienceRecord(user AdminUser) AudienceRecord {
	state := user.SecurityState
	if state == "" {
		state = "normal"
	}
	return AudienceRecord{ID: user.ID, Resource: AudienceAccounts, Username: user.Username, Email: user.Email, EmailVerified: user.EmailVerified, SecurityState: state, CreatedAt: user.CreatedAt, IsAdmin: user.IsAdmin, Eligible: len(user.EligibilityReasons) == 0, DeviceCount: int64(user.RegisteredDeviceCount), ExclusionCode: firstReason(user.EligibilityReasons), EmailOptedOut: user.CommunicationOptOut, PushOptedOut: user.CommunicationOptOut || user.PushOptedOut}
}

func audienceMemberFromRecord(record AudienceRecord) AudienceMember {
	eligible := record.Eligible
	// Memory report fixtures commonly omit eligibility because report records
	// are actionable by default; an explicit exclusion still wins.
	if record.Resource == AudienceReports && !eligible && record.ExclusionCode == "" {
		eligible = true
	}
	exclusionCode := ""
	if !eligible {
		exclusionCode = safeReason(record.ExclusionCode)
	}
	return AudienceMember{ResourceID: record.ID, Resource: record.Resource, Eligible: eligible, ExclusionCode: exclusionCode, DeviceCount: maxInt64Local(record.DeviceCount, 0), IsAdmin: record.IsAdmin, EmailEligible: record.Email != nil && record.EmailVerified, EmailOptedOut: record.EmailOptedOut, PushEligible: record.DeviceCount > 0, PushOptedOut: record.PushOptedOut, EmailEligibilityKnown: record.Resource == AudienceAccounts, PushEligibilityKnown: record.Resource == AudienceAccounts}
}

func audienceRecordIncluded(record AudienceRecord, audience Audience) bool {
	if record.ID == uuid.Nil || record.Resource != audience.Resource {
		return false
	}
	switch audience.Kind {
	case AudienceAll:
		return true
	case AudienceFilterKind:
		return audience.Filter != nil && recordMatchesFilter(record, *audience.Filter)
	default:
		return false
	}
}

// CountAudience evaluates a scope without allocating a result slice so
// production stores can expose only bounded count/page operations.
func (m *MemoryAdminStore) CountAudience(_ context.Context, audience Audience) (int64, error) {
	if m == nil {
		return 0, ErrAdminRepositoryAbsent
	}
	audience = audience.Normalize()
	if err := audience.Validate(); err != nil {
		return 0, err
	}
	if audience.Kind == AudienceSelected {
		return int64(len(audience.IDs)), nil
	}
	m.mu.RLock()
	defer m.mu.RUnlock()
	var count int64
	if audience.Resource == AudienceAccounts {
		for _, user := range m.Users {
			if audienceRecordIncluded(memoryAudienceRecord(user), audience) {
				count++
			}
		}
		return count, nil
	}
	for _, record := range m.Reports {
		if audienceRecordIncluded(record, audience) {
			count++
		}
	}
	return count, nil
}

func (m *MemoryAdminStore) nextAudienceRecord(audience Audience, last uuid.UUID) (AudienceRecord, bool) {
	var best AudienceRecord
	found := false
	consider := func(record AudienceRecord) {
		if !audienceRecordIncluded(record, audience) || (last != uuid.Nil && record.ID.String() <= last.String()) {
			return
		}
		if !found || record.ID.String() < best.ID.String() {
			best, found = record, true
		}
	}
	if audience.Resource == AudienceAccounts {
		for _, user := range m.Users {
			consider(memoryAudienceRecord(user))
		}
	} else {
		for _, record := range m.Reports {
			consider(record)
		}
	}
	return best, found
}

// ListAudienceMembers returns one bounded page in stable UUID order. The
// in-memory implementation repeatedly selects the next record to avoid making
// a temporary slice proportional to the audience; a database adapter should
// use ORDER BY plus a keyset/ordinal cursor instead.
func (m *MemoryAdminStore) ListAudienceMembers(_ context.Context, audience Audience, afterOrdinal int64, limit int) ([]AudienceMember, error) {
	if m == nil {
		return nil, ErrAdminRepositoryAbsent
	}
	audience = audience.Normalize()
	if err := audience.Validate(); err != nil {
		return nil, err
	}
	if limit < 1 || limit > maxPageLimit || afterOrdinal < -1 {
		return nil, ErrInvalidAudience
	}
	m.mu.RLock()
	defer m.mu.RUnlock()
	items := make([]AudienceMember, 0, limit)
	if audience.Kind == AudienceSelected {
		ids := append([]uuid.UUID(nil), audience.IDs...)
		sort.Slice(ids, func(i, j int) bool { return ids[i].String() < ids[j].String() })
		start := afterOrdinal + 1
		if start < 0 {
			start = 0
		}
		for ordinal := start; ordinal < int64(len(ids)) && len(items) < limit; ordinal++ {
			id := ids[ordinal]
			member := AudienceMember{ResourceID: id, Resource: audience.Resource, Eligible: false, ExclusionCode: "not_found", Ordinal: ordinal}
			if audience.Resource == AudienceAccounts {
				for _, user := range m.Users {
					if user.ID == id {
						member = audienceMemberFromRecord(memoryAudienceRecord(user))
						member.Ordinal = ordinal
						break
					}
				}
			} else {
				for _, record := range m.Reports {
					if record.ID == id {
						member = audienceMemberFromRecord(record)
						member.Ordinal = ordinal
						break
					}
				}
			}
			items = append(items, member)
		}
		return items, nil
	}
	last := uuid.Nil
	ordinal := int64(-1)
	for len(items) < limit {
		record, found := m.nextAudienceRecord(audience, last)
		if !found {
			break
		}
		last = record.ID
		ordinal++
		if ordinal <= afterOrdinal {
			continue
		}
		member := audienceMemberFromRecord(record)
		member.Ordinal = ordinal
		items = append(items, member)
	}
	return items, nil
}

func firstReason(reasons []string) string {
	if len(reasons) == 0 {
		return ""
	}
	return safeReason(reasons[0])
}

func safeReason(value string) string {
	value = strings.TrimSpace(value)
	if value == "" || !validUTF8(value) || len(value) > 64 || strings.ContainsAny(value, "\r\n\x00") {
		return "ineligible"
	}
	return value
}

func safeOptionalReason(value string) string {
	value = strings.TrimSpace(value)
	if value == "" || !validUTF8(value) || len(value) > 64 || strings.ContainsAny(value, "\r\n\x00") {
		return ""
	}
	return value
}

func maxInt64Local(value, minimum int64) int64 {
	if value < minimum {
		return minimum
	}
	return value
}

func recordMatchesFilter(record AudienceRecord, filter AudienceFilter) bool {
	if filter.Resource != record.Resource {
		return false
	}
	if filter.Resource == AudienceAccounts {
		if filter.Username != nil && !strings.Contains(strings.ToLower(record.Username), strings.ToLower(strings.TrimSpace(*filter.Username))) {
			return false
		}
		if filter.Email != nil && (record.Email == nil || !strings.Contains(strings.ToLower(*record.Email), strings.ToLower(strings.TrimSpace(*filter.Email)))) {
			return false
		}
		if filter.ID != nil && !strings.Contains(record.ID.String(), strings.TrimSpace(*filter.ID)) {
			return false
		}
		if filter.VerifiedEmail != nil && record.EmailVerified != *filter.VerifiedEmail {
			return false
		}
		if len(filter.SecurityStatuses) > 0 && !containsValue(filter.SecurityStatuses, record.SecurityState) {
			return false
		}
	} else {
		if filter.AssigneeUserID != nil && (record.AssigneeUserID == nil || *record.AssigneeUserID != *filter.AssigneeUserID) {
			return false
		}
		if len(filter.Statuses) > 0 && !containsValue(filter.Statuses, record.ReportStatus) {
			return false
		}
		if len(filter.Types) > 0 && !containsValueFold(filter.Types, record.ReportType) {
			return false
		}
	}
	if filter.CreatedAfter != nil && record.CreatedAt.Before(*filter.CreatedAfter) {
		return false
	}
	if filter.CreatedBefore != nil && !record.CreatedAt.Before(*filter.CreatedBefore) {
		return false
	}
	return true
}

func containsValue(values []string, want string) bool {
	for _, value := range values {
		if value == want {
			return true
		}
	}
	return false
}

func containsValueFold(values []string, want string) bool {
	for _, value := range values {
		if strings.EqualFold(value, want) {
			return true
		}
	}
	return false
}

func (m *MemoryAdminStore) SaveAudienceSnapshot(_ context.Context, snapshot AudienceSnapshot) error {
	if m == nil || snapshot.ID == uuid.Nil || snapshot.ActorID == uuid.Nil || snapshot.ExpiresAt.IsZero() || snapshot.Status == "" {
		return ErrInvalidAudience
	}
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.Snapshots == nil {
		m.Snapshots = make(map[uuid.UUID]AudienceSnapshot)
	}
	if _, exists := m.Snapshots[snapshot.ID]; exists {
		return ErrSnapshotBinding
	}
	snapshot.Members = cloneAudienceMembers(snapshot.Members)
	snapshot.Exclusions = cloneAudienceMembers(snapshot.Exclusions)
	snapshot.Audience = cloneAudience(snapshot.Audience)
	for i := range snapshot.Members {
		snapshot.Members[i].Ordinal = int64(i)
	}
	m.Snapshots[snapshot.ID] = snapshot
	return nil
}

func (m *MemoryAdminStore) GetAudienceSnapshot(_ context.Context, id uuid.UUID) (*AudienceSnapshot, error) {
	if m == nil {
		return nil, ErrAdminRepositoryAbsent
	}
	m.mu.RLock()
	defer m.mu.RUnlock()
	snapshot, ok := m.Snapshots[id]
	if !ok {
		return nil, nil
	}
	snapshot.Members = cloneAudienceMembers(snapshot.Members)
	snapshot.Exclusions = cloneAudienceMembers(snapshot.Exclusions)
	snapshot.Audience = cloneAudience(snapshot.Audience)
	return &snapshot, nil
}

func (m *MemoryAdminStore) ListAudienceSnapshotMembers(_ context.Context, id uuid.UUID, limit int, afterOrdinal int64) ([]AudienceMember, error) {
	if m == nil || limit <= 0 || afterOrdinal < -1 {
		return nil, ErrInvalidAudience
	}
	m.mu.RLock()
	snapshot, ok := m.Snapshots[id]
	m.mu.RUnlock()
	if !ok {
		return nil, nil
	}
	start := afterOrdinal + 1
	if start < 0 {
		start = 0
	}
	if start >= int64(len(snapshot.Members)) {
		return []AudienceMember{}, nil
	}
	end := start + int64(limit)
	if end > int64(len(snapshot.Members)) {
		end = int64(len(snapshot.Members))
	}
	return cloneAudienceMembers(snapshot.Members[start:end]), nil
}

// ErrMeaningfulAudienceStore is retained as a compile-time hint for DB
// owners: these service contracts require a single transaction around the
// snapshot row and all member rows.
var ErrMeaningfulAudienceStore = errors.New("audience store must atomically save snapshot members")

func (s AudienceSnapshot) String() string {
	return fmt.Sprintf("audience snapshot %s (%s)", s.ID, s.Status)
}
