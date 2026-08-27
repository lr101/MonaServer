import 'package:flutter/material.dart';
import 'package:openapi/api.dart';

class BestSeason extends StatelessWidget {

  final SeasonItemDto seasonItemDto;
  final double? fontSize;

  const BestSeason(
      {super.key, required this.seasonItemDto, required this.fontSize,});

  @override
  Widget build(BuildContext context) {
    final double padding = fontSize != null && fontSize! < 8.0 ? 1 : 2;
    final color = _getColor(seasonItemDto.rank);
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(5),
      ),
      padding: EdgeInsets.symmetric(horizontal: 5, vertical: padding),
      child: Text(
        "#${seasonItemDto.rank} in season ${seasonItemDto.season.seasonNumber}",
        style: TextStyle(
            color: Theme
                .of(context)
                .textTheme
                .bodyLarge!
                .color, fontSize: fontSize, fontStyle: FontStyle.italic,),),
    );
  }

  Color _getColor(int rankNr) {
    switch (rankNr) {
      case 1:
        return Colors.yellow;
      case 2:
        return Colors.grey;
      case 3:
        return Colors.brown;
      default:
        return Colors.orangeAccent;
    }
  }
}
