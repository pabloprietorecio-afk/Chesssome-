/**
 * Detectores de hechos tácticos. Describen QUÉ HACE una jugada usando solo las reglas del juego:
 * a quién ataca, qué captura, qué deja sin defensa. No opinan sobre si la jugada es buena;
 * eso lo decide el motor y se combina en explain.ts.
 */
import { Chess, type Move } from 'chess.js';
import {
  VALUE,
  applyUci,
  attackersOf,
  kingSquare,
  moveToUci,
  other,
  passTurn,
  piecesOf,
  ray,
  seeCapture,
  seeSquare,
  sliderDirs,
  type PieceOn,
} from './chessx';
import type { Color, PieceType, Square, Uci } from './types';

export type PieceRef = PieceOn;

export type Motif =
  | { kind: 'checkmate' }
  | { kind: 'stalemate' }
  | { kind: 'check'; double: boolean; discovered: boolean }
  | { kind: 'capture'; captured: PieceRef; see: number; undefended: boolean }
  | { kind: 'promotion'; to: PieceType }
  | { kind: 'fork'; by: PieceRef; targets: Target[]; safe: boolean }
  | { kind: 'attack'; by: PieceRef; target: Target; safe: boolean }
  | { kind: 'discovered'; slider: PieceRef; target: PieceRef }
  | { kind: 'pin'; pinner: PieceRef; pinned: PieceRef; behind: PieceRef; absolute: boolean }
  | { kind: 'skewer'; attacker: PieceRef; front: PieceRef; behind: PieceRef }
  | { kind: 'mateThreat'; move: Uci; san: string }
  | { kind: 'enPrise'; piece: PieceRef; loss: number; isMover: boolean };

export type Target = PieceRef & { why: 'king' | 'higher' | 'undefended' };

export interface MoveFacts {
  fenBefore: string;
  fenAfter: string;
  move: Move;
  uci: Uci;
  motifs: Motif[];
}

function isDefended(chess: Chess, p: PieceRef): boolean {
  return attackersOf(chess, p.square, p.color).length > 0;
}

/** Piezas enemigas que la pieza situada en `from` ataca y que merece la pena atacar. */
function worthyTargets(after: Chess, from: Square, mover: PieceRef): Target[] {
  const enemy = other(mover.color);
  const out: Target[] = [];
  for (const e of piecesOf(after, enemy)) {
    if (!attackersOf(after, e.square, mover.color).includes(from)) continue;
    if (e.type === 'k') out.push({ ...e, why: 'king' });
    else if (VALUE[e.type] > VALUE[mover.type]) out.push({ ...e, why: 'higher' });
    // Un peón suelto solo cuenta como objetivo para peones y piezas menores:
    // una dama o una torre "atacan" peones constantemente y señalarlo sería ruido.
    else if (!isDefended(after, e) && (e.type !== 'p' || VALUE[mover.type] <= 3)) out.push({ ...e, why: 'undefended' });
  }
  return out.sort((x, y) => VALUE[y.type] - VALUE[x.type]);
}

/** Clavadas y ataques a través ("rayos X") que ejerce una pieza de largo alcance desde su casilla. */
function lineMotifs(after: Chess, slider: PieceRef, dirs = sliderDirs(slider.type)): Motif[] {
  const out: Motif[] = [];
  const enemy = other(slider.color);
  for (const dir of dirs) {
    const [p1, p2] = ray(after, slider.square, dir);
    if (!p1 || !p2 || p1.color !== enemy || p2.color !== enemy) continue;
    if (p2.type === 'k' && p1.type !== 'k') {
      out.push({ kind: 'pin', pinner: slider, pinned: p1, behind: p2, absolute: true });
    } else if (p1.type === 'k') {
      // Jaque a través: el rey debe apartarse y cae la pieza de detrás.
      if (VALUE[p2.type] >= 3) out.push({ kind: 'skewer', attacker: slider, front: p1, behind: p2 });
    } else if (VALUE[p1.type] > VALUE[p2.type] && VALUE[p1.type] > VALUE[slider.type]) {
      if (!isDefended(after, p2) || VALUE[p2.type] > VALUE[slider.type]) {
        out.push({ kind: 'skewer', attacker: slider, front: p1, behind: p2 });
      }
    } else if (VALUE[p2.type] > VALUE[p1.type]) {
      if (VALUE[p2.type] > VALUE[slider.type] || !isDefended(after, p2)) {
        out.push({ kind: 'pin', pinner: slider, pinned: p1, behind: p2, absolute: false });
      }
    }
  }
  return out;
}

