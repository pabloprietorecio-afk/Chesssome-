/**
 * «Cine de finales» con vídeo real: cartelera, reproductor con pausa automática y editor de marcas.
 *
 * Disposición obligada por las normas de YouTube: el reproductor va arriba, sin nada dibujado delante,
 * y la pregunta, el tablero y los botones van debajo. Responder nunca es obligatorio para seguir viendo.
 */
import { useCallback, useEffect, useMemo, useRef, useState, type JSX, type RefObject } from 'react';
import { Chess } from 'chess.js';
import pack from '../data/videocine.pack.json';
import {
  EPS,
  defaultStartPly,
  fenAfter,
  moveAt,
  plyAt,
  quickSteps,
  referenceMove,
  syncRemoveFrom,
  syncSetAt,
  syncCap,
  syncProblems,
  canAutoPause,
  direct,
  initialDirector,
  judgeAnswer,
  marksKey,
  marksOf,
  marksProblems,
  run,
  watchUrl,
  withMarks,
  type Clip,
  type ClipAnswer,
  type ClipMarks,
  type ClipQuestion,
  type ClipSync,
  type QuickStep,
  type DirectorEvent,
  type DirectorState,
  type VideoCinePack,
  gapPlies,
  lessonPositions,
  syncGapAt,
} from '../core/videoCine';
import { sanEs } from '../core/lang';
import { go, log, useAppState } from '../app/store';
import { clearMarks, devFlag, loadMarks, saveMarks, setDevFlag } from '../app/clipMarks';
import { Board2D } from './Board2D';
import type { MoveAnim } from './boardTypes';
import type { Arrow } from '../core/explain';
import { CinemaScreen } from './Cinema';
import { HOST_FLAG, YouTubeAdapter, embedHost, errorText } from './youtubePlayer';
import { suggestPause, suggestSync, videoTimes } from '../core/clockSync';

/** Versión publicada (la pone el flujo de GitHub Pages); en local, «local». */
const BUILD = (import.meta.env.VITE_BUILD as string | undefined) || 'local';

const PACK = pack as unknown as VideoCinePack;
const STEP_MS = 850;
const YT_TERMS = 'https://www.youtube.com/t/terms';
const GOOGLE_PRIVACY = 'https://policies.google.com/privacy';

type StartMode = 'film' | 'direct' | 'free';
type View = { kind: 'list' } | { kind: 'clip'; id: string; start?: StartMode } | { kind: 'editor'; id: string } | { kind: 'generated' };

/** Interruptor de desarrollo: localStorage['chessome.dev.localMarks'] = '1' deja usar marcas locales también en clips verificados. */
const LOCAL_MARKS_FLAG = 'localMarks';
/** ¿Se pueden cambiar en este dispositivo las marcas de pausa? (no, si están verificadas) */
const canEditTiming = (clip: Clip) => clip.marks !== 'verified' || devFlag(LOCAL_MARKS_FLAG);
/** ¿Hay algo que marcar? Las pausas si no están verificadas; el tablero sincronizado si el clip aún no lo trae. */
const canEditMarks = (clip: Clip) => canEditTiming(clip) || !clip.sync;

/**
 * Marcas de este dispositivo que siguen valiendo: las hechas sobre las marcas actuales del clip. Si el clip ha
 * cambiado desde entonces (p. ej. se publicaron marcas nuevas), las de este dispositivo se ignoran: `stale`.
 * Con el interruptor de desarrollo se usan siempre.
 */
function deviceMarks(clip: Clip): { marks: ClipMarks | null; stale: boolean } {
  const stored = loadMarks(clip.id);
  if (!stored) return { marks: null, stale: false };
  const { base, ...marks } = stored;
  if (base === marksKey(marksOf(clip)) || devFlag(LOCAL_MARKS_FLAG)) return { marks, stale: false };
  return { marks: null, stale: true };
}

/** Clip con las marcas hechas en este dispositivo. En un clip verificado solo cuenta el tablero sincronizado local. */
function effective(clip: Clip): { clip: Clip; local: boolean; stale: boolean } {
  const { marks: local, stale } = deviceMarks(clip);
  if (!local) return { clip, local: false, stale };
  if (canEditTiming(clip)) return { clip: withMarks(clip, local), local: true, stale };
  if (!clip.sync && local.sync) return { clip: withMarks(clip, { ...marksOf(clip), sync: local.sync }), local: true, stale };
  return { clip, local: false, stale };
}

/** Si el paso `i` de la lección sigue la línea del anterior (si no, vuelve a la posición de partida). */
function lessonContinues(lesson: NonNullable<Clip['lesson']>, i: number): boolean {
  const cur = lesson.steps[i].moves.split(/\s+/).filter(Boolean);
  const prev = lesson.steps[i - 1].moves.split(/\s+/).filter(Boolean);
  return cur.length > prev.length && prev.every((x, k) => cur[k] === x);
}

/** Jugadas de `first` a `last` en notación española: «53.Txe2+ Rxe2 54.Cxf8». */
function movesText(clip: Clip, first: number, last: number): string {
  const out: string[] = [];
  for (let p = first; p <= last; p++) {
    const m = moveAt(clip, p);
    if (!m) break;
    out.push(m.number.endsWith('.') || p === first ? `${m.number}${sanEs(m.san)}` : sanEs(m.san));
  }
  return out.join(' ');
}

/** Lo que muestra el tablero sincronizado en el segundo `t`, sin pasar de la media jugada `cap`. */
function syncedView(clip: Clip, sync: ClipSync, t: number, cap = Infinity): { ply: number; fen: string; last: { from: string; to: string } | null; label: string } | null {
  const ply = Math.min(plyAt(sync, t), cap);
  if (ply < sync.startPly) return null;
  const fen = fenAfter(clip, ply);
  if (!fen) return null;
  const m = moveAt(clip, ply);
  return { ply, fen, last: m ? { from: m.from, to: m.to } : null, label: m ? `tras ${m.number}${sanEs(m.san)}` : 'posición inicial' };
}

export function VideoCinemaScreen(): JSX.Element {
  const s = useAppState();
  const [view, setView] = useState<View>({ kind: 'list' });
  const current = view.kind === 'clip' || view.kind === 'editor' ? PACK.clips.find((c) => c.id === view.id) : undefined;
  if (view.kind === 'generated') return <CinemaScreen />;
  if (view.kind === 'clip' && current)
    return <ClipView key={current.id} packed={current} autostart={view.start} onClose={() => setView({ kind: 'list' })} onEdit={() => setView({ kind: 'editor', id: current.id })} />;
  if (view.kind === 'editor' && current) return <MarksEditor key={current.id} clip={current} onClose={() => setView({ kind: 'clip', id: current.id })} />;
  return (
    <section className="vc-home">
      <header className="vc-home-head">
        <p className="cm-kicker">Cine de finales</p>
        <h2>Finales reales, en vídeo</h2>
        <p className="cm-quiet">El vídeo se para solo justo antes de la jugada clave y te pregunta qué jugarías. Después ves lo que pasó de verdad.</p>
      </header>
      <ul className="vc-bill">
        {PACK.clips.map((c) => {
          const e = effective(c);
          const auto = canAutoPause(e.clip);
          const q0 = c.stops[0]?.questions[0];
          const questions = c.stops.reduce((n, st) => n + st.questions.length, 0);
          return (
            <li key={c.id} className="vc-card" data-clip={c.id}>
              <div className="vc-card-top">
                {q0 && (
                  <div className="vc-card-board" aria-hidden="true">
                    <Board2D fen={q0.fen} orientation={c.orientation} interactive={false} lastMove={q0.lead ? { from: q0.lead.from, to: q0.lead.to } : null} animMode="none" coordinates={false} />
                  </div>
                )}
                <div className="vc-card-text">
                  <span className="vc-card-year">{c.year}</span>
                  <h3 className="vc-card-title">{c.title}</h3>
                  <span className="vc-card-sub">{c.subtitle}</span>
                </div>
              </div>
              <p className="vc-card-intro">{c.intro}</p>
              <span className={`vc-chip ${auto ? 'vc-chip-on' : ''}`}>
                {auto
                  ? e.local
                    ? 'Se para solo · marcas de este dispositivo'
                    : c.marks === 'pending'
                      ? 'Se para solo · marcas sin comprobar'
                      : 'Se para solo antes de la jugada'
                  : 'Sin pausa marcada: el vídeo se ve entero'}
              </span>
              <button className="cm-primary cm-big vc-start" onClick={() => setView({ kind: 'clip', id: c.id, start: auto ? 'film' : 'free' })}>
                Comenzar
              </button>
              <button className="cm-link vc-direct" onClick={() => setView({ kind: 'clip', id: c.id, start: 'direct' })}>
                Ir directo a la pregunta, sin vídeo
              </button>
              <span className="vc-card-meta">
                {questions} preguntas · vídeo del canal {c.video.channel} en YouTube
              </span>
              {e.stale && <span className="vc-card-meta">Las marcas guardadas en este dispositivo eran de una versión anterior del clip: ya no se usan.</span>}
            </li>
          );
        })}
      </ul>
      <p className="cm-quiet cm-small vc-home-legal">
        Los vídeos se ven con el reproductor de YouTube, desde el canal oficial de quien los grabó; Chessome no los descarga ni los modifica. Al pulsar
        «Comenzar» se carga el reproductor: se aplican los{' '}
        <a href={YT_TERMS} target="_blank" rel="noreferrer">
          Términos del Servicio de YouTube
        </a>{' '}
        y la{' '}
        <a href={GOOGLE_PRIVACY} target="_blank" rel="noreferrer">
          Política de Privacidad de Google
        </a>
        .
      </p>
      {devFlag('generatedFilms') && (
        <button className="cm-link" onClick={() => setView({ kind: 'generated' })}>
          Películas generadas (aparcadas)
        </button>
      )}
      <button className="cm-link" onClick={() => go(s.rating && s.placement?.done ? 'home' : 'welcome')}>
        Volver
      </button>
    </section>
  );
}

