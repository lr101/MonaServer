import 'dart:typed_data';

import 'package:buff_lisa/data/entity/group_entity.dart';
import 'package:buff_lisa/data/service/image_service.dart';
import 'package:buff_lisa/util/theme/data/app_color_scheme.dart';
import 'package:buff_lisa/widgets/group_edit_template/service/group_create_service.dart';
import 'package:buff_lisa/widgets/round_image/presentation/round_image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GroupEditTemplate extends ConsumerStatefulWidget {
  const GroupEditTemplate({
    super.key,
    required this.onSubmit,
    this.rowItems,
    this.groupDto,
    required this.title,
    this.embedded = false,
    this.footerItems = const [],
  });

  final Future<void> Function(
    String name,
    String description,
    String? link,
    Uint8List profileImage,
    int visibility,
  )
  onSubmit;

  final List<Widget>? rowItems;
  final GroupEntity? groupDto;
  final String title;
  final bool embedded;
  final List<Widget> footerItems;

  @override
  ConsumerState<GroupEditTemplate> createState() => _GroupEditTemplateState();
}

class _GroupEditTemplateState extends ConsumerState<GroupEditTemplate> {
  final _textEditControllerName = TextEditingController();
  final _textEditControllerDescription = TextEditingController();
  final _textEditControllerLink = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isSubmitting = false;
  bool _showImageError = false;

  bool get _isCreating => widget.groupDto == null;

  @override
  void initState() {
    super.initState();
    final groupDto = widget.groupDto;
    if (groupDto == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(groupCreateServiceProvider.notifier).reset();
      });
      return;
    }

    _textEditControllerName.text = groupDto.name;
    _textEditControllerDescription.text = groupDto.description ?? '';
    _textEditControllerLink.text = groupDto.link ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final image = ref
          .read(groupProfilePictureByIdProvider(groupDto.groupId))
          .value;
      ref.read(groupCreateServiceProvider.notifier).init(groupDto, image);
    });
  }

  @override
  void dispose() {
    _textEditControllerName.dispose();
    _textEditControllerDescription.dispose();
    _textEditControllerLink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.groupDto;
    if (existing != null) {
      ref.listen(groupProfilePictureByIdProvider(existing.groupId), (_, next) {
        final image = next.value;
        if (image != null &&
            ref.read(groupCreateServiceProvider).profileImage == null) {
          ref
              .read(groupCreateServiceProvider.notifier)
              .updateProfileImage(image);
        }
      });
    }
    final group = ref.watch(groupCreateServiceProvider);
    final groupNotifier = ref.watch(groupCreateServiceProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasExtraItems = widget.rowItems?.isNotEmpty ?? false;
    final pickedImage = ref.watch(createGroupProfileImageProvider);

    final form = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    RoundImagePicker(
                      size: 38,
                      useBrandPlaceholder: _isCreating,
                      imageUpload: (image) {
                        groupNotifier.updateProfileImage(image);
                        if (_showImageError && mounted) {
                          setState(() => _showImageError = false);
                        }
                      },
                      imageCallback: AsyncData(pickedImage),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Group photo',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _isCreating && pickedImage == null
                                ? 'Tap to add a group photo.'
                                : 'Tap the pencil to change it.',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_showImageError) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 18,
                        color: colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Add a group photo to continue.',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _textEditControllerName,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Please enter a group name'
                      : null,
                  decoration: _fieldDecoration(
                    colorScheme,
                    label: 'Group name',
                    hint: 'Choose a name people will recognize',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _sectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'About your group',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _textEditControllerDescription,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.newline,
                  minLines: 3,
                  maxLines: 6,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Please enter a group description'
                      : null,
                  decoration: _fieldDecoration(
                    colorScheme,
                    label: 'Description',
                    hint: 'What should people know about it?',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _textEditControllerLink,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.done,
                  validator: (value) {
                    final link = value?.trim() ?? '';
                    if (link.isEmpty) return null;
                    final uri = Uri.tryParse(link);
                    return uri?.isAbsolute == true
                        ? null
                        : 'Enter a valid link, including https://';
                  },
                  decoration: _fieldDecoration(
                    colorScheme,
                    label: 'Website or link (optional)',
                    hint: 'https://example.com',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _sectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Who can join?',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                _VisibilityToggle(
                  selectedVisibility: group.visibility,
                  onChanged: groupNotifier.updateVisibility,
                ),
                const SizedBox(height: 8),
                Text(
                  group.visibility == 1
                      ? 'People need an invite to join this group.'
                      : 'Anyone can find and join this group.',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (hasExtraItems) ...[
            const SizedBox(height: 10),
            ...widget.rowItems!,
          ],
        ],
      ),
    );
    final isLight = Theme.of(context).brightness == Brightness.light;
    final submitBar = SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: isLight
              ? colorScheme.surfaceContainerLowest
              : colorScheme.surfaceContainer,
          border: Border(
            top: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.55),
            ),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                icon: _isSubmitting
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.onPrimary,
                        ),
                      )
                    : Icon(
                        _isCreating
                            ? Icons.group_add_outlined
                            : Icons.save_outlined,
                      ),
                label: Text(
                  _isSubmitting
                      ? (_isCreating ? 'Creating…' : 'Saving…')
                      : (_isCreating ? 'Create group' : 'Save changes'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (widget.embedded) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                form,
                const SizedBox(height: 16),
                SizedBox(
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.onPrimary,
                            ),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_isSubmitting ? 'Saving…' : 'Save changes'),
                  ),
                ),
                if (widget.footerItems.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  ...widget.footerItems,
                ],
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: form,
          ),
        ),
      ),
      bottomNavigationBar: submitBar,
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: child,
      ),
    );
  }

  InputDecoration _fieldDecoration(
    ColorScheme colorScheme, {
    required String label,
    required String hint,
    bool alignLabelWithHint = false,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      alignLabelWithHint: alignLabelWithHint,
    );
  }

  Future<void> _submit() async {
    final formIsValid = _formKey.currentState?.validate() == true;
    final group = ref.read(groupCreateServiceProvider);
    final profileImage = group.profileImage;
    if (profileImage == null) {
      setState(() => _showImageError = true);
    }
    if (!formIsValid || profileImage == null) return;

    setState(() {
      _showImageError = false;
      _isSubmitting = true;
    });
    try {
      await widget.onSubmit(
        _textEditControllerName.text.trim(),
        _textEditControllerDescription.text.trim(),
        _textEditControllerLink.text.trim().isEmpty
            ? null
            : _textEditControllerLink.text.trim(),
        profileImage,
        group.visibility,
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

class _VisibilityToggle extends StatelessWidget {
  const _VisibilityToggle({
    required this.selectedVisibility,
    required this.onChanged,
  });

  final int selectedVisibility;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _VisibilitySegment(
              icon: Icons.public_outlined,
              label: 'Public',
              selected: selectedVisibility == 0,
              isLight: isLight,
              onTap: () => onChanged(0),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _VisibilitySegment(
              icon: Icons.lock_outline,
              label: 'Private',
              selected: selectedVisibility == 1,
              isLight: isLight,
              onTap: () => onChanged(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _VisibilitySegment extends StatelessWidget {
  const _VisibilitySegment({
    required this.icon,
    required this.label,
    required this.selected,
    required this.isLight,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool isLight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final fg = selected ? colors.primaryOnSurface : colors.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected
            ? colors.primary.withValues(alpha: isLight ? 0.44 : 0.32)
            : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: selected
              ? BorderSide(
                  color: colors.primaryOnSurface.withValues(
                    alpha: isLight ? 0.28 : 0.36,
                  ),
                )
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 17, color: fg),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: fg,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
