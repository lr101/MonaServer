package service

import (
	"context"
	"encoding/base64"
	"net/http"
	"sort"
	"strings"
	"sync"
	"time"
	"unicode/utf8"

	"github.com/google/uuid"

	"github.com/lrprojects/monaserver/internal/apperrors"
)

const (
	MaxCampaignNameBytes    = 200
	MaxCampaignSubjectBytes = 200
	MaxCampaignTitleBytes   = 200
	MaxCampaignBodyBytes    = 10_000
	MaxCampaignCursorBytes  = 512
)

const (
	CampaignChannelEmail CampaignChannel = "email"
	CampaignChannelPush  CampaignChannel = "push"

	CampaignStatusDraft    CampaignStatus = "draft"
	CampaignStatusActive   CampaignStatus = "active"
	CampaignStatusArchived CampaignStatus = "archived"
)

var ErrInvalidCampaign = apperrors.New(http.StatusBadRequest, "invalid campaign")

type CampaignChannel string
type CampaignStatus string

// Campaign is a content record only. It intentionally has no audience,
// schedule, provider, job, recipient, or delivery state.
type Campaign struct {
	ID              uuid.UUID
	Name            string
	Channel         CampaignChannel
	Subject         *string
	Title           *string
	Body            string
	Status          CampaignStatus
	Revision        int64
	CreatedAt       time.Time
	UpdatedAt       time.Time
	CreatedByUserID uuid.UUID
}

type CampaignCreateInput struct {
	Name    string
	Channel CampaignChannel
	Subject *string
	Title   *string
	Body    string
	Status  CampaignStatus
}

type CampaignUpdateInput struct {
	CampaignID       uuid.UUID
	ExpectedRevision int64
	Name             string
	Channel          CampaignChannel
	Subject          *string
	Title            *string
	Body             string
	Status           CampaignStatus
}

type CampaignRevisionInput struct {
	CampaignID       uuid.UUID
	ExpectedRevision int64
}

type CampaignListRequest struct {
	Cursor string
	Limit  int
}

type CampaignListQuery struct {
	BeforeCreatedAt *time.Time
	BeforeID        *uuid.UUID
	Limit           int
}

type CampaignPage struct {
	Items      []Campaign
	NextCursor *string
}

// CampaignStore keeps revision-sensitive persistence behind a small boundary.
// Implementations must make the update/delete predicates atomic.
type CampaignStore interface {
	ListCampaigns(context.Context, CampaignListQuery) ([]Campaign, error)
	GetCampaign(context.Context, uuid.UUID) (*Campaign, error)
	CreateCampaign(context.Context, Campaign) (*Campaign, error)
	UpdateCampaignIfRevision(context.Context, Campaign, int64) (*Campaign, bool, error)
	DeleteCampaignIfRevision(context.Context, uuid.UUID, int64) (bool, error)
}

type CampaignService struct {
	store CampaignStore
	now   func() time.Time
}

func NewCampaignService(store CampaignStore) *CampaignService {
	return &CampaignService{store: store, now: time.Now}
}

func (s *CampaignService) List(ctx context.Context, actor AdminActor, request CampaignListRequest) (*CampaignPage, error) {
	if err := s.require(actor, "campaigns.read"); err != nil {
		return nil, err
	}
	if request.Limit == 0 {
		request.Limit = defaultPageLimit
	}
	if request.Limit < 1 || request.Limit > maxPageLimit || len(request.Cursor) > MaxCampaignCursorBytes {
		return nil, ErrInvalidCampaign
	}
	query := CampaignListQuery{Limit: request.Limit + 1}
	if request.Cursor != "" {
		createdAt, id, err := decodeCampaignCursor(request.Cursor)
		if err != nil {
			return nil, err
		}
		query.BeforeCreatedAt, query.BeforeID = &createdAt, &id
	}
	items, err := s.store.ListCampaigns(ctx, query)
	if err != nil {
		return nil, err
	}
	page := &CampaignPage{Items: append([]Campaign(nil), items...)}
	if len(page.Items) > request.Limit {
		page.Items = page.Items[:request.Limit]
		cursor, err := encodeCampaignCursor(page.Items[len(page.Items)-1])
		if err != nil {
			return nil, err
		}
		page.NextCursor = &cursor
	}
	if page.Items == nil {
		page.Items = []Campaign{}
	}
	return page, nil
}

