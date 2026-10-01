import 'package:buff_lisa/data/dto/global_data_dto.dart';
import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/service/filter_service.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/group_service.dart';
import 'package:buff_lisa/data/service/image_service.dart';
import 'package:buff_lisa/data/service/pin_service.dart';
import 'package:buff_lisa/data/service/shared_preferences_service.dart';
import 'package:buff_lisa/data/service/user_service.dart';
import 'package:buff_lisa/features/map_home/data/map_state.dart';
import 'package:buff_lisa/features/pin/presentation/pin_photo_history.dart';
import 'package:buff_lisa/features/pin/presentation/view_image.dart';
import 'package:buff_lisa/features/settings/presentation/sub_widgets/edit_hidden_posts.dart';
import 'package:buff_lisa/features/settings/presentation/sub_widgets/edit_hidden_users.dart';
import 'package:buff_lisa/widgets/custom_feed/presentation/pop_up_menu_feed.dart';
import 'package:buff_lisa/widgets/custom_marker/data/default_group_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transparent_image/transparent_image.dart';

PinEntity pin(String id, String creator) => PinEntity(
  pinId: id,
  creator: creator,
  groupId: 'group',
  latitude: 0,
  longitude: 0,
  creationDate: DateTime(2026),
  ttl: DateTime(2027),
  onlySession: false,
);

