package handler

import (
	"context"
	"encoding/json"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"

	genserver "github.com/lrprojects/monaserver/internal/gen/server"
	"github.com/lrprojects/monaserver/internal/middleware"
	"github.com/lrprojects/monaserver/internal/service"
)

func TestAdminAudienceServicerBindsCSRFAndReturnsSanitizedPreview(t *testing.T) {
	store := service.NewMemoryAdminStore()
	userID := uuid.New()
	email := "alice@example.com"
	store.Users = append(store.Users, service.AdminUser{ID: userID, Username: "alice", Email: &email, EmailVerified: true})
	actorID := uuid.New()
	csrf := "csrf-preview"
	ctx := adminHandlerContext(actorID, csrf, "audience.preview", "campaign.email", "audience.read", "jobs.create")

	svc := NewAdminAudienceServicer(service.NewAdminAudienceService(store))
	html := "<p>Hello</p><script>steal()</script>"
	response, err := svc.PreviewAdminAudience(ctx, csrf, genserver.AdminAudiencePreviewRequestDto{
		Audience: genserver.AdminAudience{Kind: genserver.SELECTED, Resource: genserver.ACCOUNTS, Ids: []string{userID.String()}},
		Action:   genserver.AdminAction{Action: genserver.EMAIL, Subject: "Notice", Body: "Hello", MessageHtml: &html},
	})
	if err != nil || response.Code != 200 {
		t.Fatalf("preview response = %#v, %v", response, err)
	}
	body, ok := response.Body.(genserver.AdminAudiencePreviewResponseDto)
	if !ok || body.SnapshotId == "" || body.PayloadHash == nil || body.Action == nil {
		t.Fatalf("unexpected preview body: %#v", response.Body)
	}
	encoded, err := json.Marshal(body.Action)
	if err != nil || strings.Contains(string(encoded), "steal") {
		t.Fatalf("unsafe preview action: %s (%v)", encoded, err)
	}

	readResponse, err := svc.GetAdminAudience(ctx, body.SnapshotId, "", 25)
	if err != nil || readResponse.Code != 200 {
		t.Fatalf("read response = %#v, %v", readResponse, err)
	}
}

func TestAdminJobServicerRequiresCSRFAndUsesIdempotentCommit(t *testing.T) {
	store := service.NewMemoryAdminStore()
	userID := uuid.New()
	email := "alice@example.com"
	store.Users = append(store.Users, service.AdminUser{ID: userID, Username: "alice", Email: &email, EmailVerified: true})
	actorID := uuid.New()
	csrf := "csrf-job"
	ctx := adminHandlerContext(actorID, csrf, "audience.preview", "campaign.email", "audience.read", "jobs.create", "jobs.read")
	audience := service.NewAdminAudienceService(store)
	audienceHandler := NewAdminAudienceServicer(audience)
	previewResponse, err := audienceHandler.PreviewAdminAudience(ctx, csrf, genserver.AdminAudiencePreviewRequestDto{
		Audience: genserver.AdminAudience{Kind: genserver.SELECTED, Resource: genserver.ACCOUNTS, Ids: []string{userID.String()}},
		Action:   genserver.AdminAction{Action: genserver.EMAIL, Subject: "Notice", Body: "Hello"},
	})
	if err != nil {
		t.Fatalf("preview: %v", err)
	}
	preview := previewResponse.Body.(genserver.AdminAudiencePreviewResponseDto)
	jobs := NewAdminJobsServicer(service.NewAdminBulkService(store, audience, &service.AdminActionPorts{Email: handlerTestEmailSender{}}))
	request := genserver.AdminJobCreateRequestDto{SnapshotId: preview.SnapshotId, PayloadHash: *preview.PayloadHash, Action: *preview.Action}
	if _, err := jobs.CreateAdminJob(ctx, "wrong-csrf", "job-key", request); err != nil {
		t.Fatalf("wrong csrf returned transport error: %v", err)
	}
	wrong, _ := jobs.CreateAdminJob(ctx, "wrong-csrf", "job-key", request)
	if wrong.Code != 403 {
		t.Fatalf("wrong csrf status = %d, want 403", wrong.Code)
	}
	if body, ok := wrong.Body.(genserver.ApiErrorDto); !ok || body.Code != "forbidden" || strings.Contains(body.Message, "csrf") {
		t.Fatalf("unsafe csrf error body: %#v", wrong.Body)
	}
	accepted, err := jobs.CreateAdminJob(ctx, csrf, "job-key", request)
	if err != nil || accepted.Code != 202 {
		t.Fatalf("create = %#v, %v", accepted, err)
	}
	again, err := jobs.CreateAdminJob(ctx, csrf, "job-key", request)
	if err != nil || again.Code != 202 || again.Body.(genserver.AdminJobAcceptedDto).JobId != accepted.Body.(genserver.AdminJobAcceptedDto).JobId {
		t.Fatalf("idempotent create = %#v, %v", again, err)
	}
}

type handlerTestEmailSender struct{}

func (handlerTestEmailSender) SendCampaignEmail(context.Context, uuid.UUID, uuid.UUID, service.AdminAction) (service.ActionResult, error) {
	return service.ActionResult{Outcome: service.OutcomeProviderAccepted}, nil
}

func adminHandlerContext(actorID uuid.UUID, csrf string, capabilities ...string) context.Context {
	return middleware.WithAdminPrincipal(context.Background(), middleware.AdminPrincipal{
		UserID: actorID.String(), State: "authenticated", Capabilities: capabilities,
		CSRFHash: middleware.CSRFHash(csrf), RecentMFAAt: ptrHandlerTime(time.Now().UTC()),
	})
}

func ptrHandlerTime(value time.Time) *time.Time { return &value }
