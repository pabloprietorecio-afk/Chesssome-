/**
 * Capa explicativa.
 *
 * Reparto de responsabilidades:
 *   1. El MOTOR decide qué jugada es mejor y qué variante sigue a cada jugada (dato precalculado).
 *   2. Las REGLAS dicen qué hace cada jugada en el tablero: qué captura, a quién ataca, qué deja colgando.
 *   3. LICHESS aporta la etiqueta del tema del problema.
 *   4. Este módulo redacta. Cada frase sale de un hecho de 1, 2 o 3; aquí no se calcula ajedrez nuevo
 *      ni se afirma nada que no esté en la hoja de hechos (`facts`).
 *
 * Si un hecho no supera sus comprobaciones (por ejemplo, una ganancia de material que el motor no respalda),
 * la frase se sustituye por una más prudente en lugar de publicarse.
 */
import { Chess } from 'chess.js';
import { VALUE, census, material, other, settleOn, tryUci } from './chessx';
import {
  a,
  adj,
  cap,
  count,
  formatScore,
  joinY,
  ofTheOn,
  pieceName,
  pron,
  sanEs,
  the,
  theOn,
  toTheOn,
  your,
  yourOn,
} from './lang';
import { describeMove, existingPins, matePattern, type Motif, type MoveFacts } from './motifs';
import { THEMES, conceptThemes, themeName } from './themes';
import type { AnalyzedPuzzle, Color, MoveEval, PieceType, Score, Square, Uci } from './types';

// ---------- Tipos públicos ----------

/**
 * best      la jugada del problema (o un mate inmediato alternativo)
 * alsoWins  el motor la valora casi igual que la solución
 * slower    sigue ganando, pero claramente peor que la solución
 * missed    deja escapar la ventaja sin llegar a perder
 * loses     deja la posición peor o perdida
 */
export type Verdict = 'best' | 'alsoWins' | 'slower' | 'missed' | 'loses';

/**
 * Qué clase de error es una jugada equivocada, por su consecuencia (la evaluación inicial y el perfil del
 * jugador lo usan para saber en qué falla, no solo cuánto):
 *   mate       permite mate (en la respuesta o forzado)
 *   hangMoved  la pieza que se mueve queda a tiro y se pierde material
 *   hangOther  la respuesta captura otra pieza y se pierde material
 *   material   se pierde material en pocas jugadas sin una captura inmediata
 *   worse      la posición queda perdida según el motor, sin pérdida concreta a corto plazo
 *   missed     no pierde, pero deja pasar la ocasión
 *   slower     también gana (o es casi igual de buena), pero no es la más precisa
 * '' si la jugada es la del problema.
 */
export type ErrorKind = '' | 'mate' | 'hangMoved' | 'hangOther' | 'material' | 'worse' | 'missed' | 'slower';

export interface Arrow {
  from: Square;
  to: Square;
  tone: 'good' | 'bad' | 'info';
}

export interface LinePly {
  uci: Uci;
  san: string;
  fenAfter: string;
  color: Color;
  moveNumber: number;
}

export interface Line {
  label: string;
  tone: 'good' | 'bad';
  startFen: string;
  plies: LinePly[];
  /** Variante escrita: "1. Cf7+ Rg8 2. Cxd8" */
  text: string;
}

export interface CandidateRow {
  label: string;
  san: string;
  score: string;
  depth: number;
  continuation: string;
}

/** Hecho con su procedencia. La explicación solo puede decir lo que hay aquí. */
export interface Fact {
  source: 'reglas' | 'motor' | 'lichess';
  text: string;
}

export interface Level {
  level: 1 | 2 | 3 | 4;
  title: string;
  paragraphs: string[];
  arrows: Arrow[];
  lines: Line[];
  table: CandidateRow[];
}

export interface Explanation {
  puzzleId: string;
  pointIndex: number;
  played: Uci;
  playedSan: string;
  bestUci: Uci;
  bestSan: string;
  correct: boolean;
  verdict: Verdict;
  errorKind: ErrorKind;
  headline: string;
  levels: [Level, Level, Level, Level];
  facts: Fact[];
}

// ---------- Evaluaciones ----------

/** Valor comparable de una evaluación: los mates dominan a cualquier ventaja material. */
export function scoreValue(s: Score): number {
  if ('cp' in s) return s.cp;
  return s.mate > 0 ? 100000 - s.mate : -100000 - s.mate;
}

const findEval = (list: MoveEval[], uci: Uci): MoveEval | undefined => list.find((e) => e.uci === uci);

function sanOf(fen: string, uci: Uci): string {
  const chess = new Chess(fen);
  const m = tryUci(chess, uci);
  return m ? sanEs(m.san) : uci;
}

// ---------- Variantes ----------

export function buildLine(startFen: string, ucis: Uci[], label: string, tone: 'good' | 'bad'): Line {
  const chess = new Chess(startFen);
  const plies: LinePly[] = [];
  const parts: string[] = [];
  for (const uci of ucis) {
    const color = chess.turn();
    const moveNumber = chess.moveNumber();
    const m = tryUci(chess, uci);
    if (!m) break; // una variante del motor no debería contener jugadas ilegales; si ocurre, se corta ahí
    const san = sanEs(m.san);
    plies.push({ uci, san, fenAfter: chess.fen(), color, moveNumber });
    if (color === 'w') parts.push(`${moveNumber}. ${san}`);
    else parts.push(plies.length === 1 ? `${moveNumber}… ${san}` : san);
  }
  return { label, tone, startFen, plies, text: parts.join(' ') };
}

