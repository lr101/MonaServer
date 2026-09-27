import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/database/account_session.dart';
import 'package:buff_lisa/data/service/image_service.dart';
import 'package:buff_lisa/features/progression/presentation/group_pin_customizer.dart';
import 'package:buff_lisa/widgets/custom_marker/data/default_group_image.dart';
import 'package:buff_lisa/widgets/custom_marker/data/group_pin_design_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openapi/api.dart';
import 'package:transparent_image/transparent_image.dart';

void main() {
  testWidgets('keeps other dirty style saveable after a successful save', (
    tester,
  ) async {
    final api = _GroupPinDesignsApi(_catalog());
    await _showCustomizer(tester, api);

    await _tapShape(tester, 'Circle');
    await _selectStyle(tester, 'Sunset');
    await _tapShape(tester, 'Teardrop');
    await _selectStyle(tester, 'Moss');
    final readsBeforeSave = api.catalogReads;
    await _tap(tester, find.text('Save design'));
    await tester.pumpAndSettle();
    _hideSnackBar(tester);
    await tester.pumpAndSettle();
    expect(api.catalogReads, greaterThan(readsBeforeSave));

    await _selectStyle(tester, 'Sunset');

    final saveButton = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(saveButton.onPressed, isNotNull);

    await _tap(tester, find.text('Save design'));
    await tester.pumpAndSettle();
    expect(api.updates.map((update) => update.design.style.value), [
      'moss',
      'sunset',
    ]);
    expect(api.updates.map((update) => update.expectedRevision), [1, 2]);
  });

  testWidgets('preserves every local draft after a revision conflict', (
    tester,
  ) async {
    final api = _GroupPinDesignsApi(_catalog())
      ..conflictNextUpdate = true
      ..conflictCatalog = _catalog(
        revision: 2,
        mossShape: 'shield',
        sunsetShape: 'circle',
      );
    await _showCustomizer(tester, api);

    await _tapShape(tester, 'Circle');
    await _selectStyle(tester, 'Sunset');
    await _tapShape(tester, 'Teardrop');
    await _selectStyle(tester, 'Moss');
    await _tap(tester, find.text('Save design'));
    await tester.pumpAndSettle();
    await _selectStyle(tester, 'Sunset');

    expect(tester.widget<ChoiceChip>(_shapeChip('Teardrop')).selected, isTrue);
    expect(tester.widget<ChoiceChip>(_shapeChip('Circle')).selected, isFalse);
  });
}

Future<void> _showCustomizer(
  WidgetTester tester,
  GroupPinDesignsApi api,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        accountSessionProvider.overrideWithValue(AccountSession(true)),
        groupPinDesignsApiProvider.overrideWithValue(api),
        groupProfilePictureSmallByIdProvider('group-1')
            .overrideWith((ref) => Stream.value(null)),
        defaultErrorImageProvider.overrideWithValue(kTransparentImage),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                GroupPinCustomizer(
                  groupId: 'group-1',
                  unlockedStyles: ['moss', 'sunset', 'aurora'],
                  activeStyle: 'moss',
                ),
                _CatalogWatcher(),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await _tap(tester, find.text('Customize earned designs'));
  await tester.pumpAndSettle();
}

Future<void> _selectStyle(WidgetTester tester, String style) async {
  final dropdown = find.byType(DropdownButtonFormField<String>);
  await tester.ensureVisible(dropdown);
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await _tap(tester, find.text(style).last);
  await tester.pumpAndSettle();
}

Future<void> _tapShape(WidgetTester tester, String shape) async {
  await _tap(tester, find.text(shape));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
}

void _hideSnackBar(WidgetTester tester) {
  final messenger = tester.state<ScaffoldMessengerState>(
    find.byType(ScaffoldMessenger),
  );
  messenger.hideCurrentSnackBar();
}

Finder _shapeChip(String shape) =>
    find.ancestor(of: find.text(shape), matching: find.byType(ChoiceChip));

class _GroupPinDesignsApi extends GroupPinDesignsApi {
  _GroupPinDesignsApi(this.catalog);

  GroupPinDesignCatalogDto catalog;
  GroupPinDesignCatalogDto? conflictCatalog;
  bool conflictNextUpdate = false;
  int catalogReads = 0;
  final updates = <UpdateGroupPinDesignCatalogDto>[];

  @override
  Future<GroupPinDesignCatalogDto?> getGroupPinDesignCatalog(
    String groupId,
  ) async {
    catalogReads++;
    return catalog;
  }

  @override
  Future<GroupPinDesignCatalogDto?> updateGroupPinDesignCatalog(
    String groupId,
    UpdateGroupPinDesignCatalogDto updateGroupPinDesignCatalogDto,
  ) async {
    updates.add(updateGroupPinDesignCatalogDto);
    if (conflictNextUpdate) {
      conflictNextUpdate = false;
      catalog = conflictCatalog!;
      throw ApiException(409, 'revision conflict');
    }

    final designs = [
      for (final design in catalog.designs)
        if (design.style != updateGroupPinDesignCatalogDto.design.style) design,
      updateGroupPinDesignCatalogDto.design,
    ];
    return catalog = GroupPinDesignCatalogDto(
      revision: catalog.revision + 1,
      designs: designs,
    );
  }
}

class _CatalogWatcher extends ConsumerWidget {
  const _CatalogWatcher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(groupPinDesignCatalogProvider('group-1'));
    return const SizedBox.shrink();
  }
}

GroupPinDesignCatalogDto _catalog({
  int revision = 1,
  String mossShape = 'teardrop',
  String sunsetShape = 'shield',
  String auroraShape = 'circle',
}) => GroupPinDesignCatalogDto(
  revision: revision,
  designs: [
    _design('moss', mossShape),
    _design('sunset', sunsetShape),
    _design('aurora', auroraShape),
  ],
);

GroupPinDesignDto _design(String style, String shape) => GroupPinDesignDto(
  badge: GroupPinDesignBadge.none,
  bodyColor: '#668465',
  imageBorderColor: '#FFFFFF',
  imageInset: 2,
  imageZoom: 1,
  imageAlignmentX: 0,
  imageAlignmentY: 0,
  name: style,
  outlineColor: '#FFFFFF',
  outlineWidth: 2,
  shadow: true,
  shape: GroupPinDesignShape.values.firstWhere((value) => value.value == shape),
  style: GroupPinDesignStyle.values.firstWhere((value) => value.value == style),
);
