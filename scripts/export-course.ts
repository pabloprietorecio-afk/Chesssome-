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
import { readFileSync } from 'node:fs';
import { COURSE, toFen, type Accept, type Exercise, type Lesson } from '../src/course/course';
import { KIDS, KIDS_LINES } from '../src/course/kids';
import { VALUE } from '../src/core/chessx';
import { sanEs, the } from '../src/core/lang';
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
        const key = `${m.to}:${mask}:${blacks.filter((_, i) => !(mask & (1 << (stars.length + i)))).join('')}`;
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
  /** Lo mismo para el nivel Kids: sin notación ni casillas, para que haya pocas frases distintas (llevan voz). */
  k: string;
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

/** Nombre de la pieza para el nivel Kids, con artículo. */
const KID_PIECE: Record<string, string> = { p: 'tu peón', n: 'tu caballo', b: 'tu alfil', r: 'tu torre', q: 'tu dama', k: 'tu rey' };
const KID_THE: Record<string, string> = { p: 'el peón', n: 'el caballo', b: 'el alfil', r: 'la torre', q: 'la dama' };

/** Por qué no es mate, para el nivel Kids: solo la clase de salida. */
function kidsEscapeOf(after: Chess): string {
  const replies = after.moves({ verbose: true });
  if (replies.some((r) => r.piece === 'k' && !r.captured)) return 'Es jaque, pero el rey negro se puede escapar. ¡Prueba otra!';
  if (replies.some((r) => r.captured)) return 'Es jaque, pero te pueden capturar esa pieza. ¡Prueba otra!';
  return 'Es jaque, pero pueden tapar el jaque. ¡Prueba otra!';
}

function judge(chess: Chess, m: Move, accept: Accept, best: number): Judged {
  const adult = judgeAdult(chess, m, accept, best);
  return { ...adult, k: judgeKids(chess, m, accept, best) };
}

function judgeKids(chess: Chess, m: Move, accept: Accept, best: number): string {
  const after = load(chess.fen());
  after.move({ from: m.from, to: m.to, promotion: m.promotion });
  switch (accept.kind) {
    case 'check':
      return after.inCheck() ? `¡Jaque! Con ${KID_PIECE[m.piece]} atacas al rey negro.` : 'Esa jugada no ataca al rey negro. ¡Prueba otra!';
    case 'mate':
      if (after.isCheckmate()) return '¡Jaque mate! El rey negro no se puede salvar.';
      if (after.isStalemate()) return '¡Ahogado! El rey negro no está en jaque, pero no se puede mover. Eso es empate.';
      if (after.inCheck()) return kidsEscapeOf(after);
      return 'Esa jugada no da jaque. ¡Prueba otra!';
    case 'castle': {
      const flag = accept.side === 'k' ? 'k' : 'q';
      if (m.flags.includes(flag)) return '¡Enroque! Tu rey ya está escondido.';
      if (m.flags.includes('k') || m.flags.includes('q')) return 'Ese enroque es hacia el otro lado.';
      return 'Para enrocar, mueve el rey dos casillas hacia la torre.';
    }
    case 'enPassant':
      return m.flags.includes('e') ? '¡Al paso! Has capturado el peón negro.' : 'Mueve tu peón en diagonal, justo detrás del peón negro.';
    case 'promote':
      if (m.promotion === 'q') return '¡Coronado! Tu peón ahora es una dama.';
      if (m.promotion) return 'Se puede, pero la dama es la más fuerte. ¡Elige dama!';
      return 'Lleva el peón hasta el final del tablero.';
    case 'mostValuable': {
      if (!m.captured) return 'Esa jugada no captura nada. ¡Prueba otra!';
      const v = VALUE[pieceOf(m.captured)];
      const name = KID_THE[m.captured];
      return v === best ? `¡Bien! ${name[0].toUpperCase()}${name.slice(1)} vale ${v}: es la que más vale.` : `${name[0].toUpperCase()}${name.slice(1)} vale ${v}. Hay otra que vale más.`;
    }
    case 'escape': {
      const way = m.piece === 'k' ? 'king' : m.captured ? 'capture' : 'block';
      return { king: '¡Bien! Has salvado a tu rey moviéndolo.', capture: '¡Bien! Has salvado a tu rey capturando la pieza que atacaba.', block: '¡Bien! Has salvado a tu rey tapando el jaque.' }[way];
    }
  }
}

