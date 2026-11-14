/**
 * «Cine de finales» con vídeo real.
 *
 * Un clip es un vídeo de una partida real (hoy, incrustado desde YouTube con su reproductor oficial)
 * más unas «paradas»: el segundo exacto en que el vídeo se pausa solo, justo antes de la jugada,
 * y las preguntas «¿Qué jugarías?» que se hacen en nuestro tablero mientras el vídeo espera.
 *
 * Este módulo no toca el DOM ni el reproductor. Tiene dos partes:
 *  1. El modelo de datos y las respuestas a las preguntas (con el veredicto del motor ya calculado
 *     por pipeline/build-video-cine.ts, de modo que la app no lleva motor ni inventa nada).
 *  2. El «director»: una máquina de estados pura que, a partir del tiempo del vídeo, decide cuándo
 *     pausar, cuándo se ha saltado una parada y cuándo acaba el clip.
 *
 * Reglas de YouTube que condicionan el diseño (Developer Policies y Required Minimum Functionality):
 *  - Solo se usan funciones documentadas de su API (pausar, reproducir, saltar, leer el tiempo).
 *  - Nada se dibuja encima del reproductor: la pregunta va debajo.
 *  - No se puede obligar a hacer nada para seguir viendo: si el jugador pulsa ▶, el director no
 *    vuelve a pausar. Responder es siempre opcional.
 */
import { Chess } from 'chess.js';
import type { Color } from './types';
import { DRAW_SPOILS_CP, lineText, type FilmResult, type MoveVerdict, type VerdictClass } from './cinema';
import type { ClockData } from './clockSync';
import { sanEs } from './lang';

// ───────────────────────── Modelo de datos ─────────────────────────

export interface VideoRef {
  provider: 'youtube';
  /** Identificador de 11 caracteres. */
  id: string;
  /** Título tal como aparece en YouTube (para el crédito). */
  title: string;
  channel: string;
  channelUrl: string;
  /** Fecha de publicación, AAAA-MM-DD. Se omite si no se ha podido comprobar. */
  published?: string;
  /** El canal es del titular de los derechos (organizador, federación o productora del vídeo). */
  official: boolean;
  /** Última vez que se comprobó que se puede incrustar (respuesta de oEmbed), AAAA-MM-DD. */
  checked: string;
  /** Duración en segundos. Sirve para detectar anuncios o un vídeo reeditado. null = sin medir. */
  duration: number | null;
  /** false = vídeo montado con cortes: el tiempo del vídeo no sigue al de la partida y los relojes no sirven para estimar. */
  continuous?: boolean;
}

export interface ClipQuestionSource {
  /** Media jugada (1 = primera de las blancas) que se pregunta: la posición es la de antes de jugarla. */
  ply: number;
  question: string;
  hint?: string;
  /**
   * Por qué la jugada de la partida es buena o, si fue un error, cuál era la buena y qué pasó en la partida.
   * Texto propio, revisado contra el análisis.
   */
  why: string;
}

export interface ClipStopSource {
  /** Segundo del vídeo en que se pausa. null = todavía sin marcar. */
  at: number | null;
  /** Segundo desde el que se reanuda; por defecto, el de la pausa. */
  resumeAt?: number | null;
  /** Preguntas encadenadas que se hacen en el tablero durante esta pausa. */
  questions: ClipQuestionSource[];
}

/** Paso de una lección: la posición sale de jugar `moves` (SAN en inglés, separadas por espacios) desde la de partida. */
export interface LessonStep {
  /** Jugadas desde la posición de partida de la lección hasta este paso, acumuladas. Vacío = la posición de partida. */
  moves: string;
  /** Texto propio, comprobado contra el motor. */
  text: string;
  arrows?: { from: string; to: string; tone: 'good' | 'bad' | 'info' }[];
}

/** Lección sobre la jugada clave del clip: se abre al acabar, paso a paso en el tablero. */
export interface ClipLesson {
  title: string;
  /** La lección empieza en la posición tras esta media jugada de la partida. */
  from: number;
  steps: LessonStep[];
}