// ---------- Resultado de una variante ----------

type Tally = Partial<Record<PieceType, number>>;

export interface Outcome {
  /** La variante termina en jaque mate dado por `pov`. */
  mates: boolean;
  /** `pov` recibe mate al final de la variante. */
  mated: boolean;
  /** Jugadas de `pov` hasta el final de la variante. */
  povMoves: number;
  /** Balance material final menos inicial, desde `pov`, tras resolver los cambios pendientes. */
  delta: number;
  oppLost: Tally;
  ownLost: Tally;
  promoted: boolean;
  oppPromoted: boolean;
  oppBefore: Record<PieceType, number>;
  ownBefore: Record<PieceType, number>;
  stalemate: boolean;
}

export function lineOutcome(startFen: string, ucis: Uci[], pov: Color): Outcome {
  const chess = new Chess(startFen);
  const opp = other(pov);
  const m0 = material(chess);
  const own0 = census(chess, pov);
  const opp0 = census(chess, opp);
  let promoted = false;
  let oppPromoted = false;
  let povMoves = 0;
  let lastTo: Square | null = null;
  for (const uci of ucis) {
    const color = chess.turn();
    const m = tryUci(chess, uci);
    if (!m) break;
    lastTo = m.to;
    if (color === pov) {
      povMoves++;
      if (m.promotion) promoted = true;
    } else if (m.promotion) oppPromoted = true;
  }
  const mates = chess.isCheckmate() && chess.turn() === opp;
  const mated = chess.isCheckmate() && chess.turn() === pov;
  const stalemate = chess.isStalemate();
  if (!chess.isGameOver() && lastTo) settleOn(chess, lastTo);
  const m1 = material(chess);
  const own1 = census(chess, pov);
  const opp1 = census(chess, opp);
  const oppLost: Tally = {};
  const ownLost: Tally = {};
  for (const t of ORDER) {
    if (opp0[t] - opp1[t] > 0) oppLost[t] = opp0[t] - opp1[t];
    if (own0[t] - own1[t] > 0) ownLost[t] = own0[t] - own1[t];
  }
  return {
    mates,
    mated,
    povMoves,
    delta: m1[pov] - m1[opp] - (m0[pov] - m0[opp]),
    oppLost,
    ownLost,
    promoted,
    oppPromoted,
    oppBefore: opp0,
    ownBefore: own0,
    stalemate,
  };
}

const ORDER: PieceType[] = ['q', 'r', 'b', 'n', 'p'];
const kinds = (t: Tally): PieceType[] => ORDER.filter((k) => (t[k] ?? 0) > 0);
const valueOf = (t: Tally): number => ORDER.reduce((s, k) => s + (t[k] ?? 0) * VALUE[k], 0);
const isExchange = (big: Tally, small: Tally): PieceType | null => {
  const bk = kinds(big);
  const sk = kinds(small);
  if (bk.length === 1 && bk[0] === 'r' && big.r === 1 && sk.length === 1 && (sk[0] === 'b' || sk[0] === 'n') && small[sk[0]] === 1) return sk[0];
  return null;
};

/**
 * Anula lo que ambos bandos pierden por igual (torre por torre, alfil por caballo, peón por peón)
 * para que la frase cuente el saldo y no cada cambio intermedio.
 */
function cancelEqual(x: Tally, y: Tally): void {
  for (const k of ORDER) {
    const c = Math.min(x[k] ?? 0, y[k] ?? 0);
    if (c > 0) {
      x[k] = (x[k] ?? 0) - c;
      y[k] = (y[k] ?? 0) - c;
    }
  }
  for (const [m1, m2] of [['b', 'n'], ['n', 'b']] as [PieceType, PieceType][]) {
    const c = Math.min(x[m1] ?? 0, y[m2] ?? 0);
    if (c > 0) {
      x[m1] = (x[m1] ?? 0) - c;
      y[m2] = (y[m2] ?? 0) - c;
    }
  }
}

/** "a cambio de la torre", "a cambio del caballo" */
const inExchangeFor = (list: string): string => `a cambio de ${list}`.replace(/ de el /, ' del ');

const points = (n: number): string => (n === 1 ? '1 punto' : `${n} puntos`);

/** "la dama", "una torre y un peón", "dos peones". Usa "la/el" cuando esa pieza era única. */
function listPieces(t: Tally, before: Record<PieceType, number>): string {
  const items: string[] = [];
  for (const k of ORDER) {
    const n = t[k] ?? 0;
    if (n === 0) continue;
    if (n === 1) items.push(before[k] === 1 && k !== 'p' ? the(k) : a(k));
    else items.push(count(n, k));
  }
  return joinY(items);
}

