import 'package:buff_lisa/data/service/filter_service.dart';
import 'package:buff_lisa/widgets/tiles/presentation/user_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EditHiddenUsers extends ConsumerWidget {
  const EditHiddenUsers({super.key});



  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hiddenUsers = ref.watch(hiddenUserServiceProvider);
    return Scaffold(
      appBar: AppBar(title: const Text("Edit hidden users", style: TextStyle(fontWeight: FontWeight.bold))),
      body: ListView.builder(
        itemBuilder: (context, index) => UserTile(userId: hiddenUsers[index]),
        itemCount: hiddenUsers.length,
      ),
    );
  }

}
