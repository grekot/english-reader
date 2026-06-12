# CLAUDE.md — Nauka angielskiego (Flutter, Android + Windows)

> **Najpierw przeczytaj [`SESSION_REPORT.md`](SESSION_REPORT.md)** — pełny stan
> projektu: architektura, funkcje, Supabase, CI, wydania i pułapki.

Aplikacja do nauki angielskiego przez czytanie (stuknij słowo → tłumaczenie).

## Repozytoria
- App: `grekot/english-reader` (to repo, `C:\TMP\Android\Nauka angielskiego`).
- Teksty: `grekot/english-reader-texts` (`C:\TMP\Android\english-reader-texts`), publiczne.

## Krytyczne zasady / pułapki
- **APK buduj TYLKO przez GitHub Actions** (tag `v*`). Lokalny `flutter build apk`
  zawodzi tu na „Unable to establish loopback connection" (firewall). Windows
  build lokalnie działa: `flutter build windows --debug`.
- Wydanie = `git push origin main` + `git tag vX.Y.Z; git push origin vX.Y.Z`
  (workflow `.github/workflows/release.yml` zbuduje podpisany APK + Windows ZIP).
- Najnowsze WYDANE: **v1.1.3**; `main` bywa do przodu (kolejne → v1.1.4+).
- flutter_tts (Windows) wymaga `nuget.exe` na PATH (jest w `flutter/bin`).
- ota_update wymaga FileProvider w `AndroidManifest.xml` + core library desugaring.
- Zależności przypięte ze względu na `win32`: `package_info_plus ">=8.0.2 <10.0.0"`,
  `file_picker ^11`, `supabase_flutter 2.9.0`. Nie podnoś bez sprawdzenia konfliktu.
- Ranking = **Supabase współdzielony z aplikacją „Kalendazyk"** (config w
  `lib/core/supabase_config.dart`, tabela `reading_scores`, SQL w `DEPLOYMENT.md`).
- Keystore (`android/app/upload-keystore.jks`, gitignored) — nie commitować, jest kopia lokalna.

## Workflow pracy
- Po zmianach: `flutter analyze` (czysto) → commit → push. Build Windows do testu UI.
- Commit message kończ stopką: `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.
- Dodawanie tekstów: `python tools/add_text.py texts/<id>.json --category "X"` w repo tekstów (lub tryb „Zarządzanie" na Windows), potem commit+push tam.

## Sprawy otwarte
- Supabase: dodać politykę `delete` na `reading_scores` i usunąć testowy wiersz.
- `main` ma niewydaną poprawkę (ostrzeżenie o nieudanym usunięciu wpisu z rankingu).
