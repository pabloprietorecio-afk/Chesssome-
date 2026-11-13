/**
 * «Cine de finales»: cartelera y reproductor.
 *
 * La pantalla de cine (tablero + rótulos) lleva el filtro de película antigua; los controles,
 * la pregunta y la explicación quedan fuera de esa pantalla, con el estilo normal de la app,
 * para que el efecto nunca estorbe la lectura.
 */
import { useEffect, useMemo, useRef, useState, type JSX } from 'react';
import { Chess } from 'chess.js';
import pack from '../data/cine.pack.json';
import { certificateText, frames, judgePause, type CinemaPack, type FilmPacked, type Frame, type PauseAnswer } from '../core/cinema';
import { sanEs } from '../core/lang';
import { go, log, useAppState } from '../app/store';
import { Board2D } from './Board2D';
import type { MoveAnim } from './boardTypes';

const PACK = pack as unknown as CinemaPack;

const KIND: Record<FilmPacked['kind'], string> = { technique: 'Técnica', study: 'Estudio', game: 'Partida' };

/** Tiempo de lectura de un rótulo: base más un poco por carácter. */
const readMs = (text: string) => 1600 + text.length * 55;
const MOVE_MS = 1500;

function prefersReducedMotion(): boolean {
  try {
    return window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  } catch {
    return false;
  }
}

export function CinemaScreen(): JSX.Element {
  const [open, setOpen] = useState<string | null>(null);
  const film = PACK.films.find((f) => f.id === open);
  if (film) return <Player film={film} onClose={() => setOpen(null)} />;
  return (
    <section className="cm-card">
      <p className="cm-kicker">Cine de finales</p>
      <h2>Grandes finales, como en el cine mudo</h2>
      <p className="cm-quiet">Cada película se reproduce en el tablero de la app. En los momentos clave se para y te pregunta qué jugarías.</p>
      <ul className="cine-bill">
        {PACK.films.map((f) => (
          <li key={f.id}>
            <button className="cine-poster" onClick={() => setOpen(f.id)} data-film={f.id}>
              <span className="cine-poster-kind">{KIND[f.kind]}</span>
              <span className="cine-poster-title">{f.title}</span>
              <span className="cine-poster-sub">{f.subtitle}</span>
              <span className="cine-poster-meta">
                {f.pauses.length} {f.pauses.length === 1 ? 'pausa' : 'pausas'} para pensar
              </span>
            </button>
          </li>
        ))}
      </ul>
      <button className="cm-link" onClick={() => go('home')}>
        Volver
      </button>
    </section>
  );
}

type Phase = 'playing' | 'stopped' | 'question' | 'answered' | 'end';

