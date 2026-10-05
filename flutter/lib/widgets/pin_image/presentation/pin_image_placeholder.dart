import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';

class PinImagePlaceholder extends StatelessWidget {
  const PinImagePlaceholder({super.key, required this.blurhash});

  final String? blurhash;

  @override
  Widget build(BuildContext context) {
    if (blurhash == null || blurhash!.length != 16) {
      return const ColoredBox(color: Colors.black12);
    }

    return BlurHash(
      hash: blurhash!,
      imageFit: BoxFit.cover,
      optimizationMode: BlurHashOptimizationMode.approximation,
      duration: Duration.zero,
    );
  }
}
