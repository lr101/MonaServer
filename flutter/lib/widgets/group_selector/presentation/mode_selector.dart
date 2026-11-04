import 'package:buff_lisa/data/service/view_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ModeSelector extends ConsumerWidget {
  const ModeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final current = ref.watch(viewServiceProvider);
    return IntrinsicWidth(
      child: Material(
        color: theme.colorScheme.surfaceContainer,
        shape: StadiumBorder(
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        child: Wrap(
          alignment: WrapAlignment.end,
          children: [
            _option(context, ref, current, ViewState.group, 'Groups'),
            _option(context, ref, current, ViewState.personal, 'Personal'),
          ],
        ),
      ),
    );
  }

  Widget _option(
    BuildContext context,
    WidgetRef ref,
    ViewState current,
    ViewState mode,
    String label,
  ) {
    final selected = current == mode;
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: Semantics(
        label: label,
        selected: selected,
        button: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            if (!selected) {
              ref.read(viewServiceProvider.notifier).toggleViewState();
            }
          },
          child: Container(
            constraints: const BoxConstraints(minWidth: 52, minHeight: 48),
            decoration: ShapeDecoration(
              color: selected ? colors.primary : Colors.transparent,
              shape: const StadiumBorder(),
            ),
            child: Icon(
              mode == ViewState.group
                  ? Icons.groups_outlined
                  : Icons.person_outline,
              color: selected ? colors.onPrimary : colors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// Places map controls on separate lines when large text needs more room.
class MapScopeControls extends StatelessWidget {
  const MapScopeControls({super.key, required this.groupHint});
  final Widget groupHint;
  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    runAlignment: WrapAlignment.end,
    runSpacing: 8,
    spacing: 8,
    children: [groupHint, const ModeSelector()],
  );
}
