import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/features/profile/presentation/user_image_feed.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('profile image feed hosts its sliver in a scroll view', (
    tester,
  ) async {
    final pinsProvider = Provider<AsyncValue<List<PinEntity>>>(
      (ref) => const AsyncData(<PinEntity>[]),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: UserImageFeed(
            index: 0,
            userId: 'user-1',
            userPinNotifier: pinsProvider,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(CustomScrollView), findsOneWidget);
  });
}
