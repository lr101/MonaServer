import 'package:buff_lisa/data/entity/group_entity.dart';
import 'package:buff_lisa/data/service/image_service.dart';
import 'package:buff_lisa/widgets/tiles/presentation/group_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('can render without requesting a remote thumbnail', (
    tester,
  ) async {
    var providerBuilds = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          groupProfilePictureSmallByIdProvider('group-id').overrideWith((ref) {
            providerBuilds++;
            return Stream.value(null);
          }),
        ],
        child: MaterialApp(
          home: Scaffold(body: GroupTile(groupDto: _group(), loadImage: false)),
        ),
      ),
    );

    expect(providerBuilds, 0);
  });
}

GroupEntity _group() => GroupEntity(
  groupId: 'group-id',
  name: 'Public group',
  visibility: 0,
  userIsMember: false,
  ttl: DateTime(2026),
  onlySession: true,
);
