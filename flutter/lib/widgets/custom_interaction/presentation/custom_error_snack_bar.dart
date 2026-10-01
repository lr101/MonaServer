import 'package:buff_lisa/features/navigation/data/navigation_provider.dart';
import 'package:flutter/material.dart';

// ignore: avoid_classes_with_only_static_members
class CustomErrorSnackBar {
  static void message({
    required String message,
    CustomErrorSnackBarType type = CustomErrorSnackBarType.info,
  }) {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    final theme = Theme.of(context);
    final isError = type == CustomErrorSnackBarType.error;
    final foreground = isError
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onSurface;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          showCloseIcon: true,
          closeIconColor: foreground,
          backgroundColor: isError
              ? theme.colorScheme.errorContainer
              : theme.colorScheme.surfaceContainerHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Row(
            children: [
              Icon(switch (type) {
                CustomErrorSnackBarType.error => Icons.error_outline,
                CustomErrorSnackBarType.warning => Icons.warning_amber_rounded,
                CustomErrorSnackBarType.success => Icons.check_circle_outline,
                CustomErrorSnackBarType.info => Icons.info_outline,
              }, color: foreground),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }
}

enum CustomErrorSnackBarType { success, error, warning, info }
