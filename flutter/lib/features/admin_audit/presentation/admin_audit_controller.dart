import 'package:buff_lisa/features/admin_audit/domain/admin_audit_models.dart';
import 'package:buff_lisa/features/admin_audit/domain/admin_audit_ports.dart';

final class AdminAuditState {
  const AdminAuditState({
    this.events = const [],
    this.nextCursor,
    this.loading = false,
    this.message,
  });

  final List<AdminAuditEvent> events;
  final String? nextCursor;
  final bool loading;
  final String? message;

  AdminAuditState copyWith({
    List<AdminAuditEvent>? events,
    String? nextCursor,
    bool clearNextCursor = false,
    bool? loading,
    String? message,
    bool clearMessage = false,
  }) => AdminAuditState(
    events: events ?? this.events,
    nextCursor: clearNextCursor ? null : nextCursor ?? this.nextCursor,
    loading: loading ?? this.loading,
    message: clearMessage ? null : message ?? this.message,
  );
}

typedef AdminAuditListener = void Function(AdminAuditState state);

final class AdminAuditController {
  AdminAuditController(
    this.repository, {
    this.onUnauthorized,
    this.onCapabilityDenied,
  });

  final AdminAuditRepository repository;
  final void Function()? onUnauthorized;
  final void Function()? onCapabilityDenied;
  final _listeners = <AdminAuditListener>{};
  AdminAuditState _state = const AdminAuditState();
  int _generation = 0;
  bool _expired = false;

  AdminAuditState get state => _state;
  void addListener(AdminAuditListener listener) => _listeners.add(listener);
  void removeListener(AdminAuditListener listener) =>
      _listeners.remove(listener);

  Future<void> load() => _load(reset: true);
  Future<void> loadNextPage() =>
      _state.nextCursor == null ? Future.value() : _load(reset: false);

  Future<void> _load({required bool reset}) async {
    if (_expired || _state.loading) return;
    final generation = ++_generation;
    final cursor = reset ? null : _state.nextCursor;
    _emit(
      _state.copyWith(
        events: reset ? const [] : null,
        clearNextCursor: reset,
        loading: true,
        clearMessage: true,
      ),
    );
    try {
      final page = await repository.listAudit(AdminAuditQuery(cursor: cursor));
      if (!_isCurrent(generation)) return;
      _emit(
        _state.copyWith(
          events: reset ? page.items : [..._state.events, ...page.items],
          nextCursor: page.nextCursor,
          clearNextCursor: page.nextCursor == null,
          loading: false,
        ),
      );
    } catch (error) {
      if (!_isCurrent(generation)) return;
      if (error is AdminAuditTransportException && error.isUnauthorized) {
        expireSession();
      } else if (error is AdminAuditTransportException && error.isForbidden) {
        onCapabilityDenied?.call();
        _emit(
          _state.copyWith(
            loading: false,
            message: 'You do not have permission to view this audit history.',
          ),
        );
      } else {
        _emit(
          _state.copyWith(
            loading: false,
            message: 'Audit history is unavailable. Try again.',
          ),
        );
      }
    }
  }

  void expireSession() {
    if (_expired) return;
    _expired = true;
    ++_generation;
    _emit(
      _state.copyWith(
        loading: false,
        message: 'Your admin session has expired.',
      ),
    );
    onUnauthorized?.call();
  }

  void dispose() {
    if (_expired) return;
    _expired = true;
    ++_generation;
    _listeners.clear();
  }

  bool _isCurrent(int generation) => !_expired && generation == _generation;

  void _emit(AdminAuditState state) {
    _state = state;
    for (final listener in List<AdminAuditListener>.of(_listeners)) {
      listener(state);
    }
  }
}
