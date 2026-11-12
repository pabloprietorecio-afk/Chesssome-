/**
 * Mide cuánto ocuparía enviar las explicaciones ya generadas (en vez de generarlas en el dispositivo).
 * Uso: npx tsx scripts/measure-precomputed.ts [n_problemas]
 */
import { readFileSync } from 'node:fs';
import { gzipSync, brotliCompressSync } from 'node:zlib';
import { Chess } from 'chess.js';
import { explain, explainSolved } from '../src/core/explain';
import { unpackPuzzle } from '../src/core/pack';
import type { PuzzlePack } from '../src/core/types';

const pack = JSON.parse(readFileSync(new URL('../src/data/puzzles.pack.json', import.meta.url), 'utf8')) as PuzzlePack;
const n = Number(process.argv[2] ?? 30);
const sample = pack.puzzles.slice(0, n).map((p) => unpackPuzzle(p, pack.engine));
let count = 0;
const full: unknown[] = [];
for (const p of sample) {
  const perPuzzle: Record<string, unknown> = { id: p.id, solved: explainSolved(p) };
  for (const pt of p.points) {
    for (const m of new Chess(pt.fen).moves({ verbose: true })) {
      const e = explain(p, pt.index, m.lan);
      // Sin las posiciones intermedias de las variantes: el cliente puede reconstruirlas con las reglas.
      perPuzzle[`${pt.index}:${m.lan}`] = { v: e.verdict, h: e.headline, l: e.levels.map((l) => ({ p: l.paragraphs, a: l.arrows, n: l.lines.map((x) => [x.label, x.tone, x.plies.map((y) => y.uci).join(' ')]), t: l.table })), f: e.facts };
      count++;
    }
  }
  full.push(perPuzzle);
}
const raw = Buffer.from(JSON.stringify(full));
const gz = gzipSync(raw, { level: 9 });
const br = brotliCompressSync(raw);
const packRaw = Buffer.from(JSON.stringify({ ...pack, puzzles: pack.puzzles.slice(0, n) }));
const kb = (b: number) => (b / 1024).toFixed(0);
console.log(JSON.stringify({
  problemas: n,
  explicaciones: count,
  explicacionesPorProblema: (count / n).toFixed(1),
  explicacionesKB: { crudo: kb(raw.length), gzip: kb(gz.length), brotli: kb(br.length) },
  porProblemaKB: { crudo: (raw.length / n / 1024).toFixed(1), brotli: (br.length / n / 1024).toFixed(1) },
  paqueteActualKB: { crudo: kb(packRaw.length), gzip: kb(gzipSync(packRaw).length) },
}, null, 1));
