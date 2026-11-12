/**
 * Herramienta de desarrollo: imprime explicaciones generadas para revisar su calidad a ojo.
 * Uso: npx tsx scripts/show-explanations.ts [n] [semilla]
 */
import { readFileSync, readdirSync } from 'node:fs';
import { Chess } from 'chess.js';
import { explain, explainSolved, scoreValue } from '../src/core/explain';
import type { AnalyzedPuzzle } from '../src/core/types';

const dir = new URL('../data/dev/', import.meta.url);
const all: AnalyzedPuzzle[] = [];
for (const f of readdirSync(dir)) {
  if (!/^analysis.*\.jsonl$/.test(f)) continue;
  for (const line of readFileSync(new URL(f, dir), 'utf8').split('\n')) if (line.trim()) all.push(JSON.parse(line));
}
const n = Number(process.argv[2] ?? 6);
let seed = Number(process.argv[3] ?? 1);
const rand = () => ((seed = (seed * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff);
const only = process.argv[4];
const sample = only ? all.filter((p) => p.id === only) : [...all].sort(() => rand() - 0.5).slice(0, n);

function show(title: string, e: ReturnType<typeof explain>) {
  console.log(`  ── ${title} → [${e.verdict}] ${e.headline}`);
  for (const l of e.levels) {
    console.log(`     N${l.level} ${l.title}:`);
    for (const p of l.paragraphs) console.log(`        ${p}`);
    for (const r of l.table) console.log(`        · ${r.label}: ${r.san} ${r.score} (p${r.depth}) ${r.continuation}`);
  }
}

for (const p of sample) {
  const pt = p.points[0];
  const turn = new Chess(pt.fen).turn() === 'w' ? 'blancas' : 'negras';
  console.log(`\n══ ${p.id} · rating ${p.rating} · juegan ${turn} · ${p.themes.join(' ')}`);
  console.log(`   ${pt.fen}`);
  show('SOLUCIÓN', explainSolved(p));
  const sorted = [...pt.evals].sort((x, y) => scoreValue(y.score) - scoreValue(x.score));
  const wrong = sorted.filter((e) => e.uci !== pt.solution);
  const picks = new Map<string, string>();
  if (wrong[0]) picks.set(wrong[0].uci, 'segunda mejor');
  const chess = new Chess(pt.fen);
  const cap = wrong.find((e) => chess.get(e.uci.slice(2, 4) as never));
  if (cap && !picks.has(cap.uci)) picks.set(cap.uci, 'una captura');
  const mid = wrong[Math.floor(wrong.length / 2)];
  if (mid && !picks.has(mid.uci)) picks.set(mid.uci, 'jugada media');
  const worst = wrong[wrong.length - 1];
  if (worst && !picks.has(worst.uci)) picks.set(worst.uci, 'la peor');
  for (const [uci, why] of picks) {
    const e = explain(p, 0, uci);
    console.log(`  ── ERROR (${why}) → [${e.verdict}] ${e.headline}`);
    for (const para of e.levels[0].paragraphs) console.log(`        ${para}`);
    for (const para of e.levels[1].paragraphs.slice(0, 1)) console.log(`        (N2) ${para}`);
    for (const para of e.levels[2].paragraphs.slice(1)) console.log(`        (N3) ${para}`);
  }
}
