
import 'package:flutter/material.dart';

class UserLikeIcon extends StatelessWidget {

  final int? likeCount;
  final IconData icon;

  const UserLikeIcon({super.key, required this.likeCount, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 30,
            width: 30,
            child: Center(
              child: Icon(icon, size: 24),
            ),
          ),
          const SizedBox(height: 4),
          Text(getLikeCount(), textAlign: TextAlign.center),
        ],
      ),
    );
  }
  
  String getLikeCount() {
    if (likeCount == null) {
      return "---";
    } else if (likeCount! < 1000) {
      return likeCount.toString();
    } else if (likeCount! < 1000000) {
      return "${(likeCount! / 1000).toStringAsFixed(1)}K";
    } else {
      return "${(likeCount! / 1000000).toStringAsFixed(1)}M";
    }
  }
}
