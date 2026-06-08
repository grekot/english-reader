# Instrukcja dla agenta AI — przygotowanie tekstów do aplikacji „Nauka angielskiego”

Jesteś agentem, który zamienia angielski tekst (książkę, rozdział, artykuł) na
plik JSON dla aplikacji do nauki angielskiego przez czytanie. W aplikacji
użytkownik czyta tekst, stuka w słowo (dymek z tłumaczeniem) lub dwukrotnie
w zdanie (tłumaczenie całego zdania). Twój plik dostarcza te tłumaczenia.

## Twoje wejście i wyjście

- **Wejście:** surowy tekst po angielsku (oraz opcjonalnie metadane: tytuł,
  autor, poziom).
- **Wyjście:**
  1. plik `texts/<id>.json` zgodny ze schematem poniżej,
  2. zaktualizowany `index.json` (dopisany wpis o nowym tekście),
  3. commit + push do repozytorium (repo jest **publiczne**).

---

## Schemat pliku tekstu `texts/<id>.json`

```json
{
  "schemaVersion": 1,
  "id": "kebab-case-unikalne",
  "title": "Tytuł widoczny w aplikacji",
  "author": "Autor (opcjonalnie)",
  "source": "Źródło / informacja o prawach (opcjonalnie)",
  "level": "B1",
  "tags": ["fiction"],
  "createdAt": "RRRR-MM-DD",
  "paragraphs": [
    {
      "sentences": [
        {
          "en": "Zdanie po angielsku 1:1 (z interpunkcją).",
          "pl": "Naturalne tłumaczenie CAŁEGO zdania.",
          "tokens": [
            { "w": "słowo", "t": "tłumaczenie kontekstowe", "lemma": "forma_podstawowa" }
          ]
        }
      ]
    }
  ]
}
```

### Pola nagłówka
| Pole | Wymagane | Opis |
|------|----------|------|
| `schemaVersion` | tak | Zawsze `1`. |
| `id` | tak | Unikalne, kebab-case, np. `alice-ch01`, `bbc-news-2026-06-08`. Musi zgadzać się z nazwą pliku. |
| `title` | tak | Tytuł widoczny w katalogu. |
| `author` | nie | Autor. |
| `source` | nie | Skąd tekst + status praw autorskich. |
| `level` | nie | Poziom CEFR: `A1`–`C2`. |
| `tags` | nie | Lista etykiet, np. `["fiction","classic"]`. |
| `createdAt` | nie | Data utworzenia `RRRR-MM-DD`. |

### Pola zdania
- `en` — **oryginał wyświetlany 1:1** (zachowaj interpunkcję, cudzysłowy, wielkość liter).
- `pl` — naturalne, poprawne tłumaczenie całego zdania (do podwójnego stuknięcia).
- `tokens` — uporządkowana lista słów do stuknięcia.

### Pola tokenu
- `w` (wymagane) — słowo dokładnie tak, jak występuje w `en`.
- `t` (wymagane) — polskie tłumaczenie **dopasowane do kontekstu** tego zdania
  (dla każdego słowa, także funkcyjnego — patrz zasada 6).
- `lemma` (wymagane dla słów odmiennych) — angielska **forma podstawowa**.

---

## ⭐ Najważniejsza zasada (od niej zależy poprawność aplikacji)

> **Pole `en` jest źródłem prawdy do wyświetlenia. Lista `tokens` zawiera słowa
> w DOKŁADNIE TEJ SAMEJ KOLEJNOŚCI, w jakiej występują w `en`, a każde `w` jest
> dokładnym fragmentem `en`.**

Aplikacja sama wylicza pozycje słów, dopasowując kolejno każde `w` w tekście `en`
(szuka następnego wystąpienia od miejsca poprzedniego dopasowania). Dlatego:
- **nie podajesz żadnych offsetów ani indeksów** — tylko kolejność,
- powtórzone słowa (np. dwa razy „it”) mapują się poprawnie dzięki kolejności,
- jeśli pominiesz słowo w `tokens`, będzie ono po prostu nieklikalne (to dozwolone).

---

## Zasady tokenizacji

1. **Podział na akapity i zdania** zgodnie z oryginałem. Jeden akapit = jeden
   wpis w `paragraphs`; jedno zdanie = jeden wpis w `sentences`.
2. **Kolejność i dosłowność:** tokeny w kolejności występowania; `w` = dokładny
   fragment `en` (z zachowaniem wielkości liter, np. `Alice`, `And`).
3. **Skróty i formy łączone = jeden token:** `don't`, `I'm`, `it's`, `Alice's`,
   `well-known`, `mother-in-law`. NIE rozdzielaj na części.
4. **Interpunkcja:** NIE twórz tokenów dla samych znaków (`. , ! ? ; : " ' ( )
   — …`). W aplikacji są automatycznie nieklikalne. Token to wyłącznie słowo.
5. **Słowa znaczące** (rzeczowniki, czasowniki, przymiotniki, przysłówki, ważne
   zaimki) — podaj `t` (kontekstowo) ORAZ `lemma`:
   - czasownik → bezokolicznik: `went` → lemma `go`, `was` → lemma `be`,
   - rzeczownik → liczba pojedyncza: `pictures` → lemma `picture`,
   - przymiotnik/przysłówek → stopień równy: `better` → lemma `good`.
