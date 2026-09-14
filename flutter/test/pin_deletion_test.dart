import 'dart:async';

import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/database/database.dart';
import 'package:buff_lisa/data/entity/group_entity.dart';
import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/repository/drift_repo.dart';
import 'package:buff_lisa/data/repository/pin_repository.dart';
import 'package:buff_lisa/data/service/group_service.dart';
import 'package:buff_lisa/data/service/pin_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openapi/api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final retained in [true, false]) {
    test(
      'deletes synced pin remotely before cache (keepAlive=$retained)',
      () async {
        final response = Completer<http.Response>();
        final started = Completer<http.Request>();
        final f = _fixture((request) {
          started.complete(request);
          return response.future;
        });
        await f.repository.put(_pin(synced: true, retained: retained));
        final deletion = f.service.deletePinFromGroup('pin');
        final request = await started.future.timeout(
          const Duration(seconds: 2),
        );
        expect(request.method, 'DELETE');
        expect(request.url.path, '/api/v2/pins/pin');
        expect(await f.repository.get('pin'), isNotNull);
        response.complete(http.Response('', 200));
        expect(await deletion, isNull);
        expect(await f.repository.get('pin'), isNull);
      },
    );
  }
  test('rejected deletion preserves cached pin and returns error', () async {
    final f = _fixture((_) async => http.Response('Forbidden', 403));
    await f.repository.put(_pin(synced: true, retained: true));
    expect(await f.service.deletePinFromGroup('pin'), isNotNull);
    expect(await f.repository.get('pin'), isNotNull);
  });
  for (final retained in [true, false]) {
    test('deletes offline draft locally (keepAlive=$retained)', () async {
      final requests = <http.Request>[];
      final f = _fixture((request) async {
        requests.add(request);
        return http.Response('No server pin', 404);
      });
      await f.repository.put(_pin(synced: false, retained: retained));
      expect(await f.service.deletePinFromGroup('pin'), isNull);
      expect(await f.repository.get('pin'), isNull);
      expect(requests, isEmpty);
    });
  }
}

({PinService service, PinRepository repository}) _fixture(
  Future<http.Response> Function(http.Request) handler,
) {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final client = ApiClient(basePath: 'http://localhost');
  client.client = MockClient(handler);
  addTearDown(client.client.close);
  final repository = PinRepository(db);
  final container = ProviderContainer(
    overrides: [
      accountDatabaseProvider.overrideWithValue(db),
      pinRepositoryProvider.overrideWithValue(repository),
      pinApiProvider.overrideWithValue(PinsApi(client)),
      userGroupServiceProvider.overrideWith(_EmptyGroups.new),
    ],
  );
  addTearDown(container.dispose);
  return (service: container.read(pinServiceProvider), repository: repository);
}

PinEntity _pin({required bool synced, required bool retained}) => PinEntity(
  pinId: 'pin',
  latitude: 1,
  longitude: 2,
  creationDate: DateTime.utc(2026),
  creator: 'user',
  groupId: 'group',
  lastSynced: synced ? DateTime.utc(2026) : null,
  keepAlive: retained,
  ttl: DateTime.utc(2099),
  onlySession: false,
);

class _EmptyGroups extends UserGroupService {
  @override
  Stream<List<GroupEntity>> build() => Stream.value([]);
}
