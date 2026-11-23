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
    bx = (cx + (xx - cx) / float(zoom)).astype(np.float32)
    by = (cy + (yy - cy) / float(zoom)).astype(np.float32)
    ux, uy = bx.copy(), by.copy()
    for _ in range(3):
        d = cv2.remap(depth, ux, uy, cv2.INTER_LINEAR, borderMode=cv2.BORDER_REPLICATE)
        ux = (bx - float(shift[0]) * W * (d - focus)).astype(np.float32)
        uy = (by - float(shift[1]) * H * (d - focus)).astype(np.float32)
    return cv2.remap(img, ux, uy, cv2.INTER_LINEAR, borderMode=cv2.BORDER_REPLICATE)


def ease(t):
    return 0.5 - 0.5 * np.cos(np.pi * np.clip(t, 0, 1))


class Gesture:
    """Paso suave de la foto base a una variante (sonrisa, ojos cerrados) solo en la persona: flujo óptico denso
    (las ediciones de la IA no salen alineadas al píxel) y fundido, con el fondo y el tablero quietos."""

    def __init__(self, base, variant, depth):
        g0 = cv2.cvtColor(base.astype(np.uint8), cv2.COLOR_BGR2GRAY)
        g1 = cv2.cvtColor(variant.astype(np.uint8), cv2.COLOR_BGR2GRAY)
        dis = cv2.DISOpticalFlow_create(cv2.DISOPTICAL_FLOW_PRESET_MEDIUM)
        self.flow = dis.calc(g0, g1, None)
        self.base, self.variant = base, variant
        # La persona: lo cercano de la profundidad, por encima del tablero y las manos.
        m = (depth > np.percentile(depth[: int(H * 0.5)], 55)).astype(np.float32)
        m[int(H * 0.6):, :] = 0
        m = cv2.dilate(m, np.ones((31, 31), np.uint8))
        self.mask = cv2.GaussianBlur(m, (0, 0), 18)[..., None]
        yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
        self.xx, self.yy = xx, yy

    def at(self, t):
        if t <= 0.0:
            return self.base
        fx, fy = self.flow[..., 0], self.flow[..., 1]
        t = float(t)
        a = cv2.remap(self.base, (self.xx - t * fx).astype(np.float32), (self.yy - t * fy).astype(np.float32), cv2.INTER_LINEAR, borderMode=cv2.BORDER_REPLICATE)
        b = cv2.remap(self.variant, (self.xx + (1 - t) * fx).astype(np.float32), (self.yy + (1 - t) * fy).astype(np.float32), cv2.INTER_LINEAR, borderMode=cv2.BORDER_REPLICATE)
        mid = a * (1 - t) + b * t
        return self.base * (1 - self.mask) + mid * self.mask


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("carpeta")
    ap.add_argument("salida")
    ap.add_argument("sala")
    ap.add_argument("rivales", nargs="+")
    ap.add_argument("--sonido", default="")
    a = ap.parse_args()
    c = a.carpeta
    tmp = a.salida + ".sin_sonido.mp4"
    out = cv2.VideoWriter(tmp, cv2.VideoWriter_fourcc(*"mp4v"), FPS, (W, H))
    state = {"last": None, "n": 0}

    def emit(f):
        out.write(np.clip(f, 0, 255).astype(np.uint8))
        state["last"], state["n"] = f, state["n"] + 1
    # 1. Paseo por la sala: 4 s, acercándose, con la profundidad.
    hall = load(f"{c}/salas/{a.sala}_pasillo.jpg")
    hall_d = load(f"{c}/salas/{a.sala}_pasillo_prof.png", gray=True)
    n = int(4.0 * FPS)
    for i in range(n):
        t = ease(i / (n - 1))
        emit(warp(hall, hall_d, (-0.004 + 0.014 * t, -0.016 * t), 0.3, 1.0 + 0.10 * t))
    for r in a.rivales:
        base = load(f"{c}/rivales/{a.sala}/{r}.jpg")
        depth = load(f"{c}/rivales/{a.sala}/{r}_prof.png", gray=True)
        blink = load(f"{c}/rivales/{a.sala}/{r}_parpadeo.jpg")
        smile = load(f"{c}/rivales/{a.sala}/{r}_sonrisa.jpg")
        g_blink = Gesture(base, blink, depth) if blink is not None else None
        g_smile = Gesture(base, smile, depth) if smile is not None else None
        last = state["last"]
        total = int(7.0 * FPS)
        for i in range(total):
            s = i / FPS
            # Vaivén lento de la cámara (respira).
            ph = np.sin(2 * np.pi * s / 6.8)
            shift = (0.007 * ph, -0.004 - 0.004 * np.cos(2 * np.pi * s / 6.8))
            # Sonrisa de 1,3 s a 3,8 s; parpadeos a los 4,6 s y 6,2 s (ojos: 0,08 s cerrando, 0,05 cerrados, 0,1 abriendo).
            # Cambios rápidos (0,2 s), como un gesto: más lentos, el fundido deja ver dos caras a la vez.
            k = ease((s - 1.3) / 0.2) - ease((s - 3.6) / 0.2)
            img = g_smile.at(k) if g_smile is not None and k > 0.001 else base
            for tb in (4.6, 6.2):
                if g_blink is not None and tb <= s < tb + 0.23:
                    u = s - tb
                    kb = min(u / 0.08, 1.0) if u < 0.13 else max(0.0, 1.0 - (u - 0.13) / 0.1)
                    img = g_blink.at(kb)
            f = warp(img, depth, shift, 0.55, 1.0 + 0.02 * ease(s / 7.0))
            if i < int(0.8 * FPS):
                u = ease(i / (0.8 * FPS))
                f = last * (1 - u) + f * u
            emit(f)
    out.release()
    cmd = ["ffmpeg", "-v", "error", "-y", "-i", tmp]
    if a.sonido:
        cmd += ["-stream_loop", "-1", "-i", a.sonido, "-shortest", "-c:a", "aac", "-b:a", "128k", "-af", "volume=0.8"]
    cmd += ["-c:v", "libx264", "-preset", "veryfast", "-crf", "21", "-pix_fmt", "yuv420p", a.salida]
    subprocess.run(cmd, check=True)
    os.remove(tmp)
    print(a.salida, state["n"], "fotogramas")


if __name__ == "__main__":
    main()
