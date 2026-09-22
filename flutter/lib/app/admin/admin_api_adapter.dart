import 'package:http/http.dart' as http;
import 'package:openapi/api.dart' as api;

import '../../features/admin_audience/domain/admin_audience_models.dart';
import '../../features/admin_audit/domain/admin_audit_models.dart';
import '../../features/admin_audit/domain/admin_audit_ports.dart';
import '../../features/admin_campaigns/domain/admin_campaign_models.dart';
import '../../features/admin_campaigns/domain/admin_campaign_ports.dart';
import '../../features/admin_jobs/domain/admin_job_models.dart';
import '../../features/admin_jobs/domain/admin_job_ports.dart';
import '../../features/admin_reports/domain/admin_report_models.dart';
import '../../features/admin_reports/domain/admin_report_ports.dart';
import '../../features/admin_security/domain/admin_security_models.dart';
import '../../features/admin_security/domain/admin_security_ports.dart';
import '../../features/admin_session/domain/admin_session_models.dart';
import '../../features/admin_session/domain/admin_session_ports.dart';
import '../../features/admin_users/domain/admin_user_models.dart';
import '../../features/admin_users/domain/admin_user_ports.dart';
import 'admin_http_client.dart';

/// Generated-client adapter for the admin-only transport boundary.
///
/// The adapter owns one HTTP client and the in-memory CSRF value. It uses the
/// server's host-only opaque cookie and never constructs or persists consumer
/// JWT/refresh credentials.
final class AdminApiAdapter
    implements
        AdminSessionTransport,
        AdminUsersRepository,
        AdminReportsRepository,
        AdminCampaignRepository,
        AdminJobsRepository,
        AdminSecurityRepository,
        AdminAuditRepository {
  AdminApiAdapter({required String basePath, http.Client? client})
    : _ownsClient = client == null,
      _client = client ?? createAdminHttpClient(),
      _apiClient = api.ApiClient(basePath: basePath) {
    _apiClient.client = _client;
    _sessionApi = api.AdminSessionApi(_apiClient);
    _usersApi = api.AdminUsersApi(_apiClient);
    _reportsApi = api.AdminReportsApi(_apiClient);
    _audiencesApi = api.AdminAudiencesApi(_apiClient);
    _messagesApi = api.AdminMessagesApi(_apiClient);
    _jobsApi = api.AdminJobsApi(_apiClient);
    _auditApi = api.AdminAuditApi(_apiClient);
  }

  final bool _ownsClient;
  final http.Client _client;
  final api.ApiClient _apiClient;
  late final api.AdminSessionApi _sessionApi;
  late final api.AdminUsersApi _usersApi;
  late final api.AdminReportsApi _reportsApi;
  late final api.AdminAudiencesApi _audiencesApi;
  late final api.AdminMessagesApi _messagesApi;
  late final api.AdminJobsApi _jobsApi;
  late final api.AdminAuditApi _auditApi;
  String? _csrfToken;
  bool _closed = false;

  @override
  Future<AdminBootstrap> bootstrap() async {
    _checkOpen();
    try {
      final response = await _sessionApi.bootstrapAdminSession();
      if (response == null) throw const AdminTransportException(502);
      if (response.csrfToken.trim().isEmpty) {
        throw const AdminTransportException(428);
      }
      _csrfToken = response.csrfToken;
      return AdminBootstrap(
        csrfToken: response.csrfToken,
        expiresAt: response.expiresAt,
      );
    } catch (error) {
      throw _mapSessionError(error);
    }
  }

  @override
  Future<AdminLoginChallenge> beginLogin({
    required String username,
    required String password,
  }) async {
    _checkOpen();
    try {
      var csrfToken = _csrfToken;
      // Logout and an expired session deliberately clear the in-memory CSRF
      // value. A login is allowed to start a fresh pre-auth cookie lifecycle
      // instead of surfacing an opaque "precondition" failure to the user.
      if (csrfToken == null || csrfToken.isEmpty) {
        final bootstrap = await this.bootstrap();
        if (bootstrap.csrfToken.isEmpty) {
          throw const AdminTransportException(428);
        }
        csrfToken = bootstrap.csrfToken;
      }
      final response = await _sessionApi.adminSessionLogin(
        csrfToken,
        api.AdminSessionLoginRequestDto(username: username, password: password),
      );
      if (response == null) throw const AdminTransportException(502);
      _csrfToken = response.csrfToken;
      return AdminLoginChallenge(
        challengeId: response.challengeId,
        expiresAt: response.expiresAt,
      );
    } catch (error) {
      throw _mapSessionError(error);
    }
  }

  @override
  Future<AdminSessionSnapshot> completeMfa({
    required String challengeId,
    required String code,
  }) async {
    _checkOpen();
    final csrfToken = _csrfToken;
    if (csrfToken == null || csrfToken.isEmpty) {
      throw const AdminTransportException(428);
    }
    try {
      final response = await _sessionApi.completeAdminSessionMfa(
        csrfToken,
        api.AdminMfaRequestDto(challengeId: challengeId, code: code),
      );
      if (response == null) throw const AdminTransportException(502);
      _csrfToken = response.csrfToken;
      return _sessionFromDto(response);
    } catch (error) {
      throw _mapSessionError(error);
    }
  }

  @override
  Future<AdminSessionSnapshot?> restore() async {
    _checkOpen();
    try {
      final response = await _sessionApi.getAdminSession();
      if (response == null) return null;
      _csrfToken = response.csrfToken;
      return _sessionFromDto(response);
    } catch (error) {
      throw _mapSessionError(error);
    }
  }

  @override
  Future<void> logout() async {
    if (_closed) return;
    final csrfToken = _csrfToken;
    _csrfToken = null;
    if (csrfToken == null || csrfToken.isEmpty) return;
    try {
      await _sessionApi.logoutAdminSession(csrfToken);
    } catch (error) {
      throw _mapSessionError(error);
    }
  }

  @override
  Future<AdminUserPage> listUsers(AdminUserQuery query) async {
    _checkOpen();
    try {
      final response = await _usersApi.listAdminUsers(
        cursor: query.cursor,
        limit: query.limit,
        search: query.search.isEmpty ? null : query.search,
      );
      if (response == null) throw const AdminUsersTransportException(502);
      return AdminUserPage(
        items: response.items.map(_userFromDto).toList(growable: false),
        nextCursor: response.nextCursor,
      );
    } catch (error) {
      throw _mapUsersError(error);
    }
  }

  @override
  Future<AdminUserDetails?> getUser(String userId) async {
    _checkOpen();
    try {
      final response = await _usersApi.getAdminUser(userId);
      return response == null ? null : _detailsFromDto(response);
    } catch (error) {
      throw _mapUsersError(error);
    }
  }

  @override
  Future<AdminReportPage> listReports(AdminReportQuery query) async {
    _checkOpen();
    try {
      final response = await _reportsApi.listAdminReports(
        cursor: query.cursor,
        limit: query.limit,
        search: query.search.isEmpty ? null : query.search,
        status: query.status == null ? null : _reportStatusDto(query.status!),
      );
      if (response == null) throw const AdminReportsTransportException(502);
      return AdminReportPage(
        items: response.items.map(_reportFromDto).toList(growable: false),
        nextCursor: response.nextCursor,
      );
    } catch (error) {
      throw _mapReportsError(error);
    }
  }

  @override
  Future<AdminReport?> get(String reportId) async {
    _checkOpen();
    try {
      final response = await _reportsApi.getAdminReport(reportId);
      return response == null ? null : _reportFromDto(response);
    } catch (error) {
      throw _mapReportsError(error);
    }
  }

  @override
  Future<AdminReport> update(AdminReportUpdate update) async {
    _checkOpen();
    try {
      final response = await _reportsApi.updateAdminReport(
        update.reportId,
        _reportsCsrf(),
        api.AdminReportUpdateRequestDto(
          expectedRevision: update.expectedRevision,
          status: _reportStatusDto(update.status),
          assigneeUserId: update.clearAssignee ? null : update.assigneeUserId,
          note: update.note,
        ),
      );
      if (response == null) throw const AdminReportsTransportException(502);
      return _reportFromDto(response);
    } catch (error) {
      throw _mapReportsError(error);
    }
  }

  @override
  Future<AdminReportNote> addNote(String reportId, String text) async {
    _checkOpen();
    try {
      final response = await _reportsApi.addAdminReportNote(
        reportId,
        _reportsCsrf(),
        api.AdminReportNoteRequestDto(text: text),
      );
      if (response == null) throw const AdminReportsTransportException(502);
      return _noteFromDto(response);
    } catch (error) {
      throw _mapReportsError(error);
    }
  }

  @override
  Future<AdminReportBulkOutcome> commitBulk(
    AdminReportBulkCommand command,
  ) async {
    _checkOpen();
    try {
      final response = await _jobsApi.createAdminJob(
        _reportsCsrf(),
        command.idempotencyKey,
        _jobRequest(command.commit),
      );
      if (response == null) throw const AdminReportsTransportException(502);
      return AdminReportBulkOutcome.queued(jobId: response.jobId);
    } catch (error) {
      throw _mapReportsError(error);
    }
  }

  @override
  Future<AdminAudiencePreview> preview(
    AdminAudiencePreviewRequest request,
  ) async {
    _checkOpen();
    try {
      final response = await _audiencesApi.previewAdminAudience(
        _campaignCsrf(),
        api.AdminAudiencePreviewRequestDto(
          audience: _audienceDto(request.audience),
          action: _actionDto(request.action),
        ),
      );
      if (response == null) throw const AdminCampaignTransportException(502);
      return _previewFromDto(response, request);
    } catch (error) {
      // Preview is shared by reports and campaigns. Its port's callers only
      // distinguish their own typed errors, so preserve the campaign error for
      // campaign calls and convert it at the reports call boundary below.
      throw _mapCampaignError(error);
    }
  }

  @override
  Future<AdminCampaignCommitResult> commit(
    AdminCampaignCommitCommand command,
  ) async {
    _checkOpen();
    try {
      final response = await _jobsApi.createAdminJob(
        _campaignCsrf(),
        command.idempotencyKey,
        _jobRequest(command.commit),
      );
      if (response == null) throw const AdminCampaignTransportException(502);
      return AdminCampaignCommitResult(jobId: response.jobId);
    } catch (error) {
      throw _mapCampaignError(error);
    }
  }

  @override
  Future<AdminCampaignTestResult> sendTest({
    required String recipientUserId,
    required AdminAudienceAction action,
  }) async {
    _checkOpen();
    try {
      final response = await _messagesApi.sendAdminTestMessage(
        _campaignCsrf(),
        api.AdminTestMessageRequestDto(
          recipientUserId: recipientUserId,
          action: _actionDto(action),
        ),
      );
      if (response == null) throw const AdminCampaignTransportException(502);
      return response.accepted
          ? const AdminCampaignTestResult.accepted()
          : const AdminCampaignTestResult.unavailable();
    } catch (error) {
      throw _mapCampaignError(error);
    }
  }

  @override
  Future<AdminJobPage> listJobs(AdminJobQuery query) async {
    _checkOpen();
    try {
      final response = await _jobsApi.listAdminJobs(
        cursor: query.cursor,
        limit: query.limit,
      );
      if (response == null) throw const AdminJobsTransportException(502);
      return AdminJobPage(
        items: response.items.map(_jobFromDto).toList(growable: false),
        nextCursor: response.nextCursor,
      );
    } catch (error) {
      throw _mapJobsError(error);
    }
  }

  @override
  Future<AdminJobCommandResult> retry(AdminJobCommand command) =>
      _jobCommand(command, retry: true);

  @override
  Future<AdminJobCommandResult> cancel(AdminJobCommand command) =>
      _jobCommand(command, retry: false);

  Future<AdminJobCommandResult> _jobCommand(
    AdminJobCommand command, {
    required bool retry,
  }) async {
    _checkOpen();
    try {
      final request = api.AdminJobCommandRequestDto();
      final response = retry
          ? await _jobsApi.retryAdminJob(
              command.jobId,
              _jobsCsrf(),
              command.idempotencyKey,
              request,
            )
          : await _jobsApi.cancelAdminJob(
              command.jobId,
              _jobsCsrf(),
              command.idempotencyKey,
              request,
            );
      if (response == null) throw const AdminJobsTransportException(502);
      return AdminJobCommandResult(jobId: response.jobId);
    } catch (error) {
      throw _mapJobsError(error);
    }
  }

  @override
  Future<AdminSecurityResult> submit(AdminSecurityActionRequest request) async {
    _checkOpen();
    try {
      final preview = await _audiencesApi.previewAdminAudience(
        _securityCsrf(),
        api.AdminAudiencePreviewRequestDto(
          audience: _audienceDto(request.audience),
          action: _actionDto(request.request.action),
        ),
      );
      if (preview == null || preview.status.value != 'ready') {
        throw const AdminSecurityTransportException(409);
      }
      final payloadHash = preview.payloadHash;
      if (payloadHash == null || payloadHash.isEmpty) {
        throw const AdminSecurityTransportException(409);
      }
      final accepted = await _jobsApi.createAdminJob(
        _securityCsrf(),
        request.idempotencyKey,
        api.AdminJobCreateRequestDto(
          action: _actionDto(request.request.action),
          payloadHash: payloadHash,
          snapshotId: preview.snapshotId,
        ),
      );
      if (accepted == null) throw const AdminSecurityTransportException(502);
      return AdminSecurityResult(
        jobId: accepted.jobId,
        outcome: AdminSecurityOutcome.queued,
      );
    } catch (error) {
      throw _mapSecurityError(error);
    }
  }

  @override
  Future<AdminAuditPage> listAudit(AdminAuditQuery query) async {
    _checkOpen();
    try {
      final response = await _auditApi.listAdminAudit(
        cursor: query.cursor,
        limit: query.limit,
        targetUserId: query.targetUserId,
        action: query.action == null ? null : _auditActionDto(query.action!),
      );
      if (response == null) throw const AdminAuditTransportException(502);
      return AdminAuditPage(
        items: response.items.map(_auditFromDto).toList(growable: false),
        nextCursor: response.nextCursor,
      );
    } catch (error) {
      throw _mapAuditError(error);
    }
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _csrfToken = null;
    if (_ownsClient) _client.close();
  }

  void _checkOpen() {
    if (_closed) throw const AdminTransportException(499);
  }

  AdminTransportException _mapSessionError(Object error) {
    if (error is AdminTransportException) {
      if (error.isUnauthorized) _csrfToken = null;
      return error;
    }
    if (error is api.ApiException) {
      if (error.code == 401) _csrfToken = null;
      return AdminTransportException(error.code);
    }
    return const AdminTransportException(503);
  }

  AdminUsersTransportException _mapUsersError(Object error) {
    if (error is AdminUsersTransportException) {
      if (error.isUnauthorized) _csrfToken = null;
      return error;
    }
    if (error is api.ApiException) {
      if (error.code == 401) _csrfToken = null;
      return AdminUsersTransportException(error.code);
    }
    return const AdminUsersTransportException(503);
  }

  AdminReportsTransportException _mapReportsError(Object error) {
    if (error is AdminReportsTransportException) return error;
    if (error is api.ApiException) {
      if (error.code == 401) _csrfToken = null;
      return AdminReportsTransportException(error.code);
    }
    return const AdminReportsTransportException(503);
  }

  AdminCampaignTransportException _mapCampaignError(Object error) {
    if (error is AdminCampaignTransportException) return error;
    if (error is api.ApiException) {
      if (error.code == 401) _csrfToken = null;
      return AdminCampaignTransportException(error.code);
    }
    return const AdminCampaignTransportException(503);
  }

  AdminJobsTransportException _mapJobsError(Object error) {
    if (error is AdminJobsTransportException) return error;
    if (error is api.ApiException) {
      if (error.code == 401) _csrfToken = null;
      return AdminJobsTransportException(error.code);
    }
    return const AdminJobsTransportException(503);
  }

  AdminSecurityTransportException _mapSecurityError(Object error) {
    if (error is AdminSecurityTransportException) return error;
    if (error is api.ApiException) {
      if (error.code == 401) _csrfToken = null;
      return AdminSecurityTransportException(error.code);
    }
    return const AdminSecurityTransportException(503);
  }

  AdminAuditTransportException _mapAuditError(Object error) {
    if (error is AdminAuditTransportException) return error;
    if (error is api.ApiException) {
      if (error.code == 401) _csrfToken = null;
      return AdminAuditTransportException(error.code);
    }
    return const AdminAuditTransportException(503);
  }

  String _reportsCsrf() => _csrfToken?.trim().isNotEmpty == true
      ? _csrfToken!
      : throw const AdminReportsTransportException(428);
  String _campaignCsrf() => _csrfToken?.trim().isNotEmpty == true
      ? _csrfToken!
      : throw const AdminCampaignTransportException(428);
  String _jobsCsrf() => _csrfToken?.trim().isNotEmpty == true
      ? _csrfToken!
      : throw const AdminJobsTransportException(428);
  String _securityCsrf() => _csrfToken?.trim().isNotEmpty == true
      ? _csrfToken!
      : throw const AdminSecurityTransportException(428);

  api.AdminReportStatus _reportStatusDto(AdminReportStatus status) =>
      switch (status) {
        AdminReportStatus.open => api.AdminReportStatus.open,
        AdminReportStatus.resolved => api.AdminReportStatus.resolved,
        AdminReportStatus.dismissed => api.AdminReportStatus.dismissed,
      };

  AdminReportStatus _reportStatus(api.AdminReportStatus status) =>
      switch (status.value) {
        'resolved' => AdminReportStatus.resolved,
        'dismissed' => AdminReportStatus.dismissed,
        _ => AdminReportStatus.open,
      };

  api.AdminAction _actionDto(AdminAudienceAction action) => api.AdminAction(
    action: switch (action.kind) {
      AdminAudienceActionKind.email => api.AdminActionKind.email,
      AdminAudienceActionKind.loginLink => api.AdminActionKind.loginLink,
      AdminAudienceActionKind.push => api.AdminActionKind.push,
      AdminAudienceActionKind.revokeSessions =>
        api.AdminActionKind.revokeSessions,
      AdminAudienceActionKind.markCompromised =>
        api.AdminActionKind.markCompromised,
      AdminAudienceActionKind.recoveryResend =>
        api.AdminActionKind.recoveryResend,
      AdminAudienceActionKind.reportResolve =>
        api.AdminActionKind.reportResolve,
      AdminAudienceActionKind.reportDismiss =>
        api.AdminActionKind.reportDismiss,
    },
    body: action.body,
    messageHtml: action.messageHtml,
    subject: action.subject,
    reason: action.reason,
    title: action.title,
    note: action.note,
  );

  api.AdminActionKind _auditActionDto(String value) =>
      api.AdminActionKind.values.firstWhere(
        (action) => action.value == value,
        orElse: () => api.AdminActionKind.reportsPeriodReview,
      );

  api.AdminAudience _audienceDto(AdminAudienceSelection selection) {
    final resource = selection.resource == AdminAudienceResource.accounts
        ? api.AudienceResourceKind.accounts
        : api.AudienceResourceKind.reports;
    switch (selection.kind) {
      case AdminAudienceSelectionKind.selected:
        return api.AdminAudience(
          kind: api.AudienceKind.selected,
          resource: resource,
          ids: selection.selectedIds.toList(growable: false),
        );
      case AdminAudienceSelectionKind.all:
        return api.AdminAudience(
          kind: api.AudienceKind.all,
          resource: resource,
        );
      case AdminAudienceSelectionKind.filter:
        final filter = selection.filter!;
        return api.AdminAudience(
          kind: api.AudienceKind.filter,
          resource: resource,
          filter: api.AdminAudienceFilter(
            resource: resource,
            createdAfter: filter.createdAfter,
            createdBefore: filter.createdBefore,
            includeAdmins: filter.includeAdmins,
            verifiedEmail: filter.verifiedEmail,
            username: filter.search,
            securityStatuses: filter.securityStatus == null
                ? null
                : [_securityStatusDto(filter.securityStatus!)],
            assigneeUserId: filter.assigneeUserId,
            statuses: filter.statuses.map(_reportAudienceStatusDto).toList(),
            types: filter.types.toList(),
          ),
        );
    }
  }

  api.AdminSecurityState _securityStatusDto(
    AdminAudienceSecurityStatus status,
  ) => switch (status) {
    AdminAudienceSecurityStatus.passwordDisabled =>
      api.AdminSecurityState.passwordDisabled,
    AdminAudienceSecurityStatus.compromised =>
      api.AdminSecurityState.compromised,
    AdminAudienceSecurityStatus.securedManualRecoveryRequired =>
      api.AdminSecurityState.securedManualRecoveryRequired,
    AdminAudienceSecurityStatus.deleted => api.AdminSecurityState.deleted,
    AdminAudienceSecurityStatus.normal => api.AdminSecurityState.normal,
  };

  api.AdminReportStatus _reportAudienceStatusDto(
    AdminAudienceReportStatus status,
  ) => switch (status) {
    AdminAudienceReportStatus.open => api.AdminReportStatus.open,
    AdminAudienceReportStatus.resolved => api.AdminReportStatus.resolved,
    AdminAudienceReportStatus.dismissed => api.AdminReportStatus.dismissed,
  };

  api.AdminJobCreateRequestDto _jobRequest(AdminAudienceCommitRequest commit) =>
      api.AdminJobCreateRequestDto(
        action: _actionDto(commit.action),
        payloadHash: commit.payloadHash,
        snapshotId: commit.snapshotId,
      );

  AdminAudiencePreview _previewFromDto(
    api.AdminAudiencePreviewResponseDto dto,
    AdminAudiencePreviewRequest request,
  ) {
    if (dto.status.value == 'pending') {
      return AdminAudiencePreview.pending(
        snapshotId: dto.snapshotId,
        jobId: dto.jobId,
      );
    }
    final counts = dto.counts;
    return AdminAudiencePreview(
      snapshotId: dto.snapshotId,
      accountAudienceCount: counts?.accountAudienceCount,
      eligibleRecipientCount: counts?.eligibleRecipientCount,
      excludedCount: counts?.excludedCount,
      deviceDeliveryCount: counts?.deviceDeliveryCount,
      expiresAt: dto.expiresAt,
      exclusions: (dto.exclusions ?? const [])
          .map(
            (item) => AdminAudienceExclusion(id: item.id, reason: item.reason),
          )
          .toList(growable: false),
      audience: dto.status.value == 'ready' ? request.audience : null,
      action: dto.status.value == 'ready' ? request.action : null,
      actorUserId: dto.actorUserId,
      payloadHash: dto.payloadHash,
      resource: _resourceFromDto(dto.resource),
      status: switch (dto.status.value) {
        'ready' => AdminAudiencePreviewStatus.ready,
        'expired' => AdminAudiencePreviewStatus.expired,
        'failed' => AdminAudiencePreviewStatus.failed,
        _ => AdminAudiencePreviewStatus.pending,
      },
      jobId: dto.jobId,
    );
  }

  AdminAudienceResource? _resourceFromDto(api.AudienceResourceKind? resource) =>
      switch (resource?.value) {
        'accounts' => AdminAudienceResource.accounts,
        'reports' => AdminAudienceResource.reports,
        _ => null,
      };

  AdminReport _reportFromDto(api.AdminReportDto dto) => AdminReport(
    id: dto.id,
    text: dto.text,
    reporterUserId: dto.reporterUserId,
    reporterUsername: dto.reporterUsername,
    target: AdminReportTarget(
      userId: dto.target.userId,
      username: dto.target.username,
      deleted: dto.target.deleted,
    ),
    status: _reportStatus(dto.status),
    revision: dto.revision,
    createdAt: dto.createdAt,
    updatedAt: dto.updatedAt,
    assigneeUserId: dto.assigneeUserId,
    legacyMessage: dto.legacyMessage,
    notes: dto.notes.map(_noteFromDto).toList(growable: false),
  );

  AdminReportNote _noteFromDto(api.AdminReportNoteDto dto) => AdminReportNote(
    id: dto.id,
    actorUserId: dto.actorUserId,
    text: dto.text,
    createdAt: dto.createdAt,
  );

  AdminJobRecord _jobFromDto(api.AdminJobDto dto) => AdminJobRecord(
    id: dto.jobId,
    actionLabel: _actionLabel(dto.action.action.value),
    status: _jobStatus(dto.status),
    // The frozen API exposes audience snapshot counts only. Do not relabel
    // them as delivery progress or infer recipient failure outcomes.
    pendingCount: 0,
    completedCount: 0,
    failedCount: 0,
    unknownDeliveryCount: 0,
    cancellationRequested: dto.cancellationRequested,
    accountAudienceCount: dto.counts.accountAudienceCount,
    eligibleRecipientCount: dto.counts.eligibleRecipientCount,
    excludedAudienceCount: dto.counts.excludedCount,
    deviceDeliveryCount: dto.counts.deviceDeliveryCount,
    hasProgressDetails: false,
    updatedAt: dto.updatedAt,
  );

  AdminJobStatus _jobStatus(api.AdminJobStatus status) =>
      switch (status.value) {
        'running' => AdminJobStatus.running,
        'completed' => AdminJobStatus.completed,
        'completed_with_errors' => AdminJobStatus.completedWithErrors,
        'paused' => AdminJobStatus.paused,
        'cancelled' => AdminJobStatus.cancelled,
        _ => AdminJobStatus.pending,
      };

  AdminAuditEvent _auditFromDto(api.AdminAuditEventDto dto) => AdminAuditEvent(
    id: dto.id,
    actorLabel: dto.actorUserId == null ? 'System' : 'Administrator',
    targetLabel: dto.targetUserId == null ? 'No account target' : 'Account',
    actionLabel: _actionLabel(dto.action.value),
    outcome: AdminAuditOutcome.fromWire(dto.outcome),
    occurredAt: dto.occurredAt,
  );

  String _actionLabel(String value) => switch (value) {
    'email' => 'Email campaign',
    'login_link' => 'Sign-in link campaign',
    'push' => 'Push campaign',
    'revoke_sessions' => 'Revoke sessions',
    'mark_compromised' => 'Mark compromised',
    'recovery_resend' => 'Resend recovery',
    'report_resolve' => 'Resolve reports',
    'report_dismiss' => 'Dismiss reports',
    'jobs.control' => 'Job control',
    'messages.test' => 'Test message',
    'reports.review' => 'Report review',
    _ => 'Administrative action',
  };

  AdminSessionSnapshot _sessionFromDto(api.AdminSessionDto dto) =>
      AdminSessionSnapshot(
        sessionId: dto.sessionId,
        userId: dto.userId,
        username: dto.username,
        csrfToken: dto.csrfToken,
        capabilities: dto.capabilities.toSet(),
        permissions: dto.permissions.toSet(),
        authenticatedAt: dto.authenticatedAt,
        lastActivityAt: dto.lastActivityAt,
        idleExpiresAt: dto.idleExpiresAt,
        recentMfaAt: dto.recentMfaAt,
      );

  AdminUserRecord _userFromDto(api.AdminUserDto dto) => AdminUserRecord(
    id: dto.id,
    username: dto.username,
    email: dto.email,
    emailVerified: dto.emailVerified,
    securityStatus: _securityStatus(dto.securityState),
    createdAt: dto.createdAt,
    isAdmin: dto.isAdmin,
    passwordDisabled: dto.passwordDisabled,
    passwordResetRequired: dto.passwordResetRequired,
    authGeneration: dto.authGeneration,
    eligibilityReasons: dto.eligibilityReasons,
  );

  AdminUserDetails _detailsFromDto(api.AdminUserDetailsDto dto) =>
      AdminUserDetails(
        id: dto.id,
        username: dto.username,
        email: dto.email,
        emailVerified: dto.emailVerified,
        securityStatus: _securityStatus(dto.securityState),
        createdAt: dto.createdAt,
        isAdmin: dto.isAdmin,
        passwordDisabled: dto.passwordDisabled,
        passwordResetRequired: dto.passwordResetRequired,
        authGeneration: dto.authGeneration,
        eligibilityReasons: dto.eligibilityReasons,
        compromisedAt: dto.compromisedAt,
        communicationOptOut: dto.communicationOptOut,
        registeredDeviceCount: dto.registeredDeviceCount,
      );

  AdminSecurityStatus _securityStatus(api.AdminSecurityState state) {
    switch (state.value) {
      case 'password_disabled':
        return AdminSecurityStatus.passwordDisabled;
      case 'compromised':
        return AdminSecurityStatus.compromised;
      case 'secured_manual_recovery_required':
        return AdminSecurityStatus.securedManualRecoveryRequired;
      case 'deleted':
        return AdminSecurityStatus.deleted;
      case 'normal':
      default:
        return AdminSecurityStatus.normal;
    }
  }
}
