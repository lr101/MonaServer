import 'package:buff_lisa/features/ranking/data/ranking_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openapi/api.dart';

class RankingSearchDelegate extends SearchDelegate<RankingSearchDtoInner?> {
  final WidgetRef ref;

  static const String _world = "WORLD";
  static const String _worldName = "World wide";

  RankingSearchDelegate({required this.ref, super.searchFieldLabel});

  Future<List<RankingSearchDtoInner>> init() async {
    return await ref.read(rankingSearchProvider.future);
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => Navigator.of(context).pop(),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return FutureBuilder<List<RankingSearchDtoInner>>(
      future: init(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final searchResults = snapshot.requireData
              .where((item) => item.name.toLowerCase().contains(query.toLowerCase()),)
              .toList();
          return ListView.builder(
            itemCount: searchResults.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(searchResults[index].name),
                onTap: () {
                  close(context, searchResults[index]);
                },
              );
            },
          );
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return FutureBuilder<List<RankingSearchDtoInner>>(
      future: init(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final suggestionList = query.isEmpty
              ? [RankingSearchDtoInner(adminLevel: -1, name: _worldName, gid: _world)]
              : snapshot.requireData
                  .where((item) =>
                      item.name.toLowerCase().contains(query.toLowerCase()),)
                  .toList();
          return ListView.builder(
            itemCount: suggestionList.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(suggestionList[index].name),
                onTap: () {
                  close(context, suggestionList[index].gid == _world ? null : suggestionList[index]);
                },
              );
            },
          );
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }
}
