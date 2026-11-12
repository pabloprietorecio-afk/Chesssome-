/**
 * Utilidades sobre chess.js: aplicar jugadas UCI, material, geometría del tablero y evaluación estática de cambios.
 * Todo lo que hay aquí se deduce de las reglas del juego; no interviene ningún motor.
 */
import { Chess, type Move } from 'chess.js';
import type { Color, PieceType, Square, Uci } from './types';

export const VALUE: Record<PieceType, number> = { p: 1, n: 3, b: 3, r: 5, q: 9, k: 100 };

export const other = (c: Color): Color => (c === 'w' ? 'b' : 'w');

export function applyUci(chess: Chess, uci: Uci): Move {
  return chess.move({ from: uci.slice(0, 2), to: uci.slice(2, 4), promotion: uci[4] });
}

/** Aplica la jugada sin lanzar excepción. Devuelve null si es ilegal. */
export function tryUci(chess: Chess, uci: Uci): Move | null {
  try {
    return applyUci(chess, uci);
  } catch {
    return null;
  }
}

export const moveToUci = (m: { from: string; to: string; promotion?: string }): Uci =>
  m.from + m.to + (m.promotion ?? '');

export interface PieceOn {
  type: PieceType;
  color: Color;
  square: Square;
}

export function piecesOf(chess: Chess, color?: Color): PieceOn[] {
  const out: PieceOn[] = [];
  for (const row of chess.board()) {
    for (const cell of row) {
      if (cell && (!color || cell.color === color)) {
        out.push({ type: cell.type, color: cell.color, square: cell.square });
      }
    }
  }
  return out;
}

/** Material de cada bando en puntos clásicos (peón 1, caballo y alfil 3, torre 5, dama 9). El rey no cuenta. */
export function material(chess: Chess): Record<Color, number> {
  const m: Record<Color, number> = { w: 0, b: 0 };
  for (const p of piecesOf(chess)) if (p.type !== 'k') m[p.color] += VALUE[p.type];
  return m;
}

/** Recuento de piezas por tipo para un bando. */
export function census(chess: Chess, color: Color): Record<PieceType, number> {
  const c: Record<PieceType, number> = { p: 0, n: 0, b: 0, r: 0, q: 0, k: 0 };
  for (const p of piecesOf(chess, color)) c[p.type]++;
  return c;
}

export function kingSquare(chess: Chess, color: Color): Square | null {
  return (chess.findPiece({ type: 'k', color })[0] as Square | undefined) ?? null;
}

// ---------- Geometría ----------

export const fileOf = (sq: Square): number => sq.charCodeAt(0) - 97;
export const rankOf = (sq: Square): number => Number(sq[1]) - 1;
export const sqAt = (file: number, rank: number): Square | null =>
  file < 0 || file > 7 || rank < 0 || rank > 7 ? null : String.fromCharCode(97 + file) + (rank + 1);

const ROOK_DIRS: [number, number][] = [
  [1, 0],
  [-1, 0],
  [0, 1],
  [0, -1],
];
const BISHOP_DIRS: [number, number][] = [
  [1, 1],
  [1, -1],
  [-1, 1],
  [-1, -1],
];

export function sliderDirs(type: PieceType): [number, number][] {
  if (type === 'r') return ROOK_DIRS;
  if (type === 'b') return BISHOP_DIRS;
  if (type === 'q') return [...ROOK_DIRS, ...BISHOP_DIRS];
  return [];
}

/** Piezas que se encuentran, en orden, al recorrer una línea desde una casilla (sin incluirla). */
export function ray(chess: Chess, from: Square, dir: [number, number]): PieceOn[] {
  const out: PieceOn[] = [];
  let f = fileOf(from) + dir[0];
  let r = rankOf(from) + dir[1];
  for (;;) {
    const sq = sqAt(f, r);
    if (!sq) break;
    const p = chess.get(sq as never);
    if (p) out.push({ type: p.type, color: p.color, square: sq });
    f += dir[0];
    r += dir[1];
  }
  return out;
}

