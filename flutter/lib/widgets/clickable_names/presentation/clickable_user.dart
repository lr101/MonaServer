
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ClickableUser extends ConsumerWidget {

  final String userId;
  final Widget child;

  const ClickableUser({super.key, required this.userId, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCurrentUser = ref.watch(globalDataServiceProvider.select((e) => e.userId == userId));
    return GestureDetector(
      onTap: () => isCurrentUser ? null : context.pushNamed("userProfile", pathParameters: {"id": userId}),
      child: child,
    );
  }

}
