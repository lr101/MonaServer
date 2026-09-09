import 'package:buff_lisa/data/database/account_session.dart';
import 'package:buff_lisa/data/database/database.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'drift_repo.g.dart';

@riverpod
AppDatabase driftRepo(Ref ref) {
  throw UnimplementedError();
}

/// Repositories use a disposable facade; cleanup uses the bootstrap database.
final accountDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = ref.watch(driftRepoProvider);
  final session = ref.watch(accountSessionProvider);
  final scoped = AccountDatabase(database, session);
  ref.onDispose(scoped.close);
  return scoped;
});

class AccountDatabase extends AppDatabase {
  AccountDatabase(AppDatabase database, this.session)
    : super(database.executor.interceptWith(SessionQueries(session, database)));

  @override
  final AccountSession session;
}

/// Capture this before an async gap when a service later reads other providers.
bool Function() accountOperation(Ref ref) {
  final session = ref.read(accountSessionProvider);
  return () => session.isActive;
}
