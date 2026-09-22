package service

import (
	"context"
	"encoding/json"
	"errors"
	"sort"
	"strings"
	"time"

	"github.com/google/uuid"

	"github.com/lrprojects/monaserver/internal/db"
)

// ProductionAdminStore maps the database facade to the reviewed admin
// service-store contracts. It intentionally does not implement the execution
// safety interfaces: until concrete action ports and atomic audit/lease
// transitions are deployed, AdminBulkService stops before a provider call.
type ProductionAdminStore struct {
	queries *db.Queries
}

func NewProductionAdminStore(queries *db.Queries) *ProductionAdminStore {
	return &ProductionAdminStore{queries: queries}
}

func (s *ProductionAdminStore) ListUsers(ctx context.Context, query AdminUserQuery) (AdminUserPage, error) {
	if s == nil || s.queries == nil {
		return AdminUserPage{}, ErrAdminRepositoryAbsent
	}
	var after *uuid.UUID
	if query.Cursor != "" {
		id, err := decodeUserCursor(query.Cursor)
		if err != nil {
			return AdminUserPage{}, err
		}
		after = &id
	}
	rows, err := s.queries.ListAdminRuntimeAccounts(ctx, db.AdminRuntimeAccountQuery{
		AfterID: after, Search: query.Search, SecurityState: query.SecurityState,
		VerifiedEmail: query.VerifiedEmail, CreatedAfter: query.CreatedAfter,
		CreatedBefore: query.CreatedBefore, IncludeAdmins: true, Limit: query.Limit + 1,
	})
	if err != nil {
		return AdminUserPage{}, err
	}
	page := AdminUserPage{Items: make([]AdminUser, 0, len(rows))}
	for _, row := range rows {
		page.Items = append(page.Items, adminUserFromRuntime(row))
	}
	if len(page.Items) > query.Limit {
		page.Items = page.Items[:query.Limit]
		next := encodeUserCursor(page.Items[len(page.Items)-1].ID)
		page.Next = &next
	}
	return page, nil
}

func (s *ProductionAdminStore) GetUser(ctx context.Context, id uuid.UUID) (*AdminUser, error) {
	if s == nil || s.queries == nil {
		return nil, ErrAdminRepositoryAbsent
	}
	row, err := s.queries.GetAdminRuntimeAccount(ctx, id)
	if err != nil || row == nil {
		return nil, err
	}
	user := adminUserFromRuntime(*row)
	return &user, nil
}

func adminUserFromRuntime(row db.AdminRuntimeAccount) AdminUser {
	user := AdminUser{
		ID:                    row.ID,
		Username:              row.Username,
		Email:                 row.Email,
		EmailVerified:         row.EmailConfirmed,
		CreatedAt:             row.CreatedAt,
		SecurityState:         row.SecurityState,
		AuthGeneration:        row.AuthGeneration,
		PasswordDisabled:      row.PasswordDisabled,
		PasswordResetRequired: row.PasswordResetRequired,
		IsAdmin:               row.IsAdmin,
		CompromisedAt:         row.CompromisedAt,
		CommunicationOptOut:   !row.GeneralEmailEnabled,
		PushOptedOut:          !row.PushEnabled,
		RegisteredDeviceCount: row.DeviceCount,
	}
	user.EligibilityReasons = runtimeAccountEligibility(row, AdminAction{Kind: ActionEmail})
	return user
}

func runtimeAccountEligibility(row db.AdminRuntimeAccount, action AdminAction) []string {
	switch action.Kind {
	case ActionEmail:
		if row.Email == nil || strings.TrimSpace(*row.Email) == "" {
			return []string{"missing_email"}
		}
		if !row.EmailConfirmed {
			return []string{"email_unverified"}
		}
		if !row.GeneralEmailEnabled {
			return []string{"email_opted_out"}
		}
	case ActionLoginLink, ActionRecoveryResend:
		if row.Email == nil || strings.TrimSpace(*row.Email) == "" || !row.EmailConfirmed {
			return []string{"email_unavailable"}
		}
	case ActionPush:
		if !row.PushEnabled {
			return []string{"push_opted_out"}
		}
		if row.DeviceCount < 1 {
			return []string{"no_registered_device"}
		}
	}
	return nil
}

