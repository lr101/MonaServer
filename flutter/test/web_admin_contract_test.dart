import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:openapi/api.dart';

void main() {
  test('selected audience requires at least one canonical id', () {
    expect(
      () =>
          AdminAudience.fromJson({'kind': 'selected', 'resource': 'accounts'}),
      throwsA(isA<FormatException>()),
    );
  });

  test('filter audience requires its filter object', () {
    expect(
      () => AdminAudience.fromJson({'kind': 'filter', 'resource': 'accounts'}),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => AdminAudience.fromJson({
        'kind': 'filter',
        'resource': 'accounts',
        'ids': <String>[],
        'filter': {'resource': 'accounts'},
      }),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => AdminAudience.fromJson({
        'kind': 'filter',
        'resource': 'accounts',
        'filter': {'resource': 'accounts', 'unexpected': null},
      }),
      throwsA(isA<FormatException>()),
    );
    for (final inactiveValue in [false, null]) {
      expect(
        () => AdminAudience.fromJson({
          'kind': 'filter',
          'resource': 'reports',
          'filter': {'resource': 'reports', 'includeAdmins': inactiveValue},
        }),
        throwsA(isA<FormatException>()),
      );
    }
  });

  test('all audience has no selected or filter branch fields', () {
    final audience = AdminAudience.fromJson({
      'kind': 'all',
      'resource': 'reports',
    });
    expect(audience?.kind.value, 'all');

    expect(
      () => AdminAudience.fromJson({
        'kind': 'all',
        'resource': 'accounts',
        'ids': ['046b6c7f-0b8a-43b9-b35d-6489e6daee91'],
      }),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => AdminAudience.fromJson({
        'kind': 'all',
        'resource': 'accounts',
        'filter': null,
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('filter audience keeps account and report criteria resource-safe', () {
    final account = AdminAudience.fromJson({
      'kind': 'filter',
      'resource': 'accounts',
      'filter': {
        'resource': 'accounts',
        'includeAdmins': false,
        'securityStatuses': ['normal'],
        'verifiedEmail': true,
      },
    });
    final report = AdminAudience.fromJson({
      'kind': 'filter',
      'resource': 'reports',
      'filter': {
        'resource': 'reports',
        'statuses': ['open'],
        'types': ['abuse'],
        'createdAfter': '2026-01-01T00:00:00Z',
        'createdBefore': '2026-09-01T00:00:00Z',
        'assigneeUserId': '246b6c7f-0b8a-43b9-b35d-6489e6daee93',
      },
    });

    expect(account?.filter?.resource.value, 'accounts');
    expect(account?.filter?.verifiedEmail, isTrue);
    expect(report?.filter?.resource.value, 'reports');
    expect(report?.filter?.statuses?.single.value, 'open');
    expect(report?.filter?.types, ['abuse']);
    expect(
      report?.filter?.assigneeUserId,
      '246b6c7f-0b8a-43b9-b35d-6489e6daee93',
    );

    expect(
      () => AdminAudience.fromJson({
        'kind': 'filter',
        'resource': 'reports',
        'filter': {'resource': 'accounts', 'verifiedEmail': true},
      }),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => AdminAudience.fromJson({
        'kind': 'filter',
        'resource': 'accounts',
        'filter': {
          'resource': 'accounts',
          'statuses': ['open'],
        },
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('each action branch requires and retains its canonical fields', () {
    const validActions = <String, Map<String, dynamic>>{
      'email': {'body': 'Body', 'subject': 'Subject'},
      'login_link': {},
      'push': {'body': 'Body', 'title': 'Title'},
      'revoke_sessions': {'reason': 'Rotate sessions'},
      'mark_compromised': {'reason': 'Compromised account'},
      'recovery_resend': {'reason': 'Resend recovery'},
      'report_resolve': {},
      'report_dismiss': {},
    };
    for (final entry in validActions.entries) {
      final action = AdminAction.fromJson({
        'action': entry.key,
        ...entry.value,
      });
      expect(action?.action.value, entry.key);
    }

    const requiredFields = <String, String>{
      'email': 'body',
      'push': 'title',
      'revoke_sessions': 'reason',
      'mark_compromised': 'reason',
      'recovery_resend': 'reason',
    };
    for (final entry in requiredFields.entries) {
      expect(
        () => AdminAction.fromJson({
          'action': entry.key,
          if (entry.key == 'email') 'subject': 'Subject',
          if (entry.key == 'push') 'body': 'Body',
        }),
        throwsA(isA<FormatException>()),
      );
    }
    expect(
      () => AdminAction.fromJson({
        'action': 'email',
        'body': 'Body',
        'subject': 'Subject',
        'title': '',
      }),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => AdminAction.fromJson({
        'action': 'push',
        'body': 'Body',
        'title': 'Title',
        'reason': null,
      }),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => AdminAction.fromJson({
        'action': 'email',
        'body': 'Body',
        'subject': 'Subject',
        'unexpected': null,
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('valid selected and action fixtures retain their branch fields', () {
    final audience = AdminAudience.fromJson({
      'kind': 'selected',
      'ids': ['046b6c7f-0b8a-43b9-b35d-6489e6daee91'],
      'resource': 'accounts',
    });
    final action = AdminAction.fromJson({
      'action': 'push',
      'body': 'Security update',
      'title': 'Stick-It',
    });

    expect(audience?.ids, ['046b6c7f-0b8a-43b9-b35d-6489e6daee91']);
    expect(action?.body, 'Security update');
    expect(action?.title, 'Stick-It');
  });

  test('constructors cannot serialize incomplete canonical branches', () {
    expect(
      () => AdminAudience(
        kind: AudienceKind.selected,
        resource: AudienceResourceKind.accounts,
      ).toJson(),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => AdminAction(action: AdminActionKind.email).toJson(),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => AdminAudienceFilter(
        resource: AudienceResourceKind.accounts,
        statuses: [AdminReportStatus.open],
      ).toJson(),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => AdminAudience(
        kind: AudienceKind.filter,
        ids: ['046b6c7f-0b8a-43b9-b35d-6489e6daee91'],
        resource: AudienceResourceKind.accounts,
        filter: AdminAudienceFilter(resource: AudienceResourceKind.accounts),
      ).toJson(),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => AdminAction(
        action: AdminActionKind.push,
        body: 'Body',
        title: 'Title',
        subject: '',
      ).toJson(),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => AdminAudienceFilter(
        resource: AudienceResourceKind.reports,
        includeAdmins: false,
      ).toJson(),
      throwsA(isA<FormatException>()),
    );
    expect(
      AdminAudienceFilter(
        resource: AudienceResourceKind.reports,
        includeAdmins: null,
      ).toJson(),
      {'resource': AudienceResourceKind.reports},
    );
  });

  test(
    'legacy v2 login still decodes the token pair and preserves status errors',
    () async {
      final response = http.Response(
        jsonEncode({
          'refreshToken': 'legacy-refresh',
          'accessToken': 'legacy-access',
          'userId': '046b6c7f-0b8a-43b9-b35d-6489e6daee91',
        }),
        200,
      );
      final api = AuthApi(_StubApiClient(response));
      final tokens = await api.userLogin(
        UserLoginRequest(username: 'alice', password: 'password'),
      );

      expect(tokens?.accessToken, 'legacy-access');
      expect(tokens?.refreshToken, 'legacy-refresh');
      expect(tokens?.userId, '046b6c7f-0b8a-43b9-b35d-6489e6daee91');

      final rejected = AuthApi(
        _StubApiClient(http.Response('{"code":"invalid_credentials"}', 401)),
      );
      await expectLater(
        rejected.userLogin(
          UserLoginRequest(username: 'alice', password: 'wrong'),
        ),
        throwsA(
          isA<ApiException>().having((error) => error.code, 'status', 401),
        ),
      );
    },
  );

  test('preview convenience API decodes a queued 202 response', () async {
    final api = AdminAudiencesApi(
      _StubApiClient(
        http.Response(
          jsonEncode({
            'jobId': '146b6c7f-0b8a-43b9-b35d-6489e6daee92',
            'snapshotId': '046b6c7f-0b8a-43b9-b35d-6489e6daee91',
            'status': 'pending',
          }),
          202,
        ),
      ),
    );

    final result = await api.previewAdminAudience(
      'csrf-token-123456',
      AdminAudiencePreviewRequestDto(
        action: AdminAction(
          action: AdminActionKind.push,
          body: 'Security update',
          title: 'Stick-It',
        ),
        audience: AdminAudience(
          kind: AudienceKind.selected,
          ids: ['046b6c7f-0b8a-43b9-b35d-6489e6daee91'],
          resource: AudienceResourceKind.accounts,
        ),
      ),
    );

    expect(result?.toJson()['jobId'], '146b6c7f-0b8a-43b9-b35d-6489e6daee92');
    expect(
      result?.toJson()['snapshotId'],
      '046b6c7f-0b8a-43b9-b35d-6489e6daee91',
    );
    expect(result?.toJson()['status'].toString(), 'pending');
    expect(result?.status.value, 'pending');
  });

  test('preview convenience API decodes a ready 200 response', () async {
    final api = AdminAudiencesApi(
      _StubApiClient(
        http.Response(
          jsonEncode({
            'action': {
              'action': 'push',
              'body': 'Security update',
              'title': 'Stick-It',
            },
            'actorUserId': '246b6c7f-0b8a-43b9-b35d-6489e6daee93',
            'counts': {
              'accountAudienceCount': 1,
              'deviceDeliveryCount': 0,
              'excludedCount': 0,
              'eligibleRecipientCount': 1,
            },
            'expiresAt': '2026-09-15T04:15:00Z',
            'exclusions': [],
            'payloadHash': 'sha256-payload-hash',
            'resource': 'accounts',
            'snapshotId': '046b6c7f-0b8a-43b9-b35d-6489e6daee91',
            'status': 'ready',
          }),
          200,
        ),
      ),
    );

    final result = await api.previewAdminAudience(
      'csrf-token-123456',
      AdminAudiencePreviewRequestDto(
        action: AdminAction(
          action: AdminActionKind.push,
          body: 'Security update',
          title: 'Stick-It',
        ),
        audience: AdminAudience(
          kind: AudienceKind.selected,
          ids: ['046b6c7f-0b8a-43b9-b35d-6489e6daee91'],
          resource: AudienceResourceKind.accounts,
        ),
      ),
    );

    expect(
      result?.toJson()['snapshotId'],
      '046b6c7f-0b8a-43b9-b35d-6489e6daee91',
    );
    expect(result?.toJson()['status'].toString(), 'ready');
    expect(result?.status.value, 'ready');
    expect(result?.action?.body, 'Security update');
  });
}

class _StubApiClient extends ApiClient {
  _StubApiClient(this.response);

  final http.Response response;

  @override
  Future<http.Response> invokeAPI(
    String path,
    String method,
    List<QueryParam> queryParams,
    Object? body,
    Map<String, String> headerParams,
    Map<String, String> formParams,
    String? contentType,
  ) async => response;
}
