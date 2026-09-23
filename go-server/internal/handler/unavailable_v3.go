package handler

import (
	"context"
	"errors"
	"net/http"
	"time"

	genserver "github.com/lrprojects/monaserver/internal/gen/server"
)

// UnavailableV3Servicer is the safe pre-rollout adapter for the new v3
// contracts. The server bootstrap registers it behind explicit feature and
// session gates until the real v3 implementations are ready; every operation
// therefore returns a non-successful unavailable response.
type UnavailableV3Servicer struct{}

func NewUnavailableV3Servicer() *UnavailableV3Servicer { return &UnavailableV3Servicer{} }

// WriteV3Error emits the stable v3 error envelope used by route gates and
// the unavailable adapter. The route gates call it before a controller can
// parse input or invoke a service.
func WriteV3Error(w http.ResponseWriter, status int, code, message string) {
	_ = genserver.EncodeJSONResponse(genserver.ApiErrorDto{
		Code:    code,
		Message: message,
	}, &status, w)
}

// V3ErrorHandler is installed on every generated v3 controller. Generator
// defaults expose parser text and use 422 for required fields, while the v3
// contract uses a bounded 400 error for all malformed/invalid request bodies.
// Service errors are reduced to a small status-to-code/message vocabulary so
// raw input, credentials, and provider details never cross the HTTP boundary.
func V3ErrorHandler(w http.ResponseWriter, _ *http.Request, err error, result *genserver.ImplResponse) {
	var parsingErr *genserver.ParsingError
	var requiredErr *genserver.RequiredError
	if errors.As(err, &parsingErr) || errors.As(err, &requiredErr) {
		WriteV3Error(w, http.StatusBadRequest, "invalid_request", "request is invalid")
		return
	}

	status := http.StatusInternalServerError
	if result != nil {
		status = result.Code
	}
	if status == http.StatusUnprocessableEntity {
		status = http.StatusBadRequest
	}
	if status < http.StatusBadRequest || status > 599 {
		status = http.StatusInternalServerError
	}
	code, message := v3ErrorMetadata(status)
	WriteV3Error(w, status, code, message)
}

func v3ErrorMetadata(status int) (string, string) {
	switch status {
	case http.StatusBadRequest, http.StatusUnprocessableEntity:
		return "invalid_request", "request is invalid"
	case http.StatusUnauthorized:
		return "unauthorized", "authentication is required"
	case http.StatusForbidden:
		return "forbidden", "access is forbidden"
	case http.StatusNotFound:
		return "not_found", "resource was not found"
	case http.StatusConflict:
		return "conflict", "request conflicts with current state"
	case http.StatusTooManyRequests:
		return "rate_limited", "too many requests"
	case http.StatusServiceUnavailable:
		return "feature_unavailable", "this API is not available"
	default:
		return "internal_error", "internal server error"
	}
}

// UnavailableV3Middleware is the feature-flag gate for the pre-rollout v3
// surface. It deliberately does not call next, so disabled routes cannot
// execute a handler or return a successful placeholder mutation.
func UnavailableV3Middleware(_ http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		WriteV3Error(w, http.StatusServiceUnavailable, "feature_unavailable", "this API is not available")
	})
}

func (s *UnavailableV3Servicer) unavailable() (genserver.ImplResponse, error) {
	return genserver.ImplResponse{
		Code: http.StatusServiceUnavailable,
		Body: genserver.ApiErrorDto{
			Code:    "feature_unavailable",
			Message: "this API is not available",
		},
	}, nil
}

func (s *UnavailableV3Servicer) BootstrapAdminSession(context.Context) (genserver.ImplResponse, error) {
	return s.unavailable()
}

func (s *UnavailableV3Servicer) AdminSessionLogin(context.Context, string, genserver.AdminSessionLoginRequestDto) (genserver.ImplResponse, error) {
	return s.unavailable()
}

func (s *UnavailableV3Servicer) CompleteAdminSessionMfa(context.Context, string, genserver.AdminMfaRequestDto) (genserver.ImplResponse, error) {
	return s.unavailable()
}

func (s *UnavailableV3Servicer) ReauthenticateAdminSession(context.Context, string, genserver.AdminReauthenticateRequestDto) (genserver.ImplResponse, error) {
	return s.unavailable()
}

func (s *UnavailableV3Servicer) LogoutAdminSession(context.Context, string) (genserver.ImplResponse, error) {
	return s.unavailable()
}

func (s *UnavailableV3Servicer) GetAdminSession(context.Context) (genserver.ImplResponse, error) {
	return s.unavailable()
}

func (s *UnavailableV3Servicer) ListAdminUsers(context.Context, string, int32, string, genserver.AdminSecurityState, bool, time.Time, time.Time) (genserver.ImplResponse, error) {
	return s.unavailable()
}

func (s *UnavailableV3Servicer) GetAdminUser(context.Context, string) (genserver.ImplResponse, error) {
	return s.unavailable()
}

func (s *UnavailableV3Servicer) ListAdminCampaigns(context.Context, string, int32) (genserver.ImplResponse, error) {
	return s.unavailable()
}

func (s *UnavailableV3Servicer) CreateAdminCampaign(context.Context, string, genserver.AdminCampaignCreateRequestDto) (genserver.ImplResponse, error) {
	return s.unavailable()
}

