import 'dart:convert';

import 'package:buff_lisa/app/admin/admin_api_adapter.dart';
import 'package:buff_lisa/features/admin_audience/domain/admin_audience_models.dart';
import 'package:buff_lisa/features/admin_users/domain/admin_user_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test(
    'generated adapter maps a queued audience preview without invented data',
    () async {
      final client = _RecordingClient([
        _response(200, {
          'csrfToken': 'csrf-preview',
          'expiresAt': '2026-01-01T01:00:00Z',
          'sessionState': 'pre_authentication',
        }),
        _response(202, {
          'jobId': 'preview-job-1',
          'snapshotId': 'snapshot-pending',
          'status': 'pending',
        }),
      ]);
      final adapter = AdminApiAdapter(
        basePath: 'https://admin.example',
        client: client,
      );

      await adapter.bootstrap();
      final preview = await adapter.preview(
        AdminAudiencePreviewRequest(
          audience: AdminAudienceSelection.selected(const {'account-1'}),
          action: const AdminAudienceAction(
            kind: AdminAudienceActionKind.loginLink,
          ),
        ),
      );

      expect(preview.status, AdminAudiencePreviewStatus.pending);
      expect(preview.jobId, 'preview-job-1');
      expect(preview.eligibleRecipientCount, isNull);
      expect(preview.payloadHash, isNull);
      expect(preview.canConfirm(), isFalse);
      expect(client.requests[1].url.path, '/api/v3/admin/audiences/preview');
      expect(client.requests[1].headers['x-csrf-token'], 'csrf-preview');
    },
  );

  test(
    'generated adapter rotates CSRF and maps session data without JWTs',
    () async {
      final client = _RecordingClient([
        _response(200, {
          'csrfToken': 'csrf-bootstrap',
          'expiresAt': '2026-01-01T01:00:00Z',
          'sessionState': 'pre_authentication',
        }),
        _response(200, {
          'challengeId': 'challenge-1',
          'csrfToken': 'csrf-challenge',
          'expiresAt': '2026-01-01T01:00:00Z',
          'sessionState': 'mfa_required',
        }),
        _response(200, {
          'authenticatedAt': '2026-01-01T00:00:00Z',
          'capabilities': ['users.read'],
          'csrfToken': 'csrf-session',
          'idleExpiresAt': '2026-01-01T01:00:00Z',
          'lastActivityAt': '2026-01-01T00:00:00Z',
          'permissions': ['users.read'],
          'recentMfaAt': '2026-01-01T00:00:00Z',
          'sessionId': 'session-1',
          'sessionState': 'authenticated',
          'userId': 'user-1',
          'username': 'operator',
        }),
      ]);
      final adapter = AdminApiAdapter(
        basePath: 'https://admin.example',
        client: client,
      );

      await adapter.bootstrap();
      final challenge = await adapter.beginLogin(
        username: 'operator',
        password: 'password-only-in-memory',
      );
      final session = await adapter.completeMfa(
        challengeId: challenge.challengeId,
        code: '654321',
      );

      expect(challenge.challengeId, 'challenge-1');
      expect(session.username, 'operator');
      expect(session.capabilities, {'users.read'});
      expect(client.requests[1].headers['x-csrf-token'], 'csrf-bootstrap');
      expect(client.requests[2].headers['x-csrf-token'], 'csrf-challenge');
      expect(client.requests[1].body, contains('password-only-in-memory'));
    },
  );

  test(
    'generated adapter maps bounded users and translates status failures',
    () async {
      final client = _RecordingClient([
        _response(200, {
          'items': [
            {
              'authGeneration': 2,
              'createdAt': '2026-01-01T00:00:00Z',
              'email': 'alice@example.com',
              'emailVerified': true,
              'eligibilityReasons': [],
              'id': 'user-1',
              'isAdmin': false,
              'passwordDisabled': false,
              'passwordResetRequired': false,
              'securityState': 'normal',
              'username': 'alice',
            },
          ],
          'nextCursor': 'next-page',
        }),
        _response(401, {'error': 'body is deliberately discarded'}),
      ]);
      final adapter = AdminApiAdapter(
        basePath: 'https://admin.example',
        client: client,
      );

      final page = await adapter.listUsers(
        const AdminUserQuery(search: 'alice'),
      );
      expect(page.items.single.username, 'alice');
      expect(page.nextCursor, 'next-page');

      await expectLater(
        adapter.listUsers(const AdminUserQuery(search: 'again')),
        throwsA(
          isA<AdminUsersTransportException>().having(
            (error) => error.statusCode,
            'status code',
            401,
          ),
        ),
      );
    },
  );

  test(
    'logout clears the old CSRF and reboots pre-auth before the next login',
    () async {
      final client = _RecordingClient([
        _response(200, {
          'csrfToken': 'csrf-before-logout',
          'expiresAt': '2026-01-01T01:00:00Z',
          'sessionState': 'pre_authentication',
        }),
        http.Response('', 204),
        _response(200, {
          'csrfToken': 'csrf-after-logout',
          'expiresAt': '2026-01-01T01:00:00Z',
          'sessionState': 'pre_authentication',
        }),
        _response(202, {
          'challengeId': 'challenge-after-logout',
          'csrfToken': 'csrf-after-login',
          'expiresAt': '2026-01-01T01:00:00Z',
          'sessionState': 'mfa_required',
        }),
      ]);
      final adapter = AdminApiAdapter(
        basePath: 'https://admin.example',
        client: client,
      );

      await adapter.bootstrap();
      await adapter.logout();
      final challenge = await adapter.beginLogin(
        username: 'operator',
        password: 'password',
      );

      expect(challenge.challengeId, 'challenge-after-logout');
      expect(client.requests.map((request) => request.method), [
        'POST',
        'POST',
        'POST',
        'POST',
      ]);
      expect(client.requests[1].url.path, '/api/v3/admin/session/logout');
      expect(client.requests[1].headers['x-csrf-token'], 'csrf-before-logout');
      expect(client.requests[2].url.path, '/api/v3/admin/session/bootstrap');
      expect(client.requests[3].headers['x-csrf-token'], 'csrf-after-logout');
    },
  );

  test(
    'an unauthorized users response clears CSRF so the next login bootstraps',
    () async {
      final client = _RecordingClient([
        _response(200, {
          'csrfToken': 'csrf-before-expiry',
          'expiresAt': '2026-01-01T01:00:00Z',
          'sessionState': 'pre_authentication',
        }),
        _response(401, {'error': 'expired'}),
        _response(200, {
          'csrfToken': 'csrf-after-expiry',
          'expiresAt': '2026-01-01T01:00:00Z',
          'sessionState': 'pre_authentication',
        }),
        _response(202, {
          'challengeId': 'challenge-after-expiry',
          'csrfToken': 'csrf-after-login',
          'expiresAt': '2026-01-01T01:00:00Z',
          'sessionState': 'mfa_required',
        }),
      ]);
      final adapter = AdminApiAdapter(
        basePath: 'https://admin.example',
        client: client,
      );

      await adapter.bootstrap();
      await expectLater(
        adapter.listUsers(const AdminUserQuery()),
        throwsA(
          isA<AdminUsersTransportException>().having(
            (error) => error.statusCode,
            'status code',
            401,
          ),
        ),
      );
      final challenge = await adapter.beginLogin(
        username: 'operator',
        password: 'password',
      );

      expect(challenge.challengeId, 'challenge-after-expiry');
      expect(client.requests[2].url.path, '/api/v3/admin/session/bootstrap');
      expect(client.requests[3].headers['x-csrf-token'], 'csrf-after-expiry');
    },
  );
}

http.Response _response(int statusCode, Map<String, Object?> body) =>
    http.Response(
      jsonEncode(body),
      statusCode,
      headers: {'content-type': 'application/json'},
    );

final class _RecordingClient extends http.BaseClient {
  _RecordingClient(this.responses);

  final List<http.Response> responses;
  final requests = <_RecordedRequest>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final bytes = await request.finalize().toBytes();
    requests.add(
      _RecordedRequest(
        method: request.method,
        url: request.url,
        headers: request.headers,
        body: utf8.decode(bytes),
      ),
    );
    final response = responses.removeAt(0);
    return http.StreamedResponse(
      Stream<List<int>>.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      request: request,
      reasonPhrase: response.reasonPhrase,
    );
  }
}

final class _RecordedRequest {
  const _RecordedRequest({
    required this.method,
    required this.url,
    required this.headers,
    required this.body,
  });

  final String method;
  final Uri url;
  final Map<String, String> headers;
  final String body;
}
