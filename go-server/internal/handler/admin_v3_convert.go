package handler

import (
	"context"
	"net/http"
	"strings"
	"time"

	"github.com/google/uuid"

	"github.com/lrprojects/monaserver/internal/apperrors"
	genserver "github.com/lrprojects/monaserver/internal/gen/server"
	"github.com/lrprojects/monaserver/internal/middleware"
	"github.com/lrprojects/monaserver/internal/service"
)

func adminActor(ctx context.Context) (service.AdminActor, error) {
	actor, ok := service.AdminActorFromContext(ctx)
	if !ok {
		return service.AdminActor{}, service.ErrAudienceUnauthorized
	}
	return actor, nil
}

func adminMutationActor(ctx context.Context, csrf string) (service.AdminActor, error) {
	principal, ok := middleware.AdminPrincipalFromContext(ctx)
	if !ok {
		return service.AdminActor{}, service.ErrAudienceUnauthorized
	}
	if !middleware.CSRFMatches(principal.CSRFHash, strings.TrimSpace(csrf)) {
		return service.AdminActor{}, service.ErrAdminInvalidCSRF
	}
	return adminActor(ctx)
}

func adminResponse(ctx context.Context, err error) (genserver.ImplResponse, error) {
	if err == nil {
		return genserver.Response(http.StatusInternalServerError, nil), nil
	}
	status := apperrors.HTTPStatus(err)
	if status < http.StatusBadRequest || status > 599 {
		status = http.StatusInternalServerError
	}
	code, message := v3ErrorMetadata(status)
	return genserver.Response(status, genserver.ApiErrorDto{Code: code, Message: message}), nil
}

func parseAdminUUID(value string) (uuid.UUID, error) {
	id, err := uuid.Parse(strings.TrimSpace(value))
	if err != nil || id == uuid.Nil {
		return uuid.Nil, service.ErrInvalidAudience
	}
	return id, nil
}

func fromAdminAction(dto genserver.AdminAction) service.AdminAction {
	action := service.AdminAction{
		Kind: string(dto.Action), Body: dto.Body, Subject: dto.Subject,
		Reason: dto.Reason, Title: dto.Title,
	}
	if dto.MessageHtml != nil {
		action.MessageHTML = *dto.MessageHtml
	}
	if dto.Note != nil {
		action.Note = *dto.Note
	}
	return action
}

func toAdminAction(action service.AdminAction) genserver.AdminAction {
	dto := genserver.AdminAction{
		Action: genserver.AdminActionKind(action.Kind), Body: action.Body,
		Subject: action.Subject, Reason: action.Reason, Title: action.Title,
	}
	if action.MessageHTML != "" {
		value := action.MessageHTML
		dto.MessageHtml = &value
	}
	if action.Note != "" {
		value := action.Note
		dto.Note = &value
	}
	return dto
}

func fromAdminAudience(dto genserver.AdminAudience) (service.Audience, error) {
	audience := service.Audience{Kind: service.AudienceKind(dto.Kind), Resource: service.AudienceResource(dto.Resource)}
	for _, rawID := range dto.Ids {
		id, err := parseAdminUUID(rawID)
		if err != nil {
			return service.Audience{}, err
		}
		audience.IDs = append(audience.IDs, id)
	}
	if dto.Filter == nil {
		return audience, nil
	}
	filter := dto.Filter
	audience.Filter = &service.AudienceFilter{
		Resource: service.AudienceResource(filter.Resource), Username: cloneStringValue(filter.Username),
		Email: cloneStringValue(filter.Email), ID: cloneStringValue(filter.Id),
		IncludeAdmins: valueOrFalse(filter.IncludeAdmins), VerifiedEmail: cloneBoolValue(filter.VerifiedEmail),
		CreatedAfter: cloneTimeValue(filter.CreatedAfter), CreatedBefore: cloneTimeValue(filter.CreatedBefore),
	}
	for _, state := range derefSecurityStates(filter.SecurityStatuses) {
		audience.Filter.SecurityStatuses = append(audience.Filter.SecurityStatuses, string(state))
	}
	for _, status := range derefReportStatuses(filter.Statuses) {
		audience.Filter.Statuses = append(audience.Filter.Statuses, string(status))
	}
	audience.Filter.Types = append([]string(nil), derefStrings(filter.Types)...)
	if filter.AssigneeUserId != nil {
		id, err := parseAdminUUID(*filter.AssigneeUserId)
		if err != nil {
			return service.Audience{}, err
		}
		audience.Filter.AssigneeUserID = &id
	}
	return audience, nil
}

