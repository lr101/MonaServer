import 'dart:async';

import 'package:buff_lisa/features/admin_audience/domain/admin_audience_models.dart';
import 'package:buff_lisa/features/admin_security/domain/admin_security_models.dart';
import 'package:buff_lisa/features/admin_security/domain/admin_security_ports.dart';
import 'package:buff_lisa/features/admin_security/presentation/admin_security_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'failed recent MFA prevents a security job from being submitted',
    () async {
      final repository = _SecurityRepository();
      final controller = AdminSecurityController(
        repository,
        hasRecentMfa: () => false,
      );

      await controller.submit(
        audience: AdminAudienceSelection.selected(const {'account-1'}),
        request: const AdminSecurityRequest.compromise(
          reason: 'Credential theft',
        ),
      );

      expect(repository.requests, isEmpty);
      expect(controller.state.phase, AdminSecurityPhase.mfaRequired);
    },
  );

  test(
    'requires a separate acknowledgement before including administrators',
    () async {
      final repository = _SecurityRepository();
      final controller = AdminSecurityController(
        repository,
        hasRecentMfa: () => true,
      );
      const request = AdminSecurityRequest.revoke(
        reason: 'Incident response',
        includeAdministrators: true,
      );

      await controller.submit(
        audience: AdminAudienceSelection.all(),
        request: request,
      );
      expect(repository.requests, isEmpty);

      await controller.submit(
        audience: AdminAudienceSelection.all(),
        request: request,
        administratorInclusionAcknowledged: true,
      );
      expect(
        repository.requests.single.audience.kind,
        AdminAudienceSelectionKind.all,
      );
      expect(repository.requests.single.idempotencyKey, isNotEmpty);
    },
  );

  test(
    'compromise exposes manual recovery without an ordinary sign-in option',
    () async {
      final controller = AdminSecurityController(
        _SecurityRepository(
          result: const AdminSecurityResult(
            jobId: 'security-job',
            outcome: AdminSecurityOutcome.securedManualRecoveryRequired,
          ),
        ),
        hasRecentMfa: () => true,
      );

      await controller.submit(
        audience: AdminAudienceSelection.selected(const {'account-1'}),
        request: const AdminSecurityRequest.compromise(
          reason: 'Credential theft',
        ),
      );

      expect(controller.state.result?.manualRecoveryRequired, isTrue);
      expect(controller.state.result?.ordinarySignInAvailable, isFalse);
    },
  );

  test(
    'session expiry ignores a late security result and prevents new submits',
    () async {
      final pending = Completer<AdminSecurityResult>();
      final repository = _SecurityRepository(resultFuture: pending.future);
      final controller = AdminSecurityController(
        repository,
        hasRecentMfa: () => true,
      );
      final request = controller.submit(
        audience: AdminAudienceSelection.selected(const {'account-1'}),
        request: const AdminSecurityRequest.recoveryResend(
          reason: 'Requested by user',
        ),
      );

      controller.expireSession();
      pending.complete(
        const AdminSecurityResult(
          jobId: 'security-job',
          outcome: AdminSecurityOutcome.queued,
        ),
      );
      await request;
      await controller.submit(
        audience: AdminAudienceSelection.selected(const {'account-2'}),
        request: const AdminSecurityRequest.revoke(reason: 'Incident response'),
      );

      expect(controller.state.result, isNull);
      expect(repository.requests, hasLength(1));
    },
  );
}

final class _SecurityRepository implements AdminSecurityRepository {
  _SecurityRepository({
    this.result = const AdminSecurityResult(
      jobId: 'security-job',
      outcome: AdminSecurityOutcome.queued,
    ),
    this._resultFuture,
  });

  final List<AdminSecurityActionRequest> requests = [];
  final AdminSecurityResult result;
  final Future<AdminSecurityResult>? _resultFuture;

  @override
  Future<AdminSecurityResult> submit(AdminSecurityActionRequest request) {
    requests.add(request);
    return _resultFuture ?? Future.value(result);
  }
}