func (s *ProductionAdminStore) CountAudience(ctx context.Context, _ uuid.UUID, audience Audience, _ AdminAction) (int64, error) {
	if s == nil || s.queries == nil {
		return 0, ErrAdminRepositoryAbsent
	}
	// A selected audience is the operator's requested scope. Missing or
	// deleted targets remain members of that scope and are materialized as
	// explicit exclusions, matching the in-memory contract and preserving the
	// preview's requested-vs-eligible counts.
	if audience.Kind == AudienceSelected {
		return int64(len(audience.IDs)), nil
	}
	if audience.Resource == AudienceAccounts {
		return s.queries.CountAdminRuntimeAccounts(ctx, runtimeAccountAudienceQuery(audience, 1, 0))
	}
	if audience.Resource == AudienceReports {
		return s.queries.CountAdminRuntimeReports(ctx, runtimeReportAudienceQuery(audience, 1, 0))
	}
	return 0, ErrInvalidAudience
}

func sortedRuntimeAudienceIDs(ids []uuid.UUID) []uuid.UUID {
	out := append([]uuid.UUID(nil), ids...)
	sort.Slice(out, func(i, j int) bool { return out[i].String() < out[j].String() })
	return out
}

func runtimeAccountAudienceMember(row db.AdminRuntimeAccount, action AdminAction, ordinal int64) AudienceMember {
	reasons := runtimeAccountEligibility(row, action)
	return AudienceMember{
		ResourceID: row.ID, Resource: AudienceAccounts, Eligible: len(reasons) == 0,
		ExclusionCode: firstReason(reasons), DeviceCount: int64(row.DeviceCount), IsAdmin: row.IsAdmin,
		EmailEligible: row.Email != nil && row.EmailConfirmed && row.GeneralEmailEnabled,
		EmailOptedOut: !row.GeneralEmailEnabled, PushEligible: row.DeviceCount > 0 && row.PushEnabled,
		PushOptedOut: !row.PushEnabled, EmailEligibilityKnown: true, PushEligibilityKnown: true,
		Ordinal: ordinal,
	}
}

func runtimeReportAudienceMember(row db.Report, ordinal int64) AudienceMember {
	member := AudienceMember{ResourceID: row.ID, Resource: AudienceReports, Eligible: row.Status == "open", Ordinal: ordinal}
	if !member.Eligible {
		member.ExclusionCode = "report_not_open"
	}
	return member
}

func (s *ProductionAdminStore) listSelectedAudienceMembers(ctx context.Context, audience Audience, action AdminAction, afterID *uuid.UUID, afterOrdinal int64, limit int) ([]AudienceMember, error) {
	ids := sortedRuntimeAudienceIDs(audience.IDs)
	start := int(afterOrdinal + 1)
	if afterID != nil {
		start = sort.Search(len(ids), func(index int) bool { return ids[index].String() > afterID.String() })
	}
	if start < 0 {
		start = 0
	}
	if start >= len(ids) {
		return []AudienceMember{}, nil
	}
	end := start + limit
	if end > len(ids) {
		end = len(ids)
	}
	items := make([]AudienceMember, 0, end-start)
	for ordinal, id := range ids[start:end] {
		absoluteOrdinal := int64(start + ordinal)
		if audience.Resource == AudienceAccounts {
			row, err := s.queries.GetAdminRuntimeAccount(ctx, id)
			if err != nil {
				return nil, err
			}
			if row == nil {
				items = append(items, AudienceMember{ResourceID: id, Resource: AudienceAccounts, ExclusionCode: "not_found", Ordinal: absoluteOrdinal})
				continue
			}
			items = append(items, runtimeAccountAudienceMember(*row, action, absoluteOrdinal))
			continue
		}
		if audience.Resource == AudienceReports {
			row, err := s.queries.GetReport(ctx, id)
			if err != nil {
				return nil, err
			}
			if row == nil {
				items = append(items, AudienceMember{ResourceID: id, Resource: AudienceReports, ExclusionCode: "not_found", Ordinal: absoluteOrdinal})
				continue
			}
			items = append(items, runtimeReportAudienceMember(*row, absoluteOrdinal))
			continue
		}
		return nil, ErrInvalidAudience
	}
	return items, nil
}

