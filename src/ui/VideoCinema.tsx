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
  syncCap,
  syncProblems,
  canAutoPause,
  direct,
  initialDirector,
  judgeAnswer,
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
  type SyncMark,
  type DirectorEvent,
  type DirectorState,
  type VideoCinePack,
} from '../core/videoCine';
import { sanEs } from '../core/lang';
import { go, log, useAppState } from '../app/store';
import { clearMarks, devFlag, loadMarks, saveMarks, setDevFlag } from '../app/clipMarks';
import { Board2D } from './Board2D';
import type { MoveAnim } from './boardTypes';
import { CinemaScreen } from './Cinema';
import { HOST_FLAG, YouTubeAdapter, embedHost, errorText } from './youtubePlayer';
import { suggestPause, suggestSync, videoTimes } from '../core/clockSync';

/** Versión publicada (la pone el flujo de GitHub Pages); en local, «local». */
const BUILD = (import.meta.env.VITE_BUILD as string | undefined) || 'local';

const PACK = pack as unknown as VideoCinePack;
const STEP_MS = 850;
const YT_TERMS = 'https://www.youtube.com/t/terms';
const GOOGLE_PRIVACY = 'https://policies.google.com/privacy';

type View = { kind: 'list' } | { kind: 'clip'; id: string } | { kind: 'editor'; id: string } | { kind: 'generated' };

/** Interruptor de desarrollo: localStorage['chessome.dev.localMarks'] = '1' deja usar marcas locales también en clips verificados. */
const LOCAL_MARKS_FLAG = 'localMarks';
/** ¿Se pueden cambiar en este dispositivo las marcas de pausa? (no, si están verificadas) */
const canEditTiming = (clip: Clip) => clip.marks !== 'verified' || devFlag(LOCAL_MARKS_FLAG);
/** ¿Hay algo que marcar? Las pausas si no están verificadas; el tablero sincronizado si el clip aún no lo trae. */
const canEditMarks = (clip: Clip) => canEditTiming(clip) || !clip.sync;

