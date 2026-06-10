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

## 3. Ranking rodzinny (Supabase)

Ranking korzysta z tego samego projektu Supabase co aplikacja „Kalendazyk"
(URL i anon key w `lib/core/supabase_config.dart`). Wystarczy **jednorazowo
utworzyć tabelę** i politykę dostępu.

W Supabase → **SQL Editor** uruchom:

```sql
create table if not exists public.reading_scores (
  device_id       text primary key,
  family_code     text not null,
  display_name    text not null,
  xp              int  not null default 0,
  level           int  not null default 1,
  streak          int  not null default 0,
  reading_minutes int  not null default 0,
  completed       int  not null default 0,
  lookups         int  not null default 0,
  quiz_correct    int  not null default 0,
  updated_at      timestamptz not null default now()
);

create index if not exists reading_scores_family_idx
  on public.reading_scores (family_code);

alter table public.reading_scores enable row level security;

-- Aplikacja działa bez logowania (rola anon). Tabela zawiera tylko nazwy i
-- punkty, więc dostęp dla anon jest akceptowalny dla użytku rodzinnego.
create policy "anon read"  on public.reading_scores for select to anon using (true);
create policy "anon write" on public.reading_scores for insert to anon with check (true);
create policy "anon update" on public.reading_scores for update to anon using (true) with check (true);
create policy "anon delete" on public.reading_scores for delete to anon using (true);
```

> Jeśli utworzyłeś tabelę wcześniej (bez polityki delete), dodaj samą politykę:
> ```sql
> create policy "anon delete" on public.reading_scores for delete to anon using (true);
> ```
> Bez niej przycisk „Opuść ranking" wyczyści dane lokalnie, ale wpis w chmurze zostanie.

### Jak działa
- Każde urządzenie ma lokalny identyfikator + **nazwę** i **kod rodziny**
  (wpisywane raz w ekranie „Ranking rodzinny").
- Aplikacja wysyła (upsert) wynik tego urządzenia i pobiera wszystkie wiersze
  z tym samym `family_code`, sortując malejąco wg `xp`.
- Domownicy wpisują ten sam kod rodziny → widzą wspólny ranking.

> Uwaga prywatność: anon key jest publiczny, a polityki pozwalają na odczyt/zapis
> bez logowania. To wystarcza dla rodzinnego użytku (tylko nazwy + punkty).
> Jeśli chcesz większej kontroli — można dodać logowanie (jak w „Kalendazyku")
> i zawęzić polityki RLS.

---

## Lista kontrolna pierwszego uruchomienia

- [ ] `git push` repo tekstów (`english-reader-texts`) i aplikacji (`english-reader`).
- [ ] Dodaj 4 sekrety Android w repo aplikacji (2.2).
- [ ] Zrób kopię zapasową `upload-keystore.jks` + haseł.
- [ ] Utwórz tabelę `reading_scores` w Supabase (sekcja 3).
- [ ] `git tag v1.0.0 && git push origin v1.0.0` → sprawdź, czy workflow zbudował Release.
- [ ] Zainstaluj APK na telefonie, potem opublikuj kolejną wersję i sprawdź auto-aktualizację.
