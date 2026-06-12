# Raport projektu „Nauka angielskiego" — stan na 2026-06-12

Aplikacja Flutter do nauki angielskiego przez czytanie (Android + Windows).
Ten dokument podsumowuje architekturę, decyzje, wydania i sprawy otwarte — do
wznowienia pracy bez historii konwersacji.

## Repozytoria
- **Aplikacja:** https://github.com/grekot/english-reader (publiczne)
  - lokalnie: `C:\TMP\Android\Nauka angielskiego`
- **Teksty:** https://github.com/grekot/english-reader-texts (publiczne)
  - lokalnie: `C:\TMP\Android\english-reader-texts`
- Login GitHub: `grekot`. Bundle id: `pl.novitus.nauka_angielskiego`.
- Push: git działa, ostrzeżenie `credential-manager-core` jest nieszkodliwe.

## Główny mechanizm
- Tekst `en` zdania renderowany 1:1; stuknięcie → `TextPainter` mapuje pozycję
  znaku na token/zdanie (`lib/core/offset_mapper.dart`, fn `findWordOccurrence`).
- Format tekstu: JSON `paragraphs → sentences{en, pl, tokens[{w,t,lemma}]}` +
  opcjonalne `questions` (pytania zrozumienia). `index.json` = katalog z
  `category`, `sha256`. Specyfikacja: `repo_template/AGENT_INSTRUCTIONS.md`.
- Pojedyncze stuknięcie = słowo (`t`+`lemma`), podwójne = zdanie (`pl`).

## Funkcje (zaimplementowane)
- Czytnik: dymki słowo/zdanie, konfig. czasy (osobny dłuższy dla zdania),
  klik zamyka dymek; TTS (flutter_tts); tryb dwujęzyczny; czytanie na głos
  z podświetlaniem słowa; tytuł w osobnym wierszu pod ikonami.
- Biblioteka: kategorie + przypięte „Ostatnio używane" i „Ulubione"; import
  pliku JSON z dysku (file_picker); odświeżanie katalogu.
- Postęp: monotoniczny (max przewinięcie) + interakcje (klik słowa podnosi % do
  głębokości zdania) + ręczny ✓ „przeczytane". Krótkie teksty NIE auto-100%.
- Fiszki (vocab) + glosariusz tekstu (sprawdzone słowa) + quizy:
  słówka EN↔PL (auto z tokenów) oraz „Pytania do tekstu" (z `questions` w JSON,
  a gdy brak — auto z par zdań EN→PL).
- Statystyki/grywalizacja: XP, poziom, odznaki **wielopoziomowe**
  (brąz/srebro/złoto, klik = dialog z opisem i postępem), dzienny cel, streak,
  czas czytania.
- Ranking rodzinny (Supabase) — patrz niżej.
- Tryb „Zarządzanie tekstami" (TYLKO Windows): lista+walidacja, edycja
  metadanych/kategorii, dodawanie plików do index.json, przeliczanie sha256,
  oraz **commit+push do git z poziomu apki**.
- Ustawienia: tryb ciemny, rozmiar czcionki, czasy dymków, tempo TTS, język TTS,
  dzienny cel, „Sprawdź aktualizacje", „O aplikacji".
- „O aplikacji" + **Dziennik błędów** (przechwytywanie wyjątków:
  `lib/services/log_service.dart`, hooki w `main.dart`).
- Auto-aktualizacja z GitHub Releases (Android OTA przez ota_update; Windows =
  otwarcie strony Release).

## Backend rankingu — Supabase
- **Współdzielony projekt** z aplikacją „Kalendazyk" (`C:\TMP\Android\Kalendazyk`,
  używa supabase, nie Firebase!). Config: `lib/core/supabase_config.dart`
  (url `tkvxeozttwxxfpvmvvwp`, anon key publiczny).
- Tabela `reading_scores` (osobna), bez logowania — identyfikacja przez lokalny
  `device_id` + `display_name` + `family_code`. Ten sam kod = wspólny ranking.
- **SQL tabeli + polityki RLS w `DEPLOYMENT.md` sekcja 3** (select/insert/update
  ORAZ **delete**).
