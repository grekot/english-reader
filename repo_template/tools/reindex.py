# -*- coding: utf-8 -*-
"""Przelicza sha256 wszystkich tekstów i aktualizuje index.json.

Uruchom z dowolnego miejsca:
    python tools/reindex.py

Co robi:
- dla każdego wpisu w index.json liczy sha256 pliku wskazanego w polu "file",
  normalizując końce linii do LF (zgodnie z tym, co serwuje GitHub i co liczy
  aplikacja),
- wpisuje wynik do pola "sha256",
- ustawia "updatedAt" na dzisiejszą datę,
- zapisuje index.json (UTF-8, LF, wcięcie 2 spacje).

Dzięki temu po edycji tekstu wystarczy uruchomić ten skrypt i zrobić commit —
aplikacja wykryje zmianę i pobierze nową wersję.
"""
import json
import hashlib
import datetime
import os
import sys


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    idx_path = os.path.join(root, 'index.json')

    with open(idx_path, 'r', encoding='utf-8') as f:
        idx = json.load(f)

    texts = idx.get('texts', [])
    for e in texts:
        rel = e.get('file')
        if not rel:
            print('POMINIETO wpis bez pola "file":', e.get('id'))
            continue
        fp = os.path.join(root, rel)
        if not os.path.exists(fp):
            print('BLAD: brak pliku', rel, '(wpis', e.get('id'), ')')
            sys.exit(1)
        with open(fp, 'rb') as tf:
            data = tf.read().replace(b'\r\n', b'\n').replace(b'\r', b'\n')
        e['sha256'] = hashlib.sha256(data).hexdigest()
        print('OK', e.get('id'), '->', e['sha256'][:12], '…')

    idx['updatedAt'] = datetime.date.today().isoformat()

    with open(idx_path, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(idx, f, ensure_ascii=False, indent=2)
        f.write('\n')

    print('Zaktualizowano index.json (%d tekstow).' % len(texts))


if __name__ == '__main__':
    main()
