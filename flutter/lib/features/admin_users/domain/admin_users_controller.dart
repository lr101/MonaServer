import 'admin_user_models.dart';
import 'admin_user_ports.dart';

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
  int _requestGeneration = 0;
  bool _disposed = false;

  AdminUsersState get state => _state;

  void addListener(AdminUsersListener listener) => _listeners.add(listener);

  void removeListener(AdminUsersListener listener) =>
      _listeners.remove(listener);

  Future<void> searchUsers(String rawQuery) async {
    if (_disposed) return;
    final query = rawQuery.trim();
    final generation = ++_requestGeneration;
    _emit(AdminUsersState(query: query, loading: true));
    try {
      final page = await repository.listUsers(AdminUserQuery(search: query));
      if (!_isCurrent(generation)) return;
      _emit(
        AdminUsersState(
          query: query,
          users: page.items,
          nextCursor: page.nextCursor,
          selectedIds: const {},
        ),
      );
    } catch (error) {
      if (!_isCurrent(generation)) return;
      _handleError(error);
    }
  }

  Future<void> loadNextPage() async {
    if (_disposed || _state.loading || _state.nextCursor == null) return;
    final generation = _requestGeneration;
    _emit(_state.copyWith(loading: true, clearError: true));
    try {
      final page = await repository.listUsers(
        AdminUserQuery(search: _state.query, cursor: _state.nextCursor),
      );
      if (!_isCurrent(generation)) return;
      _emit(
        _state.copyWith(
          users: [..._state.users, ...page.items],
          nextCursor: page.nextCursor,
          clearNextCursor: page.nextCursor == null,
          loading: false,
        ),
      );
    } catch (error) {
      if (!_isCurrent(generation)) return;
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
    final generation = ++_requestGeneration;
    _emit(
      _state.copyWith(
        loadingDetail: true,
        clearSelectedDetail: true,
        clearError: true,
      ),
    );
    try {
      final details = await repository.getUser(userId);
      if (!_isCurrent(generation)) return;
      _emit(
        _state.copyWith(
          selectedDetail: details,
          loadingDetail: false,
          error: details == null ? 'User details are unavailable.' : null,
          clearError: details != null,
        ),
      );
    } catch (error) {
      if (!_isCurrent(generation)) return;
      _handleError(error, detail: true);
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    ++_requestGeneration;
    _listeners.clear();
  }

  bool _isCurrent(int generation) =>
      !_disposed && generation == _requestGeneration;

  void _handleError(Object error, {bool detail = false}) {
    if (_isUnauthorized(error)) {
      onUnauthorized?.call();
      _emit(
        _state.copyWith(
          loading: false,
          loadingDetail: false,
          error: 'Your admin session has expired.',
        ),
      );
      return;
    }
    if (_isForbidden(error)) {
      onCapabilityDenied?.call();
      _emit(
        _state.copyWith(
          loading: false,
          loadingDetail: false,
          error: 'You do not have permission to view this information.',
        ),
      );
      return;
    }
    _emit(
      _state.copyWith(
        loading: false,
        loadingDetail: false,
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
