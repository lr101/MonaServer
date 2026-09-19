import 'dart:math';

import 'package:buff_lisa/features/admin_audience/domain/admin_audience_models.dart';
import 'package:buff_lisa/features/admin_campaigns/domain/admin_campaign_models.dart';
import 'package:buff_lisa/features/admin_campaigns/domain/admin_campaign_ports.dart';

final class AdminCampaignState {
  const AdminCampaignState({
    this.audience,
    this.draft,
    this.preview,
    this.submitting = false,
    this.testDelivery = AdminCampaignTestDelivery.idle,
    this.commitIdempotencyKey,
    this.jobId,
    this.message,
    this.sessionExpired = false,
  });

  final AdminAudienceSelection? audience;
  final AdminCampaignDraft? draft;
  final AdminAudiencePreview? preview;
  final bool submitting;
  final AdminCampaignTestDelivery testDelivery;
  final String? commitIdempotencyKey;
  final String? jobId;
  final String? message;
  final bool sessionExpired;

  AdminCampaignState copyWith({
    AdminAudienceSelection? audience,
    AdminCampaignDraft? draft,
    AdminAudiencePreview? preview,
    bool clearPreview = false,
    bool? submitting,
    AdminCampaignTestDelivery? testDelivery,
    String? commitIdempotencyKey,
    bool clearCommitIdempotencyKey = false,
    String? jobId,
    bool clearJobId = false,
    String? message,
    bool clearMessage = false,
    bool? sessionExpired,
  }) => AdminCampaignState(
    audience: audience ?? this.audience,
    draft: draft ?? this.draft,
    preview: clearPreview ? null : preview ?? this.preview,
    submitting: submitting ?? this.submitting,
    testDelivery: testDelivery ?? this.testDelivery,
    commitIdempotencyKey: clearCommitIdempotencyKey
        ? null
        : commitIdempotencyKey ?? this.commitIdempotencyKey,
    jobId: clearJobId ? null : jobId ?? this.jobId,
    message: clearMessage ? null : message ?? this.message,
    sessionExpired: sessionExpired ?? this.sessionExpired,
  );
}

typedef AdminCampaignListener = void Function(AdminCampaignState state);

final class _PendingCampaignDraft {
  const _PendingCampaignDraft({required this.audience, required this.draft});

  final AdminAudienceSelection audience;
  final AdminCampaignDraft draft;
}

/// Owns a preview/commit cycle and fences all late work after session expiry.
final class AdminCampaignController {
  AdminCampaignController(
    this.repository, {
    String Function()? idempotencyKey,
    this.onUnauthorized,
    this.onCapabilityDenied,
  }) : _idempotencyKey = idempotencyKey ?? _newIdempotencyKey;

  final AdminCampaignRepository repository;
  final void Function()? onUnauthorized;
  final void Function()? onCapabilityDenied;
  final String Function() _idempotencyKey;
  final _listeners = <AdminCampaignListener>{};
  AdminCampaignState _state = const AdminCampaignState();
  Future<void>? _commitInFlight;
  Future<void>? _testInFlight;
  _PendingCampaignDraft? _pendingDraft;
  int _generation = 0;
  bool _expired = false;

  AdminCampaignState get state => _state;

  void addListener(AdminCampaignListener listener) => _listeners.add(listener);
  void removeListener(AdminCampaignListener listener) =>
      _listeners.remove(listener);

  /// A changed composer draft can no longer use a preview bound to prior text.
  void updateDraft(AdminAudienceSelection audience, AdminCampaignDraft draft) {
    if (_expired) return;
    if (_state.submitting) {
      _pendingDraft = _PendingCampaignDraft(audience: audience, draft: draft);
      return;
    }
    if (_state.audience == audience && _state.draft?.action == draft.action) {
      return;
    }
    ++_generation;
    _emit(
      _state.copyWith(
        audience: audience,
        draft: draft,
        clearPreview: true,
        clearCommitIdempotencyKey: true,
        clearJobId: true,
        submitting: false,
        clearMessage: true,
      ),
    );
  }

  Future<void> preview(
    AdminAudienceSelection audience,
    AdminCampaignDraft draft,
  ) async {
    if (_expired) return;
    final request = AdminAudiencePreviewRequest(
      audience: audience,
      action: draft.action,
    );
    if (!request.isValid) {
      _emit(
        _state.copyWith(
          audience: audience,
          draft: draft,
          clearPreview: true,
          message:
              'Choose an explicit audience and complete the message first.',
        ),
      );
      return;
    }
    final generation = ++_generation;
    _emit(
      _state.copyWith(
        audience: audience,
        draft: draft,
        clearPreview: true,
        clearJobId: true,
        clearCommitIdempotencyKey: true,
        submitting: true,
        clearMessage: true,
      ),
    );
    try {
      final preview = await repository.preview(request);
      if (!_isCurrent(generation)) return;
      _emit(_state.copyWith(preview: preview, submitting: false));
      _reconcilePendingDraft();
    } catch (error) {
      if (!_isCurrent(generation)) return;
      _handleError(
        error,
        fallback: 'Audience preview is unavailable. Try again.',
      );
      _reconcilePendingDraft();
    }
  }

