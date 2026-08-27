import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CustomDialog extends StatelessWidget {
  const CustomDialog({
    super.key,
    this.text1,
    required this.text2,
    required this.onPressed,
    this.child,
    required this.title,
  });

  final String? text1;
  final String text2;
  final String title;
  final VoidCallback onPressed;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    return dialog(
      platform,
      Text(title),
      child == null
          ? null
          : Material(
              color: Colors.transparent,
              child: child,
            ),
      <Widget>[
        TextButton(
          onPressed: () => context.pop(),
          child: text1 != null ? Text(text1!) : const SizedBox.shrink(),
        ),
        TextButton(
          onPressed: () {
            context.pop();
            onPressed();
          },
          child: Text(text2),
        ),
      ],
    );
  }

  Widget dialog(TargetPlatform platform, Widget title, Widget? content, List<Widget> actions) {
    if (platform == TargetPlatform.iOS) {
      return CupertinoAlertDialog(
        title: title,
        content: content,
        actions: actions,
      );
    } else {
      return AlertDialog(
        title: title,
        content: content,
        actions: actions,
      );
    }
  }

  static Future<void> show(BuildContext context, {String? cancelText, required String acceptText,
      required String title, required VoidCallback onPressed, Widget? child,}) async {
    await showDialog(
        context: context,
        builder: (context) => CustomDialog(
            title: title,
            text1: cancelText,
            text2: acceptText,
            onPressed: onPressed,
            child: child,),);
  }
}
