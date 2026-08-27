
import 'package:flutter/material.dart';

class CustomCloseKeyboardScaffold extends StatelessWidget {

  const CustomCloseKeyboardScaffold({super.key, required this.body, this.appBar});
  
  final Widget body;
  final PreferredSizeWidget? appBar;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      onVerticalDragDown: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        appBar: appBar,
        body: body,
      ),
    );
  }
}