/** Clip con las marcas hechas en este dispositivo. En un clip verificado solo cuenta el tablero sincronizado local. */
function effective(clip: Clip): { clip: Clip; local: boolean } {
  const local = loadMarks(clip.id);
  if (!local) return { clip, local: false };
  if (canEditTiming(clip)) return { clip: withMarks(clip, local), local: true };
  if (!clip.sync && local.sync) return { clip: withMarks(clip, { ...marksOf(clip), sync: local.sync }), local: true };
  return { clip, local: false };
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
  const [view, setView] = useState<View>({ kind: 'list' });
  const current = view.kind === 'clip' || view.kind === 'editor' ? PACK.clips.find((c) => c.id === view.id) : undefined;
  if (view.kind === 'generated') return <CinemaScreen />;
  if (view.kind === 'clip' && current) return <ClipView key={current.id} packed={current} onClose={() => setView({ kind: 'list' })} onEdit={() => setView({ kind: 'editor', id: current.id })} />;
  if (view.kind === 'editor' && current) return <MarksEditor key={current.id} clip={current} onClose={() => setView({ kind: 'clip', id: current.id })} />;
  return (
    <section className="cm-card">
      <p className="cm-kicker">Cine de finales</p>
      <h2>Finales reales, en vídeo</h2>
      <p className="cm-quiet">El vídeo se para solo justo antes de la jugada clave y te pregunta qué jugarías. Después ves lo que pasó de verdad.</p>
      <ul className="vc-bill">
        {PACK.clips.map((c) => {
          const e = effective(c);
          const auto = canAutoPause(e.clip);
          return (
            <li key={c.id}>
              <button className="vc-card" onClick={() => setView({ kind: 'clip', id: c.id })} data-clip={c.id}>
                <span className="vc-card-year">{c.year}</span>
                <span className="vc-card-title">{c.title}</span>
                <span className="vc-card-sub">{c.subtitle}</span>
                <span className="vc-card-meta">
                  Vídeo: {c.video.channel} · YouTube · {c.stops.reduce((n, s) => n + s.questions.length, 0)} preguntas
                </span>
                <span className={`vc-chip ${auto ? 'vc-chip-on' : ''}`}>{auto ? (e.local ? 'Pausa automática · marcas de este dispositivo' : c.marks === 'pending' ? 'Pausa automática · marcas estimadas' : 'Pausa automática') : 'Pausa sin marcar · directo a la pregunta'}</span>
              </button>
            </li>
          );
        })}
      </ul>
      <p className="cm-quiet cm-small">
        Los vídeos se ven con el reproductor de YouTube, desde el canal oficial de quien los grabó. Chessome no los descarga ni los modifica.
      </p>
      {devFlag('generatedFilms') && (
        <button className="cm-link" onClick={() => setView({ kind: 'generated' })}>
          Películas generadas (aparcadas)
        </button>
      )}
      <button className="cm-link" onClick={() => go('home')}>
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
  return { st, send, player, blocked, playing, time, now };
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
};

function ClipView({ packed, onClose, onEdit }: { packed: Clip; onClose: () => void; onEdit: () => void }): JSX.Element {
  const s = useAppState();
  const { clip, local } = useMemo(() => effective(packed), [packed]);
  const auto = canAutoPause(clip);
  const mount = useRef<HTMLDivElement>(null);
  const videoBox = useRef<HTMLDivElement>(null);
  const askBox = useRef<HTMLDivElement>(null);
  const { st, send, player, blocked, playing, time, now } = useDirector(clip, mount);

  const [qi, setQi] = useState(0);
  const [answer, setAnswer] = useState<ClipAnswer | null>(null);
  const [hint, setHint] = useState(false);
  const [board, setBoard] = useState<BoardState | null>(null);
  const [busy, setBusy] = useState(false);
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
    // Vídeo arriba, pregunta debajo y tablero a continuación: lo que hace falta ver al pararse.
    window.setTimeout(() => (st.videoOn ? videoBox.current : askBox.current)?.scrollIntoView({ behavior: 'smooth', block: 'start' }), 60);
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

  const showAnswer = () => {
    if (!q || answer) return;
    setAnswer({ outcome: 'answer', text: q.why });
    showPlayed(q, true);
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

  const reveal = async () => {
    if (!stop || !lastQ) return;
    clearTimers();
    setBusy(false);
    showPlayed(lastQ, false);
    ev('reveal', { stop: st.stop, answered: qi + (answer ? 1 : 0), of: totalQuestions });
    await ensureVisible(videoBox.current);
    send({ type: 'reveal', time: time() });
  };

  const start = (mode: 'film' | 'direct' | 'free') => {
    clearTimers();
    setBoard(null);
    setAnswer(null);
    ev('start', { mode, auto });
    send({ type: 'start', mode });
  };

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
  const shown = synced ? { fen: synced.fen, last: synced.last, anim: syncedAnim } : board;

  // Mientras se ve o se responde, la cabecera y el crédito se encogen para que vídeo, pregunta y tablero quepan en un móvil.
  const compact = st.phase === 'watching' || st.phase === 'asking' || st.phase === 'reveal';
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
      {compact ? (
        <p className="cm-kicker vc-compact-head">{clip.subtitle}</p>
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
      {videoCredit}

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
          {!local && auto && clip.marks === 'pending' && <p className="cm-quiet cm-small">Marcas estimadas con los relojes de la partida, sin comprobar aún en el vídeo.</p>}
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

      {st.phase === 'watching' && (
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

      {st.phase === 'asking' && q && !answer && (
        <div className="cm-hint vc-panel vc-ask" ref={askBox}>
          <p className="cm-kicker">
            {st.videoOn ? 'Vídeo en pausa' : 'Antes del vídeo'} · pregunta {qi + 1} de {totalQuestions}
          </p>
          {busy ? <p className="cm-quiet">Así siguió la partida…</p> : <p className="vc-question">{q.question}</p>}
          {!busy && (
            <>
              <p className="cm-quiet">Haz tu jugada en el tablero.</p>
              <div className="cm-row">
                {q.hint && (hint ? <p className="vc-hint">{q.hint}</p> : <button className="cm-why" onClick={() => setHint(true)}>Pista</button>)}
                <button className="cm-link" onClick={showAnswer}>
                  Ver la respuesta
                </button>
              </div>
            </>
          )}
          <SkipLink errored={st.errorCode != null} videoOn={st.videoOn} onReveal={reveal} onFinish={() => send({ type: 'finish' })} />
        </div>
      )}

      {st.phase === 'asking' && q && answer && (
        <div className={`cm-hint vc-panel vc-answer vc-o-${answer.outcome}`}>
          <p className="cm-kicker">{OUTCOME_LABEL[answer.outcome]}</p>
          <p>{answer.text}</p>
          {answer.line && <p className="cm-line-text">Línea del motor: {answer.line}</p>}
          {answer.outcome !== 'answer' && q.playedCls === 'keeps' && <p className="cm-quiet">En la partida: {q.why}</p>}
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
          {qi + 1 < totalQuestions && <SkipLink errored={st.errorCode != null} videoOn={st.videoOn} onReveal={reveal} onFinish={() => send({ type: 'finish' })} />}
        </div>
      )}

      {shown && st.phase !== 'idle' && (
        <div className="vc-board" data-board={synced ? 'video' : 'question'} data-ply={synced?.ply ?? ''}>
          {synced && <p className="cm-kicker vc-board-label">Tablero del vídeo · <span className="vc-san">{synced.label}</span></p>}
          <Board2D
            fen={shown.fen}
            orientation={clip.orientation}
            interactive={st.phase === 'asking' && !answer && !busy}
            lastMove={shown.last}
            animate={shown.anim}
            animMode={s.settings.anim}
            coordinates={s.settings.coordinates}
            onMove={onMove}
          />
        </div>
      )}

      {st.phase === 'reveal' && (
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
              {playing && <p>En la partida se jugó {lastSan}. {hasSyncMarks ? 'El tablero de abajo sigue al vídeo.' : 'Mira cómo ocurrió.'}</p>}
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

      {st.phase === 'ended' && (
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
            <button className="cm-why" onClick={() => start(auto && st.errorCode == null ? 'film' : 'direct')}>
              Otra vez
            </button>
          </div>
        </div>
      )}

      <div className="cm-row vc-foot">
        <button className="cm-link" onClick={onClose}>
          Volver a la cartelera
        </button>
        {canEditMarks(packed) && (
          <button className="cm-link" onClick={onEdit}>
            Editor de marcas
          </button>
        )}
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
  const [marks, setMarks] = useState<ClipMarks>(() => loadMarks(clip.id) ?? marksOf(clip));
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
            const ok = saveMarks(clip.id, marks);
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
  const setAt = (p: number, t: number) =>
    onChange((sy) => {
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
    });
  const removeFrom = (p: number) => onChange((sy) => ({ ...sy, marks: sy.marks.filter((m) => m.ply < p) }));

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
