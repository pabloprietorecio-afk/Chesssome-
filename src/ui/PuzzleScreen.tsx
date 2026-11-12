/**
 * Ejecuta un problema: muestra la jugada del rival, recoge las del jugador, decide el resultado
 * y presenta el feedback de la condición que toque (explicado o solo resultado).
 */
import { useCallback, useEffect, useMemo, useRef, useState, type JSX } from 'react';
import { Chess } from 'chess.js';
import { buildLine, explain, explainSolved, isAccepted, plainFeedback, type Arrow, type Explanation } from '../core/explain';
import type { AnimMode, BoardMode, Feedback } from '../core/experiment';
import { themeName, primaryTheme } from '../core/themes';
import type { AnalyzedPuzzle } from '../core/types';
import { BoardView } from './BoardView';
import type { MoveAnim, TapKind } from './boardTypes';
import { ExplanationPanel, type BoardOverride } from './ExplanationPanel';

export interface PuzzleResult {
  correct: boolean;
  ms: number;
  firstMoveMs: number;
  misTaps: number;
  failedAt: number | null;
  played: string;
}

interface Props {
  puzzle: AnalyzedPuzzle;
  phase: 'placement' | 'training' | 'review';
  feedback: Feedback;
  board: BoardMode;
  anim: AnimMode;
  coordinates: boolean;
  startLevel: 1 | 2 | 3 | 4;
  header?: JSX.Element;
  onResult: (r: PuzzleResult) => void;
  onWhy: (level: number) => void;
  onLinePlay: () => void;
  onTap: (kind: TapKind) => void;
  onNext: () => void;
}

type Stage = 'intro' | 'solving' | 'opponent' | 'feedback';

const OPP_DELAY = 550;

const apply = (fen: string, uci: string) => {
  const c = new Chess(fen);
  const m = c.move({ from: uci.slice(0, 2), to: uci.slice(2, 4), promotion: uci[4] });
  return { fen: c.fen(), move: m };
};

