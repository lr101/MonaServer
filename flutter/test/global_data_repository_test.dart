import 'package:buff_lisa/data/repository/global_data_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses an empty camera list when camera discovery fails', () async {
    final cameras = await GlobalDataRepository.loadAvailableCameras(
      loader: () async => throw StateError('no camera available'),
    );

    expect(cameras, isEmpty);
  });
}
