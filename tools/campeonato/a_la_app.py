#!/usr/bin/env python3
"""Pasa las imágenes aprobadas del Campeonato (rama campeonato-imagenes) a la app: JPEG con extensión .bin en
godot/campeonato/ (Godot no las importa ni las recomprime; las lee ui/campeonato_ui.gd).

Uso: git archive origin/campeonato-imagenes | tar -x -C /tmp/camp && python3 a_la_app.py /tmp/camp
Salas: 1024×1792, calidad 82. Retratos: 640×640, calidad 85. Solo las que estén en core/campeonato.gd.
"""
import os
import re
import sys

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
OUT = os.path.join(ROOT, "godot", "campeonato")


def wanted():
    src = open(os.path.join(ROOT, "godot", "core", "campeonato.gd"), encoding="utf8").read()
    rooms = re.findall(r'\{"key": "([a-z_]+)", "group"', src)
    rivals = {}
    block = src[src.index("const RIVALS"):]
    for sala in rooms:
        part = block[block.index(f'"{sala}": ['):]
        part = part[: part.index("\t],")]
        rivals[sala] = re.findall(r'\{"id": "([a-z_]+)"', part)
    return rooms, rivals


def save(src, dest, size, quality):
    im = Image.open(src).convert("RGB")
    if size:
        im = im.resize(size, Image.LANCZOS)
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    im.save(dest, "JPEG", quality=quality, optimize=True, progressive=True)
    return os.path.getsize(dest)


def main():
    src = sys.argv[1]
    rooms, rivals = wanted()
    total = 0
    missing = []
    for sala in rooms:
        for shot in ("entrada", "pasillo"):
            f = os.path.join(src, "salas", f"{sala}_{shot}.jpg")
            if os.path.exists(f):
                total += save(f, os.path.join(OUT, "salas", f"{sala}_{shot}.bin"), None, 82)
            else:
                missing.append(f"salas/{sala}_{shot}")
        for rid in rivals[sala]:
            f = os.path.join(src, "rivales", sala, f"{rid}.jpg")
            if os.path.exists(f):
                total += save(f, os.path.join(OUT, "rivales", sala, f"{rid}.bin"), (640, 640), 85)
            else:
                missing.append(f"rivales/{sala}/{rid}")
    print(f"{total / 1e6:.1f} MB en godot/campeonato")
    if missing:
        print("Faltan:", ", ".join(missing))


if __name__ == "__main__":
    main()
