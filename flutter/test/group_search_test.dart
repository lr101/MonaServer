import 'dart:async';
import 'dart:typed_data';

import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/dto/global_data_dto.dart';
import 'package:buff_lisa/data/entity/group_entity.dart';
import 'package:buff_lisa/data/repository/global_data_repository.dart';
import 'package:buff_lisa/data/service/group_service.dart';
import 'package:buff_lisa/data/service/image_service.dart';
import 'package:buff_lisa/features/group_search/presentation/group_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openapi/api.dart';

void main() {
  testWidgets('search rows do not request remote thumbnails', (tester) async {
    final groupsApi = _RecordingGroupsApi();
    var thumbnailProviderBuilds = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          globalDataOnceProvider.overrideWithValue(
            const GlobalDataDto(
              userId: 'user-id',
              refreshToken: null,
              cameras: [],
            ),
          ),
          userGroupServiceProvider.overrideWith(_EmptyUserGroupService.new),
          groupApiProvider.overrideWithValue(groupsApi),
          groupProfilePictureSmallByIdProvider('group-id').overrideWith((ref) {
            thumbnailProviderBuilds++;
            return Stream<Uint8List?>.value(null);
          }),
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
    expect(thumbnailProviderBuilds, 0);
  });
}

class _RecordingGroupsApi extends GroupsApi {
  _RecordingGroupsApi() : super(ApiClient());

  final requestStarted = Completer<void>();

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
    requestStarted.complete();
    return GroupsSyncDto(
      items: [GroupDto(id: 'group-id', name: 'Public group', visibility: 0)],
    );
  }
}

class _EmptyUserGroupService extends UserGroupService {
  @override
  Stream<List<GroupEntity>> build() => Stream.value([]);
}
