import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/providers.dart';
import 'core/supabase_config.dart';
import 'services/log_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LogService.instance.init();

  // Przechwytywanie nieobsłużonych wyjątków do dziennika błędów.
  final priorOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    priorOnError?.call(details);
    LogService.instance.error('Flutter', details.exception, details.stack);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    LogService.instance.error('Uncaught', error, stack);
    return true;
  };

  final prefs = await SharedPreferences.getInstance();
  // Inicjalizacja Supabase (ranking rodzinny). Błąd nie blokuje aplikacji —
  // ranking po prostu nie zadziała, reszta działa offline.
  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
  } catch (e, s) {
    LogService.instance.error('Supabase init', e, s);
  }
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const App(),
    ),
  );
}
