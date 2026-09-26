import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/service/image_service.dart';
import 'package:buff_lisa/widgets/custom_marker/data/default_group_image.dart';
import 'package:buff_lisa/widgets/custom_marker/data/group_pin_design.dart';
import 'package:buff_lisa/widgets/custom_marker/presentation/custom_marker_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openapi/api.dart';

class GroupPinCustomizer extends ConsumerStatefulWidget {
  const GroupPinCustomizer({
    super.key,
    required this.groupId,
    required this.unlockedStyles,
    required this.activeStyle,
  });

  final String groupId;
  final List<String> unlockedStyles;
  final String activeStyle;

  @override
  ConsumerState<GroupPinCustomizer> createState() => _GroupPinCustomizerState();
}

class _GroupPinCustomizerState extends ConsumerState<GroupPinCustomizer> {
  late Future<GroupPinDesignCatalogDto?> _catalog;

  @override
  void initState() {
    super.initState();
    _catalog = _loadCatalog();
  }

  Future<GroupPinDesignCatalogDto?> _loadCatalog() => Future.sync(
    () => ref
        .read(groupPinDesignsApiProvider)
        .getGroupPinDesignCatalog(widget.groupId),
  );

  @override
  Widget build(BuildContext context) => ExpansionTile(
    tilePadding: EdgeInsets.zero,
    childrenPadding: EdgeInsets.zero,
    maintainState: true,
    title: const Text('Customize earned designs'),
    subtitle: const Text('Shape, colors, image crop, and achievement badges'),
    children: [
      FutureBuilder<GroupPinDesignCatalogDto?>(
        future: _catalog,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _catalog = _loadCatalog()),
                icon: const Icon(Icons.refresh),
                label: const Text('Could not load designs. Retry.'),
              ),
            );
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return const LinearProgressIndicator(minHeight: 2);
          }
          final value = snapshot.data;
          if (value == null) {
            return const Align(
              alignment: Alignment.centerLeft,
              child: Text('Pin designs are unavailable.'),
            );
          }
          return _GroupPinDesignEditor(
            key: ValueKey('${widget.groupId}:${value.revision}'),
            groupId: widget.groupId,
            catalog: value,
            unlockedStyles: widget.unlockedStyles,
            activeStyle: widget.activeStyle,
          );
        },
      ),
    ],
  );
}

class _GroupPinDesignEditor extends ConsumerStatefulWidget {
  const _GroupPinDesignEditor({
    super.key,
    required this.groupId,
    required this.catalog,
    required this.unlockedStyles,
    required this.activeStyle,
  });

  final String groupId;
  final GroupPinDesignCatalogDto catalog;
  final List<String> unlockedStyles;
  final String activeStyle;

  @override
  ConsumerState<_GroupPinDesignEditor> createState() =>
      _GroupPinDesignEditorState();
}

