/// Ustawienia aplikacji konfigurowane przez użytkownika.
class AppSettings {
  /// Tryb ciemny.
  final bool darkMode;

  /// Rozmiar czcionki tekstu czytanego.
  final double fontSize;

  /// Czas (w sekundach) po którym znika dymek z tłumaczeniem.
  final int bubbleSeconds;

  /// Język/akcent używany przez syntezator mowy (TTS).
  final String ttsLanguage;

  const AppSettings({
    this.darkMode = false,
    this.fontSize = 18,
    this.bubbleSeconds = 2,
    this.ttsLanguage = 'en-US',
  });

  AppSettings copyWith({
    bool? darkMode,
    double? fontSize,
    int? bubbleSeconds,
    String? ttsLanguage,
  }) {
    return AppSettings(
      darkMode: darkMode ?? this.darkMode,
      fontSize: fontSize ?? this.fontSize,
      bubbleSeconds: bubbleSeconds ?? this.bubbleSeconds,
      ttsLanguage: ttsLanguage ?? this.ttsLanguage,
    );
  }

  Map<String, dynamic> toMap() => {
        'darkMode': darkMode,
        'fontSize': fontSize,
        'bubbleSeconds': bubbleSeconds,
        'ttsLanguage': ttsLanguage,
      };

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      darkMode: map['darkMode'] as bool? ?? false,
      fontSize: (map['fontSize'] as num?)?.toDouble() ?? 18,
      bubbleSeconds: map['bubbleSeconds'] as int? ?? 2,
      ttsLanguage: map['ttsLanguage'] as String? ?? 'en-US',
    );
  }
}
