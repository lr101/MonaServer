package service

import (
	"context"
	"encoding/json"
	"strings"
	"time"

	"github.com/google/uuid"

	"github.com/lrprojects/monaserver/internal/apperrors"
	"github.com/lrprojects/monaserver/internal/db"
)

// ProductionAdminStore maps the database facade to the reviewed admin
// service-store contracts. It intentionally does not implement the execution
// safety interfaces: until concrete action ports and atomic audit/lease
// transitions are deployed, AdminBulkService stops before a provider call.
type ProductionAdminStore struct {
	queries *db.Queries
	mail    *Email
}

func NewProductionAdminStore(queries *db.Queries, mail ...*Email) *ProductionAdminStore {
	store := &ProductionAdminStore{queries: queries}
	if len(mail) > 0 {
		store.mail = mail[0]
	}
	return store
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
	if row.IsAdmin {
		membership, err := s.queries.GetAdminMembership(ctx, id)
		if err != nil {
			return nil, err
		}
		if membership != nil && membership.Active && membership.RevokedAt == nil {
			user.AdminPermissions = append([]string(nil), membership.Permissions...)
		}
	}
	return &user, nil
}

func (s *ProductionAdminStore) VerifyUserEmail(ctx context.Context, actorID, id uuid.UUID) (*AdminUser, error) {
	if s == nil || s.queries == nil {
		return nil, ErrAdminRepositoryAbsent
	}
	var verified *AdminUser
	err := s.queries.InTxRetry(ctx, func(tx *db.Queries) error {
		row, err := tx.GetAdminRuntimeAccount(ctx, id)
		if err != nil {
			return err
		}
		if row == nil {
			return ErrUserNotFound
		}
		if row.Email == nil {
			return ErrUserEmailUnavailable
		}
		if !row.EmailConfirmed {
			ok, err := tx.ConfirmUserEmailWithClaim(ctx, id)
			if err != nil {
				return err
			}
			if !ok {
				return ErrUserEmailUnavailable
			}
			if err := tx.CreateAuditEvent(ctx, db.AuditEventParams{ID: uuid.New(), ActorID: &actorID, TargetAccountID: &id, Action: "admin_email_verified"}); err != nil {
				return err
			}
		}
		row, err = tx.GetAdminRuntimeAccount(ctx, id)
		if err != nil {
			return err
		}
		if row == nil {
			return ErrUserNotFound
		}
		membership, err := tx.GetAdminMembership(ctx, id)
		if err != nil {
			return err
		}
		user := adminUserFromRuntime(*row)
		if membership != nil && membership.Active && membership.RevokedAt == nil {
			user.AdminPermissions = append([]string(nil), membership.Permissions...)
		}
		verified = &user
		return nil
	})
	return verified, err
}

