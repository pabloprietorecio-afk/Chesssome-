#!/usr/bin/env python3
"""Dibuja el escudo de War Chess (pieza blindada) y su versión agrietada (el golpe que rompe el blindaje).

Arte propio, sin nada ajeno: un escudo de punta («heater») con ribete de latón, campo rojo con un brillo de
metal, un cheurón de acero, un umbo de latón y remaches (sin cruces ni símbolos con otro significado). Se dibuja a 4 veces el tamaño y se reduce (bordes suaves).
Salida: PNG con extensión .bin (Godot no los importa ni los comprime):
  godot/board3d/escudo.bin       escudo entero
  godot/board3d/escudo_roto.bin  el mismo con grietas
El peón atrincherado (dos golpes) se dibuja con dos escudos superpuestos: no necesita otro dibujo.
Uso: python3 tools/war/escudo.py [vista_previa.png]
"""
import math
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')
W, H = 192, 224
S = 4  # supersampling


def shield_path(w, h, inset):
    """Contorno del escudo: arriba casi recto (un poco combado), lados que bajan rectos y se curvan a la punta."""
    pts = []
    top = inset + h * 0.06
    left, right = inset, w - inset
    tip = h - inset
    # Borde superior: dos picos en las esquinas y una leve curva hacia abajo en el centro.
    for i in range(41):
        t = i / 40
        x = left + (right - left) * t
        y = top + math.sin(t * math.pi) * h * 0.035
        pts.append((x, y))
    # Lado derecho: recto hasta el 42 % y luego una curva hasta la punta.
    side = top + (tip - top) * 0.42
    pts.append((right, side))
    for i in range(1, 41):
        t = i / 40
        # Curva tipo cuarto de elipse deformado.
        ang = t * math.pi / 2
        x = right - (right - w / 2) * (1 - math.cos(ang)) ** 0.9
        y = side + (tip - side) * math.sin(ang) ** 1.15
        pts.append((x, y))
    for i in range(39, 0, -1):
        t = i / 40
        ang = t * math.pi / 2
        x = left + (w / 2 - left) * (1 - math.cos(ang)) ** 0.9
        y = side + (tip - side) * math.sin(ang) ** 1.15
        pts.append((x, y))
    pts.append((left, side))
    return pts


def mask_of(pts, w, h):
    m = Image.new('L', (w, h), 0)
    ImageDraw.Draw(m).polygon(pts, fill=255)
    return m


def vgrad(w, h, c0, c1, power=1.0):
    img = Image.new('RGB', (w, h))
    px = img.load()
    for y in range(h):
        t = (y / (h - 1)) ** power
        c = tuple(int(c0[i] + (c1[i] - c0[i]) * t) for i in range(3))
        for x in range(w):
            px[x, y] = c
    return img


