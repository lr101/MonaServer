package handler

import (
	"context"
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
	_ genserver.AdminJobsAPIServicer      = (*UnavailableV3Servicer)(nil)
	_ genserver.AdminMessagesAPIServicer  = (*UnavailableV3Servicer)(nil)
	_ genserver.AdminReportsAPIServicer   = (*UnavailableV3Servicer)(nil)
	_ genserver.AdminSessionAPIServicer   = (*UnavailableV3Servicer)(nil)
	_ genserver.AdminUsersAPIServicer     = (*UnavailableV3Servicer)(nil)
	_ genserver.PublicAuthAPIServicer     = (*UnavailableV3Servicer)(nil)
	_ genserver.SessionAuthAPIServicer    = (*UnavailableV3Servicer)(nil)
)
