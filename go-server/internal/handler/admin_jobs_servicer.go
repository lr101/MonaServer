package handler

import (
	"context"
	"net/http"

	genserver "github.com/lrprojects/monaserver/internal/gen/server"
	"github.com/lrprojects/monaserver/internal/service"
)

// AdminJobsServicer maps durable, idempotent bulk jobs to the v3 contract.
// CSRF and capability checks remain at this edge as well as in the service so
// direct composition cannot turn a generated method into an authorization
// bypass.
type AdminJobsServicer struct {
	jobs *service.AdminBulkService
}

type AdminJobServicer = AdminJobsServicer

func NewAdminJobsServicer(jobs *service.AdminBulkService) *AdminJobsServicer {
	return &AdminJobsServicer{jobs: jobs}
}

func NewAdminJobServicer(jobs *service.AdminBulkService) *AdminJobsServicer {
	return NewAdminJobsServicer(jobs)
}

func (s *AdminJobsServicer) ListAdminJobs(ctx context.Context, cursor string, limit int32, status genserver.AdminJobStatus, action genserver.AdminActionKind) (genserver.ImplResponse, error) {
	if s == nil || s.jobs == nil {
		return adminResponse(ctx, service.ErrAdminRepositoryAbsent)
	}
	actor, err := adminActor(ctx)
	if err != nil {
		return adminResponse(ctx, err)
	}
	page, err := s.jobs.List(ctx, actor, cursor, int(limit), string(status), string(action))
	if err != nil {
		return adminResponse(ctx, err)
	}
	body := genserver.AdminJobPageDto{Items: make([]genserver.AdminJobDto, 0, len(page.Items)), NextCursor: page.Next}
	for _, job := range page.Items {
		body.Items = append(body.Items, toAdminJob(job))
	}
	return genserver.Response(http.StatusOK, body), nil
}

func (s *AdminJobsServicer) CreateAdminJob(ctx context.Context, csrf, idempotencyKey string, request genserver.AdminJobCreateRequestDto) (genserver.ImplResponse, error) {
	if s == nil || s.jobs == nil {
		return adminResponse(ctx, service.ErrAdminRepositoryAbsent)
	}
	actor, err := adminMutationActor(ctx, csrf)
	if err != nil {
		return adminResponse(ctx, err)
	}
	snapshotID, err := parseAdminUUID(request.SnapshotId)
	if err != nil {
		return adminResponse(ctx, err)
	}
	job, err := s.jobs.Create(ctx, actor, service.AdminJobCreateRequest{
		SnapshotID: snapshotID, PayloadHash: request.PayloadHash, Action: fromAdminAction(request.Action), IdempotencyKey: idempotencyKey,
	})
	if err != nil {
		return adminResponse(ctx, err)
	}
	return genserver.Response(http.StatusAccepted, genserver.AdminJobAcceptedDto{JobId: job.ID.String(), Status: genserver.AdminJobStatus(job.Status)}), nil
}

func (s *AdminJobsServicer) GetAdminJob(ctx context.Context, jobID string) (genserver.ImplResponse, error) {
	if s == nil || s.jobs == nil {
		return adminResponse(ctx, service.ErrAdminRepositoryAbsent)
	}
	actor, err := adminActor(ctx)
	if err != nil {
		return adminResponse(ctx, err)
	}
	id, err := parseAdminUUID(jobID)
	if err != nil {
		return adminResponse(ctx, err)
	}
	job, err := s.jobs.Get(ctx, actor, id)
	if err != nil {
		return adminResponse(ctx, err)
	}
	return genserver.Response(http.StatusOK, toAdminJob(*job)), nil
}

func (s *AdminJobsServicer) ListAdminJobRecipients(ctx context.Context, jobID, cursor string, limit int32) (genserver.ImplResponse, error) {
	if s == nil || s.jobs == nil {
		return adminResponse(ctx, service.ErrAdminRepositoryAbsent)
	}
	actor, err := adminActor(ctx)
	if err != nil {
		return adminResponse(ctx, err)
	}
	id, err := parseAdminUUID(jobID)
	if err != nil {
		return adminResponse(ctx, err)
	}
	page, err := s.jobs.Recipients(ctx, actor, id, cursor, int(limit))
	if err != nil {
		return adminResponse(ctx, err)
	}
	body := genserver.AdminJobRecipientPageDto{Items: make([]genserver.AdminJobRecipientDto, 0, len(page.Items)), NextCursor: page.Next}
	for _, item := range page.Items {
		body.Items = append(body.Items, toAdminRecipient(item))
	}
	return genserver.Response(http.StatusOK, body), nil
}

func (s *AdminJobsServicer) RetryAdminJob(ctx context.Context, jobID, csrf, idempotencyKey string, request genserver.AdminJobCommandRequestDto) (genserver.ImplResponse, error) {
	return s.command(ctx, jobID, csrf, idempotencyKey, request, true)
}

func (s *AdminJobsServicer) CancelAdminJob(ctx context.Context, jobID, csrf, idempotencyKey string, request genserver.AdminJobCommandRequestDto) (genserver.ImplResponse, error) {
	return s.command(ctx, jobID, csrf, idempotencyKey, request, false)
}

func (s *AdminJobsServicer) command(ctx context.Context, jobID, csrf, idempotencyKey string, request genserver.AdminJobCommandRequestDto, retry bool) (genserver.ImplResponse, error) {
	actor, err := adminMutationActor(ctx, csrf)
	if err != nil {
		return adminResponse(ctx, err)
	}
	id, err := parseAdminUUID(jobID)
	if err != nil {
		return adminResponse(ctx, err)
	}
	reason := ""
	if request.Reason != nil {
		reason = *request.Reason
	}
	command := service.AdminJobCommand{JobID: id, ActorID: actor.ID, IdempotencyKey: idempotencyKey, Reason: reason}
	var job *service.AdminJob
	if retry {
		job, err = s.jobs.Retry(ctx, actor, command)
	} else {
		job, err = s.jobs.Cancel(ctx, actor, command)
	}
	if err != nil {
		return adminResponse(ctx, err)
	}
	return genserver.Response(http.StatusAccepted, genserver.AdminJobAcceptedDto{JobId: job.ID.String(), Status: genserver.AdminJobStatus(job.Status)}), nil
}

var _ genserver.AdminJobsAPIServicer = (*AdminJobsServicer)(nil)
