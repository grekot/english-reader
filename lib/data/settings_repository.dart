import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/providers.dart';
import '../models/settings.dart';

const _kSettingsKey = 'app_settings';

/// Kontroler ustawień: ładuje z SharedPreferences i zapisuje zmiany.
class SettingsController extends Notifier<AppSettings> {
  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  AppSettings build() {
    final raw = _prefs.getString(_kSettingsKey);
    if (raw == null) return const AppSettings();
    try {
      return AppSettings.fromMap(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> _persist(AppSettings settings) async {
    state = settings;
    await _prefs.setString(_kSettingsKey, jsonEncode(settings.toMap()));
  }

  Future<void> setDarkMode(bool value) =>
      _persist(state.copyWith(darkMode: value));

  Future<void> setFontSize(double value) =>
      _persist(state.copyWith(fontSize: value));

  Future<void> setBubbleSeconds(int value) =>
      _persist(state.copyWith(bubbleSeconds: value));

  Future<void> setSentenceBubbleSeconds(int value) =>
      _persist(state.copyWith(sentenceBubbleSeconds: value));

  Future<void> setTtsLanguage(String value) =>
      _persist(state.copyWith(ttsLanguage: value));
}

final settingsControllerProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);