/** Ganancia material en palabras ("gana la dama" / "ganas la dama") o null si no hay ganancia neta. */
function gainPhrase(o: Outcome, person: 'move' | 'you'): string | null {
  if (o.delta <= 0) return null;
  const verb = person === 'you' ? 'ganas' : 'gana';
  const gained: Tally = { ...o.oppLost };
  const lost: Tally = { ...o.ownLost };
  // Una coronación propia aparece en el recuento como un peón menos: se cuenta aparte.
  let crown = '';
  if (o.promoted && (lost.p ?? 0) > 0) {
    lost.p = (lost.p ?? 0) - 1;
    crown = person === 'you' ? 'coronas un peón' : 'corona un peón';
  }
  cancelEqual(gained, lost);
  const gk = kinds(gained);
  const lk = kinds(lost);
  let core: string | null = null;
  const minor = isExchange(gained, lost);
  if (gk.length > 0 && lk.length === 0) core = `${verb} ${listPieces(gained, o.oppBefore)}`;
  else if (minor) core = `${verb} la calidad (torre por ${pieceName(minor)})`;
  else if (gk.length > 0 && gk.length <= 3 && lk.length <= 2 && valueOf(gained) > valueOf(lost))
    core = `${verb} ${listPieces(gained, o.oppBefore)} ${inExchangeFor(listPieces(lost, o.ownBefore))}`;
  else if (gk.length > 0 && valueOf(gained) > valueOf(lost)) core = `${verb} material (${points(o.delta)})`;
  if (crown && core) return `${crown} y ${core}`;
  return crown || core;
}

/** Pérdida material en segunda persona ("pierdes la dama") o null si no hay pérdida neta. */
function lossPhrase(o: Outcome): string | null {
  if (o.delta >= 0) return null;
  const lost: Tally = { ...o.ownLost };
  const gained: Tally = { ...o.oppLost };
  let crown = '';
  if (o.oppPromoted && (gained.p ?? 0) > 0) {
    gained.p = (gained.p ?? 0) - 1;
    crown = 'el rival corona un peón';
  }
  cancelEqual(lost, gained);
  const lk = kinds(lost);
  const gk = kinds(gained);
  let core: string | null = null;
  const minor = isExchange(lost, gained);
  if (lk.length > 0 && gk.length === 0) core = `pierdes ${listPieces(lost, o.ownBefore)}`;
  else if (minor) core = `pierdes la calidad (torre por ${pieceName(minor)})`;
  else if (lk.length > 0 && lk.length <= 2 && gk.length <= 2 && valueOf(lost) > valueOf(gained))
    core = `pierdes ${listPieces(lost, o.ownBefore)} ${inExchangeFor(listPieces(gained, o.oppBefore))}`;
  else if (lk.length > 0 && valueOf(lost) > valueOf(gained)) core = `pierdes material (${points(-o.delta)})`;
  if (crown && core) return `${crown} y ${core}`;
  return crown || core;
}

/** Valoración en palabras de una evaluación del motor, desde quien mueve. */
function evalWords(s: Score): string {
  if ('mate' in s) return s.mate > 0 ? `hay mate forzado en ${s.mate}` : `recibes mate en ${-s.mate}`;
  const c = s.cp;
  if (c >= 500) return 'conservas una ventaja decisiva';
  if (c >= 200) return 'conservas una ventaja clara';
  if (c >= 60) return 'te queda solo una pequeña ventaja';
  if (c > -60) return 'la posición queda igualada';
  if (c > -200) return 'quedas algo peor';
  if (c > -500) return 'quedas claramente peor';
  return 'la posición queda perdida';
}

function advantageWords(c: number): string {
  if (c >= 500) return 'consigue una ventaja decisiva';
  if (c >= 200) return 'consigue una ventaja clara';
  if (c >= 60) return 'consigue una pequeña ventaja';
  if (c > -60) return 'mantiene la igualdad';
  return 'es la que mejor resiste';
}

// ---------- Frases a partir de los hechos del tablero ----------

type MotifOf<K extends Motif['kind']> = Extract<Motif, { kind: K }>;
const pick = <K extends Motif['kind']>(f: MoveFacts, k: K): MotifOf<K> | undefined =>
  f.motifs.find((m) => m.kind === k) as MotifOf<K> | undefined;

/** Lo que una jugada hace a primera vista: por qué resulta tentadora. Solo hechos de reglas. */
function temptations(f: MoveFacts): string[] {
  const out: string[] = [];
  const fork = pick(f, 'fork');
  const capture = pick(f, 'capture');
  const check = pick(f, 'check');
  const promo = pick(f, 'promotion');
  const attack = pick(f, 'attack');
  const threat = pick(f, 'mateThreat');
  const disc = pick(f, 'discovered');
  if (capture) {
    const n = census(new Chess(f.fenBefore), capture.captured.color)[capture.captured.type];
    out.push(`captura ${n === 1 && capture.captured.type !== 'p' ? the(capture.captured.type) : a(capture.captured.type)}`);
  }
  if (promo) out.push('corona');
  if (fork) out.push(`ataca a la vez ${joinY(fork.targets.slice(0, 2).map((t) => toTheOn(t.type, t.square)))}`);
  else if (check) out.push(check.double ? 'da jaque doble' : 'da jaque');
  if (threat) out.push(`amenaza mate con ${sanEs(threat.san)}`);
  if (attack && VALUE[attack.target.type] >= 3) out.push(`ataca ${toTheOn(attack.target.type, attack.target.square)}`);
  if (disc && disc.target.type !== 'k') out.push(`abre un ataque sobre ${theOn(disc.target.type, disc.target.square)}`);
  return out.slice(0, 2);
}

