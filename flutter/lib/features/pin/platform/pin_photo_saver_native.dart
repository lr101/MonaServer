import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';

bool get supportsPinPhotoDownload => switch (defaultTargetPlatform) {
  TargetPlatform.android ||
  TargetPlatform.iOS ||
  TargetPlatform.macOS ||
  TargetPlatform.windows => true,
  TargetPlatform.linux || TargetPlatform.fuchsia => false,
};

Future<void> savePinPhoto(Uint8List bytes, {required String name}) =>
    Gal.putImageBytes(bytes, name: name);
