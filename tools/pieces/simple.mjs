// Juego de piezas «Simple»: el dibujo de cada pieza, plano y lo más grande posible dentro de su casilla, sin
// adornos (para jugadores clásicos). Las siluetas son las nuestras (las mismas de las fichas y de los iconos de la
// interfaz, sacadas de godot/sets/fichas/iconos.bin): sin arte ajeno.
//
// Blancas: marfil con contorno azul tinta. Negras: azul tinta casi negro con contorno marfil.
//
// Uso: node tools/pieces/simple.mjs   (npm run pieces:simple)
//   godot/sets/simple/iconos.bin   atlas de 6 × 2 celdas (blancas arriba, negras abajo; PNG con otra extensión)
//   shots/piezas-simple.png        vista previa
import { deflateSync, inflateSync } from 'node:zlib';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../../', import.meta.url));
const CELL = 256;
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
  head[8] = 8; head[9] = 6;
  const raw = Buffer.alloc((w * 4 + 1) * h);
  for (let y = 0; y < h; y++) Buffer.from(rgba.buffer, rgba.byteOffset + y * w * 4, w * 4).copy(raw, y * (w * 4 + 1) + 1);
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', head), chunk('IDAT', deflateSync(raw, { level: 9 })), chunk('IEND', Buffer.alloc(0))]);
}
/** Lee un PNG de los que escribe png(): RGBA de 8 bits con todas las filas sin filtro. */
function readPng(file) {
  const buf = readFileSync(file);
  let at = 8, w = 0, h = 0;
  const data = [];
  while (at < buf.length) {
    const len = buf.readUInt32BE(at);
    const type = buf.toString('ascii', at + 4, at + 8);
    const body = buf.subarray(at + 8, at + 8 + len);
    if (type === 'IHDR') {
      w = body.readUInt32BE(0);
      h = body.readUInt32BE(4);
      if (body[8] !== 8 || body[9] !== 6) throw new Error(`${file}: se esperaba RGBA de 8 bits`);
    } else if (type === 'IDAT') data.push(body);
    at += 12 + len;
  }
  const raw = inflateSync(Buffer.concat(data));
  const rgba = new Uint8Array(w * h * 4);
  for (let y = 0; y < h; y++) {
    const row = y * (w * 4 + 1);
    if (raw[row] !== 0) throw new Error(`${file}: fila con filtro ${raw[row]}`);
    rgba.set(raw.subarray(row + 1, row + 1 + w * 4), y * w * 4);
  }
  return { w, h, rgba };
}

const clamp01 = (x) => Math.max(0, Math.min(1, x));
const smooth = (a, b, x) => {
  const t = clamp01((x - a) / (b - a));
  return t * t * (3 - 2 * t);
};
const byte = (x) => Math.max(0, Math.min(255, Math.round(x * 255)));

// ---------- Las piezas propias (del atlas de las fichas) ----------

const PIECES = ['pawn', 'knight', 'bishop', 'rook', 'queen', 'king'];
const tokens = readPng(root + 'godot/sets/fichas/iconos.bin');
const TN = tokens.w / 3; // lado de cada icono del atlas de fichas
/** Distancia al contorno de una pieza en un punto de su celda (píxeles de la celda; positivo dentro). */
const SD_RANGE_PX = (0.05 / 0.62) * TN;
function pieceChannel(index, channel, x, y) {
  const ox = (index % 3) * TN, oy = Math.floor(index / 3) * TN;
  const cx = Math.max(0, Math.min(TN - 1.001, x)), cy = Math.max(0, Math.min(TN - 1.001, y));
  const x0 = Math.floor(cx), y0 = Math.floor(cy), fx = cx - x0, fy = cy - y0;
  const at = (px, py) => tokens.rgba[4 * (ox + px + tokens.w * (oy + py)) + channel] / 255;
  return (at(x0, y0) * (1 - fx) + at(x0 + 1, y0) * fx) * (1 - fy) + (at(x0, y0 + 1) * (1 - fx) + at(x0 + 1, y0 + 1) * fx) * fy;
}
const pieceSd = (index, x, y) => (x < 0 || y < 0 || x > TN - 1 || y > TN - 1 ? -SD_RANGE_PX : (pieceChannel(index, 2, x, y) - 0.5) * 2 * SD_RANGE_PX);