func (s *ProductionAdminStore) ListAudienceMembers(ctx context.Context, _ uuid.UUID, audience Audience, action AdminAction, afterOrdinal int64, limit int) ([]AudienceMember, error) {
	if s == nil || s.queries == nil {
		return nil, ErrAdminRepositoryAbsent
	}
	if afterOrdinal < -1 || limit < 1 {
		return nil, ErrInvalidAudience
	}
	if audience.Kind == AudienceSelected {
		return s.listSelectedAudienceMembers(ctx, audience, action, nil, afterOrdinal, limit)
	}
	offset := int(afterOrdinal + 1)
	if audience.Resource == AudienceAccounts {
		rows, err := s.queries.ListAdminRuntimeAccounts(ctx, runtimeAccountAudienceQuery(audience, limit, offset))
		if err != nil {
			return nil, err
		}
		items := make([]AudienceMember, 0, len(rows))
		for i, row := range rows {
			reasons := runtimeAccountEligibility(row, action)
			member := AudienceMember{ResourceID: row.ID, Resource: AudienceAccounts, Eligible: len(reasons) == 0,
				DeviceCount: int64(row.DeviceCount), IsAdmin: row.IsAdmin, EmailEligible: row.Email != nil && row.EmailConfirmed && row.GeneralEmailEnabled,
				EmailOptedOut: !row.GeneralEmailEnabled, PushEligible: row.DeviceCount > 0 && row.PushEnabled, PushOptedOut: !row.PushEnabled,
				EmailEligibilityKnown: true, PushEligibilityKnown: true, Ordinal: afterOrdinal + int64(i) + 1}
			if len(reasons) > 0 {
				member.ExclusionCode = reasons[0]
			}
			items = append(items, member)
		}
		return items, nil
	}
	if audience.Resource == AudienceReports {
		rows, err := s.queries.ListAdminRuntimeReports(ctx, runtimeReportAudienceQuery(audience, limit, offset))
		if err != nil {
			return nil, err
		}
		items := make([]AudienceMember, 0, len(rows))
		for i, row := range rows {
			member := AudienceMember{ResourceID: row.ID, Resource: AudienceReports, Eligible: row.Status == "open", Ordinal: afterOrdinal + int64(i) + 1}
			if !member.Eligible {
				member.ExclusionCode = "report_not_open"
			}
			items = append(items, member)
		}
		return items, nil
	}
	return nil, ErrInvalidAudience
}

// ListAudienceMembersAfterID is the production keyset path used by bounded
// preview materialization. UUID ordering is stable across inserts/deletes, so
// a page cannot duplicate or skip a row merely because the underlying table
// changes between calls. The service still compares the final page count with
// the initial count and rejects a moving scope rather than persisting a partial
// snapshot.
func (s *ProductionAdminStore) ListAudienceMembersAfterID(ctx context.Context, _ uuid.UUID, audience Audience, action AdminAction, afterID *uuid.UUID, afterOrdinal int64, limit int) ([]AudienceMember, error) {
	if s == nil || s.queries == nil {
		return nil, ErrAdminRepositoryAbsent
	}
	if afterOrdinal < -1 || limit < 1 {
		return nil, ErrInvalidAudience
	}
	if audience.Kind == AudienceSelected {
		return s.listSelectedAudienceMembers(ctx, audience, action, afterID, afterOrdinal, limit)
	}
	if audience.Resource == AudienceAccounts {
		query := runtimeAccountAudienceQuery(audience, limit, 0)
		query.AfterID = afterID
		rows, err := s.queries.ListAdminRuntimeAccounts(ctx, query)
		if err != nil {
			return nil, err
		}
		items := make([]AudienceMember, 0, len(rows))
		for index, row := range rows {
			items = append(items, runtimeAccountAudienceMember(row, action, afterOrdinal+int64(index)+1))
		}
		return items, nil
	}
	if audience.Resource == AudienceReports {
		query := runtimeReportAudienceQuery(audience, limit, 0)
		query.AfterID = afterID
		rows, err := s.queries.ListAdminRuntimeReports(ctx, query)
		if err != nil {
			return nil, err
		}
		items := make([]AudienceMember, 0, len(rows))
		for index, row := range rows {
			member := AudienceMember{ResourceID: row.ID, Resource: AudienceReports, Eligible: row.Status == "open", Ordinal: afterOrdinal + int64(index) + 1}
			if !member.Eligible {
				member.ExclusionCode = "report_not_open"
			}
			items = append(items, member)
		}
		return items, nil
	}
	return nil, ErrInvalidAudience
}

func runtimeAccountAudienceQuery(audience Audience, limit, offset int) db.AdminRuntimeAccountQuery {
	query := db.AdminRuntimeAccountQuery{SelectedIDs: audience.IDs, IncludeAdmins: true, Limit: limit, Offset: offset}
	if audience.Filter == nil {
		return query
	}
	if audience.Filter.Username != nil {
		query.Username = *audience.Filter.Username
	}
	if audience.Filter.Email != nil {
		query.Email = *audience.Filter.Email
	}
	if audience.Filter.ID != nil {
		query.IDText = *audience.Filter.ID
	}
	query.VerifiedEmail = audience.Filter.VerifiedEmail
	query.CreatedAfter = audience.Filter.CreatedAfter
	query.CreatedBefore = audience.Filter.CreatedBefore
	query.SecurityStates = append([]string(nil), audience.Filter.SecurityStatuses...)
	return query
}

