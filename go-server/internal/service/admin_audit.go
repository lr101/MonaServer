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
	ErrInvalidAuditQuery = apperrors.New(http.StatusBadRequest, "invalid audit query")
	ErrAuditNotFound     = apperrors.New(http.StatusNotFound, "audit event was not found")
)

// AdminAuditEvent is the secret-free audit projection. Details are always
// copied and redacted before crossing this service boundary.
type AdminAuditEvent struct {
	ID         uuid.UUID
	ActorID    *uuid.UUID
	TargetID   *uuid.UUID
	Action     string
	Outcome    string
	Reason     *string
	Details    map[string]string
	OccurredAt time.Time
}

type AdminAuditQuery struct {
	Cursor   string
	Limit    int
	TargetID *uuid.UUID
	Action   string
}

type AdminAuditPage struct {
	Items []AdminAuditEvent
	Next  *string
}

type AdminAuditStore interface {
	ListAudit(context.Context, AdminAuditQuery) (AdminAuditPage, error)
	AppendAudit(context.Context, AdminAuditEvent) error
}

type AdminAuditService struct {
	store AdminAuditStore
}

func NewAdminAuditService(store AdminAuditStore) *AdminAuditService {
	return &AdminAuditService{store: store}
}

func NewAdminAuditLogService(store AdminAuditStore) *AdminAuditService {
	return NewAdminAuditService(store)
}

func normalizeAuditQuery(query AdminAuditQuery) (AdminAuditQuery, error) {
	if query.Limit == 0 {
		query.Limit = defaultPageLimit
	}
	if query.Limit < 1 || query.Limit > maxPageLimit || len([]byte(query.Action)) > 64 || !utf8OrEmpty(query.Action) {
		return AdminAuditQuery{}, ErrInvalidAuditQuery
	}
	query.Action = strings.TrimSpace(query.Action)
	if query.Cursor != "" {
		if _, err := decodeAuditCursor(query.Cursor); err != nil {
			return AdminAuditQuery{}, err
		}
	}
	return query, nil
}

func utf8OrEmpty(value string) bool {
	return value == "" || validUTF8(value)
}

func (s *AdminAuditService) List(ctx context.Context, actor AdminActor, cursor string, limit int, targetID, action string) (*AdminAuditPage, error) {
	if s == nil || s.store == nil {
		return nil, ErrAdminRepositoryAbsent
	}
	if !actor.Valid() {
		return nil, ErrAudienceUnauthorized
	}
	if !actor.Can("audit.read") {
		return nil, ErrAudienceForbidden
	}
	var target *uuid.UUID
	if strings.TrimSpace(targetID) != "" {
		id, err := uuid.Parse(strings.TrimSpace(targetID))
		if err != nil || id == uuid.Nil {
			return nil, ErrInvalidAuditQuery
		}
		target = &id
	}
	query, err := normalizeAuditQuery(AdminAuditQuery{Cursor: cursor, Limit: limit, TargetID: target, Action: action})
	if err != nil {
		return nil, err
	}
	page, err := s.store.ListAudit(ctx, query)
	if err != nil {
		return nil, err
	}
	for i := range page.Items {
		page.Items[i] = redactAuditEvent(page.Items[i])
	}
	return &page, nil
}

// Append records an internal administrative operation with the supplied
// actor bound by the service. Callers cannot forge a different actor by
// placing one in the event value, and all metadata is redacted before it
// reaches the persistence boundary.
func (s *AdminAuditService) Append(ctx context.Context, actor AdminActor, event AdminAuditEvent) error {
	if s == nil || s.store == nil {
		return ErrAdminRepositoryAbsent
	}
	if !actor.Valid() {
		return ErrAudienceUnauthorized
	}
	if event.ID == uuid.Nil {
		event.ID = uuid.New()
	}
	event.ActorID = &actor.ID
	if event.OccurredAt.IsZero() {
		event.OccurredAt = time.Now().UTC()
	}
	if event.Action == "" || len([]byte(event.Action)) > 64 || !validUTF8(event.Action) || strings.ContainsAny(event.Action, "\r\n\x00") || len([]byte(event.Outcome)) > 64 || !validUTF8(event.Outcome) || strings.ContainsAny(event.Outcome, "\r\n\x00") {
		return ErrInvalidAuditQuery
	}
	return s.store.AppendAudit(ctx, redactAuditEvent(event))
}