func (s *ProductionAdminStore) UpdateUser(ctx context.Context, actorID, id uuid.UUID, update AdminUserUpdate) (*AdminUser, error) {
	if s == nil || s.queries == nil {
		return nil, ErrAdminRepositoryAbsent
	}
	var updated *AdminUser
	err := s.queries.InTxRetry(ctx, func(tx *db.Queries) error {
		state, err := tx.LockUserSecurity(ctx, id)
		if err != nil {
			return err
		}
		if state == nil || state.IsDeleted {
			return ErrUserNotFound
		}
		if update.ExpectedAuthGeneration == nil || state.AuthGeneration != *update.ExpectedAuthGeneration {
			return apperrors.ErrConflict
		}
		row, err := tx.GetAdminRuntimeAccount(ctx, id)
		if err != nil {
			return err
		}
		if row == nil {
			return ErrUserNotFound
		}

		changed := make([]string, 0, 5)
		authInvalidated := false
		if update.Username != nil && row.Username != *update.Username {
			existing, err := tx.GetUserByUsername(ctx, *update.Username)
			if err != nil {
				return err
			}
			if existing != nil && existing.ID != id {
				return apperrors.ErrConflict
			}
			if err := tx.UpdateUserUsername(ctx, id, *update.Username); err != nil {
				return err
			}
			row.Username = *update.Username
			changed = append(changed, "username")
		}

		securityState := row.SecurityState
		passwordDisabled := row.PasswordDisabled
		passwordResetRequired := row.PasswordResetRequired
		compromisedAt := row.CompromisedAt
		securityStateChanged := update.SecurityState != nil && row.SecurityState != *update.SecurityState
		if securityStateChanged {
			securityState = *update.SecurityState
			passwordDisabled, passwordResetRequired, compromisedAt = adminUserSecurityValues(securityState, time.Now().UTC())
		}
		if update.PasswordDisabled != nil {
			passwordDisabled = *update.PasswordDisabled
		}
		if update.PasswordResetRequired != nil {
			passwordResetRequired = *update.PasswordResetRequired
		}
		passwordDisabledChanged := row.PasswordDisabled != passwordDisabled
		passwordResetRequiredChanged := row.PasswordResetRequired != passwordResetRequired
		if securityStateChanged || passwordDisabledChanged || passwordResetRequiredChanged {
			if _, err := tx.AdvanceUserAuthGeneration(ctx, id); err != nil {
				return err
			}
			if securityState == "normal" && !passwordDisabled && !passwordResetRequired && compromisedAt == nil {
				if err := tx.ClearUserRecoveryRestriction(ctx, id); err != nil {
					return err
				}
			} else if err := tx.SetUserSecurityState(ctx, id, securityState, passwordDisabled, passwordResetRequired, compromisedAt); err != nil {
				return err
			}
			if err := tx.InvalidateUserTokens(ctx, id); err != nil {
				return err
			}
			if err := tx.RevokeAdminSessionsForUser(ctx, id); err != nil {
				return err
			}
			if err := tx.RevokeAdminLoginChallengesForUser(ctx, id); err != nil {
				return err
			}
			authInvalidated = true
			row.SecurityState = securityState
			row.PasswordDisabled = passwordDisabled
			row.PasswordResetRequired = passwordResetRequired
			row.CompromisedAt = compromisedAt
			if securityStateChanged {
				changed = append(changed, "securityState")
			}
			if passwordDisabledChanged {
				changed = append(changed, "passwordDisabled")
			}
			if passwordResetRequiredChanged {
				changed = append(changed, "passwordResetRequired")
			}
		}

		if update.Email != nil && (row.Email == nil || db.CanonicalEmail(*row.Email) != db.CanonicalEmail(*update.Email)) {
			if row.SecurityState != "normal" || s.mail == nil {
				return ErrUserEmailUnavailable
			}
			if !authInvalidated {
				if _, err := tx.AdvanceUserAuthGeneration(ctx, id); err != nil {
					return err
				}
				if err := tx.InvalidateUserTokens(ctx, id); err != nil {
					return err
				}
				if err := tx.RevokeAdminSessionsForUser(ctx, id); err != nil {
					return err
				}
				if err := tx.RevokeAdminLoginChallengesForUser(ctx, id); err != nil {
					return err
				}
				authInvalidated = true
			}
			confirmationURL := randomURL()
			if err := tx.ChangeUserEmail(ctx, id, update.Email, &confirmationURL); err != nil {
				return err
			}
			if err := deliverEmailConfirmation(ctx, s.mail, row.Username, *update.Email, confirmationURL); err != nil {
				return err
			}
			row.Email = update.Email
			row.EmailConfirmed = false
			changed = append(changed, "email")
		}

		if update.CommunicationOptOut != nil || update.PushOptedOut != nil {
			preferences, err := tx.GetCommunicationPreferences(ctx, id)
			if err != nil {
				return err
			}
			securityEmailEnabled, generalEmailEnabled, pushEnabled := true, true, true
			if preferences != nil {
				securityEmailEnabled = preferences.SecurityEmailEnabled
				generalEmailEnabled = preferences.GeneralEmailEnabled
				pushEnabled = preferences.PushEnabled
			}
			if update.CommunicationOptOut != nil && generalEmailEnabled == *update.CommunicationOptOut {
				generalEmailEnabled = !*update.CommunicationOptOut
				changed = append(changed, "communicationOptOut")
			}
			if update.PushOptedOut != nil && pushEnabled == *update.PushOptedOut {
				pushEnabled = !*update.PushOptedOut
				changed = append(changed, "pushOptedOut")
			}
			if _, err := tx.UpsertCommunicationPreferences(ctx, id, securityEmailEnabled, generalEmailEnabled, pushEnabled); err != nil {
				return err
			}
		}

		if update.AdminPermissions != nil {
			membership, err := tx.GetAdminMembership(ctx, id)
			if err != nil {
				return err
			}
			if membership == nil || !membership.Active || membership.RevokedAt != nil {
				return ErrAdminPermissionTarget
			}
			permissions := append([]string(nil), (*update.AdminPermissions)...)
			if !equalStrings(membership.Permissions, permissions) {
				if err := tx.UpsertAdminMembership(ctx, db.AdminMembershipParams{
					ID: membership.ID, UserID: id, Permissions: permissions, Active: membership.Active,
					TotpSecretCiphertext: membership.TotpSecretCiphertext, TotpKeyID: membership.TotpKeyID,
					TotpEnrolledAt: membership.TotpEnrolledAt, RevokedAt: membership.RevokedAt,
				}); err != nil {
					return err
				}
				if err := tx.RevokeAdminSessionsForUser(ctx, id); err != nil {
					return err
				}
				if err := tx.RevokeAdminLoginChallengesForUser(ctx, id); err != nil {
					return err
				}
				changed = append(changed, "adminPermissions")
			}
		}

		if len(changed) > 0 {
			metadata, err := json.Marshal(map[string][]string{"fields": changed})
			if err != nil {
				return err
			}
			if err := tx.CreateAuditEvent(ctx, db.AuditEventParams{
				ID: uuid.New(), ActorID: &actorID, TargetAccountID: &id, Action: "admin_user_updated", Metadata: metadata,
			}); err != nil {
				return err
			}
		}

		row, err = tx.GetAdminRuntimeAccount(ctx, id)
		if err != nil {
			return err
		}
		if row == nil {
			return ErrUserNotFound
		}
		membership, err := tx.GetAdminMembership(ctx, id)
		if err != nil {
			return err
		}
		user := adminUserFromRuntime(*row)
		if membership != nil && membership.Active && membership.RevokedAt == nil {
			user.AdminPermissions = append([]string(nil), membership.Permissions...)
		}
		updated = &user
		return nil
	})
	return updated, err
}

