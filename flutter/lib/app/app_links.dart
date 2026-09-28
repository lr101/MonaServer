import 'package:buff_lisa/data/config/api_host.dart';
import 'package:buff_lisa/features/email_login/domain/email_login_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

/// The validated navigation payload captured from an Android App Link.
/// Callback tokens stay in [EmailLinkLaunchData], which redacts its token.
final class AppLaunchData {
  const AppLaunchData({this.emailLink, this.groupInviteLocation});

  factory AppLaunchData.fromUri(Uri? incoming) {
    if (incoming == null || !_isSupportedOrigin(incoming)) {
      return const AppLaunchData();
    }

    final location = incoming.toString();
    if (EmailLinkLaunchParser.isCallbackLocation(location)) {
      return AppLaunchData(emailLink: EmailLinkLaunchParser.parse(location));
    }

    final groupInviteLocation = _parseGroupInviteLocation(incoming);
    return AppLaunchData(groupInviteLocation: groupInviteLocation);
  }

  final EmailLinkLaunchData? emailLink;
  final String? groupInviteLocation;

  @override
  String toString() =>
      'AppLaunchData(emailLink: ${emailLink == null ? 'none' : 'present'}, '
      'groupInvite: ${groupInviteLocation == null ? 'none' : 'present'})';
}

String groupInviteShareLink({
  required String apiHost,
  required String groupId,
  required String inviteCode,
}) {
  final origin = Uri.parse(apiHost);
  final route = Uri(
    path: '/groups/$groupId',
    queryParameters: {'invite': inviteCode},
  );
  return Uri(
    scheme: origin.scheme,
    host: origin.host,
    port: origin.hasPort ? origin.port : null,
    path: '/',
    fragment: route.toString(),
  ).toString();
}

bool _isSupportedOrigin(Uri uri) {
  final configured = Uri.parse(defaultApiHost);
  return uri.scheme == 'https' &&
      uri.host == configured.host &&
      (!uri.hasPort || uri.port == 443) &&
      uri.userInfo.isEmpty &&
      uri.path == '/' &&
      !uri.hasQuery;
}

String? _parseGroupInviteLocation(Uri incoming) {
  if (incoming.fragment.isEmpty || incoming.fragment.contains('#')) {
    return null;
  }
  final route = Uri.tryParse(incoming.fragment);
  if (route == null ||
      route.hasFragment ||
      route.pathSegments.length != 2 ||
      route.pathSegments.first != 'groups') {
    return null;
  }

  final groupId = route.pathSegments[1];
  if (!RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  ).hasMatch(groupId)) {
    return null;
  }

  final query = route.queryParametersAll;
  final inviteCodes = query['invite'];
  if (query.length != 1 ||
      inviteCodes == null ||
      inviteCodes.length != 1 ||
      !RegExp(r'^[A-Za-z0-9]{6}$').hasMatch(inviteCodes.single)) {
    return null;
  }

  return Uri(
    path: '/groups/$groupId',
    queryParameters: {'invite': inviteCodes.single},
  ).toString();
}

final appLaunchDataProvider = Provider<AppLaunchData?>((ref) => null);

/// Holds an invite destination while the user signs in. It is consumed by the
/// router after authentication so the invitation survives password or email
/// link login without putting the invite code in a login callback URL.
final pendingAppDestinationProvider = StateProvider<String?>(
  (ref) => ref.watch(appLaunchDataProvider)?.groupInviteLocation,
);

/// Production supplies the native app_links stream. Widget and browser apps
/// use an empty stream unless their composition root overrides it.
final appLinkEventsProvider = Provider<Stream<Uri>>(
  (ref) => const Stream<Uri>.empty(),
);
