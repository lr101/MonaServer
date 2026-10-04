import 'dart:typed_data';

import 'package:buff_lisa/features/pin/platform/pin_photo_saver_native.dart'
    if (dart.library.js_interop) 'package:buff_lisa/features/pin/platform/pin_photo_saver_web.dart'
    as platform;

bool get supportsPinPhotoDownload => platform.supportsPinPhotoDownload;

Future<void> savePinPhoto(Uint8List bytes, {required String name}) =>
    platform.savePinPhoto(bytes, name: name);