function Player({ film, onClose }: { film: FilmPacked; onClose: () => void }): JSX.Element {
  const s = useAppState();
  const fr = useMemo(() => frames(film), [film]);
  // idx = fotograma visible; -1 = cartel inicial.
  const [idx, setIdx] = useState(-1);
  const [phase, setPhase] = useState<Phase>('stopped');
  const [answer, setAnswer] = useState<PauseAnswer | null>(null);
  const [tryFen, setTryFen] = useState<{ fen: string; from: string; to: string } | null>(null);
  const [asked, setAsked] = useState<Set<number>>(new Set());
  const animKey = useRef(0);

  const effects = s.settings.anim === 'full' || s.settings.anim === 'fast';
  const motion = effects && !prefersReducedMotion();

  const frame: Frame | undefined = idx >= 0 ? fr[idx] : undefined;
  const next: Frame | undefined = fr[idx + 1];

  // ¿El siguiente fotograma es una jugada con pausa que aún no se ha preguntado?
  const pendingPause = next && next.kind === 'move' && next.pause && !asked.has(next.step) ? next : null;

  const advance = () => {
    if (pendingPause) {
      setPhase('question');
      setAnswer(null);
      setTryFen(null);
      log({ type: 'cine', data: { film: film.id, event: 'pause', step: pendingPause.step } });
      return;
    }
    if (idx + 1 >= fr.length) {
      setPhase('end');
      log({ type: 'cine', data: { film: film.id, event: 'end' } });
      return;
    }
    animKey.current++;
    setIdx(idx + 1);
  };

  // Reproducción automática.
  useEffect(() => {
    if (phase !== 'playing') return;
    const ms = idx < 0 ? 2200 : frame?.kind === 'title' ? readMs(frame.text) : MOVE_MS + (frame?.kind === 'move' && frame.caption ? readMs(frame.caption) - 800 : 0);
    const t = setTimeout(advance, ms);
    return () => clearTimeout(t);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [phase, idx, asked]);

  const play = () => {
    if (phase === 'end') {
      restart();
      setPhase('playing');
      return;
    }
    setPhase('playing');
    log({ type: 'cine', data: { film: film.id, event: 'play', idx } });
  };
  const stop = () => setPhase('stopped');
  const restart = () => {
    setIdx(-1);
    setAsked(new Set());
    setAnswer(null);
    setTryFen(null);
    setPhase('stopped');
  };
  const stepBack = () => {
    setPhase('stopped');
    setAnswer(null);
    setTryFen(null);
    setIdx((i) => Math.max(-1, i - 1));
  };
  const stepFwd = () => {
    if (phase === 'question' || phase === 'answered') return;
    setPhase('stopped');
    advance();
  };
  const skipToEnd = () => {
    setAsked(new Set(fr.filter((f) => f.kind === 'move' && f.pause).map((f) => f.step)));
    setIdx(fr.length - 1);
    setPhase('end');
  };

  const pauseFrame = phase === 'question' || phase === 'answered' ? (next as Extract<Frame, { kind: 'move' }> | undefined) : undefined;
  const pausePack = pauseFrame ? film.pauses.find((p) => p.step === pauseFrame.step) : undefined;

  const onMove = (uci: string) => {
    if (!pauseFrame || !pausePack || !pauseFrame.pause) return;
    const res = judgePause(pausePack, pauseFrame.before, uci, pauseFrame.pause, film.result);
    setAnswer(res);
    setPhase('answered');
    setTryFen(res.outcome === 'answer' ? null : tryPosition(pauseFrame.before, uci));
    log({ type: 'cine', data: { film: film.id, event: 'answer', step: pauseFrame.step, uci, outcome: res.outcome } });
  };
  const reveal = () => {
    if (!pauseFrame?.pause) return;
    setAnswer({ outcome: 'answer', text: pauseFrame.pause.why });
    setTryFen(null);
    setPhase('answered');
    log({ type: 'cine', data: { film: film.id, event: 'reveal', step: pauseFrame.step } });
  };
  const continueFilm = () => {
    if (!pauseFrame) return;
    setAsked((a) => new Set(a).add(pauseFrame.step));
    setAnswer(null);
    setTryFen(null);
    animKey.current++;
    setIdx(idx + 1);
    setPhase('playing');
  };

  // Qué se ve en el tablero.
  let fen = film.fen;
  let lastMove: { from: string; to: string } | null = null;
  let animate: MoveAnim | null = null;
  if (pauseFrame && tryFen) {
    fen = tryFen.fen;
    lastMove = { from: tryFen.from, to: tryFen.to };
  } else if (pauseFrame) {
    fen = pauseFrame.before;
  } else if (frame) {
    if (frame.kind === 'move') {
      fen = frame.after;
      lastMove = { from: frame.from, to: frame.to };
      animate = { from: frame.from, to: frame.to, key: animKey.current, captured: frame.captured };
    } else {
      fen = frame.fen;
    }
  }

  const intertitle = idx < 0 ? null : frame?.kind === 'title' ? frame.text : null;
  const caption = frame?.kind === 'move' && !pauseFrame ? frame.caption : undefined;
  const moveLabel = frame?.kind === 'move' && !pauseFrame ? `${frame.number} ${sanEs(frame.san)}` : '';

  return (
    <section className="cine" data-film={film.id} data-phase={phase} data-idx={idx}>
      <div className={`cine-screen ${motion ? 'cine-motion' : ''}`} aria-label={`Película: ${film.title}`}>
        <div className="cine-board">
          <Board2D
            fen={fen}
            orientation={film.orientation}
            interactive={phase === 'question'}
            lastMove={lastMove}
            animate={animate}
            animMode={s.settings.anim}
            coordinates={s.settings.coordinates}
            onMove={onMove}
          />
        </div>
        <div className="cine-grain" aria-hidden="true" />
        <div className="cine-scratches" aria-hidden="true" />
        <div className="cine-vignette" aria-hidden="true" />
        {idx < 0 && phase !== 'question' && (
          <div className="cine-card cine-card-poster" role="status">
            <span className="cine-card-kind">{KIND[film.kind]}</span>
            <strong>{film.title}</strong>
            <span>{film.subtitle}</span>
          </div>
        )}
        {intertitle && !pauseFrame && phase !== 'end' && (
          <div className="cine-card" role="status" aria-live="polite">
            <p>{intertitle}</p>
          </div>
        )}
        {phase === 'end' && (
          <div className="cine-card cine-card-end" role="status">
            <strong>FIN</strong>
          </div>
        )}
        {(caption || moveLabel) && (
          <div className="cine-sub" aria-live="polite">
            {moveLabel && <span className="cine-move">{moveLabel}</span>}
            {caption && <span>{caption}</span>}
          </div>
        )}
      </div>

      {phase === 'question' && pauseFrame?.pause && (
        <div className="cm-hint cine-ask">
          <p className="cm-kicker">Pausa para pensar</p>
          <p className="cine-question">{pauseFrame.pause.question}</p>
          <p className="cm-quiet">Haz tu jugada en el tablero.</p>
          <div className="cm-row">
            {pauseFrame.pause.hint && <HintButton text={pauseFrame.pause.hint} />}
            <button className="cm-link" onClick={reveal}>
              Ver la respuesta
            </button>
          </div>
        </div>
      )}

      {phase === 'answered' && answer && pauseFrame && (
        <div className={`cm-hint cine-answer cine-o-${answer.outcome}`}>
          <p className="cm-kicker">{OUTCOME_LABEL[answer.outcome]}</p>
          <p>{answer.text}</p>
          {answer.line && (
            <p className="cm-line-text">
              Línea del motor: {answer.line}
            </p>
          )}
          {answer.outcome !== 'answer' && pauseFrame.pause && (
            <p className="cm-quiet">
              La idea de la película: {pauseFrame.pause.why}
            </p>
          )}
          <button className="cm-primary" onClick={continueFilm}>
            Continuar la película
          </button>
        </div>
      )}

      {phase !== 'question' && phase !== 'answered' && (
        <div className="cine-controls" role="group" aria-label="Controles de la película">
          <button onClick={restart} aria-label="Volver al principio">
            ⏮
          </button>
          <button onClick={stepBack} aria-label="Jugada anterior" disabled={idx < 0}>
            ◀
          </button>
          {phase === 'playing' ? (
            <button className="cine-play" onClick={stop} aria-label="Pausar">
              ❚❚
            </button>
          ) : (
            <button className="cine-play" onClick={play} aria-label={phase === 'end' ? 'Ver otra vez' : 'Reproducir'}>
              ▶
            </button>
          )}
          <button onClick={stepFwd} aria-label="Jugada siguiente" disabled={phase === 'end'}>
            ▶❘
          </button>
          <button onClick={skipToEnd} aria-label="Saltar al final" disabled={phase === 'end'}>
            ⏭
          </button>
        </div>
      )}

      {phase === 'end' && (
        <div className="cm-hint">
          <p>{certificateText(film.certificate)}</p>
          <p className="cm-quiet">{film.credit}</p>
        </div>
      )}
      {!effects && <p className="cm-quiet cm-small">Efectos de película desactivados por el modo de animación elegido en Ajustes.</p>}
      <button className="cm-link" onClick={onClose}>
        Volver a la cartelera
      </button>
    </section>
  );
}

const OUTCOME_LABEL: Record<PauseAnswer['outcome'], string> = {
  answer: '¡Esa es!',
  'also-good': 'También vale',
  spoils: 'No es esa',
  unclear: 'Sin veredicto claro',
  unknown: 'Sin análisis',
};

function HintButton({ text }: { text: string }): JSX.Element {
  const [on, setOn] = useState(false);
  return on ? (
    <p className="cine-hint-text">{text}</p>
  ) : (
    <button className="cm-why" onClick={() => setOn(true)}>
      Pista
    </button>
  );
}

/** Posición tras la jugada del jugador, para enseñarla en el tablero mientras se lee la respuesta. */
function tryPosition(fen: string, uci: string): { fen: string; from: string; to: string } | null {
  const c = new Chess(fen);
  try {
    c.move({ from: uci.slice(0, 2), to: uci.slice(2, 4), promotion: uci[4] });
  } catch {
    return null;
  }
  return { fen: c.fen(), from: uci.slice(0, 2), to: uci.slice(2, 4) };
}