/** Qué hace la respuesta del rival, dirigido al usuario ("captura tu torre de a1 con jaque"). */
function replyEffect(f: MoveFacts): string {
  if (pick(f, 'checkmate')) return 'es jaque mate';
  const capture = pick(f, 'capture');
  const check = pick(f, 'check');
  const fork = pick(f, 'fork');
  const promo = pick(f, 'promotion');
  const core: string[] = [];
  if (capture) core.push(`captura ${yourOn(capture.captured.type, capture.captured.square)}`);
  if (promo) core.push('corona');
  if (fork && !capture) core.push(`ataca a la vez ${joinY(fork.targets.slice(0, 2).map((t) => your(t.type)))}`);
  if (core.length > 0) return core.join(' y ') + (check && !(fork && !capture) ? ' con jaque' : '');
  if (check) return 'da jaque';
  const threat = pick(f, 'mateThreat');
  if (threat) return `amenaza mate con ${sanEs(threat.san)}`;
  const attack = pick(f, 'attack');
  if (attack) return `ataca ${yourOn(attack.target.type, attack.target.square)}`;
  return '';
}

// ---------- Concepto (nivel 2) ----------

interface Instance {
  text: string;
  arrows: Arrow[];
  /** Jugada propia de la solución en la que aparece (0 = la primera). Las flechas solo valen en la posición actual. */
  at: number;
}

/** Busca en la solución el momento en que el tema se ve en el tablero y lo describe con piezas y casillas. */
function findInstance(key: string, startFen: string, line: Uci[], pov: Color): Instance | null {
  const chess = new Chess(startFen);
  const mine: MoveFacts[] = [];
  const replies: (Uci | null)[] = [];
  for (let i = 0; i < line.length; i++) {
    const fenBefore = chess.fen();
    const isMine = chess.turn() === pov;
    if (!tryUci(chess, line[i])) break;
    if (isMine) {
      mine.push(describeMove(fenBefore, line[i]));
      replies.push(line[i + 1] ?? null);
    }
  }
  const first = <K extends Motif['kind']>(k: K, ok: (m: MotifOf<K>) => boolean = () => true) => {
    for (const [at, f] of mine.entries()) {
      const m = f.motifs.find((x) => x.kind === k && ok(x as MotifOf<K>)) as MotifOf<K> | undefined;
      if (m) return { f, m, at };
    }
    return null;
  };
  const san = (f: MoveFacts) => sanEs(f.move.san);

  switch (key) {
    case 'fork': {
      const hit = first('fork');
      if (!hit) return null;
      const targets = hit.m.targets.slice(0, 3);
      return {
        text: `Con ${san(hit.f)}, ${theOn(hit.m.by.type, hit.m.by.square)} ataca a la vez ${joinY(targets.map((t) => toTheOn(t.type, t.square)))}.`,
        arrows: targets.map((t) => ({ from: hit.m.by.square, to: t.square, tone: 'info' as const })),
        at: hit.at,
      };
    }
    case 'pin': {
      const hit = first('pin');
      if (hit) {
        const { f, m } = hit;
        return {
          text: `Con ${san(f)}, ${theOn(m.pinner.type, m.pinner.square)} clava ${toTheOn(m.pinned.type, m.pinned.square)}: si se aparta, deja a tiro ${toTheOn(m.behind.type, m.behind.square)}.`,
          arrows: [{ from: m.pinner.square, to: m.behind.square, tone: 'info' }],
          at: hit.at,
        };
      }
      // La clavada puede existir ya antes de mover. Solo se señala si es la única, para no confundir.
      const pins = existingPins(startFen, pov);
      if (pins.length === 1) {
        const m = pins[0];
        return {
          text: `${cap(theOn(m.pinned.type, m.pinned.square))} está ${adj(m.pinned.type, 'clavado', 'clavada')} por ${theOn(m.pinner.type, m.pinner.square)}: no puede apartarse sin dejar a tiro ${toTheOn(m.behind.type, m.behind.square)}.`,
          arrows: [{ from: m.pinner.square, to: m.behind.square, tone: 'info' }],
          at: 0,
        };
      }
      return null;
    }
    case 'skewer': {
      const hit = first('skewer');
      if (!hit) return null;
      const { f, m } = hit;
      return {
        text: `Con ${san(f)}, ${theOn(m.attacker.type, m.attacker.square)} ataca ${toTheOn(m.front.type, m.front.square)}; cuando se aparte, quedará a tiro ${theOn(m.behind.type, m.behind.square)}.`,
        arrows: [{ from: m.attacker.square, to: m.behind.square, tone: 'info' }],
        at: hit.at,
      };
    }
    case 'discoveredAttack':
    case 'discoveredCheck': {
      const hit = first('discovered');
      if (!hit) return null;
      const { f, m } = hit;
      return {
        text: `Al jugar ${san(f)} se abre la línea ${ofTheOn(m.slider.type, m.slider.square)}, que pasa a atacar ${toTheOn(m.target.type, m.target.square)}.`,
        arrows: [
          { from: m.slider.square, to: m.target.square, tone: 'info' },
          { from: f.move.from, to: f.move.to, tone: 'good' },
        ],
        at: hit.at,
      };
    }
    case 'doubleCheck': {
      const hit = first('check', (m) => m.double);
      if (!hit) return null;
      return { text: `${san(hit.f)} da jaque con dos piezas a la vez: el rey está obligado a moverse.`, arrows: [], at: hit.at };
    }
    case 'hangingPiece': {
      const hit = first('capture', (m) => m.undefended || m.see >= VALUE[m.captured.type]);
      if (!hit) return null;
      const { f, m } = hit;
      return {
        text: `${cap(theOn(m.captured.type, m.captured.square))} no tenía defensa suficiente: ${san(f)} ${pron(m.captured.type)} captura sin dar nada a cambio.`,
        arrows: [{ from: f.move.from, to: f.move.to, tone: 'good' }],
        at: hit.at,
      };
    }
    case 'promotion':
    case 'underPromotion':
    case 'advancedPawn': {
      const hit = first('promotion');
      if (!hit) return null;
      return {
        text: `El peón llega a ${hit.f.move.to} y se convierte en ${pieceName(hit.m.to)} con ${san(hit.f)}.`,
        arrows: [{ from: hit.f.move.from, to: hit.f.move.to, tone: 'good' }],
        at: hit.at,
      };
    }
    case 'sacrifice': {
      // Una jugada propia deja una pieza donde el rival la captura dentro de la propia solución.
      for (let i = 0; i < mine.length; i++) {
        const f = mine[i];
        const reply = replies[i];
        const piece = (f.move.promotion ?? f.move.piece) as PieceType;
        const taken = f.move.captured ? VALUE[f.move.captured as PieceType] : 0;
        if (reply && reply.slice(2, 4) === f.move.to && VALUE[piece] >= 3 && VALUE[piece] > taken) {
          return {
            text: `Con ${san(f)} entregas ${the(piece)}: el rival ${pron(piece)} captura, pero lo que consigues después vale más.`,
            arrows: [{ from: f.move.from, to: f.move.to, tone: 'good' }],
            at: i,
          };
        }
      }
      return null;
    }
    case 'backRankMate':
    case 'smotheredMate': {
      const pat = matePattern(chess);
      if (key === 'backRankMate' && pat === 'backRank')
        return { text: 'En la posición final, el rey no puede salir de la última fila: sus propias piezas le tapan el paso.', arrows: [], at: mine.length - 1 };
      if (key === 'smotheredMate' && pat === 'smothered')
        return { text: 'En la posición final, todas las casillas que rodean al rey están ocupadas por sus propias piezas.', arrows: [], at: mine.length - 1 };
      return null;
    }
    default:
      return null;
  }
}

