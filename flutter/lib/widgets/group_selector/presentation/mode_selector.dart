import 'package:buff_lisa/data/service/view_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ModeSelector extends ConsumerWidget {
  const ModeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final isLight = colors.brightness == Brightness.light;
    final current = ref.watch(viewServiceProvider);
    return IntrinsicWidth(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isLight ? 0.07 : 0.24),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: isLight
              ? colors.surfaceContainerLow.withValues(alpha: 0.96)
              : colors.surfaceContainer.withValues(alpha: 0.96),
          surfaceTintColor: Colors.transparent,
          shape: StadiumBorder(
            side: BorderSide(
              color: colors.outlineVariant.withValues(
                alpha: isLight ? 0.65 : 0.72,
              ),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Wrap(
              alignment: WrapAlignment.end,
              children: [
                _option(context, ref, current, ViewState.group, 'Groups'),
                _option(context, ref, current, ViewState.personal, 'Mine'),
              ],
            ),
          ),
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
    final fg = selected ? colors.onPrimary : colors.onSurfaceVariant;
    final semanticLabel = mode == ViewState.personal ? 'Personal' : label;
    return Tooltip(
      message: semanticLabel,
      excludeFromSemantics: true,
      child: Semantics(
        label: semanticLabel,
        selected: selected,
        button: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            if (!selected) {
              ref.read(viewServiceProvider.notifier).toggleViewState();
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            constraints: const BoxConstraints(minHeight: 34),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: ShapeDecoration(
              color: selected ? colors.primary : Colors.transparent,
              shape: const StadiumBorder(),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  mode == ViewState.group
                      ? (selected ? Icons.groups : Icons.groups_outlined)
                      : (selected ? Icons.person : Icons.person_outline),
                  size: 17,
                  color: fg,
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Signika',
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: fg,
                  ),
                ),
              ],
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
