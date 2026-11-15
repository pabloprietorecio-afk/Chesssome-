#!/usr/bin/env python3
"""Recorta Noto Sans JP a los caracteres que usa la app en japonés (todas las tablas y textos «ja»).
La fuente completa no va en el repositorio (pesa unos 5 MB): sale del paquete npm @expo-google-fonts/noto-sans-jp
(OFL 1.1). Uso: python3 tools/i18n/fonts.py RUTA/NotoSansJP_500Medium.ttf"""
import sys, os, glob, json, subprocess
HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.join(HERE, '..', '..', 'godot')
def chars():
    text = ''
    for path in glob.glob(os.path.join(GODOT, 'data', 'i18n', 'ja*.json')) + glob.glob(os.path.join(GODOT, 'data', 'i18n', '*', 'ja.json')):
        text += open(path, encoding='utf8').read()
    text += '日本語'
    return ''.join(sorted(set(c for c in text if ord(c) > 0x2000)))
if __name__ == '__main__':
    src = sys.argv[1]
    out = os.path.join(GODOT, 'fonts', 'NotoSansJP-Subset.ttf')
    cs = chars()
    open('/tmp/ja_chars.txt', 'w', encoding='utf8').write(cs)
    subprocess.run(['pyftsubset', src, '--text-file=/tmp/ja_chars.txt', '--output-file=' + out, '--layout-features=*',
                    '--no-hinting'], check=True)
    print(len(cs), 'caracteres ->', out, os.path.getsize(out), 'bytes')
