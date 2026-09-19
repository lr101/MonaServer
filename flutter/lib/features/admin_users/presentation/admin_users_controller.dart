import '../domain/admin_user_models.dart';
import '../domain/admin_user_ports.dart';

typedef AdminUsersListener = void Function(AdminUsersState state);

final class AdminUsersState {
  const AdminUsersState({
    this.query = '',
    this.users = const [],
    this.nextCursor,
    this.selectedIds = const {},
    this.loading = false,
    this.loadingDetail = false,
    this.selectedDetail,
    this.error,
  });

  final String query;
  final List<AdminUserRecord> users;
  final String? nextCursor;
  final Set<String> selectedIds;
  final bool loading;
  final bool loadingDetail;
  final AdminUserDetails? selectedDetail;
  final String? error;

  AdminUsersState copyWith({
    String? query,
    List<AdminUserRecord>? users,
    String? nextCursor,
    bool clearNextCursor = false,
    Set<String>? selectedIds,
    bool? loading,
    bool? loadingDetail,
    AdminUserDetails? selectedDetail,
    bool clearSelectedDetail = false,
    String? error,
    bool clearError = false,
  }) {
    return AdminUsersState(
      query: query ?? this.query,
      users: users ?? this.users,
      nextCursor: clearNextCursor ? null : nextCursor ?? this.nextCursor,
      selectedIds: selectedIds ?? this.selectedIds,
      loading: loading ?? this.loading,
      loadingDetail: loadingDetail ?? this.loadingDetail,
      selectedDetail: clearSelectedDetail
          ? null
          : selectedDetail ?? this.selectedDetail,
      error: clearError ? null : error ?? this.error,
    );
  }
}

/// Loads cursor pages while ignoring responses belonging to an older search.
/// Selection is independent from the visible page, so IDs remain selected when
/// an administrator moves through the result set.
final class AdminUsersController {
  AdminUsersController(
    this.repository, {
    this.onUnauthorized,
    this.onCapabilityDenied,
  });

  final AdminUsersRepository repository;
  final void Function()? onUnauthorized;
  final void Function()? onCapabilityDenied;
  final _listeners = <AdminUsersListener>{};
  AdminUsersState _state = const AdminUsersState();
  int _listGeneration = 0;
  int _detailGeneration = 0;
  bool _disposed = false;

  AdminUsersState get state => _state;

  void addListener(AdminUsersListener listener) => _listeners.add(listener);

  void removeListener(AdminUsersListener listener) =>
      _listeners.remove(listener);

  Future<void> searchUsers(String rawQuery) async {
    if (_disposed) return;
    final query = rawQuery.trim();
    final generation = ++_listGeneration;
    // A new visible result set cannot keep showing a detail from the old one.
    ++_detailGeneration;
    _emit(
      _state.copyWith(
        query: query,
        users: const [],
        clearNextCursor: true,
        selectedIds: const {},
        loading: true,
        loadingDetail: false,
        clearSelectedDetail: true,
        clearError: true,
      ),
    );
    try {
      final page = await repository.listUsers(AdminUserQuery(search: query));
      if (!_isCurrentList(generation)) return;
      _emit(
        _state.copyWith(
          query: query,
          users: page.items,
          nextCursor: page.nextCursor,
          clearNextCursor: page.nextCursor == null,
          selectedIds: const {},
          loading: false,
        ),
      );
    } catch (error) {
      if (!_isCurrentList(generation)) return;
      _handleError(error);
    }
  }

  Future<void> loadNextPage() async {
    if (_disposed || _state.loading || _state.nextCursor == null) return;
    final generation = _listGeneration;
    final cursor = _state.nextCursor;
    _emit(_state.copyWith(loading: true, clearError: true));
    try {
      final page = await repository.listUsers(
        AdminUserQuery(search: _state.query, cursor: cursor),
      );
      if (!_isCurrentList(generation)) return;
      _emit(
        _state.copyWith(
          users: [..._state.users, ...page.items],
          nextCursor: page.nextCursor,
          clearNextCursor: page.nextCursor == null,
          loading: false,
        ),
      );
    } catch (error) {
      if (!_isCurrentList(generation)) return;
      _handleError(error);
    }
  }

  void toggleSelection(String userId) {
    if (_disposed) return;
    final selected = {..._state.selectedIds};
    if (!selected.add(userId)) selected.remove(userId);
    _emit(_state.copyWith(selectedIds: selected));
  }

  Future<void> loadDetails(String userId) async {
    if (_disposed) return;
    final generation = ++_detailGeneration;
    _emit(
      _state.copyWith(
        loadingDetail: true,
        clearSelectedDetail: true,
        clearError: true,
      ),
    );
    try {
      final details = await repository.getUser(userId);
      if (!_isCurrentDetail(generation)) return;
      _emit(
        _state.copyWith(
          selectedDetail: details,
          loadingDetail: false,
          error: details == null ? 'User details are unavailable.' : null,
          clearError: details != null,
        ),
      );
    } catch (error) {
      if (!_isCurrentDetail(generation)) return;
      _handleError(error, detail: true);
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    ++_listGeneration;
    ++_detailGeneration;
    _listeners.clear();
  }

  bool _isCurrentList(int generation) =>
      !_disposed && generation == _listGeneration;

  bool _isCurrentDetail(int generation) =>
      !_disposed && generation == _detailGeneration;

  void _handleError(Object error, {bool detail = false}) {
    if (_isUnauthorized(error)) {
      onUnauthorized?.call();
      _emit(
        _state.copyWith(
          loading: detail ? null : false,
          loadingDetail: detail ? false : null,
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
          error: 'You do not have permission to view this information.',
        ),
      );
      return;
    }
    _emit(
      _state.copyWith(
        loading: detail ? null : false,
        loadingDetail: detail ? false : null,
        error: detail
            ? 'User details are unavailable.'
            : 'Users are unavailable. Try again.',
      ),
    );
  }

  bool _isUnauthorized(Object error) =>
      error is AdminUsersTransportException && error.isUnauthorized;

  bool _isForbidden(Object error) =>
      error is AdminUsersTransportException && error.isForbidden;

  void _emit(AdminUsersState state) {
    if (_disposed) return;
    _state = state;
    for (final listener in List<AdminUsersListener>.of(_listeners)) {
      listener(state);
    }
  }
}