interface Concept {
  key: string;
  instance: Instance | null;
}

function pickConcepts(p: AnalyzedPuzzle, startFen: string, line: Uci[], pov: Color): Concept[] {
  const out: Concept[] = conceptThemes(p.themes)
    .filter((k) => THEMES[k]?.def)
    .map((key) => ({ key, instance: findInstance(key, startFen, line, pov) }));
  // Primero los temas que se pueden señalar en el tablero; como mucho dos, para no abrumar.
  out.sort((x, y) => Number(!!y.instance) - Number(!!x.instance));
  return out.slice(0, 2);
}

// ---------- Veredicto ----------

/** ¿Acepta el problema esta jugada? La solución, o cualquier jugada que dé mate inmediato. */
export function isAccepted(p: AnalyzedPuzzle, pointIndex: number, played: Uci): boolean {
  const pt = p.points[pointIndex];
  if (played === pt.solution) return true;
  const chess = new Chess(pt.fen);
  return !!tryUci(chess, played) && chess.isCheckmate();
}

export function classify(best: Score, played: Score): Verdict {
  const sb = scoreValue(best);
  const sv = scoreValue(played);
  if ('mate' in played && played.mate > 0) return 'slower';
  if (sb < 150) {
    // Problemas de defensa: cuenta cuánto empeora la posición respecto a la mejor.
    if (sb - sv < 80) return 'alsoWins';
    return sv <= -150 ? 'loses' : 'missed';
  }
  if (sv >= 300) return sb - sv < 150 ? 'alsoWins' : 'slower';
  if (sv > -100) return 'missed';
  return 'loses';
}

// ---------- Explicación ----------

/** Medias jugadas tras la del usuario que se usan para medir lo que pierde. */
const REFUTATION_HORIZON = 4;

const emptyLevel = (level: 1 | 2 | 3 | 4, title: string): Level => ({ level, title, paragraphs: [], arrows: [], lines: [], table: [] });

export interface ExplainOptions {
  /** true cuando se explica el problema ya resuelto (resumen de toda la solución). */
  solved?: boolean;
}

