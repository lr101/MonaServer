
import 'dart:typed_data';

import 'package:buff_lisa/widgets/round_image/presentation/custom_image_picker.dart';
import 'package:buff_lisa/widgets/round_image/presentation/round_image.dart';
import 'package:buff_lisa/widgets/round_image/state/image_picker_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RoundImagePicker extends ConsumerWidget {

  final AsyncValue<Uint8List?> imageCallback;
  final Function(Uint8List) imageUpload;
  final double size;
  final double? editSize;

  const RoundImagePicker({super.key, required this.imageCallback, required this.size, required this.imageUpload, this.editSize});


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RoundImage(
        imageCallback: imageCallback,
        size: size,
        child: Stack(
            children: [
              Align(
                alignment: Alignment.bottomRight,
                child: GestureDetector(
                    onTap: () async {
                      final Uint8List? pickedImage = await CustomImagePicker.pickAndCrop(minHeight: 100, minWidth: 100, context: context);
                      if (pickedImage != null) {
                        ref.read(imagePickerStateProvider.notifier).setImage(imageUpload, pickedImage);
                      }
                    },
                    child: CircleAvatar(
                      radius: editSize ?? size / 2.5,
                      child: const Icon(Icons.edit),
                    ),
                ),
              ),
            ],
        ),

    );
  }

}
