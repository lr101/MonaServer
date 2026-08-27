import 'package:buff_lisa/data/service/filter_service.dart';
import 'package:buff_lisa/widgets/custom_interaction/presentation/custom_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EditHiddenPosts extends ConsumerStatefulWidget {
  const EditHiddenPosts({super.key});

  @override
  ConsumerState<EditHiddenPosts> createState() => _EditHiddenPostsState();
}

class _EditHiddenPostsState extends ConsumerState<EditHiddenPosts> {

  @override
  Widget build(BuildContext context) {
    final hiddenPosts = ref.watch(hiddenPostsServiceProvider);
    return Scaffold(
        appBar: AppBar(title: const Text("Edit hidden Posts", style: TextStyle(fontWeight: FontWeight.bold))),
        body: CustomScrollView(slivers: [
          const SliverToBoxAdapter(
            child: Text("Tap on the post to remove it from the list"),
          ),
          SliverList.builder(
            itemCount: hiddenPosts.length,
            itemBuilder: (context, index) => ListTile(
                onTap: () => CustomDialog.show(context,
                    acceptText: "Remove",
                    title: "Remove hidden post",
                    onPressed: () => ref
                        .read(hiddenPostsServiceProvider.notifier)
                        .removeHiddenPost(hiddenPosts[index]),),
                title: const Text("test")))
          
        ],),);
  }
}
