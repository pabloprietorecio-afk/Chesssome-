#!/usr/bin/env python3
"""Prepara las texturas de los acabados realistas a partir de los archivos descargados (todos CC0).

Uso: python3 -I tools/assets/prepare.py <carpeta de Poly Haven> <carpeta de ambientCG> godot/textures
Los originales se descargan con tools/assets/fetch.sh (en la CI) y quedan en la rama «assets-src».
Aquí solo se cambian de tamaño y de nombre; no se retocan.
"""
import sys
from PIL import Image

polyhaven, ambientcg, out = sys.argv[1], sys.argv[2], sys.argv[3]
# destino: (origen, archivo de origen, lado en píxeles)
PLAN = {
    # Madera (Poly Haven)
    "arce.jpg": (polyhaven, "white_maple_veneer_diffuse_1k.jpg", 1024),
    "arce_normal.jpg": (polyhaven, "white_maple_veneer_nor_gl_1k.jpg", 512),
    "nogal.jpg": (polyhaven, "walnut_veneer_diffuse_1k.jpg", 1024),
    "nogal_normal.jpg": (polyhaven, "walnut_veneer_nor_gl_1k.jpg", 512),
    "palisandro.jpg": (polyhaven, "rosewood_veneer1_diffuse_1k.jpg", 512),
    "boj.jpg": (polyhaven, "bamboo_veneer_diffuse_1k.jpg", 512),
    "ebano.jpg": (polyhaven, "flamed_black_veneer_diffuse_1k.jpg", 512),
    # Mármol (ambientCG)
    "marmol_crema.jpg": (ambientcg, "Marble014_1K-JPG_Color.jpg", 1024),
    "marmol_pizarra.jpg": (ambientcg, "Marble023_1K-JPG_Color.jpg", 1024),
    "marmol_blanco.jpg": (ambientcg, "Marble021_1K-JPG_Color.jpg", 512),
    "marmol_negro.jpg": (ambientcg, "Marble016_1K-JPG_Color.jpg", 512),
    # Metal (ambientCG)
    "acero.jpg": (ambientcg, "Metal009_1K-JPG_Color.jpg", 1024),
    "acero_normal.jpg": (ambientcg, "Metal009_1K-JPG_NormalGL.jpg", 512),
    "laton.jpg": (ambientcg, "Metal048B_1K-JPG_Color.jpg", 512),
    "bronce.jpg": (ambientcg, "Metal036_1K-JPG_Color.jpg", 512),
}
for name, (src, source, side) in PLAN.items():
    im = Image.open(f"{src}/{source}").convert("RGB")
    if im.size != (side, side):
        im = im.resize((side, side), Image.LANCZOS)
    im.save(f"{out}/{name}", quality=91, optimize=True)
    print(name, im.size)
