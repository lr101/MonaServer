import 'dart:typed_data';

import 'package:buff_lisa/widgets/custom_marker/data/default_group_image.dart';
import 'package:buff_lisa/widgets/custom_scaffold/presentation/custom_avatar_scaffold.dart';
import 'package:buff_lisa/widgets/round_image/presentation/round_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transparent_image/transparent_image.dart';

void main() {
  testWidgets('keeps profile tabs below the avatar with a clear gap', (
    tester,
  ) async {
    await tester.pumpWidget(_avatarScaffold(bottom: _profileTabs));
    await tester.pumpAndSettle();

    final avatarBottom = tester.getRect(find.byType(RoundImage)).bottom;
    final iconTop = tester.getTopLeft(find.byIcon(Icons.image_outlined)).dy;

    expect(iconTop - avatarBottom, greaterThanOrEqualTo(24));
  });

  testWidgets('preserves the expanded height when there are no profile tabs', (
    tester,
  ) async {
    await tester.pumpWidget(_avatarScaffold());

    final appBar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));

    expect(appBar.expandedHeight, 180);
  });
}

const TabBar _profileTabs = TabBar(
  tabs: [Tab(icon: Icon(Icons.image_outlined), text: 'Pins')],
);

Widget _avatarScaffold({PreferredSizeWidget? bottom}) {
  return ProviderScope(
    overrides: [defaultErrorImageProvider.overrideWithValue(kTransparentImage)],
    child: MaterialApp(
      home: DefaultTabController(
        length: 1,
        child: CustomAvatarScaffold(
          avatar: const AsyncData<Uint8List?>(null),
          title: const Text('Profile'),
          bottom: bottom,
          body: const SizedBox.expand(),
        ),
      ),
    ),
  );
}