function judgeAdult(chess: Chess, m: Move, accept: Accept, best: number): Omit<Judged, 'k'> {
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

function exportExercise(e: Exercise, where: string, kids?: string): Record<string, unknown> {
  const fen = e.fen ?? toFen(e.at);
  const k = kids !== undefined ? { kids } : {};
  if (e.kind === 'info') return { kind: 'info', fen, text: e.text, ...k };
  if (e.kind === 'collect') {
    const stars = e.stars ?? [];
    const { par, solution } = solveCollect(fen, e.hero, stars, !!e.safe);
    return { kind: 'collect', fen, hero: e.hero, stars, safe: !!e.safe, text: e.text, ...k, par, solution };
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
  return { kind: 'move', fen, text: e.text, ...k, accept: e.accept.kind, moves, ...(e.source ? { source: e.source } : {}) };
}

// ---------------------------------------------------------------- mates de partidas reales (Lichess, CC0)

const PACK = fileURLToPath(new URL('../src/data/puzzles.pack.json', import.meta.url));
/** Cuántos mates en una jugada entran en el curso, y en cuántas lecciones. */
const REAL_MATES = 12;
const MATES_PER_LESSON = 6;

/** La misma posición vista desde el otro bando: así siempre juegan las blancas (las lecciones hablan del rey negro). */
export function mirrorFen(fen: string): string {
  const [board, turn, castling, ep, half, full] = fen.split(' ');
  const swap = (c: string) => (c === c.toUpperCase() ? c.toLowerCase() : c.toUpperCase());
  const rows = board.split('/').reverse().map((r) => [...r].map((c) => (/[a-z]/i.test(c) ? swap(c) : c)).join(''));
  const cast = castling === '-' ? '-' : [...castling].map(swap).sort((x, y) => 'KQkq'.indexOf(x) - 'KQkq'.indexOf(y)).join('');
  const epm = ep === '-' ? '-' : ep[0] + String(9 - Number(ep[1]));
  return [rows.join('/'), turn === 'w' ? 'b' : 'w', cast, epm, half, full].join(' ');
}

interface PackPuzzle { i: string; f: string; m: string; r: number; p: number; n: number; t: string; g: string }

/**
 * Mates en una jugada de partidas reales: los más fáciles y populares del paquete, con piezas que dan mate
 * variadas. La posición es la de después de la jugada del rival; si juegan negras, se da la vuelta.
 */
export function realMates(): Exercise[] {
  const pack = JSON.parse(readFileSync(PACK, 'utf8')) as { puzzles: PackPuzzle[] };
  const candidates = pack.puzzles
    .filter((p) => p.t.split(' ').includes('mateIn1') && p.r < 1100 && p.p >= 85)
    .sort((x, y) => x.r - y.r || x.i.localeCompare(y.i));
  const chosen: Exercise[] = [];
  const byPiece: Record<string, number> = {};
  for (const p of candidates) {
    const chess = new Chess(p.f);
    const [first, mate] = p.m.split(' ');
    chess.move({ from: first.slice(0, 2), to: first.slice(2, 4), promotion: first[4] });
    let fen = chess.fen();
    const piece = chess.get(mate.slice(0, 2) as never)?.type ?? '?';
    // Variedad: como mucho tres mates con la misma pieza.
    if ((byPiece[piece] ?? 0) >= 3) continue;
    if (chess.turn() === 'b') fen = mirrorFen(fen);
    // Una sola jugada da mate: así el ejercicio tiene una respuesta clara.
    const probe = new Chess(fen);
    const mates = probe.moves({ verbose: true }).filter((m) => {
      const c = new Chess(fen);
      c.move(m);
      return c.isCheckmate();
    });
    if (mates.length !== 1) continue;
    byPiece[piece] = (byPiece[piece] ?? 0) + 1;
    chosen.push({ kind: 'move', at: { pieces: {} }, fen, accept: { kind: 'mate' }, text: 'Posición de una partida real. Da jaque mate en una jugada.', source: { id: p.i, game: p.g } });
    if (chosen.length === REAL_MATES) break;
  }
  if (chosen.length < REAL_MATES) throw new Error(`Solo hay ${chosen.length} mates en una jugada que sirvan`);
  return chosen;
}

function matesUnit(): { id: string; title: string; lessons: Lesson[] } {
  const mates = realMates();
  const lessons: Lesson[] = [];
  for (let i = 0; i < mates.length; i += MATES_PER_LESSON) {
    const n = lessons.length + 1;
    lessons.push({
      id: `mates-${n}`,
      title: `Mates de partidas reales ${n}`,
      icon: 'flag',
      intro: ['Estas posiciones salen de partidas de verdad, jugadas en Lichess. En todas hay un jaque mate en una jugada.', 'Mira bien todo el tablero: hay más piezas que en las lecciones.'],
      exercises: mates.slice(i, i + MATES_PER_LESSON),
      takeaway: 'Antes de jugar, busca si tienes un jaque mate.',
    });
  }
  return { id: 'practica', title: 'Practica el mate', lessons };
}

const KIDS_MATES: { intro: string[]; exercise: string; takeaway: string } = {
  intro: ['Estas posiciones son de partidas de verdad. En todas puedes dar jaque mate con una sola jugada.', 'Mira bien todo el tablero.'],
  exercise: 'Busca el jaque mate.',
  takeaway: '¡Eres un cazador de reyes!',
};

export function buildCourse() {
  const ids = new Set<string>();
  let exercises = 0;
  const units = [...COURSE, matesUnit()].map((u) => ({
    id: u.id,
    title: u.title,
    lessons: u.lessons.map((l) => {
      if (ids.has(l.id)) throw new Error(`Lección repetida: ${l.id}`);
      ids.add(l.id);
      const real = l.id.startsWith('mates-');
      const kids = real ? { intro: KIDS_MATES.intro, takeaway: KIDS_MATES.takeaway, exercises: l.exercises.map(() => KIDS_MATES.exercise) } : KIDS[l.id];
      if (!kids) throw new Error(`Falta el texto Kids de la lección ${l.id}`);
      if (kids.exercises.length !== l.exercises.length) throw new Error(`Lección ${l.id}: ${l.exercises.length} ejercicios y ${kids.exercises.length} textos Kids`);
      return {
        id: l.id,
        title: l.title,
        icon: l.icon,
        intro: l.intro,
        takeaway: l.takeaway,
        kids: { title: ('title' in kids && kids.title) || l.title, intro: kids.intro, takeaway: kids.takeaway },
        exercises: l.exercises.map((e, i) => {
          exercises++;
          return exportExercise(e, `${l.id} #${i + 1}`, kids.exercises[i]);
        }),
      };
    }),
  }));
  for (const id of Object.keys(KIDS)) if (!ids.has(id)) throw new Error(`Texto Kids de una lección que no existe: ${id}`);
  return { generatedBy: 'scripts/export-course.ts (contenido: src/course/course.ts y src/course/kids.ts; mates: Lichess, CC0)', lessons: ids.size, exercises, kidsLines: KIDS_LINES, units };
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
