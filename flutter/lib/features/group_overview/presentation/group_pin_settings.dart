import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/database/account_session.dart';
import 'package:buff_lisa/data/entity/group_entity.dart';
import 'package:buff_lisa/data/service/group_service.dart';
import 'package:buff_lisa/features/group_overview/presentation/group_pin_builder.dart';
import 'package:buff_lisa/widgets/custom_marker/data/group_pin_design.dart';
import 'package:buff_lisa/widgets/custom_marker/data/group_pin_design_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openapi/api.dart';

class GroupPinSettings extends ConsumerWidget {
  const GroupPinSettings({super.key, required this.group});
  final GroupEntity group;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(groupPinDesignCatalogProvider(group.groupId))
        .when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => TextButton(
            onPressed: () =>
                ref.invalidate(groupPinDesignCatalogProvider(group.groupId)),
            child: const Text('Retry pin appearance'),
          ),
          data: (catalog) {
            final earned =
                catalog?.designs
                    .where((d) => d.style.value != 'classic')
                    .toList() ??
                <GroupPinDesignDto>[];
            if (earned.isEmpty) {
              return const ListTile(
                title: Text('Pin appearance'),
                subtitle: Text(
                  'Collect group achievement rewards to unlock pin colors and shapes.',
                ),
              );
            }
            final selected =
                earned
                    .where((d) => d.style.value == group.pinStyle)
                    .firstOrNull ??
                earned.first;
            var revision = catalog!.revision;
            return GroupPinBuilder(
              key: ValueKey('${group.groupId}-${catalog.revision}'),
              initial: MapPinDesign.fromDto(selected),
              unlocked: [
                for (final d in earned) MapPinDesign.forStyle(d.style.value),
              ],
              onSave: (design) async {
                final session = ref.read(accountSessionProvider);
                final saved = await ref
                    .read(groupPinDesignsApiProvider)
                    .updateGroupPinDesignCatalog(
                      group.groupId,
                      UpdateGroupPinDesignCatalogDto(
                        design: design.toDto(),
                        expectedRevision: revision,
                      ),
                    );
                if (!session.isActive) return;
                revision = saved?.revision ?? revision;
                final error = await ref
                    .read(userGroupServiceProvider.notifier)
                    .updateGroup(
                      group
                          .copyWith(pinStyle: design.style)
                          .toUpdateGroupDto(null),
                      group.groupId,
                    );
                if (error != null) throw StateError(error);
                if (!session.isActive) return;
                ref.invalidate(groupPinDesignCatalogProvider(group.groupId));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Pin appearance saved')),
                  );
                }
              },
            );
          },
        );
  }
}