class _GroupPinDesignEditorState extends ConsumerState<_GroupPinDesignEditor> {
  late int _revision;
  late String _selectedStyle;
  late Map<String, MapPinDesign> _designs;
  bool _saving = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _revision = widget.catalog.revision;
    _selectedStyle = widget.unlockedStyles.contains(widget.activeStyle)
        ? widget.activeStyle
        : widget.unlockedStyles.first;
    _designs = {
      for (final design in widget.catalog.designs)
        design.style.value: MapPinDesign.fromDto(design),
    };
  }

  MapPinDesign get _design =>
      _designs[_selectedStyle] ?? MapPinDesign.forStyle(_selectedStyle);

  void _change(MapPinDesign design) {
    setState(() {
      _designs[_selectedStyle] = design;
      _saved = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final updated = await ref
          .read(groupPinDesignsApiProvider)
          .updateGroupPinDesignCatalog(
            widget.groupId,
            UpdateGroupPinDesignCatalogDto(
              expectedRevision: _revision,
              design: _design.toDto(),
            ),
          );
      if (!mounted || updated == null) return;
      setState(() {
        _revision = updated.revision;
        for (final design in updated.designs) {
          _designs.putIfAbsent(
            design.style.value,
            () => MapPinDesign.fromDto(design),
          );
        }
        _saved = true;
      });
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Pin design saved. It will appear after app restart.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Could not save this pin design. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final design = _design;
    final groupImage = ref.watch(defaultGroupPinImageProvider);
    final pinImage = ref.watch(groupPinImageByIdProvider(widget.groupId)).value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: SizedBox(
            width: 58,
            height: 66,
            child: PinMarkerImage(
              isGone: false,
              style: design.style,
              design: design,
              image: Image.memory(
                pinImage ?? groupImage,
                fit: BoxFit.cover,
                alignment: Alignment(
                  design.imageAlignmentX,
                  design.imageAlignmentY,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _selectedStyle,
          decoration: const InputDecoration(
            labelText: 'Unlocked style',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: [
            for (final style in widget.unlockedStyles)
              DropdownMenuItem(value: style, child: Text(_styleName(style))),
          ],
          onChanged: _saving
              ? null
              : (style) {
                  if (style != null) setState(() => _selectedStyle = style);
                },
        ),
        const SizedBox(height: 12),
        Text('Shape', style: theme.textTheme.labelLarge),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            for (final shape in _shapes)
              ChoiceChip(
                label: Text(_shapeName(shape)),
                selected: design.shape == shape,
                onSelected: _saving
                    ? null
                    : (_) => _change(design.copyWith(shape: shape)),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _ColorPaletteControl(
          title: 'Pin color',
          selected: design.bodyColor,
          onSelected: (color) => _change(design.copyWith(bodyColor: color)),
          enabled: !_saving,
        ),
        const SizedBox(height: 10),
        _ColorPaletteControl(
          title: 'Outline color',
          selected: design.outlineColor,
          onSelected: (color) => _change(design.copyWith(outlineColor: color)),
          enabled: !_saving,
        ),
        const SizedBox(height: 10),
        _ColorPaletteControl(
          title: 'Image frame color',
          selected: design.imageBorderColor,
          onSelected: (color) =>
              _change(design.copyWith(imageBorderColor: color)),
          enabled: !_saving,
        ),
        const SizedBox(height: 8),
        _SliderControl(
          label: 'Image zoom',
          value: design.imageZoom,
          minimum: 1,
          maximum: 2.5,
          divisions: 15,
          onChanged: _saving
              ? null
              : (value) => _change(design.copyWith(imageZoom: value)),
        ),
        _SliderControl(
          label: 'Image left / right',
          value: design.imageAlignmentX,
          minimum: -1,
          maximum: 1,
          divisions: 20,
          onChanged: _saving
              ? null
              : (value) => _change(design.copyWith(imageAlignmentX: value)),
        ),
        _SliderControl(
          label: 'Image up / down',
          value: design.imageAlignmentY,
          minimum: -1,
          maximum: 1,
          divisions: 20,
          onChanged: _saving
              ? null
              : (value) => _change(design.copyWith(imageAlignmentY: value)),
        ),
        _SliderControl(
          label: 'Image frame inset',
          value: design.imageInset,
          minimum: 0,
          maximum: 8,
          divisions: 16,
          onChanged: _saving
              ? null
              : (value) => _change(design.copyWith(imageInset: value)),
        ),
        _SliderControl(
          label: 'Outline width',
          value: design.outlineWidth,
          minimum: 0,
          maximum: 5,
          divisions: 10,
          onChanged: _saving
              ? null
              : (value) => _change(design.copyWith(outlineWidth: value)),
        ),
        const SizedBox(height: 8),
        Text('Achievement badge', style: theme.textTheme.labelLarge),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final badge in _badges)
              ChoiceChip(
                avatar: Icon(_badgeIcon(badge), size: 16),
                label: Text(_badgeName(badge)),
                selected: design.badge == badge,
                onSelected: _saving
                    ? null
                    : (_) => _change(design.copyWith(badge: badge)),
              ),
          ],
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Pin shadow'),
          value: design.shadow,
          onChanged: _saving
              ? null
              : (value) => _change(design.copyWith(shadow: value)),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _saving || _saved ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_saved ? 'Saved' : 'Save design'),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Saved designs are loaded when the app restarts.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ColorPaletteControl extends StatelessWidget {
  const _ColorPaletteControl({
    required this.title,
    required this.selected,
    required this.onSelected,
    required this.enabled,
  });

  final String title;
  final Color selected;
  final ValueChanged<Color> onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 6),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final color in _colors)
            Semantics(
              button: true,
              selected: color.toARGB32() == selected.toARGB32(),
              label: '$title ${_colorName(color)}',
              child: InkWell(
                onTap: enabled ? () => onSelected(color) : null,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color.toARGB32() == selected.toARGB32()
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outlineVariant,
                      width: color.toARGB32() == selected.toARGB32() ? 3 : 1,
                    ),
                  ),
                  child: color.toARGB32() == selected.toARGB32()
                      ? Icon(
                          Icons.check,
                          size: 16,
                          color: color.computeLuminance() > .5
                              ? Colors.black87
                              : Colors.white,
                        )
                      : null,
                ),
              ),
            ),
        ],
      ),
    ],
  );
}

class _SliderControl extends StatelessWidget {
  const _SliderControl({
    required this.label,
    required this.value,
    required this.minimum,
    required this.maximum,
    required this.divisions,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double minimum;
  final double maximum;
  final int divisions;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('$label · ${value.toStringAsFixed(1)}'),
      Slider(
        value: value.clamp(minimum, maximum),
        min: minimum,
        max: maximum,
        divisions: divisions,
        onChanged: onChanged,
      ),
    ],
  );
}

const _shapes = ['circle', 'teardrop', 'shield'];
const _badges = ['none', 'star', 'leaf', 'sun', 'spark'];
const _colors = [
  Color(0xff2457d6),
  Color(0xff668465),
  Color(0xffd57b50),
  Color(0xff6d77ba),
  Color(0xffc34f63),
  Color(0xffe0aa32),
  Color(0xff178b88),
  Color(0xff353b44),
  Color(0xffeeeeee),
  Color(0xffffffff),
];

String _styleName(String style) => switch (style) {
  'moss' => 'Moss',
  'sunset' => 'Sunset',
  'aurora' => 'Aurora',
  _ => 'Classic',
};

String _shapeName(String shape) => switch (shape) {
  'teardrop' => 'Teardrop',
  'shield' => 'Shield',
  _ => 'Circle',
};

IconData? _badgeIcon(String badge) => switch (badge) {
  'star' => Icons.star,
  'leaf' => Icons.eco,
  'sun' => Icons.wb_sunny,
  'spark' => Icons.auto_awesome,
  _ => null,
};

String _badgeName(String badge) => switch (badge) {
  'star' => 'Star',
  'leaf' => 'Leaf',
  'sun' => 'Sun',
  'spark' => 'Spark',
  _ => 'None',
};

String _colorName(Color color) =>
    '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
