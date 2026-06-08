import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/providers.dart';

const _kOffsetPrefix = 'progress_offset_';
const _kFractionPrefix = 'progress_fraction_';

/// Reaktywny postęp czytania per tekst (id -> ułamek 0..1).
///
/// Stan to mapa ułamków, którą obserwują ekrany list — dzięki temu po zapisie
/// (np. po przewinięciu w czytniku) procent na liście odświeża się sam.
class ProgressController extends Notifier<Map<String, double>> {
  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  Map<String, double> build() {
    final map = <String, double>{};
    for (final key in _prefs.getKeys()) {
      if (key.startsWith(_kFractionPrefix)) {
        map[key.substring(_kFractionPrefix.length)] =
            _prefs.getDouble(key) ?? 0;
      }
    }
    return map;
  }

  double fraction(String textId) => state[textId] ?? 0;

  double scrollOffset(String textId) =>
      _prefs.getDouble('$_kOffsetPrefix$textId') ?? 0;

  /// Zapis pozycji przewijania. Procent rośnie monotonicznie (najdalsza
  /// osiągnięta pozycja) — cofnięcie w górę go nie zmniejsza.
  Future<void> saveScroll(
      String textId, double offset, double currentFraction) async {
    final cur = state[textId] ?? 0;
    final reached = currentFraction.clamp(0.0, 1.0);
    final next = reached > cur ? reached : cur;
    await _prefs.setDouble('$_kOffsetPrefix$textId', offset);
    await _prefs.setDouble('$_kFractionPrefix$textId', next);
    if (next != cur) state = {...state, textId: next};
  }

  /// Ręczne oznaczenie tekstu jako przeczytany (100%) / nieprzeczytany (0%).
  Future<void> setRead(String textId, bool read) async {
    final value = read ? 1.0 : 0.0;
    await _prefs.setDouble('$_kFractionPrefix$textId', value);
    state = {...state, textId: value};
  }
}

final progressProvider =
    NotifierProvider<ProgressController, Map<String, double>>(
        ProgressController.new);
