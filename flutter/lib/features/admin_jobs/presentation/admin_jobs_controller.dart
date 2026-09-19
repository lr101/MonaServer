import 'package:buff_lisa/features/admin_jobs/domain/admin_job_models.dart';
import 'package:buff_lisa/features/admin_jobs/domain/admin_job_ports.dart';

final class AdminJobsState {
  const AdminJobsState({
    this.jobs = const [],
    this.nextCursor,
    this.loading = false,
    this.pendingCancellationJobId,
    this.message,
  });

  final List<AdminJobRecord> jobs;
  final String? nextCursor;
  final bool loading;
  final String? pendingCancellationJobId;
  final String? message;

  AdminJobsState copyWith({
    List<AdminJobRecord>? jobs,
    String? nextCursor,
    bool clearNextCursor = false,
    bool? loading,
    String? pendingCancellationJobId,
    bool clearPendingCancellation = false,
    String? message,
    bool clearMessage = false,
  }) => AdminJobsState(
    jobs: jobs ?? this.jobs,
    nextCursor: clearNextCursor ? null : nextCursor ?? this.nextCursor,
    loading: loading ?? this.loading,
    pendingCancellationJobId: clearPendingCancellation
        ? null
        : pendingCancellationJobId ?? this.pendingCancellationJobId,
    message: clearMessage ? null : message ?? this.message,
  );
}

typedef AdminJobsListener = void Function(AdminJobsState state);

final class AdminJobsController {
  AdminJobsController(
    this.repository, {
    this.onUnauthorized,
    this.onCapabilityDenied,
  });

  final AdminJobsRepository repository;
  final void Function()? onUnauthorized;
  final void Function()? onCapabilityDenied;
  final _listeners = <AdminJobsListener>{};
  AdminJobsState _state = const AdminJobsState();
  final _commands = <String, Future<void>>{};
  int _generation = 0;
  bool _expired = false;

  AdminJobsState get state => _state;
  void addListener(AdminJobsListener listener) => _listeners.add(listener);
  void removeListener(AdminJobsListener listener) =>
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
        jobs: reset ? const [] : null,
        clearNextCursor: reset,
        loading: true,
        clearMessage: true,
      ),
    );
    try {
      final page = await repository.list(AdminJobQuery(cursor: cursor));
      if (!_isCurrent(generation)) return;
      _emit(
        _state.copyWith(
          jobs: reset ? page.items : [..._state.jobs, ...page.items],
          nextCursor: page.nextCursor,
          clearNextCursor: page.nextCursor == null,
          loading: false,
        ),
      );
    } catch (error) {
      if (!_isCurrent(generation)) return;
      _handleError(error, 'Jobs are unavailable. Try again.');
    }
  }

  void requestCancellation(String jobId) {
    if (_expired || jobId.trim().isEmpty) return;
    _emit(
      _state.copyWith(
        pendingCancellationJobId: jobId.trim(),
        message: 'Cancellation stops pending work only. Accepted deliveries cannot be unsent.',
      ),
    );
  }

  Future<void> confirmCancellation({bool acknowledged = false}) {
    final jobId = _state.pendingCancellationJobId;
    if (_expired || jobId == null) return Future.value();
    if (!acknowledged) {
      _emit(
        _state.copyWith(
          message: 'Acknowledge the cancellation warning before continuing.',
        ),
      );
      return Future.value();
    }
    return _command(jobId, cancel: true);
  }

  Future<void> retry(String jobId) => _command(jobId, cancel: false);

  Future<void> _command(String jobId, {required bool cancel}) {
    if (_expired || jobId.trim().isEmpty) return Future.value();
    final key = '${cancel ? 'cancel' : 'retry'}:$jobId';
    final current = _commands[key];
    if (current != null) return current;
    final future = _runCommand(jobId, cancel: cancel, key: key);
    _commands[key] = future;
    return future;
  }

  Future<void> _runCommand(
    String jobId, {
    required bool cancel,
    required String key,
  }) async {
    final generation = _generation;
    _emit(_state.copyWith(loading: true, clearMessage: true));
    try {
      await (cancel ? repository.cancel(jobId) : repository.retry(jobId));
      if (!_isCurrent(generation)) return;
      _emit(
        _state.copyWith(
          loading: false,
          clearPendingCancellation: cancel,
          message: cancel
              ? 'Cancellation was requested. Pending work will stop.'
              : 'Eligible failed work was queued for retry.',
        ),
      );
    } catch (error) {
      if (!_isCurrent(generation)) return;
      _handleError(
        error,
        'Job command is unavailable. No change was confirmed.',
      );
    } finally {
      _commands.remove(key);
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

  bool _isCurrent(int generation) => !_expired && generation == _generation;

  void _handleError(Object error, String fallback) {
    if (error is AdminJobsTransportException && error.isUnauthorized) {
      expireSession();
    } else if (error is AdminJobsTransportException && error.isForbidden) {
      onCapabilityDenied?.call();
      _emit(
        _state.copyWith(
          loading: false,
          message: 'You do not have permission for that action.',
        ),
      );
    } else {
      _emit(_state.copyWith(loading: false, message: fallback));
    }
  }

  void _emit(AdminJobsState state) {
    _state = state;
    for (final listener in List<AdminJobsListener>.of(_listeners)) {
      listener(state);
    }
  }
}
