// Colección «Clásico de autor»: proporciones Staunton, formas más redondas y cabezas distintas vistas desde arriba.
// Cada pieza es un campo de distancia; las medidas están en casillas (la pieza apoya en y = 0 y mira a +Z).
import { union, subtract, smin, lathe, smoothProfile, polygon2D, pillow, roundCylinder, torus, disc, sphere, ellipsoid, roundBox, roundCone, radial, translate, rotateZ, scale } from './sdf.mjs';

const stem = (pts) => lathe(smoothProfile(pts, 10));

/** Pie común a toda la familia: disco de apoyo y moldura. */
const foot = (R) => union(0.04, roundCylinder(R, 0, 0.078, 0.03), torus(0.106, R * 0.75, 0.05));

function pawn() {
  const body = union(
    0.02,
    foot(0.29),
    stem([[0, 0.05, 1], [0.225, 0.05, 1], [0.215, 0.13], [0.165, 0.2], [0.124, 0.3], [0.104, 0.41], [0.1, 0.47, 1], [0, 0.47, 1]]),
  );
  const collar = disc(0.487, 0.178, 0.027);
  const neck = roundCone([0, 0.49, 0], [0, 0.57, 0], 0.098, 0.085);
  const head = sphere(0, 0.682, 0, 0.16);
  return { field: union(0.04, body, collar, union(0.03, neck, head)), top: 0.9 };
}

function rook() {
  const body = union(
    0.02,
    foot(0.33),
    stem([[0, 0.05, 1], [0.262, 0.05, 1], [0.255, 0.14], [0.215, 0.23], [0.192, 0.37], [0.188, 0.52], [0.2, 0.63, 1], [0, 0.63, 1]]),
  );
  const collar = disc(0.652, 0.258, 0.028);
  const tower = roundCylinder(0.265, 0.675, 0.985, 0.028);
  const hollow = roundCylinder(0.172, 0.87, 1.3, 0.02);
  const slot = radial(roundBox(0.26, 1.0, 0, 0.13, 0.082, 0.047, 0.012), 6, Math.PI / 6);
  const top = subtract(0.03, tower, hollow, slot);
  return { field: union(0.04, body, collar, top), cut: 0.686, bounds: [-0.4, 0, -0.4, 0.4, 1.05, 0.4], cell: 0.017 };
}

function bishop() {
  const body = union(
    0.02,
    foot(0.325),
    stem([[0, 0.05, 1], [0.255, 0.05, 1], [0.245, 0.14], [0.188, 0.23], [0.128, 0.37], [0.102, 0.53], [0.1, 0.66, 1], [0, 0.66, 1]]),
  );
  const collars = union(0.03, disc(0.686, 0.192, 0.027), disc(0.74, 0.136, 0.022));
  const mitre = stem([[0, 0.745, 1], [0.1, 0.745, 1], [0.156, 0.84], [0.17, 0.93], [0.135, 1.04], [0.075, 1.125], [0.036, 1.16, 1], [0, 1.16, 1]]);
  const finial = sphere(0, 1.195, 0, 0.052);
  // Corte del alfil: una acanaladura redonda en diagonal (sin labios finos, para que el mallado salga limpio).
  const slit = roundCone([0.135, 0.9, -0.3], [0.135, 1.06, 0.3], 0.042, 0.042);
  const head = union(0.02, subtract(0.03, mitre, slit), finial);
  return { field: union(0.04, body, collars, head), cut: 0.768, bounds: [-0.3, 0, -0.3, 0.3, 1.3, 0.3], cell: 0.016 };
}

function queen() {
  const body = union(
    0.02,
    foot(0.355),
    stem([[0, 0.05, 1], [0.28, 0.05, 1], [0.27, 0.15], [0.205, 0.26], [0.138, 0.43], [0.108, 0.63], [0.103, 0.8], [0.11, 0.9, 1], [0, 0.9, 1]]),
  );
  const collars = union(0.03, disc(0.927, 0.218, 0.028), disc(0.985, 0.152, 0.022));
  const cup = stem([[0, 0.995, 1], [0.115, 0.995, 1], [0.137, 1.08], [0.192, 1.2], [0.248, 1.315], [0.238, 1.35, 1], [0, 1.35, 1]]);
  // Corona de perlas: ocho bolas sobre el borde, que desde arriba dibujan un anillo de puntos inconfundible.
  const pearls = radial(sphere(0.228, 1.372, 0, 0.05), 8, Math.PI / 8);
  const dome = ellipsoid(0, 1.335, 0, 0.16, 0.105, 0.16);
  const finial = sphere(0, 1.47, 0, 0.056);
  const crown = union(0.02, cup, pearls, dome, finial);
  return { field: union(0.04, body, collars, crown), cut: 1.012, bounds: [-0.36, 0, -0.36, 0.36, 1.58, 0.36], cell: 0.016 };
}

