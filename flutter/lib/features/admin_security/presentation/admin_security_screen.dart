import 'package:buff_lisa/features/admin_audience/domain/admin_audience_models.dart';
import 'package:buff_lisa/features/admin_security/domain/admin_security_models.dart';
import 'package:buff_lisa/features/admin_security/presentation/admin_security_controller.dart';
import 'package:flutter/material.dart';

/// Constructor-only seam for T10 composition; this screen does not route itself.
final class AdminSecurityScreen extends StatefulWidget {
  const AdminSecurityScreen({
    required this.controller,
    required this.audience,
    super.key,
  });

  final AdminSecurityController controller;
  final AdminAudienceSelection audience;

  @override
  State<AdminSecurityScreen> createState() => _AdminSecurityScreenState();
}

final class _AdminSecurityScreenState extends State<AdminSecurityScreen> {
  AdminSecurityActionKind _kind = AdminSecurityActionKind.revokeSessions;
  final _reason = TextEditingController();
  bool _includeAdministrators = false;
  bool _administratorAcknowledged = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _reason.dispose();
    super.dispose();
  }

  void _changed(AdminSecurityState _) {
    if (mounted) setState(() {});
  }

  AdminSecurityRequest get _request => switch (_kind) {
    AdminSecurityActionKind.revokeSessions => AdminSecurityRequest.revoke(
      reason: _reason.text,
      includeAdministrators: _includeAdministrators,
    ),
    AdminSecurityActionKind.compromise => AdminSecurityRequest.compromise(
      reason: _reason.text,
      includeAdministrators: _includeAdministrators,
    ),
    AdminSecurityActionKind.recoveryResend =>
      AdminSecurityRequest.recoveryResend(
        reason: _reason.text,
        includeAdministrators: _includeAdministrators,
      ),
  };

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Security actions',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text('Audience: ${widget.audience.summary}'),
        DropdownButtonFormField<AdminSecurityActionKind>(
          initialValue: _kind,
          decoration: const InputDecoration(labelText: 'Action'),
          items: const [
            DropdownMenuItem(
              value: AdminSecurityActionKind.revokeSessions,
              child: Text('Revoke sessions'),
            ),
            DropdownMenuItem(
              value: AdminSecurityActionKind.compromise,
              child: Text('Mark compromised'),
            ),
            DropdownMenuItem(
              value: AdminSecurityActionKind.recoveryResend,
              child: Text('Resend recovery'),
            ),
          ],
          onChanged: state.phase == AdminSecurityPhase.submitting
              ? null
              : (value) => setState(() => _kind = value!),
        ),
        TextField(
          controller: _reason,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Reason'),
        ),
        CheckboxListTile(
          value: _includeAdministrators,
          onChanged: (value) => setState(() {
            _includeAdministrators = value ?? false;
            if (!_includeAdministrators) _administratorAcknowledged = false;
          }),
          title: const Text('Include administrator accounts'),
        ),
        if (_includeAdministrators)
          CheckboxListTile(
            value: _administratorAcknowledged,
            onChanged: (value) =>
                setState(() => _administratorAcknowledged = value ?? false),
            title: const Text(
              'I understand this may revoke administrator access.',
            ),
          ),
        ElevatedButton(
          onPressed: state.phase == AdminSecurityPhase.submitting
              ? null
              : () => widget.controller.submit(
                  audience: widget.audience,
                  request: _request,
                  administratorInclusionAcknowledged:
                      _administratorAcknowledged,
                ),
          child: const Text('Submit security action'),
        ),
        if (state.message != null) ...[
          const SizedBox(height: 16),
          Text(state.message!, key: const ValueKey('admin-security-message')),
        ],
      ],
    );
  }
}
