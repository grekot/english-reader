import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider instancji SharedPreferences.
///
/// Nadpisywany w `main()` po asynchronicznej inicjalizacji, dzięki czemu
/// reszta aplikacji może odczytywać preferencje synchronicznie.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider musi zostać nadpisany w main()',
  );
});
