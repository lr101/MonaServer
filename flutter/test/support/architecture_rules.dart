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
  final pure = _pureDart.contains(target);
  final core = target.startsWith('lib/core/');
  final shared = target.startsWith('lib/shared/');
  final feature = RegExp('^lib/features/([^/]+)/(domain|data|presentation)/')
      .firstMatch(file);
  if (file == 'lib/app/app_configuration.dart') return pure;
  if (file == 'lib/app/app.dart' || file == 'lib/app/bootstrap.dart') {
    return pure ||
        target.startsWith('package:flutter/') ||
        target.startsWith('package:flutter_riverpod/') ||
        target.startsWith('lib/util/routing/') ||
        target.startsWith('lib/util/theme/') ||
        target == 'lib/app/app_configuration.dart' ||
        target == 'lib/app/routing/app_router.dart' ||
        target == 'lib/app/lifecycle/sync_lifecycle.dart' ||
        target == 'lib/app/lifecycle/app_link_lifecycle.dart' ||
        target == 'lib/app/play_store_update_guard.dart';
  }
  if (file.startsWith('lib/core/')) return pure || core;
  if (file.startsWith('lib/shared/')) {
    return pure || shared || target.startsWith('package:flutter/');
  }
  if (feature == null) return true;
  final root = 'lib/features/${feature.group(1)}/';
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
