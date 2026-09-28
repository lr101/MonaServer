import 'package:buff_lisa/app/app_links.dart';
import 'package:buff_lisa/data/config/api_host.dart';
import 'package:buff_lisa/data/entity/group_entity.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GroupInviteShareButton extends StatelessWidget {
  const GroupInviteShareButton({super.key, required this.groupDto});

  final GroupEntity groupDto;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Copy share link',
      onPressed: () => _copyShareLink(context),
      icon: const Icon(Icons.share),
    );
  }

  Future<void> _copyShareLink(BuildContext context) async {
    final inviteCode = groupDto.inviteUrl;
    if (inviteCode == null) return;

    final shareLink = groupInviteShareLink(
      apiHost: resolveApiHost(
        configuredHost: dotenv.env['API_HOST'],
        pageOrigin: kIsWeb ? Uri.base.origin : null,
      ),
      groupId: groupDto.groupId,
      inviteCode: inviteCode,
    );
    await Clipboard.setData(ClipboardData(text: shareLink));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Share link copied')));
  }
}
