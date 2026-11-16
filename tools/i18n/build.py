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
# Frases de las explicaciones que se sacan de otra: «Tu jugada, {1}, X» y «La mejor era {1}, que X» salen de «{1} X».
# Por idioma: cómo empieza la traducción de «{1} X» y qué se pone en su lugar.
DERIVED = {
    'Tu jugada, {1}, ': {'en': ('{1} ', 'Your move, {1}, '), 'fr': ('{1} ', 'Ton coup, {1}, '), 'it': ('{1} ', 'La tua mossa, {1}, '),
                        'ja': [('{1}は', 'あなたの手{1}は'), ('{1}で', 'あなたの手{1}で')], 'pt': ('{1} ', 'Seu lance, {1}, '), 'id': ('{1} ', 'Langkahmu, {1}, '),
                        'hi': ('{1} ', 'आपकी चाल {1} '), 'de': ('{1} ', 'Dein Zug {1} '), 'ru': ('{1} ', 'Твой ход {1} ')},
    'La mejor era {1}, que ': {'en': ('{1} ', 'The best was {1}, which '), 'fr': ('{1} ', 'Le meilleur était {1}, qui '),
                              'it': ('{1} ', 'La migliore era {1}, che '), 'ja': [('{1}は', '最善手は{1}で、この手は'), ('{1}で', '最善手は{1}で、この手で')],
                              'pt': ('{1} ', 'O melhor era {1}, que '), 'id': ('{1} ', 'Yang terbaik adalah {1}, yang '),
                              'hi': ('{1} ', 'सबसे अच्छी चाल {1} थी, जो '), 'de': ('{1} ', 'Besser war {1}: Er '),
                              'ru': ('{1} ', 'Лучшим был {1}: он ')},
}


def derive(exp_keys, tables):
    for key in exp_keys:
        for prefix, rules in DERIVED.items():
            if not key.startswith(prefix):
                continue
            base = '{1} ' + key[len(prefix):]
            for lang, options in rules.items():
                t = tables[lang]['@exp']
                for lead, new in (options if isinstance(options, list) else [options]):
                    if key not in t and base in t and t[base].startswith(lead):
                        t[key] = new + t[base][len(lead):]


def main():
    keys = json.load(open(os.path.join(HERE, 'claves_ui.json'), encoding='utf8'))
    tables = {l: {'@exp': {}} for l in LANGS}
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
                if os.path.basename(path).startswith('exp_'):
                    tables[lang]['@exp'][key] = unesc(val)
                else:
                    tables[lang][key] = unesc(val)
        if changed:
            open(path, 'w', encoding='utf8').write('\n'.join(lines))
    derive(json.load(open(os.path.join(HERE, 'exp_plantillas.json'), encoding='utf8')), tables)
    os.makedirs(DATA, exist_ok=True)
    for lang in LANGS:
        json.dump(tables[lang], open(os.path.join(DATA, lang + '.json'), 'w', encoding='utf8'), ensure_ascii=False,
                  indent=0, sort_keys=True)
    print('tablas:', {l: (len(t) - 1, len(t['@exp'])) for l, t in tables.items()})
if __name__ == '__main__':
    main()