func (s *UnavailableV3Servicer) GetAdminCampaign(context.Context, string) (genserver.ImplResponse, error) {
	return s.unavailable()
}

func (s *UnavailableV3Servicer) UpdateAdminCampaign(context.Context, string, string, genserver.AdminCampaignUpdateRequestDto) (genserver.ImplResponse, error) {
	return s.unavailable()
}

func (s *UnavailableV3Servicer) ArchiveAdminCampaign(context.Context, string, string, genserver.AdminCampaignRevisionRequestDto) (genserver.ImplResponse, error) {
	return s.unavailable()
}

func (s *UnavailableV3Servicer) DeleteAdminCampaign(context.Context, string, string, genserver.AdminCampaignRevisionRequestDto) (genserver.ImplResponse, error) {
	return s.unavailable()
}

func (s *UnavailableV3Servicer) PreviewAdminAudience(context.Context, string, genserver.AdminAudiencePreviewRequestDto) (genserver.ImplResponse, error) {
	return s.unavailable()
}

func (s *UnavailableV3Servicer) GetAdminAudience(context.Context, string, string, int32) (genserver.ImplResponse, error) {
	return s.unavailable()
}

func (s *UnavailableV3Servicer) ListAdminJobs(context.Context, string, int32, genserver.AdminJobStatus, genserver.AdminActionKind) (genserver.ImplResponse, error) {
	return s.unavailable()
}

func (s *UnavailableV3Servicer) CreateAdminJob(context.Context, string, string, genserver.AdminJobCreateRequestDto) (genserver.ImplResponse, error) {
	return s.unavailable()
}

func (s *UnavailableV3Servicer) GetAdminJob(context.Context, string) (genserver.ImplResponse, error) {
	return s.unavailable()
}

func (s *UnavailableV3Servicer) ListAdminJobRecipients(context.Context, string, string, int32) (genserver.ImplResponse, error) {
	return s.unavailable()
}

func (s *UnavailableV3Servicer) RetryAdminJob(context.Context, string, string, string, genserver.AdminJobCommandRequestDto) (genserver.ImplResponse, error) {
	return s.unavailable()
}

func (s *UnavailableV3Servicer) CancelAdminJob(context.Context, string, string, string, genserver.AdminJobCommandRequestDto) (genserver.ImplResponse, error) {
	return s.unavailable()
}

func (s *UnavailableV3Servicer) SendAdminTestMessage(context.Context, string, genserver.AdminTestMessageRequestDto) (genserver.ImplResponse, error) {
	return s.unavailable()
}

func (s *UnavailableV3Servicer) ListAdminReports(context.Context, string, int32, genserver.AdminReportStatus, string) (genserver.ImplResponse, error) {
	return s.unavailable()
}

func (s *UnavailableV3Servicer) GetAdminReport(context.Context, string, int64) (genserver.ImplResponse, error) {
	return s.unavailable()
}

func (s *UnavailableV3Servicer) ListAdminReportNotes(context.Context, string, string, int32) (genserver.ImplResponse, error) {
	return s.unavailable()
}

func (s *UnavailableV3Servicer) UpdateAdminReport(context.Context, string, string, genserver.AdminReportUpdateRequestDto) (genserver.ImplResponse, error) {
	return s.unavailable()
}

func (s *UnavailableV3Servicer) AddAdminReportNote(context.Context, string, string, genserver.AdminReportNoteRequestDto) (genserver.ImplResponse, error) {
	return s.unavailable()
}

func (s *UnavailableV3Servicer) ListAdminAudit(context.Context, string, int32, string, genserver.AdminActionKind) (genserver.ImplResponse, error) {
	return s.unavailable()
}

func (s *UnavailableV3Servicer) RequestEmailLink(context.Context, genserver.EmailLinkRequestDto) (genserver.ImplResponse, error) {
	return s.unavailable()
}

func (s *UnavailableV3Servicer) ExchangeEmailLink(context.Context, genserver.EmailLinkExchangeRequestDto) (genserver.ImplResponse, error) {
	return s.unavailable()
}

func (s *UnavailableV3Servicer) CompleteRecovery(context.Context, genserver.RecoveryCompleteRequestDto) (genserver.ImplResponse, error) {
	return s.unavailable()
}

func (s *UnavailableV3Servicer) RevokeOwnSession(context.Context, genserver.SessionRevokeRequestDto) (genserver.ImplResponse, error) {
	return s.unavailable()
}

var (
	_ genserver.AdminAudiencesAPIServicer = (*UnavailableV3Servicer)(nil)
	_ genserver.AdminAuditAPIServicer     = (*UnavailableV3Servicer)(nil)
	_ genserver.AdminCampaignsAPIServicer = (*UnavailableV3Servicer)(nil)
	_ genserver.AdminJobsAPIServicer      = (*UnavailableV3Servicer)(nil)
	_ genserver.AdminMessagesAPIServicer  = (*UnavailableV3Servicer)(nil)
	_ genserver.AdminReportsAPIServicer   = (*UnavailableV3Servicer)(nil)
	_ genserver.AdminSessionAPIServicer   = (*UnavailableV3Servicer)(nil)
	_ genserver.AdminUsersAPIServicer     = (*UnavailableV3Servicer)(nil)
	_ genserver.PublicAuthAPIServicer     = (*UnavailableV3Servicer)(nil)
	_ genserver.SessionAuthAPIServicer    = (*UnavailableV3Servicer)(nil)
)
