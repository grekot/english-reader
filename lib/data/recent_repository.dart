import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/providers.dart';

const _kRecentKey = 'recent_ids';
const _maxRecent = 30;

/// Lista ostatnio otwartych tekstów (id), najnowsze na początku.
class RecentController extends Notifier<List<String>> {
  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  List<String> build() {
    return _prefs.getStringList(_kRecentKey) ?? const [];
  }

  /// Oznacza tekst jako właśnie otwarty — przesuwa go na początek listy.
  Future<void> markOpened(String id) async {
    final next = <String>[id, ...state.where((e) => e != id)];
    if (next.length > _maxRecent) next.removeRange(_maxRecent, next.length);
    state = next;
    await _prefs.setStringList(_kRecentKey, next);
  }
}

final recentControllerProvider =
    NotifierProvider<RecentController, List<String>>(RecentController.new);