function king() {
  const body = union(
    0.02,
    foot(0.37),
    stem([[0, 0.05, 1], [0.29, 0.05, 1], [0.28, 0.15], [0.218, 0.27], [0.152, 0.45], [0.124, 0.67], [0.12, 0.86], [0.127, 0.96, 1], [0, 0.96, 1]]),
  );
  const collars = union(0.03, disc(0.987, 0.23, 0.03), disc(1.048, 0.162, 0.022));
  const cup = stem([[0, 1.055, 1], [0.125, 1.055, 1], [0.147, 1.14], [0.2, 1.26], [0.252, 1.375], [0.242, 1.405, 1], [0, 1.405, 1]]);
  const dome = ellipsoid(0, 1.395, 0, 0.205, 0.075, 0.205);
  const cross = union(0.014, roundBox(0, 1.61, 0, 0.047, 0.15, 0.042, 0.018), roundBox(0, 1.635, 0, 0.125, 0.045, 0.042, 0.018));
  const crown = union(0.02, cup, dome, cross);
  return { field: union(0.04, body, collars, crown), cut: 1.075, bounds: [-0.36, 0, -0.36, 0.36, 1.84, 0.36], cell: 0.016 };
}

function knight() {
  const plinth = union(
    0.03,
    foot(0.33),
    stem([[0, 0.05, 1], [0.262, 0.05, 1], [0.255, 0.14], [0.232, 0.2], [0.222, 0.25, 1], [0, 0.25, 1]]),
    disc(0.262, 0.243, 0.024),
  );
  // El caballo se dibuja de perfil (plano Z–Y, mira a +Z) y se «infla» hacia los lados: así el contorno,
  // que es lo que hace reconocible la pieza, se controla punto a punto.
  const outline = smoothProfile(
    [
      [0.185, 0.235, 1], [0.198, 0.29], [0.216, 0.37], [0.2, 0.47], [0.15, 0.545], [0.108, 0.6], [0.088, 0.642, 1],
      [0.135, 0.618], [0.2, 0.602], [0.262, 0.6], [0.302, 0.628], [0.318, 0.675], [0.303, 0.722],
      [0.24, 0.778], [0.152, 0.862], [0.08, 0.935], [0.04, 0.985, 1],
      [0.052, 1.07], [0.036, 1.145, 1], [-0.022, 1.06], [-0.055, 0.99, 1],
      [-0.125, 0.955], [-0.195, 0.88], [-0.248, 0.76], [-0.27, 0.62], [-0.264, 0.46], [-0.236, 0.34], [-0.205, 0.235, 1],
    ],
    8,
    false,
  );
  const sil = polygon2D(outline);
  const smooth = (a, b, v) => { const t = Math.max(0, Math.min(1, (v - a) / (b - a))); return t * t * (3 - 2 * t); };
  const halfWidth = (z, y) => (0.172 - 0.07 * smooth(0.35, 0.9, y)) * (1 - 0.22 * smooth(0.1, 0.3, z));
  const bust = pillow(sil, halfWidth, 0.12);
  const jowl = sphere(0, 0.79, 0.065, 0.116);
  // Crin: una banda más fina a lo largo de la cresta del cuello, con el borde en ondas (se lee de perfil y por detrás).
  const maneOutline = smoothProfile(
    [
      [-0.045, 1.0, 1], [-0.11, 1.002], [-0.165, 0.958], [-0.186, 0.905, 1], [-0.236, 0.892], [-0.27, 0.825], [-0.27, 0.768, 1],
      [-0.302, 0.738], [-0.313, 0.665], [-0.297, 0.612, 1], [-0.32, 0.572], [-0.315, 0.492], [-0.292, 0.447, 1],
      [-0.303, 0.402], [-0.282, 0.33], [-0.245, 0.285, 1],
      [-0.17, 0.29], [-0.19, 0.46], [-0.195, 0.62], [-0.175, 0.76], [-0.125, 0.87], [-0.06, 0.935],
    ],
    6,
    false,
  );
  const mane = pillow(polygon2D(maneOutline), () => 0.052, 0.04);
  const earGap = roundBox(0, 1.1, 0, 0.02, 0.1, 0.2, 0.012);
  const eye = (s) => sphere(s * 0.108, 0.872, 0.1, 0.034);
  const horse = (x, y, z) => {
    let d = smin(bust(x, y, z), jowl(x, y, z), 0.04);
    d = smin(d, mane(x, y, z), 0.012);
    d = -smin(-d, earGap(x, y, z), 0.012);
    d = -smin(-d, eye(1)(x, y, z), 0.012);
    d = -smin(-d, eye(-1)(x, y, z), 0.012);
    return d;
  };
  return { field: union(0.03, plinth, horse), axial: plinth, cut: 0.214, bounds: [-0.4, 0, -0.4, 0.4, 1.2, 0.4], cell: 0.019 };
}

export const SET = {
  id: 'clasico',
  pieces: { pawn: pawn(), knight: knight(), bishop: bishop(), rook: rook(), queen: queen(), king: king() },
};
