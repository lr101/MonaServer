import 'package:flutter/material.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

class MapPanelDraggable extends StatelessWidget {
  const MapPanelDraggable({super.key, required this.panelController});

  final PanelController panelController;

  @override
  Widget build(BuildContext context) {
    return Align(
        alignment: Alignment.topCenter,
        child: GestureDetector(
          onTap: _closePanel,
          child: Container(
              height: 22,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(10),
                    topRight: Radius.circular(10),),
              ),
              child: Center(
                  child: Container(
                      width: MediaQuery.of(context).size.width * 0.35,
                      height: 5,
                      decoration: BoxDecoration(
                          color: Theme.of(context).hintColor,
                          borderRadius:
                              const BorderRadius.all(Radius.circular(2.5)),),),),),
        ),);
  }

  Future<void> _closePanel() async {
    await panelController.animatePanelToPosition(0.0,
        duration: const Duration(milliseconds: 200),);
  }
}
