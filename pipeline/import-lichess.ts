/**
 * Importa problemas en el formato oficial de Lichess (lichess_db_puzzle.csv) y los valida.
 *
 * Uso:
 *   npm run pipeline:import -- --in data/raw/lichess_db_puzzle.csv --out data/dev/puzzles.json \
 *        --via "https://database.lichess.org/lichess_db_puzzle.csv.zst" [--per-bin 25] [--bin 100]
 *        [--min-popularity 80] [--min-plays 500] [--seed 7]
 *
 * - Cada fila se valida con las reglas del ajedrez: FEN legal y todas las jugadas legales.
 * - Con --per-bin hace un muestreo estratificado por rating para que haya problemas de todos los niveles.
 * - No inventa nada: las filas que no validan se descartan y se cuentan en el informe.
 */
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname } from 'node:path';
import { Chess } from 'chess.js';
import type { DatasetSource, Puzzle } from '../src/core/types';

function arg(name: string, def?: string): string | undefined {
  const i = process.argv.indexOf(`--${name}`);
  return i >= 0 ? process.argv[i + 1] : def;
}

/** Parser CSV tolerante con comillas (el CSV de Lichess no las usa, pero no se da por hecho). */
export function parseCsvLine(line: string): string[] {
  const out: string[] = [];
  let cur = '';
  let inQ = false;
  for (let i = 0; i < line.length; i++) {
    const ch = line[i];
    if (inQ) {
      if (ch === '"' && line[i + 1] === '"') {
        cur += '"';
        i++;
      } else if (ch === '"') inQ = false;
      else cur += ch;
    } else if (ch === '"') inQ = true;
    else if (ch === ',') {
      out.push(cur);
      cur = '';
    } else cur += ch;
  }
  out.push(cur);
  return out;
}

/** Devuelve null si la fila no describe un problema jugable. */
export function rowToPuzzle(header: string[], row: string[]): Puzzle | null {
  const get = (k: string) => row[header.indexOf(k)] ?? '';
  const moves = get('Moves').trim().split(/\s+/).filter(Boolean);
  const puzzle: Puzzle = {
    id: get('PuzzleId'),
    fen: get('FEN'),
    moves,
    rating: Number(get('Rating')),
    rd: Number(get('RatingDeviation')),
    popularity: Number(get('Popularity')),
    plays: Number(get('NbPlays')),
    themes: get('Themes').trim().split(/\s+/).filter(Boolean),
    gameUrl: get('GameUrl'),
    openingTags: get('OpeningTags').trim().split(/\s+/).filter(Boolean),
  };
  if (!puzzle.id || !puzzle.fen || moves.length < 2 || moves.length % 2 !== 0) return null;
  if (!Number.isFinite(puzzle.rating) || !Number.isFinite(puzzle.rd)) return null;
  try {
    const chess = new Chess(puzzle.fen);
    for (const uci of moves) {
      chess.move({ from: uci.slice(0, 2), to: uci.slice(2, 4), promotion: uci[4] });
    }
  } catch {
    return null;
  }
  return puzzle;
}

/** Generador pseudoaleatorio determinista (mulberry32) para que el muestreo sea reproducible. */
export function rng(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a |= 0;
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/**
 * Orden estratificado: reparte los problemas por tramos de rating y los entrega por turnos,
 * de modo que cualquier prefijo de la lista cubre todos los niveles disponibles.
 */
export function stratifiedOrder(puzzles: Puzzle[], bin: number, seed: number): Puzzle[] {
  const rand = rng(seed);
  const bins = new Map<number, Puzzle[]>();
  for (const p of puzzles) {
    const k = Math.floor(p.rating / bin) * bin;
    if (!bins.has(k)) bins.set(k, []);
    bins.get(k)!.push(p);
  }
  for (const list of bins.values()) {
    for (let i = list.length - 1; i > 0; i--) {
      const j = Math.floor(rand() * (i + 1));
      [list[i], list[j]] = [list[j], list[i]];
    }
  }
  const keys = [...bins.keys()].sort((a, b) => a - b);
  const out: Puzzle[] = [];
  for (let round = 0; ; round++) {
    let any = false;
    for (const k of keys) {
      const list = bins.get(k)!;
      if (round < list.length) {
        out.push(list[round]);
        any = true;
      }
    }
    if (!any) break;
  }
  return out;
}

function main(): void {
  const input = arg('in');
  const output = arg('out', 'data/dev/puzzles.json')!;
  const via = arg('via', 'desconocido')!;
  if (!input) {
    console.error('Falta --in <fichero.csv>');
    process.exit(1);
  }
  const perBin = Number(arg('per-bin', '0'));
  const bin = Number(arg('bin', '100'));
  const minPop = Number(arg('min-popularity', '-100'));
  const minPlays = Number(arg('min-plays', '0'));
  const seed = Number(arg('seed', '7'));

  const lines = readFileSync(input, 'utf8').split(/\r?\n/).filter((l) => l.length > 0);
  const header = parseCsvLine(lines[0]);
  let invalid = 0;
  let filtered = 0;
  const all: Puzzle[] = [];
  for (const line of lines.slice(1)) {
    const p = rowToPuzzle(header, parseCsvLine(line));
    if (!p) {
      invalid++;
      continue;
    }
    if (p.popularity < minPop || p.plays < minPlays) {
      filtered++;
      continue;
    }
    all.push(p);
  }
  let ordered = stratifiedOrder(all, bin, seed);
  if (perBin > 0) {
    const count = new Map<number, number>();
    ordered = ordered.filter((p) => {
      const k = Math.floor(p.rating / bin) * bin;
      const c = count.get(k) ?? 0;
      if (c >= perBin) return false;
      count.set(k, c + 1);
      return true;
    });
  }
  const source: DatasetSource = {
    dataset: 'lichess-puzzles',
    license: 'CC0-1.0',
    origin: 'https://database.lichess.org/#puzzles',
    via,
    retrievedAt: new Date().toISOString().slice(0, 10),
  };
  mkdirSync(dirname(output), { recursive: true });
  writeFileSync(output, JSON.stringify({ source, puzzles: ordered }, null, 0));
  const ratings = ordered.map((p) => p.rating);
  console.log(
    JSON.stringify({
      filas: lines.length - 1,
      invalidas: invalid,
      filtradas: filtered,
      importadas: ordered.length,
      ratingMin: Math.min(...ratings),
      ratingMax: Math.max(...ratings),
      salida: output,
    }),
  );
}

if (process.argv[1] && process.argv[1].endsWith('import-lichess.ts')) main();
