import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/widgets/image_grid/presentation/image_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows an error when image loading fails', (tester) async {
    final pins = Provider<AsyncValue<List<PinEntity>?>>(
      (ref) => AsyncError<List<PinEntity>?>(
        StateError('pin load failed'),
        StackTrace.current,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: ImageGrid(pinProvider: pins)),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Unable to load images'), findsOneWidget);
    expect(find.text('No images found'), findsNothing);
  });
}
