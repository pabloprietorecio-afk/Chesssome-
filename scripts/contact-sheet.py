#!/usr/bin/env python3
"""Hoja de contactos: junta varias capturas en una sola imagen para revisarlas de un vistazo.
Uso: scripts/contact-sheet.py salida.png [--crop] captura1.png captura2.png …   (--crop recorta al cuadrado central)"""
import sys
from PIL import Image

out, *rest = sys.argv[1:]
crop = '--crop' in rest
files = [f for f in rest if not f.startswith('--')]
tiles = []
for f in files:
    im = Image.open(f).convert('RGB')
    w, h = im.size
    if crop:
        im = im.crop((0, (h - w) // 2, w, (h + w) // 2))
    tiles.append(im)
tw = min(t.size[0] for t in tiles)
cols = 2 if len(tiles) <= 4 else 3
tw = min(tw, 1440 // cols)
tiles = [t.resize((tw, round(t.size[1] * tw / t.size[0])), Image.LANCZOS) for t in tiles]
th = max(t.size[1] for t in tiles)
rows = -(-len(tiles) // cols)
sheet = Image.new('RGB', (cols * tw + (cols - 1) * 8, rows * th + (rows - 1) * 8), 'white')
for i, t in enumerate(tiles):
    sheet.paste(t, ((i % cols) * (tw + 8), (i // cols) * (th + 8)))
sheet.save(out)
print(out, sheet.size)
