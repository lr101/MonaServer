import 'package:buff_lisa/app/lifecycle/app_link_lifecycle.dart';
import 'package:buff_lisa/app/lifecycle/sync_lifecycle.dart';
import 'package:buff_lisa/app/play_store_update_guard.dart';
import 'package:buff_lisa/app/routing/app_router.dart';
import 'package:buff_lisa/util/theme/data/material_theme.dart';
import 'package:buff_lisa/util/theme/service/theme_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
    );
    final theme = MaterialTheme(Theme.of(context).textTheme);
    final router = ref.watch(routerProvider);
    return AppLinkLifecycle(
      child: AppSyncLifecycle(
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          title: 'Mona App',
          themeMode: ref.watch(themeStateProvider),
          darkTheme: theme.dark(),
          theme: theme.light(),
          routerConfig: router,
          builder: (context, child) {
            final appContent = !kIsWeb
                ? child!
                : ColoredBox(
                    color: Colors
                        .black, // Background color for web outside the app
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 450),
                        child: child,
                      ),
                    ),
                  );
            return PlayStoreUpdateGuard(child: appContent);
          },
        ),
      ),
    );
  }
}
