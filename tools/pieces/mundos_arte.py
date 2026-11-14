"""Mundos de piezas del nivel Kids: recorta los personajes de tools/pieces/mundos/fuente.png (la lámina de cinco
mundos que aportó Pablo, generada con IA) y hace un atlas plano por mundo en godot/sets/mundos/<mundo>.bin
(6 × 2 celdas: peón, caballo, alfil, torre, dama, rey; blancas arriba, negras abajo; PNG con otra extensión).

Los personajes van sin ficha, lo más grandes posible. Los bandos se distinguen por el contorno (blanco / azul tinta)
y porque las negras van oscurecidas; una insignia pequeña abajo a la derecha enseña la pieza clásica que es cada
personaje (siluetas propias, de godot/sets/fichas/iconos.bin).

El fondo se quita con rembg (modelo isnet-general-use); solo hace falta para regenerar los atlas:
  pip install rembg onnxruntime scipy
Uso: python3 tools/pieces/mundos_arte.py   (npm run pieces:mundos)
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter
from rembg import new_session, remove
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "tools/pieces/mundos/fuente.png"
OUT = ROOT / "godot/sets/mundos"
CELL = 320
UP = 3  # ampliación antes de recortar
# Franja de cada mundo en la lámina (x0, y0, x1, y1). En la lámina el orden es peón, torre, caballo, alfil, dama, rey.
STRIPS = {
    "reino": (0, 92, 610, 305),
    "safari": (612, 70, 1220, 305),
    "espacio": (0, 478, 405, 650),
    "piratas": (408, 442, 812, 650),
    "dino": (816, 420, 1220, 650),
}
SHEET_ORDER = [0, 3, 1, 2, 4, 5]  # celda del atlas de cada personaje de la lámina
TRIM_TOP = {("safari", 1): 0.30}
# Cada personaje llena su casilla; el peón, algo más pequeño (como en el resto de la app).
FILL = [0.80, 1.0, 1.0, 1.0, 1.0, 1.0]
SIDES = [
    {"line": (255, 255, 255), "badge": (255, 255, 255), "glyph": (37, 46, 78), "mul": (1.0, 1.0, 1.0), "add": 0.0},
    {"line": (22, 27, 52), "badge": (26, 32, 58), "glyph": (255, 246, 226), "mul": (0.62, 0.64, 0.80), "add": 0.0},
]


def split(alpha):
    """Corta la franja en seis personajes por los cinco valles más hondos de la suma por columnas."""
    cols = ndimage.uniform_filter1d((alpha > 100).sum(axis=0).astype(float), 9)
    xs = np.nonzero(cols > 0)[0]
    x0, x1 = xs[0], xs[-1] + 1
    step = (x1 - x0) / 6
    cuts = [x0]
    for k in range(1, 6):
        mid = int(x0 + k * step)
        lo, hi = int(mid - step * 0.38), int(mid + step * 0.38)
        cuts.append(lo + int(np.argmin(cols[lo:hi])))
    cuts.append(x1)
    return list(zip(cuts[:-1], cuts[1:]))


def clean(piece):
    """Deja solo el personaje: su mancha más grande, sin huecos por dentro y con el borde limpio."""
    a = np.asarray(piece.getchannel("A"))
    solid = a > 110
    labels, n = ndimage.label(solid)
    if n > 1:
        sizes = ndimage.sum(solid, labels, range(1, n + 1))
        solid = labels == (1 + int(np.argmax(sizes)))
    solid = ndimage.binary_fill_holes(ndimage.binary_closing(solid, iterations=3))
    soft = Image.fromarray((solid * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2))
    out = piece.copy()
    out.putalpha(soft)
    box = Image.fromarray((solid * 255).astype(np.uint8)).getbbox()
    return out.crop(box)


def glyphs():
    tok = np.asarray(Image.open(ROOT / "godot/sets/fichas/iconos.bin").convert("RGBA"))
    n = tok.shape[1] // 3
    out = []
    for i in range(6):
        cell = tok[(i // 3) * n:(i // 3 + 1) * n, (i % 3) * n:(i % 3 + 1) * n, 2].astype(float) / 255
        mask = Image.fromarray((np.clip((cell - 0.5) * 24 + 0.5, 0, 1) * 255).astype(np.uint8))
        out.append(mask.crop(mask.point(lambda v: 255 if v > 128 else 0).getbbox()))
    return out


def outlined(piece, side, line_px):
    arr = np.asarray(piece).astype(float)
    arr[..., :3] = np.clip(arr[..., :3] * side["mul"], 0, 255)
    body = Image.fromarray(arr.astype(np.uint8))
    pad = line_px + 2
    canvas = Image.new("RGBA", (piece.width + 2 * pad, piece.height + 2 * pad), (0, 0, 0, 0))
    grown = Image.new("L", canvas.size, 0)
    grown.paste(piece.getchannel("A"), (pad, pad))
    grown = grown.filter(ImageFilter.MaxFilter(2 * line_px + 1)).filter(ImageFilter.GaussianBlur(0.8))
    canvas.paste(Image.new("RGBA", canvas.size, side["line"] + (255,)), (0, 0), grown)
    canvas.alpha_composite(body, (pad, pad))
    return canvas


def main():
    sheet = Image.open(SRC).convert("RGB")
    session = new_session("isnet-general-use")
    marks = glyphs()
    OUT.mkdir(parents=True, exist_ok=True)
    previews = []
    for world, box in STRIPS.items():
        strip = sheet.crop(box)
        strip = strip.resize((strip.width * UP, strip.height * UP), Image.LANCZOS)
        cut = remove(strip, session=session)
        alpha = np.asarray(cut.getchannel("A"))
        pieces = []
        for i, (a, b) in enumerate(split(alpha)):
            part = cut.crop((a, 0, b, cut.height))
            trim = TRIM_TOP.get((world, i), 0.0)
            if trim > 0.0:  # quita lo que hay encima del personaje (el árbol sobre el elefante)
                part.paste((0, 0, 0, 0), (0, 0, part.width, round(part.height * trim)))
            pieces.append(clean(part))
        line = max(3, round(CELL * 0.022))
        room = CELL - 2 * (line + 3)
        atlas = Image.new("RGBA", (CELL * 6, CELL * 2), (0, 0, 0, 0))
        for i, piece in enumerate(pieces):
            cell = SHEET_ORDER[i]
            scale = FILL[i] * min(room / piece.height, room / piece.width)
            small = piece.resize((max(1, round(piece.width * scale)), max(1, round(piece.height * scale))), Image.LANCZOS)
            for row, side in enumerate(SIDES):
                art = outlined(small, side, line)
                x = cell * CELL + (CELL - art.width) // 2
                y = row * CELL + CELL - art.height - 1
                atlas.alpha_composite(art, (x, y))
                # Insignia con la pieza clásica.
                r = round(CELL * 0.115)
                cx, cy = cell * CELL + CELL - r - 5, row * CELL + CELL - r - 5
                disc = Image.new("L", (4 * r + 12, 4 * r + 12), 0)
                dd = np.hypot(*np.mgrid[-2 * r - 6:2 * r + 6, -2 * r - 6:2 * r + 6] / 2.0)
                ring = Image.fromarray((np.clip(r + 3 - dd, 0, 1) * 255).astype(np.uint8)).resize((2 * r + 6, 2 * r + 6), Image.LANCZOS)
                inner = Image.fromarray((np.clip(r - dd, 0, 1) * 255).astype(np.uint8)).resize((2 * r + 6, 2 * r + 6), Image.LANCZOS)
                atlas.paste(Image.new("RGBA", ring.size, SIDES[1 - row]["badge"] + (255,)) if False else Image.new("RGBA", ring.size, side["glyph"] + (255,)), (cx - r - 3, cy - r - 3), ring)
                atlas.paste(Image.new("RGBA", inner.size, side["badge"] + (255,)), (cx - r - 3, cy - r - 3), inner)
                g = marks[cell]
                gh = round(r * 1.4)
                g = g.resize((max(1, round(g.width * gh / g.height)), gh), Image.LANCZOS)
                atlas.paste(Image.new("RGBA", g.size, side["glyph"] + (255,)), (cx - g.width // 2, cy - g.height // 2), g)
        atlas.save(OUT / f"{world}.bin", format="PNG", optimize=True)
        prev = Image.new("RGBA", atlas.size)
        for r_ in range(2):
            for c in range(6):
                col = (220, 234, 250, 255) if (r_ + c) % 2 == 0 else (124, 166, 216, 255)
                prev.paste(col, (c * CELL, r_ * CELL, (c + 1) * CELL, (r_ + 1) * CELL))
        prev.alpha_composite(atlas)
        previews.append(prev)
        print(world)
    sheet_prev = Image.new("RGBA", (CELL * 6, CELL * 2 * len(previews)))
    for i, p in enumerate(previews):
        sheet_prev.paste(p, (0, i * CELL * 2))
    (ROOT / "shots").mkdir(exist_ok=True)
    sheet_prev.save(ROOT / "shots/piezas-mundos.png")


if __name__ == "__main__":
    main()
