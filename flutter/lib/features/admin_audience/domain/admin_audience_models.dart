enum AdminAudienceSelectionKind { selected, filter, all }

/// Resources that can be addressed by an administrative audience. Keeping
/// this enum in the feature domain prevents generated API types leaking into
/// presentation and makes resource mismatches impossible to ignore.
enum AdminAudienceResource { accounts, reports }

enum AdminAudienceActionKind {
  email,
  loginLink,
  push,
  revokeSessions,
  markCompromised,
  recoveryResend,
  reportResolve,
  reportDismiss,
}

/// The bounded action payload sent with an audience preview. The server still
/// validates the payload and computes the authoritative hash; this value is
/// retained locally so confirmation can reject edits made after preview.
final class AdminAudienceAction {
  const AdminAudienceAction({
    required this.kind,
    this.body,
    this.messageHtml,
    this.subject,
    this.reason,
    this.title,
    this.note,
  });

  final AdminAudienceActionKind kind;
  final String? body;
  final String? messageHtml;
  final String? subject;
  final String? reason;
  final String? title;
  final String? note;

  bool get isValid {
    bool hasText(String? value) => value?.trim().isNotEmpty == true;
    switch (kind) {
      case AdminAudienceActionKind.email:
        return hasText(body) &&
            hasText(subject) &&
            reason == null &&
            title == null &&
            note == null;
      case AdminAudienceActionKind.loginLink:
        return body == null &&
            messageHtml == null &&
            subject == null &&
            title == null &&
            note == null;
      case AdminAudienceActionKind.push:
        return hasText(body) &&
            hasText(title) &&
            messageHtml == null &&
            subject == null &&
            reason == null &&
            note == null;
      case AdminAudienceActionKind.revokeSessions:
      case AdminAudienceActionKind.markCompromised:
      case AdminAudienceActionKind.recoveryResend:
        return hasText(reason) &&
            body == null &&
            messageHtml == null &&
            subject == null &&
            title == null &&
            note == null;
      case AdminAudienceActionKind.reportResolve:
      case AdminAudienceActionKind.reportDismiss:
        return body == null &&
            messageHtml == null &&
            subject == null &&
            reason == null &&
            title == null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is AdminAudienceAction &&
      other.kind == kind &&
      other.body == body &&
      other.messageHtml == messageHtml &&
      other.subject == subject &&
      other.reason == reason &&
      other.title == title &&
      other.note == note;

  @override
  int get hashCode =>
      Object.hash(kind, body, messageHtml, subject, reason, title, note);

  @override
  String toString() => 'AdminAudienceAction(kind: $kind, payload: [redacted])';
}

enum AdminAudienceSecurityStatus {
  normal,
  passwordDisabled,
  compromised,
  securedManualRecoveryRequired,
  deleted,
}

enum AdminAudienceReportStatus { open, resolved, dismissed }

// Keep the unnamed constructor const-compatible for account callers. Use the
// resource-specific reports factory for report filters.
final class AdminAudienceFilter {
  const AdminAudienceFilter({
    this.search,
    this.includeAdmins,
    this.verifiedEmail,
    this.securityStatus,
    this.createdAfter,
    this.createdBefore,
  }) : resource = AdminAudienceResource.accounts,
       _statuses = const {},
       _types = const {},
       assigneeUserId = null;

  AdminAudienceFilter._reports({
    required this.createdAfter,
    required this.createdBefore,
    required this._statuses,
    required this._types,
    required this.assigneeUserId,
  }) : resource = AdminAudienceResource.reports,
       search = null,
       includeAdmins = null,
       verifiedEmail = null,
       securityStatus = null;

  factory AdminAudienceFilter.reports({
    Iterable<AdminAudienceReportStatus> statuses = const {},
    Iterable<String> types = const {},
    String? assigneeUserId,
    DateTime? createdAfter,
    DateTime? createdBefore,
  }) {
    final normalizedAssigneeUserId = assigneeUserId?.trim();
    final trimmedTypes = types.map((type) => type.trim()).toList();
    final normalizedTypes = trimmedTypes.toSet();
    if (trimmedTypes.length > 32 ||
        normalizedTypes.any((type) => type.isEmpty || type.length > 64)) {
      throw ArgumentError.value(
        types,
        'types',
        'must contain at most 32 non-blank values of at most 64 characters',
      );
    }
    return AdminAudienceFilter._reports(
      statuses: Set.unmodifiable(statuses),
      types: Set.unmodifiable(normalizedTypes),
      assigneeUserId: normalizedAssigneeUserId?.isEmpty == true
          ? null
          : normalizedAssigneeUserId,
      createdAfter: createdAfter,
      createdBefore: createdBefore,
    );
  }

  final AdminAudienceResource resource;
  final String? search;
  final bool? includeAdmins;
  final bool? verifiedEmail;
  final AdminAudienceSecurityStatus? securityStatus;
  final DateTime? createdAfter;
  final DateTime? createdBefore;
  final Set<AdminAudienceReportStatus> _statuses;
  final Set<String> _types;
  final String? assigneeUserId;

  Set<AdminAudienceReportStatus> get statuses => _statuses;
  Set<String> get types => _types;

  bool get hasCriteria {
    if (resource == AdminAudienceResource.reports) {
      return statuses.isNotEmpty ||
          types.isNotEmpty ||
          assigneeUserId != null ||
          createdAfter != null ||
          createdBefore != null;
    }
    return (search?.trim().isNotEmpty ?? false) ||
        includeAdmins != null ||
        verifiedEmail != null ||
        securityStatus != null ||
        createdAfter != null ||
        createdBefore != null;
  }

  AdminAudienceFilter copyWith({
    AdminAudienceResource? resource,
    String? search,
    bool clearSearch = false,
    bool? includeAdmins,
    bool clearIncludeAdmins = false,
    bool? verifiedEmail,
    bool clearVerifiedEmail = false,
    AdminAudienceSecurityStatus? securityStatus,
    bool clearSecurityStatus = false,
    DateTime? createdAfter,
    bool clearCreatedAfter = false,
    DateTime? createdBefore,
    bool clearCreatedBefore = false,
    Iterable<AdminAudienceReportStatus>? statuses,
    bool clearStatuses = false,
    Iterable<String>? types,
    bool clearTypes = false,
    String? assigneeUserId,
    bool clearAssigneeUserId = false,
  }) {
    if (resource != null && resource != this.resource) {
      throw ArgumentError.value(
        resource,
        'resource',
        'Resource transitions require a new resource-specific filter.',
      );
    }
    if (this.resource == AdminAudienceResource.reports) {
      if (search != null ||
          clearSearch ||
          includeAdmins != null ||
          clearIncludeAdmins ||
          verifiedEmail != null ||
          clearVerifiedEmail ||
          securityStatus != null ||
          clearSecurityStatus) {
        throw ArgumentError('Account criteria require an account filter.');
      }
      return AdminAudienceFilter.reports(
        statuses: clearStatuses ? const {} : statuses ?? this.statuses,
        types: clearTypes ? const {} : types ?? this.types,
        assigneeUserId: clearAssigneeUserId
            ? null
            : assigneeUserId ?? this.assigneeUserId,
        createdAfter: clearCreatedAfter
            ? null
            : createdAfter ?? this.createdAfter,
        createdBefore: clearCreatedBefore
            ? null
            : createdBefore ?? this.createdBefore,
      );
    }
    if (statuses != null ||
        clearStatuses ||
        types != null ||
        clearTypes ||
        assigneeUserId != null ||
        clearAssigneeUserId) {
      throw ArgumentError(
        'Report criteria require AdminAudienceFilter.reports.',
      );
    }
    return AdminAudienceFilter(
      search: clearSearch ? null : search ?? this.search,
      includeAdmins: clearIncludeAdmins
          ? null
          : includeAdmins ?? this.includeAdmins,
      verifiedEmail: clearVerifiedEmail
          ? null
          : verifiedEmail ?? this.verifiedEmail,
      securityStatus: clearSecurityStatus
          ? null
          : securityStatus ?? this.securityStatus,
      createdAfter: clearCreatedAfter
          ? null
          : createdAfter ?? this.createdAfter,
      createdBefore: clearCreatedBefore
          ? null
          : createdBefore ?? this.createdBefore,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AdminAudienceFilter &&
      other.resource == resource &&
      other.search == search &&
      other.includeAdmins == includeAdmins &&
      other.verifiedEmail == verifiedEmail &&
      other.securityStatus == securityStatus &&
      other.createdAfter == createdAfter &&
      other.createdBefore == createdBefore &&
      other.assigneeUserId == assigneeUserId &&
      other.statuses.length == statuses.length &&
      other.statuses.containsAll(statuses) &&
      other.types.length == types.length &&
      other.types.containsAll(types);

  @override
  int get hashCode => Object.hash(
    resource,
    search,
    includeAdmins,
    verifiedEmail,
    securityStatus,
    createdAfter,
    createdBefore,
    assigneeUserId,
    Object.hashAllUnordered(statuses),
    Object.hashAllUnordered(types),
  );

  @override
  String toString() => 'AdminAudienceFilter(criteria: $hasCriteria)';
}

final class AdminAudienceSelection {
  AdminAudienceSelection._({
    required this.kind,
    required this.resource,
    Set<String> selectedIds = const {},
    this.filter,
  }) : selectedIds = Set.unmodifiable(selectedIds);

  factory AdminAudienceSelection.selected(
    Iterable<String> ids, {
    AdminAudienceResource resource = AdminAudienceResource.accounts,
  }) {
    final normalized = ids
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    return AdminAudienceSelection._(
      kind: AdminAudienceSelectionKind.selected,
      resource: resource,
      selectedIds: normalized,
    );
  }

  factory AdminAudienceSelection.filter(AdminAudienceFilter filter) =>
      AdminAudienceSelection._(
        kind: AdminAudienceSelectionKind.filter,
        resource: filter.resource,
        filter: filter,
      );

  factory AdminAudienceSelection.all({
    AdminAudienceResource resource = AdminAudienceResource.accounts,
  }) => AdminAudienceSelection._(
    kind: AdminAudienceSelectionKind.all,
    resource: resource,
  );

  final AdminAudienceSelectionKind kind;
  final AdminAudienceResource resource;
  final Set<String> selectedIds;
  final AdminAudienceFilter? filter;

  bool get isActionable {
    if (kind == AdminAudienceSelectionKind.selected) {
      return selectedIds.isNotEmpty;
    }
    if (kind == AdminAudienceSelectionKind.filter) {
      return filter?.hasCriteria == true;
    }
    return true;
  }

  String get summary {
    final noun = resource == AdminAudienceResource.reports
        ? 'report'
        : 'account';
    final pluralNoun = resource == AdminAudienceResource.reports
        ? 'reports'
        : 'accounts';
    switch (kind) {
      case AdminAudienceSelectionKind.selected:
        return '${selectedIds.length} selected ${selectedIds.length == 1 ? noun : pluralNoun}';
      case AdminAudienceSelectionKind.filter:
        final search = filter?.search?.trim();
        if (resource == AdminAudienceResource.reports) {
          final reportFilter = filter;
          final criteria = <String>[
            if (reportFilter?.statuses.isNotEmpty == true)
              'status: ${reportFilter!.statuses.map((status) => status.name).join(', ')}',
            if (reportFilter?.types.isNotEmpty == true)
              'type: ${reportFilter!.types.join(', ')}',
            if (reportFilter?.assigneeUserId != null)
              'assignee: ${reportFilter!.assigneeUserId}',
            if (reportFilter?.createdAfter != null)
              'created after: ${reportFilter!.createdAfter!.toIso8601String()}',
            if (reportFilter?.createdBefore != null)
              'created before: ${reportFilter!.createdBefore!.toIso8601String()}',
          ];
          return criteria.isEmpty
              ? 'All $pluralNoun matching this filter'
              : 'All $pluralNoun matching ${criteria.join('; ')}';
        }
        return search?.isNotEmpty == true
            ? 'All $pluralNoun matching “$search”'
            : 'All $pluralNoun matching this filter';
      case AdminAudienceSelectionKind.all:
        return 'All eligible $pluralNoun';
    }
  }

  @override
  bool operator ==(Object other) =>
      other is AdminAudienceSelection &&
      other.kind == kind &&
      other.resource == resource &&
      other.selectedIds.length == selectedIds.length &&
      other.selectedIds.containsAll(selectedIds) &&
      other.filter == filter;

  @override
  int get hashCode => Object.hash(
    kind,
    resource,
    Object.hashAll(selectedIds.toList()..sort()),
    filter,
  );

  @override
  String toString() => 'AdminAudienceSelection(kind: $kind, summary: $summary)';
}

/// Mutable UI model for explicit selection, a frozen matching filter, or all.
/// Changing the filter clears selected IDs and increments [filterRevision],
/// making stale previews visibly invalid to callers.
final class AdminAudienceSelectionModel {
  final _selectedIds = <String>{};
  AdminAudienceFilter? _filter;
  bool _allMatching = false;
  AdminAudienceResource _resource = AdminAudienceResource.accounts;
  int _filterRevision = 0;

  Set<String> get selectedIds => Set.unmodifiable(_selectedIds);
  AdminAudienceFilter? get filter => _filter;
  AdminAudienceResource get resource => _resource;
  int get filterRevision => _filterRevision;

  AdminAudienceSelection get audience {
    final filter = _filter;
    if (filter != null) return AdminAudienceSelection.filter(filter);
    if (_allMatching) return AdminAudienceSelection.all(resource: _resource);
    return AdminAudienceSelection.selected(_selectedIds, resource: _resource);
  }

  void toggleSelected(String id) {
    final normalized = id.trim();
    if (normalized.isEmpty) return;
    _clearMode();
    if (!_selectedIds.add(normalized)) _selectedIds.remove(normalized);
  }

  void setFilter(AdminAudienceFilter filter) {
    _selectedIds.clear();
    _allMatching = false;
    _resource = filter.resource;
    _filter = filter;
    ++_filterRevision;
  }

  /// Select every record matching the current filter. If no filter is active,
  /// the explicit all-eligible mode is used for backwards-compatible callers.
  void selectAllMatching([AdminAudienceFilter? visibleFilter]) {
    if (visibleFilter != null) {
      setFilter(visibleFilter);
      return;
    }
    _selectedIds.clear();
    _allMatching = _filter == null;
  }

  void selectAllEligible({
    AdminAudienceResource resource = AdminAudienceResource.accounts,
  }) {
    _selectedIds.clear();
    _filter = null;
    _resource = resource;
    _allMatching = true;
  }

  void clear() {
    _selectedIds.clear();
    _filter = null;
    _allMatching = false;
    ++_filterRevision;
  }

  void _clearMode() {
    if (_filter != null) ++_filterRevision;
    _filter = null;
    _allMatching = false;
  }
}

enum AdminAudiencePreviewStatus { pending, ready, expired, failed }

/// The immutable input used to create a server-frozen preview. The request is
/// intentionally separate from the response so callers cannot accidentally
/// treat a count as confirmation for a different action or audience.
final class AdminAudiencePreviewRequest {
  const AdminAudiencePreviewRequest({
    required this.audience,
    required this.action,
  });

  final AdminAudienceSelection audience;
  final AdminAudienceAction action;

  bool get isValid => audience.isActionable && action.isValid;
}

/// The values required to commit a previously previewed action. The server
/// compares all three fields atomically; the client uses the same binding when
/// deciding whether to enable the confirmation control.
final class AdminAudienceCommitRequest {
  const AdminAudienceCommitRequest({
    required this.snapshotId,
    required this.action,
    required this.payloadHash,
  });

  final String snapshotId;
  final AdminAudienceAction action;
  final String payloadHash;

  bool get isValid =>
      snapshotId.trim().isNotEmpty &&
      payloadHash.trim().isNotEmpty &&
      action.isValid;
}

final class AdminAudiencePreview {
  const AdminAudiencePreview({
    required this.snapshotId,
    required this.accountAudienceCount,
    required this.eligibleRecipientCount,
    required this.excludedCount,
    required this.deviceDeliveryCount,
    required this.expiresAt,
    this.exclusions = const [],
    this.audience,
    this.action,
    this.actorUserId,
    this.payloadHash,
    this.resource,
    this.status = AdminAudiencePreviewStatus.ready,
    this.jobId,
  });

  /// A queued server calculation deliberately has no count, action binding,
  /// hash, or expiry until the server makes the snapshot ready.
  const AdminAudiencePreview.pending({required this.snapshotId, this.jobId})
    : accountAudienceCount = null,
      eligibleRecipientCount = null,
      excludedCount = null,
      deviceDeliveryCount = null,
      expiresAt = null,
      exclusions = const [],
      audience = null,
      action = null,
      actorUserId = null,
      payloadHash = null,
      resource = null,
      status = AdminAudiencePreviewStatus.pending;

  final String snapshotId;
  final int? accountAudienceCount;
  final int? eligibleRecipientCount;
  final int? excludedCount;
  final int? deviceDeliveryCount;
  final DateTime? expiresAt;
  final List<AdminAudienceExclusion> exclusions;
  final AdminAudienceSelection? audience;
  final AdminAudienceAction? action;
  final String? actorUserId;
  final String? payloadHash;
  final AdminAudienceResource? resource;
  final AdminAudiencePreviewStatus status;
  final String? jobId;

  bool isExpired([DateTime? now]) =>
      expiresAt != null && !expiresAt!.isAfter(now ?? DateTime.now());

  bool canConfirm([
    DateTime? now,
    AdminAudienceSelection? expectedAudience,
    AdminAudienceAction? expectedAction,
    String? expectedPayloadHash,
  ]) {
    if (status != AdminAudiencePreviewStatus.ready ||
        snapshotId.trim().isEmpty ||
        eligibleRecipientCount == null ||
        eligibleRecipientCount! <= 0 ||
        expiresAt == null ||
        isExpired(now) ||
        audience == null ||
        action == null ||
        payloadHash?.trim().isNotEmpty != true ||
        resource == null ||
        audience!.resource != resource) {
      return false;
    }
    if (expectedAudience == null ||
        expectedAction == null ||
        expectedPayloadHash == null) {
      return false;
    }
    return audience == expectedAudience &&
        action == expectedAction &&
        payloadHash == expectedPayloadHash;
  }

  AdminAudienceCommitRequest? commitRequest({
    AdminAudienceSelection? expectedAudience,
    AdminAudienceAction? expectedAction,
    String? expectedPayloadHash,
  }) {
    if (!canConfirm(
      null,
      expectedAudience,
      expectedAction,
      expectedPayloadHash,
    )) {
      return null;
    }
    return AdminAudienceCommitRequest(
      snapshotId: snapshotId,
      action: action!,
      payloadHash: payloadHash!,
    );
  }
}

final class AdminAudienceExclusion {
  const AdminAudienceExclusion({required this.id, required this.reason});

  final String id;
  final String reason;
}

abstract interface class AdminAudiencePreviewPort {
  Future<AdminAudiencePreview> preview(AdminAudiencePreviewRequest request);
}
