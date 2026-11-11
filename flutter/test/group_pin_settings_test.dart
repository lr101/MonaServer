import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/database/account_session.dart';
import 'package:buff_lisa/data/entity/group_entity.dart';
import 'package:buff_lisa/data/service/group_service.dart';
import 'package:buff_lisa/features/group_overview/presentation/group_pin_settings.dart';
import 'package:buff_lisa/widgets/custom_marker/data/group_pin_design.dart';
import 'package:buff_lisa/widgets/custom_marker/data/group_pin_design_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openapi/api.dart';

void main() {
  testWidgets('retries applying a saved design with its new revision', (
    tester,
  ) async {
    final api = _DesignApi();
    final updates = <UpdateGroupDto>[];
    final group = GroupEntity(
      groupId: 'group',
      name: 'Group',
      visibility: 0,
      userIsMember: true,
      groupAdmin: 'admin',
      ttl: DateTime(2026),
      onlySession: false,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountSessionProvider.overrideWithValue(AccountSession(true)),
          groupPinDesignsApiProvider.overrideWithValue(api),
          groupPinDesignCatalogProvider('group')
              .overrideWith((ref) => api.catalog),
          userGroupServiceProvider.overrideWith(() => _Groups(updates)),
        ],
        child: MaterialApp(
          home: Scaffold(body: GroupPinSettings(group: group)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aurora'));
    await tester.tap(find.text('Shield'));
    await tester.tap(find.text('Save pin appearance'));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not save pin appearance. Try again.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Save pin appearance'));
    await tester.pumpAndSettle();
    expect(api.revisions, [1, 2]);
    expect(api.catalog.designs.first.shape.value, 'shield');
    expect(
      api.catalog.designs.first.bodyColor,
      MapPinDesign.forStyle('aurora').toDto().bodyColor,
    );
    expect(api.catalog.designs.first.badge.value, 'none');
    expect(updates.last.pinStyle?.value, 'moss');
    expect(find.text('Pin appearance saved'), findsOneWidget);
  });
}

class _DesignApi extends GroupPinDesignsApi {
  final revisions = <int>[];
  GroupPinDesignCatalogDto catalog = GroupPinDesignCatalogDto(
    revision: 1,
    designs: [
      MapPinDesign.forStyle('moss').toDto(),
      MapPinDesign.forStyle('aurora').toDto(),
    ],
  );
  @override
  Future<GroupPinDesignCatalogDto?> updateGroupPinDesignCatalog(
    String groupId,
    UpdateGroupPinDesignCatalogDto data,
  ) async {
    revisions.add(data.expectedRevision);
    if (data.expectedRevision != catalog.revision) {
      throw StateError('stale revision');
    }
    return catalog = GroupPinDesignCatalogDto(
      revision: catalog.revision + 1,
      designs: [data.design, catalog.designs.last],
    );
  }
}

class _Groups extends UserGroupService {
  _Groups(this.updates);
  final List<UpdateGroupDto> updates;
  @override
  Stream<List<GroupEntity>> build() => const Stream.empty();
  @override
  Future<String?> updateGroup(UpdateGroupDto data, String groupId) async {
    updates.add(data);
    return updates.length == 1 ? 'temporarily unavailable' : null;
  }
}