/**
 * Explica la jugada `played` en el punto de decisión `pointIndex`.
 * Si es la solución, cuenta por qué funciona; si no, qué tenía de atractiva, qué permite y cuál era mejor.
 */
/** Lo que no depende de la jugada del usuario: se calcula una vez por punto de decisión y se reutiliza. */
interface PointContext {
  pov: Color;
  bestEval: MoveEval | undefined;
  solutionUcis: Uci[];
  solLine: Line;
  solOutcome: Outcome;
  bestSan: string;
  bestGets: string;
  bestFacts: Fact[];
  concepts: Concept[];
}

const CONTEXT = new WeakMap<AnalyzedPuzzle, Map<number, PointContext>>();

function pointContext(p: AnalyzedPuzzle, pointIndex: number): PointContext {
  let byPoint = CONTEXT.get(p);
  if (!byPoint) CONTEXT.set(p, (byPoint = new Map()));
  const cached = byPoint.get(pointIndex);
  if (cached) return cached;

  const pt = p.points[pointIndex];
  const pov = new Chess(pt.fen).turn();
  const bestEval = findEval(pt.top, pt.solution) ?? findEval(pt.evals, pt.solution);
  // Lo que queda de la línea publicada por Lichess desde este punto.
  const solutionUcis = p.moves.slice(1 + 2 * pointIndex);
  const solLine = buildLine(pt.fen, solutionUcis, 'La solución', 'good');
  const solOutcome = lineOutcome(pt.fen, solutionUcis, pov);
  const bestSan = sanOf(pt.fen, pt.solution);
  const bestFacts: Fact[] = [];

  // Qué consigue la solución, en tercera persona: "gana la dama", "da mate en 2".
  let bestGets: string;
  if (solOutcome.mates) {
    bestGets = solOutcome.povMoves === 1 ? 'es jaque mate' : `da mate en ${solOutcome.povMoves}`;
    bestFacts.push({ source: 'reglas', text: `La línea de la solución termina en jaque mate en ${solOutcome.povMoves}.` });
  } else {
    const gain = gainPhrase(solOutcome, 'move');
    // Una ganancia material solo se afirma si el motor también ve ventaja clara.
    const engineBacksGain = !bestEval || scoreValue(bestEval.score) >= 100;
    if (gain && engineBacksGain) {
      bestGets = gain;
      bestFacts.push({ source: 'reglas', text: `Balance material de la solución, resueltos los cambios: +${solOutcome.delta}.` });
    } else if (bestEval && 'mate' in bestEval.score && bestEval.score.mate > 0) {
      bestGets = `lleva a mate forzado en ${bestEval.score.mate}`;
    } else if (bestEval) {
      bestGets = advantageWords(scoreValue(bestEval.score));
    } else {
      bestGets = 'es la jugada del problema';
    }
  }
  if (bestEval) {
    const depth = findEval(pt.top, pt.solution) ? p.engine.depthTop : p.engine.depthAll;
    bestFacts.push({ source: 'motor', text: `${bestSan}: ${formatScore(bestEval.score)} (${p.engine.name}, profundidad ${depth}).` });
  }
  const ctx: PointContext = {
    pov,
    bestEval,
    solutionUcis,
    solLine,
    solOutcome,
    bestSan,
    bestGets,
    bestFacts,
    concepts: pickConcepts(p, pt.fen, solutionUcis, pov),
  };
  byPoint.set(pointIndex, ctx);
  return ctx;
}

