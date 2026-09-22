import 'dart:math';

import 'package:buff_lisa/features/admin_audience/domain/admin_audience_models.dart';
import 'package:buff_lisa/features/admin_reports/domain/admin_report_models.dart';
import 'package:buff_lisa/features/admin_reports/domain/admin_report_ports.dart';

typedef AdminReportsListener = void Function(AdminReportsState state);

final class AdminReportsState {
  const AdminReportsState({
    this.query = const AdminReportQuery(),
    this.reports = const [],
    this.nextCursor,
    this.selectedIds = const {},
    this.loading = false,
    this.loadingDetail = false,
    this.detail,
    this.error,
    this.bulkPreview,
    this.bulkStatus,
    this.bulkMessage,
    this.bulkLoading = false,
  });

  final AdminReportQuery query;
  final List<AdminReport> reports;
  final String? nextCursor;
  final Set<String> selectedIds;
  final bool loading;
  final bool loadingDetail;
  final AdminReport? detail;
  final String? error;
  final AdminAudiencePreview? bulkPreview;
  final AdminReportStatus? bulkStatus;
  final String? bulkMessage;
  final bool bulkLoading;

  AdminReportsState copyWith({
    AdminReportQuery? query,
    List<AdminReport>? reports,
    String? nextCursor,
    bool clearNextCursor = false,
    Set<String>? selectedIds,
    bool? loading,
    bool? loadingDetail,
    AdminReport? detail,
    bool clearDetail = false,
    String? error,
    bool clearError = false,
    AdminAudiencePreview? bulkPreview,
    bool clearBulkPreview = false,
    AdminReportStatus? bulkStatus,
    bool clearBulkStatus = false,
    String? bulkMessage,
    bool clearBulkMessage = false,
    bool? bulkLoading,
  }) => AdminReportsState(
    query: query ?? this.query,
    reports: reports ?? this.reports,
    nextCursor: clearNextCursor ? null : nextCursor ?? this.nextCursor,
    selectedIds: selectedIds ?? this.selectedIds,
    loading: loading ?? this.loading,
    loadingDetail: loadingDetail ?? this.loadingDetail,
    detail: clearDetail ? null : detail ?? this.detail,
    error: clearError ? null : error ?? this.error,
    bulkPreview: clearBulkPreview ? null : bulkPreview ?? this.bulkPreview,
    bulkStatus: clearBulkStatus ? null : bulkStatus ?? this.bulkStatus,
    bulkMessage: clearBulkMessage ? null : bulkMessage ?? this.bulkMessage,
    bulkLoading: bulkLoading ?? this.bulkLoading,
  );
}

/// Coordinates only feature models and ports. Generations ensure a late page,
/// filter, or detail response cannot overwrite a newer reviewer decision.
final class AdminReportsController {
  AdminReportsController(
    this.repository, {
    String Function()? idempotencyKey,
    this.onUnauthorized,
    this.onCapabilityDenied,
  }) : _idempotencyKey = idempotencyKey ?? _newIdempotencyKey;

  final AdminReportsRepository repository;
  final void Function()? onUnauthorized;
  final void Function()? onCapabilityDenied;
  final String Function() _idempotencyKey;
  final _listeners = <AdminReportsListener>{};
  AdminReportsState _state = const AdminReportsState();
  int _listGeneration = 0;
  int _detailGeneration = 0;
  int _bulkGeneration = 0;
  bool _disposed = false;

  AdminReportsState get state => _state;

  void addListener(AdminReportsListener listener) => _listeners.add(listener);
  void removeListener(AdminReportsListener listener) =>
      _listeners.remove(listener);

