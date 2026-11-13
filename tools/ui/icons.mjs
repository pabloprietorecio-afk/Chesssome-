// Iconos e ilustraciones de la interfaz de la app (Godot).
//
// Salen de dos sitios:
//   · Phosphor Icons (licencia MIT, paquete @phosphor-icons/core): los iconos generales, casi todos en su
//     variante «duotone» (línea más un relleno suave), que es la que da el aire ilustrado.
//   · Nuestras propias piezas: las siluetas y el caballo del emblema se sacan del atlas de las fichas
//     (godot/sets/fichas/iconos.bin, que genera tools/pieces/fichas.mjs a partir de las piezas 3D). Sin arte ajeno.
//
// Todo va en blanco con transparencia: el color se lo da la app al dibujarlo (un mismo icono vale para el tema
// claro, el oscuro y cualquier tono pastel). El relleno suave de los «duotone» es el mismo blanco al 20–25 %.
//
// Uso: node tools/ui/icons.mjs   (npm run ui:icons)
//   godot/ui/iconos.bin    atlas de iconos (un PNG; la extensión evita que Godot lo importe y lo comprima)
//   godot/ui/iconos.json   qué icono hay en cada celda
//   godot/ui/emblema.bin   emblema de la app: el caballo en relieve sobre una tesela pastel (PNG)
//   shots/ui-iconos.png    vista previa
import { deflateSync, inflateSync } from 'node:zlib';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { Resvg } from '@resvg/resvg-js';

const root = fileURLToPath(new URL('../../', import.meta.url));
const phosphor = root + 'node_modules/@phosphor-icons/core/assets/';

/** Lado de cada celda del atlas, en píxeles. Los iconos se enseñan entre 50 y 130 px. */
const CELL = 160;
const COLS = 8;

/** nombre en la app → [icono de Phosphor, variante]. */
const ICONS = {
  bulb: ['lightbulb', 'duotone'],
  step: ['footprints', 'duotone'],
  eye: ['eye', 'duotone'],
  skip: ['skip-forward', 'duotone'],
  retry: ['arrow-counter-clockwise', 'bold'],
  next: ['arrow-right', 'bold'],
  why: ['question', 'duotone'],
  line: ['path', 'duotone'],
  chart: ['chart-bar', 'duotone'],
  tap: ['hand-tap', 'duotone'],
  sliders: ['sliders-horizontal', 'duotone'],
  pin: ['push-pin', 'duotone'],
  pin_on: ['push-pin', 'fill'],
  view: ['perspective', 'duotone'],
  search: ['magnifying-glass', 'duotone'],
  spark: ['sparkle', 'duotone'],
  copy: ['copy', 'duotone'],
  open: ['arrow-square-out', 'duotone'],
  close: ['x', 'bold'],
  check: ['check-circle', 'duotone'],
  wrong: ['x-circle', 'duotone'],
  sound: ['speaker-high', 'duotone'],
  phone: ['device-rotate', 'duotone'],
  sun: ['sun', 'duotone'],
  moon: ['moon', 'duotone'],
  film: ['film-strip', 'duotone'],
  palette: ['palette', 'duotone'],
  outline: ['circle-dashed', 'duotone'],
  info: ['info', 'duotone'],
  whatif: ['strategy', 'duotone'],
  book: ['book-open', 'duotone'],
  back: ['arrow-u-up-left', 'bold'],
  party: ['confetti', 'duotone'],
  target: ['target', 'duotone'],
  zoom: ['arrows-out', 'duotone'],
  play: ['play', 'fill'],
  first: ['skip-back', 'fill'],
  cap: ['graduation-cap', 'duotone'],
};

// ---------- PNG (mismo formato sencillo que tools/pieces/fichas.mjs: 8 bits RGBA, sin filtro) ----------

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

function phosphorGlyph(name, weight) {
  const file = `${phosphor}${weight}/${name}${weight === 'regular' ? '' : '-' + weight}.svg`;
  // El relleno suave de los «duotone» va al 20 %; sobre teselas pastel se lee mejor un poco más lleno.
  const svg = readFileSync(file, 'utf8').replace('fill="currentColor"', 'fill="#ffffff"').replaceAll('opacity="0.2"', 'opacity="0.26"');
  // Un pequeño margen: los iconos de Phosphor llegan casi al borde de su cuadro.
  const inner = Math.round(CELL * 0.94);
  const image = new Resvg(svg, { fitTo: { mode: 'width', value: inner }, background: 'rgba(0,0,0,0)' }).render();
  const out = new Float32Array(CELL * CELL);
  const off = Math.floor((CELL - image.width) / 2);
  // Ojo: `pixels` devuelve una copia cada vez que se lee.
  const pixels = image.pixels;
  for (let y = 0; y < image.height; y++) for (let x = 0; x < image.width; x++) {
    out[x + off + CELL * (y + off)] = pixels[4 * (x + image.width * y) + 3] / 255;
  }
  return out;
}