/** Clip tal como lo escribimos (fuente). */
export interface ClipSource {
  id: string;
  title: string;
  subtitle: string;
  event: string;
  year: number;
  white: string;
  black: string;
  video: VideoRef;
  /** Segundo en que empieza y acaba el clip dentro del vídeo. null = sin marcar. */
  start: number | null;
  end: number | null;
  /** 'verified' solo si una persona ha visto el vídeo y ha comprobado cada marca. */
  marks: 'pending' | 'verified';
  /** Partida completa en SAN inglesa desde la posición inicial. */
  moves: string;
  /** De dónde salen las jugadas. */
  gameSource: string;
  orientation: Color;
  stops: ClipStopSource[];
  /** Texto propio que sitúa la escena antes del vídeo. */
  intro: string;
  /** Texto propio para el final. */
  outro: string;
  /** Avisos para quien selecciona vídeos (título que destripa, comentaristas…). */
  notes?: string;
  /** Relojes de la partida (retransmisión oficial), para estimar el segundo de cada jugada. */
  clocks?: ClockData;
  /** Tablero sincronizado con el vídeo: posición al empezar y segundo en que aparece cada jugada. */
  sync?: ClipSync;
  /** Lección sobre la jugada clave, para después del clip. */
  lesson?: ClipLesson;
}

/** Segundo del vídeo en que el tablero 2D debe mostrar hecha la media jugada `ply`. */
export interface SyncMark {
  ply: number;
  at: number;
}

/**
 * Tablero sincronizado. `startPly` es la posición que muestra el vídeo al empezar el clip (tras esa media jugada).
 * Hay que dar el segundo de cada media jugada siguiente hasta la última marcada, sin huecos. Las jugadas que el
 * vídeo no enseña (cortes, cámara) se marcan donde tenga sentido, pero nunca antes de la pausa de su pregunta.
 */
export interface ClipSync {
  startPly: number;
  marks: SyncMark[];
  /**
   * Tramos del vídeo en que no se puede saber qué jugada se está viendo (cortes de cámara, manos que tapan las
   * piezas). Durante un tramo, el tablero no finge seguir al vídeo: se atenúa y dice qué jugadas se están
   * haciendo. Las jugadas del tramo se marcan todas al final del tramo.
   */
  gaps?: SyncGap[];
}

/** Tramo [from, to) en segundos del vídeo en que el tablero no puede seguir las jugadas. */
export interface SyncGap {
  from: number;
  to: number;
}

/** Tramo sin seguimiento en el que cae el segundo `t`, si lo hay. */
export const syncGapAt = (sync: ClipSync, t: number): SyncGap | null => sync.gaps?.find((g) => t >= g.from && t < g.to) ?? null;

/** Medias jugadas que se hacen durante un tramo sin seguimiento: de la siguiente a la que había al empezar, a la marcada al acabar. */
export const gapPlies = (sync: ClipSync, g: SyncGap): { first: number; last: number } => ({ first: plyAt(sync, g.from) + 1, last: plyAt(sync, g.to) });

/** Jugada de la partida que el tablero reproduce entre preguntas. */
export interface GameMove {
  san: string;
  from: string;
  to: string;
  fenAfter: string;
  /** «55.» o «55…» */
  number: string;
  captured: boolean;
}

export interface ClipQuestion extends ClipQuestionSource {
  fen: string;
  mover: Color;
  /** Jugada que llevó a esta posición (para resaltarla en el tablero). */
  lead: GameMove | null;
  /** Jugadas de la partida desde la respuesta anterior hasta esta posición. */
  bridge: GameMove[];
  /** Jugada de la partida. */
  played: GameMove;
  playedUci: string;
  playedCls: VerdictClass;
  /** Mejor resultado alcanzable en la posición según el motor. */
  target: FilmResult;
  verdicts: MoveVerdict[];
  /** 'mate' si el motor encontró mate forzado tras la jugada de la partida. */
  proof: 'mate' | 'engine';
}

export interface ClipStop {
  at: number | null;
  resumeAt?: number | null;
  questions: ClipQuestion[];
}

export interface Clip extends Omit<ClipSource, 'stops' | 'moves'> {
  stops: ClipStop[];
  /** Jugadas que quedan tras la última pregunta hasta el final de la partida. */
  tail: GameMove[];
  /** Media jugadas totales de la partida. */
  plies: number;
  /** Nombre de cada media jugada con reloj («55…Txf2»), para el editor de marcas. */
  clockLabels?: { ply: number; label: string }[];
  /** Jugadas de la partida desde `fromPly` hasta el final (para el tablero sincronizado y el editor). */
  timeline: { fromPly: number; moves: GameMove[] };
}

