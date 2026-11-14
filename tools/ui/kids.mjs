// Arte del nivel Kids: iconos de colores para los botones y un fondo de juguetes en tonos pastel.
//
// Sale de Fluent Emoji de Microsoft (estilo «Flat», licencia MIT): las SVG que se usan están copiadas en
// tools/ui/fluent/ con su licencia (https://github.com/microsoft/fluentui-emoji).
//
// Uso: node tools/ui/kids.mjs   (npm run ui:kids)
//   godot/ui/kids_iconos.bin    atlas de iconos a color (PNG con otra extensión, como iconos.bin)
//   godot/ui/kids_iconos.json   qué icono hay en cada celda (mismos nombres que los iconos normales)
//   godot/ui/kids_fondo.bin     fondo de juguetes que se repite en mosaico (PNG, transparente)
//   shots/ui-kids.png           vista previa
import { deflateSync } from 'node:zlib';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { Resvg } from '@resvg/resvg-js';

const root = fileURLToPath(new URL('../../', import.meta.url));
const src = root + 'tools/ui/fluent/';

const CELL = 160;
const COLS = 6;

/** nombre del icono en la app → SVG de Fluent Emoji (Flat). */
const ICONS = {
  bulb: 'light_bulb_flat',
  retry: 'counterclockwise_arrows_button_flat',
  next: 'right_arrow_flat',
  back: 'left_arrow_flat',
  sound: 'speaker_high_volume_flat',
  party: 'party_popper_flat',
  book: 'open_book_flat',
  first: 'house_flat',
  sliders: 'gear_flat',
  close: 'cross_mark_flat',
  eye: 'eyes_flat',
  why: 'red_question_mark_flat',
  target: 'star_flat',
  flag: 'chequered_flag_flat',
  piece_knight: 'carousel_horse_flat',
  clock: 'alarm_clock_flat',
  trend: 'chart_increasing_flat',
  cap: 'graduation_cap_flat',
  skip: 'next_track_button_flat',
  step: 'footprints_flat',
  pin: 'pushpin_flat',
  pin_on: 'pushpin_flat',
  trophy: 'trophy_flat',
  spark: 'glowing_star_flat',
};

/** Juguetes y peluches del fondo. */
const TOYS = ['teddy_bear_flat', 'kite_flat', 'balloon_flat', 'duck_flat', 'puzzle_piece_flat', 'soccer_ball_flat', 'rocket_flat', 'locomotive_flat', 'game_die_flat', 'unicorn_flat', 'sauropod_flat', 'rainbow_flat', 'lollipop_flat', 'yo-yo_flat', 'nesting_dolls_flat', 'sailboat_flat', 'panda_flat', 'rabbit_face_flat', 'bear_flat', 'wrapped_gift_flat', 'carousel_horse_flat', 'crayon_flat'];

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

/** Una SVG rasterizada a `side` píxeles: RGBA sin premultiplicar. */
function render(name, side) {
  const svg = readFileSync(src + name + '.svg', 'utf8');
  const img = new Resvg(svg, { fitTo: { mode: 'width', value: side }, background: 'rgba(0,0,0,0)' }).render();
  return { w: img.width, h: img.height, rgba: new Uint8Array(img.pixels) };
}

/** Pega `img` en `dst` con el centro en (cx, cy), girada `angle` radianes; color mezclado con blanco (`wash`) y
 *  opacidad `alpha`. Con `wrap`, lo que sale por un borde entra por el contrario (mosaico sin costuras). */
