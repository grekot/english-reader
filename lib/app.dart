import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'data/settings_repository.dart';
import 'services/tts_service.dart';
import 'ui/library/library_screen.dart';
import 'ui/update/update_checker.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Inicjalizacja TTS językiem z ustawień.
      final settings = ref.read(settingsControllerProvider);
      await ref.read(ttsServiceProvider).init(settings.ttsLanguage);

      // Automatyczne, ciche sprawdzenie aktualizacji.
      final ctx = _navKey.currentContext;
      if (ctx != null && ctx.mounted) {
        await checkForUpdateInteractive(ctx, ref, silent: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final darkMode = ref.watch(
      settingsControllerProvider.select((s) => s.darkMode),
    );

    return MaterialApp(
      navigatorKey: _navKey,
      title: 'Nauka angielskiego',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
      home: const LibraryScreen(),
    );
  }
}
