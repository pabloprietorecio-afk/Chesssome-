/**
 * Lenguaje: notación algebraica en español y nombres de piezas con su género.
 * Las frases se componen aquí para que ninguna otra parte del núcleo concatene artículos a mano.
 */
import type { PieceType, Square } from './types';

const SAN_ES: Record<string, string> = { K: 'R', Q: 'D', R: 'T', B: 'A', N: 'C' };

/** Convierte SAN inglesa (K Q R B N) a española (R D T A C). Los enroques y las casillas no cambian. */
export function sanEs(san: string): string {
  return san.replace(/[KQRBN]/g, (ch) => SAN_ES[ch]);
}

interface Noun {
  s: string; // singular
  pl: string; // plural
  f: boolean; // femenino
}

const NOUN: Record<PieceType, Noun> = {
  p: { s: 'peón', pl: 'peones', f: false },
  n: { s: 'caballo', pl: 'caballos', f: false },
  b: { s: 'alfil', pl: 'alfiles', f: false },
  r: { s: 'torre', pl: 'torres', f: true },
  q: { s: 'dama', pl: 'damas', f: true },
  k: { s: 'rey', pl: 'reyes', f: false },
};

export const pieceName = (t: PieceType): string => NOUN[t].s;
export const piecePlural = (t: PieceType): string => NOUN[t].pl;

/** "el caballo", "la dama" */
export const the = (t: PieceType): string => `${NOUN[t].f ? 'la' : 'el'} ${NOUN[t].s}`;
/** "un caballo", "una torre" */
export const a = (t: PieceType): string => `${NOUN[t].f ? 'una' : 'un'} ${NOUN[t].s}`;
/** "al caballo", "a la dama" */
export const toThe = (t: PieceType): string => `${NOUN[t].f ? 'a la' : 'al'} ${NOUN[t].s}`;
/** "del caballo", "de la dama" */
export const ofThe = (t: PieceType): string => `${NOUN[t].f ? 'de la' : 'del'} ${NOUN[t].s}`;
/** "el caballo de f7" */
export const theOn = (t: PieceType, sq: Square): string => `${the(t)} de ${sq}`;
/** "al caballo de f7" */
export const toTheOn = (t: PieceType, sq: Square): string => `${toThe(t)} de ${sq}`;
/** "tu torre de a1" */
export const yourOn = (t: PieceType, sq: Square): string => `tu ${NOUN[t].s} de ${sq}`;
/** "tu torre" */
export const your = (t: PieceType): string => `tu ${NOUN[t].s}`;
/** "de la torre de a1", "del alfil de c4" */
export const ofTheOn = (t: PieceType, sq: Square): string => `${ofThe(t)} de ${sq}`;
/** Pronombre de objeto: "la" (la captura) / "lo" (lo captura) */
export const pron = (t: PieceType): string => (NOUN[t].f ? 'la' : 'lo');
/** "defendido" / "defendida" según la pieza */
export const adj = (t: PieceType, masc: string, fem: string): string => (NOUN[t].f ? fem : masc);

const NUM = ['cero', 'una', 'dos', 'tres', 'cuatro', 'cinco', 'seis', 'siete', 'ocho'];
const NUM_M = ['cero', 'un', 'dos', 'tres', 'cuatro', 'cinco', 'seis', 'siete', 'ocho'];

/** "dos torres", "un peón" */
export function count(n: number, t: PieceType): string {
  const num = NOUN[t].f ? NUM[n] ?? String(n) : NUM_M[n] ?? String(n);
  return `${num} ${n === 1 ? NOUN[t].s : NOUN[t].pl}`;
}

/** Une elementos como en una frase: "a", "a y b", "a, b y c". */
export function joinY(items: string[]): string {
  if (items.length === 0) return '';
  if (items.length === 1) return items[0];
  return `${items.slice(0, -1).join(', ')} y ${items[items.length - 1]}`;
}

/** Primera letra en mayúscula. */
export const cap = (s: string): string => (s ? s[0].toUpperCase() + s.slice(1) : s);

/** "blancas" / "negras" */
export const sideName = (c: 'w' | 'b'): string => (c === 'w' ? 'blancas' : 'negras');

/** Formatea una evaluación del motor para lectura humana: "+2,35", "−0,80", "mate en 3", "te dan mate en 2". */
export function formatScore(score: { cp: number } | { mate: number }): string {
  if ('mate' in score) {
    if (score.mate > 0) return `mate en ${score.mate}`;
    if (score.mate === 0) return 'mate';
    return `mate en contra en ${-score.mate}`;
  }
  const v = score.cp / 100;
  const sign = v > 0 ? '+' : v < 0 ? '−' : '';
  return `${sign}${Math.abs(v).toFixed(2).replace('.', ',')}`;
}