- ⚠️ SPRAWA OTWARTA: w realnym projekcie Supabase trzeba było ręcznie dodać
  politykę `delete` i usunąć testowy wiersz — bez polityki delete „Opuść ranking"
  nie usuwa wpisu z chmury (RLS po cichu blokuje). Polecenie:
  `create policy "anon delete" on public.reading_scores for delete to anon using (true);`

## CI/CD i podpisywanie (KRYTYCZNE)
- Workflow `.github/workflows/release.yml` — trigger na tag `v*`: buduje
  podpisany APK + Windows ZIP i tworzy Release.
- Podpisywanie Android: `android/app/build.gradle.kts` czyta `android/key.properties`.
  Keystore: `android/app/upload-keystore.jks` (+ `key.properties`,
  `keystore_base64.txt`) — **gitignored, istnieją tylko lokalnie. TRZEBA ZROBIĆ
  KOPIĘ ZAPASOWĄ** — utrata = brak możliwości aktualizacji OTA (inny podpis).
- Sekrety CI w repo aplikacji: `ANDROID_KEYSTORE_BASE64`, `ANDROID_STORE_PASSWORD`,
  `ANDROID_KEY_PASSWORD`, `ANDROID_KEY_ALIAS` (=`upload`).

## Wydania
- Wydane tagi do **v1.1.3** (najnowsze wydane). `main` jest o kilka commitów
  do przodu (m.in. ostrzeżenie o nieudanym usunięciu wpisu z rankingu) —
  do wydania jako **v1.1.4** przy większej paczce.
- Build-name z tagu, build-number = numer runu workflow (rośnie).

## Pułapki / wiedza nieoczywista
- **flutter_tts na Windows wymaga `nuget.exe` na PATH** (pobrany do `flutter/bin`).
- **ota_update wymaga**: `FileProvider` w `AndroidManifest.xml` (authority
  `${applicationId}.ota_update_provider`, `res/xml/ota_update_filepaths.xml`) +
  **core library desugaring** w build.gradle.kts. Brak providera = CRASH przy
  instalacji.
- **OTA naprawione**: rozwijanie przekierowania GitHub do bezpośredniego URL
  (`UpdateService.resolveDownloadUrl`) + unikalna nazwa APK per wersja. Bez tego
  na części urządzeń instalacja wisiała/instalowała starą wersję.
- Po naprawie OTA: na zepsutych urządzeniach trzeba **raz zainstalować APK
  ręcznie** (poprawka jest w nowej wersji, nie w zainstalowanej).
- **Konflikt zależności win32**: `package_info_plus` przypięty `">=8.0.2 <10.0.0"`
  (win32 ^5), by współistniał z `file_picker ^11` i `supabase_flutter 2.9.0`.
  Aktualnie: file_picker 11.0.2, package_info_plus 9.x, win32 5.15.
- **file_picker 11 API statyczne**: `FilePicker.pickFiles/getDirectoryPath`
  (bez `.platform`), parametr `lockParentWindow: true` (okno na wierzchu Windows).
- **Lokalny build APK na maszynie dewelopera ZAWODZI** z błędem Gradle
  „Unable to establish loopback connection" (firewall/AV blokuje loopback Javy).
  APK budować przez **GitHub Actions**. Windows build lokalnie działa.
- Czas czytania liczony przez Stopwatch w czytniku + **cykliczny zapis co 20 s**
  (zapamiętana referencja `StatsController` w initState — `ref` w `dispose`
  w Riverpod bywa zawodne). Wcześniej pokazywało stale 0.

## Dodawanie tekstów
- Agent AI generuje `texts/<id>.json` wg `AGENT_INSTRUCTIONS.md` (tłumacz KAŻDE
  słowo; przedimki opisowo „(przedimek określony)"; opcjonalne `questions`).
- `python tools/add_text.py texts/<id>.json --category "X"` (lub tryb
  interaktywny / `-y`) → dopisuje do index + liczy sha256.
- `python tools/reindex.py` → przelicza sha256 po ręcznej edycji.
- `.gitattributes` wymusza LF (spójność sha256 z tym, co liczy aplikacja).
- Albo tryb „Zarządzanie tekstami" w aplikacji (Windows).

## Konfiguracja środowiska
- Flutter 3.41.9, Dart 3.11.5. Windows 11. Python 3.10 (Pillow) do ikony
  (`tool/make_icon.py`).
