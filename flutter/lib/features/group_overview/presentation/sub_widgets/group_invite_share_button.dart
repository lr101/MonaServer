import 'package:buff_lisa/app/app_links.dart';
import 'package:buff_lisa/data/config/api_host.dart';
import 'package:buff_lisa/data/entity/group_entity.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:share_plus/share_plus.dart';

class GroupInviteShareButton extends StatefulWidget {
  const GroupInviteShareButton({super.key, required this.groupDto});

  final GroupEntity groupDto;

  @override
  State<GroupInviteShareButton> createState() => _GroupInviteShareButtonState();
}

class _GroupInviteShareButtonState extends State<GroupInviteShareButton> {
  final _shareButtonKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: _shareButtonKey,
      tooltip: 'Share group',
      onPressed: _shareInviteLink,
      icon: const Icon(Icons.share),
    );
  }

  Future<void> _shareInviteLink() async {
    final inviteCode = widget.groupDto.inviteUrl;
    if (inviteCode == null) return;

    final shareLink = groupInviteShareLink(
      apiHost: resolveApiHost(
        configuredHost: dotenv.env['API_HOST'],
        pageOrigin: kIsWeb ? Uri.base.origin : null,
      ),
      groupId: widget.groupDto.groupId,
      inviteCode: inviteCode,
    );

    try {
      await SharePlus.instance.share(
        ShareParams(
          title: 'Join ${widget.groupDto.name}',
          text: 'Join ${widget.groupDto.name} on Stick-It: $shareLink',
          sharePositionOrigin: _sharePositionOrigin,
        ),
      );
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: shareLink));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Share unavailable. Link copied.')),
      );
    }
  }

  Rect? get _sharePositionOrigin {
    final renderObject = _shareButtonKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;

    return renderObject.localToGlobal(Offset.zero) & renderObject.size;
  }
}
