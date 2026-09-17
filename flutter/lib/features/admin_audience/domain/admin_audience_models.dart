enum AdminAudienceSelectionKind { selected, filter, all }

enum AdminAudienceSecurityStatus {
  normal,
  passwordDisabled,
  compromised,
  securedManualRecoveryRequired,
  deleted,
}

final class AdminAudienceFilter {
  const AdminAudienceFilter({
    this.search,
    this.verifiedEmail,
    this.securityStatus,
    this.createdAfter,
    this.createdBefore,
  });

  final String? search;
  final bool? verifiedEmail;
  final AdminAudienceSecurityStatus? securityStatus;
  final DateTime? createdAfter;
  final DateTime? createdBefore;

  bool get hasCriteria =>
      (search?.trim().isNotEmpty ?? false) ||
      verifiedEmail != null ||
      securityStatus != null ||
      createdAfter != null ||
      createdBefore != null;

  AdminAudienceFilter copyWith({
    String? search,
    bool clearSearch = false,
    bool? verifiedEmail,
    bool clearVerifiedEmail = false,
    AdminAudienceSecurityStatus? securityStatus,
    bool clearSecurityStatus = false,
    DateTime? createdAfter,
    bool clearCreatedAfter = false,
    DateTime? createdBefore,
    bool clearCreatedBefore = false,
  }) {
    return AdminAudienceFilter(
      search: clearSearch ? null : search ?? this.search,
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
      other.search == search &&
      other.verifiedEmail == verifiedEmail &&
      other.securityStatus == securityStatus &&
      other.createdAfter == createdAfter &&
      other.createdBefore == createdBefore;

  @override
  int get hashCode => Object.hash(
    search,
    verifiedEmail,
    securityStatus,
    createdAfter,
    createdBefore,
  );

  @override
  String toString() => 'AdminAudienceFilter(criteria: $hasCriteria)';
}

final class AdminAudienceSelection {
  AdminAudienceSelection._({
    required this.kind,
    Set<String> selectedIds = const {},
    this.filter,
  }) : selectedIds = Set.unmodifiable(selectedIds);

  factory AdminAudienceSelection.selected(Iterable<String> ids) {
    final normalized = ids
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    return AdminAudienceSelection._(
      kind: AdminAudienceSelectionKind.selected,
      selectedIds: normalized,
    );
  }

  factory AdminAudienceSelection.filter(AdminAudienceFilter filter) =>
      AdminAudienceSelection._(
        kind: AdminAudienceSelectionKind.filter,
        filter: filter,
      );

  factory AdminAudienceSelection.all() =>
      AdminAudienceSelection._(kind: AdminAudienceSelectionKind.all);

  final AdminAudienceSelectionKind kind;
  final Set<String> selectedIds;
  final AdminAudienceFilter? filter;

  bool get isActionable => kind == AdminAudienceSelectionKind.selected
      ? selectedIds.isNotEmpty
      : true;

  String get summary {
    switch (kind) {
      case AdminAudienceSelectionKind.selected:
        return '${selectedIds.length} selected account${selectedIds.length == 1 ? '' : 's'}';
      case AdminAudienceSelectionKind.filter:
        final search = filter?.search?.trim();
        return search?.isNotEmpty == true
            ? 'All accounts matching “$search”'
            : 'All accounts matching this filter';
      case AdminAudienceSelectionKind.all:
        return 'All eligible accounts';
    }
  }

  @override
  bool operator ==(Object other) =>
      other is AdminAudienceSelection &&
      other.kind == kind &&
      other.selectedIds.length == selectedIds.length &&
      other.selectedIds.containsAll(selectedIds) &&
      other.filter == filter;

  @override
  int get hashCode => Object.hash(kind, Object.hashAll(selectedIds), filter);

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
  int _filterRevision = 0;

  Set<String> get selectedIds => Set.unmodifiable(_selectedIds);
  AdminAudienceFilter? get filter => _filter;
  int get filterRevision => _filterRevision;

  AdminAudienceSelection get audience {
    if (_allMatching) return AdminAudienceSelection.all();
    final filter = _filter;
    if (filter != null) return AdminAudienceSelection.filter(filter);
    return AdminAudienceSelection.selected(_selectedIds);
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
    _filter = filter;
    ++_filterRevision;
  }

  void selectAllMatching() {
    _selectedIds.clear();
    _filter = null;
    _allMatching = true;
  }

  void clear() {
    _selectedIds.clear();
    _filter = null;
    _allMatching = false;
  }

  void _clearMode() {
    _filter = null;
    _allMatching = false;
  }
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
  });

  final String snapshotId;
  final int accountAudienceCount;
  final int eligibleRecipientCount;
  final int excludedCount;
  final int deviceDeliveryCount;
  final DateTime expiresAt;
  final List<AdminAudienceExclusion> exclusions;

  bool isExpired([DateTime? now]) => !expiresAt.isAfter(now ?? DateTime.now());

  bool canConfirm([DateTime? now]) =>
      snapshotId.isNotEmpty && eligibleRecipientCount > 0 && !isExpired(now);
}

final class AdminAudienceExclusion {
  const AdminAudienceExclusion({required this.id, required this.reason});

  final String id;
  final String reason;
}

abstract interface class AdminAudiencePreviewPort {
  Future<AdminAudiencePreview> preview(AdminAudienceSelection selection);
}
