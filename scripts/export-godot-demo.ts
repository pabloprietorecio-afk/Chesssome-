/**
 * Exporta una muestra de problemas para la demo 3D de Godot (godot/data/demo_puzzles.json).
 * Son los mismos problemas reales de Lichess (CC0) del paquete provisional de desarrollo.
 * Uso: npx tsx scripts/export-godot-demo.ts [cuántos]
 */
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { unpackPuzzle } from '../src/core/pack';
import { primaryTheme, themeName } from '../src/core/themes';
import type { PuzzlePack } from '../src/core/types';

const OUT = fileURLToPath(new URL('../godot/data/demo_puzzles.json', import.meta.url));
const n = Number(process.argv[2] ?? 60);
const pack = JSON.parse(readFileSync(new URL('../src/data/puzzles.pack.json', import.meta.url), 'utf8')) as PuzzlePack;
const all = pack.puzzles.map((p) => unpackPuzzle(p, pack.engine)).sort((a, b) => a.rating - b.rating);
// Repartidos por dificultad, de fácil a difícil.
const picked = Array.from({ length: n }, (_, i) => all[Math.floor((i * (all.length - 1)) / (n - 1))]);
const out = {
  provisional: true,
  source: 'Lichess (CC0), muestra de desarrollo',
  puzzles: picked.map((p) => ({ id: p.id, fen: p.fen, moves: p.moves, rating: p.rating, theme: themeName(primaryTheme(p.themes)) })),
};
mkdirSync(dirname(OUT), { recursive: true });
writeFileSync(OUT, JSON.stringify(out) + '\n');
console.log(`Escrito ${OUT}: ${out.puzzles.length} problemas (${picked[0].rating}–${picked.at(-1)!.rating})`);