/** Clavadas que `color` ya ejerce en la posición, antes de mover. */
export function existingPins(fen: string, color: Color): Extract<Motif, { kind: 'pin' }>[] {
  const chess = new Chess(fen);
  const out: Extract<Motif, { kind: 'pin' }>[] = [];
  for (const s of piecesOf(chess, color)) {
    if (!['b', 'r', 'q'].includes(s.type)) continue;
    for (const m of lineMotifs(chess, s)) if (m.kind === 'pin') out.push(m);
  }
  return out;
}

/** ¿Tiene `color` algún mate en una jugada en esta posición (siendo su turno)? */
export function mateInOne(chess: Chess): Move | null {
  // chess.js marca con "#" las jugadas que dan mate al generar la notación.
  return chess.moves({ verbose: true }).find((m) => m.san.endsWith('#')) ?? null;
}

/** Describe una jugada: todo lo que se puede afirmar de ella mirando solo el tablero. */
export function describeMove(fenBefore: string, uci: Uci): MoveFacts {
  const before = new Chess(fenBefore);
  const after = new Chess(fenBefore);
  const move = applyUci(after, uci);
  const me: Color = move.color;
  const enemy = other(me);
  const motifs: Motif[] = [];
  const moved: PieceRef = { type: (move.promotion ?? move.piece) as PieceType, color: me, square: move.to };

  if (after.isCheckmate()) motifs.push({ kind: 'checkmate' });
  else if (after.isStalemate()) motifs.push({ kind: 'stalemate' });

  // Jaque: doble si dan jaque dos piezas; a la descubierta si no lo da la pieza que se ha movido.
  const ek = kingSquare(after, enemy);
  if (!after.isCheckmate() && after.isCheck() && ek) {
    const checkers = attackersOf(after, ek, me);
    motifs.push({ kind: 'check', double: checkers.length >= 2, discovered: !checkers.includes(move.to) });
  }

  if (move.captured) {
    const capSq: Square = move.isEnPassant() ? move.to[0] + move.from[1] : move.to;
    const captured: PieceRef = { type: move.captured as PieceType, color: enemy, square: capSq };
    motifs.push({
      kind: 'capture',
      captured,
      see: seeCapture(move),
      undefended: attackersOf(before, capSq, enemy).length === 0,
    });
  }
  if (move.promotion) motifs.push({ kind: 'promotion', to: move.promotion as PieceType });

  if (!after.isGameOver()) {
    // ¿La pieza movida puede ser capturada con ganancia? (turno del rival en `after`)
    // Si la jugada era una captura, se descuenta lo capturado: un cambio igualado no es dejarse una pieza.
    const moverLoss = seeSquare(after, move.to) - (move.captured ? VALUE[move.captured as PieceType] : 0);
    const safe = moverLoss <= 0;

    // Ataque doble / ataque simple de la pieza movida.
    if (!move.isKingsideCastle() && !move.isQueensideCastle()) {
      const targets = worthyTargets(after, move.to, moved);
      if (targets.length >= 2) motifs.push({ kind: 'fork', by: moved, targets, safe });
      else if (targets.length === 1 && targets[0].type !== 'k') {
        motifs.push({ kind: 'attack', by: moved, target: targets[0], safe });
      }
    }

    // Ataque a la descubierta: una pieza propia de largo alcance tenía delante a la pieza que se ha movido.
    for (const s of piecesOf(after, me)) {
      if (s.square === move.to || !['b', 'r', 'q'].includes(s.type)) continue;
      for (const dir of sliderDirs(s.type)) {
        const firstBefore = ray(before, s.square, dir)[0];
        if (!firstBefore || firstBefore.square !== move.from) continue;
        const firstAfter = ray(after, s.square, dir)[0];
        if (!firstAfter || firstAfter.color !== enemy) continue;
        const worth =
          firstAfter.type === 'k' || VALUE[firstAfter.type] > VALUE[s.type] || !isDefended(after, firstAfter);
        if (worth) motifs.push({ kind: 'discovered', slider: s, target: firstAfter });
        // Solo en la línea que se acaba de abrir: las demás ya existían antes de la jugada.
        motifs.push(...lineMotifs(after, s, [dir]));
      }
    }

    // Clavadas y ataques a través creados por la pieza movida.
    if (['b', 'r', 'q'].includes(moved.type)) motifs.push(...lineMotifs(after, moved));

    // Amenaza de mate en una: si el rival "pasara", ¿habría mate?
    const passed = passTurn(after);
    if (passed) {
      const mate = mateInOne(passed);
      if (mate) motifs.push({ kind: 'mateThreat', move: moveToUci(mate), san: mate.san });
    }

    // Piezas propias que quedan a tiro: el rival gana material capturándolas.
    let worst: { piece: PieceRef; loss: number } | null = null;
    for (const p of piecesOf(after, me)) {
      if (p.type === 'k') continue;
      const loss = p.square === move.to ? moverLoss : seeSquare(after, p.square);
      if (loss > 0 && (!worst || loss > worst.loss)) worst = { piece: p, loss };
    }
    if (worst) motifs.push({ kind: 'enPrise', piece: worst.piece, loss: worst.loss, isMover: worst.piece.square === move.to });
  }

  return { fenBefore, fenAfter: after.fen(), move, uci, motifs };
}

