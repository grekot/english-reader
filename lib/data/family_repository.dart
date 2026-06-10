import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/providers.dart';

const _kDeviceId = 'family_device_id';
const _kName = 'family_display_name';
const _kCode = 'family_code';

/// Tożsamość domownika w rankingu rodzinnym.
class FamilySettings {
  final String deviceId;
  final String displayName;
  final String familyCode;
  const FamilySettings({
    required this.deviceId,
    required this.displayName,
    required this.familyCode,
  });
}

/// Ustawienia uczestnictwa w rankingu (nazwa + kod rodziny), zapisane lokalnie.
class FamilyController extends Notifier<FamilySettings?> {
  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  FamilySettings? build() {
    final id = _ensureDeviceId();
    final name = _prefs.getString(_kName);
    final code = _prefs.getString(_kCode);
    if (name == null || name.isEmpty || code == null || code.isEmpty) {
      return null;
    }
    return FamilySettings(deviceId: id, displayName: name, familyCode: code);
  }

  String _ensureDeviceId() {
    var id = _prefs.getString(_kDeviceId);
    if (id == null || id.isEmpty) {
      final r = Random();
      const chars = '0123456789abcdef';
      id = List.generate(24, (_) => chars[r.nextInt(16)]).join();
      _prefs.setString(_kDeviceId, id);
    }
    return id;
  }

  Future<void> join(String name, String code) async {
    final id = _ensureDeviceId();
    final n = name.trim();
    final c = code.trim().toLowerCase();
    await _prefs.setString(_kName, n);
    await _prefs.setString(_kCode, c);
    state = FamilySettings(deviceId: id, displayName: n, familyCode: c);
  }

  Future<void> leave() async {
    await _prefs.remove(_kName);
    await _prefs.remove(_kCode);
    state = null;
  }
}

final familyControllerProvider =
    NotifierProvider<FamilyController, FamilySettings?>(FamilyController.new);

/// Wiersz rankingu (jeden domownik).
class ScoreRow {
  final String deviceId;
  final String displayName;
  final int xp;
  final int level;
  final int streak;
  final int readingMinutes;
  final int completed;
  final int lookups;
  final int quizCorrect;

  const ScoreRow({
    required this.deviceId,
    required this.displayName,
    required this.xp,
    required this.level,
    required this.streak,
    required this.readingMinutes,
    required this.completed,
    required this.lookups,
    required this.quizCorrect,
  });

  factory ScoreRow.fromMap(Map<String, dynamic> m) => ScoreRow(
        deviceId: m['device_id'] as String? ?? '',
        displayName: m['display_name'] as String? ?? '?',
        xp: (m['xp'] as num?)?.toInt() ?? 0,
        level: (m['level'] as num?)?.toInt() ?? 1,
        streak: (m['streak'] as num?)?.toInt() ?? 0,
        readingMinutes: (m['reading_minutes'] as num?)?.toInt() ?? 0,
        completed: (m['completed'] as num?)?.toInt() ?? 0,
        lookups: (m['lookups'] as num?)?.toInt() ?? 0,
        quizCorrect: (m['quiz_correct'] as num?)?.toInt() ?? 0,
      );
}

/// Operacje na tabeli `reading_scores` w Supabase.
class LeaderboardService {
  SupabaseClient get _client => Supabase.instance.client;

  /// Wysyła (upsert) aktualny wynik tego urządzenia.
  Future<void> uploadScore(
    FamilySettings f, {
    required int xp,
    required int level,
    required int streak,
    required int readingMinutes,
    required int completed,
    required int lookups,
    required int quizCorrect,
  }) async {
    await _client.from('reading_scores').upsert({
      'device_id': f.deviceId,
      'family_code': f.familyCode,
      'display_name': f.displayName,
      'xp': xp,
      'level': level,
      'streak': streak,
      'reading_minutes': readingMinutes,
      'completed': completed,
      'lookups': lookups,
      'quiz_correct': quizCorrect,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'device_id');
  }

  /// Usuwa wpis tego urządzenia z rankingu (po opuszczeniu grupy).
  Future<void> deleteScore(String deviceId) async {
    await _client.from('reading_scores').delete().eq('device_id', deviceId);
  }

  /// Pobiera ranking dla danego kodu rodziny (malejąco wg XP).
  Future<List<ScoreRow>> fetch(String familyCode) async {
    final rows = await _client
        .from('reading_scores')
        .select()
        .eq('family_code', familyCode)
        .order('xp', ascending: false);
    return (rows as List)
        .map((e) => ScoreRow.fromMap(e as Map<String, dynamic>))
        .toList();
  }
}

final leaderboardServiceProvider =
    Provider<LeaderboardService>((ref) => LeaderboardService());
