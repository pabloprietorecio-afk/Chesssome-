# Fondo de la cabecera de «A Chess Way»: ondas y bruma pintadas por código + rey y peones renderizados (piezas.py).
# Todo se define en píxeles de diseño (pantalla de 390 de ancho); S es el factor de salida (6 -> 2340 px de ancho).
#
# Uso:  python3 fondo.py 6 rey_dia.npy peon_dia.npy fondo-cabecera            (de día)
#       python3 fondo.py 6 rey_noche.npy peon_noche.npy fondo-noche --noche   (tema oscuro)
import sys, math, json
import numpy as np, cv2
from scipy.interpolate import splprep, splev
from scipy.spatial import cKDTree

W0, H0 = 390, 256                 # caja de la cabecera en píxeles de diseño
PAGINA = "#E7E4F1"                # color de la página al que tiene que llegar el fondo por abajo


def hx(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], float) / 255


def lin(c):
    c = np.asarray(c, float)
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def srgb(x):
    x = np.clip(x, 0, 1)
    return np.where(x <= 0.0031308, 12.92 * x, 1.055 * x ** (1 / 2.4) - 0.055)


def ss(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def curva(pts, paso=0.02):
    pts = np.asarray(pts, float)
    tck, _ = splprep(pts.T, s=0, k=3)
    u = np.linspace(0, 1, 4000)
    p = np.array(splev(u, tck)).T
    largo = np.hypot(*np.diff(p, axis=0).T).sum()
    u = np.linspace(0, 1, int(largo / paso) + 2)
    return np.array(splev(u, tck)).T


def distancia(c, X, Y, S, Sd=2):
    """Distancia con signo (px de diseño) al borde c; negativa a la derecha del sentido de avance (y hacia abajo).
    Se calcula en una rejilla gruesa (Sd) y se amplía: el campo es suave y así sale rápido y sin dientes."""
    w, h = W0 * Sd, H0 * Sd
    x, y = np.meshgrid((np.arange(w) + 0.5) / Sd, (np.arange(h) + 0.5) / Sd)
    p = np.c_[x.ravel(), y.ravel()]
    d, i = cKDTree(c).query(p, workers=-1)
    t = np.gradient(c, axis=0)[i]
    v = p - c[i]
    signo = np.where(t[:, 0] * v[:, 1] - t[:, 1] * v[:, 0] > 0, -1.0, 1.0)
    f = (d * signo).reshape(h, w).astype(np.float32)
    return cv2.resize(f, (X.shape[1], X.shape[0]), interpolation=cv2.INTER_CUBIC).astype(np.float64)


def blob(X, Y, cx, cy, rx, ry):
    return np.exp(-(((X - cx) / rx) ** 2 + ((Y - cy) / ry) ** 2))


# ----------------------------------------------------------------------------- composición (en px de diseño)
REY_X, REY_BASE, REY_ALTO = 326.0, 203.0, 122.0
PEONES = [                        # x, base, alto, desenfoque (px de diseño), bruma
    dict(x=243.0, base=199.0, alto=45.0, blur=1.5, bruma=0.30),
    dict(x=375.0, base=196.0, alto=40.0, blur=2.1, bruma=0.46),
]
ONDA_MAYOR = [(-40, 126), (20, 150), (85, 171), (150, 178), (212, 164), (260, 135), (292, 101), (313, 72), (337, 44), (368, 22), (430, -4)]
ONDA_DERECHA = [(262, 290), (292, 232), (322, 196), (352, 168), (378, 140), (430, 92)]


DIA = dict(
    pagina="#E7E4F1", cielo="#E5E6F4", cielo_izq="#ECE8F2", cielo_azul="#DAE0F6", cielo_dcha="#E6E3F0", halo_rosa="#F1E5E8", halo="#FDF3EB",
    colina="#F3E9EA", colina_dcha="#E8E2EC", colina_ancho="#F8E7DC", brasa="#F6D7C6", colina_izq="#EADFE5", canto="#FFFFFF", canto_f=1.0,
    onda="#E4E8F9", onda_dentro="#DDE1F3", sombra=(0.052, 0.050, 0.030), bruma_pieza="#F6EDEE", sombra_rey=(0.55, 0.72, 0.62), halo_rey=(0.050, 0.068, 0.058))
NOCHE = dict(
    pagina="#101533", cielo="#0F1535", cielo_izq="#14133A", cielo_azul="#151E4B", cielo_dcha="#131740", halo_rosa="#221A44", halo="#3A2A52",
    colina="#1B1F4D", colina_dcha="#1A2153", colina_ancho="#2E2450", brasa="#5A3046", colina_izq="#161A42", canto="#8F9BE0", canto_f=0.75,
    onda="#1E2A62", onda_dentro="#182050", sombra=(0.20, 0.20, 0.14), bruma_pieza="#1B2150", sombra_rey=(0.5, 0.5, 0.4), halo_rey=(0.10, 0.10, 0.07))
P = DIA


def fondo(S):
    W, H = W0 * S, H0 * S
    X, Y = np.meshgrid((np.arange(W) + 0.5) / S, (np.arange(H) + 0.5) / S)
    aa = 0.7 / S
    mez = lambda img, color, peso: img + (hx(color) - img) * np.clip(peso, 0, 1)[:, :, None]
    canto = hx(P["canto"])

    d1 = distancia(curva(ONDA_MAYOR), X, Y, S)
    d2 = distancia(curva(ONDA_DERECHA), X, Y, S)

    # cielo: lila azulado arriba (más azul a la derecha, más rosado a la izquierda)...
    img = np.empty((H, W, 3))
    img[:] = hx(P["cielo"])
    img = mez(img, P["cielo_izq"], 0.95 * blob(X, Y, 0, 10, 150, 110))
    img = mez(img, P["cielo_azul"], 0.95 * blob(X, Y, 300, 0, 125, 66))
    img = mez(img, P["cielo_dcha"], 0.70 * blob(X, Y, 400, 60, 60, 70))
    # ...y un resplandor cálido que sube desde el canto de la onda, como un amanecer detrás de la colina
    sobre = np.maximum(d1, 0)
    bajo = ss(8, 150, Y)                                                                       # el resplandor no llega al cielo de arriba
    img = mez(img, P["halo_rosa"], 0.62 * np.exp(-sobre / 95) * np.exp(-((X - 110) / 200) ** 2) * bajo)
    gx = np.exp(-((X - 185) / 125) ** 2) * bajo
    img = mez(img, P["halo"], (0.62 * np.exp(-sobre / 24) + 0.74 * np.exp(-sobre / 88)) * gx)

    # onda mayor: la colina que cruza la cabecera y sube hacia la derecha; melocotón encendido junto al canto, a la izquierda
    dentro = ss(aa, -aa, d1)
    prof = np.maximum(-d1, 0)
    col = np.empty((H, W, 3))
    col[:] = hx(P["colina"])
    col = mez(col, P["colina_dcha"], 0.92 * ss(215, 345, X + (140 - Y) * 0.25))               # hacia la derecha, lila rosado
    col = mez(col, P["colina_ancho"], 0.90 * blob(X, Y, 150, 196, 150, 46))                    # melocotón ancho
    col = mez(col, P["brasa"], 0.95 * blob(X, Y, 70, 185, 84, 28))                             # brasa
    col = mez(col, P["colina_izq"], 0.70 * blob(X, Y, -10, 176, 34, 40))                       # el extremo izquierdo se apaga
    grueso = 0.20 + 0.16 * ss(215, 300, X)                                                     # en la subida, el canto se ve más grueso
    col = col + (canto - col) * (P["canto_f"] * (0.60 * np.exp(-prof / 0.9) + grueso * np.exp(-prof / 9.0)))[:, :, None]   # canto luminoso
    img = img * (1 - dentro[:, :, None]) + col * dentro[:, :, None]

    # onda de la derecha: lila azulado, por delante de la colina y por detrás de las piezas
    dentro = ss(aa, -aa, d2)
    prof = np.maximum(-d2, 0)
    fuera = np.maximum(d2, 0)
    img *= 1 - (np.array(P["sombra"]) * np.exp(-fuera / 26)[:, :, None])                        # su sombra sobre la colina
    col = np.empty((H, W, 3))
    col[:] = hx(P["onda"])
    col = mez(col, P["onda_dentro"], 1 - np.exp(-prof / 44))
    col = col + (canto - col) * (P["canto_f"] * (0.55 * np.exp(-prof / 0.9) + 0.16 * np.exp(-prof / 7.0)))[:, :, None]
    img = img * (1 - dentro[:, :, None]) + col * dentro[:, :, None]
    return np.clip(img, 0, 1), X, Y


RAMPA = [(0.00, "#CDB2AF"), (0.30, "#E1C9C6"), (0.55, "#EEDAD0"), (0.80, "#FBECE3"), (1.00, "#FFFBF6")]   # porcelana cálida, de sombra a brillo


def pieza(npy, alto_px, mezcla=0.72):
    """Recorta la pieza por su alfa, la lleva a clave alta con la rampa de porcelana y la escala a alto_px.
    Devuelve RGBA lineal premultiplicado."""
    im = np.load(npy).astype(np.float64)
    a = im[:, :, 3]
    ys, xs = np.nonzero(a > 0.5)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    m = 6
    im = im[max(y0 - m, 0):y1 + m, max(x0 - m, 0):x1 + m]
    k = alto_px / (y1 - y0)
    al = im[:, :, 3:4]
    recto = np.clip(im[:, :, :3] / np.clip(al, 1e-6, 1), 0, None)
    solido = im[:, :, 3] > 0.995
    lum = recto @ np.array([0.2126, 0.7152, 0.0722])
    lo, hi = np.percentile(lum[solido], 1.0), np.percentile(lum[solido], 99.6)
    t = np.clip((lum - lo) / (hi - lo), 0, 1) ** 0.5                                           # clave alta: medios tonos arriba
    ts = np.array([p for p, _ in RAMPA])
    cs = np.array([lin(hx(c)) for _, c in RAMPA])
    rampa = np.stack([np.interp(t, ts, cs[:, c]) for c in range(3)], -1)
    propio = np.clip(recto / np.percentile(recto[solido].max(1), 99.6), 0, 1) ** 0.55          # el render, levantado
    recto = rampa * mezcla + propio * (1 - mezcla)
    if P is NOCHE:
        recto = np.clip(np.clip(im[:, :, :3] / np.clip(al, 1e-6, 1), 0, None) * 0.62, 0, 1)   # luna fría y brasa naranja, sin tocar
    im = np.dstack([recto * al, im[:, :, 3]])
    out = cv2.resize(im, (int(round(im.shape[1] * k)), int(round(im.shape[0] * k))), interpolation=cv2.INTER_AREA if k < 1 else cv2.INTER_CUBIC)
    return np.clip(out, 0, None), m * k


def poner(img_lin, capa, cx, base_y, S, margen):
    """Compone una capa RGBA premultiplicada con su centro en cx y su base en base_y (px de diseño)."""
    h, w = capa.shape[:2]
    x0 = int(round(cx * S - w / 2))
    y0 = int(round(base_y * S + margen - h))
    H, W = img_lin.shape[:2]
    sx0, sy0 = max(0, -x0), max(0, -y0)
    sx1, sy1 = min(w, W - x0), min(h, H - y0)
    if sx1 <= sx0 or sy1 <= sy0:
        return
    reg = img_lin[y0 + sy0:y0 + sy1, x0 + sx0:x0 + sx1]
    c = capa[sy0:sy1, sx0:sx1]
    reg[:] = c[:, :, :3] + reg * (1 - c[:, :, 3:4])


def componer(S, npy_rey, npy_peon, grano=True):
    img, X, Y = fondo(S)
    L = lin(img)
    pag = lin(hx(P["pagina"]))
    # sombra de contacto del rey sobre la colina
    sombra = 0.20 * blob(X, Y, REY_X + 5, REY_BASE - 2.5, 36, 5.2) + 0.08 * blob(X, Y, REY_X + 14, REY_BASE - 9, 46, 16)
    L *= 1 - sombra[:, :, None] * np.array(P["sombra_rey"])
    capas = []
    if npy_peon:
        for p in PEONES:
            c, m = pieza(npy_peon, p["alto"] * S)
            pad = int(p["blur"] * S * 3) + 2
            c = cv2.copyMakeBorder(c, pad, pad, pad, pad, cv2.BORDER_CONSTANT, value=0)
            c = cv2.GaussianBlur(c, (0, 0), p["blur"] * S)
            bruma = lin(hx(P["bruma_pieza"]))
            c[:, :, :3] = c[:, :, :3] * (1 - p["bruma"]) + bruma * c[:, :, 3:4] * p["bruma"]
            poner(L, c, p["x"], p["base"], S, m + pad)
    c, m = pieza(npy_rey, REY_ALTO * S)
    # halo: el rey oscurece apenas lo que tiene detrás, para despegarse del fondo claro
    tmp = np.zeros(L.shape)
    poner(tmp, np.dstack([c[:, :, 3]] * 4), REY_X + 2.0, REY_BASE + 1.5, S, m)
    halo = cv2.GaussianBlur(tmp[:, :, 0], (0, 0), 5.0 * S)
    L *= 1 - halo[:, :, None] * np.array(P["halo_rey"])
    poner(L, c, REY_X, REY_BASE, S, m)
    # bruma baja: las piezas se hunden en ella y todo llega al color de la página
    niebla = (0.55 * ss(190, 232, Y) + 0.45 * ss(212, 250, Y))[:, :, None]
    L = L * (1 - niebla) + pag * niebla
    out = srgb(L)
    if grano:
        # tramado mínimo para que los degradados no hagan bandas en 8 bits, más un grano muy fino
        rng = np.random.default_rng(11)
        out = out + (rng.uniform(-0.5, 0.5, out.shape) + rng.normal(0, 0.45, out.shape[:2])[:, :, None]) / 255
    alfa = 1 - ss(208, 254, Y)
    return np.clip(out, 0, 1), alfa


if __name__ == "__main__":
    if "--noche" in sys.argv:
        sys.argv.remove("--noche")
        P = NOCHE
    S = int(sys.argv[1])
    rey = sys.argv[2]
    peon = sys.argv[3] if len(sys.argv) > 3 and sys.argv[3] != "-" else None
    nombre = sys.argv[4] if len(sys.argv) > 4 else "fondo-cabecera"
    out, alfa = componer(S, rey, peon)
    rgba = np.dstack([out[:, :, ::-1], alfa])
    cv2.imwrite(nombre + ".png", (rgba * 255 + 0.5).astype(np.uint8), [cv2.IMWRITE_PNG_COMPRESSION, 9])
    plano = out * alfa[:, :, None] + hx(P["pagina"]) * (1 - alfa[:, :, None])
    cv2.imwrite(nombre + "_plano.png", (plano[:, :, ::-1] * 255 + 0.5).astype(np.uint8))
    print(nombre, rgba.shape)
