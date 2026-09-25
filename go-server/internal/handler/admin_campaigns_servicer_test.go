package handler

import (
	"context"
	"net/http"
	"testing"

	"github.com/google/uuid"

	genserver "github.com/lrprojects/monaserver/internal/gen/server"
	"github.com/lrprojects/monaserver/internal/service"
)

func TestAdminCampaignsServicerEnforcesCapabilitiesCSRFAndLifecycle(t *testing.T) {
	actorID := uuid.New()
	csrf := "campaign-csrf"
	ctx := adminHandlerContext(actorID, csrf, "campaigns.read", "campaigns.write")
	servicer := NewAdminCampaignsServicer(service.NewCampaignService(service.NewMemoryCampaignStore()))
	subject := "September"

	created, err := servicer.CreateAdminCampaign(ctx, csrf, genserver.AdminCampaignCreateRequestDto{
		Name: "Newsletter", Channel: genserver.ADMINCAMPAIGNCHANNEL_EMAIL, Subject: &subject, Body: "Hello", Status: genserver.DRAFT,
	})
	if err != nil || created.Code != http.StatusCreated {
		t.Fatalf("create response = %#v, %v", created, err)
	}
	campaign, ok := created.Body.(genserver.AdminCampaignDto)
	if !ok || campaign.CreatedByUserId == nil || *campaign.CreatedByUserId != actorID.String() || campaign.Revision != 1 {
		t.Fatalf("create body = %#v", created.Body)
	}

	wrongCSRF, err := servicer.UpdateAdminCampaign(ctx, campaign.Id, "wrong", genserver.AdminCampaignUpdateRequestDto{
		Name: "Newsletter", Channel: genserver.ADMINCAMPAIGNCHANNEL_EMAIL, Subject: &subject, Body: "Hello {{login_link}}", Status: genserver.ACTIVE, ExpectedRevision: campaign.Revision,
	})
	if err != nil || wrongCSRF.Code != http.StatusForbidden {
		t.Fatalf("wrong csrf update = %#v, %v", wrongCSRF, err)
	}
	updated, err := servicer.UpdateAdminCampaign(ctx, campaign.Id, csrf, genserver.AdminCampaignUpdateRequestDto{
		Name: "Newsletter", Channel: genserver.ADMINCAMPAIGNCHANNEL_EMAIL, Subject: &subject, Body: "Hello {{login_link}}", Status: genserver.ACTIVE, ExpectedRevision: campaign.Revision,
	})
	if err != nil || updated.Code != http.StatusOK {
		t.Fatalf("update response = %#v, %v", updated, err)
	}
	active := updated.Body.(genserver.AdminCampaignDto)
	deleteActive, err := servicer.DeleteAdminCampaign(ctx, active.Id, csrf, genserver.AdminCampaignRevisionRequestDto{ExpectedRevision: active.Revision})
	if err != nil || deleteActive.Code != http.StatusConflict {
		t.Fatalf("delete active response = %#v, %v", deleteActive, err)
	}
	archived, err := servicer.ArchiveAdminCampaign(ctx, active.Id, csrf, genserver.AdminCampaignRevisionRequestDto{ExpectedRevision: active.Revision})
	if err != nil || archived.Code != http.StatusOK || archived.Body.(genserver.AdminCampaignDto).Status != genserver.ARCHIVED {
		t.Fatalf("archive response = %#v, %v", archived, err)
	}

	forbidden, err := servicer.ListAdminCampaigns(context.Background(), "", 25)
	if err != nil || forbidden.Code != http.StatusUnauthorized {
		t.Fatalf("list unauthenticated response = %#v, %v", forbidden, err)
	}
}