6. **Tłumacz KAŻDE słowo** — także słowa funkcyjne. Każdy token ma mieć `t`
   i `lemma`. Dla słów, które nie mają polskiego odpowiednika, użyj krótkiego
   opisu w nawiasie:
   - przedimek określony `the` → `t: "(przedimek określony)"`,
   - przedimek nieokreślony `a`/`an` → `t: "(przedimek nieokreślony)"`,
   - partykuła bezokolicznika `to` (np. w „to get") → `t: "(bezokolicznik)"`.
   Pozostałe słowa funkcyjne tłumacz kontekstowo: `or` → „lub/albo/ani”,
   `of` → „z/od”, `and` → „i/a”, `in` → „w”, `on` → „na”.
7. **Nazwy własne:** `t` = polski odpowiednik, jeśli istnieje (`Alice` → „Alicja”,
   `London` → „Londyn”); w innym razie `t` = oryginał. `lemma` można pominąć.
8. **Idiomy i frazy:** sens oddaj w `pl` (tłumaczenie całego zdania). W `t`
   poszczególnych słów dawaj znaczenie pasujące do kontekstu (nie dosłowne, jeśli
   dosłowne myli). Możesz dla kluczowego słowa idiomu podać `t` oddające sens
   frazy (np. w „kick the bucket” dla `kick` → „umrzeć (idiom)”).

---

## Walidacja PRZED zapisem (obowiązkowa)

Zanim zapiszesz plik, sprawdź każde zdanie:

1. **Dopasowanie tokenów:** przejdź `tokens` po kolei i symuluj wyszukiwanie
   każdego `w` w `en` od pozycji kursora (kursor zaczyna na 0, po dopasowaniu
   przesuwa się za znalezione słowo). Każde `w` MUSI dać się dopasować w tej
   kolejności. Jeśli któreś się nie dopasowuje — popraw kolejność/pisownię tokenu.
2. **`pl`** jest poprawnym, naturalnym tłumaczeniem `en` (nie słowo-w-słowo).
3. **JSON** jest składniowo poprawny (kodowanie UTF-8, polskie znaki dosłownie).
4. **`id`** zgadza się z nazwą pliku i jest unikalne w `index.json`.

---

## Publikacja (kroki końcowe)

1. Zapisz plik jako `texts/<id>.json` (UTF-8).
2. Dopisz/zmień wpis w `index.json`:
   ```json
   { "id": "...", "title": "...", "author": "...", "level": "...",
     "category": "Lektury", "tags": ["..."], "file": "texts/<id>.json",
     "sha256": "<policzony hash>" }
   ```
   - **`category`** (zalecane) — nazwa kategorii do grupowania w bibliotece,
     np. `"Lektury"`, `"Wiadomości"`, `"Nauka"`, `"Dialogi"`. Teksty z tą samą
     nazwą trafiają do jednej kategorii. Brak pola => kategoria `"Ogólne"`.
   - Ustaw też `updatedAt` na dzisiejszą datę.
3. Policz `sha256` pliku tekstu i wpisz do `index.json`. Najprościej uruchom
   skrypt, który przeliczy wszystkie hashe automatycznie:
   ```
   python tools/reindex.py
   ```
4. Commit + push do gałęzi `main`. Aplikacja wykryje zmianę przy następnym
   odświeżeniu katalogu (przycisk „Odśwież" / pociągnięcie listy / restart).

> Aplikacja używa `sha256`, by wykryć, że tekst się zmienił. Po KAŻDEJ edycji
> pliku tekstu zaktualizuj jego `sha256` w `index.json` (najlepiej `reindex.py`).

---

## Wskazówki jakości

- Zachowuj oryginalny podział na akapity (lepsze tempo czytania).
- `pl` zwięzłe i naturalne; unikaj kalk.
- Lematy spójne w całym dokumencie.
- Dbaj o prawa autorskie — preferuj teksty z domeny publicznej (np. Project
  Gutenberg) lub takie, do których masz prawa. Odnotuj to w `source`.

---

## Pełny przykład (skrócony)

```json
{
  "schemaVersion": 1,
  "id": "alice-ch01",
  "title": "Alice's Adventures in Wonderland — Chapter 1 (fragment)",
  "author": "Lewis Carroll",
  "source": "Project Gutenberg (public domain)",
  "level": "B1",
  "tags": ["fiction", "classic"],
  "createdAt": "2026-06-08",
  "paragraphs": [
    {
      "sentences": [
        {
          "en": "Alice was beginning to get very tired of sitting by her sister.",
          "pl": "Alicja zaczynała się bardzo nudzić siedzeniem przy swojej siostrze.",
          "tokens": [
            { "w": "Alice", "t": "Alicja", "lemma": "Alice" },
            { "w": "was", "t": "była", "lemma": "be" },
            { "w": "beginning", "t": "zaczynała", "lemma": "begin" },
            { "w": "to", "t": "(bezokolicznik)", "lemma": "to" },
            { "w": "get", "t": "stawać się", "lemma": "get" },
            { "w": "very", "t": "bardzo", "lemma": "very" },
            { "w": "tired", "t": "zmęczona", "lemma": "tired" },
            { "w": "of", "t": "z", "lemma": "of" },
            { "w": "sitting", "t": "siedzeniem", "lemma": "sit" },
            { "w": "by", "t": "przy", "lemma": "by" },
            { "w": "her", "t": "swojej", "lemma": "her" },
            { "w": "sister", "t": "siostrze", "lemma": "sister" }
          ]
        }
      ]
    }
  ]
}
```

Pełny, dłuższy wzorzec znajduje się w pliku `texts/alice-ch01.json`.
