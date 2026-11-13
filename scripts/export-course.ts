/**
 * Comprueba y exporta el curso «Aprende a jugar» (src/course/course.ts) para la app: godot/data/curso.json.
 *
 * Cada ejercicio se resuelve aquí con las reglas (chess.js):
 *   collect  búsqueda en anchura del camino más corto que recoge todas las estrellas y captura todas las piezas
 *            negras (que no se mueven), sin terminar en una casilla atacada si el ejercicio es «safe». Si no hay
 *            camino, falla. Se exportan el mínimo de jugadas (par) y una solución.
 *   move     se juzgan todas las jugadas legales: cuáles valen y, para las que no, por qué (en una frase).
 * Un ejercicio mal planteado (casilla repetida, estrella ocupada, posición imposible, nada que valga, una
 * salida del jaque que no es la que dice la lección…) lanza un error: no llega a la app.
 *
 * Uso: npm run course   (la prueba godot/tests/test_course.gd repite cada solución con las reglas de Godot)
 */
import { mkdirSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { Chess, validateFen, type Move } from 'chess.js';
import { COURSE, toFen, type Accept, type Exercise } from '../src/course/course';
import { VALUE } from '../src/core/chessx';
import { pieceName, sanEs, the } from '../src/core/lang';
import type { PieceType } from '../src/core/types';

const OUT = fileURLToPath(new URL('../godot/data/curso.json', import.meta.url));

const uciOf = (m: Move): string => m.from + m.to + (m.promotion ?? '');
const load = (fen: string): Chess => new Chess(fen, { skipValidation: true });
const withTurn = (fen: string, turn: 'w' | 'b'): string => {
  const parts = fen.split(' ');
  parts[1] = turn;
  parts[3] = '-';
  return parts.join(' ');
};

interface Collect {
  par: number;
  solution: string[];
}

/** Camino más corto del héroe que recoge todo. Las negras no se mueven; el turno vuelve siempre a blancas. */
export function solveCollect(fen: string, hero: string, stars: string[], safe: boolean): Collect {
  const start = load(fen);
  if (!start.get(hero as never) || start.get(hero as never)!.color !== 'w') throw new Error(`No hay pieza blanca en ${hero}`);
  for (const s of stars) if (start.get(s as never)) throw new Error(`Estrella en una casilla ocupada: ${s}`);
  const blacks = start.board().flat().filter((p) => p && p.color === 'b').map((p) => p!.square as string);
  const goals = [...stars, ...blacks];
  if (goals.length === 0) throw new Error('Nada que recoger');
  if (goals.length > 12) throw new Error('Demasiados objetivos');
  const full = (1 << goals.length) - 1;
  type Node = { fen: string; sq: string; mask: number; path: string[] };
  const seen = new Set<string>([`${hero}:0`]);
  let frontier: Node[] = [{ fen: withTurn(fen, 'w'), sq: hero, mask: 0, path: [] }];
  for (let depth = 0; depth < 40 && frontier.length > 0; depth++) {
    const next: Node[] = [];
    for (const node of frontier) {
      const chess = load(node.fen);
      for (const m of chess.moves({ square: node.sq as never, verbose: true })) {
        if (m.promotion && m.promotion !== 'q') continue;
        const after = load(node.fen);
        after.move({ from: m.from, to: m.to, promotion: m.promotion });
        const afterFen = withTurn(after.fen(), 'w');
        const probe = load(afterFen);
        if (safe && probe.isAttacked(m.to as never, 'b')) continue;
        let mask = node.mask;
        const gi = goals.indexOf(m.to);
        if (gi >= 0) mask |= 1 << gi;
        const path = [...node.path, uciOf(m)];
        if (mask === full) return { par: path.length, solution: path };
        const key = `${m.to}:${mask}:${blacks.filter((b, i) => !(mask & (1 << (stars.length + i)))).join('')}`;
        if (seen.has(key)) continue;
        seen.add(key);
        next.push({ fen: afterFen, sq: m.to, mask, path });
      }
    }
    frontier = next;
  }
  throw new Error(`Sin solución: ${fen} (héroe ${hero})`);
}

interface Judged {
  ok: boolean;
  /** Qué decir tras esa jugada. */
  t: string;
}

const pieceOf = (t: string): PieceType => t as PieceType;

/** Por qué una jugada que no da mate no lo es: una salida del rival, dicha en una frase. */
function escapeOf(after: Chess): string {
  const replies = after.moves({ verbose: true });
  const king = replies.find((r) => r.piece === 'k' && !r.captured);
  if (king) return `el rey puede escaparse a ${king.to}`;
  const capture = replies.find((r) => r.captured);
  if (capture) return `pueden capturar tu pieza con ${sanEs(capture.san)}`;
  return `pueden tapar el jaque con ${sanEs(replies[0].san)}`;
}

function judge(chess: Chess, m: Move, accept: Accept, best: number): Judged {
  const after = load(chess.fen());
  after.move({ from: m.from, to: m.to, promotion: m.promotion });
  const san = sanEs(m.san);
  switch (accept.kind) {
    case 'check':
      return after.inCheck() ? { ok: true, t: `¡Jaque! Con ${san} atacas al rey negro.` } : { ok: false, t: `${san} no da jaque: el rey negro no queda atacado.` };
    case 'mate':
      if (after.isCheckmate()) return { ok: true, t: `¡Jaque mate! Con ${san} el rey negro no tiene salida.` };
      if (after.isStalemate()) return { ok: false, t: `¡Ahogado! Tras ${san} el rey negro no está en jaque y no tiene ninguna jugada: sería tablas.` };
      if (after.inCheck()) return { ok: false, t: `${san} es jaque, pero no mate: ${escapeOf(after)}.` };
      return { ok: false, t: `${san} no es jaque: el rey negro no está atacado.` };
    case 'castle': {
      const flag = accept.side === 'k' ? 'k' : 'q';
      if (m.flags.includes(flag)) return { ok: true, t: accept.side === 'k' ? '¡Enroque corto! El rey queda resguardado y la torre entra en juego.' : '¡Enroque largo! La torre va al centro y el rey se aparta.' };
      if (m.flags.includes('k') || m.flags.includes('q')) return { ok: false, t: 'Ese es el enroque del otro lado.' };
      return { ok: false, t: 'Para enrocar, mueve el rey dos casillas hacia la torre.' };
    }
    case 'enPassant':
      return m.flags.includes('e') ? { ok: true, t: `¡Al paso! ${san}: tu peón captura como si el negro hubiera avanzado solo una casilla.` } : { ok: false, t: `Mueve tu peón en diagonal a ${chess.fen().split(' ')[3]}, la casilla por la que pasó el peón negro.` };
    case 'promote':
      if (m.promotion === 'q') return { ok: true, t: `¡Coronado! ${san}: el peón se convierte en dama.` };
      if (m.promotion) return { ok: false, t: `También se puede, pero la dama es la pieza más fuerte. Elige dama.` };
      return { ok: false, t: 'Lleva el peón hasta la última fila.' };
    case 'mostValuable': {
      if (!m.captured) return { ok: false, t: `${san} no captura nada. Busca la pieza que más vale.` };
      const v = VALUE[pieceOf(m.captured)];
      return v === best
        ? { ok: true, t: `Bien: ${the(pieceOf(m.captured))} vale ${v}, más que las demás.` }
        : { ok: false, t: `${the(pieceOf(m.captured))[0].toUpperCase()}${the(pieceOf(m.captured)).slice(1)} vale ${v}. Hay otra que vale más.` };
    }
    case 'escape': {
      const way = m.piece === 'k' ? 'king' : m.captured ? 'capture' : 'block';
      if (way !== accept.way) throw new Error(`En «salir del jaque» (${accept.way}) hay otra salida: ${m.san}`);
      const words = { king: `moviendo el rey (${san})`, capture: `capturando la pieza que daba jaque (${san})`, block: `poniendo ${the(pieceOf(m.piece))} en medio (${san})` }[way];
      return { ok: true, t: `Has salido del jaque ${words}.` };
    }
  }
}

function exportExercise(e: Exercise, where: string): Record<string, unknown> {
  const fen = toFen(e.at);
  if (e.kind === 'info') return { kind: 'info', fen, text: e.text };
  if (e.kind === 'collect') {
    const stars = e.stars ?? [];
    const { par, solution } = solveCollect(fen, e.hero, stars, !!e.safe);
    return { kind: 'collect', fen, hero: e.hero, stars, safe: !!e.safe, text: e.text, par, solution };
  }
  const valid = validateFen(fen);
  if (!valid.ok) throw new Error(`${where}: posición imposible (${valid.error})`);
  const chess = new Chess(fen);
  const legal = chess.moves({ verbose: true });
  if (legal.length === 0) throw new Error(`${where}: sin jugadas`);
  const best = Math.max(0, ...legal.map((m) => (m.captured ? VALUE[pieceOf(m.captured)] : 0)));
  const moves: Record<string, Judged> = {};
  for (const m of legal) moves[uciOf(m)] = judge(chess, m, e.accept, best);
  const good = Object.values(moves).filter((j) => j.ok).length;
  if (good === 0) throw new Error(`${where}: ninguna jugada vale`);
  if (e.accept.kind === 'mostValuable' && legal.filter((m) => m.captured && VALUE[pieceOf(m.captured)] === best).length !== 1) {
    throw new Error(`${where}: hay más de una captura de máximo valor`);
  }
  return { kind: 'move', fen, text: e.text, accept: e.accept.kind, moves };
}

export function buildCourse() {
  const ids = new Set<string>();
  let exercises = 0;
  const units = COURSE.map((u) => ({
    id: u.id,
    title: u.title,
    lessons: u.lessons.map((l) => {
      if (ids.has(l.id)) throw new Error(`Lección repetida: ${l.id}`);
      ids.add(l.id);
      return {
        id: l.id,
        title: l.title,
        icon: l.icon,
        intro: l.intro,
        takeaway: l.takeaway,
        exercises: l.exercises.map((e, i) => {
          exercises++;
          return exportExercise(e, `${l.id} #${i + 1}`);
        }),
      };
    }),
  }));
  return { generatedBy: 'scripts/export-course.ts (contenido: src/course/course.ts)', lessons: ids.size, exercises, units };
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  const data = buildCourse();
  mkdirSync(fileURLToPath(new URL('../godot/data/', import.meta.url)), { recursive: true });
  writeFileSync(OUT, JSON.stringify(data) + '\n');
  console.log(`Escrito ${OUT}: ${data.lessons} lecciones, ${data.exercises} ejercicios`);
  for (const u of data.units) for (const l of u.lessons) for (const [i, e] of l.exercises.entries()) {
    if (e.kind === 'collect') console.log(`  ${l.id} #${i + 1}: mínimo ${e.par} (${(e.solution as string[]).join(' ')})`);
    if (e.kind === 'move') console.log(`  ${l.id} #${i + 1}: valen ${Object.entries(e.moves as Record<string, Judged>).filter(([, j]) => j.ok).map(([u]) => u).join(' ')}`);
  }
}
