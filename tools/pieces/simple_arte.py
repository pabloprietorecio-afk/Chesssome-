"""Juego de piezas «Simple»: recorta el dibujo de tools/pieces/simple/fuente.png (6 × 2 casillas: peón, caballo,
alfil, torre, dama, rey; blancas arriba, negras abajo, sobre casillas azules) y lo deja con fondo transparente en
godot/sets/simple/iconos.bin (atlas PNG de 6 × 2 celdas cuadradas, con otra extensión).

El fondo azul se quita rellenando desde los bordes de cada casilla todo lo que es azul y claro; el contorno oscuro de
las piezas frena el relleno. Todas las piezas usan la misma escala y la misma línea de base, así que el peón sigue
siendo más pequeño que las demás, como en el dibujo.

Uso: python3 tools/pieces/simple_arte.py   (npm run pieces:simple)
"""
from collections import deque
from pathlib import Path

from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "tools/pieces/simple/fuente.png"
OUT = ROOT / "godot/sets/simple/iconos.bin"
PREVIEW = ROOT / "shots/piezas-simple.png"
CELL = 320  # lado de cada celda del atlas
FILL = 0.94  # la pieza más grande ocupa este tanto de su celda
HOLE = 150  # área mínima (px) de un hueco azul cerrado para tratarlo como fondo


def is_bg(p):
    r, g, b = p[:3]
    return b - r > 38 and b > 150


def fill(px, w, h, bg, q, mark):
    """Rellena desde q todo lo azul aún sin marcar; devuelve los índices marcados."""
    seen = []
    while q:
        x, y = q.popleft()
        i = y * w + x
        if bg[i] or not is_bg(px[x, y]):
            continue
        bg[i] = mark
        seen.append(i)
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h and not bg[ny * w + nx]:
                q.append((nx, ny))
    return seen


def cut(cell):
    w, h = cell.size
    px = cell.load()
    bg = bytearray(w * h)
    q = deque()
    for x in range(w):
        q.extend([(x, 0), (x, h - 1)])
    for y in range(h):
        q.extend([(0, y), (w - 1, y)])
    fill(px, w, h, bg, q, 1)
    # Huecos cerrados por la pieza (la ranura del alfil): también fondo si son azules y no diminutos.
    for y in range(h):
        for x in range(w):
            if not bg[y * w + x] and is_bg(px[x, y]):
                seen = fill(px, w, h, bg, deque([(x, y)]), 2)
                if len(seen) >= HOLE:
                    for i in seen:
                        bg[i] = 1

    mask = Image.frombytes("L", (w, h), bytes(0 if v == 1 else 255 for v in bg))
    # Suaviza el borde: quita el pixel de halo azul y difumina medio pixel.
    mask = mask.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.7))
    out = cell.convert("RGBA")
    out.putalpha(mask)
    return out


def main():
    src = Image.open(SRC).convert("RGB")
    n = src.width // 6
    pieces = [[cut(src.crop((c * n, r * n, c * n + n, r * n + n))) for c in range(6)] for r in range(2)]
    boxes = [[p.getchannel("A").point(lambda a: 255 if a > 40 else 0).getbbox() for p in row] for row in pieces]
    top = min(b[1] for row in boxes for b in row)
    bottom = max(b[3] for row in boxes for b in row)
    widest = max(b[2] - b[0] for row in boxes for b in row)
    scale = FILL * CELL / max(bottom - top, widest)
    atlas = Image.new("RGBA", (CELL * 6, CELL * 2), (0, 0, 0, 0))
    for r in range(2):
        for c in range(6):
            b = boxes[r][c]
            piece = pieces[r][c].crop((b[0], top, b[2], bottom))
            size = (round(piece.width * scale), round(piece.height * scale))
            piece = piece.resize(size, Image.LANCZOS)
            x = c * CELL + (CELL - size[0]) // 2
            y = r * CELL + (CELL - size[1]) // 2
            atlas.alpha_composite(piece, (x, y))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(OUT, format="PNG", optimize=True)
    prev = Image.new("RGBA", atlas.size)
    for r in range(2):
        for c in range(6):
            col = (238, 238, 210, 255) if (r + c) % 2 == 0 else (118, 150, 86, 255)
            prev.paste(col, (c * CELL, r * CELL, (c + 1) * CELL, (r + 1) * CELL))
    prev.alpha_composite(atlas)
    PREVIEW.parent.mkdir(parents=True, exist_ok=True)
    prev.save(PREVIEW)
    print(OUT, atlas.size, "escala", round(scale, 3))


if __name__ == "__main__":
    main()