func runtimeReportAudienceQuery(audience Audience, limit, offset int) db.AdminRuntimeReportQuery {
	query := db.AdminRuntimeReportQuery{SelectedIDs: audience.IDs, Limit: limit, Offset: offset}
	if audience.Filter == nil {
		return query
	}
	query.Statuses = append([]string(nil), audience.Filter.Statuses...)
	query.TargetTypes = append([]string(nil), audience.Filter.Types...)
	query.AssigneeUserID = audience.Filter.AssigneeUserID
	query.CreatedAfter = audience.Filter.CreatedAfter
	query.CreatedBefore = audience.Filter.CreatedBefore
	return query
}

type runtimeAudienceEnvelope struct {
	Audience Audience    `json:"audience"`
	Action   AdminAction `json:"action"`
}

func (s *ProductionAdminStore) SaveAudienceSnapshot(ctx context.Context, snapshot AudienceSnapshot) error {
	if s == nil || s.queries == nil {
		return ErrAdminRepositoryAbsent
	}
	encoded, err := json.Marshal(runtimeAudienceEnvelope{Audience: snapshot.Audience, Action: snapshot.Action})
	if err != nil {
		return err
	}
	return s.queries.InTx(ctx, func(tx *db.Queries) error {
		if err := tx.CreateAudienceSnapshot(ctx, db.AudienceSnapshotParams{ID: snapshot.ID, ActorID: snapshot.ActorID, Resource: string(snapshot.Resource), Action: snapshot.Action.Kind, PayloadHash: []byte(snapshot.PayloadHash), Filter: encoded, Status: snapshot.Status, ExpiresAt: snapshot.ExpiresAt}); err != nil {
			return err
		}
		for _, member := range snapshot.Members {
			if err := tx.AddAudienceSnapshotMember(ctx, snapshot.ID, member.Ordinal, member.ResourceID, member.Eligible, stringPointer(member.ExclusionCode)); err != nil {
				return err
			}
		}
		return tx.UpdateAudienceSnapshotCounts(ctx, snapshot.ID, snapshot.Status, snapshot.AccountCount, snapshot.EligibleCount, snapshot.DeviceCount, snapshot.ExclusionCount)
	})
}

func (s *ProductionAdminStore) GetAudienceSnapshot(ctx context.Context, id uuid.UUID) (*AudienceSnapshot, error) {
	if s == nil || s.queries == nil {
		return nil, ErrAdminRepositoryAbsent
	}
	raw, err := s.queries.GetAudienceSnapshot(ctx, id)
	if err != nil || raw == nil {
		return nil, err
	}
	return runtimeAudienceSnapshot(*raw)
}

func runtimeAudienceSnapshot(raw db.AudienceSnapshot) (*AudienceSnapshot, error) {
	var envelope runtimeAudienceEnvelope
	if err := json.Unmarshal(raw.Filter, &envelope); err != nil {
		return nil, err
	}
	actorID := uuid.Nil
	if raw.ActorID != nil {
		actorID = *raw.ActorID
	}
	return &AudienceSnapshot{ID: raw.ID, ActorID: actorID, Resource: AudienceResource(raw.Resource), Action: envelope.Action,
		PayloadHash: string(raw.PayloadHash), Audience: envelope.Audience, Status: raw.Status, AccountCount: raw.AccountCount,
		EligibleCount: raw.EligibleCount, DeviceCount: raw.DeviceCount, ExclusionCount: raw.ExclusionCount, ExpiresAt: raw.ExpiresAt,
		CreatedAt: raw.CreatedAt, UpdatedAt: raw.UpdatedAt}, nil
}

