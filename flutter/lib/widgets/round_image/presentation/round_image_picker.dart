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
  final Offset editOffset;

  const RoundImagePicker({
    super.key,
    required this.imageCallback,
    required this.size,
    required this.imageUpload,
    this.editSize,
    this.editOffset = Offset.zero,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final editButtonSize = (editSize ?? 22) * 2;

    return RoundImage(
      imageCallback: imageCallback,
      size: size,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.bottomRight,
            child: Tooltip(
              message: 'Change image',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () async {
                    final Uint8List? pickedImage =
                        await CustomImagePicker.pickAndCrop(
                          minHeight: 100,
                          minWidth: 100,
                          context: context,
                        );
                    if (pickedImage != null) {
                      ref
                          .read(imagePickerStateProvider.notifier)
                          .setImage(imageUpload, pickedImage);
                    }
                  },
                  child: SizedBox.square(
                    dimension: 44,
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: Transform.translate(
                        offset: editOffset,
                        child: Ink(
                          width: editButtonSize,
                          height: editButtonSize,
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.edit,
                            size: editSize == null ? 24 : editSize! * 1.25,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
