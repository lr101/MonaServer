import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:buff_lisa/data/entity/group_entity.dart';
import 'package:buff_lisa/data/service/image_service.dart';
import 'package:buff_lisa/widgets/custom_marker/data/default_group_image.dart';
import 'package:buff_lisa/widgets/group_edit_template/presentation/group_edit_template.dart';
import 'package:buff_lisa/widgets/group_edit_template/service/group_create_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transparent_image/transparent_image.dart';

void main() {
  testWidgets(
    'opening group creation while its state is observed does not mutate during build',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            defaultErrorImageProvider.overrideWithValue(kTransparentImage),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                ref.watch(groupCreateServiceProvider);
                return GroupEditTemplate(
                  title: 'Create',
                  onSubmit: (_, _, _, _, _) async {},
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'editing uses an existing group photo that arrives after the form opens',
    (tester) async {
      final photos = StreamController<Uint8List?>();
      addTearDown(photos.close);
      Uint8List? submitted;
      final group = GroupEntity(
        groupId: 'g',
        name: 'Group',
        description: 'Description',
        visibility: 0,
        userIsMember: true,
        groupAdmin: 'admin',
        ttl: DateTime(2027),
        onlySession: false,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            groupProfilePictureByIdProvider('g')
                .overrideWith((ref) => photos.stream),
            defaultErrorImageProvider.overrideWithValue(kTransparentImage),
          ],
          child: MaterialApp(
            home: GroupEditTemplate(
              title: 'Edit',
              groupDto: group,
              onSubmit: (_, _, _, image, _) async {
                submitted = image;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      photos.add(kTransparentImage);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(submitted, orderedEquals(kTransparentImage));
    },
  );
  testWidgets(
    'a late existing image never replaces a photo chosen in the form',
    (tester) async {
      final photos = StreamController<Uint8List?>();
      addTearDown(photos.close);
      final replacement = File('assets/achievements/art.jpeg')
          .readAsBytesSync();
      Uint8List? submitted;
      final container = ProviderContainer(
        overrides: [
          groupProfilePictureByIdProvider('g')
              .overrideWith((ref) => photos.stream),
          defaultErrorImageProvider.overrideWithValue(kTransparentImage),
        ],
      );
      addTearDown(container.dispose);
      final group = GroupEntity(
        groupId: 'g',
        name: 'Group',
        description: 'Description',
        visibility: 0,
        userIsMember: true,
        groupAdmin: 'admin',
        ttl: DateTime(2027),
        onlySession: false,
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: GroupEditTemplate(
              title: 'Edit',
              groupDto: group,
              onSubmit: (_, _, _, image, _) async {
                submitted = image;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      container
          .read(groupCreateServiceProvider.notifier)
          .updateProfileImage(replacement);
      photos.add(kTransparentImage);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(submitted, orderedEquals(replacement));
    },
  );
}
