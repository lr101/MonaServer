import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/architecture_rules.dart';

void main() {
  test('new layers respect dependency boundaries', () {
    final violations = <String>[];
    for (final file in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      // Existing feature folders predate the target architecture. Register each
      // complete feature migration here; do not silently grandfather new files.
      const migratedFeatures = <String>[
        'admin_session',
        'admin_users',
        'admin_audience',
      ];
      final guarded =
          file.path == 'lib/main.dart' ||
          file.path == 'lib/main_admin.dart' ||
          file.path.startsWith('lib/app/') ||
          file.path.startsWith('lib/core/') ||
          file.path.startsWith('lib/shared/') ||
          migratedFeatures.any(
            (name) => file.path.startsWith('lib/features/$name/'),
          );
      if (!guarded) continue;
      violations.addAll(
        architectureViolations(file.path, file.readAsStringSync()),
      );
    }
    expect(violations, isEmpty);
  });

  test('guard rejects domain dependencies through relative, package and conditional imports', () {
    for (final source in [
      "import 'package:flutter/widgets.dart';",
      "export '../data/source.dart';",
      "import 'model.dart' if (dart.library.io) 'dart:io';",
      "import 'package:buff_lisa/data/entity/group.dart';",
      "import 'dart:ui';",
    ]) {
      expect(
        architectureViolations('lib/features/auth/domain/session.dart', source),
        isNotEmpty,
      );
    }
  });

  test('guard allows pure models and core foundations', () {
    expect(
      architectureViolations('lib/features/auth/domain/session.dart', '''
import 'dart:async';
import 'model.dart';
import 'package:buff_lisa/core/failure.dart';
// import 'package:flutter/widgets.dart';
'''),
      isEmpty,
    );
  });

  test('guard prevents presentation bypassing use cases', () {
    for (final target in [
      '../data/source.dart',
      '../domain/session_repository.dart',
      'package:buff_lisa/data/service/global_data_service.dart',
      'package:buff_lisa/features/auth/domain/../data/source.dart',
      'package:openapi/api.dart',
      'package:drift/drift.dart',
    ]) {
      expect(
        architectureViolations(
          'lib/features/auth/presentation/login.dart',
          "import '$target';",
        ),
        isNotEmpty,
      );
    }
    expect(
      architectureViolations(
        'lib/features/auth/presentation/login.dart',
        "import '../domain/sign_in.dart';",
      ),
      isEmpty,
    );
  });

  test('guard prevents data, core and shared UI from depending on presentation or app wiring', () {
    for (final file in [
      'lib/core/failure.dart',
      'lib/shared/button.dart',
      'lib/features/auth/data/source.dart',
    ]) {
      expect(
        architectureViolations(
          file,
          "import 'package:buff_lisa/app/app.dart';",
        ),
        isNotEmpty,
      );
      expect(
        architectureViolations(
          file,
          "export 'package:buff_lisa/features/auth/presentation/login.dart';",
        ),
        isNotEmpty,
      );
    }
  });

  test('entry point only launches the composition root', () {
    expect(
      architectureViolations(
        'lib/main.dart',
        "import 'package:buff_lisa/data/database/database.dart';",
      ),
      isNotEmpty,
    );
    expect(
      architectureViolations(
        'lib/main.dart',
        "import 'package:buff_lisa/app/bootstrap.dart';",
      ),
      isEmpty,
    );
  });

  test(
    'rendering and configuration cannot initialize legacy infrastructure',
    () {
      expect(
        architectureViolations(
          'lib/app/app.dart',
          "import 'package:buff_lisa/data/database/database.dart';",
        ),
        isNotEmpty,
      );
      expect(
        architectureViolations(
          'lib/app/app_configuration.dart',
          "import 'package:flutter/widgets.dart';",
        ),
        isNotEmpty,
      );
      expect(
        architectureViolations(
          'lib/app/production_bootstrap.dart',
          "import 'package:buff_lisa/data/database/database.dart';",
        ),
        isEmpty,
      );
    },
  );

  test(
    'admin entry point only launches the independent admin composition root',
    () {
      expect(
        architectureViolations(
          'lib/main_admin.dart',
          "import 'package:buff_lisa/app/admin/admin_bootstrap.dart';",
        ),
        isEmpty,
      );
      expect(
        architectureViolations(
          'lib/main_admin.dart',
          "import 'package:buff_lisa/app/bootstrap.dart';",
        ),
        isNotEmpty,
      );
      expect(
        architectureViolations(
          'lib/main_admin.dart',
          "import 'package:buff_lisa/data/database/database.dart';",
        ),
        isNotEmpty,
      );
    },
  );

  test('admin graph cannot import consumer session, storage, sync, camera, or Firebase', () {
    const forbidden = [
      "import 'package:buff_lisa/app/production_bootstrap.dart';",
      "import 'package:buff_lisa/app/app.dart';",
      "import 'package:buff_lisa/data/service/global_data_service.dart';",
      "import 'package:buff_lisa/data/database/database.dart';",
      "import 'package:buff_lisa/core/session/session_status.dart';",
      "import 'package:buff_lisa/core/sync/sync_coordinator.dart';",
      "import 'package:camera/camera.dart';",
      "import 'package:firebase_core/firebase_core.dart';",
      "import 'package:firebase_messaging/firebase_messaging.dart';",
    ];
    for (final source in forbidden) {
      expect(
        architectureViolations('lib/app/admin/admin_app.dart', source),
        isNotEmpty,
        reason: source,
      );
    }
  });
}
