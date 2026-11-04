import 'dart:typed_data';

import 'package:buff_lisa/widgets/round_image/presentation/round_image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transparent_image/transparent_image.dart';

void main() {
  testWidgets('change-image action has a 48 dp target', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: RoundImagePicker(
                size: 50,
                imageCallback: AsyncData<Uint8List?>(kTransparentImage),
                imageUpload: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    final target = tester.getSize(find.byType(InkWell));
    expect(target.width, greaterThanOrEqualTo(48));
    expect(target.height, greaterThanOrEqualTo(48));
  });
  for (final radius in [36.0, 40.0]) {
    testWidgets(
      'edit badge stays compact with a full touch target for radius $radius',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: Center(
                  child: RoundImagePicker(
                    size: radius,
                    imageCallback: AsyncData<Uint8List?>(kTransparentImage),
                    imageUpload: (_) {},
                  ),
                ),
              ),
            ),
          ),
        );
        final target = tester.getRect(find.byType(InkWell));
        final badge = tester.getRect(find.byType(Ink));
        expect(badge.size, const Size(28, 28));
        expect(tester.widget<Icon>(find.byIcon(Icons.edit)).size, 18);
        expect(target.size, const Size(48, 48));
        expect(target.contains(badge.center), isTrue);
        expect(target.left, lessThanOrEqualTo(badge.left));
        expect(target.top, lessThanOrEqualTo(badge.top));
        expect(target.right, greaterThanOrEqualTo(badge.right));
        expect(target.bottom, greaterThanOrEqualTo(badge.bottom));
      },
    );
  }
}
