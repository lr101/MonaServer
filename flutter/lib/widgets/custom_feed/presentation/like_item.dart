import 'package:flutter/material.dart';

class LikeItem extends StatelessWidget {
  final IconData iconLiked;
  final IconData iconNotLiked;
  final int count;
  final bool liked;

  const LikeItem({super.key, required this.iconLiked, required this.iconNotLiked, required this.count, required this.liked});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          liked ? iconLiked : iconNotLiked,
          color: liked ? Colors.red : Colors.grey,
          size: 30,
        ),
        const SizedBox(height: 4),
        Text(
          count.toString(),
          style: const TextStyle(fontSize: 16),
        ),
      ],
    );
  }
}