/** Casillas adyacentes a una dada. */
export function neighbours(sq: Square): Square[] {
  const out: Square[] = [];
  for (let df = -1; df <= 1; df++) {
    for (let dr = -1; dr <= 1; dr++) {
      if (df === 0 && dr === 0) continue;
      const s = sqAt(fileOf(sq) + df, rankOf(sq) + dr);
      if (s) out.push(s);
    }
  }
  return out;
}

export function attackersOf(chess: Chess, sq: Square, by: Color): Square[] {
  return chess.attackers(sq as never, by) as Square[];
}

// ---------- Evaluación estática de cambios (SEE) ----------

/**
 * Ganancia material que puede asegurarse el bando que mueve iniciando capturas en `sq`.
 * Nunca es negativa: siempre puede optar por no capturar. Usa jugadas legales, así que respeta clavadas.
 */
export function seeSquare(chess: Chess, sq: Square, depth = 0): number {
  if (depth > 12) return 0;
  const target = chess.get(sq as never);
  if (!target) return 0;
  // Atacantes del bando que mueve, del menos valioso al más valioso.
  const attackers = (chess.attackers(sq as never, chess.turn()) as Square[])
    .map((from) => ({ from, type: chess.get(from as never)!.type as PieceType }))
    .sort((x, y) => VALUE[x.type] - VALUE[y.type]);
  for (const att of attackers) {
    // Solo capturas legales: un atacante clavado no cuenta.
    const caps = chess.moves({ square: att.from as never, verbose: true }).filter((m) => m.to === sq);
    if (caps.length === 0) continue;
    const m = caps.find((c) => !c.promotion || c.promotion === 'q') ?? caps[0];
    const gain = VALUE[target.type as PieceType] + (m.promotion ? VALUE[m.promotion as PieceType] - 1 : 0);
    chess.move({ from: m.from, to: m.to, promotion: m.promotion });
    const reply = seeSquare(chess, sq, depth + 1);
    chess.undo();
    return Math.max(0, gain - reply);
  }
  return 0;
}

/** Resultado material de UNA captura concreta, contando las recapturas en esa casilla. Puede ser negativo. */
export function seeCapture(m: Move): number {
  if (!m.captured) return 0;
  const gain = VALUE[m.captured as PieceType] + (m.promotion ? VALUE[m.promotion as PieceType] - 1 : 0);
  const probe = new Chess(m.before);
  probe.move({ from: m.from, to: m.to, promotion: m.promotion });
  return gain - seeSquare(probe, m.to);
}

/**
 * Devuelve la misma posición con el turno cambiado ("jugada nula"), o null si no es legal hacerlo
 * (el bando que mueve está en jaque). Sirve para preguntar qué amenaza quien acaba de jugar.
 */
export function passTurn(chess: Chess): Chess | null {
  if (chess.isCheck()) return null;
  const parts = chess.fen().split(' ');
  parts[1] = parts[1] === 'w' ? 'b' : 'w';
  parts[3] = '-';
  try {
    return new Chess(parts.join(' '));
  } catch {
    return null;
  }
}

/**
 * Resuelve el cambio pendiente en UNA casilla: mientras el bando que mueve gane material capturando ahí, captura.
 * Evita contar el material a mitad de un intercambio cuando una variante se corta justo tras una captura.
 * Se limita a esa casilla a propósito: seguir capturando por todo el tablero sería inventar una variante.
 */
export function settleOn(chess: Chess, sq: Square, maxPlies = 8): number {
  let plies = 0;
  while (plies < maxPlies && !chess.isGameOver()) {
    const caps = chess
      .moves({ verbose: true })
      .filter((m) => m.to === sq && m.isCapture() && !m.isEnPassant())
      .sort((a, b) => VALUE[a.piece] - VALUE[b.piece]);
    const m = caps.find((c) => !c.promotion || c.promotion === 'q') ?? caps[0];
    if (!m || seeCapture(m) <= 0) break;
    chess.move({ from: m.from, to: m.to, promotion: m.promotion });
    plies++;
  }
  return plies;
}
