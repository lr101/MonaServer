import 'package:buff_lisa/features/admin_audience/domain/admin_audience_models.dart';
import 'package:buff_lisa/features/admin_security/domain/admin_security_models.dart';
import 'package:buff_lisa/features/admin_security/domain/admin_security_ports.dart';

enum AdminSecurityPhase {
  idle,
  mfaRequired,
  submitting,
  submitted,
  expired,
  failed,
}

final class AdminSecurityState {
  const AdminSecurityState({
    this.phase = AdminSecurityPhase.idle,
    this.result,
    this.message,
  });

  final AdminSecurityPhase phase;
  final AdminSecurityResult? result;
  final String? message;

  AdminSecurityState copyWith({
    AdminSecurityPhase? phase,
    AdminSecurityResult? result,
    bool clearResult = false,
    String? message,
    bool clearMessage = false,
  }) => AdminSecurityState(
    phase: phase ?? this.phase,
    result: clearResult ? null : result ?? this.result,
    message: clearMessage ? null : message ?? this.message,
  );
}

typedef AdminSecurityListener = void Function(AdminSecurityState state);

final class AdminSecurityController {
  AdminSecurityController(
    this.repository, {
    required this.hasRecentMfa,
    this.onUnauthorized,
    this.onCapabilityDenied,
  });

  final AdminSecurityRepository repository;
  final bool Function() hasRecentMfa;
  final void Function()? onUnauthorized;
  final void Function()? onCapabilityDenied;
  final _listeners = <AdminSecurityListener>{};
  AdminSecurityState _state = const AdminSecurityState();
  Future<void>? _submission;
  int _generation = 0;
  bool _expired = false;

  AdminSecurityState get state => _state;

  void addListener(AdminSecurityListener listener) => _listeners.add(listener);
  void removeListener(AdminSecurityListener listener) =>
      _listeners.remove(listener);

  Future<void> submit({
    required AdminAudienceSelection audience,
    required AdminSecurityRequest request,
    bool administratorInclusionAcknowledged = false,
  }) {
    if (_expired) return Future.value();
    if (!hasRecentMfa()) {
      _emit(
        _state.copyWith(
          phase: AdminSecurityPhase.mfaRequired,
          clearResult: true,
          message: 'Verify MFA again before submitting this security action.',
        ),
      );
      return Future.value();
    }
    final command = AdminSecurityActionRequest(
      audience: audience,
      request: request,
      administratorInclusionAcknowledged: administratorInclusionAcknowledged,
    );
    if (!command.isValid) {
      _emit(
        _state.copyWith(
          phase: AdminSecurityPhase.idle,
          message: request.includeAdministrators
              ? 'Acknowledge administrator inclusion before continuing.'
              : 'Choose an explicit audience and provide a reason.',
        ),
      );
      return Future.value();
    }
    final inFlight = _submission;
    if (inFlight != null) return inFlight;
    final future = _submit(command);
    _submission = future;
    return future;
  }

  Future<void> _submit(AdminSecurityActionRequest request) async {
    final generation = _generation;
    _emit(
      _state.copyWith(
        phase: AdminSecurityPhase.submitting,
        clearResult: true,
        clearMessage: true,
      ),
    );
    try {
      final result = await repository.submit(request);
      if (!_isCurrent(generation)) return;
      _emit(
        _state.copyWith(
          phase: AdminSecurityPhase.submitted,
          result: result,
          message: result.manualRecoveryRequired
              ? 'Account containment completed. Manual identity recovery is required.'
              : 'Security action accepted for processing.',
        ),
      );
    } catch (error) {
      if (!_isCurrent(generation)) return;
      if (error is AdminSecurityTransportException && error.isUnauthorized) {
        expireSession();
      } else if (error is AdminSecurityTransportException &&
          error.isForbidden) {
        onCapabilityDenied?.call();
        _emit(
          _state.copyWith(
            phase: AdminSecurityPhase.failed,
            message: 'You do not have permission for that action.',
          ),
        );
      } else {
        _emit(
          _state.copyWith(
            phase: AdminSecurityPhase.failed,
            message: 'Security action is unavailable. No result was confirmed.',
          ),
        );
      }
    } finally {
      _submission = null;
    }
  }

  void expireSession() {
    if (_expired) return;
    _expired = true;
    ++_generation;
    _emit(
      _state.copyWith(
        phase: AdminSecurityPhase.expired,
        clearResult: true,
        message: 'Your admin session has expired.',
      ),
    );
    onUnauthorized?.call();
  }

  bool _isCurrent(int generation) => !_expired && generation == _generation;

  void _emit(AdminSecurityState state) {
    _state = state;
    for (final listener in List<AdminSecurityListener>.of(_listeners)) {
      listener(state);
    }
  }
}
