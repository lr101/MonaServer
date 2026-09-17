import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

const _pureDart = {
  'dart:async',
  'dart:collection',
  'dart:convert',
  'dart:core',
  'dart:math',
  'dart:typed_data',
};

/// Checks only migrated layers. Legacy code remains migration debt.
/// Parse directives so comments cannot trigger failures and conditional imports
/// and exports cannot hide forbidden dependencies.
List<String> architectureViolations(String file, String source) {
  final path = Uri(path: file).normalizePath().path;
  final unit = parseString(content: source, throwIfDiagnostics: false).unit;
  final violations = <String>[];
  for (final directive in unit.directives.whereType<UriBasedDirective>()) {
    final targets = [
      directive.uri.stringValue,
      if (directive is NamespaceDirective)
        ...directive.configurations.map((config) => config.uri.stringValue),
    ];
    for (final target in targets.whereType<String>()) {
      final resolved = target.startsWith('package:buff_lisa/')
          ? Uri(path: 'lib/${target.substring('package:buff_lisa/'.length)}')
                .normalizePath()
                .path
          : Uri.parse(target).hasScheme
          ? target
          : Uri(path: path).resolve(target).normalizePath().path;
      if (_isAdminFile(path) && !_adminTargetAllowed(resolved)) {
        violations.add('$path -> $resolved');
      }
      if (!_allowed(path, resolved)) violations.add('$path -> $resolved');
    }
  }
  return violations;
}

bool _allowed(String file, String target) {
  if (file == 'lib/main.dart') {
    return target == 'package:flutter/widgets.dart' ||
        target == 'lib/app/bootstrap.dart' ||
        target == 'lib/app/production_bootstrap.dart';
  }
  if (file == 'lib/main_admin.dart') {
    return target == 'package:flutter/widgets.dart' ||
        target == 'lib/app/admin/admin_bootstrap.dart';
  }
  final pure = _pureDart.contains(target);
  final core = target.startsWith('lib/core/');
  final shared = target.startsWith('lib/shared/');
  final feature = RegExp('^lib/features/([^/]+)/(domain|data|presentation)/')
      .firstMatch(file);
  if (file == 'lib/app/app_configuration.dart') return pure;
  if (file.startsWith('lib/app/admin/')) {
    return pure ||
        target.startsWith('package:flutter/') ||
        target.startsWith('package:http/') ||
        target.startsWith('package:openapi/') ||
        target.startsWith('lib/app/admin/') ||
        target.startsWith('lib/features/admin_');
  }
  if (file == 'lib/app/app.dart' || file == 'lib/app/bootstrap.dart') {
    return pure ||
        target.startsWith('package:flutter/') ||
        target.startsWith('package:flutter_riverpod/') ||
        target.startsWith('lib/util/routing/') ||
        target.startsWith('lib/util/theme/') ||
        target == 'lib/app/app_configuration.dart' ||
        target == 'lib/app/routing/app_router.dart' ||
        target == 'lib/app/lifecycle/sync_lifecycle.dart';
  }
  if (file.startsWith('lib/core/')) return pure || core;
  if (file.startsWith('lib/shared/')) {
    return pure || shared || target.startsWith('package:flutter/');
  }
  if (feature == null) return true;
  final featureName = feature.group(1)!;
  final root = 'lib/features/$featureName/';
  if (featureName.startsWith('admin_')) {
    switch (feature.group(2)) {
      case 'domain':
        return pure || core || target.startsWith('${root}domain/');
      case 'presentation':
        return pure ||
            core ||
            shared ||
            target.startsWith('${root}presentation/') ||
            target.startsWith('${root}domain/') ||
            target.startsWith('lib/features/admin_audience/') ||
            target.startsWith('package:flutter/');
      case 'data':
        return pure ||
            core ||
            target.startsWith('${root}domain/') ||
            target.startsWith('${root}data/') ||
            (target.startsWith('package:') &&
                !target.startsWith('package:flutter/'));
      default:
        return true;
    }
  }
  switch (feature.group(2)) {
    case 'domain':
      return pure || core || target.startsWith('${root}domain/');
    case 'presentation':
      return pure ||
          core ||
          shared ||
          target.startsWith('${root}presentation/') ||
          (target.startsWith('${root}domain/') &&
              !target.endsWith('_repository.dart')) ||
          target.startsWith('package:flutter/') ||
          target.startsWith('package:flutter_riverpod/') ||
          target.startsWith('package:riverpod_annotation/');
    case 'data':
      return pure ||
          core ||
          target.startsWith('${root}domain/') ||
          target.startsWith('${root}data/') ||
          (target.startsWith('package:') &&
              (!target.startsWith('package:flutter/') ||
                  target == 'package:flutter/foundation.dart'));
    default:
      return true;
  }
}

bool _isAdminFile(String file) =>
    file == 'lib/main_admin.dart' ||
    file.startsWith('lib/app/admin/') ||
    file.startsWith('lib/features/admin_session/') ||
    file.startsWith('lib/features/admin_users/') ||
    file.startsWith('lib/features/admin_audience/');

bool _adminTargetAllowed(String target) {
  if (target.startsWith('package:buff_lisa/')) {
    // Package imports have already been resolved to lib/ paths above.
    return _adminTargetAllowed(
      Uri(path: 'lib/${target.substring('package:buff_lisa/'.length)}')
          .normalizePath()
          .path,
    );
  }
  if (target.startsWith('lib/app/bootstrap.dart') ||
      target.startsWith('lib/app/production_bootstrap.dart') ||
      target.startsWith('lib/app/app.dart') ||
      target.startsWith('lib/app/routing/') ||
      target.startsWith('lib/app/lifecycle/') ||
      target.startsWith('lib/data/') ||
      target.startsWith('lib/core/session/') ||
      target.startsWith('lib/core/sync/') ||
      target.startsWith('lib/features/camera/') ||
      target.startsWith('lib/features/auth/') ||
      target.startsWith('lib/features/email_login/') ||
      target == 'lib/firebase_options.dart' ||
      target == 'lib/main.dart') {
    return false;
  }
  if (target == 'dart:io' ||
      target.startsWith('package:camera/') ||
      target.startsWith('package:firebase_') ||
      target.startsWith('package:flutter_secure_storage/') ||
      target.startsWith('package:drift/')) {
    return false;
  }
  return true;
}
