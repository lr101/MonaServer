import 'dart:async';

import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/dto/global_data_dto.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/features/group_search/presentation/group_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openapi/api.dart';

class _DelayedGroupsApi extends GroupsApi {
  final response = Completer<GroupsSyncDto?>();
  int requests = 0;

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
  }) {
    requests++;
    return response.future;
  }
}

void main() {
  for (final failed in [false, true]) {
    testWidgets(
      'leaving group search before ${failed ? 'failure' : 'success'} ignores the late response',
      (tester) async {
        final api = _DelayedGroupsApi();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              groupApiProvider.overrideWithValue(api),
              globalDataServiceProvider.overrideWithValue(
                const GlobalDataDto(
                  userId: 'viewer',
                  refreshToken: null,
                  cameras: [],
                ),
              ),
            ],
            child: const MaterialApp(home: GroupSearch()),
          ),
        );
        await tester.pump();
        expect(api.requests, 1);
        await tester.pumpWidget(const SizedBox());
        if (failed) {
          api.response.completeError(Exception('Request failed after leaving'));
        } else {
          api.response.complete(GroupsSyncDto());
        }
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(
          api.requests,
          1,
          reason: 'No fallback request after the route is disposed',
        );
      },
    );
  }
}
