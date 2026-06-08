# Repozytorium tekstów — Nauka angielskiego

To repozytorium zawiera teksty pobierane przez aplikację „Nauka angielskiego”.
Musi być **publiczne** (aplikacja pobiera pliki bez logowania).

## Struktura

```
index.json            # katalog wszystkich tekstów
texts/<id>.json       # pojedyncze teksty (z tłumaczeniami słów i zdań)
AGENT_INSTRUCTIONS.md # instrukcja dla agenta AI tworzącego teksty
```

## Jak dodać nowy tekst

1. Wygeneruj plik `texts/<id>.json` zgodnie z `AGENT_INSTRUCTIONS.md`.
2. Policz sumę kontrolną:
   ```powershell
   (Get-FileHash -Algorithm SHA256 texts\<id>.json).Hash.ToLower()
   ```
3. Dopisz wpis do `index.json` (z policzonym `sha256`) i zaktualizuj `updatedAt`.
4. `git add . && git commit -m "Dodaj <id>" && git push`.

Aplikacja zobaczy nowy tekst po odświeżeniu katalogu (pociągnięcie listy w dół).

## Konfiguracja w aplikacji

W pliku `lib/core/config.dart` aplikacji ustaw:
- `textsOwner` — Twój login/organizacja GitHub,
- `textsRepo` — nazwę tego repozytorium,
- `textsBranch` — gałąź (domyślnie `main`).
