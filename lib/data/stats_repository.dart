import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/providers.dart';

const _kDailySecondsKey = 'stats_daily_seconds';

String _dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Statystyki czytania: czas dzienny (sekundy) i seria dni (streak).
class StatsController extends Notifier<Map<String, int>> {
  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  Map<String, int> build() {
    final raw = _prefs.getString(_kDailySecondsKey);
    if (raw == null) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  /// Dodaje czas czytania do dzisiejszego dnia.
  Future<void> addReadingTime(Duration d) async {
    if (d.inSeconds <= 0) return;
    final key = _dayKey(DateTime.now());
    final next = {...state, key: (state[key] ?? 0) + d.inSeconds};
    state = next;
    await _prefs.setString(_kDailySecondsKey, jsonEncode(next));
  }

  int get todaySeconds => state[_dayKey(DateTime.now())] ?? 0;

  int get totalSeconds => state.values.fold(0, (a, b) => a + b);

  int get activeDays => state.values.where((s) => s > 0).length;

  /// Liczba kolejnych dni z aktywnością, licząc do dziś (dziś może być jeszcze
  /// bez aktywności — wtedy liczymy serię do wczoraj).
  int get streak {
    final active = state.entries
        .where((e) => e.value > 0)
        .map((e) => e.key)
        .toSet();
    var day = DateTime.now();
    if (!active.contains(_dayKey(day))) {
      day = day.subtract(const Duration(days: 1));
    }
    var count = 0;
    while (active.contains(_dayKey(day))) {
      count++;
      day = day.subtract(const Duration(days: 1));
    }
    return count;
  }
}

final statsControllerProvider =
    NotifierProvider<StatsController, Map<String, int>>(StatsController.new);
