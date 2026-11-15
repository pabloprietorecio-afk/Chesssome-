#!/usr/bin/env python3
"""Junta las traducciones de tools/i18n/trad/*.tsv en las tablas godot/data/i18n/<idioma>.json.
Cada línea del .tsv: texto en español (o su número en claves_ui.json, que se cambia por el texto la primera vez)
y luego las traducciones en el orden de LANGS, separadas por tabuladores. «\\n» es un salto de línea."""
import json, os, glob, sys
HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, '..', '..', 'godot', 'data', 'i18n')
LANGS = ['en', 'fr', 'it', 'ja', 'pt', 'id', 'hi', 'de', 'ru']
def unesc(s):
    return s.replace('\\n', '\n')
def esc(s):
    return s.replace('\n', '\\n')
def main():
    keys = json.load(open(os.path.join(HERE, 'claves_ui.json'), encoding='utf8'))
    tables = {l: {} for l in LANGS}
    for path in sorted(glob.glob(os.path.join(HERE, 'trad', '*.tsv'))):
        lines = open(path, encoding='utf8').read().split('\n')
        changed = False
        for i, line in enumerate(lines):
            if not line.strip():
                continue
            cols = line.split('\t')
            if len(cols) != len(LANGS) + 1:
                sys.exit('%s:%d: %d columnas' % (path, i + 1, len(cols)))
            key = cols[0]
            if key.isdigit():
                key = keys[int(key)]
                cols[0] = esc(key)
                lines[i] = '\t'.join(cols)
                changed = True
            key = unesc(key)
            for lang, val in zip(LANGS, cols[1:]):
                tables[lang][key] = unesc(val)
        if changed:
            open(path, 'w', encoding='utf8').write('\n'.join(lines))
    os.makedirs(DATA, exist_ok=True)
    for lang in LANGS:
        json.dump(tables[lang], open(os.path.join(DATA, lang + '.json'), 'w', encoding='utf8'), ensure_ascii=False,
                  indent=0, sort_keys=True)
    print('tablas:', {l: len(t) for l, t in tables.items()})
if __name__ == '__main__':
    main()
