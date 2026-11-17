#!/usr/bin/env python3
"""Genera los iconos de la app (lanzador, adaptativo, arranque y el de 512 para Google Play) a partir del icono
del inicio: godot/ui/inicio/icono.bin (el caballo marfil en 3D sobre tesela naranja; ver tools/inicio/icono.py).
Uso: python3 tools/logo/iconos_app.py   (desde la raíz del repositorio)"""
from PIL import Image, ImageFilter, ImageDraw
import os

SRC = "godot/ui/inicio/icono.bin"
OUT = "godot/iconos_app"
src = Image.open(SRC).convert("RGBA")          # 512 × 512, esquinas redondeadas con transparencia
W = src.width


def gradient_from_edge(size: int) -> Image.Image:
    """Degradado vertical con los naranjas del borde de la tesela (franja justo dentro, a la izquierda)."""
    x = int(W * 0.04)
    col = [src.getpixel((x, y))[:3] for y in range(int(W * 0.30), int(W * 0.70))]
    top = src.getpixel((W // 2, int(W * 0.03)))[:3]
    bottom = src.getpixel((W // 2, W - int(W * 0.03)))[:3]
    img = Image.new("RGB", (size, size))
    d = ImageDraw.Draw(img)
    for y in range(size):
        t = y / (size - 1)
        c = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        d.line([(0, y), (size, y)], fill=c)
    return img.convert("RGBA")


def inner_square(frac: float) -> Image.Image:
    """Cuadrado central opaco de la tesela (sin las esquinas transparentes)."""
    m = int(W * (1.0 - frac) / 2.0)
    return src.crop((m, m, W - m, W - m))


def feather(img: Image.Image, px: int) -> Image.Image:
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rectangle([px, px, img.width - px, img.height - px], fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(px / 2.0))
    out = img.copy()
    out.putalpha(mask)
    return out


# Lanzador clásico: la tesela entera, con sus esquinas.
src.resize((192, 192), Image.LANCZOS).save(f"{OUT}/lanzador_192.png")

# Adaptativo: fondo = degradado naranja; frente = el centro de la tesela difuminado en los bordes (la máscara del
# móvil —círculo, gota…— recorta fuera de los 288 px centrales, así que el caballo queda dentro).
gradient_from_edge(432).save(f"{OUT}/adaptativo_fondo_432.png")
core = inner_square(0.84).resize((262, 262), Image.LANCZOS)
core = feather(core, 14)
front = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
front.alpha_composite(core, ((432 - 262) // 2, (432 - 262) // 2))
front.save(f"{OUT}/adaptativo_frente_432.png")

# Arranque (Android 12 lo recorta en círculo): la tesela entera algo más pequeña, sobre transparente.
splash = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
t = src.resize((250, 250), Image.LANCZOS)
splash.alpha_composite(t, ((432 - 250) // 2, (432 - 250) // 2))
splash.save(f"{OUT}/arranque_432.png")

# Google Play: 512 × 512, cuadrada y sin esquinas transparentes (Play aplica su máscara).
play = Image.new("RGBA", (512, 512), (0, 0, 0, 255))
play.alpha_composite(gradient_from_edge(512), (0, 0))
play.alpha_composite(src, (0, 0))
os.makedirs("docs/play", exist_ok=True)
play.convert("RGB").save("docs/play/icono_512.png")
print("listo")
