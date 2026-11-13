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
  /** Fecha de publicación, AAAA-MM-DD. */
  published: string;
  /** El canal es del titular de los derechos (organizador, federación o productora del vídeo). */
  official: boolean;
  /** Última vez que se comprobó que se puede incrustar (respuesta de oEmbed), AAAA-MM-DD. */
  checked: string;
  /** Duración en segundos. Sirve para detectar anuncios o un vídeo reeditado. null = sin medir. */
  duration: number | null;
}

export interface ClipQuestionSource {
  /** Media jugada (1 = primera de las blancas) que se pregunta: la posición es la de antes de jugarla. */
  ply: number;
  question: string;
  hint?: string;
  /** Por qué la jugada de la partida es buena. Texto propio, revisado contra el análisis. */
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
}

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
}

export const marksOf = (clip: Clip): ClipMarks => ({ start: clip.start, end: clip.end, stops: clip.stops.map((s) => s.at), duration: clip.video.duration });

/** Aplica unas marcas (p. ej. las hechas en este dispositivo con el editor) sobre un clip. */
export function withMarks(clip: Clip, m: ClipMarks): Clip {
  return {
    ...clip,
    start: m.start,
    end: m.end,
    video: { ...clip.video, duration: m.duration ?? clip.video.duration },
    stops: clip.stops.map((s, i) => ({ ...s, at: m.stops[i] ?? null, resumeAt: null })),
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

export type AnswerOutcome = 'answer' | 'also-good' | 'spoils' | 'unclear' | 'unknown' | 'played-error';

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
  mode: 'film' | 'direct';
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
  | { type: 'start'; mode: 'film' | 'direct' }
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
      if (e.mode === 'film' && canAutoPause(clip)) {
        return { state: { ...base, phase: 'watching', mode: 'film', videoOn: true }, commands: [{ type: 'cue', at: clip.start! }] };
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
