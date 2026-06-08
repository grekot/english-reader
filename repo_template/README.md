# Repozytorium tekstów — Nauka angielskiego

To repozytorium zawiera teksty pobierane przez aplikację „Nauka angielskiego”.
Musi być **publiczne** (aplikacja pobiera pliki bez logowania).

## Struktura

```
index.json            # katalog wszystkich tekstów (kategorie, sha256)
texts/<id>.json       # pojedyncze teksty (z tłumaczeniami słów i zdań)
AGENT_INSTRUCTIONS.md # instrukcja dla agenta AI tworzącego teksty
tools/add_text.py     # dodaje/aktualizuje wpis w index.json + liczy sha256
tools/reindex.py      # przelicza sha256 wszystkich tekstów
```

## Jak dodać nowy tekst

1. Wygeneruj plik `texts/<id>.json` zgodnie z `AGENT_INSTRUCTIONS.md`.
2. Dodaj go do katalogu jednym poleceniem (metadane bierze z pliku, liczy sha256):
   ```powershell
   python tools\add_text.py texts\<id>.json --category "Lektury"
   ```
   - `--category` ustawia kategorię w bibliotece (np. „Lektury", „Wiadomości").
     Pominięte = kategoria z pliku tekstu, inaczej „Ogólne".
   - Skrypt aktualizuje istniejący wpis (po `id`) albo dodaje nowy.
3. `git add . && git commit -m "Dodaj <id>" && git push`.

> Po RĘCZNEJ edycji już dodanego tekstu wystarczy `python tools\reindex.py`,
> aby przeliczyć `sha256` (inaczej aplikacja pokaże starą wersję z cache).

Aplikacja zobaczy zmiany po odświeżeniu katalogu (przycisk „Odśwież" / restart).

## Konfiguracja w aplikacji

W pliku `lib/core/config.dart` aplikacji ustaw:
- `textsOwner` — Twój login/organizacja GitHub,
- `textsRepo` — nazwę tego repozytorium,
- `textsBranch` — gałąź (domyślnie `main`).