const glyphs = [];
for (const [name, [icon, weight]] of Object.entries(ICONS)) glyphs.push([name, phosphorGlyph(icon, weight)]);
PIECES.forEach((piece, index) => glyphs.push(['piece_' + piece, pieceGlyph(index, CELL, 0.86)]));
{
  // Ficha: un disco suave con su aro y el peón encima (el estilo «duotone» de los demás iconos).
  const pawn = pieceGlyph(0, CELL, 0.5);
  const out = new Float32Array(CELL * CELL);
  const c = CELL / 2, r = CELL * 0.45, ring = CELL * 0.045;
  for (let y = 0; y < CELL; y++) for (let x = 0; x < CELL; x++) {
    const d = Math.hypot(x + 0.5 - c, y + 0.5 - c);
    const disc = clamp01(r - d + 0.5);
    const edge = disc * clamp01(d - (r - ring) + 0.5);
    out[x + CELL * y] = Math.max(0.26 * disc, edge, pawn[x + CELL * y]);
  }
  glyphs.push(['token_pawn', out]);
}

const rows = Math.ceil(glyphs.length / COLS);
const W = CELL * COLS, H = CELL * rows;
const atlas = new Uint8Array(W * H * 4);
const preview = new Uint8Array(W * H * 4);
const TINTS = [[0xff, 0xe3, 0xd3, 0xd9, 0x5b, 0x1e], [0xdc, 0xf3, 0xe6, 0x1b, 0x8a, 0x5a], [0xe7, 0xe1, 0xfb, 0x5b, 0x48, 0xc8], [0xd9, 0xe9, 0xff, 0x23, 0x6f, 0xd1], [0xff, 0xf0, 0xc4, 0xa8, 0x6e, 0x00], [0xff, 0xdd, 0xe6, 0xc9, 0x3a, 0x6c]];
const index = {};
glyphs.forEach(([name, alpha], i) => {
  const cx = i % COLS, cy = Math.floor(i / COLS);
  index[name] = [cx, cy];
  const tint = TINTS[i % TINTS.length];
  for (let y = 0; y < CELL; y++) for (let x = 0; x < CELL; x++) {
    const a = alpha[x + CELL * y];
    const o = 4 * (cx * CELL + x + W * (cy * CELL + y));
    atlas.set([255, 255, 255, byte(a)], o);
    // Vista previa: cada icono sobre una tesela pastel redondeada, con su tinta.
    const rx = Math.max(Math.abs(x + 0.5 - CELL / 2) - (CELL / 2 - 34), 0), ry = Math.max(Math.abs(y + 0.5 - CELL / 2) - (CELL / 2 - 34), 0);
    const tile = clamp01(28 - Math.hypot(rx, ry) + 0.5);
    const k = 0.74; // el icono, algo más pequeño que su tesela
    const sx = Math.round((x - CELL / 2) / k + CELL / 2), sy = Math.round((y - CELL / 2) / k + CELL / 2);
    const ia = sx >= 0 && sy >= 0 && sx < CELL && sy < CELL ? alpha[sx + CELL * sy] : 0;
    const bg = [255 + (tint[0] - 255) * tile, 255 + (tint[1] - 255) * tile, 255 + (tint[2] - 255) * tile];
    preview.set([bg[0] + (tint[3] - bg[0]) * ia, bg[1] + (tint[4] - bg[1]) * ia, bg[2] + (tint[5] - bg[2]) * ia, 255], o);
  }
});
for (let i = 0; i < W * H; i++) if (preview[4 * i + 3] === 0) preview.set([255, 255, 255, 255], 4 * i);

