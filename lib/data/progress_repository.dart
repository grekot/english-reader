import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/providers.dart';

/// Zapamiętuje postęp czytania per tekst: ostatnia pozycja przewijania (px)
/// oraz przybliżony procent przeczytania (0–1).
class ProgressRepository {
  final SharedPreferences _prefs;
  ProgressRepository(this._prefs);

  String _offsetKey(String textId) => 'progress_offset_$textId';
  String _fractionKey(String textId) => 'progress_fraction_$textId';

  double scrollOffset(String textId) =>
      _prefs.getDouble(_offsetKey(textId)) ?? 0;

  double fraction(String textId) =>
      _prefs.getDouble(_fractionKey(textId)) ?? 0;

  Future<void> save(String textId, double offset, double fraction) async {
    await _prefs.setDouble(_offsetKey(textId), offset);
    await _prefs.setDouble(_fractionKey(textId), fraction.clamp(0, 1));
  }
}

final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  return ProgressRepository(ref.read(sharedPreferencesProvider));
});
