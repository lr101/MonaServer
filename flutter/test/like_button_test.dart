import 'dart:async';

import 'package:buff_lisa/widgets/custom_feed/presentation/like_button_animated.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'authoritative updates animate immediately and rollback stops animation',
    (tester) async {
      final provider = Provider<bool?>((ref) => false);
      final key = GlobalKey<LikeButtonAnimatedState>();
      Widget button(bool liked, int count) => ProviderScope(
        child: MaterialApp(
          home: LikeButtonAnimated(
            key: key,
            isLikedProvider: provider,
            isLiked: liked,
            likeCount: count,
          ),
        ),
      );
      await tester.pumpWidget(button(false, 0));
      await tester.pumpWidget(button(true, 1));
      expect(key.currentState!.controller!.isAnimating, isTrue);
      expect(key.currentState!.likeCount, 1);
      await tester.pumpWidget(button(false, 0));
      expect(key.currentState!.isLiked, false);
      expect(key.currentState!.likeCount, 0);
      expect(key.currentState!.controller!.isAnimating, isFalse);
    },
  );

  testWidgets('feed state changes show a red heart without animation', (
    tester,
  ) async {
    final provider = Provider<bool?>((ref) => false);
    final key = GlobalKey<LikeButtonAnimatedState>();
    Widget button(bool liked, int count) => ProviderScope(
      child: MaterialApp(
        home: LikeButtonAnimated(
          key: key,
          isLikedProvider: provider,
          isLiked: liked,
          likeCount: count,
          animateLikeChanges: false,
          likeBuilder: (isLiked) => Icon(
            isLiked ? Icons.favorite : Icons.favorite_border,
            color: isLiked ? Colors.red : Colors.grey,
          ),
        ),
      ),
    );

    await tester.pumpWidget(button(false, 0));
    await tester.pumpWidget(button(true, 1));

    expect(key.currentState!.controller!.isAnimating, isFalse);
    expect(key.currentState!.likeCountController!.isAnimating, isFalse);
    expect(tester.widget<Icon>(find.byIcon(Icons.favorite)).color, Colors.red);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('rapid taps submit only once while sync is pending', (
    tester,
  ) async {
    final result = Completer<bool>();
    var calls = 0;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: LikeButtonAnimated(
            isLikedProvider: Provider<bool?>((ref) => false),
            onTap: (_) {
              calls++;
              return result.future;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byType(LikeButtonAnimated));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byType(LikeButtonAnimated));
    expect(calls, 1);
    result.complete(true);
    await tester.pumpAndSettle();
  });
}