  Future<void> confirm() {
    if (_expired || _state.jobId != null) return Future.value();
    final existing = _commitInFlight;
    if (existing != null) return existing;
    final audience = _state.audience;
    final draft = _state.draft;
    final preview = _state.preview;
    final request = preview?.commitRequest(
      expectedAudience: audience,
      expectedAction: draft?.action,
      expectedPayloadHash: preview.payloadHash,
    );
    if (request == null) {
      _emit(
        _state.copyWith(
          message: 'This preview is stale. Prepare a new preview.',
        ),
      );
      return Future.value();
    }
    final command = AdminCampaignCommitCommand(
      commit: request,
      idempotencyKey: _state.commitIdempotencyKey ?? _idempotencyKey(),
    );
    if (_state.commitIdempotencyKey == null) {
      _emit(_state.copyWith(commitIdempotencyKey: command.idempotencyKey));
    }
    final future = _commit(command);
    _commitInFlight = future;
    return future;
  }

  Future<void> _commit(AdminCampaignCommitCommand command) async {
    final generation = _generation;
    _emit(_state.copyWith(submitting: true, clearMessage: true));
    try {
      final result = await repository.commit(command);
      if (!_isCurrent(generation)) return;
      _emit(
        _state.copyWith(
          submitting: false,
          jobId: result.jobId,
          message: 'Campaign accepted for delivery.',
        ),
      );
      _reconcilePendingDraft();
    } catch (error) {
      if (!_isCurrent(generation)) return;
      _handleError(
        error,
        fallback: 'Campaign could not be accepted. Try again.',
      );
      _reconcilePendingDraft();
    } finally {
      _commitInFlight = null;
    }
  }

  Future<void> sendTest({
    required String recipientUserId,
    required AdminCampaignDraft draft,
  }) {
    if (_expired || recipientUserId.trim().isEmpty || !draft.isValid) {
      return Future<void>.value();
    }
    final existing = _testInFlight;
    if (existing != null) return existing;
    final future = _sendTest(recipientUserId: recipientUserId, draft: draft);
    _testInFlight = future;
    return future;
  }

  Future<void> _sendTest({
    required String recipientUserId,
    required AdminCampaignDraft draft,
  }) async {
    final generation = _generation;
    _emit(_state.copyWith(submitting: true, clearMessage: true));
    try {
      final result = await repository.sendTest(
        recipientUserId: recipientUserId.trim(),
        action: draft.action,
      );
      if (!_isCurrent(generation)) return;
      final message = switch (result.delivery) {
        AdminCampaignTestDelivery.accepted => 'Test delivery was accepted.',
        AdminCampaignTestDelivery.unavailable =>
          'Test delivery is unavailable. Nothing was sent.',
        AdminCampaignTestDelivery.failed =>
          'Test delivery failed. Nothing was sent.',
        AdminCampaignTestDelivery.idle => null,
      };
      _emit(
        _state.copyWith(
          submitting: false,
          testDelivery: result.delivery,
          message: message,
        ),
      );
      _reconcilePendingDraft();
    } catch (error) {
      if (!_isCurrent(generation)) return;
      _handleError(error, fallback: 'Test delivery failed. Nothing was sent.');
      _reconcilePendingDraft();
    } finally {
      _testInFlight = null;
    }
  }

  void _reconcilePendingDraft() {
    final pending = _pendingDraft;
    _pendingDraft = null;
    if (pending == null || _expired) return;
    ++_generation;
    _emit(
      _state.copyWith(
        audience: pending.audience,
        draft: pending.draft,
        clearPreview: true,
        clearCommitIdempotencyKey: true,
      ),
    );
  }

  void expireSession() {
    if (_expired) return;
    _expired = true;
    _pendingDraft = null;
    ++_generation;
    _emit(
      _state.copyWith(
        clearPreview: true,
        submitting: false,
        sessionExpired: true,
        message: 'Your admin session has expired.',
      ),
    );
    onUnauthorized?.call();
  }

  bool _isCurrent(int generation) => !_expired && generation == _generation;

  void _handleError(Object error, {required String fallback}) {
    if (error is AdminCampaignTransportException && error.isUnauthorized) {
      expireSession();
      return;
    }
    if (error is AdminCampaignTransportException && error.isForbidden) {
      onCapabilityDenied?.call();
      _emit(
        _state.copyWith(
          submitting: false,
          message: 'You do not have permission for that action.',
        ),
      );
      return;
    }
    _emit(_state.copyWith(submitting: false, message: fallback));
  }

  void _emit(AdminCampaignState state) {
    _state = state;
    for (final listener in List<AdminCampaignListener>.of(_listeners)) {
      listener(state);
    }
  }

  static String _newIdempotencyKey() {
    const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return List<String>.generate(
      32,
      (_) => alphabet[random.nextInt(alphabet.length)],
      growable: false,
    ).join();
  }
}
