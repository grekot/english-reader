/// Ustawienia aplikacji konfigurowane przez użytkownika.
class AppSettings {
  /// Tryb ciemny.
  final bool darkMode;

  /// Rozmiar czcionki tekstu czytanego.
  final double fontSize;

  /// Czas (w sekundach) po którym znika dymek z tłumaczeniem SŁOWA.
  final int bubbleSeconds;

  /// Czas (w sekundach) po którym znika dymek z tłumaczeniem ZDANIA
  /// (dłuższy, bo więcej tekstu do przeczytania).
  final int sentenceBubbleSeconds;

  /// Język/akcent używany przez syntezator mowy (TTS).
  final String ttsLanguage;

  /// Dzienny cel czytania w minutach.
  final int dailyGoalMinutes;

  /// Tempo lektora TTS (0.0–1.0; ~0.45 to naturalne tempo).
  final double ttsRate;

  const AppSettings({
    this.darkMode = false,
    this.fontSize = 18,
    this.bubbleSeconds = 2,
    this.sentenceBubbleSeconds = 4,
    this.ttsLanguage = 'en-US',
    this.dailyGoalMinutes = 10,
    this.ttsRate = 0.45,
  });

  AppSettings copyWith({
    bool? darkMode,
    double? fontSize,
    int? bubbleSeconds,
    int? sentenceBubbleSeconds,
    String? ttsLanguage,
    int? dailyGoalMinutes,
    double? ttsRate,
  }) {
    return AppSettings(
      darkMode: darkMode ?? this.darkMode,
      fontSize: fontSize ?? this.fontSize,
      bubbleSeconds: bubbleSeconds ?? this.bubbleSeconds,
      sentenceBubbleSeconds:
          sentenceBubbleSeconds ?? this.sentenceBubbleSeconds,
      ttsLanguage: ttsLanguage ?? this.ttsLanguage,
      dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
      ttsRate: ttsRate ?? this.ttsRate,
    );
  }

  Map<String, dynamic> toMap() => {
        'darkMode': darkMode,
        'fontSize': fontSize,
        'bubbleSeconds': bubbleSeconds,
        'sentenceBubbleSeconds': sentenceBubbleSeconds,
        'ttsLanguage': ttsLanguage,
        'dailyGoalMinutes': dailyGoalMinutes,
        'ttsRate': ttsRate,
      };

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      darkMode: map['darkMode'] as bool? ?? false,
      fontSize: (map['fontSize'] as num?)?.toDouble() ?? 18,
      bubbleSeconds: map['bubbleSeconds'] as int? ?? 2,
      sentenceBubbleSeconds: map['sentenceBubbleSeconds'] as int? ?? 4,
      ttsLanguage: map['ttsLanguage'] as String? ?? 'en-US',
      dailyGoalMinutes: map['dailyGoalMinutes'] as int? ?? 10,
      ttsRate: (map['ttsRate'] as num?)?.toDouble() ?? 0.45,
    );
  }
}