def draw(cracked):
    w, h = W * S, H * S
    out = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    outer = shield_path(w, h, 6 * S)
    rim_w = 15 * S
    inner = shield_path(w, h, 6 * S + rim_w)
    m_outer = mask_of(outer, w, h)
    m_inner = mask_of(inner, w, h)

    # Contorno oscuro (se lee sobre cualquier tablero).
    dark = m_outer.filter(ImageFilter.MaxFilter(2 * S + 1))
    out.paste((38, 24, 14, 255), (0, 0), dark)
    # Ribete de latón: degradado vertical con brillo arriba.
    brass = vgrad(w, h, (255, 228, 150), (150, 98, 36), 1.1)
    out.paste(brass, (0, 0), m_outer)
    # Biselado del ribete: una línea clara por dentro del borde exterior.
    bevel = ImageChops.subtract(m_outer, m_outer.filter(ImageFilter.MinFilter(2 * S + 1)))
    out.paste((255, 244, 205, 255), (0, 0), bevel)
    # Campo rojo: más claro arriba a la izquierda.
    field = vgrad(w, h, (226, 58, 52), (122, 18, 26), 0.9)
    out.paste(field, (0, 0), m_inner)
    # Sombra interior del ribete sobre el campo.
    inner_shadow = ImageChops.subtract(m_inner, m_inner.filter(ImageFilter.MinFilter(5 * S + 1))).filter(ImageFilter.GaussianBlur(3 * S))
    out.paste((60, 6, 10, 255), (0, 0), ImageChops.multiply(inner_shadow, m_inner).point(lambda v: int(v * 0.7)))
    # Cruz de acero (franjas vertical y horizontal) dentro del campo.
    steel = vgrad(w, h, (236, 240, 246), (120, 130, 146), 1.0)
    cross = Image.new('L', (w, h), 0)
    cd = ImageDraw.Draw(cross)
    band = 15 * S
    cx = w // 2
    cy = int(h * 0.40)
    # Cheurón: una banda en V invertida que sube hasta el umbo.
    apex = (cx, cy - 4 * S)
    for x0 in (0, w):
        foot = (x0, cy + h * 0.42)
        cd.line([foot, apex], fill=255, width=band)
    cd.ellipse((apex[0] - band // 2, apex[1] - band // 2, apex[0] + band // 2, apex[1] + band // 2), fill=255)
    cross = ImageChops.multiply(cross, m_inner)
    out.paste((50, 40, 44, 255), (0, 0), cross.filter(ImageFilter.MaxFilter(S * 2 + 1)))
    out.paste(steel, (0, 0), cross)
    # Umbo (botón central de metal).
    r = 21 * S
    boss = Image.new('L', (w, h), 0)
    ImageDraw.Draw(boss).ellipse((cx - r, cy - r, cx + r, cy + r), fill=255)
    out.paste((40, 34, 36, 255), (0, 0), boss.filter(ImageFilter.MaxFilter(S * 2 + 1)))
    boss_img = Image.new('RGB', (w, h))
    bp = boss_img.load()
    for y in range(cy - r - 2, cy + r + 2):
        for x in range(cx - r - 2, cx + r + 2):
            dx, dy = (x - cx) / r, (y - cy) / r
            d = min(1.0, math.hypot(dx, dy))
            # Luz desde arriba a la izquierda sobre una cúpula.
            nz = math.sqrt(max(0.0, 1 - d * d))
            light = max(0.0, (-dx * 0.5 - dy * 0.6 + nz * 0.62))
            v = 90 + 165 * min(1.0, light)
            bp[x, y] = (int(v * 1.0), int(v * 0.86), int(v * 0.55))
    out.paste(boss_img, (0, 0), boss)
    # Remaches en el ribete.
    for t in (0.1, 0.5, 0.9):
        for (px, py) in [(6 * S + rim_w / 2 + (w - 2 * (6 * S + rim_w / 2)) * t, 6 * S + h * 0.06 + rim_w / 2 + math.sin(t * math.pi) * h * 0.035)]:
            _rivet(out, px, py, 4.2 * S)
    for side in (0, 1):
        x = 6 * S + rim_w / 2 if side == 0 else w - 6 * S - rim_w / 2
        _rivet(out, x, h * 0.36, 4.2 * S)
    _rivet(out, w / 2, h - 6 * S - rim_w * 0.85, 4.2 * S)
    # Brillo de metal: una franja diagonal suave sobre todo el escudo.
    gloss = Image.new('L', (w, h), 0)
    gd = ImageDraw.Draw(gloss)
    gd.polygon([(w * 0.08, h * 0.05), (w * 0.42, h * 0.05), (w * 0.12, h * 0.62), (w * 0.0, h * 0.5)], fill=70)
    gloss = gloss.filter(ImageFilter.GaussianBlur(10 * S))
    gloss = ImageChops.multiply(gloss, m_outer)
    white = Image.new('RGBA', (w, h), (255, 255, 255, 255))
    out = Image.composite(Image.blend(out, white, 0.0), out, Image.new('L', (w, h), 0))
    out.paste((255, 255, 255, 255), (0, 0), gloss)

    if cracked:
        _cracks(out, m_outer, w, h)
    # Reducción con buen filtro.
    return out.resize((W, H), Image.LANCZOS)


def _rivet(img, x, y, r):
    d = ImageDraw.Draw(img)
    d.ellipse((x - r - 2, y - r - 2, x + r + 2, y + r + 2), fill=(70, 46, 20, 255))
    d.ellipse((x - r, y - r, x + r, y + r), fill=(205, 170, 96, 255))
    d.ellipse((x - r * 0.65, y - r * 0.75, x + r * 0.1, y - r * 0.05), fill=(255, 246, 214, 255))


def _cracks(img, mask, w, h):
    """Grietas que salen de un punto de impacto, con su borde claro (el metal doblado)."""
    import random
    rnd = random.Random(7)
    ix, iy = w * 0.64, h * 0.27
    lines = []
    for k in range(6):
        ang = -math.pi / 2 + k * (2 * math.pi / 6) + rnd.uniform(-0.3, 0.3)
        x, y = ix, iy
        seg = [(x, y)]
        length = rnd.uniform(0.28, 0.5) * h
        steps = 6
        for _ in range(steps):
            ang += rnd.uniform(-0.45, 0.45)
            x += math.cos(ang) * length / steps
            y += math.sin(ang) * length / steps
            seg.append((x, y))
        lines.append(seg)
    crack = Image.new('L', (w, h), 0)
    hl = Image.new('L', (w, h), 0)
    cd = ImageDraw.Draw(crack)
    hd = ImageDraw.Draw(hl)
    for seg in lines:
        for i in range(len(seg) - 1):
            width = int(max(S, (len(seg) - i) * 0.55 * S))
            cd.line([seg[i], seg[i + 1]], fill=255, width=width)
            hd.line([(seg[i][0] + 2 * S, seg[i][1] + 2 * S), (seg[i + 1][0] + 2 * S, seg[i + 1][1] + 2 * S)], fill=200, width=max(1, width // 2))
    # Hendidura del impacto.
    cd.ellipse((ix - 5 * S, iy - 5 * S, ix + 5 * S, iy + 5 * S), fill=255)
    img.paste((255, 236, 200, 255), (0, 0), ImageChops.multiply(hl, mask))
    img.paste((26, 14, 12, 255), (0, 0), ImageChops.multiply(crack, mask))


def main():
    a = draw(False)
    b = draw(True)
    for img, name in ((a, 'escudo.bin'), (b, 'escudo_roto.bin')):
        img.save(os.path.join(ROOT, 'godot', 'board3d', name), format='PNG', optimize=True)
        print(name, img.size)
    if len(sys.argv) > 1:
        prev = Image.new('RGBA', (W * 2 + 60, H + 40), (234, 241, 251, 255))
        prev.alpha_composite(a, (20, 20))
        prev.alpha_composite(b, (W + 40, 20))
        prev.save(sys.argv[1])


if __name__ == '__main__':
    main()