  Future<void> loadInbox({
    String? search,
    AdminReportStatus? status,
    bool clearStatus = false,
    bool preserveBulkMessage = false,
    bool bulkRefresh = false,
  }) async {
    if (_disposed ||
        (!bulkRefresh && _state.bulkLoading && _state.bulkPreview != null)) {
      return;
    }
    final query = AdminReportQuery(
      search: (search ?? _state.query.search).trim(),
      status: clearStatus ? null : status ?? _state.query.status,
    );
    final generation = ++_listGeneration;
    ++_detailGeneration;
    ++_bulkGeneration;
    _emit(
      _state.copyWith(
        query: query,
        reports: const [],
        clearNextCursor: true,
        selectedIds: const {},
        loading: true,
        loadingDetail: false,
        clearDetail: true,
        clearError: true,
        clearBulkPreview: true,
        clearBulkStatus: true,
        clearBulkMessage: !preserveBulkMessage,
        bulkLoading: bulkRefresh,
      ),
    );
    try {
      final page = await repository.listReports(query);
      if (!_isCurrentList(generation)) return;
      _emit(
        _state.copyWith(
          reports: page.items,
          nextCursor: page.nextCursor,
          clearNextCursor: page.nextCursor == null,
          loading: false,
          bulkLoading: false,
        ),
      );
    } catch (error) {
      if (_isCurrentList(generation)) {
        _handleError(error, bulk: bulkRefresh);
      }
    }
  }

  Future<void> loadNextPage() async {
    final cursor = _state.nextCursor;
    if (_disposed || _state.loading || cursor == null) return;
    final generation = _listGeneration;
    _emit(_state.copyWith(loading: true, clearError: true));
    try {
      final page = await repository.listReports(
        _state.query.copyWith(cursor: cursor),
      );
      if (!_isCurrentList(generation)) return;
      _emit(
        _state.copyWith(
          reports: [..._state.reports, ...page.items],
          nextCursor: page.nextCursor,
          clearNextCursor: page.nextCursor == null,
          loading: false,
        ),
      );
    } catch (error) {
      if (_isCurrentList(generation)) _handleError(error);
    }
  }

  void toggleSelection(String reportId) {
    if (_disposed || (_state.bulkLoading && _state.bulkPreview != null)) {
      return;
    }
    ++_bulkGeneration;
    final selected = {..._state.selectedIds};
    if (!selected.add(reportId)) selected.remove(reportId);
    _emit(
      _state.copyWith(
        selectedIds: selected,
        clearBulkPreview: true,
        clearBulkStatus: true,
        bulkLoading: false,
      ),
    );
  }

  Future<void> loadDetail(String reportId) async {
    if (_disposed) return;
    final generation = ++_detailGeneration;
    _emit(
      _state.copyWith(loadingDetail: true, clearDetail: true, clearError: true),
    );
    try {
      final report = await repository.get(reportId);
      if (!_isCurrentDetail(generation)) return;
      _emit(
        _state.copyWith(
          detail: report,
          loadingDetail: false,
          error: report == null ? 'Report details are unavailable.' : null,
          clearError: report != null,
        ),
      );
    } catch (error) {
      if (_isCurrentDetail(generation)) _handleError(error, detail: true);
    }
  }

  Future<void> updateDetail({
    required AdminReportStatus status,
    String? assigneeUserId,
    bool clearAssignee = false,
    String? note,
  }) async {
    final detail = _state.detail;
    if (_disposed || detail == null || _state.loadingDetail) return;
    final generation = _detailGeneration;
    final normalizedAssignee = assigneeUserId?.trim();
    final shouldClearAssignee =
        clearAssignee ||
        (assigneeUserId != null && normalizedAssignee!.isEmpty);
    _emit(_state.copyWith(loadingDetail: true, clearError: true));
    try {
      final updated = await repository.update(
        AdminReportUpdate(
          reportId: detail.id,
          expectedRevision: detail.revision,
          status: status,
          assigneeUserId: shouldClearAssignee ? null : normalizedAssignee,
          clearAssignee: shouldClearAssignee,
          note: note?.trim(),
        ),
      );
      if (!_isCurrentDetail(generation)) return;
      _replaceDetail(updated);
      _emit(_state.copyWith(detail: updated, loadingDetail: false));
    } catch (error) {
      if (!_isCurrentDetail(generation)) return;
      if (_isConflict(error)) {
        _emit(
          _state.copyWith(
            loadingDetail: false,
            error: 'This report changed by another reviewer. Reload it before saving.',
          ),
        );
      } else {
        _handleError(error, detail: true);
      }
    }
  }

