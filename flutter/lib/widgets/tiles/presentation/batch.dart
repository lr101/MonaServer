import 'package:buff_lisa/util/theme/data/app_color_scheme.dart';
import 'package:buff_lisa/util/types/achievement.dart';
import 'package:flutter/material.dart';

class Batch extends StatelessWidget {
  final int batchId;
  final double? fontSize;
  final String? colorOverride;

  const Batch({
    super.key,
    required this.batchId,
    this.fontSize,
    this.colorOverride,
  });

  @override
  Widget build(BuildContext context) {
    final double padding = fontSize != null && fontSize! < 8.0 ? 1 : 2;
    final achievement = Achievement.getById(batchId);
    final isCapstone = const {16, 19, 20, 21, 22, 23, 26, 29}.contains(batchId);
    final color = colorOverride == null || colorOverride == 'default'
        ? achievement.color
        : Color(int.parse(colorOverride!.substring(1), radix: 16));
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(5),
        border: isCapstone
            ? Border.all(
                color: Theme.of(context).colorScheme.primaryOnSurface,
                width: 1.5,
              )
            : null,
      ),
      padding: EdgeInsets.symmetric(horizontal: 5, vertical: padding),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isCapstone) ...[
            Icon(
              Icons.auto_awesome,
              key: const ValueKey('capstone-badge-mark'),
              size: fontSize == null ? 13 : fontSize! + 3,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(width: 3),
          ],
          Text(
            achievement.name,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge!.color,
              fontSize: fontSize,
              fontStyle: FontStyle.italic,
              fontWeight: isCapstone ? FontWeight.w700 : null,
            ),
          ),
        ],
      ),
    );
  }
}
