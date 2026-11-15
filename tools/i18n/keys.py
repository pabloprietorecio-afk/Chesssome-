#!/usr/bin/env python3
"""Reúne los textos en español de la interfaz (los .gd de godot/, menos el tablero 3D) que hay que traducir.
Escribe tools/i18n/claves_ui.json: lista ordenada de textos únicos. Las tablas de cada idioma
(godot/data/i18n/<idioma>.json) se rellenan a partir de esta lista; tools/i18n/check.py dice qué falta."""
import re, json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
from scan import FILES, cands, ROOT
SKIP_FILES = {'core/move_why.gd'}  # sus frases van aparte (tools/i18n/claves_tablero.json)
CAMEL = re.compile(r'^[a-z]+[A-Z][A-Za-z]*$')
TECH = re.compile(r'\.(woff2|png|jpg|json|ogg|wav|bin|gd|tscn)\b|^[@#]|^[A-Z][a-zA-Z]+(Rect|Container|Button|Label)$|Stockfish|^%[sd]?\s*%[sd]$')
# Palabras sueltas en minúscula que sí se ven (se meten en frases con «%s»).
WORDS = ['alfil', 'caballo', 'dama', 'peón', 'rey', 'torre', 'sí', 'no', 'ene', 'feb', 'mar', 'abr', 'may', 'jun',
         'jul', 'ago', 'sep', 'oct', 'nov', 'dic', 'blancas', 'negras', 'inicio']
# Lo que no se ve o no se traduce (cabeceras HTTP, rutas de Firebase, la marca, mensajes para desarrolladores…).
EXCLUDE = re.compile(r'^(Content-Type|Accept|grant_type|auth=|orderBy|partidas/|abiertas/|AIza|\^\[|A CHESS$|WAY$|'
                     r'Falta el índice|No se puede cargar|Icono desconocido|Jan$|Feb$|Mar$|Apr$|May$|Jun$|Jul$|Aug$|'
                     r'Sep$|Oct$|Nov$|Dec$|coño$|Lichess$|OK$|A Chess Way$)')
def wanted(s):
    if EXCLUDE.search(s):
        return False
    if CAMEL.match(s) or TECH.search(s):
        return False
    if re.fullmatch(r'[\s%sd·:,.\-+()/\[\]0-9]*', s):
        return False
    if re.fullmatch(r'[a-z]+:[%a-z:]*', s):  # claves internas tipo "learn:%s:%d"
        return False
    return True
def collect():
    keys = []
    seen = set()
    for f in FILES:
        for rel, n, s in cands(f):
            if rel in SKIP_FILES or not wanted(s):
                continue
            s = s.encode('utf8').decode('unicode_escape').encode('latin1').decode('utf8') if '\\' in s else s
            if s not in seen:
                seen.add(s)
                keys.append(s)
    # Nombres de los temas de los problemas (vienen en los datos, no en el código).
    puzzles = json.load(open(os.path.join(ROOT, 'data', 'demo_puzzles.json'), encoding='utf8'))['puzzles']
    for p in puzzles:
        th = str(p.get('theme', ''))
        if th and th not in seen:
            seen.add(th)
            keys.append(th)
    for w in WORDS:
        if w not in seen:
            keys.append(w)
    return keys
if __name__ == '__main__':
    keys = collect()
    out = os.path.join(os.path.dirname(__file__), 'claves_ui.json')
    json.dump(keys, open(out, 'w', encoding='utf8'), ensure_ascii=False, indent=0)
    print(len(keys), 'textos ->', out)