export interface VideoCinePack {
  version: 1;
  engine: { name: string; depth: number };
  builtAt: string;
  clips: Clip[];
}

/** Marcas de tiempo de un clip; es lo que produce el editor de marcas. */
export interface ClipMarks {
  start: number | null;
  end: number | null;
  stops: (number | null)[];
  duration: number | null;
  /** Tablero sincronizado; null o ausente = sin sincronizar. */
  sync?: ClipSync | null;
}

export const marksOf = (clip: Clip): ClipMarks => ({
  start: clip.start,
  end: clip.end,
  stops: clip.stops.map((s) => s.at),
  duration: clip.video.duration,
  ...(clip.sync ? { sync: clip.sync } : {}),
});

/** Huella de unas marcas: sirve para saber si las de un dispositivo se hicieron sobre las marcas actuales del clip. */
export const marksKey = (m: ClipMarks): string => JSON.stringify([m.start, m.end, m.stops, m.duration, m.sync ?? null]);

/** Aplica unas marcas (p. ej. las hechas en este dispositivo con el editor) sobre un clip. */
export function withMarks(clip: Clip, m: ClipMarks): Clip {
  return {
    ...clip,
    start: m.start,
    end: m.end,
    video: { ...clip.video, duration: m.duration ?? clip.video.duration },
    stops: clip.stops.map((s, i) => ({ ...s, at: m.stops[i] ?? null, resumeAt: null })),
    sync: m.sync === undefined ? clip.sync : m.sync ?? undefined,
  };
}

/** ¿Tiene el clip todo lo necesario para pausar solo? */
export function canAutoPause(clip: { start: number | null; stops: { at: number | null }[] }): boolean {
  return clip.start != null && clip.stops.length > 0 && clip.stops.every((s) => s.at != null);
}

/** Errores de coherencia de unas marcas; lista vacía si están bien. */
export function marksProblems(m: ClipMarks): string[] {
  const out: string[] = [];
  if (m.start == null) out.push('Falta el inicio.');
  if (m.stops.some((s) => s == null)) out.push('Falta alguna pausa.');
  const seq = [m.start, ...m.stops, m.end].filter((x): x is number => x != null);
  for (let i = 1; i < seq.length; i++) if (seq[i] <= seq[i - 1]) out.push('Las marcas tienen que ir en orden: inicio, pausas y fin.');
  if (m.duration != null && seq.some((x) => x > m.duration!)) out.push('Hay marcas más allá del final del vídeo.');
  if (seq.some((x) => x < 0)) out.push('Hay marcas negativas.');
  return [...new Set(out)];
}

// ───────────────────────── Tablero sincronizado ─────────────────────────

export const START_FEN = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/** Jugada de la partida en la media jugada `ply`, si está en el trozo empaquetado. */
export function moveAt(clip: Pick<Clip, 'timeline'>, ply: number): GameMove | null {
  const i = ply - clip.timeline.fromPly;
  return i >= 0 && i < clip.timeline.moves.length ? clip.timeline.moves[i] : null;
}

/** Posición tras la media jugada `ply` (0 = posición inicial). */
export function fenAfter(clip: Pick<Clip, 'timeline'>, ply: number): string | null {
  if (ply === 0) return START_FEN;
  return moveAt(clip, ply)?.fenAfter ?? null;
}

/** Posición por defecto al empezar el clip: la de la primera pregunta. */
export const defaultStartPly = (clip: { stops: { questions: { ply: number }[] }[] }): number => (clip.stops[0]?.questions[0]?.ply ?? 1) - 1;

/** Media jugada que el tablero sincronizado debe mostrar en el segundo `t`. */
export function plyAt(sync: ClipSync, t: number): number {
  let ply = sync.startPly;
  for (const m of sync.marks) {
    if (m.at <= t) ply = m.ply;
    else break;
  }
  return ply;
}

/**
 * Última media jugada que el tablero sincronizado puede enseñar sin destripar la próxima pregunta.
 * Es una red de seguridad además de syncProblems: aunque una marca caiga mal, la jugada de la pregunta
 * no aparece en el tablero hasta que se ha preguntado.
 */
