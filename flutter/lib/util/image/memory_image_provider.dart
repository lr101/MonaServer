import 'dart:typed_data';

import 'package:flutter/widgets.dart';

ImageProvider<Object> memoryImageForDisplay(
  Uint8List bytes, {
  required double devicePixelRatio,
  double? logicalWidth,
  int? maximumCacheWidth,
}) {
  if (logicalWidth == null || !logicalWidth.isFinite || logicalWidth <= 0) {
    return MemoryImage(bytes);
  }

  var cacheWidth = (logicalWidth * devicePixelRatio).ceil();
  if (maximumCacheWidth != null && cacheWidth > maximumCacheWidth) {
    cacheWidth = maximumCacheWidth;
  }
  return ResizeImage.resizeIfNeeded(cacheWidth, null, MemoryImage(bytes));
}
