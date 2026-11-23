#!/usr/bin/env python3
"""Dónde está la cara en cada retrato del Campeonato, para la cara redonda de encima del tablero.

Uso: python3 caras.py godot/campeonato/rivales godot/data/campeonato_caras.json [haarcascade_frontalface_default.xml]
Escribe {"escuela/lucia": [x, y, lado], …}: un cuadrado (en fracciones del ancho y del alto) centrado en la cara.
El detector es el clásico de OpenCV (viene con opencv-python, en cv2.data); sin cara, un recorte por defecto.
"""
import glob
import json
import os
import sys

import cv2
import numpy as np


def main():
    src, dst = sys.argv[1], sys.argv[2]
    xml = sys.argv[3] if len(sys.argv) > 3 else os.path.join(cv2.data.haarcascades, "haarcascade_frontalface_default.xml")
    casc = cv2.CascadeClassifier(xml)
    out = {}
    for f in sorted(glob.glob(os.path.join(src, "*", "*.bin"))):
        if "_prof" in f:
            continue
        im = cv2.imdecode(np.frombuffer(open(f, "rb").read(), np.uint8), cv2.IMREAD_GRAYSCALE)
        h, w = im.shape[:2]
        best = None
        for (x, y, fw, fh) in casc.detectMultiScale(im, 1.08, 5, minSize=(50, 50)):
            # La cara más grande y más centrada (al fondo puede haber más gente).
            score = fw * fh - abs(x + fw / 2 - w / 2) * fw * 0.8
            if best is None or score > best[0]:
                best = (score, x, y, fw, fh)
        if best is None:
            print("sin cara:", f)
            cx, cy, side = w * 0.5, h * 0.32, w * 0.6
        else:
            _, x, y, fw, fh = best
            cx, cy, side = x + fw / 2, y + fh * 0.55, fw * 2.3
        side = min(side, w, h)
        x0 = min(max(cx - side / 2, 0), w - side)
        y0 = min(max(cy - side / 2, 0), h - side)
        key = os.path.relpath(f, src)[:-4].replace(os.sep, "/")
        out[key] = [round(x0 / w, 3), round(y0 / h, 3), round(side / w, 3)]
    with open(dst, "w") as fh:
        json.dump(out, fh, separators=(",", ":"), sort_keys=True)
        fh.write("\n")
    print(len(out), "caras →", dst)


if __name__ == "__main__":
    main()
