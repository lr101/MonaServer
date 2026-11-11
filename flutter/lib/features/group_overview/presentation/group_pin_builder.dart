import 'package:buff_lisa/widgets/custom_marker/data/group_pin_design.dart';
import 'package:buff_lisa/widgets/custom_marker/presentation/custom_marker_content.dart';
import 'package:flutter/material.dart';

/// Combines the group's earned palette and geometric outlines.
class GroupPinBuilder extends StatefulWidget {
  const GroupPinBuilder({
    super.key,
    required this.initial,
    required this.unlocked,
    required this.onSave,
  });
  final MapPinDesign initial;
  final List<MapPinDesign> unlocked;
  final Future<void> Function(MapPinDesign) onSave;
  @override
  State<GroupPinBuilder> createState() => _GroupPinBuilderState();
}

class _GroupPinBuilderState extends State<GroupPinBuilder> {
  late MapPinDesign draft = widget.initial.copyWith(badge: 'none');
  bool saving = false;
  String? error;
  @override
  Widget build(BuildContext context) {
    final colors = {for (final d in widget.unlocked) d.bodyColor: d};
    final shapes = {for (final d in widget.unlocked) d.shape: d};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pin appearance', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text(
          'Combine colors and shapes collected from group achievements.',
        ),
        const SizedBox(height: 16),
        Center(
          child: SizedBox(
            width: 72,
            height: 88,
            child: PinMarkerImage(
              isGone: false,
              style: draft.style,
              design: draft,
              image: Icon(
                Icons.groups,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text('Color'),
        Wrap(
          spacing: 8,
          children: [
            for (final d in colors.values)
              ChoiceChip(
                avatar: CircleAvatar(backgroundColor: d.bodyColor, radius: 8),
                label: Text(d.name),
                selected: draft.bodyColor == d.bodyColor,
                onSelected: saving
                    ? null
                    : (_) => setState(
                        () => draft = draft.copyWith(bodyColor: d.bodyColor),
                      ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        const Text('Shape'),
        Wrap(
          spacing: 8,
          children: [
            for (final shape in shapes.keys)
              ChoiceChip(
                label: Text(shape[0].toUpperCase() + shape.substring(1)),
                selected: draft.shape == shape,
                onSelected: saving
                    ? null
                    : (_) =>
                          setState(() => draft = draft.copyWith(shape: shape)),
              ),
          ],
        ),
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: saving
              ? null
              : () async {
                  setState(() {
                    saving = true;
                    error = null;
                  });
                  try {
                    await widget.onSave(draft);
                  } catch (_) {
                    if (mounted) {
                      setState(
                        () =>
                            error = 'Could not save pin appearance. Try again.',
                      );
                    }
                  } finally {
                    if (mounted) setState(() => saving = false);
                  }
                },
          child: Text(saving ? 'Saving…' : 'Save pin appearance'),
        ),
      ],
    );
  }
}