export function syncCap(clip: { stops: { questions: { ply: number }[] }[] }, st: { phase: Phase; stop: number; mode: DirectorState['mode'] }): number {
  if (st.mode === 'free') return Infinity;
  const next = st.phase === 'watching' ? clip.stops[st.stop] : st.phase === 'reveal' ? clip.stops[st.stop + 1] : undefined;
  const q = next?.questions[0]?.ply;
  return q == null ? Infinity : q - 1;
}

/**
 * Marca que la media jugada `p` aparece en el segundo `t`. Las anteriores sin marcar se ponen en el mismo segundo
 * (jugadas que el vídeo no enseña) y el orden se mantiene: ninguna anterior queda después ni ninguna posterior antes.
 */
export function syncSetAt(sy: ClipSync, p: number, t: number): ClipSync {
  const lastMarked = sy.marks.length ? sy.marks[sy.marks.length - 1].ply : sy.startPly;
  const out: SyncMark[] = [];
  for (let q = sy.startPly + 1; q <= Math.max(p, lastMarked); q++) {
    const old = sy.marks.find((m) => m.ply === q)?.at;
    let at = q === p ? t : (old ?? (q < p ? t : null));
    if (at == null) break;
    if (q < p && at > t) at = t;
    if (q > p && at < t) at = t;
    out.push({ ply: q, at: Math.round(at * 100) / 100 });
  }
  return { ...sy, marks: out };
}

/** Quita la marca de la media jugada `p` y las siguientes. */
export const syncRemoveFrom = (sy: ClipSync, p: number): ClipSync => ({ ...sy, marks: sy.marks.filter((m) => m.ply < p) });

/** Un paso del marcado rápido: lo que hay que marcar con un toque mientras se ve el vídeo. */
export type QuickStep = { kind: 'start' } | { kind: 'ply'; ply: number } | { kind: 'pause'; stop: number } | { kind: 'end' };

/**
 * Pasos del marcado rápido, en el orden en que ocurren en el vídeo: inicio, cada jugada desde la posición inicial
 * del tablero, la pausa justo antes de la primera jugada de cada parada, y el fin.
 */
export function quickSteps(clip: { stops: { questions: { ply: number }[] }[]; plies: number }, startPly: number): QuickStep[] {
  const out: QuickStep[] = [{ kind: 'start' }];
  const pauseBefore = new Map(clip.stops.map((st, i) => [st.questions[0].ply, i] as const));
  for (let p = startPly + 1; p <= clip.plies; p++) {
    const i = pauseBefore.get(p);
    if (i != null) out.push({ kind: 'pause', stop: i });
    out.push({ kind: 'ply', ply: p });
  }
  out.push({ kind: 'end' });
  return out;
}

/** Problemas de un tablero sincronizado; lista vacía si está bien. */
export function syncProblems(
  clip: Pick<Clip, 'timeline' | 'plies'> & { stops: { questions: { ply: number }[] }[] },
  sync: ClipSync,
  marks: { start: number | null; end: number | null; stops: (number | null | { at: number | null })[] },
): string[] {
  const out: string[] = [];
  if (fenAfter(clip, sync.startPly) == null) out.push('La posición inicial del tablero sincronizado queda fuera de las jugadas disponibles.');
  sync.marks.forEach((m, i) => {
    if (m.ply !== sync.startPly + 1 + i) out.push('Faltan jugadas por marcar en el tablero sincronizado: tienen que ir seguidas, sin huecos.');
    if (i > 0 && m.at < sync.marks[i - 1].at) out.push('Las jugadas del tablero sincronizado tienen que ir en orden de tiempo.');
    if (m.ply > clip.plies) out.push('Hay jugadas marcadas más allá del final de la partida.');
    if (marks.start != null && m.at < marks.start) out.push('Hay jugadas marcadas antes del inicio del clip.');
    if (marks.end != null && m.at > marks.end) out.push('Hay jugadas marcadas después del fin del clip.');
  });
  (sync.gaps ?? []).forEach((g, i, all) => {
    if (!(g.from < g.to)) out.push('Un tramo sin seguimiento del tablero tiene que empezar antes de acabar.');
    if (i > 0 && g.from < all[i - 1].to) out.push('Los tramos sin seguimiento del tablero tienen que ir en orden y sin solaparse.');
    if ((marks.start != null && g.from < marks.start) || (marks.end != null && g.to > marks.end)) out.push('Hay un tramo sin seguimiento del tablero fuera del clip.');
    if (gapPlies(sync, g).last < gapPlies(sync, g).first) out.push('Un tramo sin seguimiento del tablero no tiene jugadas: sobra.');
  });
  // Sin destripar: ninguna jugada de una pregunta (ni posterior) puede aparecer en el tablero antes de su pausa.
  clip.stops.forEach((st, i) => {
    const q = st.questions[0]?.ply;
    const raw = marks.stops[i];
    const at = raw != null && typeof raw === 'object' ? raw.at : raw;
    if (q == null || at == null) return;
    if (sync.startPly >= q) out.push(`El tablero empieza después de la pregunta ${i + 1}: la destriparía.`);
    for (const m of sync.marks) if (m.ply >= q && m.at < at) out.push(`El tablero mostraría la jugada de la pregunta ${i + 1} antes de la pausa.`);
  });
  return [...new Set(out)];
}

