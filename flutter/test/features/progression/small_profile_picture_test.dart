import 'package:buff_lisa/features/progression/presentation/small_profile_picture.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('compact user and group avatars do not show level badges', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  SmallProfilePicture.user(
                    userId: 'user-id',
                    loadImage: false,
                    placeholderAvatar: CircleAvatar(child: Text('User')),
                  ),
                  SmallProfilePicture.group(
                    groupId: 'group-id',
                    loadImage: false,
                    placeholderAvatar: CircleAvatar(child: Text('Group')),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CircleAvatar), findsNWidgets(2));
      expect(find.byType(UserXpAvatarIndicator), findsNothing);
      expect(find.semantics.byLabel(RegExp(r'Level \d+')), findsNothing);
    } finally {
      semanticsHandle.dispose();
    }
  });
}
