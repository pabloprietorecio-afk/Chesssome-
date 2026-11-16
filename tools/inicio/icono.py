# Icono del inicio (godot/ui/inicio/icono.bin): el caballo 3D sobre la tesela naranja que Pablo enseñó en su captura
# del 16 nov (una edición con IA de la pantalla de inicio). Se recorta de esa captura (tools/inicio/icono_origen.png,
# 262 × 263 px), se amplía ×4 con EDSR (OpenCV dnn_superres; modelo EDSR_x4.pb de
# https://github.com/Saafke/EDSR_Tensorflow, se descarga aparte, no va en el repositorio) y se rehace el borde:
#   - bordes de la tesela medidos en la captura por el perfil de saturación (a medio píxel);
#   - esquinas: círculo de 64 px sobre 241 (26,6 % del lado), ajustado al contorno con 0,34 px de error medio;
#   - la franja de 2,6 px mezclada con el fondo lila se rellena desde dentro (cv2.inpaint) para que no haya halo;
#   - filo claro de ~2 px (bisel), medido también: fuerte arriba, suave a los lados, nada abajo.
# La sombra no va en la imagen: la pinta la app (ui/home_screens.gd, _icon_mark), medida también en la captura.
# Uso: python3 tools/inicio/icono.py RUTA/EDSR_x4.pb
import sys, os, cv2, numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_PATH = os.path.join(HERE, '..', '..', 'godot', 'ui', 'inicio', 'icono.bin')
crop = cv2.imread(os.path.join(HERE, 'icono_origen.png'))
X0, Y0 = 35, 132                                   # esquina del recorte en la captura
L, R, T, B = 45.6, 285.9, 142.6, 384.0             # bordes de la tesela en la captura
RADIUS = 64.0 / 241.0
S, OUT = 4, 512

sr = cv2.dnn_superres.DnnSuperResImpl_create()
sr.readModel(sys.argv[1])
sr.setModel('edsr', S)
up = sr.upsample(crop).astype(np.float32) / 255

x0, x1, y0, y1 = (L - X0) * S, (R - X0) * S, (T - Y0) * S, (B - Y0) * S
M = np.float32([[(x1 - x0) / OUT, 0, x0], [0, (y1 - y0) / OUT, y0]])
tile = cv2.warpAffine(up, M, (OUT, OUT), flags=cv2.INTER_AREA | cv2.WARP_INVERSE_MAP, borderMode=cv2.BORDER_REPLICATE)


def rounded_sdf(n, r, ss=4):
    """Distancia con signo al borde de la tesela (positiva dentro), en píxeles de la salida, y la normal hacia fuera
    (solo su componente vertical: el filo claro depende de si el borde mira arriba o abajo)."""
    N = n * ss
    yy, xx = (np.mgrid[0:N, 0:N].astype(np.float32) + 0.5) / ss
    cx, cy = np.clip(xx, r, n - r), np.clip(yy, r, n - r)
    corner = (xx != cx) & (yy != cy)
    d_corner = r - np.hypot(xx - cx, yy - cy)
    d_side = np.minimum(np.minimum(xx, n - xx), np.minimum(yy, n - yy))
    d = np.where(corner, d_corner, d_side)
    # normal: en las esquinas, la del círculo; en los lados, la del lado más cercano
    ny = np.where(corner, (yy - cy) / np.maximum(np.hypot(xx - cx, yy - cy), 1e-6),
                  np.where(np.minimum(yy, n - yy) <= np.minimum(xx, n - xx), np.where(yy < n / 2, -1.0, 1.0), 0.0))
    pool = lambda a: a.reshape(n, ss, n, ss).mean((1, 3)).astype(np.float32)
    return pool(d), pool(ny)


px = OUT / 241.0                                    # un píxel de la captura, en la salida
dist, ny = rounded_sdf(OUT, RADIUS * OUT)
# Borde: el de la captura es algo blando (≈1,2 px de la salida a cada lado), no un corte seco.
alpha = np.clip((dist + 1.2) / 2.4, 0, 1)
alpha = alpha * alpha * (3 - 2 * alpha)
color = (np.clip(tile, 0, 1) * 255).astype(np.uint8)
color = cv2.inpaint(color, ((dist < 2.6 * px) * 255).astype(np.uint8), 6, cv2.INPAINT_TELEA).astype(np.float32)
# Filo claro (bisel) medido en la captura: ~2 px, fuerte arriba, suave a los lados, nada abajo.
rim = np.exp(-((np.maximum(dist, 0) - 0.6 * px) / (1.6 * px)) ** 2) * (dist > -1)
facing = np.clip(0.5 - 0.5 * ny, 0, 1) ** 1.5      # 1 arriba, 0,35 a los lados, 0 abajo
light = np.array([190, 236, 255], np.float32)      # BGR: crema amarillento
k = (0.55 * rim * facing)[..., None]
color = np.clip(color * (1 - k) + light * k, 0, 255).astype(np.uint8)
ok, png = cv2.imencode('.png', np.dstack([color, (alpha * 255).astype(np.uint8)]))
open(OUT_PATH, 'wb').write(png.tobytes())
print('icono.bin', OUT, 'x', OUT)
# El mismo icono, a 256 px, como imagen grande de los avisos de Android (android_espera/: «¡Rival encontrado!»).
large = os.path.join(HERE, '..', '..', 'android_espera', 'res', 'drawable-nodpi')
os.makedirs(large, exist_ok=True)
rgba = np.dstack([color, (alpha * 255).astype(np.uint8)])
ok, png2 = cv2.imencode('.png', cv2.resize(rgba, (256, 256), interpolation=cv2.INTER_AREA))
open(os.path.join(large, 'ic_large_achessway.png'), 'wb').write(png2.tobytes())