func cloneStringValue(value *string) *string {
	if value == nil {
		return nil
	}
	copy := *value
	return &copy
}

func uuidStringPtr(value *uuid.UUID) *string {
	if value == nil {
		return nil
	}
	formatted := value.String()
	return &formatted
}

func cloneBoolValue(value *bool) *bool {
	if value == nil {
		return nil
	}
	copy := *value
	return &copy
}

func cloneTimeValue(value *time.Time) *time.Time {
	if value == nil {
		return nil
	}
	copy := value.UTC()
	return &copy
}

func valueOrFalse(value *bool) bool {
	return value != nil && *value
}

func derefSecurityStates(value *[]genserver.AdminSecurityState) []genserver.AdminSecurityState {
	if value == nil {
		return nil
	}
	return append([]genserver.AdminSecurityState(nil), (*value)...)
}

func derefReportStatuses(value *[]genserver.AdminReportStatus) []genserver.AdminReportStatus {
	if value == nil {
		return nil
	}
	return append([]genserver.AdminReportStatus(nil), (*value)...)
}

func derefStrings(value *[]string) []string {
	if value == nil {
		return nil
	}
	return append([]string(nil), (*value)...)
}

func toAudienceCounts(account, eligible, devices, excluded int64) genserver.AdminAudienceCountsDto {
	return genserver.AdminAudienceCountsDto{
		AccountAudienceCount: account, EligibleRecipientCount: eligible,
		DeviceDeliveryCount: devices, ExcludedCount: excluded,
	}
}

func toAudienceMember(member service.AudienceMember) genserver.AdminAudienceMemberDto {
	dto := genserver.AdminAudienceMemberDto{Id: member.ResourceID.String(), Resource: genserver.AudienceResourceKind(member.Resource), Eligible: member.Eligible}
	if member.ExclusionCode != "" {
		reason := member.ExclusionCode
		dto.Reason = &reason
	}
	return dto
}

func toAudienceExclusion(member service.AudienceMember) genserver.AdminAudienceExclusionDto {
	return genserver.AdminAudienceExclusionDto{Id: member.ResourceID.String(), Resource: genserver.AudienceResourceKind(member.Resource), Reason: member.ExclusionCode}
}

func toAudiencePreview(preview *service.AudiencePreview) genserver.AdminAudiencePreviewResponseDto {
	dto := genserver.AdminAudiencePreviewResponseDto{SnapshotId: preview.SnapshotID.String(), Status: preview.Status}
	actorID := preview.ActorID.String()
	dto.ActorUserId = &actorID
	resource := genserver.AudienceResourceKind(preview.Resource)
	dto.Resource = &resource
	expires := preview.ExpiresAt
	dto.ExpiresAt = &expires
	hash := preview.PayloadHash
	dto.PayloadHash = &hash
	action := toAdminAction(preview.Action)
	dto.Action = &action
	if preview.Status == service.AudienceSnapshotPending {
		if preview.PendingJobID != uuid.Nil {
			jobID := preview.PendingJobID.String()
			dto.JobId = &jobID
		}
		return dto
	}
	dto.Counts = ptrAudienceCounts(toAudienceCounts(preview.AccountCount, preview.EligibleCount, preview.DeviceCount, preview.ExclusionCount))
	exclusions := make([]genserver.AdminAudienceExclusionDto, 0, len(preview.Exclusions))
	for _, exclusion := range preview.Exclusions {
		exclusions = append(exclusions, toAudienceExclusion(exclusion))
	}
	dto.Exclusions = &exclusions
	return dto
}

func ptrAudienceCounts(value genserver.AdminAudienceCountsDto) *genserver.AdminAudienceCountsDto {
	return &value
}