  Future<void> addNote(String text) async {
    final detail = _state.detail;
    final trimmed = text.trim();
    if (_disposed ||
        detail == null ||
        trimmed.isEmpty ||
        _state.loadingDetail) {
      return;
    }
    final generation = _detailGeneration;
    _emit(_state.copyWith(loadingDetail: true, clearError: true));
    try {
      final note = await repository.addNote(detail.id, trimmed);
      if (!_isCurrentDetail(generation)) return;
      final withNote = detail.copyWith(notes: [...detail.notes, note]);
      _replaceDetail(withNote);
      _emit(_state.copyWith(detail: withNote, loadingDetail: false));
    } catch (error) {
      if (_isCurrentDetail(generation)) _handleError(error, detail: true);
    }
  }

  Future<void> previewBulk(
    AdminReportStatus status, {
    bool allMatching = false,
  }) async {
    if (_disposed || (_state.bulkLoading && _state.bulkPreview != null)) {
      return;
    }
    final generation = ++_bulkGeneration;
    if (allMatching && _state.query.search.trim().isNotEmpty) {
      _emit(
        _state.copyWith(
          error:
              'Clear the text search before using all-matching report actions.',
          clearBulkPreview: true,
          clearBulkStatus: true,
          bulkLoading: false,
        ),
      );
      return;
    }
    final reportFilter = _state.query.audienceFilter;
    final audience = allMatching
        ? reportFilter.hasCriteria
              ? AdminAudienceSelection.filter(reportFilter)
              : AdminAudienceSelection.all(
                  resource: AdminAudienceResource.reports,
                )
        : AdminAudienceSelection.selected(
            _state.selectedIds,
            resource: AdminAudienceResource.reports,
          );
    final action = _bulkAction(status);
    final request = AdminAudiencePreviewRequest(
      audience: audience,
      action: action,
    );
    if (!request.isValid) {
      _emit(
        _state.copyWith(
          error: 'Select at least one report or choose all matching reports.',
          clearBulkPreview: true,
          clearBulkStatus: true,
          bulkLoading: false,
        ),
      );
      return;
    }
    _emit(
      _state.copyWith(
        clearError: true,
        clearBulkMessage: true,
        clearBulkPreview: true,
        clearBulkStatus: true,
        bulkLoading: true,
      ),
    );
    try {
      final preview = await repository.preview(request);
      if (!_isCurrentBulk(generation)) return;
      _emit(
        _state.copyWith(
          bulkPreview: preview,
          bulkStatus: status,
          bulkLoading: false,
        ),
      );
    } catch (error) {
      if (_isCurrentBulk(generation)) _handleError(error, bulk: true);
    }
  }