func equalStrings(left, right []string) bool {
	if len(left) != len(right) {
		return false
	}
	for i := range left {
		if left[i] != right[i] {
			return false
		}
	}
	return true
}

func adminUserFromRuntime(row db.AdminRuntimeAccount) AdminUser {
	user := AdminUser{
		ID:                    row.ID,
		Username:              row.Username,
		Email:                 row.Email,
		EmailVerified:         row.EmailConfirmed,
		AccountActivated:      row.AccountActivated,
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
	if audience.Resource == AudienceAccounts {
		return s.queries.CountAdminRuntimeAccounts(ctx, runtimeAccountAudienceQuery(audience, 1, 0))
	}
	if audience.Resource == AudienceReports {
		return s.queries.CountAdminRuntimeReports(ctx, runtimeReportAudienceQuery(audience, 1, 0))
	}
	return 0, ErrInvalidAudience
}

func (s *ProductionAdminStore) ListAudienceMembers(ctx context.Context, _ uuid.UUID, audience Audience, action AdminAction, afterOrdinal int64, limit int) ([]AudienceMember, error) {
	if s == nil || s.queries == nil {
		return nil, ErrAdminRepositoryAbsent
	}
	if afterOrdinal < -1 || limit < 1 {
		return nil, ErrInvalidAudience
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
			if err := tx.AddAdminJobItem(ctx, db.AdminJobItemParams{ID: item.ID, JobID: job.ID, TargetID: item.TargetID, DeviceID: item.DeviceID, Outcome: item.Outcome, ErrorCode: stringPointer(item.ErrorCode), ProviderReference: stringPointer(item.ProviderReference)}); err != nil {
				return err
			}
		}
		return nil
	})
	if err != nil {
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
	if snapshot, err := s.GetAudienceSnapshot(ctx, *raw.SnapshotID); err == nil && snapshot != nil && snapshot.Action.Kind == raw.Action {
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
		page.Items = append(page.Items, AdminJobItem{ID: row.ID, JobID: row.JobID, TargetID: row.TargetID, DeviceID: row.DeviceID, Outcome: row.Outcome, ErrorCode: errorCode, ProviderReference: providerReference, AttemptCount: row.AttemptCount, CompletedAt: row.CompletedAt, CreatedAt: row.CreatedAt, UpdatedAt: row.UpdatedAt})
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
