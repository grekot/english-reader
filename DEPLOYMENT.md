# Wdrożenie i zdalna aktualizacja

Dokument opisuje, co skonfigurować, aby działały **dwie** ścieżki aktualizacji:
1. **Aktualizacja tekstów** — przez repozytorium `grekot/english-reader-texts`.
2. **Aktualizacja aplikacji** — przez wydania (Releases) w `grekot/english-reader`
   (Android: instalacja APK przez `ota_update`).

---

## 1. Aktualizacja tekstów (gotowe)

- Aplikacja pobiera `index.json` z repo tekstów przy każdym odświeżeniu katalogu
  (pociągnięcie listy w dół) i porównuje `sha256` każdego tekstu.
- Po edycji dowolnego tekstu **zaktualizuj jego `sha256` w `index.json`** —
  aplikacja wykryje zmianę i pobierze nową wersję (inaczej użyje wersji z cache).
- Szczegóły formatu i procesu: `repo_template/AGENT_INSTRUCTIONS.md`.

---

## 2. Aktualizacja aplikacji (Releases + podpisywanie)

### 2.1. Klucz podpisywania (KRYTYCZNE — zrób kopię zapasowej!)

Wygenerowano trwały keystore do podpisywania wydań Androida:

- `android/app/upload-keystore.jks` — klucz (NIE w gicie),
- `android/key.properties` — ścieżka + hasła (NIE w gicie),
- `android/keystore_base64.txt` — keystore w base64 do wklejenia w sekret CI (NIE w gicie).

> ⚠️ **Zrób kopię zapasową `upload-keystore.jks` i haseł z `key.properties` w
> bezpiecznym miejscu.** Aktualizacja „po wierzchu" na Androidzie zadziała tylko,
> gdy KOLEJNE wersje są podpisane TYM SAMYM kluczem. Utrata klucza = brak
> możliwości aktualizacji już zainstalowanej aplikacji (konieczna reinstalacja).

Lokalny build podpisany kluczem release:
```powershell
flutter build apk --release
```
(`build.gradle.kts` używa klucza z `key.properties`, a gdy go nie ma — klucza debug.)

### 2.2. Sekrety w repozytorium aplikacji

W `github.com/grekot/english-reader` → **Settings → Secrets and variables →
Actions → New repository secret** dodaj 4 sekrety:

| Nazwa sekretu | Wartość (skąd wziąć) |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | cała zawartość pliku `android/keystore_base64.txt` |
| `ANDROID_STORE_PASSWORD` | `storePassword` z `android/key.properties` |
| `ANDROID_KEY_PASSWORD` | `keyPassword` z `android/key.properties` |
| `ANDROID_KEY_ALIAS` | `keyAlias` z `android/key.properties` (czyli `upload`) |

### 2.3. Publikacja wydania

Workflow `.github/workflows/release.yml` uruchamia się po wypchnięciu tagu:

```powershell
git tag v1.0.1
git push origin v1.0.1
```

Co zrobi automatycznie:
1. zbuduje **podpisany APK** (Android) z `build-name` = wersja z tagu,
2. zbuduje i spakuje **aplikację Windows** (`*-windows.zip`),
3. utworzy **Release** `v1.0.1` i dołączy oba pliki.

### 2.4. Jak aplikacja wykrywa aktualizację

- Na starcie (cicho) oraz po kliknięciu „Sprawdź aktualizacje" aplikacja pobiera
  `releases/latest` z GitHub API i porównuje wersję z bieżącą (`package_info_plus`).
- **Android:** jeśli jest nowsza i Release ma plik `.apk`, pobiera go i uruchamia
  instalację (`ota_update`). Użytkownik musi zezwolić na „instaluj z nieznanych
  źródeł".
- **Windows:** otwiera stronę wydania do ręcznego pobrania ZIP-a.

> Wersja w `pubspec.yaml` (`version: 1.0.0+1`) to wartość bazowa. W wydaniach
> nadpisuje ją `--build-name` z tagu, więc podbijaj numer tagu przy każdym wydaniu
> (`v1.0.1`, `v1.0.2`, …).

---

## Lista kontrolna pierwszego uruchomienia

- [ ] `git push` repo tekstów (`english-reader-texts`) i aplikacji (`english-reader`).
- [ ] Dodaj 4 sekrety Android w repo aplikacji (2.2).
- [ ] Zrób kopię zapasową `upload-keystore.jks` + haseł.
- [ ] `git tag v1.0.0 && git push origin v1.0.0` → sprawdź, czy workflow zbudował Release.
- [ ] Zainstaluj APK na telefonie, potem opublikuj `v1.0.1` i sprawdź auto-aktualizację.
