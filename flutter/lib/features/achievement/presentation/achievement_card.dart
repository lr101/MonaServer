
import 'package:flutter/material.dart';

class AchievementCard extends StatelessWidget {
  final double progress; // Progress between 0.0 and 1.0
  final Color progressColor; // Color for the progress border
  final Widget child; // Content inside the card
  final Color claimedBorderColor;
  final bool isSelected;
  final Color? color;
  final double borderWidth;
  final EdgeInsetsGeometry? margin;
  
  const AchievementCard({
    super.key,
    required this.progress,
    this.progressColor = Colors.blue,
    required this.child,
    required this.claimedBorderColor,
    required this.isSelected,
    this.color,
    this.borderWidth = 2.0,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    if (isSelected || progress == 1.0) {
      return Card(
      color: color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: BorderSide(color: isSelected ? claimedBorderColor : progressColor, width: borderWidth),
        ),
        margin: margin,
        child: child,
      );
    }
    return Padding(
        padding: margin ?? EdgeInsets.zero,
      child: CustomPaint(
        painter: ProgressBorderPainter(
          progress: progress,
          progressColor: progressColor,
          borderWidth: borderWidth,
        ),
        child: Padding(
          padding: EdgeInsets.all(borderWidth), child:
        Card(
          color: color,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: child,
        ),
      ),),);
  }
}

class ProgressBorderPainter extends CustomPainter {
  final double progress;
  final Color progressColor;
  final double borderWidth;

  ProgressBorderPainter({required this.progress, required this.progressColor, required this.borderWidth});

  @override
  void paint(Canvas canvas, Size size) {
    const radius = 12.0;

    // Adjust the drawing rect to account for the stroke width
    final rect = Rect.fromLTWH(
      borderWidth / 2,
      borderWidth / 2,
      size.width - borderWidth,
      size.height - borderWidth,
    );

    final paintBackground = Paint()
      ..color = Colors.transparent
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final paintProgress = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeCap = StrokeCap.round;

    // Draw full border as a transparent background
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(radius)),
      paintBackground,
    );

    // Draw the progress border
    final progressPath = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(radius)));

    for (final metric in progressPath.computeMetrics()) {
      final length = metric.length * progress; // Adjust length based on progress
      canvas.drawPath(
        metric.extractPath(0, length),
        paintProgress,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true; // Redraw when progress changes
  }
}
