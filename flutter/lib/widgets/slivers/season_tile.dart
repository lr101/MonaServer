import 'package:buff_lisa/data/entity/season_entity.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class SeasonTile extends StatelessWidget {
  final SeasonEntity bestSeason;

  const SeasonTile({super.key, required this.bestSeason});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: const Text("Best All-Time Season", style: TextStyle(fontWeight: FontWeight.bold),),
      subtitle: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: "#${bestSeason.rank}",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _getColor(bestSeason.rank),
              ),
            ),
            TextSpan(
              text: " | ${_getCurrentMonth()} Season | ",
            ),
            TextSpan(
              text: "Points: ${bestSeason.points}",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.info_outline),
        onPressed: () {
          // Show more details about the season
          showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: const Text("Season Details"),
                content: Text(
                  "You achieved rank #${bestSeason.rank} in Season ${bestSeason.seasonNumber} (${DateFormat('MMMM').format(DateTime(0, bestSeason.month))} ${bestSeason.year}), "
                  "with ${bestSeason.points} points! Keep on sticking!",
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text("Close"),
                  ),
                ],
              );
            },
          );
        },
      ),
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


  String _getCurrentMonth() {
    final now = DateTime(bestSeason.year, bestSeason.month);
    final formatter = DateFormat('MMM. yy');
    final currentMonth = formatter.format(now);
    return currentMonth;
  }
}
