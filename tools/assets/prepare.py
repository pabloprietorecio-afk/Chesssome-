#!/usr/bin/env python3
"""Prepara las texturas del acabado realista a partir de los archivos descargados de Poly Haven (CC0).

Uso: python3 -I tools/assets/prepare.py <carpeta con los archivos descargados> godot/textures
Los originales se descargan con tools/assets/fetch.sh (en la CI) y quedan en la rama «assets-src».
Aquí solo se cambian de tamaño y de nombre; no se retocan.
"""
import sys
from PIL import Image

src, out = sys.argv[1], sys.argv[2]
# destino: (archivo de origen, lado en píxeles)
PLAN = {
    "arce.jpg": ("white_maple_veneer_diffuse_1k.jpg", 1024),
    "arce_normal.jpg": ("white_maple_veneer_nor_gl_1k.jpg", 512),
    "nogal.jpg": ("walnut_veneer_diffuse_1k.jpg", 1024),
    "nogal_normal.jpg": ("walnut_veneer_nor_gl_1k.jpg", 512),
    "palisandro.jpg": ("rosewood_veneer1_diffuse_1k.jpg", 512),
    "boj.jpg": ("bamboo_veneer_diffuse_1k.jpg", 512),
    "ebano.jpg": ("flamed_black_veneer_diffuse_1k.jpg", 512),
}
for name, (source, side) in PLAN.items():
    im = Image.open(f"{src}/{source}").convert("RGB")
    if im.size != (side, side):
        im = im.resize((side, side), Image.LANCZOS)
    im.save(f"{out}/{name}", quality=91, optimize=True)
    print(name, im.size)