func toAudiencePage(page *service.AudiencePage) genserver.AdminAudiencePageDto {
	dto := genserver.AdminAudiencePageDto{
		Counts:    toAudienceCounts(page.Snapshot.AccountCount, page.Snapshot.EligibleCount, page.Snapshot.DeviceCount, page.Snapshot.ExclusionCount),
		ExpiresAt: page.Snapshot.ExpiresAt, SnapshotId: page.Snapshot.ID.String(), Status: page.Snapshot.Status,
		Items: make([]genserver.AdminAudienceMemberDto, 0, len(page.Items)),
	}
	for _, item := range page.Items {
		dto.Items = append(dto.Items, toAudienceMember(item))
	}
	for _, exclusion := range page.Snapshot.Exclusions {
		dto.Exclusions = append(dto.Exclusions, toAudienceExclusion(exclusion))
	}
	dto.NextCursor = page.Next
	return dto
}

func toAdminUser(user service.AdminUser) genserver.AdminUserDto {
	return genserver.AdminUserDto{
		Id: user.ID.String(), Username: user.Username, Email: cloneStringValue(user.Email), EmailVerified: user.EmailVerified,
		CreatedAt: user.CreatedAt, SecurityState: genserver.AdminSecurityState(user.SecurityState), AuthGeneration: user.AuthGeneration,
		PasswordDisabled: user.PasswordDisabled, PasswordResetRequired: user.PasswordResetRequired,
		IsAdmin: user.IsAdmin, CompromisedAt: cloneTimeValue(user.CompromisedAt), EligibilityReasons: append([]string(nil), user.EligibilityReasons...),
	}
}

func toAdminUserDetails(user service.AdminUser) genserver.AdminUserDetailsDto {
	return genserver.AdminUserDetailsDto{
		Id: user.ID.String(), Username: user.Username, Email: cloneStringValue(user.Email), EmailVerified: user.EmailVerified,
		CreatedAt: user.CreatedAt, SecurityState: genserver.AdminSecurityState(user.SecurityState), AuthGeneration: user.AuthGeneration,
		PasswordDisabled: user.PasswordDisabled, PasswordResetRequired: user.PasswordResetRequired,
		IsAdmin: user.IsAdmin, CompromisedAt: cloneTimeValue(user.CompromisedAt), EligibilityReasons: append([]string(nil), user.EligibilityReasons...),
		CommunicationOptOut: user.CommunicationOptOut, RegisteredDeviceCount: user.RegisteredDeviceCount,
	}
}

func toAdminJob(job service.AdminJob) genserver.AdminJobDto {
	excluded := job.AccountCount - job.EligibleCount
	if excluded < 0 {
		excluded = 0
	}
	return genserver.AdminJobDto{
		Action: toAdminAction(job.Action), ActorUserId: job.ActorID.String(), CancellationRequested: job.CancellationRequested,
		Counts: toAudienceCounts(job.AccountCount, job.EligibleCount, job.DeviceCount, excluded), CreatedAt: job.CreatedAt,
		JobId: job.ID.String(), SnapshotId: job.SnapshotID.String(), Status: genserver.AdminJobStatus(job.Status), UpdatedAt: job.UpdatedAt,
	}
}

func toAdminRecipient(item service.AdminJobItem) genserver.AdminJobRecipientDto {
	dto := genserver.AdminJobRecipientDto{AccountId: item.TargetID.String(), AttemptCount: item.AttemptCount, DeviceCount: item.DeviceCount, Outcome: item.Outcome, LastAttemptAt: cloneTimeValue(item.LastAttemptAt)}
	if item.Reason != "" {
		reason := item.Reason
		dto.Reason = &reason
	}
	return dto
}

func toAdminAudit(event service.AdminAuditEvent) genserver.AdminAuditEventDto {
	dto := genserver.AdminAuditEventDto{Action: genserver.AdminActionKind(event.Action), Details: map[string]string{}, Id: event.ID.String(), OccurredAt: event.OccurredAt, Outcome: event.Outcome}
	for key, value := range event.Details {
		dto.Details[key] = value
	}
	if event.ActorID != nil {
		id := event.ActorID.String()
		dto.ActorUserId = &id
	}
	if event.TargetID != nil {
		id := event.TargetID.String()
		dto.TargetUserId = &id
	}
	if event.Reason != nil {
		reason := *event.Reason
		dto.Reason = &reason
	}
	return dto
}