func (s *ProductionAdminStore) ListAudienceSnapshotMembers(ctx context.Context, snapshotID uuid.UUID, limit int, afterOrdinal int64) ([]AudienceMember, error) {
	if s == nil || s.queries == nil {
		return nil, ErrAdminRepositoryAbsent
	}
	rows, err := s.queries.ListAudienceSnapshotMembers(ctx, snapshotID, limit, afterOrdinal)
	if err != nil {
		return nil, err
	}
	snapshot, err := s.GetAudienceSnapshot(ctx, snapshotID)
	if err != nil {
		return nil, err
	}
	if snapshot == nil {
		return nil, ErrSnapshotNotFound
	}
	items := make([]AudienceMember, 0, len(rows))
	for _, row := range rows {
		code := ""
		if row.ExclusionCode != nil {
			code = *row.ExclusionCode
		}
		items = append(items, AudienceMember{ResourceID: row.ResourceID, Resource: snapshot.Resource, Eligible: row.Eligible, ExclusionCode: code, Ordinal: row.Ordinal})
	}
	return items, nil
}

func (s *ProductionAdminStore) ListAudit(ctx context.Context, query AdminAuditQuery) (AdminAuditPage, error) {
	if s == nil || s.queries == nil {
		return AdminAuditPage{}, ErrAdminRepositoryAbsent
	}
	var after *uuid.UUID
	if query.Cursor != "" {
		id, err := decodeAuditCursor(query.Cursor)
		if err != nil {
			return AdminAuditPage{}, err
		}
		after = &id
	}
	rows, err := s.queries.ListAdminRuntimeAuditEvents(ctx, db.AdminRuntimeAuditQuery{AfterID: after, TargetAccountID: query.TargetID, Action: query.Action, Limit: query.Limit + 1})
	if err != nil {
		return AdminAuditPage{}, err
	}
	page := AdminAuditPage{Items: make([]AdminAuditEvent, 0, len(rows))}
	for _, row := range rows {
		details := make(map[string]string)
		_ = json.Unmarshal(row.Metadata, &details)
		outcome := ""
		if row.Outcome != nil {
			outcome = *row.Outcome
		}
		page.Items = append(page.Items, AdminAuditEvent{ID: row.ID, ActorID: row.ActorID, TargetID: row.TargetAccountID, Action: row.Action, Outcome: outcome, Reason: row.Reason, Details: details, OccurredAt: row.CreatedAt})
	}
	if len(page.Items) > query.Limit {
		page.Items = page.Items[:query.Limit]
		next := encodeAuditCursor(page.Items[len(page.Items)-1].ID)
		page.Next = &next
	}
	return page, nil
}

func (s *ProductionAdminStore) AppendAudit(ctx context.Context, event AdminAuditEvent) error {
	if s == nil || s.queries == nil {
		return ErrAdminRepositoryAbsent
	}
	metadata, err := json.Marshal(event.Details)
	if err != nil {
		return err
	}
	return s.queries.CreateAuditEvent(ctx, db.AuditEventParams{ID: event.ID, ActorID: event.ActorID, TargetAccountID: event.TargetID, Action: event.Action, Reason: event.Reason, Outcome: stringPointer(event.Outcome), Metadata: metadata})
}

func (s *ProductionAdminStore) CreateJob(ctx context.Context, job AdminJob, items []AdminJobItem) (*AdminJob, error) {
	if s == nil || s.queries == nil {
		return nil, ErrAdminRepositoryAbsent
	}
	var created *db.AdminJob
	err := s.queries.InTx(ctx, func(tx *db.Queries) error {
		var err error
		created, err = tx.CreateAdminJob(ctx, db.AdminJobParams{ID: job.ID, ActorID: &job.ActorID, SnapshotID: &job.SnapshotID, Action: job.Action.Kind, PayloadHash: []byte(job.PayloadHash), IdempotencyKey: job.IdempotencyKey, AccountCount: job.AccountCount, EligibleCount: job.EligibleCount, DeviceCount: job.DeviceCount, Reason: stringPointer(job.Reason), RecentMFAAt: job.RecentMFAAt, RecentMFAAction: stringPointer(job.RecentMFAAction)})
		if err != nil || created == nil || created.ID != job.ID {
			return err
		}
		for _, item := range items {
			if err := tx.AddAdminJobItem(ctx, db.AdminJobItemParams{ID: item.ID, JobID: job.ID, TargetID: item.TargetID, DeviceID: item.DeviceID, DeviceCount: item.DeviceCount, Outcome: item.Outcome, ErrorCode: stringPointer(item.ErrorCode), ProviderReference: stringPointer(item.ProviderReference)}); err != nil {
				return err
			}
		}
		return nil
	})
	if err != nil {
		if errors.Is(err, db.ErrIdempotencyConflict) {
			return nil, ErrJobConflict
		}
		return nil, err
	}
	if created == nil {
		return nil, ErrJobConflict
	}
	return s.runtimeJob(ctx, *created)
}

