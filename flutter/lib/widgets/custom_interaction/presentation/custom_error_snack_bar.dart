import 'package:buff_lisa/features/navigation/data/navigation_provider.dart';
import 'package:floating_snackbar/floating_snackbar.dart';
import 'package:flutter/material.dart';

// ignore: avoid_classes_with_only_static_members
class CustomErrorSnackBar {
  static void message(
      {required String message,
      CustomErrorSnackBarType type = CustomErrorSnackBarType.info,}) {
    floatingSnackBar(
      message: message,
      context: navigatorKey.currentContext!,
      backgroundColor: type.color,
    );
  }

  static void loadingMessage({required String message, CustomErrorSnackBarType type = CustomErrorSnackBarType.info,}) {
    final snack = SnackBar(
    behavior: SnackBarBehavior.floating, // Make the SnackBar floating
    margin: const EdgeInsets.all(20), // Set margin around the SnackBar
    shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10)), // Rounded corners for the SnackBar
    content: Row(
      children: [
        const SizedBox.square(dimension: 10, child: CircularProgressIndicator(),),
        const SizedBox(width: 10,),
        Text(message,style: const TextStyle(color: Colors.white),
    ),
    ],), 
    backgroundColor: type.color
  );

  // Hide any currently displayed SnackBar
  ScaffoldMessenger.of(navigatorKey.currentContext!).hideCurrentSnackBar();

  // Show the created SnackBar
  ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(snack);
  }
}

enum CustomErrorSnackBarType {
  success, error, warning, info;

  Color get color {
    switch (this) {
      case CustomErrorSnackBarType.success:
        return Colors.green;
      case CustomErrorSnackBarType.error:
        return Colors.red;
      case CustomErrorSnackBarType.warning:
        return Colors.orange;
      case CustomErrorSnackBarType.info:
        return Colors.blue;
    }
  }
}
