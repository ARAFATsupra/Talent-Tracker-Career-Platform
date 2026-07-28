import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app/app_theme.dart';
import 'app/app_router.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔶 Requires `flutterfire configure` to have been run (see
  // PHASE2_GUIDE.md, Step 1) — otherwise this throws an API-key error.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 🔶 Phase 4: await Hive.initFlutter(); for offline cache (NFR-14, FR-47)

  runApp(const ProviderScope(child: TalentTrackerApp()));
}

class TalentTrackerApp extends ConsumerWidget {
  const TalentTrackerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: 'Talent Tracker AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
