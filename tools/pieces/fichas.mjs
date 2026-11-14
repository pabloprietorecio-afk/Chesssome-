// Colección «Fichas»: una ficha plana para todas las piezas y, en su cara, el icono de cada pieza en bajorrelieve.
//
// Los iconos no son dibujos de terceros: son las piezas de la colección «Clásico de autor» (clasico.mjs) vistas
// de perfil. Cada punto del icono guarda hacia dónde mira la superficie de la pieza en ese punto (su normal,
// aplanada como en una medalla), la distancia al contorno y la sombra de sus recovecos. El material de la ficha
// (piece_token.gdshader) usa esos datos para tallar el icono con la luz de la escena.
//
// Uso: node tools/pieces/fichas.mjs
//   godot/sets/fichas/token.glb    la ficha
//   godot/sets/fichas/iconos.bin   atlas de 3 × 2 iconos (un PNG; la extensión evita que Godot lo comprima)
//   shots/fichas-iconos.png        vista previa de los iconos, iluminados
import { deflateSync } from 'node:zlib';
import { mkdirSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { roundCylinder, subtract, torus, latheMesh, rotateY } from './sdf.mjs';
import { writeGlb } from './glb.mjs';
import { SET as CLASICO } from './clasico.mjs';

// ---------- La ficha ----------

/** Medidas en casillas. Las usa también el material de la ficha (godot/board3d/board_3d.gd, TOKEN). */
export const TOKEN = {
  radius: 0.4,
  height: 0.165,
  /** Radio de la cara rehundida donde va el icono y altura a la que queda. */
  fieldRadius: 0.343,
  faceHeight: 0.152,
  /** Semilado del cuadro del icono sobre la cara. */
  iconRadius: 0.31,
  /** Distancia al contorno que cabe en el canal azul (a cada lado). */
  sdRange: 0.05,
};

const tokenField = subtract(
  0.008,
  roundCylinder(TOKEN.radius, 0, TOKEN.height, 0.034),
  // Cara rehundida: deja un aro alrededor, como en una ficha de damas o una moneda.
  roundCylinder(TOKEN.fieldRadius, TOKEN.faceHeight, TOKEN.height + 0.1, 0.012),
  // Una ranura fina en el canto.
  torus(TOKEN.height * 0.5, TOKEN.radius + 0.004, 0.011),
);

// ---------- Los iconos ----------

const N = 384; // lado de cada icono, en píxeles
const SS = 2; // el contorno se calcula al doble de resolución
const COLS = 3;
const ROWS = 2;
/** Aplanado del relieve: 1 sería la pieza tal cual; menos, una medalla. */
const DEPTH = 0.55;

/**
 * Cada pieza: altura del icono sobre la ficha y cuánto se ensancha. Las piezas reales son esbeltas; a tamaño
 * de icono se leen mejor algo más anchas, como en los diagramas impresos.
 */
const ICONS = [
  { name: 'pawn', top: 0.842, height: 0.45, widen: 1.12 },
  { name: 'knight', top: 1.15, height: 0.54, widen: 1.1 },
  { name: 'bishop', top: 1.25, height: 0.56, widen: 1.22 },
  { name: 'rook', top: 0.99, height: 0.48, widen: 1.1 },
  { name: 'queen', top: 1.53, height: 0.59, widen: 1.3 },
  // El rey se mira de frente: de perfil, su cruz se vería de canto.
  { name: 'king', top: 1.76, height: 0.61, widen: 1.36, turn: Math.PI / 2 },
];

/** Primer punto de la pieza que ve un rayo que llega desde +X (la pieza de perfil), o null. */
function hitFromSide(field, y, z) {
  let x = 0.5;
  let prev = x;
  for (let i = 0; i < 400; i++) {
    const d = field(x, y, z);
    if (d < 0) {
      // Bisección entre el último punto de fuera y este.
      let a = prev, b = x;
      for (let k = 0; k < 14; k++) {
        const m = (a + b) / 2;
        if (field(m, y, z) < 0) b = m; else a = m;
      }
      return (a + b) / 2;
    }
    prev = x;
    x -= Math.max(0.55 * d, 0.0025);
    if (x < -0.5) return null;
  }
  return null;
}

/** Transformada de distancia euclídea exacta (Felzenszwalb y Huttenlocher) de una máscara. */
function distanceTo(mask, w, h) {
  const INF = 1e12;
  const g = new Float64Array(w * h);
  for (let i = 0; i < w * h; i++) g[i] = mask[i] ? 0 : INF;
  const f = new Float64Array(Math.max(w, h)), d = new Float64Array(Math.max(w, h));
  const v = new Int32Array(Math.max(w, h)), zz = new Float64Array(Math.max(w, h) + 1);
  const pass = (n, get, set) => {
    for (let q = 0; q < n; q++) f[q] = get(q);
    let k = 0;
    v[0] = 0; zz[0] = -INF; zz[1] = INF;
    for (let q = 1; q < n; q++) {
      let s;
      do {
        const p = v[k];
        s = (f[q] + q * q - (f[p] + p * p)) / (2 * q - 2 * p);
      } while (s <= zz[k] && --k >= 0);
      k++;
      v[k] = q; zz[k] = s; zz[k + 1] = INF;
    }
    k = 0;
    for (let q = 0; q < n; q++) {
      while (zz[k + 1] < q) k++;
      const p = v[k];
      d[q] = (q - p) * (q - p) + f[p];
    }
    for (let q = 0; q < n; q++) set(q, d[q]);
  };
  for (let x = 0; x < w; x++) pass(h, (y) => g[x + w * y], (y, val) => { g[x + w * y] = val; });
  for (let y = 0; y < h; y++) pass(w, (x) => g[x + w * y], (x, val) => { g[x + w * y] = val; });
  for (let i = 0; i < w * h; i++) g[i] = Math.sqrt(g[i]);
  return g;
}

/** Datos de un icono: por píxel, normal aplanada (u, v), distancia con signo al contorno y sombra de recovecos. */
function renderIcon(def) {
  const base = CLASICO.pieces[def.name].field;
  const field = def.turn ? rotateY(base, def.turn) : base;
  const s = def.height / def.top; // de casillas de la pieza a casillas de la ficha
  const R = TOKEN.iconRadius;
  // Píxel → punto del perfil de la pieza. El que mira ve +Z a su izquierda: el caballo queda mirando a la izquierda.
  const toPiece = (px, py, n) => {
    const u = ((px + 0.5) / n) * 2 - 1, v = 1 - ((py + 0.5) / n) * 2;
    return [def.top / 2 + (v * R) / s, (-u * R) / (s * def.widen)];
  };
  // Contorno, al doble de resolución.
  const M = N * SS;
  const mask = new Uint8Array(M * M);
  for (let py = 0; py < M; py++) for (let px = 0; px < M; px++) {
    const [y, z] = toPiece(px, py, M);
    if (y < 0 || y > def.top + 0.02) continue;
    if (hitFromSide(field, y, z) !== null) mask[px + M * py] = 1;
  }
  const inv = mask.map((m) => 1 - m);
  const dOut = distanceTo(mask, M, M), dIn = distanceTo(inv, M, M);
  const pixel = (2 * R) / M; // casillas de la ficha por píxel
  const out = { nu: new Float32Array(N * N), nv: new Float32Array(N * N), sd: new Float32Array(N * N), ao: new Float32Array(N * N).fill(1) };
  for (let py = 0; py < N; py++) for (let px = 0; px < N; px++) {
    const i = px + N * py;
    let sd = 0;
    for (let b = 0; b < SS; b++) for (let a = 0; a < SS; a++) {
      const j = px * SS + a + M * (py * SS + b);
      sd += mask[j] ? dIn[j] - 0.5 : -(dOut[j] - 0.5);
    }
    out.sd[i] = (sd / (SS * SS)) * pixel;
    const [y, z] = toPiece(px, py, N);
    if (y < 0 || y > def.top + 0.02) continue;
    const x = hitFromSide(field, y, z);
    if (x === null) continue;
    const e = 1e-3;
    let gx = field(x + e, y, z) - field(x - e, y, z), gy = field(x, y + e, z) - field(x, y - e, z), gz = field(x, y, z + e) - field(x, y, z - e);
    const gl = Math.hypot(gx, gy, gz) || 1;
    gx /= gl; gy /= gl; gz /= gl;
    // Sombra de recovecos, como en el mallado de las piezas: cuánto se cierra el campo al salir por la normal.
    let occ = 0, w = 1;
    for (let k = 1; k <= 5; k++) {
      const hgt = 0.035 * k;
      occ += (w * Math.max(0, hgt - field(x + gx * hgt, y + gy * hgt, z + gz * hgt))) / hgt;
      w *= 0.62;
    }
    out.ao[i] = Math.max(0.35, Math.min(1, 1 - 0.55 * occ));
    // Normal del relieve aplanado, en los ejes del icono (u a la derecha, v arriba, w hacia quien mira).
    const nu = (-DEPTH * gz) / def.widen, nv = DEPTH * gy, nw = Math.max(gx, 0.1);
    const nl = Math.hypot(nu, nv, nw);
    out.nu[i] = nu / nl;
    out.nv[i] = nv / nl;
  }
  return out;
}

// ---------- PNG ----------

const CRC = new Uint32Array(256).map((_, n) => {
  let c = n;
  for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
  return c >>> 0;
});
function crc32(buf) {
  let c = 0xffffffff;
  for (const b of buf) c = CRC[(c ^ b) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}
function png(w, h, rgba) {
  const chunk = (type, data) => {
    const len = Buffer.alloc(4);
    len.writeUInt32BE(data.length);
    const body = Buffer.concat([Buffer.from(type, 'ascii'), data]);
    const crc = Buffer.alloc(4);
    crc.writeUInt32BE(crc32(body));
    return Buffer.concat([len, body, crc]);
  };
  const head = Buffer.alloc(13);
  head.writeUInt32BE(w, 0);
  head.writeUInt32BE(h, 4);
  head[8] = 8; head[9] = 6; // 8 bits por canal, RGBA
  const raw = Buffer.alloc((w * 4 + 1) * h);
  for (let y = 0; y < h; y++) Buffer.from(rgba.buffer, rgba.byteOffset + y * w * 4, w * 4).copy(raw, y * (w * 4 + 1) + 1);
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', head), chunk('IDAT', deflateSync(raw, { level: 9 })), chunk('IEND', Buffer.alloc(0))]);
}

// ---------- Salida ----------

const root = fileURLToPath(new URL('../../', import.meta.url));
const outDir = root + 'godot/sets/fichas/';
mkdirSync(outDir, { recursive: true });

const body = latheMesh(tokenField, -0.02, TOKEN.height + 0.03, { rMax: 0.46, step: 0.003, segments: 56, tolerance: 0.0006, maxEdge: 0.06 });
writeGlb(outDir + 'token.glb', 'token', [{ name: 'ficha', mesh: body }]);
console.log(`token.glb: ${body.indices.length / 3} triángulos (32 fichas: ${(body.indices.length / 3) * 32})`);

const W = N * COLS, H = N * ROWS;
const atlas = new Uint8Array(W * H * 4);
const preview = new Uint8Array(W * H * 4);
const byte = (x) => Math.max(0, Math.min(255, Math.round(x * 255)));
// Los bordes de cada celda son «cara lisa»: así no pasa nada si el filtrado mezcla celdas vecinas.
for (let i = 0; i < W * H; i++) atlas.set([128, 128, 0, 255], 4 * i);
ICONS.forEach((def, index) => {
  const t0 = performance.now();
  const icon = renderIcon(def);
  const ox = (index % COLS) * N, oy = Math.floor(index / COLS) * N;
  let inside = 0;
  for (let py = 0; py < N; py++) for (let px = 0; px < N; px++) {
    const i = px + N * py, o = 4 * (ox + px + W * (oy + py));
    atlas[o] = byte(0.5 + 0.5 * icon.nu[i]);
    atlas[o + 1] = byte(0.5 + 0.5 * icon.nv[i]);
    atlas[o + 2] = byte(0.5 + icon.sd[i] / (2 * TOKEN.sdRange));
    atlas[o + 3] = byte(icon.ao[i]);
    // Vista previa: el relieve con una luz arriba a la izquierda, oscuro sobre claro.
    const m = Math.max(0, Math.min(1, icon.sd[i] / 0.0016 + 0.5));
    if (m > 0.5) inside++;
    const nw = Math.sqrt(Math.max(0, 1 - icon.nu[i] ** 2 - icon.nv[i] ** 2));
    const lit = Math.max(0, -0.42 * icon.nu[i] + 0.5 * icon.nv[i] + 0.76 * nw);
    const ink = (0.1 + 0.5 * lit ** 1.5) * (0.55 + 0.45 * icon.ao[i]);
    const paper = 0.86 - 0.3 * Math.max(0, Math.min(1, 1 + icon.sd[i] / 0.014)) * (1 - m);
    const c = paper * (1 - m) + ink * m;
    preview.set([byte(c * 1.0), byte(c * 0.94), byte(c * 0.82), 255], o);
  }
  console.log(`${def.name.padEnd(7)} ${Math.round(performance.now() - t0)} ms · ${((100 * inside) / (N * N)).toFixed(1)} % del cuadro`);
});
writeFileSync(outDir + 'iconos.bin', png(W, H, atlas));
mkdirSync(root + 'shots', { recursive: true });
writeFileSync(root + 'shots/fichas-iconos.png', png(W, H, preview));
console.log(`iconos.bin: ${W} × ${H}`);
