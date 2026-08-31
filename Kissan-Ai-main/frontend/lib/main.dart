import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/storage/local_storage.dart';
import 'core/theme/app_theme.dart' as theme;
import 'router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise Hive boxes before the app starts.
  await LocalStorage.instance.init();

  runApp(
    const ProviderScope(
      child: KisanAiApp(),
    ),
  );
}

class KisanAiApp extends ConsumerWidget {
  const KisanAiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Kisan AI',
      debugShowCheckedModeBanner: false,
      theme: theme.appTheme,
      routerConfig: router,
    );
  }
}