function stamp(dst, dw, dh, img, cx, cy, angle, wash, alpha, wrap) {
  const cos = Math.cos(angle), sin = Math.sin(angle);
  const half = Math.ceil(Math.hypot(img.w, img.h) / 2) + 1;
  for (let y = -half; y <= half; y++) {
    for (let x = -half; x <= half; x++) {
      // Punto de la imagen que cae aquí (giro inverso) y su muestra bilineal.
      const sx = cos * x + sin * y + img.w / 2 - 0.5;
      const sy = -sin * x + cos * y + img.h / 2 - 0.5;
      if (sx < -1 || sy < -1 || sx > img.w || sy > img.h) continue;
      const x0 = Math.floor(sx), y0 = Math.floor(sy), fx = sx - x0, fy = sy - y0;
      let r = 0, g = 0, b = 0, a = 0;
      for (const [px, py, wgt] of [[x0, y0, (1 - fx) * (1 - fy)], [x0 + 1, y0, fx * (1 - fy)], [x0, y0 + 1, (1 - fx) * fy], [x0 + 1, y0 + 1, fx * fy]]) {
        if (px < 0 || py < 0 || px >= img.w || py >= img.h) continue;
        const i = 4 * (px + img.w * py);
        const pa = img.rgba[i + 3] / 255 * wgt;
        r += img.rgba[i] * pa; g += img.rgba[i + 1] * pa; b += img.rgba[i + 2] * pa; a += pa;
      }
      if (a <= 0.001) continue;
      r /= a; g /= a; b /= a;
      r = r + (255 - r) * wash; g = g + (255 - g) * wash; b = b + (255 - b) * wash;
      a *= alpha;
      let tx = Math.round(cx + x), ty = Math.round(cy + y);
      if (wrap) {
        tx = ((tx % dw) + dw) % dw;
        ty = ((ty % dh) + dh) % dh;
      } else if (tx < 0 || ty < 0 || tx >= dw || ty >= dh) continue;
      const o = 4 * (tx + dw * ty);
      const da = dst[o + 3] / 255;
      const oa = a + da * (1 - a);
      if (oa <= 0) continue;
      dst[o] = Math.round((r * a + dst[o] * da * (1 - a)) / oa);
      dst[o + 1] = Math.round((g * a + dst[o + 1] * da * (1 - a)) / oa);
      dst[o + 2] = Math.round((b * a + dst[o + 2] * da * (1 - a)) / oa);
      dst[o + 3] = Math.round(oa * 255);
    }
  }
}

// ---------- Atlas de iconos ----------
const names = Object.keys(ICONS);
const rows = Math.ceil(names.length / COLS);
const atlas = new Uint8Array(COLS * CELL * rows * CELL * 4);
const index = {};
names.forEach((name, i) => {
  const img = render(ICONS[name], Math.round(CELL * 0.86));
  const col = i % COLS, row = Math.floor(i / COLS);
  stamp(atlas, COLS * CELL, rows * CELL, img, col * CELL + CELL / 2, row * CELL + CELL / 2, 0, 0, 1, false);
  index[name] = [col, row];
});
mkdirSync(root + 'godot/ui', { recursive: true });
writeFileSync(root + 'godot/ui/kids_iconos.bin', png(COLS * CELL, rows * CELL, atlas));
writeFileSync(root + 'godot/ui/kids_iconos.json', JSON.stringify({ cell: CELL, source: 'Fluent Emoji (Microsoft, MIT), estilo Flat', icons: index }, null, 1) + '\n');

// ---------- Fondo de juguetes (mosaico) ----------
// Rejilla con un poco de desorden, para que los juguetes no se amontonen ni dejen huecos grandes.
const TILE = 1024;
const bgImg = new Uint8Array(TILE * TILE * 4);
let seed = 7;
const rnd = () => ((seed = (seed * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff);
const GRID = 4;
let k = 0;
for (let gy = 0; gy < GRID; gy++) {
  for (let gx = 0; gx < GRID; gx++) {
    const toy = TOYS[(k * 5) % TOYS.length];
    k++;
    const side = Math.round(150 + rnd() * 60);
    const img = render(toy, side);
    const cx = (gx + 0.5 + (gy % 2) * 0.5 + (rnd() - 0.5) * 0.3) * (TILE / GRID);
    const cy = (gy + 0.5 + (rnd() - 0.5) * 0.3) * (TILE / GRID);
    stamp(bgImg, TILE, TILE, img, cx, cy, (rnd() - 0.5) * 0.6, 0.42, 0.5, true);
  }
}
writeFileSync(root + 'godot/ui/kids_fondo.bin', png(TILE, TILE, bgImg));

// ---------- Vista previa ----------
const PW = 1024, PH = TILE + rows * CELL;
const prev = new Uint8Array(PW * PH * 4);
for (let i = 0; i < PW * PH; i++) prev.set([238, 240, 252, 255], i * 4);
const over = (srcBuf, sw, sh, ox, oy) => {
  for (let y = 0; y < sh; y++) for (let x = 0; x < sw && x + ox < PW; x++) {
    const s = 4 * (x + sw * y), d = 4 * (x + ox + PW * (y + oy));
    const a = srcBuf[s + 3] / 255;
    for (let c = 0; c < 3; c++) prev[d + c] = Math.round(srcBuf[s + c] * a + prev[d + c] * (1 - a));
  }
};
over(bgImg, TILE, TILE, 0, 0);
over(atlas, COLS * CELL, rows * CELL, 0, TILE);
mkdirSync(root + 'shots', { recursive: true });
writeFileSync(root + 'shots/ui-kids.png', png(PW, PH, prev));
console.log(`Iconos Kids: ${names.length}; fondo ${TILE}×${TILE} con ${GRID * GRID} juguetes`);
