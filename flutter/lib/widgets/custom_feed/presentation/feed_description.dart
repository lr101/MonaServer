import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/widgets/custom_feed/data/feed_description.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FeedDescriptionExpandable extends ConsumerWidget {
  const FeedDescriptionExpandable({
    super.key,
    required this.pin,
  });

  final PinEntity pin;

  static const showLessOrMoreStyle = TextStyle(
    fontWeight: FontWeight.bold,
    color: Colors.grey, // Instagram style "more" is usually greyish
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // NOTE: Ensure feedDescriptionProvider is defined in your state management
    final isExpanded = ref.watch(feedDescriptionProvider(pin.pinId));
    final toggleExpansion = ref.watch(feedDescriptionProvider(pin.pinId).notifier);
    final text = pin.description ?? "";

    return LayoutBuilder(
      builder: (context, constraints) {
        final defaultStyle = DefaultTextStyle.of(context).style;
        
        final textPainterExpanded = getTextPainter(text, defaultStyle, null, constraints.maxWidth);
        
        final numLines = textPainterExpanded.computeLineMetrics().length;
        
        // If text is short, just show it
        if (numLines <= 2) {
          return Text(text, style: defaultStyle);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The Description Text
            GestureDetector(
               onTap: () => toggleExpansion.toggle(),
               child: Text(
                text,
                maxLines: isExpanded ? null : 2,
                overflow: isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                style: defaultStyle,
              ),
            ),
            // The "more/less" button
            GestureDetector(
              onTap: toggleExpansion.toggle,
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  isExpanded ? '• less' : '• more',
                  style: showLessOrMoreStyle,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  TextPainter getTextPainter(String text, TextStyle style, int? numLines, double maxWidth) {
    return TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: numLines,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
  }
}