export function PuzzleScreen(p: Props): JSX.Element {
  const { puzzle } = p;
  const solverColor = useMemo(() => new Chess(puzzle.points[0].fen).turn(), [puzzle]);
  const [stage, setStage] = useState<Stage>('intro');
  const [fen, setFen] = useState(puzzle.fen);
  const [lastMove, setLastMove] = useState<{ from: string; to: string } | null>(null);
  const [animate, setAnimate] = useState<MoveAnim | null>(null);
  const [point, setPoint] = useState(0);
  const [result, setResult] = useState<PuzzleResult | null>(null);
  const [override, setOverride] = useState<BoardOverride | null>(null);
  const [plainArrows, setPlainArrows] = useState<Arrow[]>([]);
  const t0 = useRef(0);
  const firstMove = useRef<number | null>(null);
  const misTaps = useRef(0);
  const animKey = useRef(1);
  const timers = useRef<number[]>([]);

  const later = (fn: () => void, ms: number) => {
    timers.current.push(window.setTimeout(fn, ms));
  };

  useEffect(() => {
    // Nuevo problema: posición inicial y, tras una pausa, la jugada del rival.
    timers.current.forEach(clearTimeout);
    timers.current = [];
    setStage('intro');
    setFen(puzzle.fen);
    setLastMove(null);
    setAnimate(null);
    setPoint(0);
    setResult(null);
    setOverride(null);
    setPlainArrows([]);
    firstMove.current = null;
    misTaps.current = 0;
    later(() => {
      const r = apply(puzzle.fen, puzzle.moves[0]);
      setFen(r.fen);
      setLastMove({ from: r.move.from, to: r.move.to });
      setAnimate({ from: r.move.from, to: r.move.to, key: animKey.current++, captured: !!r.move.captured });
      setStage('solving');
      t0.current = performance.now();
    }, OPP_DELAY);
    return () => timers.current.forEach(clearTimeout);
  }, [puzzle]);

  const finish = useCallback(
    (correct: boolean, failedAt: number | null, played: string) => {
      const now = performance.now();
      const r: PuzzleResult = {
        correct,
        ms: Math.round(now - t0.current),
        firstMoveMs: Math.round((firstMove.current ?? now) - t0.current),
        misTaps: misTaps.current,
        failedAt,
        played,
      };
      setResult(r);
      p.onResult(r);
      later(() => setStage('feedback'), correct ? 350 : 650);
    },
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [p.onResult],
  );

  const onMove = (uci: string) => {
    if (stage !== 'solving') return;
    if (firstMove.current === null) firstMove.current = performance.now();
    const pt = puzzle.points[point];
    const r = apply(pt.fen, uci);
    setFen(r.fen);
    setLastMove({ from: r.move.from, to: r.move.to });
    setAnimate({ from: r.move.from, to: r.move.to, key: animKey.current++, captured: !!r.move.captured });
    if (!isAccepted(puzzle, point, uci)) {
      setStage('opponent');
      finish(false, point, uci);
      return;
    }
    const isLast = point === puzzle.points.length - 1 || new Chess(r.fen).isGameOver();
    if (isLast) {
      setStage('opponent');
      finish(true, null, uci);
      return;
    }
    setStage('opponent');
    const reply = puzzle.moves[2 * point + 2];
    later(() => {
      const rr = apply(r.fen, reply);
      setFen(rr.fen);
      setLastMove({ from: rr.move.from, to: rr.move.to });
      setAnimate({ from: rr.move.from, to: rr.move.to, key: animKey.current++, captured: !!rr.move.captured });
      setPoint(point + 1);
      setStage('solving');
    }, OPP_DELAY);
  };

  const onTap = (k: TapKind) => {
    if (stage === 'solving' && firstMove.current === null && k !== 'select') misTaps.current++;
    p.onTap(k);
  };

  // ---------- Feedback ----------
  const explanation: Explanation | null = useMemo(() => {
    if (!result || p.feedback !== 'explained') return null;
    return result.correct ? explainSolved(puzzle) : explain(puzzle, result.failedAt ?? 0, result.played);
  }, [result, p.feedback, puzzle]);

  const plain = useMemo(() => {
    if (!result || p.feedback !== 'plain') return null;
    if (result.correct) return { correct: true, text: 'Correcto.' };
    return plainFeedback(puzzle, result.failedAt ?? 0, result.played);
  }, [result, p.feedback, puzzle]);

  const decisionFen = result ? puzzle.points[result.failedAt ?? 0].fen : fen;

  useEffect(() => {
    if (stage !== 'feedback' || !result || p.feedback !== 'plain') return;
    const pt = puzzle.points[result.failedAt ?? 0];
    const arrows: Arrow[] = result.correct ? [] : [
      { from: result.played.slice(0, 2), to: result.played.slice(2, 4), tone: 'bad' },
      { from: pt.solution.slice(0, 2), to: pt.solution.slice(2, 4), tone: 'good' },
    ];
    setPlainArrows(arrows);
    if (!result.correct) setOverride({ fen: pt.fen, lastMove: null, arrows, animate: null });
  }, [stage, result, p.feedback, puzzle]);

  const onBoard = useCallback((o: BoardOverride | null) => setOverride(o), []);

  const board = override && stage === 'feedback' ? override : { fen, lastMove, arrows: [] as Arrow[], animate };

  const solutionLine = useMemo(() => {
    const k = result?.failedAt ?? 0;
    return buildLine(puzzle.points[k].fen, puzzle.moves.slice(1 + 2 * k), 'La solución', 'good');
  }, [result, puzzle]);

  const [plainPly, setPlainPly] = useState<number | null>(null);
  useEffect(() => setPlainPly(null), [puzzle]);

  const stepPlain = (ply: number) => {
    setPlainPly(ply);
    if (ply < 0) {
      setOverride({ fen: solutionLine.startFen, lastMove: null, arrows: plainArrows, animate: null });
      return;
    }
    const pl = solutionLine.plies[ply];
    const from = pl.uci.slice(0, 2);
    const to = pl.uci.slice(2, 4);
    setOverride({ fen: pl.fenAfter, lastMove: { from, to }, arrows: [], animate: { from, to, key: animKey.current++ } });
    p.onLinePlay();
  };

  const theme = themeName(primaryTheme(puzzle.themes));

  return (
    <div className="cm-puzzle" data-puzzle-id={puzzle.id} data-point={point} data-stage={stage}>
      <div className="cm-board-wrap">
        {p.header}
        <div className={`cm-turn cm-turn-${solverColor}`}>
          {stage === 'feedback' ? (result?.correct ? 'Resuelto' : 'Fallado') : solverColor === 'w' ? 'Juegan blancas' : 'Juegan negras'}
          {stage === 'solving' && puzzle.points.length > 1 && <span className="cm-sub"> · jugada {point + 1} de {puzzle.points.length}</span>}
        </div>
        <BoardView
          mode={p.board}
          fen={board.fen}
          orientation={solverColor}
          interactive={stage === 'solving'}
          lastMove={board.lastMove}
          arrows={board.arrows}
          animate={board.animate}
          animMode={p.anim}
          coordinates={p.coordinates}
          onMove={onMove}
          onTap={onTap}
        />
      </div>
      <div className="cm-side">
        {stage !== 'feedback' && (
          <div className="cm-hint">
            <p>{stage === 'intro' ? 'Mira la jugada del rival…' : 'Encuentra la mejor jugada.'}</p>
            <p className="cm-quiet">Problema real de Lichess · rating {puzzle.rating}</p>
          </div>
        )}
        {stage === 'feedback' && explanation && (
          <>
            <ExplanationPanel
              key={`${puzzle.id}-${result?.played}`}
              exp={explanation}
              startLevel={p.startLevel}
              baseFen={decisionFen}
              onBoard={onBoard}
              onLevel={p.onWhy}
              onLinePlay={p.onLinePlay}
            />
            <p className="cm-quiet cm-meta">
              Tema: {theme} ·{' '}
              <a href={puzzle.gameUrl} target="_blank" rel="noreferrer">
                partida de origen en Lichess
              </a>
            </p>
          </>
        )}
        {stage === 'feedback' && plain && (
          <section className={`cm-explain cm-tone-${plain.correct ? 'good' : 'bad'}`}>
            <h2 className="cm-headline">{plain.text}</h2>
            <div className="cm-line cm-line-good">
              <div className="cm-line-head">
                <strong>La solución</strong>
                <span className="cm-line-text">{solutionLine.text}</span>
              </div>
              <div className="cm-stepper">
                <button onClick={() => stepPlain(-1)} aria-label="Al principio">
                  ⏮
                </button>
                <button onClick={() => stepPlain(plainPly === null ? -1 : Math.max(-1, plainPly - 1))} aria-label="Jugada anterior">
                  ◀
                </button>
                <button
                  onClick={() => stepPlain(plainPly === null ? 0 : Math.min(solutionLine.plies.length - 1, plainPly + 1))}
                  aria-label="Jugada siguiente"
                >
                  ▶
                </button>
                {plainPly !== null && plainPly >= 0 && (
                  <span className="cm-ply">
                    {plainPly + 1}/{solutionLine.plies.length} · {solutionLine.plies[plainPly].san}
                  </span>
                )}
              </div>
            </div>
            <p className="cm-quiet cm-meta">
              {p.phase !== 'placement' && <>Tema: {theme} · </>}
              <a href={puzzle.gameUrl} target="_blank" rel="noreferrer">
                partida de origen en Lichess
              </a>
            </p>
          </section>
        )}
        {stage === 'feedback' && (
          <button className="cm-primary cm-next" onClick={p.onNext} autoFocus>
            Siguiente
          </button>
        )}
      </div>
    </div>
  );
}
