"""Genera los fondos del cuadro del campeonato (godot/textures/campeonato/): corcho, pantalla gigante y público de
espaldas. Todo procedural (sin fotos con derechos): `python3 tools/campeonato/escenario.py`."""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "godot", "textures", "campeonato")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)


def blur_wrap(a, sigma):
    """Desenfoque gaussiano con bordes que se enlazan (para que el corcho se pueda repetir)."""
    f = np.fft.fft2(a)
    ky = np.fft.fftfreq(a.shape[0])[:, None]
    kx = np.fft.fftfreq(a.shape[1])[None, :]
    g = np.exp(-2 * (np.pi * sigma) ** 2 * (kx ** 2 + ky ** 2))
    return np.real(np.fft.ifft2(f * g))


def norm(a):
    return (a - a.min()) / (a.max() - a.min() + 1e-9)


def corcho(n=1024):
    base = np.zeros((n, n))
    for sigma, w in [(1.2, 0.5), (3, 0.9), (8, 1.0), (24, 0.7)]:
        base += w * norm(blur_wrap(rng.standard_normal((n, n)), sigma))
    base = norm(base)
    # Gránulos: manchas oscuras y claras sueltas.
    gran = norm(blur_wrap(rng.standard_normal((n, n)), 1.6))
    oscuros = (gran < 0.18).astype(float)
    oscuros = blur_wrap(oscuros, 0.8)
    claros = (gran > 0.86).astype(float)
    claros = blur_wrap(claros, 0.8)
    c1 = np.array([196, 146, 92], float)   # tono medio
    c2 = np.array([226, 182, 124], float)  # claro
    c3 = np.array([120, 78, 42], float)    # oscuro
    img = c1[None, None, :] * (1 - base[..., None]) + c2[None, None, :] * base[..., None]
    img = img * (1 - 0.55 * oscuros[..., None]) + c3[None, None, :] * 0.55 * oscuros[..., None]
    img = img + 22 * claros[..., None]
    fino = norm(blur_wrap(rng.standard_normal((n, n)), 0.9))
    medio = norm(blur_wrap(rng.standard_normal((n, n)), 2.5))
    img *= (0.80 + 0.40 * fino * 0.6 + 0.40 * medio * 0.4)[..., None]
    pits = blur_wrap((norm(blur_wrap(rng.standard_normal((n, n)), 2.0)) < 0.07).astype(float), 1.0)
    img = img * (1 - 0.7 * np.clip(pits * 3, 0, 1))[..., None] + np.array([70, 40, 20])[None, None, :] * 0.7 * np.clip(pits * 3, 0, 1)[..., None]
    img *= (0.92 + 0.16 * norm(blur_wrap(rng.standard_normal((n, n)), 60)))[..., None]
    Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).save(os.path.join(OUT, "corcho.jpg"), quality=90)


def pantalla(w=1024, h=1024):
    y = np.linspace(0, 1, h)[:, None]
    x = np.linspace(0, 1, w)[None, :]
    top = np.array([24, 36, 84], float)
    bot = np.array([10, 14, 40], float)
    glow = np.exp(-(((x - 0.5) / 0.55) ** 2 + ((y - 0.25) / 0.45) ** 2))
    img = top * (1 - y[..., None]) + bot * y[..., None]
    img = img + glow[..., None] * np.array([40, 60, 120])
    # Rejilla de píxeles de pantalla LED.
    gx = (np.arange(w) % 8 == 0).astype(float)[None, :]
    gy = (np.arange(h) % 8 == 0).astype(float)[:, None]
    img = img * (1 - 0.18 * np.maximum(gx, gy))[..., None]
    Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).save(os.path.join(OUT, "pantalla.jpg"), quality=90)


def persona(d, cx, base_y, s, color, rim, rnd):
    """Una persona de espaldas: hombros, cuello y cabeza (con pelo, moño o gorro)."""
    sh_w = 1.0 * s
    sh_h = 0.62 * s
    head_r = 0.30 * s
    d.rounded_rectangle([cx - sh_w, base_y - sh_h, cx + sh_w, base_y + 0.2 * s], radius=0.55 * s, fill=color)
    d.rectangle([cx - 0.12 * s, base_y - sh_h - 0.18 * s, cx + 0.12 * s, base_y - sh_h + 0.1 * s], fill=color)
    hy = base_y - sh_h - 0.18 * s - head_r * 0.9
    tall = 1.0 + rnd.uniform(-0.05, 0.1)
    d.ellipse([cx - head_r, hy - head_r * tall, cx + head_r, hy + head_r * tall], fill=color)
    kind = rnd.integers(0, 6)
    if kind == 0:  # moño
        d.ellipse([cx - 0.12 * s, hy - head_r * tall - 0.16 * s, cx + 0.12 * s, hy - head_r * tall + 0.1 * s], fill=color)
    elif kind == 1:  # pelo largo
        d.rounded_rectangle([cx - head_r * 0.95, hy, cx + head_r * 0.95, hy + 0.55 * s], radius=0.2 * s, fill=color)
    elif kind == 2:  # gorra
        d.rectangle([cx - head_r * 1.12, hy - 0.04 * s, cx + head_r * 1.12, hy + 0.04 * s], fill=color)
    # Luz de borde por arriba.
    d.arc([cx - head_r, hy - head_r * tall, cx + head_r, hy + head_r * tall], 205, 335, fill=rim, width=max(2, int(0.035 * s)))
    d.arc([cx - sh_w, base_y - sh_h, cx - sh_w + 1.1 * s, base_y - sh_h + 1.1 * s], 180, 270, fill=rim, width=max(2, int(0.03 * s)))
    d.arc([cx + sh_w - 1.1 * s, base_y - sh_h, cx + sh_w, base_y - sh_h + 1.1 * s], 270, 360, fill=rim, width=max(2, int(0.03 * s)))


def publico(w=1080, h=210, fila=0):
    k = 2  # supermuestreo
    img = Image.new("RGBA", (w * k, h * k), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rnd = np.random.default_rng(31 + fila)
    if fila == 0:  # fondo: más lejos, más pequeño y más claro
        s, color, rim, step, y0 = 46 * k, (44, 48, 84, 255), (120, 130, 190, 255), 62 * k, h * k * 0.72
    else:  # delante: grande y casi negro
        s, color, rim, step, y0 = 70 * k, (14, 16, 38, 255), (70, 80, 140, 255), 104 * k, h * k * 1.02
    x = -step * 0.3
    while x < w * k + step:
        jitter = rnd.uniform(-0.18, 0.18) * step
        ss = s * rnd.uniform(0.88, 1.1)
        persona(d, x + jitter, y0 + rnd.uniform(-0.12, 0.12) * s, ss, color, rim, rnd)
        x += step * rnd.uniform(0.8, 1.15)
    img = img.resize((w, h), Image.LANCZOS)
    img.save(os.path.join(OUT, "publico_%d.png" % fila))


corcho()
pantalla()
publico(fila=0)
publico(fila=1)
print("hecho en", os.path.abspath(OUT))
