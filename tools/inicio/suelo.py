# Suelo de damero en perspectiva (pie de la pantalla), con canal alfa. Mismo trazado que el del diseño, a cualquier tamaño.
# Uso: python3 suelo.py 6 fondo-suelo.png            (de día)
#      python3 suelo.py 6 fondo-suelo-noche.png --noche   (tema oscuro)
import sys, numpy as np, cv2
NOCHE = '--noche' in sys.argv
if NOCHE:
    sys.argv.remove('--noche')
S = int(sys.argv[1]); SS = 3
W = 390 * S; scale = W / 841.0
T0, T1 = 128.0, 251.0                      # px de la referencia bajo el horizonte: de transparente al borde inferior
Hf = int(round((T1 - T0) * scale))
F, f, xv = 1538.0, 928.0, 420.5
ys = ((np.arange(Hf * SS) + 0.5) / (SS * scale) + T0).astype(np.float32)
xs = ((np.arange(W * SS) + 0.5) / (SS * scale)).astype(np.float32)
tt, xx = np.meshgrid(ys, xs, indexing="ij")
z = F / tt; X = (xx - xv) * z / f
dark = ((np.floor(X).astype(np.int64) + np.floor(z - 0.02).astype(np.int64)) % 2 == 0)
cd = np.array([0xC4, 0xD8, 0xF8], np.float32) / 255; cl = np.array([0xE4, 0xF0, 0xFE], np.float32) / 255      # BGR de #F8D8C4 y #FEF0E4
if NOCHE:
    cd = np.array([0x4A, 0x22, 0x2C], np.float32) / 255; cl = np.array([0x5C, 0x2E, 0x3A], np.float32) / 255  # BGR de #2C224A y #3A2E5C
col = np.where(dark[:, :, None], cd, cl)
u = np.clip((tt - 138.0) / (222.0 - 138.0), 0, 1); a = u * u * (3 - 2 * u)
col = col.reshape(Hf, SS, W, SS, 3).mean((1, 3)); a = a.reshape(Hf, SS, W, SS).mean((1, 3))
cv2.imwrite(sys.argv[2], (np.clip(np.dstack([col, a]), 0, 1) * 255 + 0.5).astype(np.uint8), [cv2.IMWRITE_PNG_COMPRESSION, 9])
print(sys.argv[2], (Hf, W))