func (s *CampaignService) Get(ctx context.Context, actor AdminActor, id uuid.UUID) (*Campaign, error) {
	if err := s.require(actor, "campaigns.read"); err != nil {
		return nil, err
	}
	if id == uuid.Nil {
		return nil, ErrInvalidCampaign
	}
	campaign, err := s.store.GetCampaign(ctx, id)
	if err != nil {
		return nil, err
	}
	if campaign == nil {
		return nil, apperrors.ErrNotFound
	}
	return cloneCampaign(*campaign), nil
}

func (s *CampaignService) Create(ctx context.Context, actor AdminActor, input CampaignCreateInput) (*Campaign, error) {
	if err := s.require(actor, "campaigns.write"); err != nil {
		return nil, err
	}
	if err := validateCampaignContent(input.Name, input.Channel, input.Subject, input.Title, input.Body); err != nil || !isMutableCampaignStatus(input.Status) {
		return nil, ErrInvalidCampaign
	}
	now := s.now().UTC()
	return s.store.CreateCampaign(ctx, Campaign{
		ID: uuid.New(), Name: strings.TrimSpace(input.Name), Channel: input.Channel, Subject: cloneCampaignString(input.Subject), Title: cloneCampaignString(input.Title),
		Body: strings.TrimSpace(input.Body), Status: input.Status, Revision: 1, CreatedAt: now, UpdatedAt: now, CreatedByUserID: actor.ID,
	})
}

func (s *CampaignService) Update(ctx context.Context, actor AdminActor, input CampaignUpdateInput) (*Campaign, error) {
	if err := s.require(actor, "campaigns.write"); err != nil {
		return nil, err
	}
	if input.CampaignID == uuid.Nil || input.ExpectedRevision < 1 || !isMutableCampaignStatus(input.Status) || validateCampaignContent(input.Name, input.Channel, input.Subject, input.Title, input.Body) != nil {
		return nil, ErrInvalidCampaign
	}
	current, err := s.store.GetCampaign(ctx, input.CampaignID)
	if err != nil {
		return nil, err
	}
	if current == nil {
		return nil, apperrors.ErrNotFound
	}
	if current.Status == CampaignStatusArchived || current.Revision != input.ExpectedRevision {
		return nil, apperrors.ErrConflict
	}
	updated, ok, err := s.store.UpdateCampaignIfRevision(ctx, Campaign{
		ID: current.ID, Name: strings.TrimSpace(input.Name), Channel: input.Channel, Subject: cloneCampaignString(input.Subject), Title: cloneCampaignString(input.Title),
		Body: strings.TrimSpace(input.Body), Status: input.Status, Revision: input.ExpectedRevision + 1, CreatedAt: current.CreatedAt, UpdatedAt: s.now().UTC(), CreatedByUserID: current.CreatedByUserID,
	}, input.ExpectedRevision)
	if err != nil {
		return nil, err
	}
	if !ok {
		return nil, s.conflictOrNotFound(ctx, input.CampaignID)
	}
	return updated, nil
}

func (s *CampaignService) Archive(ctx context.Context, actor AdminActor, input CampaignRevisionInput) (*Campaign, error) {
	if err := s.require(actor, "campaigns.write"); err != nil {
		return nil, err
	}
	if input.CampaignID == uuid.Nil || input.ExpectedRevision < 1 {
		return nil, ErrInvalidCampaign
	}
	current, err := s.store.GetCampaign(ctx, input.CampaignID)
	if err != nil {
		return nil, err
	}
	if current == nil {
		return nil, apperrors.ErrNotFound
	}
	if current.Status == CampaignStatusArchived || current.Revision != input.ExpectedRevision {
		return nil, apperrors.ErrConflict
	}
	updated := cloneCampaign(*current)
	updated.Status, updated.Revision, updated.UpdatedAt = CampaignStatusArchived, input.ExpectedRevision+1, s.now().UTC()
	result, ok, err := s.store.UpdateCampaignIfRevision(ctx, *updated, input.ExpectedRevision)
	if err != nil {
		return nil, err
	}
	if !ok {
		return nil, s.conflictOrNotFound(ctx, input.CampaignID)
	}
	return result, nil
}