func (s *ProductionAdminStore) GetJob(ctx context.Context, id uuid.UUID) (*AdminJob, error) {
	if s == nil || s.queries == nil {
		return nil, ErrAdminRepositoryAbsent
	}
	raw, err := s.queries.GetAdminJob(ctx, id)
	if err != nil || raw == nil {
		return nil, err
	}
	return s.runtimeJob(ctx, *raw)
}

func (s *ProductionAdminStore) runtimeJob(ctx context.Context, raw db.AdminJob) (*AdminJob, error) {
	if raw.ActorID == nil || raw.SnapshotID == nil {
		return nil, ErrAdminRepositoryAbsent
	}
	action := AdminAction{Kind: raw.Action}
	snapshot, err := s.GetAudienceSnapshot(ctx, *raw.SnapshotID)
	if err != nil {
		return nil, err
	}
	if snapshot == nil {
		return nil, ErrSnapshotNotFound
	}
	if snapshot.Action.Kind == raw.Action {
		action = snapshot.Action
	}
	reason := ""
	if raw.Reason != nil {
		reason = *raw.Reason
	}
	recentAction := ""
	if raw.RecentMFAAction != nil {
		recentAction = *raw.RecentMFAAction
	}
	return &AdminJob{ID: raw.ID, ActorID: *raw.ActorID, SnapshotID: *raw.SnapshotID, Action: action, PayloadHash: string(raw.PayloadHash), IdempotencyKey: raw.IdempotencyKey, Status: raw.Status, AccountCount: raw.AccountCount, EligibleCount: raw.EligibleCount, DeviceCount: raw.DeviceCount, CompletedCount: raw.CompletedCount, FailedCount: raw.FailedCount, Reason: reason, CreatedAt: raw.CreatedAt, UpdatedAt: raw.UpdatedAt, StartedAt: raw.StartedAt, CompletedAt: raw.CompletedAt, RecentMFAAt: raw.RecentMFAAt, RecentMFAAction: recentAction}, nil
}

func (s *ProductionAdminStore) ListJobs(ctx context.Context, cursor string, limit int, status, action string) (AdminJobPage, error) {
	if s == nil || s.queries == nil {
		return AdminJobPage{}, ErrAdminRepositoryAbsent
	}
	var after *uuid.UUID
	if cursor != "" {
		id, err := decodeJobCursor(cursor)
		if err != nil {
			return AdminJobPage{}, err
		}
		after = &id
	}
	rows, err := s.queries.ListAdminRuntimeJobs(ctx, after, limit+1, status, action)
	if err != nil {
		return AdminJobPage{}, err
	}
	page := AdminJobPage{Items: make([]AdminJob, 0, len(rows))}
	for _, row := range rows {
		job, err := s.runtimeJob(ctx, row)
		if err != nil {
			return AdminJobPage{}, err
		}
		page.Items = append(page.Items, *job)
	}
	if len(page.Items) > limit {
		page.Items = page.Items[:limit]
		next := encodeJobCursor(page.Items[len(page.Items)-1].ID)
		page.Next = &next
	}
	return page, nil
}

func (s *ProductionAdminStore) ListJobItems(ctx context.Context, jobID uuid.UUID, cursor string, limit int) (AdminJobRecipientPage, error) {
	if s == nil || s.queries == nil {
		return AdminJobRecipientPage{}, ErrAdminRepositoryAbsent
	}
	var after *uuid.UUID
	if cursor != "" {
		id, err := decodeOpaqueCursor("i", cursor, ErrInvalidJobRequest)
		if err != nil {
			return AdminJobRecipientPage{}, err
		}
		after = &id
	}
	rows, err := s.queries.ListAdminRuntimeJobItems(ctx, jobID, after, limit+1)
	if err != nil {
		return AdminJobRecipientPage{}, err
	}
	page := AdminJobRecipientPage{Items: make([]AdminJobItem, 0, len(rows))}
	for _, row := range rows {
		errorCode, providerReference := "", ""
		if row.ErrorCode != nil {
			errorCode = *row.ErrorCode
		}
		if row.ProviderReference != nil {
			providerReference = *row.ProviderReference
		}
		page.Items = append(page.Items, AdminJobItem{ID: row.ID, JobID: row.JobID, TargetID: row.TargetID, DeviceID: row.DeviceID, Outcome: row.Outcome, ErrorCode: errorCode, ProviderReference: providerReference, AttemptCount: row.AttemptCount, DeviceCount: row.DeviceCount, CompletedAt: row.CompletedAt, CreatedAt: row.CreatedAt, UpdatedAt: row.UpdatedAt})
	}
	if len(page.Items) > limit {
		page.Items = page.Items[:limit]
		next := encodeOpaqueCursor("i", page.Items[len(page.Items)-1].ID)
		page.Next = &next
	}
	return page, nil
}

