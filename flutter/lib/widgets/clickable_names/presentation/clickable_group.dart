
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ClickableGroup extends ConsumerWidget {

  final String groupId;
  final Widget child;

  const ClickableGroup({super.key, required this.groupId, required this.child});


  @override
  Widget build(BuildContext context, WidgetRef ref) {
      return GestureDetector(
        onTap: () => context.pushNamed("groupOverview", pathParameters: {"id": groupId}),
        child: child,
      );
  }

}
