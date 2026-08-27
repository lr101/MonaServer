import 'package:buff_lisa/data/service/group_service.dart';
import 'package:buff_lisa/data/service/image_service.dart';
import 'package:buff_lisa/widgets/group_selector/service/group_order_service.dart';
import 'package:buff_lisa/widgets/round_image/presentation/round_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:transparent_image/transparent_image.dart';

class RoundGroupCard extends ConsumerStatefulWidget {
  const RoundGroupCard({super.key});

  @override
  ConsumerState<RoundGroupCard> createState() => _RoundGroupCardState();
}

class _RoundGroupCardState extends ConsumerState<RoundGroupCard> {
  @override
  Widget build(BuildContext context) {
    final double baseHeight = (MediaQuery.of(context).size.height * 0.09) - 15;
    final Color color = Colors.grey.withValues(alpha: 0.8);
    final groupId = ref.watch(roundGroupIdProvider);
    final isActive = ref.watch(groupByIdActivatedProvider(groupId)).value ?? false;

    return Padding(
              padding: const EdgeInsets.all(5),
              child: GestureDetector(
                  onTap: () => {
                        ref
                            .watch(userGroupServiceProvider.notifier)
                            .setIsActive(groupId, !isActive),
                      },
                  child: Stack(children: [
                    ClipOval(
                      child: Container(
                        height: baseHeight,
                        width: baseHeight,
                        decoration: BoxDecoration(
                            color: isActive ? color : Colors.transparent,),
                      ),
                    ),
                    RoundImage(
                      size: baseHeight / 2,
                      defaultPlaceholderImage: kTransparentImage,
                      imageCallback: AsyncData(ref.watch(groupProfilePictureByIdProvider(groupId)).value),
                      child: ClipOval(
                        child: Container(
                          height: baseHeight,
                          width: baseHeight,
                          decoration: BoxDecoration(
                              color: isActive ? Colors.transparent : color,),
                        ),
                      ),
                    ),
                  ],),),);

  }
}
