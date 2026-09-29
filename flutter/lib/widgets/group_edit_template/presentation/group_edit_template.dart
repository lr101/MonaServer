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
      ref.read(groupCreateServiceProvider.notifier).reset();
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
    final group = ref.watch(groupCreateServiceProvider);
    final groupNotifier = ref.watch(groupCreateServiceProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasExtraItems = widget.rowItems?.isNotEmpty ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Form(
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
                          size: 40,
                          imageUpload: (image) {
                            groupNotifier.updateProfileImage(image);
                            if (_showImageError && mounted) {
                              setState(() => _showImageError = false);
                            }
                          },
                          imageCallback: AsyncData(
                            ref.watch(createGroupProfileImageProvider),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Group photo',
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tap the pencil to choose or change it.',
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
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _textEditControllerName,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
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
              const SizedBox(height: 16),
              _sectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'About your group',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _textEditControllerDescription,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.newline,
                      minLines: 3,
                      maxLines: 6,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Please enter a group description'
                          : null,
                      decoration: _fieldDecoration(
                        colorScheme,
                        label: 'Description',
                        hint: 'What should people know about it?',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 16),
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
              const SizedBox(height: 16),
              _sectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Who can join?',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          avatar: const Icon(Icons.public, size: 18),
                          label: const Text('Public'),
                          selected: group.visibility == 0,
                          onSelected: (_) => groupNotifier.updateVisibility(0),
                        ),
                        ChoiceChip(
                          avatar: const Icon(Icons.lock_outline, size: 18),
                          label: const Text('Private'),
                          selected: group.visibility == 1,
                          onSelected: (_) => groupNotifier.updateVisibility(1),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      group.visibility == 1
                          ? 'People need an invite to join this group.'
                          : 'Anyone can find and join this group.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasExtraItems) ...[
                const SizedBox(height: 16),
                ...widget.rowItems!,
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
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
                height: 54,
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
      ),
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }

  InputDecoration _fieldDecoration(
    ColorScheme colorScheme, {
    required String label,
    required String hint,
    bool alignLabelWithHint = false,
  }) {
    final borderRadius = BorderRadius.circular(12);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      alignLabelWithHint: alignLabelWithHint,
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.22),
      enabledBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: colorScheme.primaryOnSurface, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: colorScheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: colorScheme.error, width: 2),
      ),
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
