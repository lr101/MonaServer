import 'dart:async';

import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/dto/global_data_dto.dart';
import 'package:buff_lisa/data/entity/group_entity.dart';
import 'package:buff_lisa/data/repository/global_data_repository.dart';
import 'package:buff_lisa/data/service/batch_read_coalescer.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/group_service.dart';
import 'package:buff_lisa/data/service/pin_image_source.dart';
import 'package:buff_lisa/features/group_search/presentation/group_search.dart';
import 'package:buff_lisa/widgets/custom_marker/data/default_group_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openapi/api.dart';
import 'package:transparent_image/transparent_image.dart';

import 'support/pin_image_test_cache.dart';

void main() {
  testWidgets('search rows reuse thumbnail URLs from the page response', (
    tester,
  ) async {
    final groupsApi = _RecordingGroupsApi();
    final images = PinImageTestCache()..install();
    final sources = createTestImageSources();
    addTearDown(images.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pinImageSourcesProvider.overrideWithValue(sources),
          suppliedImageUrlRegistryProvider.overrideWithValue(sources.registry),
          globalDataOnceProvider.overrideWithValue(
            const GlobalDataDto(
              userId: 'user-id',
              refreshToken: null,
              cameras: [],
            ),
          ),
          userGroupServiceProvider.overrideWith(_EmptyUserGroupService.new),
          groupApiProvider.overrideWithValue(groupsApi),
          defaultErrorImageProvider.overrideWithValue(kTransparentImage),
        ],
        child: const MaterialApp(home: GroupSearch()),
      ),
    );

    await tester.pump();
    await groupsApi.requestStarted.future.timeout(
      const Duration(milliseconds: 100),
    );
    await tester.pump();

    expect(find.text('Public group'), findsOneWidget);
    expect(groupsApi.requestedWithImages, [true]);
    await pumpImageLoads(tester);
    expect(images.urls, ['https://example.com/group-small.png']);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 11));
  });

  testWidgets('search results fall back when image URL generation fails', (
    tester,
  ) async {
    final groupsApi = _RecordingGroupsApi(failImageRequest: true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pinImageSourcesProvider.overrideWithValue(createTestImageSources()),
          globalDataServiceProvider.overrideWithValue(
            const GlobalDataDto(
              userId: 'user-id',
              refreshToken: null,
              cameras: [],
            ),
          ),
          userGroupServiceProvider.overrideWith(_EmptyUserGroupService.new),
          groupApiProvider.overrideWithValue(groupsApi),
          defaultErrorImageProvider.overrideWithValue(kTransparentImage),
        ],
        child: const MaterialApp(home: GroupSearch()),
      ),
    );

    await groupsApi.requestStarted.future;
    await tester.pump();
    await tester.pump();

    expect(find.text('Public group'), findsOneWidget);
    expect(groupsApi.requestedWithImages, [true, false]);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 20));
  });
}

class _RecordingGroupsApi extends GroupsApi {
  _RecordingGroupsApi({this.failImageRequest}) : super(ApiClient());

  final requestStarted = Completer<void>();
  final bool? failImageRequest;
  final requestedWithImages = <bool?>[];

  @override
  Future<GroupsSyncDto?> getGroupsByIds({
    List<String>? ids,
    String? search,
    String? userId,
    bool? withUser,
    bool? withImages,
    int? page,
    int? size,
    DateTime? updatedAfter,
  }) async {
    requestedWithImages.add(withImages);
    if (!requestStarted.isCompleted) requestStarted.complete();
    if (failImageRequest == true && withImages == true) {
      throw StateError('image URL generation failed');
    }
    return GroupsSyncDto(
      items: [
        GroupDto(
          id: 'group-id',
          name: 'Public group',
          visibility: 0,
          profileImageSmall: withImages == true
              ? 'https://example.com/group-small.png'
              : null,
        ),
      ],
    );
  }
}

class _EmptyUserGroupService extends UserGroupService {
  @override
  Stream<List<GroupEntity>> build() => Stream.value([]);
}
