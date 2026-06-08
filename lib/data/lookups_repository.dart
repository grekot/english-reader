import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/providers.dart';

const _kLookupsKey = 'lookups';

/// Sprawdzone słowo (do glosariusza i quizów).
class LookupWord {
  final String w;
  final String? t;
  final String? lemma;
  const LookupWord({required this.w, this.t, this.lemma});

  Map<String, dynamic> toJson() => {
        'w': w,
        if (t != null) 't': t,
        if (lemma != null) 'lemma': lemma,
      };
  factory LookupWord.fromJson(Map<String, dynamic> j) => LookupWord(
        w: j['w'] as String,
        t: j['t'] as String?,
        lemma: j['lemma'] as String?,
      );
}

/// Słowa sprawdzone (stuknięte) przez użytkownika, pogrupowane per tekst.
class LookupsController extends Notifier<Map<String, List<LookupWord>>> {
  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  Map<String, List<LookupWord>> build() {
    final raw = _prefs.getString(_kLookupsKey);
    if (raw == null) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(
            k,
            (v as List<dynamic>)
                .map((e) => LookupWord.fromJson(e as Map<String, dynamic>))
                .toList(),
          ));
    } catch (_) {
      return {};
    }
  }

  List<LookupWord> wordsFor(String textId) => state[textId] ?? const [];

  /// Łączna liczba unikalnych sprawdzonych słów (do statystyk).
  int get totalCount =>
      state.values.fold(0, (sum, list) => sum + list.length);

  Future<void> record(String textId, String w, String? t, String? lemma) async {
    if (t == null || t.isEmpty || t.startsWith('(')) return; // pomiń bez sensu
    final list = List<LookupWord>.from(state[textId] ?? const []);
    if (list.any((e) => e.w.toLowerCase() == w.toLowerCase())) return;
    list.add(LookupWord(w: w, t: t, lemma: lemma));
    final next = {...state, textId: list};
    state = next;
    await _persist(next);
  }

  Future<void> _persist(Map<String, List<LookupWord>> map) async {
    final data =
        map.map((k, v) => MapEntry(k, v.map((e) => e.toJson()).toList()));
    await _prefs.setString(_kLookupsKey, jsonEncode(data));
  }
}

final lookupsControllerProvider =
    NotifierProvider<LookupsController, Map<String, List<LookupWord>>>(
        LookupsController.new);