  Future<void> confirmBulk() async {
    final preview = _state.bulkPreview;
    final status = _state.bulkStatus;
    if (_disposed || preview == null || status == null || _state.bulkLoading) {
      return;
    }
    final generation = _bulkGeneration;
    final commit = preview.commitRequest(
      expectedAudience: preview.audience,
      expectedAction: preview.action,
      expectedPayloadHash: preview.payloadHash,
    );
    if (commit == null) {
      _emit(
        _state.copyWith(
          error: 'Review the current audience preview before confirming.',
        ),
      );
      return;
    }
    _emit(_state.copyWith(clearError: true, bulkLoading: true));
    try {
      final outcome = await repository.commitBulk(
        AdminReportBulkCommand(
          commit: commit,
          status: status,
          idempotencyKey: _idempotencyKey(),
        ),
      );
      if (outcome.isQueued) {
        _emit(
          _state.copyWith(
            selectedIds: const {},
            bulkMessage:
                'Report update was queued as job ${outcome.jobId}. It has not completed yet.',
            clearBulkPreview: true,
            clearBulkStatus: true,
            bulkLoading: false,
          ),
        );
        return;
      }
      final changed = outcome.changed!;
      final skipped = outcome.skipped!;
      if (!_isCurrentBulk(generation)) {
        if (!_disposed) {
          _emit(
            _state.copyWith(
              bulkMessage: _bulkOutcomeMessage(
                changed: changed,
                skipped: skipped,
                status: status,
                inboxChanged: true,
              ),
            ),
          );
        }
        return;
      }
      final query = _state.query;
      _emit(
        _state.copyWith(
          selectedIds: const {},
          bulkMessage: _bulkOutcomeMessage(
            changed: changed,
            skipped: skipped,
            status: status,
          ),
          clearBulkPreview: true,
          clearBulkStatus: true,
          bulkLoading: true,
        ),
      );
      await loadInbox(
        search: query.search,
        status: query.status,
        clearStatus: query.status == null,
        preserveBulkMessage: true,
        bulkRefresh: true,
      );
    } catch (error) {
      if (_isCurrentBulk(generation)) _handleError(error, bulk: true);
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    ++_listGeneration;
    ++_detailGeneration;
    ++_bulkGeneration;
    _listeners.clear();
  }

  AdminAudienceAction _bulkAction(AdminReportStatus status) =>
      AdminAudienceAction(
        kind: status == AdminReportStatus.dismissed
            ? AdminAudienceActionKind.reportDismiss
            : AdminAudienceActionKind.reportResolve,
      );

  String _pastTense(AdminReportStatus status) => switch (status) {
    AdminReportStatus.open => 'reopened',
    AdminReportStatus.resolved => 'resolved',
    AdminReportStatus.dismissed => 'dismissed',
  };

  String _bulkOutcomeMessage({
    required int changed,
    required int skipped,
    required AdminReportStatus status,
    bool inboxChanged = false,
  }) {
    final changedText =
        '$changed report${changed == 1 ? '' : 's'} ${changed == 1 ? 'was' : 'were'} ${_pastTense(status)}';
    final skippedText = skipped == 0
        ? ''
        : '; $skipped report${skipped == 1 ? '' : 's'} skipped';
    final inboxText = inboxChanged
        ? ' while the inbox changed. Refresh to see the latest results'
        : '';
    return '$changedText$skippedText$inboxText.';
  }

  bool _isCurrentList(int generation) =>
      !_disposed && generation == _listGeneration;
  bool _isCurrentDetail(int generation) =>
      !_disposed && generation == _detailGeneration;
  bool _isCurrentBulk(int generation) =>
      !_disposed && generation == _bulkGeneration;
  bool _isUnauthorized(Object error) =>
      error is AdminReportsTransportException && error.isUnauthorized;
  bool _isForbidden(Object error) =>
      error is AdminReportsTransportException && error.isForbidden;
  bool _isConflict(Object error) =>
      error is AdminReportsTransportException && error.isConflict;

  void _replaceDetail(AdminReport report) {
    final index = _state.reports.indexWhere((item) => item.id == report.id);
    if (index < 0) return;
    final reports = [..._state.reports]..[index] = report;
    _state = _state.copyWith(reports: reports);
  }

  void _handleError(Object error, {bool detail = false, bool bulk = false}) {
    if (_isUnauthorized(error)) {
      onUnauthorized?.call();
      _emit(
        _state.copyWith(
          loading: detail ? null : false,
          loadingDetail: detail ? false : null,
          bulkLoading: bulk ? false : null,
          error: 'Your admin session has expired.',
        ),
      );
      return;
    }
    if (_isForbidden(error)) {
      onCapabilityDenied?.call();
      _emit(
        _state.copyWith(
          loading: detail ? null : false,
          loadingDetail: detail ? false : null,
          bulkLoading: bulk ? false : null,
          error: 'You do not have permission to review reports.',
        ),
      );
      return;
    }
    _emit(
      _state.copyWith(
        loading: detail ? null : false,
        loadingDetail: detail ? false : null,
        bulkLoading: bulk ? false : null,
        error: detail
            ? 'Report details are unavailable.'
            : 'Reports are unavailable. Try again.',
      ),
    );
  }

  void _emit(AdminReportsState next) {
    if (_disposed) return;
    _state = next;
    for (final listener in List<AdminReportsListener>.of(_listeners)) {
      listener(next);
    }
  }

  static String _newIdempotencyKey() {
    const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return List<String>.generate(
      32,
      (_) => alphabet[random.nextInt(alphabet.length)],
      growable: false,
    ).join();
  }
}