/** Extrae el identificador de un vídeo de YouTube de una URL o de un texto con el propio identificador. */
export function youtubeId(input: string): string | null {
  const s = input.trim();
  if (/^[\w-]{11}$/.test(s)) return s;
  const m = /(?:youtu\.be\/|[?&]v=|\/embed\/|\/shorts\/|\/live\/)([\w-]{11})(?:[?&#/]|$)/.exec(s);
  return m ? m[1] : null;
}

/** Enlace a YouTube en el segundo indicado (para «Ver en YouTube» y para cuando el vídeo no carga). */
export const watchUrl = (v: VideoRef, at?: number | null): string => `https://www.youtube.com/watch?v=${v.id}${at && at >= 1 ? `&t=${Math.floor(at)}s` : ''}`;

/** Convierte la lista de jugadas en SAN en jugadas con posiciones. Lanza un error si alguna es ilegal. */
export function replay(moves: string, id = 'clip'): GameMove[] {
  const sans = moves
    .replace(/\{[^}]*\}/g, ' ')
    .replace(/\d+\.(\.\.)?/g, ' ')
    .replace(/\b(1-0|0-1|1\/2-1\/2|\*)\s*$/, ' ')
    .trim()
    .split(/\s+/)
    .filter(Boolean);
  const chess = new Chess();
  return sans.map((raw, i) => {
    const before = chess.fen();
    const white = chess.turn() === 'w';
    const n = Number(before.split(' ')[5]);
    let m;
    try {
      m = chess.move(raw.replace(/^0-0-0/, 'O-O-O').replace(/^0-0/, 'O-O'));
    } catch {
      throw new Error(`${id}: jugada ilegal n.º ${i + 1}: ${raw} (${before})`);
    }
    return { san: m.san, from: m.from, to: m.to, fenAfter: chess.fen(), number: white ? `${n}.` : `${n}…`, captured: !!m.captured };
  });
}

// ───────────────────────── Respuestas ─────────────────────────

/** 'shown': el jugador pidió ver la respuesta sin jugar. */
export type AnswerOutcome = 'answer' | 'also-good' | 'spoils' | 'unclear' | 'unknown' | 'played-error' | 'shown';

/** Jugada que se enseña con «Ver la respuesta»: la de la partida o, si fue un error, la primera que el motor da por buena. */
export function referenceMove(q: Pick<ClipQuestion, 'playedCls' | 'playedUci' | 'played' | 'verdicts'>): { uci: string; san: string; fromGame: boolean } {
  if (q.playedCls === 'keeps') return { uci: q.playedUci, san: q.played.san, fromGame: true };
  const best = q.verdicts.find((x) => x.cls === 'keeps');
  return best ? { uci: best.uci, san: best.san, fromGame: false } : { uci: q.playedUci, san: q.played.san, fromGame: true };
}

export interface ClipAnswer {
  outcome: AnswerOutcome;
  /** Texto para el jugador. Solo usa el veredicto del motor y el texto propio del clip. */
  text: string;
  /** Línea del motor tras la jugada del jugador. */
  line?: string;
}

const lineEndText = (v: MoveVerdict): string =>
  v.lineEnd === 'stalemate' ? ' La línea acaba en ahogado: tablas.' : v.lineEnd === 'checkmate' ? ' La línea acaba en mate.' : v.lineEnd === 'insufficient' ? ' La línea acaba sin material para dar mate: tablas.' : '';

/** Responde a la jugada del jugador en una pregunta de un clip. */
export function judgeAnswer(q: ClipQuestion, uci: string): ClipAnswer {
  const playedEs = sanEs(q.played.san);
  const v = q.verdicts.find((x) => x.uci === uci);
  if (!v) return { outcome: 'unknown', text: `No hay análisis para esa jugada. En la partida se jugó ${playedEs}.` };
  const mine = sanEs(v.san);
  const after = new Chess(q.fen);
  after.move(v.san);
  const line = v.line.length ? lineText(after.fen(), v.line) : undefined;
  // «Pierde» solo si el motor da la posición por perdida; si no, en una posición ganadora, es que se escapa la victoria.
  const losing = 'mate' in v.score ? v.score.mate < 0 : v.score.cp <= DRAW_SPOILS_CP;
  const lost = q.target === 'win' && !losing ? 'deja escapar la victoria' : 'pierde';
  if (uci === q.playedUci) {
    if (q.playedCls === 'keeps') return { outcome: 'answer', text: q.why };
    const best = q.verdicts.find((x) => x.cls === 'keeps');
    const better = best ? ` Según el motor, lo correcto era ${sanEs(best.san)}.` : '';
    return { outcome: 'played-error', text: `Es lo que se jugó en la partida, pero según el motor ${mine} ${lost}.${lineEndText(v)}${better}`, line };
  }
  if (v.cls === 'keeps' && q.playedCls !== 'keeps') {
    // La partida tuvo aquí un error: encontrar una jugada que mantiene el resultado es la respuesta.
    const goal = q.target === 'win' ? 'gana' : 'mantiene las tablas';
    return { outcome: 'answer', text: `Según el motor, ${mine} ${goal}. ${q.why}`, line };
  }
  if (v.cls === 'keeps') {
    const goal = q.target === 'win' ? 'también gana' : 'también mantiene las tablas';
    return { outcome: 'also-good', text: `Según el motor, ${mine} ${goal}. En la partida se jugó ${playedEs}.`, line };
  }
  if (v.cls === 'spoils') return { outcome: 'spoils', text: `Según el motor, ${mine} ${lost}.${lineEndText(v)}`, line };
  return { outcome: 'unclear', text: `El motor no da un veredicto claro sobre ${mine}. En la partida se jugó ${playedEs}.`, line };
}

// ───────────────────────── Director ─────────────────────────

/** Adelanto, en segundos, para compensar que el tiempo se lee cada 100 ms. */
export const EPS = 0.12;
/** Si el tiempo ya ha pasado la marca por más de esto, el jugador ha saltado por delante de la parada. */
export const LATE = 1.0;
/** Tras ordenar la pausa, margen en el que el reproductor puede seguir diciendo «reproduciendo». */
export const PAUSE_GRACE_MS = 600;
/** Ventana en la que se reintenta la pausa una sola vez si el reproductor no la obedeció. */
export const PAUSE_RETRY_MS = 1500;
/** Diferencia de duración, en segundos, a partir de la cual se sospecha un anuncio u otro vídeo. */
export const DURATION_TOLERANCE = 2;
/** Si al reanudar el vídeo está a menos de esto del punto de reanudación, no se salta: solo se reproduce. */
export const RESUME_NEAR = 1.5;

export type Phase = 'idle' | 'watching' | 'asking' | 'reveal' | 'ended';

export interface DirectorState {
  phase: Phase;
  /** film: se para en las marcas · direct: pregunta primero · free: vídeo entero, sin marcas que lo paren. */
  mode: 'film' | 'direct' | 'free';
  /** Parada actual (preguntando o revelada) o próxima (viendo). */
  stop: number;
  /** El reproductor se ha pedido ya. En modo directo no se pide hasta la revelación. */
  videoOn: boolean;
  /** El jugador siguió viendo sin responder ('resumed') o saltó por delante de la parada ('skipped'). */
  missed: 'none' | 'resumed' | 'skipped';
  /** La duración que da el reproductor no es la del vídeo: probablemente un anuncio. No se actúa. */
  adSuspected: boolean;
  pauseIssuedAt: number | null;
  pauseRetries: number;
  /** Código de error del reproductor, si lo hubo. El clip sigue funcionando sin vídeo. */
  errorCode: number | null;
}

export type Command = { type: 'cue'; at: number } | { type: 'play' } | { type: 'pause' } | { type: 'seek'; at: number };

export type DirectorEvent =
  | { type: 'start'; mode: 'film' | 'direct' | 'free' }
  /** Lectura periódica del reproductor. `now` en milisegundos (reloj monótono). */
  | { type: 'tick'; time: number; duration: number; playing: boolean; now: number }
  /** El jugador quiere ver cómo sigue el vídeo. `time` es la última lectura, si la hay. */
  | { type: 'reveal'; time: number | null }
  /** El jugador quiere volver a la pregunta que se saltó. */
  | { type: 'back'; now: number }
  /** El jugador no quiere esperar a la marca: se pausa ya y se pregunta. */
  | { type: 'ask'; now: number }
  /** El jugador da el clip por terminado (p. ej. cuando el vídeo no se puede ver). */
  | { type: 'finish' }
  | { type: 'error'; code: number };

export const initialDirector = (): DirectorState => ({
  phase: 'idle',
  mode: 'film',
  stop: 0,
  videoOn: false,
  missed: 'none',
  adSuspected: false,
  pauseIssuedAt: null,
  pauseRetries: 0,
  errorCode: null,
});

type Step = { state: DirectorState; commands: Command[] };
const stay = (state: DirectorState): Step => ({ state, commands: [] });

/** Transición del director. Función pura: no toca el reproductor, devuelve las órdenes que hay que darle. */
export function direct(clip: Pick<Clip, 'start' | 'end' | 'stops' | 'video'>, s: DirectorState, e: DirectorEvent): Step {
  switch (e.type) {
    case 'start': {
      const base = { ...initialDirector(), errorCode: null };
      if ((e.mode === 'film' || e.mode === 'free') && canAutoPause(clip)) {
        return { state: { ...base, phase: 'watching', mode: 'film', videoOn: true }, commands: [{ type: 'cue', at: clip.start! }] };
      }
      if (e.mode === 'free') {
        // Sin marcas no hay dónde pararse: se ve el vídeo entero y la pregunta queda a un toque («Volver a la pregunta»).
        return { state: { ...base, phase: 'reveal', mode: 'free', stop: 0, videoOn: true, missed: 'skipped' }, commands: [{ type: 'cue', at: clip.start ?? 0 }] };
      }
      return stay({ ...base, phase: 'asking', mode: 'direct' });
    }

    case 'error': {
      const st: DirectorState = { ...s, videoOn: false, errorCode: e.code, adSuspected: false, pauseIssuedAt: null };
      if (s.phase === 'watching') return stay({ ...st, phase: 'asking', mode: 'direct' });
      if (s.phase === 'reveal') return stay({ ...st, phase: 'ended' });
      return stay(st);
    }

    case 'reveal': {
      if (s.phase !== 'asking') return stay(s);
      const stop = clip.stops[s.stop];
      const from = stop.resumeAt ?? stop.at ?? clip.start ?? 0;
      const next: DirectorState = { ...s, phase: 'reveal', missed: 'none', pauseIssuedAt: null, pauseRetries: 0 };
      if (!s.videoOn) {
        // El reproductor se carga parado en el punto exacto: el jugador pulsa ▶ en el propio reproductor.
        return { state: { ...next, videoOn: true }, commands: [{ type: 'cue', at: from }] };
      }
      const near = e.time != null && Math.abs(e.time - from) <= RESUME_NEAR && stop.resumeAt == null;
      return { state: next, commands: near ? [{ type: 'play' }] : [{ type: 'seek', at: from }, { type: 'play' }] };
    }

    case 'ask': {
      if (s.phase !== 'watching') return stay(s);
      return {
        state: { ...s, phase: 'asking', missed: 'none', pauseIssuedAt: e.now, pauseRetries: 0 },
        commands: [{ type: 'pause' }],
      };
    }

    case 'finish':
      return stay({ ...s, phase: 'ended', pauseIssuedAt: null });

    case 'back': {
      if (s.phase !== 'reveal' || s.missed === 'none') return stay(s);
      return {
        state: { ...s, phase: 'asking', missed: 'none', pauseIssuedAt: s.videoOn ? e.now : null, pauseRetries: 0 },
        commands: s.videoOn ? [{ type: 'pause' }] : [],
      };
    }

    case 'tick': {
      if (!s.videoOn) return stay(s);
      const expected = clip.video.duration;
      const ad = expected != null && e.duration > 0 && Math.abs(e.duration - expected) > DURATION_TOLERANCE;
      if (ad) return stay(s.adSuspected ? s : { ...s, adSuspected: true });
      const st = s.adSuspected ? { ...s, adSuspected: false } : s;

      if (st.phase === 'watching') {
        if (!e.playing) return stay(st);
        const at = clip.stops[st.stop].at!;
        if (e.time >= at - EPS && e.time <= at + LATE) {
          return { state: { ...st, phase: 'asking', missed: 'none', pauseIssuedAt: e.now, pauseRetries: 0 }, commands: [{ type: 'pause' }] };
        }
        if (e.time > at + LATE) return stay({ ...st, phase: 'reveal', missed: 'skipped' });
        return stay(st);
      }

      if (st.phase === 'asking') {
        if (!e.playing) return stay(st);
        if (st.pauseIssuedAt != null) {
          const dt = e.now - st.pauseIssuedAt;
          if (dt < PAUSE_GRACE_MS) return stay(st);
          if (st.pauseRetries < 1 && dt < PAUSE_RETRY_MS) {
            return { state: { ...st, pauseIssuedAt: e.now, pauseRetries: st.pauseRetries + 1 }, commands: [{ type: 'pause' }] };
          }
        }
        // El jugador ha pulsado ▶ en el reproductor: sigue viendo y no se le vuelve a parar.
        return stay({ ...st, phase: 'reveal', missed: 'resumed', pauseIssuedAt: null });
      }

      if (st.phase === 'reveal') {
        if (!e.playing) return stay(st);
        const next = clip.stops[st.stop + 1];
        if (next && next.at != null) {
          if (e.time >= next.at - EPS && e.time <= next.at + LATE) {
            return { state: { ...st, phase: 'asking', stop: st.stop + 1, missed: 'none', pauseIssuedAt: e.now, pauseRetries: 0 }, commands: [{ type: 'pause' }] };
          }
          if (e.time > next.at + LATE) return stay({ ...st, stop: st.stop + 1, missed: 'skipped' });
          return stay(st);
        }
        if (clip.end != null && e.time >= clip.end - EPS) {
          return { state: { ...st, phase: 'ended', pauseIssuedAt: e.now, pauseRetries: 0 }, commands: [{ type: 'pause' }] };
        }
        return stay(st);
      }
      return stay(st);
    }
  }
}

/** Lo que el director necesita de un reproductor de vídeo. La app tiene uno para YouTube. */
export interface PlayerAdapter {
  /** Carga el vídeo parado en el segundo indicado (crea el reproductor si hace falta). */
  cue(at: number): void;
  play(): void;
  pause(): void;
  seek(at: number): void;
  /** Lectura instantánea; null si el reproductor todavía no está listo. */
  snapshot(): { time: number; duration: number; playing: boolean } | null;
  destroy(): void;
}

/** Ejecuta en el reproductor las órdenes del director. */
export function run(adapter: PlayerAdapter, commands: Command[]): void {
  for (const c of commands) {
    if (c.type === 'cue') adapter.cue(c.at);
    else if (c.type === 'play') adapter.play();
    else if (c.type === 'pause') adapter.pause();
    else adapter.seek(c.at);
  }
}

/** Posiciones de cada paso de una lección, o el error si alguna jugada no es legal. */
export function lessonPositions(clip: Pick<Clip, 'timeline'> & { lesson?: ClipLesson }): { fen: string; last: { from: string; to: string; captured: boolean } | null }[] {
  const lesson = clip.lesson;
  if (!lesson) return [];
  const start = fenAfter(clip, lesson.from);
  if (!start) throw new Error(`La lección empieza fuera de las jugadas disponibles (${lesson.from}).`);
  return lesson.steps.map((st, i) => {
    const c = new Chess(start);
    let last: { from: string; to: string; captured: boolean } | null = null;
    for (const san of st.moves.split(/\s+/).filter(Boolean)) {
      const m = (() => {
        try {
          return c.move(san);
        } catch {
          return null;
        }
      })();
      if (!m) throw new Error(`Lección, paso ${i + 1}: ${san} no es legal.`);
      last = { from: m.from, to: m.to, captured: !!m.captured };
    }
    return { fen: c.fen(), last };
  });
}
