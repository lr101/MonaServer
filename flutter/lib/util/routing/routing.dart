import 'dart:typed_data';

import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/features/achievement/presentation/achievement_page.dart';
import 'package:buff_lisa/features/auth/presentation/auth.dart';
import 'package:buff_lisa/features/auth/presentation/logout_screen.dart';
import 'package:buff_lisa/features/camera/presentation/image_upload.dart';
import 'package:buff_lisa/features/camera/presentation/select_location.dart';
import 'package:buff_lisa/features/group_create/presentation/group_create.dart';
import 'package:buff_lisa/features/group_edit/presentation/group_edit.dart';
import 'package:buff_lisa/features/group_overview/presentation/user_group_overview.dart';
import 'package:buff_lisa/features/group_search/presentation/group_search.dart';
import 'package:buff_lisa/features/map_home/presentation/osm_copyright.dart';
import 'package:buff_lisa/features/navigation/data/navigation_provider.dart';
import 'package:buff_lisa/features/navigation/presentation/navigation.dart';
import 'package:buff_lisa/features/pin/presentation/view_image.dart';
import 'package:buff_lisa/features/profile/presentation/other_user_profile.dart';
import 'package:buff_lisa/features/settings/presentation/settings.dart';
import 'package:buff_lisa/features/settings/presentation/sub_widgets/change_email.dart';
import 'package:buff_lisa/features/settings/presentation/sub_widgets/change_password.dart';
import 'package:buff_lisa/features/settings/presentation/sub_widgets/change_profile.dart';
import 'package:buff_lisa/features/settings/presentation/sub_widgets/delete_account.dart';
import 'package:buff_lisa/features/settings/presentation/sub_widgets/edit_hidden_posts.dart';
import 'package:buff_lisa/features/settings/presentation/sub_widgets/edit_hidden_users.dart';
import 'package:buff_lisa/features/web/presentation/show_web.dart';
import 'package:buff_lisa/widgets/custom_interaction/presentation/custom_error_snack_bar.dart';
import 'package:buff_lisa/widgets/report_issue/presentation/report_issue_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

final authStateProvider = StateProvider<bool>((ref) => false);

final routerProvider = Provider<GoRouter>(
  (ref) => GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: '/login',
    redirect: (context, state) {
      final isLoggedIn = ref.read(globalDataServiceProvider).userId != null;
      final bool isGoingToLogin = state.matchedLocation == '/login';
      final bool isWeb = state.matchedLocation == "/web";
      final bool isLogout = state.matchedLocation == "/logout";
      if (!isLoggedIn && !isGoingToLogin && !isWeb && !isLogout) {
        return '/login';
      }
      if (isLoggedIn && isGoingToLogin && !isWeb) {
        return '/home';
      }
      return null;
    },
    routes: [
      // WEB ---
      GoRoute(
        path: '/web',
        name: 'web',
        builder: (context, state) {
          final url = state.uri.queryParameters['url'] ?? '';
          final title = state.uri.queryParameters['title'] ?? '';
          return ShowWebWidget(route: url, title: title);
        },
      ),

      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const Auth(),
      ),

      GoRoute(
        path: '/logout',
        name: 'logout',
        builder: (context, state) =>
            LogoutScreen(isCacheOnly: state.extra as bool? ?? false),
      ),

      GoRoute(
        path: '/home',
        name: 'home',
        builder: (contet, state) => const Navigation(),
      ),

      // --- CAMERA FLOW (Passing complex data via 'extra') ---
      GoRoute(
        path: '/camera/select-location',
        name: 'selectLocation',
        builder: (context, state) {
          final image = state.extra! as Uint8List;
          final lat = state.uri.queryParameters['lat'];
          final long = state.uri.queryParameters['long'];
          final LatLng? latLng;
          if (lat != null && long != null) {
            latLng = LatLng(double.parse(lat), double.parse(long));
          } else {
            latLng = null;
          }
          return SelectLocation(image: image, center: latLng);
        },
      ),
      GoRoute(
        path: '/camera/upload',
        name: 'imageUpload',
        builder: (context, state) {
          final image = state.extra! as Uint8List;
          return ImageUpload(
            image: image,
            position: LatLng(
              double.parse(state.uri.queryParameters['lat']!),
              double.parse(state.uri.queryParameters['long']!),
            ),
          );
        },
      ),

      // --- GROUPS ---
      GoRoute(
        path: '/groups/search',
        name: 'groupSearch',
        builder: (context, state) => const GroupSearch(),
      ),
      GoRoute(
        path: '/groups/create',
        name: 'groupCreate',
        builder: (context, state) => const GroupCreate(),
      ),
      // Path parameter used for the ID
      GoRoute(
        path: '/groups/:id',
        name: 'groupOverview',
        builder: (context, state) {
          final groupId = state.pathParameters['id']!;
          return UserGroupOverview(groupId: groupId);
        },
      ),
      GoRoute(
        path: '/groups/:id/edit', // Passing DTO via extra
        name: 'groupEdit',
        builder: (context, state) =>
            GroupEdit(groupid: state.pathParameters['id']!),
      ),

      // --- USERS ---
      GoRoute(
        path: '/users/:id',
        name: 'userProfile',
        builder: (context, state) =>
            OtherUserProfile(userId: state.pathParameters['id']!),
      ),

      // --- PINS / IMAGES ---
      GoRoute(
        path: '/pins/:id',
        name: 'viewImage',
        builder: (context, state) =>
            ViewImage(pinId: state.pathParameters['id']!),
      ),

      // --- SETTINGS & PROFILE ---
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const Settings(),
        routes: [
          // These act as sub-routes: /settings/profile
          GoRoute(
            path: 'profile',
            name: "profileSettings",
            builder: (context, state) => const ChangeProfile(),
          ),
          GoRoute(
            path: 'password',
            name: "pswSettings",
            builder: (context, state) => const ChangePassword(),
          ),
          GoRoute(
            path: 'email',
            name: "emailSettings",
            builder: (context, state) => const ChangeEmailPage(),
          ),
          GoRoute(
            path: 'hidden-posts',
            name: "hiddenPostSettings",
            builder: (context, state) => const EditHiddenPosts(),
          ),
          GoRoute(
            path: 'hidden-users',
            name: "hiddenUserSettings",
            builder: (context, state) => const EditHiddenUsers(),
          ),
          GoRoute(
            path: 'delete-account',
            name: "deleteSettings",
            builder: (context, state) => const DeleteAccount(),
          ),
        ],
      ),

      // --- MISC ---
      GoRoute(
        path: '/achievements',
        name: 'achievements',
        builder: (context, state) => const AchievementsPage(),
      ),
      GoRoute(
        path: '/osm-copyright',
        name: 'osmCopyright',
        // Assuming you have a widget for this
        builder: (context, state) => const OsmCopyright(),
      ),
      GoRoute(
        path: '/report',
        name: 'report',
        builder: (context, state) {
          return ReportIssuePage(
            issueTypes:
                state.extra as List<String>? ??
                ["Bug", "Feature Request", "Other"],
            groupId: state.uri.queryParameters['groupId'],
            userId: state.uri.queryParameters['userId'],
            pinId: state.uri.queryParameters['pinId'],
          );
        },
      ),
    ],
  ),
);

Future<void> clickedOnLink(String? link) async {
  if (link != null) {
    try {
      await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
    } catch (e) {
      CustomErrorSnackBar.message(
        message: "No app to open link found",
        type: CustomErrorSnackBarType.error,
      );
    }
  }
}
