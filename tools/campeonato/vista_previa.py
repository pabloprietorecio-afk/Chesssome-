#!/usr/bin/env python3
"""Vídeo de muestra del Campeonato fuera de la app: paseo por la sala y rival animado (foto viva por profundidad,
parpadeo y sonrisa), para comparar estilos antes de meterlos en la app.

Uso: python3 vista_previa.py carpeta salida.mp4 sala rival [rival…] [--sonido murmullo.ogg]
En «carpeta»: salas/<sala>_pasillo.jpg y rivales/<sala>/<rival>{,_parpadeo,_sonrisa}.jpg, con sus *_prof.png.
"""
import argparse
import os
import subprocess

import cv2
import numpy as np

W, H, FPS = 720, 1280, 30


def load(path, size=(W, H), gray=False):
    im = cv2.imread(path, cv2.IMREAD_GRAYSCALE if gray else cv2.IMREAD_COLOR)
    if im is None:
        return None
    # Llenar el cuadro sin deformar (recortar lo que sobra), como la app.
    h, w = im.shape[:2]
    k = max(size[0] / w, size[1] / h)
    im = cv2.resize(im, (round(w * k), round(h * k)), interpolation=cv2.INTER_AREA)
    y0 = (im.shape[0] - size[1]) // 2
    x0 = (im.shape[1] - size[0]) // 2
    im = im[y0:y0 + size[1], x0:x0 + size[0]]
    return im.astype(np.float32) / (255.0 if gray else 1.0)


def warp(img, depth, shift, focus, zoom=1.0):
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    # Zoom hacia el centro.
    cx, cy = W / 2, H / 2
    bx = cx + (xx - cx) / zoom
    by = cy + (yy - cy) / zoom
    ux, uy = bx.copy(), by.copy()
    for _ in range(3):
        d = cv2.remap(depth, ux, uy, cv2.INTER_LINEAR, borderMode=cv2.BORDER_REPLICATE)
        ux = bx - shift[0] * W * (d - focus)
        uy = by - shift[1] * H * (d - focus)
    return cv2.remap(img, ux, uy, cv2.INTER_LINEAR, borderMode=cv2.BORDER_REPLICATE)


def ease(t):
    return 0.5 - 0.5 * np.cos(np.pi * np.clip(t, 0, 1))


def face_patch(base, variant):
    """Solo la zona que cambia (la cara): así el fondo no tiembla al pasar de una imagen a otra."""
    a = cv2.GaussianBlur(base, (0, 0), 3)
    b = cv2.GaussianBlur(variant, (0, 0), 3)
    diff = np.abs(a - b).mean(axis=2)
    m = (diff > 18).astype(np.uint8)
    m[int(H * 0.62):, :] = 0  # el tablero y las manos se quedan como en la base
    n, lab, stats, _ = cv2.connectedComponentsWithStats(m)
    if n > 1:
        big = 1 + np.argmax(stats[1:, cv2.CC_STAT_AREA])
        m = (lab == big).astype(np.uint8)
    m = cv2.dilate(m, np.ones((25, 25), np.uint8))
    mask = cv2.GaussianBlur(m.astype(np.float32), (0, 0), 12)[..., None]
    return base * (1 - mask) + variant * mask


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("carpeta")
    ap.add_argument("salida")
    ap.add_argument("sala")
    ap.add_argument("rivales", nargs="+")
    ap.add_argument("--sonido", default="")
    a = ap.parse_args()
    c = a.carpeta
    frames = []
    # 1. Paseo por la sala: 4 s, acercándose, con la profundidad.
    hall = load(f"{c}/salas/{a.sala}_pasillo.jpg")
    hall_d = load(f"{c}/salas/{a.sala}_pasillo_prof.png", gray=True)
    n = int(4.0 * FPS)
    for i in range(n):
        t = ease(i / (n - 1))
        frames.append(warp(hall, hall_d, (-0.004 + 0.014 * t, -0.016 * t), 0.3, 1.0 + 0.10 * t))
    for r in a.rivales:
        base = load(f"{c}/rivales/{a.sala}/{r}.jpg")
        depth = load(f"{c}/rivales/{a.sala}/{r}_prof.png", gray=True)
        blink = load(f"{c}/rivales/{a.sala}/{r}_parpadeo.jpg")
        smile = load(f"{c}/rivales/{a.sala}/{r}_sonrisa.jpg")
        blink = face_patch(base, blink) if blink is not None else base
        smile = face_patch(base, smile) if smile is not None else base
        last = frames[-1]
        total = int(7.0 * FPS)
        for i in range(total):
            s = i / FPS
            # Vaivén lento de la cámara (respira).
            ph = np.sin(2 * np.pi * s / 6.8)
            shift = (0.007 * ph, -0.004 - 0.004 * np.cos(2 * np.pi * s / 6.8))
            # Sonrisa y gesto entre 1,2 s y 3,4 s; parpadeos a los 4,6 s y 6,3 s.
            k = ease((s - 1.2) / 0.45) - ease((s - 3.0) / 0.45)
            img = base * (1 - k) + smile * k
            for tb in (4.6, 6.3):
                if tb <= s < tb + 0.13:
                    img = blink
            f = warp(img, depth, shift, 0.55, 1.0 + 0.02 * ease(s / 7.0))
            if i < int(0.8 * FPS):
                u = ease(i / (0.8 * FPS))
                f = last * (1 - u) + f * u
            frames.append(f)
    tmp = a.salida + ".sin_sonido.mp4"
    out = cv2.VideoWriter(tmp, cv2.VideoWriter_fourcc(*"mp4v"), FPS, (W, H))
    for f in frames:
        out.write(np.clip(f, 0, 255).astype(np.uint8))
    out.release()
    cmd = ["ffmpeg", "-v", "error", "-y", "-i", tmp]
    if a.sonido:
        cmd += ["-stream_loop", "-1", "-i", a.sonido, "-shortest", "-c:a", "aac", "-b:a", "128k", "-af", "volume=0.8"]
    cmd += ["-c:v", "libx264", "-preset", "veryfast", "-crf", "21", "-pix_fmt", "yuv420p", a.salida]
    subprocess.run(cmd, check=True)
    os.remove(tmp)
    print(a.salida, len(frames), "fotogramas")


if __name__ == "__main__":
    main()
