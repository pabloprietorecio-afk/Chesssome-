#!/usr/bin/env python3
"""Mapas de profundidad de las fotos del Campeonato, para la «foto viva» (ui/campeonato_ui.gd: la foto se mueve en
2,5D, lo cercano más que lo lejano). Modelo: Depth Anything V2 Small (ONNX, onnx-community).

Uso: python3 profundidad.py modelo.onnx godot/campeonato salida/
Por cada <nombre>.bin (JPEG) escribe <nombre>_prof.bin: PNG en grises de 8 bits (blanco = cerca), lado mayor 512.
"""
import os
import sys

import numpy as np
import onnxruntime as ort
from PIL import Image, ImageFilter

SIDE = 518
MEAN = np.array([0.485, 0.456, 0.406], dtype=np.float32)
STD = np.array([0.229, 0.224, 0.225], dtype=np.float32)


def depth(sess, img):
    x = np.asarray(img.convert("RGB").resize((SIDE, SIDE), Image.BICUBIC), dtype=np.float32) / 255.0
    x = ((x - MEAN) / STD).transpose(2, 0, 1)[None]
    name = sess.get_inputs()[0].name
    d = sess.run(None, {name: x})[0].reshape(SIDE, SIDE)
    lo, hi = np.percentile(d, 1), np.percentile(d, 99)
    d = np.clip((d - lo) / max(hi - lo, 1e-6), 0, 1)
    out = Image.fromarray((d * 255).astype(np.uint8), "L")
    w, h = img.size
    k = 512 / max(w, h)
    out = out.resize((max(1, round(w * k)), max(1, round(h * k))), Image.BICUBIC)
    # Suave: sin bordes duros, el desplazamiento no rompe la imagen en los contornos.
    return out.filter(ImageFilter.GaussianBlur(2))


def main():
    model, src, dst = sys.argv[1], sys.argv[2], sys.argv[3]
    sess = ort.InferenceSession(model, providers=["CPUExecutionProvider"])
    n = 0
    for root, _, files in os.walk(src):
        for f in sorted(files):
            if not f.endswith(".bin") or f.endswith("_prof.bin"):
                continue
            path = os.path.join(root, f)
            rel = os.path.relpath(path, src)
            out = os.path.join(dst, rel[:-4] + "_prof.bin")
            os.makedirs(os.path.dirname(out), exist_ok=True)
            depth(sess, Image.open(path)).save(out, "PNG", optimize=True)
            n += 1
            print("ok", rel, flush=True)
    print(n, "mapas")


if __name__ == "__main__":
    main()
