import 'package:buff_lisa/features/admin_audience/domain/admin_audience_models.dart';
import 'package:buff_lisa/features/admin_campaigns/domain/admin_campaign_models.dart';
import 'package:buff_lisa/features/admin_campaigns/presentation/admin_campaign_controller.dart';
import 'package:flutter/material.dart';

/// Constructor-only seam for T10 composition; it does not own routing or API wiring.
final class AdminCampaignScreen extends StatefulWidget {
  const AdminCampaignScreen({
    required this.controller,
    required this.audience,
    required this.testRecipientUserId,
    super.key,
  });

  final AdminCampaignController controller;
  final AdminAudienceSelection audience;
  final String testRecipientUserId;

  @override
  State<AdminCampaignScreen> createState() => _AdminCampaignScreenState();
}

final class _AdminCampaignScreenState extends State<AdminCampaignScreen> {
  AdminCampaignKind _kind = AdminCampaignKind.email;
  final _subject = TextEditingController();
  final _title = TextEditingController();
  final _body = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _subject.dispose();
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _changed(AdminCampaignState _) {
    if (mounted) setState(() {});
  }

  void _syncDraft() => widget.controller.updateDraft(widget.audience, _draft);

  @override
  void didUpdateWidget(covariant AdminCampaignScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audience != widget.audience) _syncDraft();
  }

  AdminCampaignDraft get _draft => switch (_kind) {
    AdminCampaignKind.email => AdminCampaignDraft.email(
      subject: _subject.text,
      body: _body.text,
    ),
    AdminCampaignKind.push => AdminCampaignDraft.push(
      title: _title.text,
      body: _body.text,
    ),
    AdminCampaignKind.loginLink => const AdminCampaignDraft.loginLink(),
  };

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    final canConfirm =
        !state.submitting &&
        state.jobId == null &&
        (state.preview?.canConfirm(
              null,
              widget.audience,
              _draft.action,
              state.preview?.payloadHash,
            ) ??
            false);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Campaign composer',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text('Audience: ${widget.audience.summary}'),
        const SizedBox(height: 16),
        DropdownButtonFormField<AdminCampaignKind>(
          initialValue: _kind,
          decoration: const InputDecoration(labelText: 'Message type'),
          items: const [
            DropdownMenuItem(
              value: AdminCampaignKind.email,
              child: Text('Email'),
            ),
            DropdownMenuItem(
              value: AdminCampaignKind.push,
              child: Text('Push notification'),
            ),
            DropdownMenuItem(
              value: AdminCampaignKind.loginLink,
              child: Text('Sign-in link'),
            ),
          ],
          onChanged: state.submitting
              ? null
              : (value) {
                  setState(() => _kind = value!);
                  _syncDraft();
                },
        ),
        if (_kind == AdminCampaignKind.email)
          TextField(
            controller: _subject,
            enabled: !state.submitting,
            onChanged: (_) => _syncDraft(),
            decoration: const InputDecoration(labelText: 'Subject'),
          ),
        if (_kind == AdminCampaignKind.push)
          TextField(
            controller: _title,
            enabled: !state.submitting,
            onChanged: (_) => _syncDraft(),
            decoration: const InputDecoration(labelText: 'Title'),
          ),
        if (_kind != AdminCampaignKind.loginLink)
          TextField(
            controller: _body,
            enabled: !state.submitting,
            onChanged: (_) => _syncDraft(),
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Message'),
          ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          children: [
            OutlinedButton(
              onPressed: state.submitting
                  ? null
                  : () => widget.controller.sendTest(
                      recipientUserId: widget.testRecipientUserId,
                      draft: _draft,
                    ),
              child: const Text('Send safe test'),
            ),
            ElevatedButton(
              onPressed: state.submitting
                  ? null
                  : () => widget.controller.preview(widget.audience, _draft),
              child: const Text('Preview audience'),
            ),
            ElevatedButton(
              onPressed: canConfirm ? widget.controller.confirm : null,
              child: const Text('Confirm campaign'),
            ),
          ],
        ),
        if (state.preview != null) ...[
          const SizedBox(height: 16),
          Text(
            '${state.preview!.accountAudienceCount} accounts in frozen snapshot',
          ),
          Text('${state.preview!.eligibleRecipientCount} eligible recipients'),
          Text('${state.preview!.excludedCount} exclusions'),
        ],
        if (state.message != null) ...[
          const SizedBox(height: 16),
          Text(state.message!, key: const ValueKey('admin-campaign-message')),
        ],
      ],
    );
  }
}
