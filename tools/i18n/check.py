#!/usr/bin/env python3
"""Comprueba las tablas de idiomas: qué textos faltan y si cada traducción conserva los «%d», «%s» y «%%».
Uso: python3 tools/i18n/check.py [idioma…]"""
import json, os, re, sys, glob
HERE = os.path.dirname(__file__)
DATA = os.path.join(HERE, '..', '..', 'godot', 'data', 'i18n')
LANGS = ['en', 'fr', 'it', 'ja', 'pt', 'id', 'hi', 'de', 'ru']
FMT = re.compile(r'%[-+0-9.]*[dsf%]')
def keys():
    out = []
    for f in sorted(glob.glob(os.path.join(HERE, 'claves_*.json'))):
        out += json.load(open(f, encoding='utf8'))
    return list(dict.fromkeys(out))
def main(langs):
    ks = keys()
    bad = 0
    for lang in langs:
        path = os.path.join(DATA, lang + '.json')
        table = json.load(open(path, encoding='utf8')) if os.path.exists(path) else {}
        exp = table.pop('@exp', {})
        missing = [k for k in ks if k not in table]
        wrong = [k for k, v in table.items() if FMT.findall(k) != FMT.findall(v)]
        tpls = json.load(open(os.path.join(HERE, 'exp_plantillas.json'), encoding='utf8'))
        hole = re.compile(r'\{\d+')
        exp_missing = [k for k in tpls if k not in exp]
        exp_wrong = [k for k, v in exp.items() if set(hole.findall(k)) != set(hole.findall(v))]
        print('   explicaciones: faltan %d de %d, huecos mal %d' % (len(exp_missing), len(tpls), len(exp_wrong)))
        for k in exp_wrong[:5]:
            print('   huecos:', k, '->', exp[k])
        bad += len(exp_missing) + len(exp_wrong)
        print('%s: %d de %d, faltan %d, formato mal %d' % (lang, len(ks) - len(missing), len(ks), len(missing), len(wrong)))
        for k in wrong[:10]:
            print('   formato:', k, '->', table[k])
        bad += len(missing) + len(wrong)
    return bad
if __name__ == '__main__':
    sys.exit(1 if main(sys.argv[1:] or LANGS) else 0)