// ───────────────────────── Director + reproductor ─────────────────────────

type PlayerStatus = 'none' | 'loading' | 'ready';

function useDirector(clip: Clip, mount: RefObject<HTMLDivElement | null>) {
  const [st, setSt] = useState<DirectorState>(initialDirector);
  const stRef = useRef(st);
  const adapter = useRef<YouTubeAdapter | null>(null);
  const [player, setPlayer] = useState<PlayerStatus>('none');
  const [blocked, setBlocked] = useState(false);
  const [playing, setPlaying] = useState(false);
  const [now, setNow] = useState<number | null>(null);

  const send = useCallback(
    (e: DirectorEvent) => {
      const r = direct(clip, stRef.current, e);
      stRef.current = r.state;
      if (r.commands.length) {
        if (!adapter.current && mount.current) {
          setPlayer('loading');
          adapter.current = new YouTubeAdapter(mount.current, clip.video.id, {
            onReady: () => setPlayer('ready'),
            onBlocked: () => setBlocked(true),
            onError: (code) => {
              adapter.current?.destroy();
              adapter.current = null;
              setPlayer('none');
              send({ type: 'error', code });
              log({ type: 'cine', data: { clip: clip.id, event: 'video_error', code } });
            },
          });
        }
        if (adapter.current) run(adapter.current, r.commands);
      }
      setSt(r.state);
    },
    [clip, mount],
  );

  // El tiempo del vídeo se lee cada 100 ms: la API de YouTube no avisa del avance.
  useEffect(() => {
    if (!st.videoOn) return;
    const id = window.setInterval(() => {
      const snap = adapter.current?.snapshot();
      if (!snap) return;
      setPlaying(snap.playing);
      setNow(snap.time);
      if (snap.playing) setBlocked(false);
      send({ type: 'tick', ...snap, now: performance.now() });
    }, 100);
    return () => window.clearInterval(id);
  }, [st.videoOn, send]);

  useEffect(
    () => () => {
      adapter.current?.destroy();
      adapter.current = null;
    },
    [clip],
  );

  const time = useCallback(() => adapter.current?.snapshot()?.time ?? null, []);
  const playNow = useCallback(() => adapter.current?.play(), []);
  return { st, send, player, blocked, playing, time, now, playNow };
}

/** Desplaza hasta el elemento si no está a la vista en más de la mitad; resuelve cuando ya lo está. */
function ensureVisible(el: HTMLElement | null): Promise<void> {
  if (!el) return Promise.resolve();
  const r = el.getBoundingClientRect();
  const visible = Math.max(0, Math.min(r.bottom, window.innerHeight) - Math.max(r.top, 0));
  if (r.height > 0 && visible / r.height > 0.6) return Promise.resolve();
  el.scrollIntoView({ behavior: 'smooth', block: 'start' });
  return new Promise((resolve) => window.setTimeout(resolve, 450));
}

// ───────────────────────── Vista de un clip ─────────────────────────

interface BoardState {
  fen: string;
  last: { from: string; to: string } | null;
  anim: MoveAnim | null;
}

const OUTCOME_LABEL: Record<ClipAnswer['outcome'], string> = {
  answer: '¡Esa es!',
  'also-good': 'También vale',
  spoils: 'No es esa',
  unclear: 'Sin veredicto claro',
  unknown: 'Sin análisis',
  'played-error': 'Fue un error en la partida',
  shown: 'La respuesta',
};

/** Marca discreta junto al veredicto: tick verde si vale, aspa roja si no. */
function OutcomeMark({ outcome }: { outcome: ClipAnswer['outcome'] }): JSX.Element | null {
  const ok = outcome === 'answer' || outcome === 'also-good';
  const bad = outcome === 'spoils' || outcome === 'played-error';
  if (!ok && !bad) return null;
  return (
    <svg className={`vc-mark vc-mark-${ok ? 'ok' : 'bad'}`} viewBox="0 0 16 16" width="13" height="13" aria-label={ok ? 'Correcta' : 'Incorrecta'} role="img">
      {ok ? <path d="M3 8.5l3.2 3L13 4.5" /> : <path d="M4 4l8 8M12 4l-8 8" />}
    </svg>
  );
}

