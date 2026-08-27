import 'package:buff_lisa/data/repository/image_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:transparent_image/transparent_image.dart';

class SquareImage extends ConsumerWidget {
  final String pinId;
  final String groupId;
  final int index;
  final Function(int index) onTap;

  const SquareImage(
      {super.key,
      required this.pinId,
      required this.index,
      required this.groupId,
      required this.onTap,});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder(
      future: ref.watch(pinImageRepositoryProvider).fetchImage(pinId, false), 
      builder: (context, future) {
            if (future.data != null) {
              return GestureDetector(
                onTap: () => onTap(index),
                child: FadeInImage(
                    fadeInDuration: const Duration(milliseconds: 100),
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    placeholder: MemoryImage(kTransparentImage),
                    image: MemoryImage(future.data!),),);
            } else {
             return const SizedBox.shrink();
            }
            }
            );
  }
}
