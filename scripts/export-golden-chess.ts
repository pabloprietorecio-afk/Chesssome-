/**
 * Datos de oro de las REGLAS para el port a GDScript (godot/core/chess.gd).
 * La referencia es chess.js: jugadas legales de cada posición de los problemas reales, posición tras cada
 * jugada y recuentos «perft» de posiciones de prueba con enroques, capturas al paso y promociones.
 * Uso: npm run golden
 */
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { Chess } from 'chess.js';
import type { PuzzlePack } from '../src/core/types';

const OUT = fileURLToPath(new URL('../godot/tests/golden/chess.json', import.meta.url));

/** Posiciones clásicas para probar generadores de jugadas (enroques, clavadas, al paso, promociones). */
const PERFT_FENS = [
  'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
  'r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1',
  '8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1',
  'r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1',
  'rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8',
  'r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 10',
];

function perft(c: Chess, depth: number): number {
  if (depth === 0) return 1;
  const moves = c.moves({ verbose: true });
  if (depth === 1) return moves.length;
  let n = 0;
  for (const m of moves) {
    c.move(m);
    n += perft(c, depth - 1);
    c.undo();
  }
  return n;
}

const core = (fen: string): string => fen.split(' ').slice(0, 3).join(' ');
const uciOf = (m: { from: string; to: string; promotion?: string }): string => m.from + m.to + (m.promotion ?? '');

export function buildChessGolden(): { positions: unknown[]; perft: unknown[] } {
  const pack = JSON.parse(readFileSync(new URL('../src/data/puzzles.pack.json', import.meta.url), 'utf8')) as PuzzlePack;
  const positions: unknown[] = [];
  for (const p of pack.puzzles.slice(0, 160)) {
    const c = new Chess(p.f);
    for (const u of p.m.split(' ')) {
      const legal = c.moves({ verbose: true }).map(uciOf).sort();
      c.move({ from: u.slice(0, 2), to: u.slice(2, 4), promotion: u[4] });
      positions.push({
        fen: c.history({ verbose: true }).at(-1)!.before,
        legal: legal.join(' '),
        move: u,
        after: core(c.fen()),
        check: c.isCheck(),
        mate: c.isCheckmate(),
        stalemate: c.isStalemate(),
      });
    }
  }
  const perftRows = PERFT_FENS.map((fen, i) => {
    const c = new Chess(fen);
    return { fen, d1: perft(c, 1), d2: perft(c, 2), d3: i === 1 || i === 3 ? perft(c, 3) : 0 };
  });
  return { positions, perft: perftRows };
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  const data = buildChessGolden();
  mkdirSync(dirname(OUT), { recursive: true });
  writeFileSync(OUT, JSON.stringify(data) + '\n');
  console.log(`Escrito ${OUT}: ${data.positions.length} posiciones, ${data.perft.length} perft`);
}
