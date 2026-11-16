# Ilustraciones del menú nuevo, sacadas de la imagen de referencia: caballo con montañas y trofeo.
# Se les quita lo que en el diseño va como texto real (la letra manuscrita, la flecha) y se les da un borde fundido.
import numpy as np, cv2
import scipy.sparse as sp
from scipy.sparse.linalg import splu

REF = "/home/claude/menu2/ref.png"


def harmonic_fill(img, mask):
    h, w = mask.shape
    idx = -np.ones((h, w), np.int64)
    ys, xs = np.nonzero(mask); n = len(ys); idx[ys, xs] = np.arange(n)
    rows, cols, vals = [], [], []; rhs = np.zeros((n, img.shape[2])); diag = np.zeros(n)
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        ny, nx = ys + dy, xs + dx
        k = np.nonzero((ny >= 0) & (ny < h) & (nx >= 0) & (nx < w))[0]
        diag[k] += 1
        nidx = idx[ny[k], nx[k]]; unk = nidx >= 0
        rows.append(k[unk]); cols.append(nidx[unk]); vals.append(-np.ones(unk.sum()))
        kn = k[~unk]; rhs[kn] += img[ny[kn], nx[kn]]
    rows.append(np.arange(n)); cols.append(np.arange(n)); vals.append(diag)
    A = sp.csc_matrix((np.concatenate(vals), (np.concatenate(rows), np.concatenate(cols))), shape=(n, n))
    lu = splu(A); out = img.copy()
    for c in range(img.shape[2]):
        out[ys, xs, c] = lu.solve(rhs[:, c])
    return out


def ss(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def quitar_tinta(im, cajas, umbral=118, crece=4):
    """Borra los trazos oscuros (texto, flecha) dentro de las cajas y rellena con el degradado de alrededor."""
    lum = im @ np.array([0.114, 0.587, 0.299])
    m = np.zeros(lum.shape, np.uint8)
    for x0, y0, x1, y1 in cajas:
        m[y0:y1, x0:x1] = (lum[y0:y1, x0:x1] < umbral / 255).astype(np.uint8)
    m = cv2.dilate(m, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * crece + 1, 2 * crece + 1)))
    out = harmonic_fill(im, m.astype(bool))
    return np.clip(out, 0, 1), m


def limpiar(im):
    """Devuelve un poco de nitidez a los bordes (máscara de enfoque suave). Sin filtros de ruido: hacían bandas."""
    suave = cv2.GaussianBlur(im, (0, 0), 1.1)
    return np.clip(im + 0.40 * (im - suave), 0, 1)


def guardar(nombre, im, alfa, relleno=None):
    nitida = limpiar(im)
    if relleno is not None:                      # lo rellenado se queda liso: enfocarlo solo sacaría grano
        nitida = np.where(cv2.dilate(relleno, np.ones((7, 7), np.uint8))[:, :, None] > 0, im, nitida)
    im = nitida
    rgba = np.dstack([im, alfa])
    cv2.imwrite(nombre, (np.clip(rgba, 0, 1) * 255 + 0.5).astype(np.uint8), [cv2.IMWRITE_PNG_COMPRESSION, 9])
    print(nombre, rgba.shape)


ref = cv2.imread(REF).astype(np.float64) / 255

# ---------------------------------------------------------------- portada: caballo, montañas, camino y bandera
X0, Y0 = 560, 236
h = ref[Y0:626, X0:1120].copy()
h, mh = quitar_tinta(h, [(404, 38, 545, 120), (428, 108, 545, 215)])
cv2.imwrite("dbg_hero_mask.png", mh * 255)
x0, x1, y0, y1 = 100, 551, 6, 382
h = h[y0:y1, x0:x1]
yy, xx = np.mgrid[0:h.shape[0], 0:h.shape[1]]
alfa = ss(112 - x0, 152 - x0, xx) * ss(0, 22, yy)
guardar("portada-caballo.png", h, alfa, mh[6:382, 100:551])
print("portada: origen en la referencia", (X0 + x0, Y0 + y0), "tamaño", h.shape[1], h.shape[0])

# ---------------------------------------------------------------- desafío: trofeo, arbustos y destellos
X0, Y0 = 560, 1324
t = ref[Y0:1544, X0:1120].copy()
t, mt = quitar_tinta(t, [(494, 34, 530, 78), (418, 98, 546, 198)])
cv2.imwrite("dbg_trofeo_mask.png", mt * 255)
x0, x1, y0, y1 = 90, 551, 6, 213
t = t[y0:y1, x0:x1]
yy, xx = np.mgrid[0:t.shape[0], 0:t.shape[1]]
alfa = ss(96 - x0, 156 - x0, xx) * ss(0, 18, yy)
guardar("desafio-trofeo.png", t, alfa, mt[6:213, 90:551])
print("trofeo: origen en la referencia", (X0 + x0, Y0 + y0), "tamaño", t.shape[1], t.shape[0])