/** Patrón de mate de la posición final, deducido del tablero. */
export function matePattern(chess: Chess): 'backRank' | 'smothered' | null {
  if (!chess.isCheckmate()) return null;
  const loser = chess.turn();
  const winner = other(loser);
  const k = kingSquare(chess, loser);
  if (!k) return null;
  const checkers = attackersOf(chess, k, winner).map((sq) => ({ sq, p: chess.get(sq as never)! }));
  if (checkers.length !== 1) return null;
  const { sq, p } = checkers[0];
  const homeRank = loser === 'w' ? '1' : '8';
  if (p.type === 'n') {
    // Mate de la coz: el rey está rodeado por sus propias piezas.
    const around = piecesOf(chess, loser).filter(
      (q) => q.type !== 'k' && Math.abs(q.square.charCodeAt(0) - k.charCodeAt(0)) <= 1 && Math.abs(Number(q.square[1]) - Number(k[1])) <= 1,
    );
    const free = [-1, 0, 1].flatMap((df) =>
      [-1, 0, 1]
        .filter((dr) => df !== 0 || dr !== 0)
        .map((dr) => [k.charCodeAt(0) - 97 + df, Number(k[1]) - 1 + dr])
        .filter(([f, r]) => f >= 0 && f < 8 && r >= 0 && r < 8),
    ).length;
    if (around.length === free) return 'smothered';
  }
  if ((p.type === 'r' || p.type === 'q') && k[1] === homeRank && sq[1] === homeRank) {
    // Mate del pasillo: el rey no puede subir porque sus propios peones o piezas le tapan la salida.
    const fwd = loser === 'w' ? 2 : 7;
    const blockers = [-1, 0, 1]
      .map((df) => String.fromCharCode(k.charCodeAt(0) + df) + fwd)
      .filter((s) => /^[a-h][1-8]$/.test(s))
      .map((s) => chess.get(s as never));
    if (blockers.length > 0 && blockers.every((b) => b && b.color === loser)) return 'backRank';
  }
  return null;
}
