/// Konfiguracja źródeł zdalnych. Uzupełnij wartości po utworzeniu repozytoriów
/// na GitHubie. Repozytorium tekstów musi być PUBLICZNE (pobieranie bez tokenu).
class AppConfig {
  /// Właściciel (konto/organizacja) repozytorium z tekstami.
  static const String textsOwner = 'grekot';

  /// Nazwa repozytorium z tekstami (zawiera index.json oraz katalog texts/).
  static const String textsRepo = 'english-reader-texts';

  /// Gałąź repozytorium tekstów.
  static const String textsBranch = 'main';

  /// Bazowy URL do plików surowych (raw) repozytorium tekstów.
  static String get rawBase =>
      'https://raw.githubusercontent.com/$textsOwner/$textsRepo/$textsBranch';

  static String get indexUrl => '$rawBase/index.json';

  static String textUrl(String relativePath) => '$rawBase/$relativePath';

  /// Repozytorium z wydaniami aplikacji (auto-aktualizacja).
  /// Może być to samo co repo kodu aplikacji.
  static const String appOwner = 'grekot';
  static const String appRepo = 'english-reader';

  static String get latestReleaseApiUrl =>
      'https://api.github.com/repos/$appOwner/$appRepo/releases/latest';

  static String get releasesPageUrl =>
      'https://github.com/$appOwner/$appRepo/releases/latest';
}