function ClipView({ packed, autostart, onClose, onEdit }: { packed: Clip; autostart?: StartMode; onClose: () => void; onEdit: () => void }): JSX.Element {
  const s = useAppState();
  const { clip, local, stale } = useMemo(() => effective(packed), [packed]);
  const auto = canAutoPause(clip);
  const mount = useRef<HTMLDivElement>(null);
  const videoBox = useRef<HTMLDivElement>(null);
  const askBox = useRef<HTMLDivElement>(null);
  const stage = useRef<HTMLDivElement>(null);
  const { st, send, player, blocked, playing, time, now, playNow } = useDirector(clip, mount);

  const [qi, setQi] = useState(0);
  const [answer, setAnswer] = useState<ClipAnswer | null>(null);
  const [hint, setHint] = useState(false);
  const [board, setBoard] = useState<BoardState | null>(null);
  const [busy, setBusy] = useState(false);
  /** Paso de la lección abierto al acabar el clip; null = cerrada. */
  const [lessonStep, setLessonStep] = useState<number | null>(null);
  const lessonPos = useMemo(() => lessonPositions(clip), [clip]);
  const lessonRef = useRef<HTMLDivElement | null>(null);
  // Paso anterior de la lección (para animar solo al avanzar de uno en uno).
  const lessonPrev = useRef<number | null>(null);
  const lessonShownRef = useRef<number | null>(null);
  if (lessonShownRef.current !== lessonStep) {
    lessonPrev.current = lessonShownRef.current;
    lessonShownRef.current = lessonStep;
  }
  useEffect(() => {
    if (lessonStep != null) lessonRef.current?.scrollIntoView({ block: 'start', behavior: 'smooth' });
  }, [lessonStep]);
  const animKey = useRef(0);
  const timers = useRef<number[]>([]);
  const clearTimers = () => {
    timers.current.forEach((t) => window.clearTimeout(t));
    timers.current = [];
  };
  useEffect(() => clearTimers, []);

  const stop = clip.stops[st.stop];
  const q: ClipQuestion | undefined = stop?.questions[qi];
  const lastQ = stop?.questions[stop.questions.length - 1];
  const totalQuestions = stop?.questions.length ?? 0;
  const ev = (event: string, data: Record<string, unknown> = {}) => log({ type: 'cine', data: { clip: clip.id, event, ...data } });

  const showPlayed = (qq: ClipQuestion, animate: boolean) =>
    setBoard({
      fen: qq.played.fenAfter,
      last: { from: qq.played.from, to: qq.played.to },
      anim: animate ? { from: qq.played.from, to: qq.played.to, key: ++animKey.current, captured: qq.played.captured } : null,
    });

  // Al entrar en una pausa empieza la cadena de preguntas de esa parada.
  useEffect(() => {
    if (st.phase !== 'asking') return;
    clearTimers();
    const q0 = clip.stops[st.stop].questions[0];
    setQi(0);
    setAnswer(null);
    setHint(false);
    setBusy(false);
    setBoard({ fen: q0.fen, last: q0.lead ? { from: q0.lead.from, to: q0.lead.to } : null, anim: null });
    ev('pause', { stop: st.stop, mode: st.mode });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [st.phase, st.stop]);

  const onMove = (uci: string) => {
    if (!q || answer || busy || st.phase !== 'asking') return;
    const res = judgeAnswer(q, uci);
    setAnswer(res);
    if (uci === q.playedUci) showPlayed(q, false);
    else {
      const c = new Chess(q.fen);
      try {
        c.move({ from: uci.slice(0, 2), to: uci.slice(2, 4), promotion: uci[4] });
        setBoard({ fen: c.fen(), last: { from: uci.slice(0, 2), to: uci.slice(2, 4) }, anim: null });
      } catch {
        /* el tablero solo deja hacer jugadas legales */
      }
    }
    ev('answer', { stop: st.stop, question: qi, uci, outcome: res.outcome });
  };

  // Tras una jugada que no mantiene el resultado: volver a la posición y probar otra.
  const retry = () => {
    if (!q || !answer || busy) return;
    setAnswer(null);
    setBoard({ fen: q.fen, last: q.lead ? { from: q.lead.from, to: q.lead.to } : null, anim: null });
    ev('retry', { stop: st.stop, question: qi });
  };
  const canRetry = !!answer && answer.outcome !== 'answer' && answer.outcome !== 'also-good' && answer.outcome !== 'shown' && !busy;

  const showAnswer = () => {
    if (!q || answer) return;
    setAnswer({ outcome: 'shown', text: q.why });
    const ref = referenceMove(q);
    if (ref.fromGame) showPlayed(q, true);
    else {
      // En la partida fue un error: se enseña la jugada buena.
      const c = new Chess(q.fen);
      const m = c.move({ from: ref.uci.slice(0, 2), to: ref.uci.slice(2, 4), promotion: ref.uci[4] });
      setBoard({ fen: c.fen(), last: { from: m.from, to: m.to }, anim: { from: m.from, to: m.to, key: ++animKey.current, captured: !!m.captured } });
    }
    ev('show_answer', { stop: st.stop, question: qi });
  };

  const nextQuestion = () => {
    if (!q || !stop) return;
    const nq = stop.questions[qi + 1];
    if (!nq) return;
    setBusy(true);
    const steps: (() => void)[] = [];
    if (board?.fen !== q.played.fenAfter) {
      // El jugador probó otra jugada: se vuelve a la posición y se hace la de la partida.
      steps.push(() => setBoard({ fen: q.fen, last: null, anim: null }));
      steps.push(() => showPlayed(q, true));
    }
    for (const m of nq.bridge) {
      steps.push(() => setBoard({ fen: m.fenAfter, last: { from: m.from, to: m.to }, anim: { from: m.from, to: m.to, key: ++animKey.current, captured: m.captured } }));
    }
    steps.push(() => {
      setQi(qi + 1);
      setAnswer(null);
      setHint(false);
      setBusy(false);
    });
    clearTimers();
    steps.forEach((fn, i) => timers.current.push(window.setTimeout(fn, 350 + i * STEP_MS)));
  };

  /** «Seguir viendo sin responder»: primero un aviso con la jugada de la partida; el vídeo sigue al pulsar OK. */
  const [gate, setGate] = useState(false);
  /** La ventana de la pregunta (o del veredicto) sobre el tablero se quita al tocarla, para jugar o mirar. */
  const [cardHidden, setCardHidden] = useState(false);
  useEffect(() => setCardHidden(false), [qi, answer, st.phase]);
  // En el móvil, el mismo toque que suelta la pieza llega después como «click» a la ventana que acaba de aparecer
  // debajo del dedo: se ignoran los toques de los primeros instantes para que el veredicto no se cierre solo.
  const cardShownAt = useRef(0);
  useEffect(() => {
    if (!cardHidden) cardShownAt.current = performance.now();
  }, [cardHidden, qi, answer, st.phase]);
  const hideCard = () => {
    if (performance.now() - cardShownAt.current < 600) return;
    setCardHidden(true);
  };
  const skip = () => {
    if (!stop || !lastQ) return;
    clearTimers();
    setBusy(false);
    setGate(true);
  };
  useEffect(() => {
    if (st.phase !== 'asking') setGate(false);
  }, [st.phase]);
  const reveal = async () => {
    setGate(false);
    if (!stop || !lastQ) return;
    clearTimers();
    setBusy(false);
    showPlayed(lastQ, false);
    ev('reveal', { stop: st.stop, answered: qi + (answer ? 1 : 0), of: totalQuestions });
    await ensureVisible(videoBox.current);
    send({ type: 'reveal', time: time() });
  };

  const start = (mode: StartMode) => {
    clearTimers();
    setBoard(null);
    setAnswer(null);
    ev('start', { mode, auto });
    send({ type: 'start', mode });
  };
  // «Comenzar» en la cartelera arranca el clip directamente.
  const autostarted = useRef(false);
  useEffect(() => {
    if (!autostart || autostarted.current) return;
    autostarted.current = true;
    start(autostart);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const at = stop?.resumeAt ?? stop?.at ?? clip.start;
  const lastSan = lastQ ? sanEs(lastQ.played.san) : '';
  // Tablero sincronizado con el vídeo: mientras se ve el vídeo y, si hay jugadas marcadas, al revelar y al final.
  const sync: ClipSync = clip.sync ?? { startPly: defaultStartPly(clip), marks: [] };
  const hasSyncMarks = sync.marks.length > 0;
  const syncTime = st.phase === 'ended' && hasSyncMarks ? Infinity : (now ?? (st.phase === 'watching' ? (clip.start ?? 0) : null));
  const useSynced = syncTime != null && (st.phase === 'watching' || ((st.phase === 'reveal' || st.phase === 'ended') && hasSyncMarks));
  const synced = useSynced ? syncedView(clip, sync, syncTime!, syncCap(clip, st)) : null;
  const prevSynced = useRef<{ ply: number; key: number } | null>(null);
  let syncedAnim: MoveAnim | null = null;
  if (synced) {
    const prev = prevSynced.current;
    if (!prev || prev.ply !== synced.ply) {
      // Se anima solo el paso de una jugada a la siguiente; los saltos (rebobinar, adelantar) van sin animación.
      const step = !!prev && synced.ply === prev.ply + 1;
      prevSynced.current = { ply: synced.ply, key: step ? ++animKey.current : -1 };
    }
    const cur = prevSynced.current!;
    const m = moveAt(clip, synced.ply);
    if (cur.key >= 0 && m) syncedAnim = { from: m.from, to: m.to, key: cur.key, captured: m.captured };
  } else prevSynced.current = null;
  // Tras la pregunta, con el tablero sincronizado, no hace falta texto: el tablero grande sigue al vídeo.
  const quietReveal = st.phase === 'reveal' && st.missed === 'none' && hasSyncMarks && st.errorCode == null;
  // Mientras se ve el vídeo, el aviso va encima del tablero (sin mover nada) y desaparece en cuanto el vídeo arranca.
  const watchNote: JSX.Element | null =
    st.phase !== 'watching' && !quietReveal
      ? null
      : st.adSuspected
        ? <p>Anuncio de YouTube. {quietReveal ? 'El vídeo sigue después.' : 'La pausa esperará a que empiece el vídeo.'}</p>
        : !playing && player !== 'none'
          ? (
              <>
                {player === 'ready' && (
                  <button className="cm-primary vc-note-play" onClick={playNow} aria-label="Reproducir el vídeo">
                    ▶ {quietReveal ? 'Ver la jugada' : 'Ver el vídeo'}
                  </button>
                )}
                {quietReveal ? (
                  <p>{blocked ? 'Si no arranca, pulsa ▶ en el propio vídeo (el navegador no deja arrancarlo desde fuera).' : 'El tablero seguirá al vídeo.'}</p>
                ) : (
                  <p>{blocked ? 'Si no arranca, pulsa ▶ en el propio vídeo.' : 'Se parará solo justo antes de la jugada clave.'}</p>
                )}
              </>
            )
          : null;
  const inLesson = st.phase === 'ended' && lessonStep != null && !!clip.lesson;
  const lessonNow = inLesson ? { pos: lessonPos[lessonStep!], step: clip.lesson!.steps[lessonStep!] } : null;
  // Al avanzar un paso de la lección, se anima la última jugada del paso.
  const lessonAnim: MoveAnim | null =
    lessonNow && lessonNow.pos.last && lessonPrev.current != null && lessonPrev.current === lessonStep! - 1 && lessonContinues(clip.lesson!, lessonStep!)
      ? { ...lessonNow.pos.last, key: 1000 + lessonStep! }
      : null;
  const shown = lessonNow
    ? { fen: lessonNow.pos.fen, last: lessonNow.pos.last, anim: lessonAnim }
    : synced
      ? { fen: synced.fen, last: synced.last, anim: syncedAnim }
      : board;
  // En un tramo sin seguimiento (cortes de cámara), el tablero no finge: se atenúa y dice qué jugadas se están haciendo.
  const gap = synced && Number.isFinite(syncTime) ? syncGapAt(sync, syncTime!) : null;
  const gapMoves = gap ? (({ first, last }) => movesText(clip, first, Math.min(last, syncCap(clip, st))))(gapPlies(sync, gap)) : '';
  // El tablero no se gira: siempre la orientación del clip.
  const boardSide = clip.orientation;

  // Mientras se ve o se responde, la cabecera y el crédito se encogen para que vídeo, pregunta y tablero quepan en un móvil.
  const compact = st.phase === 'watching' || st.phase === 'asking' || st.phase === 'reveal';
  // Mientras se ve o se responde, vídeo, texto y tablero ocupan la pantalla entera, sin la barra de secciones,
  // para que el vídeo y el tablero se vean a la vez sin desplazarse.
  useEffect(() => {
    if (!compact) return;
    document.documentElement.dataset.immersive = 'cine';
    return () => {
      delete document.documentElement.dataset.immersive;
    };
  }, [compact]);
  useEffect(() => {
    if (!compact) return;
    const id = window.setTimeout(() => stage.current?.scrollIntoView({ behavior: 'smooth', block: 'start' }), 60);
    return () => window.clearTimeout(id);
  }, [compact, st.phase, st.stop]);
  // Vídeo y tablero a la vez en una pantalla: la cabecera y las opciones se condensan.
  const fit = compact && !!shown;
  const videoCredit = (
    <p className="vc-credit">
      {compact ? `Vídeo: ${clip.video.channel} · YouTube · ` : `Vídeo: «${clip.video.title}» · canal ${clip.video.channel} en YouTube · `}
      <a href={watchUrl(clip.video, at)} target="_blank" rel="noreferrer">
        Ver en YouTube
      </a>
    </p>
  );

  return (
    <section className="vc" data-clip={clip.id} data-phase={st.phase} data-stop={st.stop} data-question={qi} data-player={player} data-video={st.videoOn ? 'on' : 'off'}>
      <div className="vc-stage" ref={stage} data-fit={fit ? 'on' : 'off'}>
        {compact ? (
          <div className="vc-compact-row">
            <p className="cm-kicker vc-compact-head">{clip.subtitle}</p>
            {fit && (
              <a className="vc-compact-yt" href={watchUrl(clip.video, at)} target="_blank" rel="noreferrer">
                {clip.video.channel} en YouTube
              </a>
            )}
          </div>
        ) : (
          <header className="vc-head">
            <p className="cm-kicker">{clip.event}</p>
            <h2>{clip.title}</h2>
            <p className="cm-quiet">
              {clip.white} – {clip.black}
            </p>
          </header>
        )}

        <div className="vc-video" ref={videoBox}>
          {/* El reproductor de YouTube ocupa este hueco entero. Nunca se dibuja nada delante de él. */}
          <div className="vc-player" ref={mount} />
          {player === 'none' && (
            <div className="vc-poster">
              {st.errorCode != null ? (
                <>
                  <p>{errorText(st.errorCode)}</p>
                  <a className="cm-primary vc-yt-link" href={watchUrl(clip.video, at)} target="_blank" rel="noreferrer">
                    Ver en YouTube
                  </a>
                </>
              ) : (
                st.phase === 'idle' ? (
                  // Aún no hay reproductor: el botón carga el de YouTube (nada se pide a YouTube antes).
                  <>
                    <button className="vc-play" onClick={() => start(auto ? 'film' : 'free')} aria-label="Ver el vídeo">
                      ▶
                    </button>
                    <p>Ver el vídeo</p>
                    <p className="vc-poster-small">{auto ? 'Se parará solo antes de la jugada clave' : 'Aún sin pausa marcada: se verá entero'}</p>
                  </>
                ) : (
                  <p>El vídeo aparecerá aquí cuando quieras ver cómo ocurrió.</p>
                )
              )}
            </div>
          )}
        </div>
        {player === 'loading' && st.errorCode == null && <p className="cm-quiet vc-loading">Cargando el reproductor de YouTube…</p>}
        {!fit && videoCredit}

        {st.phase === 'idle' && (
          <div className="cm-hint vc-panel">
            <p>{clip.intro}</p>
            {auto ? (
              <button className="cm-primary" onClick={() => start('film')}>
                Ver el vídeo: se para antes de la jugada
              </button>
            ) : (
              <p className="vc-warn">
                Este vídeo todavía no tiene marcado el segundo de la pausa, así que no puede pararse solo.{' '}
                <button className="cm-link" onClick={onEdit}>
                  Marcar la pausa
                </button>
              </p>
            )}
            <button className={auto ? 'cm-why' : 'cm-primary'} onClick={() => start('direct')}>
              Ir directo a la pregunta
            </button>
            {local && <p className="vc-warn">La pausa usa marcas hechas en este dispositivo. No están verificadas.</p>}
            {stale && <p className="cm-quiet cm-small">Las marcas guardadas en este dispositivo eran de una versión anterior del clip: ya no se usan.</p>}
            {!local && auto && clip.marks === 'pending' && <p className="cm-quiet cm-small">Marcas sin comprobar aún en el vídeo.</p>}
            <p className="cm-quiet cm-small">
              El vídeo se reproduce con YouTube. Al verlo aceptas los{' '}
              <a href={YT_TERMS} target="_blank" rel="noreferrer">
                Términos del Servicio de YouTube
              </a>{' '}
              y se aplica la{' '}
              <a href={GOOGLE_PRIVACY} target="_blank" rel="noreferrer">
                Política de Privacidad de Google
              </a>
              . Nada se carga de YouTube hasta que eliges ver el vídeo.
            </p>
          </div>
        )}

        {st.phase === 'watching' && !synced && (
          <div className="cm-hint vc-panel" aria-live="polite">
            {st.adSuspected ? (
              <p>Anuncio de YouTube. La pausa esperará a que empiece el vídeo.</p>
            ) : playing ? (
              <p>El vídeo se parará solo justo antes de la jugada clave.</p>
            ) : (
              <p>
                <strong>Pulsa ▶ en el vídeo.</strong> Se parará solo justo antes de la jugada clave.
              </p>
            )}
            <button className="cm-link" onClick={() => send({ type: 'ask', now: performance.now() })}>
              No esperar: ir ya a la pregunta
            </button>
          </div>
        )}

        {/* En la pausa: la pregunta (o el veredicto) encima del tablero y las acciones debajo, para que el vídeo y el
            tablero quepan a la vez en un móvil. */}
        {st.phase === 'asking' && q && !answer && !gate && !fit && (
          <div className="cm-hint vc-panel vc-ask" ref={askBox}>
            <p className="cm-kicker">
              {st.videoOn ? 'Vídeo en pausa' : 'Antes del vídeo'} · pregunta {qi + 1} de {totalQuestions}
            </p>
            {busy ? <p className="cm-quiet">Así siguió la partida…</p> : <p className="vc-question">{q.question}</p>}
          </div>
        )}

        {st.phase === 'asking' && q && answer && !gate && !fit && (
          <div className={`cm-hint vc-panel vc-answer vc-o-${answer.outcome}`}>
            <p className="cm-kicker">
              <OutcomeMark outcome={answer.outcome} /> {OUTCOME_LABEL[answer.outcome]}
            </p>
            <p>{answer.text}</p>
            {canRetry && (
              <button className="cm-why vc-retry" onClick={retry}>
                Repetir
              </button>
            )}
          </div>
        )}

        {lessonNow && (
          <div ref={lessonRef} className="cm-hint vc-panel vc-lesson" data-step={lessonStep}>
            <p className="cm-kicker">
              Lección · paso {lessonStep! + 1} de {clip.lesson!.steps.length}
            </p>
            {lessonStep === 0 && <h3 className="vc-lesson-title">{clip.lesson!.title}</h3>}
            <p>{lessonNow.step.text}</p>
            <div className="cm-row">
              {lessonStep! > 0 && (
                <button className="cm-why" onClick={() => setLessonStep(lessonStep! - 1)}>
                  Anterior
                </button>
              )}
              {lessonStep! < clip.lesson!.steps.length - 1 ? (
                <button className="cm-primary" onClick={() => setLessonStep(lessonStep! + 1)}>
                  Siguiente
                </button>
              ) : (
                <button className="cm-primary" onClick={() => setLessonStep(null)}>
                  Terminar la lección
                </button>
              )}
            </div>
          </div>
        )}

        {shown && st.phase !== 'idle' && (
          <div className="vc-board" data-board={synced ? 'video' : 'question'} data-ply={synced?.ply ?? ''} data-gap={gap ? 'on' : 'off'}>
            {synced && !lessonNow && <p className="cm-kicker vc-board-label">Tablero del vídeo · <span className="vc-san">{synced.label}</span></p>}
            {!synced && fit && st.phase === 'asking' && q && (
              <p className="cm-kicker vc-board-label vc-board-label-ask">
                <span className="vc-board-label-text">
                  {st.videoOn ? 'Vídeo en pausa' : 'Antes del vídeo'} · pregunta {qi + 1} de {totalQuestions}
                </span>
                {!gate && cardHidden && (
                  <button className="vc-reopen" onClick={() => setCardHidden(false)}>
                    {answer ? 'Ver la explicación' : 'Ver la pregunta'}
                  </button>
                )}
              </p>
            )}
            <div className="vc-board-fit" data-gap={gap ? 'on' : undefined}>
              <div className="vc-board-box">
                <Board2D
                  fen={shown.fen}
                  orientation={boardSide}
                  interactive={st.phase === 'asking' && !answer && !busy && !gate}
                  lastMove={shown.last}
                  arrows={lessonNow?.step.arrows as Arrow[] | undefined}
                  animate={shown.anim ?? undefined}
                  animMode={s.settings.anim}
                  coordinates={s.settings.coordinates}
                  onMove={onMove}
                />
                {fit && st.phase === 'asking' && q && !gate && !cardHidden && (
                  <div className="vc-gap vc-card-over" onClick={hideCard} role="dialog" aria-label="Pregunta">
                    {!answer ? (
                      <div className="vc-gap-card vc-glass vc-ask">
                        {busy ? <p className="cm-quiet">Así siguió la partida…</p> : <p className="vc-question">{q.question}</p>}
                        {hint && q.hint && <p className="vc-hint">{q.hint}</p>}
                        {!busy && <p className="cm-quiet cm-small">Toca para jugar en el tablero</p>}
                      </div>
                    ) : (
                      <div className={`vc-gap-card vc-glass vc-answer vc-o-${answer.outcome}`}>
                        <p className="cm-kicker">
              <OutcomeMark outcome={answer.outcome} /> {OUTCOME_LABEL[answer.outcome]}
            </p>
                        <p>{answer.text}</p>
                        {answer.line && <p className="cm-line-text">Línea del motor: {answer.line}</p>}
                        {answer.outcome !== 'answer' && answer.outcome !== 'shown' && q.playedCls === 'keeps' && <p className="cm-quiet">En la partida: {q.why}</p>}
                        {canRetry && (
                          <button
                            className="cm-why vc-retry"
                            onClick={(e) => {
                              e.stopPropagation();
                              retry();
                            }}
                          >
                            Repetir
                          </button>
                        )}
                        <p className="cm-quiet cm-small">Toca para ver el tablero</p>
                      </div>
                    )}
                  </div>
                )}
                {gate && st.phase === 'asking' && (
                  <div className="vc-gap vc-gate">
                    <div className="vc-gap-card vc-glass">
                      <p>En la partida se jugó {q ? sanEs(q.played.san) : lastSan}.</p>
                      <button className="cm-primary" onClick={reveal}>
                        OK
                      </button>
                    </div>
                  </div>
                )}
                {watchNote && !gap && !gate && (
                  <div className="vc-gap vc-watch-note" role="status" aria-live="polite">
                    <div className="vc-gap-card vc-glass vc-note-card">{watchNote}</div>
                  </div>
                )}
                {gap && (
                  <div className="vc-gap" role="status">
                    <div className="vc-gap-card">
                      <p className="vc-gap-title">El tablero no puede seguir estas jugadas</p>
                      {gapMoves && <p className="vc-gap-moves">{gapMoves}</p>}
                      <p className="vc-gap-note">El vídeo tiene cortes de cámara aquí. El tablero se pone al día en cuanto se vuelven a ver las piezas.</p>
                    </div>
                  </div>
                )}
              </div>
            </div>
          </div>
        )}

      {fit && !(st.phase === 'asking' && q && !gate) && <div className="vc-tools" aria-hidden="true" />}
      {st.phase === 'asking' && q && !answer && !gate && (
        <div className="vc-tools">
          {!busy && (
            <>
              <div className="cm-row">
                {q.hint &&
                  (fit ? (
                    !hint && (
                      <button className="cm-why" onClick={() => { setHint(true); setCardHidden(false); }}>
                        Pista
                      </button>
                    )
                  ) : hint ? (
                    <p className="vc-hint">{q.hint}</p>
                  ) : (
                    <button className="cm-why" onClick={() => setHint(true)}>Pista</button>
                  ))}
                <button className="cm-link" onClick={showAnswer}>
                  Ver la respuesta
                </button>
              </div>
            </>
          )}
          {!fit && <SkipLink errored={st.errorCode != null} videoOn={st.videoOn} onReveal={skip} onFinish={() => send({ type: 'finish' })} />}
        </div>
      )}

      {st.phase === 'asking' && q && answer && !gate && (
        <div className="vc-tools">
          {!fit && answer.line && <p className="cm-line-text">Línea del motor: {answer.line}</p>}
          {!fit && answer.outcome !== 'answer' && answer.outcome !== 'shown' && q.playedCls === 'keeps' && <p className="cm-quiet">En la partida: {q.why}</p>}
          {qi + 1 < totalQuestions ? (
            <button className="cm-primary" onClick={nextQuestion} disabled={busy}>
              Siguiente pregunta
            </button>
          ) : st.errorCode != null ? (
            <button className="cm-primary" onClick={() => send({ type: 'finish' })}>
              Terminar
            </button>
          ) : (
            <button className="cm-primary" onClick={reveal}>
              Ver cómo ocurrió en el vídeo
            </button>
          )}
          {!fit && qi + 1 < totalQuestions && <SkipLink errored={st.errorCode != null} videoOn={st.videoOn} onReveal={skip} onFinish={() => send({ type: 'finish' })} />}
        </div>
      )}

      {st.phase === 'reveal' && !quietReveal && (
        <div className="cm-hint vc-panel" aria-live="polite">
          {st.mode === 'free' && st.missed !== 'none' ? (
            <>
              <p className="cm-kicker">Vídeo sin pausas</p>
              <p>Este clip aún no tiene marcado el segundo de la pausa, así que el vídeo no se parará solo.</p>
              {!playing && player === 'ready' && (
                <p>
                  <strong>Pulsa ▶ en el vídeo</strong> para verlo.
                </p>
              )}
              {player === 'loading' && <p className="cm-quiet">Cargando el reproductor de YouTube…</p>}
              <div className="cm-row">
                <button className="cm-why" onClick={() => send({ type: 'back', now: performance.now() })}>
                  Ir a la pregunta
                </button>
                <button className="cm-link" onClick={onEdit}>
                  Marcar la pausa
                </button>
              </div>
            </>
          ) : st.missed === 'none' ? (
            <>
              <p className="cm-kicker">Así ocurrió</p>
              {!playing && player !== 'none' && (
                <p>
                  <strong>Pulsa ▶ en el vídeo</strong> para ver la jugada{blocked ? ' (el navegador no deja arrancarlo solo)' : ''}.
                </p>
              )}
              {player === 'loading' && <p className="cm-quiet">Cargando el reproductor de YouTube…</p>}
              {playing && <p>En la partida se jugó {lastSan}. {hasSyncMarks ? 'El tablero sigue al vídeo.' : 'Mira cómo ocurrió.'}</p>}
              {st.adSuspected && <p className="cm-quiet">Anuncio de YouTube: el vídeo sigue después.</p>}
            </>
          ) : (
            <>
              <p className="cm-kicker">{st.missed === 'resumed' ? 'Has seguido viendo el vídeo' : 'Has pasado de largo la pregunta'}</p>
              <p>No pasa nada: responder es opcional. Si quieres, puedes pensarla ahora.</p>
              <button className="cm-why" onClick={() => send({ type: 'back', now: performance.now() })}>
                Volver a la pregunta
              </button>
            </>
          )}
          <button className="cm-link" onClick={() => send({ type: 'finish' })}>
            Terminar
          </button>
        </div>
      )}

      {st.phase === 'ended' && !lessonNow && (
        <div className="cm-hint vc-panel">
          <p className="cm-kicker">Fin del clip</p>
          <p>{clip.outro}</p>
          {lastQ && (
            <p className="cm-quiet cm-small">
              Respuestas comprobadas con {PACK.engine.name} (profundidad {PACK.engine.depth}): en cada pregunta se analizaron todas las jugadas legales.
              {stop.questions.every((x) => x.proof === 'mate') ? ' Mate forzado encontrado.' : ' Sin prueba de mate ni tablas de finales.'}
            </p>
          )}
          <p className="cm-quiet cm-small">{clip.gameSource}</p>
          <div className="cm-row">
            {clip.lesson && (
              <button className="cm-primary" onClick={() => setLessonStep(0)}>
                Ver la lección
              </button>
            )}
            <button className="cm-why" onClick={() => { setLessonStep(null); start(auto && st.errorCode == null ? 'film' : 'direct'); }}>
              Otra vez
            </button>
          </div>
        </div>
      )}


      <div className="cm-row vc-foot">
        <button className="cm-link" onClick={onClose}>
          Volver a la cartelera
        </button>
        {st.phase === 'watching' && synced && (
          <button className="cm-link" onClick={() => send({ type: 'ask', now: performance.now() })}>
            Ir ya a la pregunta
          </button>
        )}
        {fit && st.phase === 'asking' && q && !gate && (!answer || qi + 1 < totalQuestions) && <SkipLink errored={st.errorCode != null} videoOn={st.videoOn} onReveal={skip} onFinish={() => send({ type: 'finish' })} />}
        {st.phase === 'reveal' && quietReveal && (
          <button className="cm-link" onClick={() => send({ type: 'finish' })}>
            Terminar
          </button>
        )}
        {canEditMarks(packed) && (
          <button className="cm-link" onClick={onEdit}>
            Editor de marcas
          </button>
        )}
      </div>
      </div>
    </section>
  );
}

/** Seguir viendo sin responder: siempre disponible, porque no se puede condicionar el vídeo a contestar. */
function SkipLink({ errored, videoOn, onReveal, onFinish }: { errored: boolean; videoOn: boolean; onReveal: () => void; onFinish: () => void }): JSX.Element {
  if (errored)
    return (
      <button className="cm-link" onClick={onFinish}>
        Terminar sin responder
      </button>
    );
  return (
    <button className="cm-link" onClick={onReveal}>
      {videoOn ? 'Seguir viendo sin responder' : 'Ver el vídeo sin responder'}
    </button>
  );
}

// ───────────────────────── Editor de marcas ─────────────────────────

type MarkKey = 'start' | 'end' | number;

const fmt = (t: number | null) => (t == null ? '—' : `${t.toFixed(2)} s`);
const clock = (t: number) => `${Math.floor(t / 60)}:${String(Math.floor(t % 60)).padStart(2, '0')}`;

/**
 * Herramienta para marcar, viendo el vídeo, el segundo de inicio, el de cada pausa y el de fin.
 * Es la única parte del cine que no se puede automatizar: hay que mirar cuándo se hace la jugada.
 */
function MarksEditor({ clip, onClose }: { clip: Clip; onClose: () => void }): JSX.Element {
  const mount = useRef<HTMLDivElement>(null);
  const adapter = useRef<YouTubeAdapter | null>(null);
  const [status, setStatus] = useState<PlayerStatus>('none');
  const [error, setError] = useState<number | null>(null);
  const [snap, setSnap] = useState<{ time: number; duration: number; playing: boolean } | null>(null);
  const [raw, setRaw] = useState<number | null>(null);
  const [standardHost, setStandardHost] = useState(() => devFlag(HOST_FLAG));
  const [marks, setMarks] = useState<ClipMarks>(() => deviceMarks(clip).marks ?? marksOf(clip));
  const [test, setTest] = useState<{ at: number; pausedAt: number | null } | null>(null);
  const testRef = useRef(test);
  testRef.current = test;
  const [note, setNote] = useState('');

  useEffect(
    () => () => {
      adapter.current?.destroy();
      adapter.current = null;
    },
    [],
  );

  useEffect(() => {
    if (status === 'none') return;
    const id = window.setInterval(() => {
      setRaw(adapter.current?.rawState() ?? null);
      const sn = adapter.current?.snapshot();
      if (!sn) return;
      setSnap(sn);
      if (sn.duration > 0) setMarks((m) => (m.duration === Math.round(sn.duration * 10) / 10 ? m : { ...m, duration: Math.round(sn.duration * 10) / 10 }));
      const t = testRef.current;
      if (t && t.pausedAt == null && sn.playing && sn.time >= t.at - EPS) {
        adapter.current?.pause();
        setTest({ at: t.at, pausedAt: sn.time });
      }
    }, 100);
    return () => window.clearInterval(id);
  }, [status]);

  const load = () => {
    if (!mount.current || adapter.current) return;
    setStatus('loading');
    adapter.current = new YouTubeAdapter(mount.current, clip.video.id, {
      onReady: () => setStatus('ready'),
      onError: (code) => {
        adapter.current?.destroy();
        adapter.current = null;
        setStatus('none');
        setError(code);
      },
    });
    adapter.current.cue(0);
  };

  const now = snap ? Math.round(snap.time * 100) / 100 : null;
  const get = (k: MarkKey): number | null => (k === 'start' ? marks.start : k === 'end' ? marks.end : marks.stops[k]);
  const set = (k: MarkKey, v: number | null) => {
    setNote('');
    setMarks((m) => (k === 'start' ? { ...m, start: v } : k === 'end' ? { ...m, end: v } : { ...m, stops: m.stops.map((x, i) => (i === k ? v : x)) }));
  };
  const nudge = (k: MarkKey, d: number) => {
    const v = get(k);
    if (v != null) set(k, Math.max(0, Math.round((v + d) * 100) / 100));
  };
  const tryPause = (at: number) => {
    setTest({ at, pausedAt: null });
    adapter.current?.seek(Math.max(0, at - 4));
    adapter.current?.play();
  };

  // Estimación con los relojes: un ancla (segundo en que se pulsa el reloj tras una jugada) y el resto se calcula.
  const labels = clip.clockLabels ?? [];
  const firstQ = clip.stops[0]?.questions[0]?.ply;
  const [anchorPly, setAnchorPly] = useState<number>(() => (labels.some((l) => l.ply === firstQ) ? firstQ! : labels[0]?.ply ?? 0));
  const [anchorAt, setAnchorAt] = useState<number | null>(null);
  const estimates = clip.clocks && anchorAt != null ? videoTimes(clip.clocks, { ply: anchorPly, at: anchorAt }) : null;
  const goTo = (t: number) => {
    adapter.current?.seek(Math.max(0, t - 4));
    adapter.current?.play();
  };

  // Tablero sincronizado: se guarda junto a las marcas (marks.sync).
  const timing = canEditTiming(clip);
  const sync: ClipSync = marks.sync ?? { startPly: defaultStartPly(clip), marks: [] };
  const changeSync = (f: (s: ClipSync) => ClipSync) => {
    setNote('');
    setMarks((m) => ({ ...m, sync: f(m.sync ?? { startPly: defaultStartPly(clip), marks: [] }) }));
  };

  const problems = [...marksProblems(marks), ...syncProblems(clip, sync, marks)];
  const json = JSON.stringify({ clip: clip.id, video: clip.video.id, ...marks });
  const rows: { key: MarkKey; label: string }[] = [
    { key: 'start', label: 'Inicio' },
    ...clip.stops.map((st, i) => ({ key: i as MarkKey, label: `Pausa ${i + 1} (antes de ${st.questions[0].played.number}${sanEs(st.questions[0].played.san)})` })),
    { key: 'end', label: 'Fin' },
  ];

  return (
    <section className="vc vc-editor" data-editor={clip.id} data-player={status}>
      <header className="vc-head">
        <p className="cm-kicker">Editor de marcas</p>
        <h2>{clip.title}</h2>
        <p className="cm-quiet">Mira el vídeo y marca el segundo exacto de cada momento. La pausa tiene que caer justo antes de que se haga la jugada (y antes de que alguien la diga).</p>
      </header>

      <div className="vc-video">
        <div className="vc-player" ref={mount} />
        {status === 'none' && (
          <div className="vc-poster">
            {error != null ? (
              <p>{errorText(error)}</p>
            ) : (
              <button className="cm-primary" onClick={load}>
                Cargar el vídeo
              </button>
            )}
          </div>
        )}
      </div>
      {status === 'loading' && <p className="cm-quiet vc-loading">Cargando el reproductor de YouTube…</p>}

      <p className="vc-time" aria-live="off">
        {snap ? (
          <>
            <strong>{snap.time.toFixed(2)} s</strong> ({clock(snap.time)}) de {snap.duration.toFixed(0)} s · {snap.playing ? 'reproduciendo' : 'parado'}
          </>
        ) : (
          'Carga el vídeo para leer el tiempo.'
        )}
      </p>

      {timing && <QuickMarker clip={clip} marks={marks} sync={sync} now={now} ready={status === 'ready'} setMarks={setMarks} onNote={setNote} />}

      {!timing && <p className="cm-quiet cm-small">Las pausas de este clip ya están verificadas. Aquí solo se marca el tablero sincronizado.</p>}
      {timing && (
        <div className="vc-marks">
          {rows.map(({ key, label }) => {
            const v = get(key);
            return (
              <div className="vc-mark" key={String(key)} data-mark={String(key)}>
                <div className="vc-mark-head">
                  <span>{label}</span>
                  <strong>{fmt(v)}</strong>
                </div>
                <div className="vc-mark-tools">
                  <button className="cm-chip" onClick={() => now != null && set(key, now)} disabled={now == null}>
                    = ahora
                  </button>
                  {[-1, -0.1, 0.1, 1].map((d) => (
                    <button key={d} className="cm-chip" onClick={() => nudge(key, d)} disabled={v == null} aria-label={`${d > 0 ? 'Sumar' : 'Restar'} ${Math.abs(d)} segundos`}>
                      {d > 0 ? `+${d}` : d}
                    </button>
                  ))}
                  {typeof key === 'number' && (
                    <button className="cm-chip" onClick={() => v != null && tryPause(v)} disabled={v == null || status !== 'ready'}>
                      Probar
                    </button>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      )}

      {timing && clip.clocks && labels.length > 0 && (
        <section className="vc-clock" data-clock="on">
          <h3>Estimar con los relojes</h3>
          {clip.video.continuous === false && (
            <p className="vc-warn">Este vídeo está montado con cortes: el tiempo del vídeo no sigue al de la partida y la estimación no vale.</p>
          )}
          <p className="cm-quiet cm-small">
            Marca el segundo en que se pulsa el reloj tras una jugada. Con los relojes de la partida se calcula el de las demás. Solo vale si el vídeo no
            tiene cortes entre medias: compruébalo con «Ir» en dos o tres jugadas.
          </p>
          <div className="cm-row">
            <label className="vc-clock-anchor">
              Jugada ancla{' '}
              <select value={anchorPly} onChange={(e) => setAnchorPly(Number(e.target.value))}>
                {labels.map((l) => (
                  <option key={l.ply} value={l.ply}>
                    {l.label}
                  </option>
                ))}
              </select>
            </label>
            <button className="cm-chip" onClick={() => now != null && setAnchorAt(now)} disabled={now == null}>
              = ahora
            </button>
            <strong>{fmt(anchorAt)}</strong>
          </div>
          {estimates && (
            <>
              <ul className="vc-clock-list">
                {labels.map((l) => {
                  const t = estimates.get(l.ply);
                  if (t == null) return null;
                  return (
                    <li key={l.ply} className={l.ply === anchorPly ? 'vc-clock-anchor-row' : ''} data-ply={l.ply}>
                      <span>{l.label}</span>
                      <span className="vc-clock-t">
                        {t.toFixed(1)} s · {clock(Math.max(0, t))}
                      </span>
                      <button className="cm-chip" onClick={() => goTo(t)} disabled={status !== 'ready'} aria-label={`Ir a ${l.label}`}>
                        Ir
                      </button>
                    </li>
                  );
                })}
              </ul>
              {clip.stops.map((st, i) => {
                const sug = suggestPause(estimates, st.questions[0].ply);
                const mine = marks.stops[i];
                return (
                  <p key={i} className="cm-small" data-suggest={i}>
                    Pausa {i + 1}: estimada {sug == null ? 'sin hueco entre jugadas' : `${sug.toFixed(2)} s`}
                    {mine != null && sug != null && ` · la marcada: ${mine.toFixed(2)} s (diferencia ${(mine - sug).toFixed(1)} s)`}
                  </p>
                );
              })}
              <button
                className="cm-why"
                onClick={() => {
                  const firstQ = clip.stops[0]?.questions[0]?.ply ?? 1;
                  setMarks((m) => {
                    const stops = clip.stops.map((st, i) => suggestPause(estimates, st.questions[0].ply) ?? m.stops[i]);
                    const sug = suggestSync(estimates, { start: m.start, end: m.end, minStart: clip.timeline.fromPly === 1 ? 0 : clip.timeline.fromPly, maxStart: firstQ - 1 });
                    return sug ? { ...m, start: sug.start, stops, sync: sug.sync } : { ...m, stops };
                  });
                  setNote('Marcas estimadas puestas: inicio (si faltaba), pausas y tablero. Compruébalas con «Ir» y «Probar» antes de guardar.');
                }}
              >
                Poner las marcas estimadas
              </button>
              <p className="cm-quiet cm-small">Relojes: {clip.clocks.source}</p>
            </>
          )}
        </section>
      )}

      <SyncEditor clip={clip} sync={sync} onChange={changeSync} now={now} ready={status === 'ready'} onGo={goTo} />

      {test && (
        <p className="cm-quiet" aria-live="polite">
          {test.pausedAt == null ? `Probando: el vídeo debe pararse en ${test.at.toFixed(2)} s…` : `Se ha parado en ${test.pausedAt.toFixed(2)} s (marca: ${test.at.toFixed(2)} s). ¿Se ve ya la jugada? Si es así, adelanta la marca.`}
        </p>
      )}
      {problems.map((p) => (
        <p key={p} className="vc-warn">
          {p}
        </p>
      ))}

      <div className="cm-row">
        <button
          className="cm-primary"
          disabled={problems.length > 0}
          onClick={() => {
            const ok = saveMarks(clip.id, marks, marksKey(marksOf(clip)));
            setNote(ok ? 'Guardado en este dispositivo. El clip ya puede pararse solo aquí.' : 'No se ha podido guardar en este dispositivo.');
          }}
        >
          Guardar en este dispositivo
        </button>
        <button
          className="cm-why"
          onClick={() => {
            navigator.clipboard?.writeText(json).then(
              () => setNote('Copiado. Pégalo en el chat para dejarlo en el proyecto.'),
              () => setNote('No se ha podido copiar: selecciona el texto de abajo.'),
            );
          }}
        >
          Copiar las marcas
        </button>
        <button
          className="cm-link cm-danger"
          onClick={() => {
            clearMarks(clip.id);
            setMarks(marksOf(clip));
            setNote('Marcas de este dispositivo borradas.');
          }}
        >
          Borrar
        </button>
      </div>
      {note && (
        <p className="cm-quiet" aria-live="polite">
          {note}
        </p>
      )}
      <textarea className="vc-json" readOnly value={json} rows={3} aria-label="Marcas en formato para copiar" />
      <details className="vc-diag">
        <summary>Diagnóstico</summary>
        <p className="cm-small">
          Versión {BUILD} · reproductor {(adapter.current?.host || embedHost()).replace('https://', '')} · estado de YouTube {raw ?? '—'} (−1 sin empezar, 0 terminado, 1 reproduciendo, 2 en pausa, 3 cargando, 5 preparado)
        </p>
        <label className="cm-check">
          <input
            type="checkbox"
            checked={standardHost}
            onChange={(e) => {
              setDevFlag(HOST_FLAG, e.target.checked);
              setStandardHost(e.target.checked);
              adapter.current?.destroy();
              adapter.current = null;
              setStatus('none');
              setSnap(null);
              setError(null);
            }}
          />
          Usar youtube.com en lugar de youtube-nocookie.com (solo para comprobar si el modo de privacidad da problemas)
        </label>
      </details>
      <p className="cm-quiet cm-small">Las marcas guardadas aquí solo valen en este dispositivo y aparecen como «sin verificar» hasta que se añadan al proyecto.</p>
      <button className="cm-link" onClick={onClose}>
        Volver al clip
      </button>
    </section>
  );
}

/** Marcas del tablero sincronizado: en qué segundo del vídeo aparece cada jugada. */
function SyncEditor({
  clip,
  sync,
  onChange,
  now,
  ready,
  onGo,
}: {
  clip: Clip;
  sync: ClipSync;
  onChange: (f: (s: ClipSync) => ClipSync) => void;
  now: number | null;
  ready: boolean;
  onGo: (t: number) => void;
}): JSX.Element {
  const s = useAppState();
  const firstQ = clip.stops[0]?.questions[0]?.ply ?? 1;
  const minStart = clip.timeline.fromPly === 1 ? 0 : clip.timeline.fromPly;
  const lastPly = clip.timeline.fromPly + clip.timeline.moves.length - 1;
  const range = (a: number, b: number) => Array.from({ length: Math.max(0, b - a + 1) }, (_, i) => a + i);
  const name = (p: number) => {
    if (p === 0) return 'Posición inicial';
    const m = moveAt(clip, p);
    return m ? `${m.number}${sanEs(m.san)}` : `media jugada ${p}`;
  };
  const markOf = (p: number) => sync.marks.find((m) => m.ply === p)?.at ?? null;
  const questionPlies = new Set(clip.stops.flatMap((st) => st.questions.map((q) => q.ply)));

  // Marcar una jugada: las anteriores sin marcar se ponen en el mismo segundo y el orden se mantiene.
  const setAt = (p: number, t: number) => onChange((sy) => syncSetAt(sy, p, t));
  const removeFrom = (p: number) => onChange((sy) => syncRemoveFrom(sy, p));

  const preview = syncedView(clip, sync, now ?? 0);

  return (
    <section className="vc-sync" data-sync={sync.marks.length}>
      <h3>Tablero sincronizado</h3>
      <p className="cm-quiet cm-small">
        Marca el segundo en que cada jugada aparece en el tablero del vídeo. Si una jugada no sale en cámara, márcala cuando el vídeo ya la muestre (por ejemplo, después de un corte). Las jugadas de una pregunta no
        pueden aparecer antes de su pausa.
      </p>
      <label className="vc-sync-start">
        Al empezar el clip, el tablero está{' '}
        <select
          value={sync.startPly}
          onChange={(e) => {
            const v = Number(e.target.value);
            onChange((sy) => ({ startPly: v, marks: sy.marks.filter((m) => m.ply > v) }));
          }}
        >
          {range(minStart, firstQ - 1).map((p) => (
            <option key={p} value={p}>
              {p === 0 ? 'en la posición inicial' : `tras ${name(p)}`}
            </option>
          ))}
        </select>
      </label>
      <div className="vc-marks">
        {range(sync.startPly + 1, lastPly).map((p) => {
          const at = markOf(p);
          return (
            <div className="vc-mark" key={p} data-sync-ply={p}>
              <div className="vc-mark-head">
                <span>
                  {name(p)}
                  {questionPlies.has(p) && <span className="cm-quiet"> · pregunta</span>}
                </span>
                <strong>{fmt(at)}</strong>
              </div>
              <div className="vc-mark-tools">
                <button className="cm-chip" onClick={() => now != null && setAt(p, now)} disabled={now == null}>
                  = ahora
                </button>
                {[-0.5, 0.5].map((d) => (
                  <button key={d} className="cm-chip" onClick={() => at != null && setAt(p, Math.max(0, at + d))} disabled={at == null} aria-label={`${d > 0 ? 'Sumar' : 'Restar'} medio segundo`}>
                    {d > 0 ? `+${d}` : d}
                  </button>
                ))}
                <button className="cm-chip" onClick={() => at != null && onGo(at + 2)} disabled={at == null || !ready}>
                  Ir
                </button>
                <button className="cm-chip" onClick={() => removeFrom(p)} disabled={at == null} aria-label={`Quitar ${name(p)} y las siguientes`}>
                  Quitar
                </button>
              </div>
            </div>
          );
        })}
      </div>
      {preview && (
        <div className="vc-board vc-sync-preview" data-board="preview" data-ply={preview.ply}>
          <p className="cm-kicker vc-board-label">En este segundo del vídeo · <span className="vc-san">{preview.label}</span></p>
          <Board2D fen={preview.fen} orientation={clip.orientation} interactive={false} lastMove={preview.last} animMode={s.settings.anim} coordinates={s.settings.coordinates} />
        </div>
      )}
    </section>
  );
}

/**
 * Marcado rápido: con el vídeo en marcha, un solo botón grande que se pulsa cada vez que pasa algo (empieza el clip,
 * aparece una jugada, llega el momento de la pausa, acaba). «Saltar» deja una jugada que no se ve para el siguiente
 * toque y «Deshacer» borra el último.
 */
function QuickMarker({ clip, marks, sync, now, ready, setMarks, onNote }: { clip: Clip; marks: ClipMarks; sync: ClipSync; now: number | null; ready: boolean; setMarks: (f: (m: ClipMarks) => ClipMarks) => void; onNote: (s: string) => void }): JSX.Element {
  const firstQ = clip.stops[0]?.questions[0]?.ply ?? 1;
  const minStart = clip.timeline.fromPly === 1 ? 0 : clip.timeline.fromPly;
  const setStartPly = (v: number) => setMarks((m) => ({ ...m, sync: { startPly: v, marks: (m.sync?.marks ?? []).filter((x) => x.ply > v) } }));
  const steps = useMemo(() => quickSteps(clip, sync.startPly), [clip, sync.startPly]);
  const [i, setI] = useState(0);
  // Cada toque o salto guarda cómo estaba todo antes, para que «Deshacer» lo deje exactamente igual.
  const [hist, setHist] = useState<{ i: number; marks: ClipMarks }[]>([]);
  // Si cambia la posición inicial del tablero, cambian los pasos: se empieza por el principio.
  useEffect(() => {
    setI(0);
    setHist([]);
  }, [sync.startPly]);
  const step: QuickStep | undefined = steps[i];
  const plyName = (p: number) => {
    const m = moveAt(clip, p);
    return m ? `${m.number}${sanEs(m.san)}` : `media jugada ${p}`;
  };
  const label = (st: QuickStep): string =>
    st.kind === 'start' ? 'Empieza el clip' : st.kind === 'end' ? 'Fin del clip' : st.kind === 'pause' ? `Pausa: justo antes de ${plyName(clip.stops[st.stop].questions[0].ply)}` : `Se ve ${plyName(st.ply)}`;
  const base = (m: ClipMarks): ClipSync => m.sync ?? { startPly: sync.startPly, marks: [] };

  const mark = () => {
    if (!step || now == null) return;
    const t = Math.round(now * 100) / 100;
    setMarks((m) => {
      if (step.kind === 'start') return { ...m, start: t };
      if (step.kind === 'end') return { ...m, end: t };
      if (step.kind === 'pause') return { ...m, stops: m.stops.map((x, k) => (k === step.stop ? t : x)) };
      return { ...m, sync: syncSetAt(base(m), step.ply, t) };
    });
    onNote('');
    setHist((h) => [...h, { i, marks }]);
    setI(i + 1);
  };
  const skip = () => {
    if (step?.kind !== 'ply') return;
    setHist((h) => [...h, { i, marks }]);
    setI(i + 1);
  };
  const undo = () => {
    const last = hist[hist.length - 1];
    if (!last) return;
    setMarks(() => last.marks);
    setHist((h) => h.slice(0, -1));
    setI(last.i);
  };
  const restart = () => {
    setMarks((m) => ({ ...m, start: null, end: null, stops: m.stops.map(() => null), sync: { startPly: sync.startPly, marks: [] } }));
    onNote('Marcas borradas. Vuelve al principio del vídeo y empieza de nuevo.');
    setHist([]);
    setI(0);
  };

  return (
    <section className="vc-quick" data-step={i} data-steps={steps.length}>
      <h3>Marcado rápido</h3>
      <label className="vc-sync-start">
        Al empezar el clip, el tablero está{' '}
        <select value={sync.startPly} onChange={(e) => setStartPly(Number(e.target.value))}>
          {Array.from({ length: Math.max(0, firstQ - minStart) }, (_, k) => minStart + k).map((p) => (
            <option key={p} value={p}>
              {p === 0 ? 'en la posición inicial' : `tras ${plyName(p)}`}
            </option>
          ))}
        </select>
      </label>
      <p className="cm-quiet cm-small">Reproduce el vídeo y pulsa el botón cada vez que ocurra lo que dice. La pausa, justo antes de que la mano vaya a la pieza. Si una jugada no se ve, «Saltar».</p>
      {step ? (
        <button className="cm-primary cm-big vc-quick-mark" onClick={mark} disabled={!ready || now == null}>
          {label(step)}
        </button>
      ) : (
        <p className="vc-quick-done">Hecho: todo marcado. Prueba la pausa y guarda.</p>
      )}
      <p className="cm-quiet cm-small">
        Paso {Math.min(i + 1, steps.length)} de {steps.length}
        {step && steps[i + 1] ? ` · después: ${label(steps[i + 1])}` : ''}
      </p>
      <div className="cm-row">
        <button className="cm-chip" onClick={undo} disabled={hist.length === 0}>
          Deshacer
        </button>
        <button className="cm-chip" onClick={skip} disabled={step?.kind !== 'ply'}>
          Saltar
        </button>
        <button className="cm-link cm-danger" onClick={restart}>
          Empezar de nuevo
        </button>
      </div>
    </section>
  );
}
