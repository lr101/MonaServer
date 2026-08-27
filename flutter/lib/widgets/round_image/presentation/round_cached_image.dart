
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:transparent_image/transparent_image.dart';

class RoundCachedImage extends StatelessWidget {
  const RoundCachedImage( {super.key, required this.image, required this.size,});

  final Uint8List? image;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size * 2,
      child: ClipOval(
        child: FadeInImage(
          fadeInDuration: const Duration(milliseconds: 100),
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          placeholder: MemoryImage(kTransparentImage),
          image: image == null ? MemoryImage(kTransparentImage) : MemoryImage(image!),
          )
      ),
    );
  }

}
