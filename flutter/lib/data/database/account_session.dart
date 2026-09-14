import 'package:buff_lisa/data/database/database.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final accountSessionProvider = Provider<AccountSession>((ref) {
  ref.watch(
    globalDataServiceProvider.select(
      (data) => (data.userId, data.refreshToken),
    ),
  );
  return ref.read(globalDataServiceProvider.notifier).storageSession;
});

/// A captured account can never regain access after it is retired. Suppressing
/// old cache writes also covers repository batches and transactions.
/// Authentication still uses the independently fenced HTTP client.
class AccountSession {
  AccountSession(this._active);
  bool _active;
  bool get isActive => _active;
  final _listeners = <void Function()>{};

  void onRevoke(void Function() listener) {
    if (!_active) {
      listener();
    } else {
      _listeners.add(listener);
    }
  }

  void removeListener(void Function() listener) => _listeners.remove(listener);

  void revoke() {
    _active = false;
    for (final listener in _listeners.toList()) {
      listener();
    }
    _listeners.clear();
  }
}

class SessionQueries extends QueryInterceptor {
  SessionQueries(this.session, this.database);
  final AccountSession session;
  final AppDatabase database;
  bool get _active => session.isActive;

  // Only the bootstrap database may run schema creation/migrations.
  @override
  Future<bool> ensureOpen(QueryExecutor executor, QueryExecutorUser user) =>
      executor.ensureOpen(database);

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    if (!_active) return [];
    final rows = await executor.runSelect(statement, args);
    return _active ? rows : [];
  }

  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async => _active ? executor.runInsert(statement, args) : 0;

  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async => _active ? executor.runUpdate(statement, args) : 0;

  @override
  Future<int> runDelete(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async => _active ? executor.runDelete(statement, args) : 0;

  @override
  Future<void> runBatched(
    QueryExecutor executor,
    BatchedStatements statements,
  ) async {
    if (_active) await executor.runBatched(statements);
  }

  @override
  Future<void> runCustom(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    if (_active) await executor.runCustom(statement, args);
  }

  // The bootstrap database owns the physical connection. Disposing a session
  // only closes its stream subscriptions, never another session's connection.
  @override
  Future<void> close(QueryExecutor inner) async {}
}
