#!/usr/bin/env python3
"""Frases del nivel Kids en los demás idiomas, para generar su voz (.github/workflows/voz-idiomas.yml).

Lee godot/data/voz.json (frase en español → audio) y las tablas godot/data/i18n/<idioma>.json, y escribe:
- tools/voz/lineas_<idioma>.json: [{id, text}] con el texto traducido (lo que lee generar_idiomas.py);
- godot/data/voz_<idioma>.json: frase en español → id del audio (lo que busca la app; ver _voice_path en demo.gd).
El id es el sha1 del texto traducido (12 cifras), como el de las voces en español: si cambia la traducción, cambia
el audio. Uso: python3 tools/voz/idiomas.py"""
import hashlib, json, os
HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.join(HERE, '..', '..', 'godot')
LANGS = ['en', 'fr', 'it', 'ja', 'pt', 'id', 'hi', 'de', 'ru']


def voice_id(text):
    return hashlib.sha1(text.encode('utf8')).hexdigest()[:12]


def main():
    spanish = json.load(open(os.path.join(GODOT, 'data', 'voz.json'), encoding='utf8'))
    for lang in LANGS:
        table = json.load(open(os.path.join(GODOT, 'data', 'i18n', lang + '.json'), encoding='utf8'))
        lines, index = {}, {}
        for es in spanish:
            text = table.get(es)
            if not text:
                print('sin traducción (%s): %s' % (lang, es))
                continue
            vid = voice_id(text)
            lines[vid] = text
            index[es] = vid
        json.dump([{'id': k, 'text': v} for k, v in lines.items()],
                  open(os.path.join(HERE, 'lineas_%s.json' % lang), 'w', encoding='utf8'), ensure_ascii=False, indent=1)
        json.dump(index, open(os.path.join(GODOT, 'data', 'voz_%s.json' % lang), 'w', encoding='utf8'),
                  ensure_ascii=False, separators=(',', ':'))
        print(lang, len(lines), 'frases')


if __name__ == '__main__':
    main()