const outDir = root + 'godot/ui/';
mkdirSync(outDir, { recursive: true });
writeFileSync(outDir + 'iconos.bin', png(W, H, atlas));
writeFileSync(outDir + 'iconos.json', JSON.stringify({ cell: CELL, icons: index }, null, 1) + '\n');
mkdirSync(root + 'shots', { recursive: true });
writeFileSync(root + 'shots/ui-iconos.png', png(W, H, preview));
console.log(`iconos.bin: ${glyphs.length} iconos, ${W} × ${H}`);

// ---------- El emblema ----------

{
  const S = 640;
  const out = new Uint8Array(S * S * 4);
  const KNIGHT = 1;
  const c = S / 2, r = 272, n = 5;
  const box = pieceBox(KNIGHT);
  const scale = (box.y1 - box.y0) / (r * 2 * 0.66); // el caballo ocupa dos tercios del alto de la tesela
  const mx = (box.x0 + box.x1) / 2, my = (box.y0 + box.y1) / 2;
  const squircle = (x, y) => Math.pow(Math.pow(Math.abs(x - c), n) + Math.pow(Math.abs(y - c), n), 1 / n) - r;
  const mix = (a, b, t) => a + (b - a) * t;
  const lerp3 = (a, b, t) => [mix(a[0], b[0], t), mix(a[1], b[1], t), mix(a[2], b[2], t)];
  const PEACH = [1.0, 0.86, 0.73], PINK = [1.0, 0.77, 0.84], LILAC = [0.78, 0.77, 1.0];
  const L = (() => { const v = [-0.46, 0.62, 0.64]; const l = Math.hypot(...v); return v.map((q) => q / l); })();
  for (let y = 0; y < S; y++) for (let x = 0; x < S; x++) {
    const px = x + 0.5, py = y + 0.5;
    // Sombra suave de la tesela, hacia abajo.
    const shadow = 0.2 * smooth(40, -6, squircle(px, py - 16));
    let col = [0.42, 0.34, 0.66], alpha = shadow;
    const tile = clamp01(0.5 - squircle(px, py));
    if (tile > 0) {
      // Degradado pastel en diagonal, con un brillo arriba a la izquierda.
      const t = clamp01((px + py - (2 * c - 2 * r * 0.82)) / (4 * r * 0.82));
      let bg = t < 0.5 ? lerp3(PEACH, PINK, t * 2) : lerp3(PINK, LILAC, (t - 0.5) * 2);
      const glow = 0.26 * smooth(1.25 * r, 0, Math.hypot(px - (c - 0.55 * r), py - (c - 0.7 * r)));
      bg = lerp3(bg, [1, 1, 1], glow);
      // El caballo, en relieve, y su sombra sobre la tesela.
      const sx = mx + (px - c) * scale, sy = my + (py - c - 6) * scale;
      const cast = 0.3 * smooth(-30 * scale, 3 * scale, pieceSd(KNIGHT, sx - 13 * scale, sy - 19 * scale));
      bg = lerp3(bg, [0.5, 0.36, 0.66], cast);
      const inside = clamp01(pieceSd(KNIGHT, sx, sy) / scale + 0.5);
      if (inside > 0) {
        const nu = pieceChannel(KNIGHT, 0, sx, sy) * 2 - 1, nv = pieceChannel(KNIGHT, 1, sx, sy) * 2 - 1;
        const nw = Math.sqrt(Math.max(0, 1 - nu * nu - nv * nv));
        const ao = pieceChannel(KNIGHT, 3, sx, sy);
        const lit = Math.max(0, nu * L[0] + nv * L[1] + nw * L[2]);
        let k = lerp3([0.7, 0.6, 0.84], [1.0, 0.985, 0.965], smooth(0.1, 0.92, lit));
        k = lerp3([0.56, 0.45, 0.74], k, 0.55 + 0.45 * ao);
        // Un filo más claro junto al borde iluminado, como en una pieza de porcelana.
        const rim = 0.2 * smooth(7 * scale, 0, pieceSd(KNIGHT, sx, sy)) * smooth(0.2, 0.9, lit);
        k = lerp3(k, [1, 1, 1], rim);
        bg = lerp3(bg, k, inside);
      }
      col = lerp3(col, bg, tile);
      alpha = alpha + (1 - alpha) * tile;
    }
    out.set([byte(col[0]), byte(col[1]), byte(col[2]), byte(alpha)], 4 * (x + S * y));
  }
  writeFileSync(outDir + 'emblema.bin', png(S, S, out));
  writeFileSync(root + 'shots/ui-emblema.png', png(S, S, out));
  console.log(`emblema.bin: ${S} × ${S}`);
}