func (s *CampaignService) Delete(ctx context.Context, actor AdminActor, input CampaignRevisionInput) error {
	if err := s.require(actor, "campaigns.write"); err != nil {
		return err
	}
	if input.CampaignID == uuid.Nil || input.ExpectedRevision < 1 {
		return ErrInvalidCampaign
	}
	current, err := s.store.GetCampaign(ctx, input.CampaignID)
	if err != nil {
		return err
	}
	if current == nil {
		return apperrors.ErrNotFound
	}
	if current.Status != CampaignStatusDraft || current.Revision != input.ExpectedRevision {
		return apperrors.ErrConflict
	}
	ok, err := s.store.DeleteCampaignIfRevision(ctx, input.CampaignID, input.ExpectedRevision)
	if err != nil {
		return err
	}
	if !ok {
		return s.conflictOrNotFound(ctx, input.CampaignID)
	}
	return nil
}

func (s *CampaignService) require(actor AdminActor, capability string) error {
	if s == nil || s.store == nil {
		return ErrAdminRepositoryAbsent
	}
	if !actor.Valid() {
		return ErrAudienceUnauthorized
	}
	if !actor.Can(capability) {
		return ErrAudienceForbidden
	}
	return nil
}

func (s *CampaignService) conflictOrNotFound(ctx context.Context, id uuid.UUID) error {
	current, err := s.store.GetCampaign(ctx, id)
	if err != nil {
		return err
	}
	if current == nil {
		return apperrors.ErrNotFound
	}
	return apperrors.ErrConflict
}

func validateCampaignContent(name string, channel CampaignChannel, subject, title *string, body string) error {
	if !campaignText(name, MaxCampaignNameBytes) || !campaignText(body, MaxCampaignBodyBytes) {
		return ErrInvalidCampaign
	}
	switch channel {
	case CampaignChannelEmail:
		if !campaignOptionalText(subject, MaxCampaignSubjectBytes) || title != nil {
			return ErrInvalidCampaign
		}
	case CampaignChannelPush:
		if !campaignOptionalText(title, MaxCampaignTitleBytes) || subject != nil {
			return ErrInvalidCampaign
		}
	default:
		return ErrInvalidCampaign
	}
	return nil
}

func campaignText(value string, limit int) bool {
	value = strings.TrimSpace(value)
	return value != "" && len([]byte(value)) <= limit && utf8.ValidString(value) && !strings.ContainsRune(value, 0)
}

func campaignOptionalText(value *string, limit int) bool {
	return value != nil && campaignText(*value, limit)
}

func isMutableCampaignStatus(status CampaignStatus) bool {
	return status == CampaignStatusDraft || status == CampaignStatusActive
}

func encodeCampaignCursor(campaign Campaign) (string, error) {
	if campaign.ID == uuid.Nil || campaign.CreatedAt.IsZero() {
		return "", ErrInvalidCampaign
	}
	value := base64.RawURLEncoding.EncodeToString([]byte("c:" + campaign.CreatedAt.UTC().Format(time.RFC3339Nano) + ":" + campaign.ID.String()))
	if len(value) > MaxCampaignCursorBytes {
		return "", ErrInvalidCampaign
	}
	return value, nil
}

func decodeCampaignCursor(value string) (time.Time, uuid.UUID, error) {
	if value == "" || len(value) > MaxCampaignCursorBytes {
		return time.Time{}, uuid.Nil, ErrInvalidCampaign
	}
	payload, err := base64.RawURLEncoding.DecodeString(value)
	if err != nil || len(payload) > MaxCampaignCursorBytes {
		return time.Time{}, uuid.Nil, ErrInvalidCampaign
	}
	raw := strings.TrimPrefix(string(payload), "c:")
	separator := strings.LastIndexByte(raw, ':')
	if raw == string(payload) || separator < 1 || separator == len(raw)-1 {
		return time.Time{}, uuid.Nil, ErrInvalidCampaign
	}
	createdAt, err := time.Parse(time.RFC3339Nano, raw[:separator])
	if err != nil {
		return time.Time{}, uuid.Nil, ErrInvalidCampaign
	}
	id, err := uuid.Parse(raw[separator+1:])
	if err != nil || id == uuid.Nil {
		return time.Time{}, uuid.Nil, ErrInvalidCampaign
	}
	return createdAt, id, nil
}

