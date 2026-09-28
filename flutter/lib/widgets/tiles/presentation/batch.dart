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
    final color = colorOverride == null || colorOverride == 'default'
        ? achievement.color
        : Color(int.parse(colorOverride!.substring(1), radix: 16));
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(5),
      ),
      padding: EdgeInsets.symmetric(horizontal: 5, vertical: padding),
      child: Text(
        achievement.name,
        style: TextStyle(
          color: Theme.of(context).textTheme.bodyLarge!.color,
          fontSize: fontSize,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
