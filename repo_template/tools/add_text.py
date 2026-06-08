# -*- coding: utf-8 -*-
"""Dodaje (lub aktualizuje) wpis tekstu w index.json pod wybraną kategorią.

Użycie:
    python tools/add_text.py texts/<id>.json --category "Lektury"
    python tools/add_text.py texts/<id>.json -c "Wiadomości"
    python tools/add_text.py texts/<id>.json            # kategoria z pliku / istniejąca / "Ogólne"

Co robi:
- czyta metadane z samego pliku tekstu (id, title, author, level, tags),
- dopisuje nowy wpis do index.json albo aktualizuje istniejący (po "id"),
- ustawia kategorię (z argumentu --category; gdy brak: pole "category" z pliku
  tekstu, inaczej dotychczasowa kategoria wpisu, inaczej "Ogólne"),
- przelicza sha256 WSZYSTKICH tekstów (normalizacja końców linii do LF),
- ustawia updatedAt i zapisuje index.json (UTF-8, LF, wcięcie 2).
"""
import argparse
import datetime
import hashlib
import json
import os
import sys


def sha256_of(path):
    with open(path, 'rb') as f:
        data = f.read().replace(b'\r\n', b'\n').replace(b'\r', b'\n')
    return hashlib.sha256(data).hexdigest()


def choose_category(categories, default):
    """Interaktywny wybór kategorii: numer z listy, nowa nazwa albo Enter."""
    print()
    print('Wybierz kategorię:')
    for i, c in enumerate(categories, 1):
        marker = '  (domyślna)' if c == default else ''
        print('  %d) %s%s' % (i, c, marker))
    print('  [Enter] = %s' % default)
    print('  …albo wpisz nazwę nowej kategorii')
    try:
        raw = input('Wybór: ').lstrip('﻿').strip()
    except EOFError:
        return default
    if not raw:
        return default
    if raw.isdigit():
        n = int(raw)
        if 1 <= n <= len(categories):
            return categories[n - 1]
        print('Numer poza zakresem — używam:', default)
        return default
    return raw


def main():
    parser = argparse.ArgumentParser(description='Dodaj/aktualizuj tekst w index.json')
    parser.add_argument('file', help='ścieżka do pliku tekstu, np. texts/alice-ch01.json')
    parser.add_argument('-c', '--category', help='nazwa kategorii (np. "Lektury")')
    parser.add_argument('-y', '--yes', action='store_true',
                        help='bez pytań — użyj kategorii z pliku/istniejącej/"Ogólne"')
    args = parser.parse_args()

    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    idx_path = os.path.join(root, 'index.json')

    # Ścieżka pliku tekstu — bezwzględna + repo-względna z ukośnikami "/".
    abs_file = os.path.abspath(args.file)
    if not os.path.exists(abs_file):
        print('BŁĄD: nie znaleziono pliku:', args.file)
        sys.exit(1)
    rel_file = os.path.relpath(abs_file, root).replace('\\', '/')
    if rel_file.startswith('..'):
        print('BŁĄD: plik musi leżeć w repozytorium tekstów:', rel_file)
        sys.exit(1)

    # Metadane z pliku tekstu.
    with open(abs_file, 'r', encoding='utf-8') as f:
        doc = json.load(f)
    text_id = doc.get('id')
    if not text_id:
        print('BŁĄD: plik tekstu nie ma pola "id".')
        sys.exit(1)

    # Wczytaj lub utwórz index.json.
    if os.path.exists(idx_path):
        with open(idx_path, 'r', encoding='utf-8') as f:
            idx = json.load(f)
    else:
        idx = {'schemaVersion': 1, 'texts': []}
    idx.setdefault('schemaVersion', 1)
    idx.setdefault('texts', [])

    # Znajdź istniejący wpis po id.
    existing = next((e for e in idx['texts'] if e.get('id') == text_id), None)

    # Domyślna kategoria: pole w pliku > dotychczasowa > "Ogólne".
    default_category = (
        doc.get('category')
        or (existing.get('category') if existing else None)
        or 'Ogólne'
    )

    if args.category:
        # Jawnie podana w argumencie — bez pytań.
        category = args.category
    elif args.yes:
        # Tryb automatyczny — użyj domyślnej.
        category = default_category
    else:
        # Tryb interaktywny — pokaż istniejące kategorie do wyboru.
        existing_cats = sorted({e.get('category', 'Ogólne') for e in idx['texts']})
        if default_category not in existing_cats:
            existing_cats.append(default_category)
            existing_cats = sorted(set(existing_cats))
        category = choose_category(existing_cats, default_category)

    entry = {
        'id': text_id,
        'title': doc.get('title', text_id),
        'author': doc.get('author'),
        'level': doc.get('level'),
        'category': category,
        'tags': doc.get('tags', []),
        'file': rel_file,
        'sha256': sha256_of(abs_file),
    }
    # Usuń puste pola opcjonalne (author/level), by index był schludny.
    entry = {k: v for k, v in entry.items() if v is not None}

    if existing:
        idx['texts'][idx['texts'].index(existing)] = entry
        action = 'zaktualizowano'
    else:
        idx['texts'].append(entry)
        action = 'dodano'

    # Przelicz sha256 dla wszystkich tekstów (spójność katalogu).
    for e in idx['texts']:
        fp = os.path.join(root, e['file'])
        if os.path.exists(fp):
            e['sha256'] = sha256_of(fp)
        else:
            print('UWAGA: brak pliku dla wpisu', e.get('id'), '->', e['file'])

    idx['updatedAt'] = datetime.date.today().isoformat()

    with open(idx_path, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(idx, f, ensure_ascii=False, indent=2)
        f.write('\n')

    print('%s wpis "%s" (kategoria: %s).' % (action, text_id, category))
    print('Razem tekstów w index.json:', len(idx['texts']))
    print('Pamiętaj o: git add -A && git commit && git push')


if __name__ == '__main__':
    main()
