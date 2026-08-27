

import 'package:flutter/material.dart';

class CircleWithIndicator extends StatelessWidget {
  final Color color;
  final int number;

  const CircleWithIndicator({
    super.key,
    required this.color,
    required this.number,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Align(
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary,
              colorScheme.primary.withAlpha(220),
            ],
          ),
          border: Border.all(
            color: colorScheme.onPrimary.withAlpha(40),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withAlpha(80),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                number.toString(),
                style: TextStyle(
                  fontSize: 12.0, // max size
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onPrimary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