// The legacy execution methods are deliberately unavailable. AdminBulkService
// checks its stronger fenced/audited execution interfaces before these can be
// called, so no provider action can be fabricated through this adapter.
func (*ProductionAdminStore) ClaimJobItem(context.Context, uuid.UUID, uuid.UUID, string) (*AdminJobItem, bool, error) {
	return nil, false, ErrActionUnavailable
}

func (*ProductionAdminStore) FinishJobItem(context.Context, uuid.UUID, string, string, string, string) (*AdminJobItem, error) {
	return nil, ErrActionUnavailable
}

func (*ProductionAdminStore) ApplyJobCommand(context.Context, AdminJobCommand) (*AdminJob, error) {
	return nil, ErrActionUnavailable
}

func (*ProductionAdminStore) PauseJob(context.Context, uuid.UUID, string) error {
	return ErrActionUnavailable
}

func (*ProductionAdminStore) UpdateJobProgress(context.Context, uuid.UUID) error {
	return ErrActionUnavailable
}

func runtimeAdminJobItem(raw db.AdminJobItem) *AdminJobItem {
	reason, errorCode, providerReference := "", "", ""
	if raw.Reason != nil {
		reason = *raw.Reason
	}
	if raw.ErrorCode != nil {
		errorCode = *raw.ErrorCode
	}
	if raw.ProviderReference != nil {
		providerReference = *raw.ProviderReference
	}
	return &AdminJobItem{ID: raw.ID, JobID: raw.JobID, TargetID: raw.TargetID, OperationID: raw.OperationID,
		DeviceID: raw.DeviceID, DeviceCount: raw.DeviceCount, Outcome: raw.Outcome, Reason: reason,
		ErrorCode: errorCode, ProviderReference: providerReference, Retryable: raw.Retryable,
		Ambiguous: raw.Ambiguous, AttemptCount: raw.AttemptCount, LastAttemptAt: raw.LastAttemptAt,
		CompletedAt: raw.CompletedAt, CreatedAt: raw.CreatedAt, UpdatedAt: raw.UpdatedAt}
}

func (s *ProductionAdminStore) ClaimJobItemWithLease(ctx context.Context, jobID, itemID uuid.UUID, worker string, ttl time.Duration) (*AdminJobItem, *AdminJobLease, bool, error) {
	if s == nil || s.queries == nil {
		return nil, nil, false, ErrAdminRepositoryAbsent
	}
	raw, claimed, err := s.queries.ClaimAdminJobItemWithFence(ctx, jobID, itemID, worker, ttl)
	if err != nil || !claimed || raw == nil {
		return nil, nil, claimed, err
	}
	if raw.LeaseToken == uuid.Nil || raw.LeaseFence <= 0 || raw.LeaseUntil == nil || raw.OperationID == uuid.Nil {
		return nil, nil, false, ErrAdminRepositoryAbsent
	}
	return runtimeAdminJobItem(*raw), &AdminJobLease{Token: raw.LeaseToken.String(), Fence: raw.LeaseFence, ExpiresAt: *raw.LeaseUntil}, true, nil
}

func (s *ProductionAdminStore) RenewJobItemLease(ctx context.Context, itemID uuid.UUID, lease AdminJobLease, ttl time.Duration) (*AdminJobLease, error) {
	if s == nil || s.queries == nil {
		return nil, ErrAdminRepositoryAbsent
	}
	token, err := uuid.Parse(lease.Token)
	if err != nil || token == uuid.Nil || lease.Fence <= 0 {
		return nil, ErrJobConflict
	}
	expiresAt, renewed, err := s.queries.RenewAdminJobItemLeaseWithFence(ctx, itemID, token, lease.Fence, ttl)
	if err != nil {
		return nil, err
	}
	if !renewed || expiresAt == nil {
		return nil, ErrJobConflict
	}
	return &AdminJobLease{Token: lease.Token, Fence: lease.Fence, ExpiresAt: *expiresAt}, nil
}