/** Caja que ocupa la silueta de una pieza dentro de su celda. */
function pieceBox(index) {
  let x0 = TN, y0 = TN, x1 = 0, y1 = 0;
  for (let y = 0; y < TN; y++) for (let x = 0; x < TN; x++) {
    if (pieceSd(index, x, y) > 0) {
      x0 = Math.min(x0, x); x1 = Math.max(x1, x); y0 = Math.min(y0, y); y1 = Math.max(y1, y);
    }
  }
  return { x0, y0, x1, y1 };
}

/** Cobertura (0–1) de la silueta de una pieza en una celda de `size` px, ajustada a `fit` del alto y centrada. */
function pieceGlyph(index, size, fit, dy = 0) {
  const box = pieceBox(index);
  const scale = (box.y1 - box.y0) / (size * fit); // píxeles del atlas por píxel de salida
  const mx = (box.x0 + box.x1) / 2, my = (box.y0 + box.y1) / 2;
  const out = new Float32Array(size * size);
  const SS = 3;
  for (let y = 0; y < size; y++) for (let x = 0; x < size; x++) {
    let a = 0;
    for (let j = 0; j < SS; j++) for (let i = 0; i < SS; i++) {
      const sx = mx + (x + (i + 0.5) / SS - size / 2) * scale, sy = my + (y + (j + 0.5) / SS - size / 2 - dy) * scale;
      a += clamp01(pieceSd(index, sx, sy) / scale + 0.5);
    }
    out[x + size * y] = a / (SS * SS);
  }
  return out;
}


// ---------- El atlas ----------

/** Distancia con signo (en px de la celda de salida) al contorno de la pieza, con la pieza ajustada a `fit`. */
function pieceField(index, size, fit) {
  const box = pieceBox(index);
  const scale = (box.y1 - box.y0) / (size * fit);
  const mx = (box.x0 + box.x1) / 2, my = (box.y0 + box.y1) / 2;
  const out = new Float32Array(size * size);
  for (let y = 0; y < size; y++) for (let x = 0; x < size; x++) {
    const sx = mx + (x + 0.5 - size / 2) * scale, sy = my + (y + 0.5 - size / 2) * scale;
    out[x + size * y] = pieceSd(index, sx, sy) / scale;
  }
  return out;
}

const SIDES = [
  { fill: [0xf8, 0xf0, 0xe0], line: [0x1b, 0x25, 0x40] },
  { fill: [0x1d, 0x24, 0x3a], line: [0xf3, 0xec, 0xdc] },
];
const LINE = CELL * 0.028;
const W = CELL * 6, H = CELL * 2;
const atlas = new Uint8Array(W * H * 4);
PIECES.forEach((_, index) => {
  // La pieza ocupa casi todo el alto: el contorno queda dentro de la celda.
  const field = pieceField(index, CELL, 0.86);
  SIDES.forEach((side, row) => {
    for (let y = 0; y < CELL; y++) for (let x = 0; x < CELL; x++) {
      const d = field[x + CELL * y];
      const inside = clamp01(d + 0.5);
      const outer = clamp01(d + LINE + 0.5);
      const o = 4 * (index * CELL + x + W * (row * CELL + y));
      const fillAmt = clamp01(d - 0.5 + 0.5); // relleno dentro del borde
      const c = [0, 1, 2].map((k) => side.line[k] * (1 - fillAmt) + side.fill[k] * fillAmt);
      atlas[o] = Math.round(c[0]);
      atlas[o + 1] = Math.round(c[1]);
      atlas[o + 2] = Math.round(c[2]);
      atlas[o + 3] = byte(Math.max(outer, inside));
    }
  });
});
writeFileSync(root + 'godot/sets/simple/iconos.bin', png(W, H, atlas));
// Vista previa sobre casillas.
const prev = new Uint8Array(W * H * 4);
for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
  const sq = ((Math.floor(x / CELL) + Math.floor(y / CELL)) % 2) ? [0x66, 0x83, 0xb7] : [0xbd, 0xcd, 0xea];
  const o = 4 * (x + W * y), a = atlas[o + 3] / 255;
  for (let k = 0; k < 3; k++) prev[o + k] = Math.round(atlas[o + k] * a + sq[k] * (1 - a));
  prev[o + 3] = 255;
}
mkdirSync(root + 'shots', { recursive: true });
writeFileSync(root + 'shots/piezas-simple.png', png(W, H, prev));
console.log(`Piezas simples: ${W}×${H}`);
