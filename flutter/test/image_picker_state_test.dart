import 'dart:async';
import 'dart:typed_data';

import 'package:buff_lisa/widgets/round_image/state/image_picker_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'finishing an image upload after picker disposal does not touch its state',
    () async {
      final container = ProviderContainer();
      final subscription = container.listen(
        imagePickerStateProvider,
        (_, _) {},
      );
      await container.read(imagePickerStateProvider.future);
      final upload = Completer<void>();
      final operation = container
          .read(imagePickerStateProvider.notifier)
          .setImage((_) => upload.future, Uint8List.fromList([1]));
      subscription.close();
      container.dispose();
      upload.complete();
      await expectLater(operation, completes);
    },
  );
}
