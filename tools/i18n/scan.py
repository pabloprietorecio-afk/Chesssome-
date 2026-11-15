#!/usr/bin/env python3
"""Lista los textos entre comillas de los .gd que parecen texto para el jugador (en español).
Uso: python3 tools/i18n/scan.py > candidatos.tsv  (archivo<TAB>línea<TAB>texto)"""
import re, sys, glob, os
ROOT = os.path.join(os.path.dirname(__file__), '..', '..', 'godot')
FILES = ['demo/demo.gd'] + sorted(glob.glob(ROOT + '/core/*.gd') + glob.glob(ROOT + '/ui/*.gd'))
ID = re.compile(r'^[a-z0-9_./:\-]+$')
def cands(path):
    full = path if os.path.isabs(path) else os.path.join(ROOT, path)
    for n, line in enumerate(open(full, encoding='utf8'), 1):
        code = line.split('#')[0] if '"#' not in line and '# ' in line and line.count('"') % 2 == 0 and False else line
        if line.lstrip().startswith('##') or line.lstrip().startswith('#'):
            continue
        for m in re.finditer(r'"((?:[^"\\]|\\.)*)"', line):
            s = m.group(1)
            if not re.search(r'[A-Za-zÁÉÍÓÚÜáéíóúüñÑ]{2,}', s):
                continue
            if ID.match(s) or s.startswith(('res://', 'user://', 'http')):
                continue
            yield os.path.relpath(full, ROOT), n, s
if __name__ == '__main__':
    for f in FILES:
        for rel, n, s in cands(f):
            print('%s\t%d\t%s' % (rel, n, s))
