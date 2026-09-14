import 'dart:async';

/// Serializes explicit sync triggers and fences follow-up work by session.
/// This is an in-process coordinator, not a durable upload queue.
class SyncCoordinator {
  SyncCoordinator({
    required this.sync,
    DateTime Function()? now,
    this.resumeCooldown = const Duration(minutes: 1),
  }) : _now = now ?? DateTime.now;

  final Future<void> Function(bool Function() isCurrent) sync;
  final DateTime Function() _now;
  final Duration resumeCooldown;
  Object? _session;
  int _epoch = 0;
  int? _runningEpoch;
  DateTime? _lastStarted;
  Future<void>? _inFlight;
  bool _disposed = false;

  Future<void> setSession(Object? session) {
    if (_disposed || identical(session, _session)) return Future.value();
    _session = session;
    _epoch++;
    _lastStarted = null;
    return _request(force: true);
  }

  /// Invalidate old follow-up work after caches have been reset, then run again.
  Future<void> restart() {
    if (_disposed || _session == null) return Future.value();
    _epoch++;
    _lastStarted = null;
    return _request(force: true);
  }

  Future<void> refresh() => _request(force: true);
  Future<void> resume() => _request(force: false);

  Future<void> _request({required bool force}) {
    if (_disposed || _session == null) return Future.value();
    final epoch = _epoch;
    final running = _inFlight;
    if (running != null) {
      if (_runningEpoch == epoch) return running;
      // A new account waits for old transport work to finish. Old failures do
      // not prevent the replacement session from getting its initial sync.
      return running
          .then<void>((_) {}, onError: (Object _, StackTrace _) {})
          .then<void>((_) {
            if (_disposed || epoch != _epoch) return Future<void>.value();
            return _request(force: force);
          });
    }
    final now = _now();
    if (!force &&
        _lastStarted != null &&
        now.difference(_lastStarted!) < resumeCooldown) {
      return Future.value();
    }
    _lastStarted = now;
    _runningEpoch = epoch;
    bool isCurrent() => !_disposed && _session != null && epoch == _epoch;
    return _inFlight =
        Future<void>.microtask(() async {
          if (isCurrent()) await sync(isCurrent);
        }).whenComplete(() {
          _inFlight = null;
          _runningEpoch = null;
        });
  }

  void dispose() {
    _disposed = true;
    _session = null;
    _epoch++;
  }
}
