import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OsmCopyright extends StatelessWidget {
  const OsmCopyright({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isLight = colors.brightness == Brightness.light;
    return Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: GestureDetector(
          onTap: () => _onTap(context),
          child: Container(
            decoration: BoxDecoration(
              color: (isLight
                      ? colors.surfaceContainerLowest
                      : colors.surfaceContainerHigh)
                  .withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isLight ? 0.08 : 0.24),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            child: Text(
              "© OpenStreetMap",
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onTap(BuildContext context) {
    context.pushNamed(
      "web",
      queryParameters: {
        "url": "https://www.openstreetmap.org/copyright",
        "title": "OpenStreetMap Copyright",
      },
    );
  }
}
