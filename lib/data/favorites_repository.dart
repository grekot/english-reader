import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/providers.dart';

const _kFavoritesKey = 'favorite_ids';

/// Zbiór identyfikatorów tekstów oznaczonych jako ulubione.
class FavoritesController extends Notifier<Set<String>> {
  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  Set<String> build() {
    return (_prefs.getStringList(_kFavoritesKey) ?? const []).toSet();
  }

  bool isFavorite(String id) => state.contains(id);

  Future<void> toggle(String id) async {
    final next = Set<String>.from(state);
    if (!next.add(id)) next.remove(id);
    state = next;
    await _prefs.setStringList(_kFavoritesKey, next.toList());
  }
}

final favoritesControllerProvider =
    NotifierProvider<FavoritesController, Set<String>>(FavoritesController.new);