func (s *ProductionAdminStore) FinishJobItemWithLease(ctx context.Context, itemID uuid.UUID, lease AdminJobLease, operationID uuid.UUID, outcome, reason, errorCode, providerReference string, retryable, ambiguous bool) (*AdminJobItem, error) {
	if s == nil || s.queries == nil {
		return nil, ErrAdminRepositoryAbsent
	}
	token, err := uuid.Parse(lease.Token)
	if err != nil || token == uuid.Nil || lease.Fence <= 0 {
		return nil, ErrJobConflict
	}
	raw, finished, err := s.queries.FinishAdminJobItemWithFence(ctx, itemID, token, lease.Fence, operationID, outcome, stringPointer(reason), stringPointer(errorCode), stringPointer(providerReference), retryable, ambiguous)
	if err != nil {
		return nil, err
	}
	if !finished || raw == nil {
		return nil, ErrJobConflict
	}
	return runtimeAdminJobItem(*raw), nil
}

func (s *ProductionAdminStore) FinishJobItemWithAudit(ctx context.Context, itemID uuid.UUID, lease AdminJobLease, operationID uuid.UUID, outcome, reason, errorCode, providerReference string, retryable, ambiguous bool, audit AdminJobItemAudit) (*AdminJobItem, error) {
	if s == nil || s.queries == nil {
		return nil, ErrAdminRepositoryAbsent
	}
	token, err := uuid.Parse(lease.Token)
	if err != nil || token == uuid.Nil || lease.Fence <= 0 {
		return nil, ErrJobConflict
	}
	raw, finished, err := s.queries.FinishAdminJobItemWithAudit(ctx, itemID, token, lease.Fence, operationID, outcome, stringPointer(reason), stringPointer(errorCode), stringPointer(providerReference), retryable, ambiguous, runtimeAuditParams(audit))
	if err != nil {
		return nil, err
	}
	if !finished || raw == nil {
		return nil, ErrJobConflict
	}
	return runtimeAdminJobItem(*raw), nil
}

func (s *ProductionAdminStore) CommitUnknownDeliveryAfterLeaseLoss(ctx context.Context, itemID uuid.UUID, lease AdminJobLease, operationID uuid.UUID, audit AdminJobItemAudit) (*AdminJobItem, error) {
	if s == nil || s.queries == nil {
		return nil, ErrAdminRepositoryAbsent
	}
	token, err := uuid.Parse(lease.Token)
	if err != nil || token == uuid.Nil || lease.Fence <= 0 {
		return nil, ErrJobConflict
	}
	raw, committed, err := s.queries.CommitAdminJobItemUnknownDeliveryAfterLeaseLoss(ctx, itemID, token, lease.Fence, operationID, runtimeAuditParams(audit))
	if err != nil {
		return nil, err
	}
	if !committed || raw == nil {
		return nil, ErrJobConflict
	}
	return runtimeAdminJobItem(*raw), nil
}

func (s *ProductionAdminStore) RecordJobItemAudit(ctx context.Context, audit AdminJobItemAudit) error {
	if s == nil || s.queries == nil {
		return ErrAdminRepositoryAbsent
	}
	return s.queries.RecordAdminJobItemAudit(ctx, runtimeAuditParams(audit))
}

func (s *ProductionAdminStore) SupportsTerminalUnknownDelivery() bool {
	// This is a type-level capability declaration: construction with a nil
	// query facade is still rejected by every execution method above.
	return s != nil
}

func runtimeAuditParams(audit AdminJobItemAudit) db.AdminJobItemAuditParams {
	return db.AdminJobItemAuditParams{JobID: audit.JobID, ItemID: audit.ItemID, OperationID: audit.OperationID,
		ActorID: audit.ActorID, TargetID: audit.TargetID, Action: audit.Action, Outcome: audit.Outcome,
		Reason: audit.Reason, ErrorCode: audit.ErrorCode}
}

func stringPointer(value string) *string {
	if strings.TrimSpace(value) == "" {
		return nil
	}
	return &value
}

var _ AdminUserStore = (*ProductionAdminStore)(nil)
var _ AudienceSnapshotStore = (*ProductionAdminStore)(nil)
var _ AdminAuditStore = (*ProductionAdminStore)(nil)
var _ AdminJobStore = (*ProductionAdminStore)(nil)
var _ FencedAdminJobStore = (*ProductionAdminStore)(nil)
var _ AdminJobLeaseRenewer = (*ProductionAdminStore)(nil)
var _ TerminalUnknownDeliveryStore = (*ProductionAdminStore)(nil)
var _ AdminJobItemCommitStore = (*ProductionAdminStore)(nil)
var _ AdminJobLeaseLossCommitStore = (*ProductionAdminStore)(nil)
var _ AdminJobItemAuditStore = (*ProductionAdminStore)(nil)
