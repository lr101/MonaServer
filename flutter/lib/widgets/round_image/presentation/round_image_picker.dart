import 'dart:typed_data';

import 'package:buff_lisa/util/theme/data/app_color_scheme.dart';
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
  final bool useBrandPlaceholder;

  const RoundImagePicker({
    super.key,
    required this.imageCallback,
    required this.size,
    required this.imageUpload,
    this.editSize,
    this.editOffset = Offset.zero,
    this.useBrandPlaceholder = false,
  });

  Future<void> _pickImage(BuildContext context, WidgetRef ref) async {
    final Uint8List? pickedImage = await CustomImagePicker.pickAndCrop(
      minHeight: 100,
      minWidth: 100,
      context: context,
    );
    if (pickedImage != null) {
      ref.read(imagePickerStateProvider.notifier).setImage(
            imageUpload,
            pickedImage,
          );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLight = colorScheme.brightness == Brightness.light;
    final editButtonSize = (editSize ?? 14) * 2;

    if (useBrandPlaceholder && imageCallback.value == null) {
      return Tooltip(
        message: 'Add photo',
        child: Material(
          color: colorScheme.primary.withValues(alpha: isLight ? 0.16 : 0.20),
          shape: CircleBorder(
            side: BorderSide(
              color: colorScheme.primary.withValues(alpha: 0.42),
              width: 1.2,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => _pickImage(context, ref),
            child: SizedBox.square(
              dimension: size * 2,
              child: Icon(
                Icons.add_a_photo_outlined,
                size: size * 0.68,
                color: colorScheme.primaryOnSurface,
              ),
            ),
          ),
        ),
      );
    }

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
                  onTap: () => _pickImage(context, ref),
                  child: SizedBox.square(
                    dimension: 48,
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: Transform.translate(
                        offset: editOffset,
                        child: Ink(
                          width: editButtonSize,
                          height: editButtonSize,
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHigh,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colorScheme.outlineVariant,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.edit,
                            size: editSize == null ? 18 : editSize! * 1.25,
                            color: colorScheme.onSurface,
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
