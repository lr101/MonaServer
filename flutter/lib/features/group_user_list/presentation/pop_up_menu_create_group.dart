import 'package:buff_lisa/widgets/buttons/presentation/custom_menu_item.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PopUpMenuCreateGroup extends StatelessWidget {

  const PopUpMenuCreateGroup({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton(
        icon: const Icon(Icons.add),
        itemBuilder: (context) {
          return [
            CustomMenuItem<int>(
              value: 0,
              title: "Search existing groups",
              icon: Icons.search,
            ),
            CustomMenuItem<int>(
              value: 1,
              title: "Create a new group",
              icon: Icons.group_add_outlined,
            ),
          ];
        },
        onSelected:(value){
          switch (value) {
            case 0: context.pushNamed("groupSearch");
            case 1: context.pushNamed("groupCreate");
          }
        },
    );
  }
}
