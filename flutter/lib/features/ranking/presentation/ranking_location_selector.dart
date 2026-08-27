import 'package:buff_lisa/features/ranking/data/ranking_state.dart';
import 'package:buff_lisa/features/ranking/presentation/ranking_search_delegate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openapi/api.dart';

class RankingLocationSelector extends StatelessWidget {
  const RankingLocationSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      width: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.5),
            spreadRadius: 5,
            blurRadius: 7,
            offset: const Offset(0, 3), // changes position of shadow
          ),
        ],
      ),
      child:  Padding(
        padding: const EdgeInsets.all(2.0),
        child: Image.asset("assets/image/leaderboard.png",),
      ),
    );
  }
}

class RankingLocationSearch extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rankingState = ref.watch(rankingGidProvider);
    final rankingStateNotifier = ref.watch(rankingGidProvider.notifier);
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.5,
      child: TextButton(
        onPressed: () async {
          final selectedGid = await showSearch<RankingSearchDtoInner?>(
            context: context,
            delegate: RankingSearchDelegate(
                ref: ref, searchFieldLabel: "Search a place",),
          );
          rankingStateNotifier.update(selectedGid);
        },
        child: Text(
          rankingState == null ? 'World wide' : rankingState.name,
          style: const TextStyle(fontSize: 12),
          overflow: TextOverflow.fade,
        ),
      ),
    );
  }
}
