import 'package:buff_lisa/data/service/global_data_service.dart'; // Adjust path
import 'package:buff_lisa/data/service/image_service.dart';
import 'package:buff_lisa/data/service/user_service.dart';
import 'package:buff_lisa/features/navigation/data/navigation_provider.dart';
import 'package:buff_lisa/widgets/group_selector/presentation/group_filter.dart';
import 'package:buff_lisa/widgets/round_image/presentation/round_image.dart';
import 'package:buff_lisa/widgets/tiles/presentation/batch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TopStatusBar extends ConsumerWidget {
  const TopStatusBar({super.key});

  

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const double height = 48.0;   
    const double borderRadius = 24.0;
    const double innerPadding = 4.0; 


    final theme = Theme.of(context);
    final userId = ref.watch(userIdProvider);
    final user = ref.watch(currentUserProvider).value;
  

    return GestureDetector(
      onTap: () => ref.read(navigationStateProvider.notifier).setIndex(4),
      child: Container(
      height: height,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: innerPadding),
        child: Row(
          children: [
            RoundImage(
              size: 20,
              imageCallback: ref.watch(getUserProfileSmallProvider(userId)), 
            ),
              
            
            const SizedBox(width: 12),

            // 2. NAME & XP BAR
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  
                      Text(
                        user?.username ?? "",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      
                      if (user?.selectedBatch != null)
                        GestureDetector(
                          child: Batch(
                            batchId: user!.selectedBatch!,
                            fontSize: 7,
                          ),
                        )
                ]
              ),
            ),

            const SizedBox(width: 16),

            const GroupFilterWidget(),
          ],
        ),
      )
    ));
  }
}