func cloneCampaignString(value *string) *string {
	if value == nil {
		return nil
	}
	copy := *value
	return &copy
}

func cloneCampaign(value Campaign) *Campaign {
	value.Subject, value.Title = cloneCampaignString(value.Subject), cloneCampaignString(value.Title)
	return &value
}

// MemoryCampaignStore is an in-process store for service tests. Production
// composition uses ProductionCampaignStore, which delegates to PostgreSQL.
type MemoryCampaignStore struct {
	mu    sync.RWMutex
	items map[uuid.UUID]Campaign
}

func NewMemoryCampaignStore() *MemoryCampaignStore {
	return &MemoryCampaignStore{items: make(map[uuid.UUID]Campaign)}
}

func (m *MemoryCampaignStore) ListCampaigns(_ context.Context, query CampaignListQuery) ([]Campaign, error) {
	if m == nil || query.Limit < 1 {
		return nil, ErrAdminRepositoryAbsent
	}
	m.mu.RLock()
	items := make([]Campaign, 0, len(m.items))
	for _, item := range m.items {
		items = append(items, *cloneCampaign(item))
	}
	m.mu.RUnlock()
	sort.Slice(items, func(i, j int) bool {
		if items[i].CreatedAt.Equal(items[j].CreatedAt) {
			return items[i].ID.String() > items[j].ID.String()
		}
		return items[i].CreatedAt.After(items[j].CreatedAt)
	})
	filtered := items[:0]
	for _, item := range items {
		if query.BeforeCreatedAt != nil && (item.CreatedAt.After(*query.BeforeCreatedAt) || (item.CreatedAt.Equal(*query.BeforeCreatedAt) && query.BeforeID != nil && item.ID.String() >= query.BeforeID.String())) {
			continue
		}
		filtered = append(filtered, item)
		if len(filtered) == query.Limit {
			break
		}
	}
	return append([]Campaign(nil), filtered...), nil
}

func (m *MemoryCampaignStore) GetCampaign(_ context.Context, id uuid.UUID) (*Campaign, error) {
	if m == nil {
		return nil, ErrAdminRepositoryAbsent
	}
	m.mu.RLock()
	item, ok := m.items[id]
	m.mu.RUnlock()
	if !ok {
		return nil, nil
	}
	return cloneCampaign(item), nil
}

func (m *MemoryCampaignStore) CreateCampaign(_ context.Context, campaign Campaign) (*Campaign, error) {
	if m == nil || campaign.ID == uuid.Nil {
		return nil, ErrAdminRepositoryAbsent
	}
	m.mu.Lock()
	m.items[campaign.ID] = *cloneCampaign(campaign)
	m.mu.Unlock()
	return cloneCampaign(campaign), nil
}

func (m *MemoryCampaignStore) UpdateCampaignIfRevision(_ context.Context, campaign Campaign, expectedRevision int64) (*Campaign, bool, error) {
	if m == nil {
		return nil, false, ErrAdminRepositoryAbsent
	}
	m.mu.Lock()
	current, ok := m.items[campaign.ID]
	if !ok || current.Revision != expectedRevision {
		m.mu.Unlock()
		return nil, false, nil
	}
	m.items[campaign.ID] = *cloneCampaign(campaign)
	m.mu.Unlock()
	return cloneCampaign(campaign), true, nil
}

func (m *MemoryCampaignStore) DeleteCampaignIfRevision(_ context.Context, id uuid.UUID, expectedRevision int64) (bool, error) {
	if m == nil {
		return false, ErrAdminRepositoryAbsent
	}
	m.mu.Lock()
	current, ok := m.items[id]
	if !ok || current.Revision != expectedRevision {
		m.mu.Unlock()
		return false, nil
	}
	delete(m.items, id)
	m.mu.Unlock()
	return true, nil
}

var _ CampaignStore = (*MemoryCampaignStore)(nil)
