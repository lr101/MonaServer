import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mutex/mutex.dart';

class AccountDataSessionGuard {
  final Mutex _mutex = Mutex();
  int _generation = 0;
  int _activeCleanups = 0;
  bool _writesEnabled = true;
  bool _sessionClosed = false;

  int get generation => _generation;

  bool isCurrent(int generation) {
    return _writesEnabled && !_sessionClosed && generation == _generation;
  }

  void beginCleanup({required bool endSession}) {
    _generation++;
    _activeCleanups++;
    _writesEnabled = false;
    if (endSession) {
      _sessionClosed = true;
    }
  }

  void completeCleanup({required bool resumeSession}) {
    _activeCleanups--;
    if (_activeCleanups > 0 || !resumeSession || _sessionClosed) return;

    _generation++;
    _writesEnabled = true;
  }

  void beginSession() {
    _generation++;
    _writesEnabled = true;
    _sessionClosed = false;
  }

  Future<T> synchronize<T>(Future<T> Function() action) {
    return _mutex.protect(action);
  }

  Future<bool> runIfCurrent(int generation, Future<void> Function() action) {
    return synchronize(() async {
      if (!isCurrent(generation)) return false;
      await action();
      return true;
    });
  }
}

final accountDataSessionGuardProvider = Provider<AccountDataSessionGuard>(
  (ref) => AccountDataSessionGuard(),
);