// Record is a descriptive alias used by operation services that call the
// append-only audit boundary.
func (s *AdminAuditService) Record(ctx context.Context, actor AdminActor, event AdminAuditEvent) error {
	return s.Append(ctx, actor, event)
}

func redactAuditEvent(event AdminAuditEvent) AdminAuditEvent {
	event.Action = safeOptionalReason(event.Action)
	event.Outcome = safeOptionalReason(event.Outcome)
	if event.Action == "" {
		event.Action = "unknown"
	}
	if event.Outcome == "" {
		event.Outcome = "unknown"
	}
	if event.ActorID != nil {
		actorID := *event.ActorID
		event.ActorID = &actorID
	}
	if event.TargetID != nil {
		targetID := *event.TargetID
		event.TargetID = &targetID
	}
	event.Details = redactAuditDetails(event.Details)
	event.Reason = boundedAuditString(event.Reason, 2_000)
	return event
}

func boundedAuditString(value *string, max int) *string {
	if value == nil || !validUTF8(*value) || len([]byte(*value)) > max || strings.ContainsAny(*value, "\r\n\x00") {
		return nil
	}
	copy := strings.TrimSpace(*value)
	return &copy
}

func redactAuditDetails(details map[string]string) map[string]string {
	if len(details) == 0 {
		return map[string]string{}
	}
	keys := make([]string, 0, len(details))
	for key := range details {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	out := make(map[string]string, len(keys))
	for _, key := range keys {
		if len(out) >= 50 {
			break
		}
		cleanKey := strings.TrimSpace(key)
		if cleanKey == "" || len([]byte(cleanKey)) > 64 || !validUTF8(cleanKey) || strings.ContainsAny(cleanKey, "\r\n\x00") {
			continue
		}
		value := details[key]
		if isSecretAuditField(cleanKey) || looksLikeSecret(value) {
			out[cleanKey] = "[redacted]"
			continue
		}
		if !validUTF8(value) || strings.ContainsAny(value, "\r\n\x00") {
			out[cleanKey] = "[redacted]"
			continue
		}
		if len([]byte(value)) > 256 {
			value = truncateAuditUTF8(value, 256)
		}
		out[cleanKey] = value
	}
	return out
}

func truncateAuditUTF8(value string, maxBytes int) string {
	if maxBytes <= 0 || len([]byte(value)) <= maxBytes {
		return value
	}
	value = value[:maxBytes]
	for len(value) > 0 && !validUTF8(value) {
		value = value[:len(value)-1]
	}
	return value
}

func isSecretAuditField(key string) bool {
	key = strings.ToLower(strings.TrimSpace(key))
	for _, word := range []string{"token", "password", "secret", "credential", "authorization", "bearer", "cookie", "payload", "html"} {
		if strings.Contains(key, word) {
			return true
		}
	}
	return false
}

func looksLikeSecret(value string) bool {
	lower := strings.ToLower(value)
	for _, marker := range []string{"bearer ", "password=", "token=", "secret=", "-----begin ", "eyj"} {
		if strings.Contains(lower, marker) {
			return true
		}
	}
	return false
}

func encodeAuditCursor(id uuid.UUID) string {
	return base64.RawURLEncoding.EncodeToString([]byte("a:" + id.String()))
}

func decodeAuditCursor(cursor string) (uuid.UUID, error) {
	b, err := base64.RawURLEncoding.DecodeString(cursor)
	if err != nil || !strings.HasPrefix(string(b), "a:") {
		return uuid.Nil, ErrInvalidAuditQuery
	}
	id, err := uuid.Parse(strings.TrimPrefix(string(b), "a:"))
	if err != nil || id == uuid.Nil {
		return uuid.Nil, ErrInvalidAuditQuery
	}
	return id, nil
}

func (m *MemoryAdminStore) AppendAudit(_ context.Context, event AdminAuditEvent) error {
	if m == nil || event.ID == uuid.Nil || event.Action == "" || event.OccurredAt.IsZero() {
		return ErrInvalidAuditQuery
	}
	m.mu.Lock()
	defer m.mu.Unlock()
	event = redactAuditEvent(event)
	m.Audit = append(m.Audit, event)
	return nil
}

// RecordJobItemAudit is the in-memory equivalent of the durable finish/outbox
// transaction. The composite key makes retries and outbox replays idempotent.
func (m *MemoryAdminStore) RecordJobItemAudit(_ context.Context, item AdminJobItemAudit) error {
	if m == nil || item.JobID == uuid.Nil || item.ItemID == uuid.Nil || item.ActorID == uuid.Nil || item.TargetID == uuid.Nil || !validOutcome(item.Outcome) || item.Action == "" {
		return ErrInvalidAuditQuery
	}
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.jobAuditKeys == nil {
		m.jobAuditKeys = make(map[string]struct{})
	}
	key := item.JobID.String() + ":" + item.ItemID.String() + ":" + item.Outcome
	if _, exists := m.jobAuditKeys[key]; exists {
		return nil
	}
	m.jobAuditKeys[key] = struct{}{}
	actorID, targetID := item.ActorID, item.TargetID
	var reason *string
	if cleaned := safeOptionalReason(item.Reason); cleaned != "" {
		reason = &cleaned
	}
	details := map[string]string{"job_id": item.JobID.String(), "item_id": item.ItemID.String()}
	if item.OperationID != uuid.Nil {
		details["operation_id"] = item.OperationID.String()
	}
	if item.ErrorCode != "" {
		details["error_code"] = safeErrorCode(item.ErrorCode)
	}
	m.Audit = append(m.Audit, redactAuditEvent(AdminAuditEvent{ID: uuid.New(), ActorID: &actorID, TargetID: &targetID, Action: item.Action, Outcome: item.Outcome, Reason: reason, Details: details, OccurredAt: time.Now().UTC()}))
	return nil
}

func (m *MemoryAdminStore) ListAudit(_ context.Context, query AdminAuditQuery) (AdminAuditPage, error) {
	if m == nil {
		return AdminAuditPage{}, ErrAdminRepositoryAbsent
	}
	query, err := normalizeAuditQuery(query)
	if err != nil {
		return AdminAuditPage{}, err
	}
	var after uuid.UUID
	if query.Cursor != "" {
		after, err = decodeAuditCursor(query.Cursor)
		if err != nil {
			return AdminAuditPage{}, err
		}
	}
	m.mu.RLock()
	events := append([]AdminAuditEvent(nil), m.Audit...)
	m.mu.RUnlock()
	sort.Slice(events, func(i, j int) bool {
		if events[i].OccurredAt.Equal(events[j].OccurredAt) {
			return events[i].ID.String() > events[j].ID.String()
		}
		return events[i].OccurredAt.After(events[j].OccurredAt)
	})
	filtered := make([]AdminAuditEvent, 0, len(events))
	seenCursor := after == uuid.Nil
	for _, event := range events {
		if !seenCursor {
			if event.ID == after {
				seenCursor = true
			}
			continue
		}
		if query.TargetID != nil && (event.TargetID == nil || *event.TargetID != *query.TargetID) {
			continue
		}
		if query.Action != "" && event.Action != query.Action {
			continue
		}
		filtered = append(filtered, event)
	}
	page := AdminAuditPage{Items: append([]AdminAuditEvent(nil), filtered...)}
	if len(page.Items) > query.Limit {
		page.Items = page.Items[:query.Limit]
		cursor := encodeAuditCursor(page.Items[len(page.Items)-1].ID)
		page.Next = &cursor
	}
	return page, nil
}