void main() {
  testWidgets(
    'inspect hidden artwork without restoring it, then restore explicitly',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'hiddenPosts': ['artwork'],
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          globalDataServiceProvider.overrideWithValue(
            const GlobalDataDto(
              userId: 'viewer',
              refreshToken: null,
              cameras: [],
            ),
          ),
          defaultErrorImageProvider.overrideWithValue(kTransparentImage),
          pinByIdProvider('artwork')
              .overrideWith((ref) => Stream.value(pin('artwork', 'artist'))),
          pinImageForDetailsProvider('artwork')
              .overrideWith((ref) => kTransparentImage),
          userByIdUsernameProvider('artist')
              .overrideWith((ref) => Future.value('Artist')),
          groupMetadataProvider('group')
              .overrideWith((ref) => Stream.value(null)),
          currentLocationProvider.overrideWith((ref) => const Stream.empty()),
          pinPhotoHistoryProvider('artwork')
              .overrideWith((ref) => Future.value([])),
        ],
      );
      addTearDown(container.dispose);
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const EditHiddenPosts()),
          GoRoute(
            path: '/pins/:id',
            name: 'viewImage',
            builder: (_, state) =>
                ViewImage(pinId: state.pathParameters['id']!),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(ListTile),
          matching: find.byType(Image),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Hidden artwork'));
      await tester.pumpAndSettle();
      expect(find.byType(ViewImage), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(PageView),
          matching: find.byType(Image),
        ),
        findsOneWidget,
      );
      expect(find.text('Artist'), findsOneWidget);
      expect(container.read(hiddenPostsServiceProvider), ['artwork']);
      expect(prefs.getStringList('hiddenPosts'), ['artwork']);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Hidden artwork'), findsOneWidget);
      await tester.tap(find.byTooltip('Show this post again'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Show post'));
      await tester.pumpAndSettle();
      expect(find.text('No hidden posts'), findsOneWidget);
      expect(prefs.getStringList('hiddenPosts'), isEmpty);
    },
  );

  for (final hideUser in [false, true]) {
    testWidgets(
      'dropdown hides ${hideUser ? 'user' : 'post'} and settings restores it',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final artwork = pin('artwork', 'artist');
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            defaultErrorImageProvider.overrideWithValue(kTransparentImage),
            globalDataServiceProvider.overrideWithValue(
              const GlobalDataDto(
                userId: 'viewer',
                refreshToken: 'test',
                cameras: [],
              ),
            ),
            groupMetadataProvider('group')
                .overrideWith((ref) => Stream.value(null)),
            pinGroupServiceUnfilteredProvider('group').overrideWith(_Pins.new),
            userByIdUsernameProvider('artist')
                .overrideWith((ref) => Future.value('Artist')),
            getUserProfileSmallProvider('artist')
                .overrideWith((ref) => Stream.value(null)),
          ],
        );
        addTearDown(container.dispose);
        container.listen(pinGroupServiceProvider('group'), (_, _) {});
        Future<void> show(Widget child) async {
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(home: Scaffold(body: child)),
            ),
          );
          await tester.pumpAndSettle();
        }

        await show(
          Consumer(
            builder: (context, ref, child) {
              final pins =
                  ref.watch(pinGroupServiceProvider('group')).value ?? [];
              return pins.any((pin) => pin.pinId == artwork.pinId)
                  ? PopUpMenuFeed(pinDto: artwork)
                  : const SizedBox.shrink();
            },
          ),
        );
        await tester.tap(find.byType(PopupMenuButton<int>));
        await tester.pumpAndSettle();
        await tester.tap(find.text(hideUser ? 'Hide user' : 'Hide post'));
        await tester.pumpAndSettle();
        expect(
          (await container.read(pinGroupServiceProvider('group').future))
              .map((p) => p.pinId),
          hideUser ? ['third'] : ['second', 'third'],
        );
        expect(prefs.getStringList(hideUser ? 'hiddenUsers' : 'hiddenPosts'), [
          if (hideUser) 'artist' else 'artwork',
        ]);
        expect(find.byType(SnackBar), findsOneWidget);
        await tester.tap(find.text('Undo'));
        await tester.pumpAndSettle();
        expect(
          (await container.read(pinGroupServiceProvider('group').future))
              .length,
          3,
        );
        expect(
          prefs.getStringList(hideUser ? 'hiddenUsers' : 'hiddenPosts'),
          isEmpty,
        );
        await tester.tap(find.byType(PopupMenuButton<int>));
        await tester.pumpAndSettle();
        await tester.tap(find.text(hideUser ? 'Hide user' : 'Hide post'));
        await tester.pumpAndSettle();
        // Recreate the saved filters, as happens when the app is reopened.
        container.invalidate(hiddenPostsServiceProvider);
        container.invalidate(hiddenUserServiceProvider);

        await show(
          hideUser ? const EditHiddenUsers() : const EditHiddenPosts(),
        );
        await tester.tap(
          find.byTooltip(
            hideUser ? 'Show this user’s posts again' : 'Show this post again',
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(
            FilledButton,
            hideUser ? 'Show user' : 'Show post',
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(hideUser ? 'No hidden users' : 'No hidden posts'),
          findsOneWidget,
        );
        expect(
          (await container.read(pinGroupServiceProvider('group').future))
              .length,
          3,
        );
        expect(
          prefs.getStringList(hideUser ? 'hiddenUsers' : 'hiddenPosts'),
          isEmpty,
        );
      },
    );
  }

  testWidgets('own posts can be hidden without reporting or hiding yourself', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          globalDataServiceProvider.overrideWithValue(
            const GlobalDataDto(
              userId: 'viewer',
              refreshToken: 'test',
              cameras: [],
            ),
          ),
          groupMetadataProvider('group')
              .overrideWith((ref) => Stream.value(null)),
        ],
        child: MaterialApp(
          home: Scaffold(body: PopUpMenuFeed(pinDto: pin('mine', 'viewer'))),
        ),
      ),
    );
    await tester.tap(find.byType(PopupMenuButton<int>));
    await tester.pumpAndSettle();
    expect(find.text('Hide post'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    expect(find.text('Hide user'), findsNothing);
    expect(find.text('Report post'), findsNothing);
  });
}

class _Pins extends PinGroupServiceUnfiltered {
  @override
  Stream<List<PinEntity>> build(String groupId) => Stream.value([
    pin("artwork", "artist"),
    pin("second", "artist"),
    pin("third", "other"),
  ]);
}