export function explain(p: AnalyzedPuzzle, pointIndex: number, played: Uci, opts: ExplainOptions = {}): Explanation {
  const pt = p.points[pointIndex];
  const { pov, bestEval, solLine, solOutcome, bestSan, bestGets, bestFacts, concepts } = pointContext(p, pointIndex);
  const facts: Fact[] = [...bestFacts];
  const correct = isAccepted(p, pointIndex, played);

  const inTop = (uci: Uci) => !!findEval(pt.top, uci);
  const depthOf = (uci: Uci) => (inTop(uci) ? p.engine.depthTop : p.engine.depthAll);
  const playedEval = findEval(pt.top, played) ?? findEval(pt.evals, played);
  const playedFacts = describeMove(pt.fen, played);
  const playedSan = sanEs(playedFacts.move.san);

  const verdict: Verdict = correct ? 'best' : bestEval && playedEval ? classify(bestEval.score, playedEval.score) : 'missed';

  const l1 = emptyLevel(1, 'Qué ha pasado');
  const l2 = emptyLevel(2, 'El concepto');
  const l3 = emptyLevel(3, 'La variante');
  const l4 = emptyLevel(4, 'Análisis del motor');
  let headline: string;
  let errorKind: ErrorKind = '';

  if (correct) {
    headline = opts.solved || pointIndex === p.points.length - 1 ? '¡Resuelto!' : '¡Correcto!';
    l1.paragraphs.push(played === pt.solution ? `${bestSan} ${bestGets}.` : `${playedSan} es jaque mate. También valía ${bestSan}.`);
    l1.arrows.push({ from: played.slice(0, 2), to: played.slice(2, 4), tone: 'good' });
  } else {
    headline = verdict === 'alsoWins' ? 'Buena, pero hay otra más precisa' : verdict === 'slower' ? 'Gana, pero hay algo más fuerte' : 'No es la mejor';

    // 1) Qué tiene de atractiva la jugada del usuario (hechos de reglas).
    const tempt = temptations(playedFacts);
    if (tempt.length > 0) {
      l1.paragraphs.push(`Tu jugada, ${playedSan}, ${joinY(tempt)}.`);
      facts.push({ source: 'reglas', text: `${playedSan} ${joinY(tempt)}.` });
    } else {
      l1.paragraphs.push(`Tu jugada, ${playedSan}, no da jaque, no captura y no ataca ninguna pieza de más valor.`);
    }

    // 2) Qué permite (variante del motor tras la jugada del usuario).
    const refUcis = playedEval ? [played, ...playedEval.pv] : [played];
    // El saldo material se mide a corto plazo (la jugada y cuatro medias jugadas más):
    // la cola de una variante poco profunda es poco fiable y no debe convertirse en afirmación.
    const refOutcome = lineOutcome(pt.fen, refUcis.slice(0, 1 + REFUTATION_HORIZON), pov);
    const reply = playedEval?.pv[0];
    let replySan = '';
    let effect = '';
    let replyFacts: MoveFacts | null = null;
    if (reply) {
      const probe = new Chess(playedFacts.fenAfter);
      if (tryUci(probe, reply)) {
        const rf = describeMove(playedFacts.fenAfter, reply);
        replyFacts = rf;
        replySan = sanEs(rf.move.san);
        effect = replyEffect(rf);
      }
    }
    if (playedEval) facts.push({ source: 'motor', text: `${playedSan}: ${formatScore(playedEval.score)} (profundidad ${depthOf(played)}).` });
    const allows = replySan ? `permite ${replySan}${effect ? `, que ${effect}` : ''}` : '';

    if (pick(playedFacts, 'stalemate')) {
      errorKind = 'missed';
      l1.paragraphs.push('Pero deja al rey rival sin jugadas legales y sin jaque: es ahogado, tablas.');
    } else if (verdict === 'loses') {
      const mateAgainst = playedEval && 'mate' in playedEval.score && playedEval.score.mate < 0 ? -playedEval.score.mate : 0;
      if (effect === 'es jaque mate') {
        errorKind = 'mate';
        l1.paragraphs.push(`Pero permite ${replySan}, que es jaque mate.`);
      } else if (mateAgainst > 0) {
        errorKind = 'mate';
        l1.paragraphs.push(`Pero ${allows}. El motor ve mate en contra en ${mateAgainst}.`);
      } else {
        const loss = lossPhrase(refOutcome);
        const taken = replyFacts ? pick(replyFacts, 'capture') : undefined;
        errorKind = !loss ? 'worse' : !taken ? 'material' : taken.captured.square === played.slice(2, 4) ? 'hangMoved' : 'hangOther';
        const words = playedEval ? evalWords(playedEval.score) : 'quedas peor';
        if (effect) l1.paragraphs.push(`Pero ${allows}. ${loss ? `En pocas jugadas ${loss}.` : `Según el motor, ${words}.`}`);
        else if (replySan) l1.paragraphs.push(loss ? `Pero tras ${replySan}, en pocas jugadas ${loss}.` : `Pero tras ${replySan}, según el motor, ${words}.`);
        else l1.paragraphs.push(`Pero, según el motor, ${words}.`);
        if (loss) facts.push({ source: 'reglas', text: `Balance material tras ${playedSan}, resueltos los cambios: ${refOutcome.delta}.` });
      }
    } else if (verdict === 'missed') {
      errorKind = 'missed';
      const tail = playedEval ? evalWords(playedEval.score) : 'la ventaja desaparece';
      l1.paragraphs.push(`Pero deja pasar la ocasión: ${replySan ? `tras ${replySan}, ` : ''}${tail}.`);
    } else if (verdict === 'slower') {
      errorKind = 'slower';
      if (playedEval && 'mate' in playedEval.score) {
        l1.paragraphs.push(`También gana: el motor ve mate en ${playedEval.score.mate}. Pero hay un camino más corto.`);
      } else if (solOutcome.mates) {
        l1.paragraphs.push(`Conserva ventaja (${playedEval ? formatScore(playedEval.score) : ''}), pero deja escapar el mate.`);
      } else {
        l1.paragraphs.push(`Conserva ventaja (${playedEval ? formatScore(playedEval.score) : ''}), pero se queda lejos de lo que ofrece la posición.`);
      }
    } else {
      errorKind = 'slower';
      l1.paragraphs.push(`El motor también la valora bien (${playedEval ? formatScore(playedEval.score) : ''}). El problema pide la más precisa.`);
    }

    // 3) Cuál era mejor y qué consigue.
    l1.paragraphs.push(`La mejor era ${bestSan}, que ${bestGets}.`);
    l1.arrows.push({ from: played.slice(0, 2), to: played.slice(2, 4), tone: 'bad' });
    l1.arrows.push({ from: pt.solution.slice(0, 2), to: pt.solution.slice(2, 4), tone: 'good' });
    // La variante del motor se muestra recortada: las últimas jugadas de una línea poco profunda son las menos fiables.
    if (reply && replySan) l3.lines.push(buildLine(pt.fen, refUcis.slice(0, 9), 'Tu jugada', 'bad'));

    // Concepto del error: la jugada dejó una pieza a tiro y la refutación la captura.
    const hung = pick(playedFacts, 'enPrise');
    if (hung && reply && reply.slice(2, 4) === hung.piece.square) {
      l2.paragraphs.push(
        hung.isMover
          ? `El error: ${playedSan} deja ${theOn(hung.piece.type, hung.piece.square)} donde el rival ${pron(hung.piece.type)} captura con ventaja.`
          : `El error: tras ${playedSan}, ${yourOn(hung.piece.type, hung.piece.square)} queda sin defensa suficiente.`,
      );
      facts.push({ source: 'reglas', text: `Tras ${playedSan}, la pieza de ${hung.piece.square} puede capturarse con ganancia de ${hung.loss}.` });
    }
  }

  // --- Nivel 2: el concepto de la solución ---
  for (const c of concepts) {
    const info = THEMES[c.key];
    l2.paragraphs.push(`${info.name}. ${info.def}`);
    facts.push({ source: 'lichess', text: `Tema etiquetado en Lichess: ${c.key}.` });
    if (c.instance) {
      l2.paragraphs.push(`Aquí: ${c.instance.text}`);
      // Las flechas se dibujan sobre la posición actual: solo valen si el motivo aparece en la primera jugada.
      if (c.instance.at === 0) l2.arrows.push(...c.instance.arrows);
      facts.push({ source: 'reglas', text: c.instance.text });
    }
  }
  if (concepts.length === 0) {
    const goal = ['mateIn1', 'mateIn2', 'mateIn3', 'mateIn4', 'mateIn5', 'mate', 'equality', 'crushing', 'advantage'].find((t) => p.themes.includes(t));
    l2.paragraphs.push(
      goal
        ? `${themeName(goal)}. ${THEMES[goal].def} Este problema no tiene un motivo táctico con nombre: la clave está en calcular la variante.`
        : 'Este problema no tiene un motivo táctico con nombre: la clave está en calcular la variante.',
    );
  }

  if (l2.arrows.length > 0) l2.arrows.unshift({ from: pt.solution.slice(0, 2), to: pt.solution.slice(2, 4), tone: 'good' });

  // --- Nivel 3: variantes ---
  l3.lines.unshift({ ...solLine, plies: [...solLine.plies] });
  l3.paragraphs.push(`La solución: ${solLine.text}.`);
  const refLine = l3.lines.find((l) => l.tone === 'bad');
  if (refLine) l3.paragraphs.push(`Tras tu jugada: ${refLine.text}.`);

  // --- Nivel 4: cifras del motor ---
  const rows: CandidateRow[] = [];
  const addRow = (label: string, e: MoveEval | undefined) => {
    if (!e) return;
    const san = sanOf(pt.fen, e.uci);
    if (rows.some((r) => r.san === san)) return;
    rows.push({
      label,
      san,
      score: formatScore(e.score),
      depth: depthOf(e.uci),
      continuation: buildLine(pt.fen, [e.uci, ...e.pv.slice(0, 5)], '', 'good').text,
    });
  };
  addRow('Mejor', bestEval);
  if (played !== pt.solution) addRow('Tu jugada', playedEval);
  for (const e of pt.top) addRow('Alternativa', e);
  l4.table = rows;
  l4.paragraphs.push(
    `Cifras de ${p.engine.name}. Las tres mejores jugadas están analizadas a profundidad ${p.engine.depthTop}; el resto, a profundidad ${p.engine.depthAll}.`,
  );
  l4.paragraphs.push('Un número positivo favorece a quien mueve. «Mate en 3» significa mate forzado en tres jugadas.');
  if (!correct && bestEval && playedEval && 'cp' in bestEval.score && 'cp' in playedEval.score) {
    const d = (bestEval.score.cp - playedEval.score.cp) / 100;
    l4.paragraphs.push(`Diferencia entre la mejor y tu jugada: ${d.toFixed(2).replace('.', ',')}.`);
  }

  return {
    puzzleId: p.id,
    pointIndex,
    played,
    playedSan,
    bestUci: pt.solution,
    bestSan,
    correct,
    verdict,
    errorKind,
    headline,
    levels: [l1, l2, l3, l4],
    facts,
  };
}

/** Explicación del problema completo una vez resuelto: toda la solución desde la primera jugada. */
export function explainSolved(p: AnalyzedPuzzle): Explanation {
  return explain(p, 0, p.points[0].solution, { solved: true });
}

/** Condición de control del experimento: solo el resultado, sin explicación. */
export function plainFeedback(p: AnalyzedPuzzle, pointIndex: number, played: Uci): { correct: boolean; text: string } {
  const pt = p.points[pointIndex];
  const correct = isAccepted(p, pointIndex, played);
  if (correct) return { correct, text: 'Correcto.' };
  return { correct, text: `Incorrecto. La solución era ${sanOf(pt.fen, pt.solution)}.` };
}
