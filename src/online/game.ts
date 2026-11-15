/** Estado de una partida online a partir de los datos de Firebase (partidas/<id>) y de las reglas del ajedrez. */
import { Chess } from 'chess.js';
import { colorOf } from './ids';

export interface GameDoc {
  creador?: string;
  rival?: string;
  unidoEn?: number;
  jugadas?: unknown;
  perfiles?: Record<string, unknown>;
  gestos?: Record<string, unknown>;
}

/** Lo que cada jugador enseña de sí mismo al rival: su nivel (−1 sin nivel), su icono y, si quiere, su foto. */
export interface Profile {
  nivel: number;
  icono?: string;
  /** JPEG pequeño en base64. Solo si el jugador ha elegido enseñarla. */
  foto?: string;
}

/** Gestos del chat: solo estos, sin texto libre. */
export const GESTURES = ['saludo', 'aplauso', 'genial', 'arriba', 'abajo', 'buena'] as const;
export type Gesture = (typeof GESTURES)[number];
export const GESTURE_TEXT: Record<Gesture, { emoji: string; text: string }> = {
  saludo: { emoji: '👋', text: '¡Hola!' },
  aplauso: { emoji: '👏', text: '¡Bravo!' },
  genial: { emoji: '⭐', text: '¡Genial!' },
  arriba: { emoji: '👍', text: 'Bien' },
  abajo: { emoji: '👎', text: 'Vaya' },
  buena: { emoji: '🤝', text: 'Buena partida' },
};

export interface GestureEvent {
  key: string;
  mine: boolean;
  g: Gesture;
}

export function profileOf(doc: GameDoc | null, uid: string): Profile | null {
  const p = doc?.perfiles?.[uid] as { nivel?: unknown; icono?: unknown; foto?: unknown } | undefined;
  if (!p || typeof p.nivel !== 'number') return null;
  return { nivel: p.nivel, icono: typeof p.icono === 'string' ? p.icono : undefined, foto: typeof p.foto === 'string' ? p.foto : undefined };
}

/** Gestos en orden de llegada (las claves de Firebase ordenan por tiempo). */
export function gesturesOf(doc: GameDoc | null, uid: string): GestureEvent[] {
  const g = doc?.gestos;
  if (!g || typeof g !== 'object') return [];
  return Object.keys(g)
    .sort()
    .flatMap((key) => {
      const v = g[key] as { de?: unknown; g?: unknown } | null;
      if (!v || typeof v.g !== 'string' || !(GESTURES as readonly string[]).includes(v.g)) return [];
      return [{ key, mine: v.de === uid, g: v.g as Gesture }];
    });
}

/** Jugadas en orden, sin huecos (Firebase puede devolver la lista como objeto o como array). */
export function movesOf(doc: GameDoc | null): string[] {
  const j = doc?.jugadas;
  if (!j || typeof j !== 'object') return [];
  const get = (n: number): unknown => (Array.isArray(j) ? j[n] : (j as Record<string, unknown>)[String(n)]);
  const out: string[] = [];
  for (let n = 0; typeof get(n) === 'string'; n++) out.push(get(n) as string);
  return out;
}

/** 'w' o 'b' si el jugador participa y la partida ya empezó; null si no. */
export function colorFor(doc: GameDoc | null, uid: string): 'w' | 'b' | null {
  if (!doc || typeof doc.unidoEn !== 'number' || !doc.rival || !doc.creador) return null;
  if (doc.creador === uid) return colorOf(doc.unidoEn, 'creador');
  if (doc.rival === uid) return colorOf(doc.unidoEn, 'rival');
  return null;
}

export interface Replay {
  fen: string;
  turn: 'w' | 'b';
  /** Jugadas válidas (UCI) hasta la primera que no lo sea. */
  moves: string[];
  /** Hubo una jugada ilegal: se ignora desde ahí. */
  illegalAt: number | null;
  lastMove: { from: string; to: string } | null;
  over: null | { kind: 'checkmate' | 'draw'; winner: 'w' | 'b' | null; why: string };
}

export function parseUci(uci: string): { from: string; to: string; promotion?: string } | null {
  const m = /^([a-h][1-8])([a-h][1-8])([qrbn])?$/.exec(uci);
  return m ? { from: m[1], to: m[2], promotion: m[3] } : null;
}

export function replay(moves: string[]): Replay {
  const chess = new Chess();
  const ok: string[] = [];
  let illegalAt: number | null = null;
  let lastMove: Replay['lastMove'] = null;
  for (let i = 0; i < moves.length; i++) {
    const p = parseUci(moves[i]);
    let done = false;
    if (p) {
      try {
        chess.move(p);
        done = true;
      } catch {
        done = false;
      }
    }
    if (!done) {
      illegalAt = i;
      break;
    }
    ok.push(moves[i]);
    lastMove = { from: p!.from, to: p!.to };
  }
  let over: Replay['over'] = null;
  if (chess.isCheckmate()) over = { kind: 'checkmate', winner: chess.turn() === 'w' ? 'b' : 'w', why: 'Jaque mate' };
  else if (chess.isStalemate()) over = { kind: 'draw', winner: null, why: 'Tablas por rey ahogado' };
  else if (chess.isInsufficientMaterial()) over = { kind: 'draw', winner: null, why: 'Tablas por material insuficiente' };
  else if (chess.isThreefoldRepetition()) over = { kind: 'draw', winner: null, why: 'Tablas por triple repetición' };
  else if (chess.isDraw()) over = { kind: 'draw', winner: null, why: 'Tablas (regla de los 50 movimientos)' };
  return { fen: chess.fen(), turn: chess.turn(), moves: ok, illegalAt, lastMove, over };
}
