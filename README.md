# Nauka angielskiego (Flutter — Android + Windows)

Aplikacja do nauki angielskiego przez czytanie. Użytkownik czyta angielski
tekst; **stuknięcie w słowo** pokazuje nad nim dymek z polskim tłumaczeniem
(znika po konfigurowalnym czasie), a **podwójne stuknięcie w zdanie** pokazuje
tłumaczenie całego zdania.

## Funkcje

- Czytnik z dymkami: słowo (pojedyncze stuknięcie) i zdanie (podwójne).
- Wymowa (TTS) słów i zdań — na Androidzie natywnie; na Windows w miarę
  dostępności głosów SAPI (jeśli brak, przycisk jest ukrywany).
- Zapis nieznanych słów do fiszek + prosty tryb powtórki.
- Postęp czytania i pasek procentu w katalogu.
- Ustawienia: tryb ciemny, rozmiar czcionki, czas znikania dymka, język TTS.
- Zdalne pobieranie tekstów z publicznego repo GitHub (offline-first z cache).
- Auto-aktualizacja aplikacji z GitHub Releases (Android: instalacja APK przez
  `ota_update`; Windows: pobranie ze strony wydania).

## Architektura

```
lib/
  main.dart, app.dart
  models/      text_document.dart, settings.dart, vocab_entry.dart
  core/        offset_mapper.dart, providers.dart, config.dart, theme.dart
  data/        text_repository.dart, settings_repository.dart,
               vocab_repository.dart, progress_repository.dart
  services/    github_service.dart, tts_service.dart, update_service.dart
  ui/library/  library_screen.dart
  ui/reader/   reader_screen.dart, tappable_text.dart, bubble.dart
  ui/vocab/    vocab_screen.dart
  ui/settings/ settings_screen.dart
  ui/update/   update_checker.dart
assets/sample/ alice-ch01.json   # tekst wbudowany (działa offline od 1. uruchomienia)
repo_template/                    # szablon publicznego repo z tekstami
```

Mechanika dymków: tekst `en` zdania jest renderowany 1:1; `TextPainter`
mapuje stuknięcie na pozycję znaku, a `offset_mapper.dart` na token/zdanie.
Pozycje słów są wyliczane przez kolejne dopasowanie `w` w `en` (patrz
`repo_template/AGENT_INSTRUCTIONS.md`).

## Format tekstów

Patrz `repo_template/AGENT_INSTRUCTIONS.md` (pełna specyfikacja JSON + zasady dla
agenta AI generującego teksty) oraz `assets/sample/alice-ch01.json` (wzorzec).

## Konfiguracja zdalna

W `lib/core/config.dart` ustaw:
- `textsOwner`, `textsRepo`, `textsBranch` — repozytorium z tekstami (publiczne),
- `appOwner`, `appRepo` — repozytorium z wydaniami aplikacji (auto-aktualizacja).

## Uruchomienie

```bash
flutter pub get
flutter run -d windows      # albo: flutter run -d android
flutter test                # testy jednostkowe (mapper offsetów)
flutter analyze
```

> Build na Windows wymaga `nuget.exe` na PATH (zależność pluginu `flutter_tts`).
> Pobierz z https://dist.nuget.org/win-x86-commandline/latest/nuget.exe i umieść
> w katalogu na PATH (np. w `flutter/bin`).
