import 'dart:convert';

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

  test('adds presence state when upgrading the local pin cache', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (database) {
          database.execute('CREATE TABLE pin_entities (pin_id TEXT NOT NULL)');
          database.userVersion = 2;
        },
      ),
    );
    addTearDown(db.close);

    final columns = await db
        .customSelect('PRAGMA table_info(pin_entities)')
        .get();

    expect(
      columns.map((column) => column.read<String>('name')),
      contains('is_gone'),
    );
  });

  test(
    'marks a synced pin gone remotely and persists the returned state',
    () async {
      final f = _fixture((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v2/pins/pin/presence');
        expect(jsonDecode(request.body), {'state': 'gone'});
        return http.Response(jsonEncode(_pinDto(isGone: true)), 200);
      });
      await f.repository.put(_pin());

      expect(await f.service.setPinGone('pin', true), isNull);

      expect((await f.repository.get('pin'))?.isGone, isTrue);
    },
  );

  test('failed presence update leaves cached state unchanged', () async {
    final f = _fixture((_) async => http.Response('Forbidden', 403));
    await f.repository.put(_pin());

    expect(await f.service.setPinGone('pin', true), isNotNull);

    expect((await f.repository.get('pin'))?.isGone, isFalse);
  });
}

Map<String, Object> _pinDto({required bool isGone}) => {
  'id': 'pin',
  'creationDate': '2026-01-01T00:00:00Z',
  'latitude': 1,
  'longitude': 2,
  'creationUser': 'user',
  'groupId': 'group',
  'isGone': isGone,
};

PinEntity _pin() => PinEntity(
  pinId: 'pin',
  latitude: 1,
  longitude: 2,
  creationDate: DateTime.utc(2026),
  creator: 'user',
  groupId: 'group',
  lastSynced: DateTime.utc(2026),
  ttl: DateTime.utc(2099),
  onlySession: false,
);

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

class _EmptyGroups extends UserGroupService {
  @override
  Stream<List<GroupEntity>> build() => Stream.value([]);
}
