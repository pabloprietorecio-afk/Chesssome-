/**
 * Tablero 2D en SVG. Es el tablero de referencia: siempre disponible y siempre legible.
 * Mover: tocar pieza y destino, o arrastrar la pieza hasta el destino.
 */
import { useEffect, useMemo, useRef, useState, type JSX, type PointerEvent as RPointerEvent } from 'react';
import { Chess, type Move } from 'chess.js';
import type { BoardProps } from './boardTypes';
import { SLIDE_MS } from './boardTypes';
import { PIECE_LABEL, PieceSvg } from './pieces';
import type { PieceType } from '../core/types';

const S = 100; // tamaño de casilla en unidades SVG
const FILES = 'abcdefgh';

const LIGHT = '#e6eef8'; // casillas «cielo», a juego con el estilo WakeAgenda
const DARK = '#93a9c9';
const TONE: Record<'good' | 'bad' | 'info', string> = { good: '#1f9a52', bad: '#e5484d', info: '#7c5cfa' };

function squareXY(sq: string, orientation: 'w' | 'b'): { x: number; y: number } {
  const f = FILES.indexOf(sq[0]);
  const r = Number(sq[1]) - 1;
  return orientation === 'w' ? { x: f * S, y: (7 - r) * S } : { x: (7 - f) * S, y: r * S };
}

function squareAt(x: number, y: number, orientation: 'w' | 'b'): string | null {
  const col = Math.floor(x / S);
  const row = Math.floor(y / S);
  if (col < 0 || col > 7 || row < 0 || row > 7) return null;
  return orientation === 'w' ? FILES[col] + (8 - row) : FILES[7 - col] + (row + 1);
}

export function Board2D(props: BoardProps): JSX.Element {
  const { fen, orientation, interactive, lastMove, arrows = [], animate, animMode, coordinates, onMove, onTap } = props;
  const svgRef = useRef<SVGSVGElement>(null);
  const [selected, setSelected] = useState<string | null>(null);
  const [drag, setDrag] = useState<{ from: string; x: number; y: number } | null>(null);
  const [promo, setPromo] = useState<{ from: string; to: string } | null>(null);

  const chess = useMemo(() => new Chess(fen), [fen]);
  const legal: Move[] = useMemo(() => (interactive ? chess.moves({ verbose: true }) : []), [chess, interactive]);
  const targets = useMemo(() => new Set<string>(selected ? legal.filter((m) => m.from === selected).map((m) => m.to) : []), [legal, selected]);
  const checkSq = useMemo(() => {
    if (!chess.isCheck()) return null;
    return chess.findPiece({ type: 'k', color: chess.turn() })[0] ?? null;
  }, [chess]);

  useEffect(() => {
    setSelected(null);
    setPromo(null);
    setDrag(null);
  }, [fen, interactive]);

  const point = (e: RPointerEvent): { x: number; y: number } => {
    const svg = svgRef.current!;
    const rect = svg.getBoundingClientRect();
    return { x: ((e.clientX - rect.left) / rect.width) * 8 * S, y: ((e.clientY - rect.top) / rect.height) * 8 * S };
  };

  const tryMove = (from: string, to: string): boolean => {
    const cands = legal.filter((m) => m.from === from && m.to === to);
    if (cands.length === 0) return false;
    if (cands.some((m) => m.promotion)) {
      setPromo({ from, to });
      return true;
    }
    setSelected(null);
    onMove?.(from + to);
    return true;
  };

  const ownPieceAt = (sq: string) => {
    const p = chess.get(sq as never);
    return !!p && p.color === chess.turn();
  };

  const onPointerDown = (e: RPointerEvent) => {
    if (!interactive || promo) return;
    const { x, y } = point(e);
    const sq = squareAt(x, y, orientation);
    if (!sq) return;
    if (selected && sq !== selected && targets.has(sq)) {
      tryMove(selected, sq);
      return;
    }
    if (ownPieceAt(sq)) {
      if (selected === sq) {
        setSelected(null);
        onTap?.('deselect');
      } else {
        if (selected) onTap?.('deselect');
        setSelected(sq);
        onTap?.('select');
      }
      (e.target as Element).setPointerCapture?.(e.pointerId);
      setDrag({ from: sq, x, y });
      return;
    }
    if (selected) {
      setSelected(null);
      onTap?.('illegal');
    }
  };

  const onPointerMove = (e: RPointerEvent) => {
    if (!drag) return;
    const { x, y } = point(e);
    setDrag({ ...drag, x, y });
  };

  const onPointerUp = (e: RPointerEvent) => {
    if (!drag) return;
    const { x, y } = point(e);
    const sq = squareAt(x, y, orientation);
    const from = drag.from;
    setDrag(null);
    if (sq && sq !== from) {
      if (!tryMove(from, sq)) {
        setSelected(null);
        onTap?.('illegal');
      }
    }
  };

  // ---------- Dibujo ----------
  const squares: JSX.Element[] = [];
  for (let r = 0; r < 8; r++) {
    for (let f = 0; f < 8; f++) {
      const sq = FILES[f] + (r + 1);
      const { x, y } = squareXY(sq, orientation);
      const light = (f + r) % 2 === 1;
      squares.push(<rect key={sq} x={x} y={y} width={S} height={S} fill={light ? LIGHT : DARK} />);
    }
  }

  const highlight = (sq: string, color: string, key: string, opacity = 0.42) => {
    const { x, y } = squareXY(sq, orientation);
    return <rect key={key} x={x} y={y} width={S} height={S} fill={color} opacity={opacity} />;
  };

  const ms = SLIDE_MS[animMode];
  const pieces: JSX.Element[] = [];
  for (const row of chess.board()) {
    for (const cell of row) {
      if (!cell) continue;
      const { x, y } = squareXY(cell.square, orientation);
      const isDragged = drag && drag.from === cell.square;
      let style: React.CSSProperties | undefined;
      let k = cell.square + cell.type + cell.color;
      if (animate && ms > 0) {
        const kingCastled = chess.get(animate.to as never)?.type === 'k';
        const slideFrom = animate.to === cell.square ? animate.from : kingCastled ? castlingRookFrom(animate, cell.square, cell.type) : null;
        if (slideFrom) {
          const a = squareXY(slideFrom, orientation);
          style = {
            ['--dx' as string]: `${a.x - x}px`,
            ['--dy' as string]: `${a.y - y}px`,
            animation: `cm-slide ${ms}ms cubic-bezier(.2,.7,.2,1)`,
          };
          k += `-${animate.key}`;
        }
      }
      pieces.push(
        <g
          key={k}
          className="cm-piece"
          transform={isDragged ? `translate(${drag.x - S / 2} ${drag.y - S / 2})` : `translate(${x} ${y})`}
          style={isDragged ? { pointerEvents: 'none', opacity: 0.92 } : undefined}
          aria-label={`${PIECE_LABEL[cell.type as PieceType]} ${cell.color === 'w' ? 'blanco' : 'negro'} en ${cell.square}`}
        >
          <g style={isDragged ? undefined : style}>
            <PieceSvg type={cell.type as PieceType} color={cell.color} />
          </g>
        </g>,
      );
    }
  }

  const coords: JSX.Element[] = [];
  if (coordinates) {
    for (let i = 0; i < 8; i++) {
      const file = orientation === 'w' ? FILES[i] : FILES[7 - i];
      const rank = orientation === 'w' ? 8 - i : i + 1;
      const fileDark = (i + 7) % 2 === 1 === (orientation === 'w');
      coords.push(
        <text key={`f${i}`} x={i * S + S - 6} y={8 * S - 6} textAnchor="end" fontSize="17" fontWeight="600" fill={fileDark ? LIGHT : DARK}>
          {file}
        </text>,
      );
      coords.push(
        <text key={`r${i}`} x={6} y={i * S + 20} fontSize="17" fontWeight="600" fill={i % 2 === 0 ? DARK : LIGHT}>
          {rank}
        </text>,
      );
    }
  }

  return (
    <div className="cm-board">
      <svg
        ref={svgRef}
        viewBox={`0 0 ${8 * S} ${8 * S}`}
        role="img"
        aria-label="Tablero de ajedrez"
        onPointerDown={onPointerDown}
        onPointerMove={onPointerMove}
        onPointerUp={onPointerUp}
        style={{ touchAction: 'none', cursor: interactive ? 'pointer' : 'default' }}
      >
        <defs>
          {(['good', 'bad', 'info'] as const).map((t) => (
            <marker key={t} id={`cm-head-${t}`} viewBox="0 0 10 10" refX="5" refY="5" markerWidth="3.2" markerHeight="3.2" orient="auto">
              <path d="M0 0L10 5L0 10z" fill={TONE[t]} />
            </marker>
          ))}
        </defs>
        {squares}
        {lastMove && highlight(lastMove.from, '#ff9a2e', 'lm-f', 0.34)}
        {lastMove && highlight(lastMove.to, '#ff9a2e', 'lm-t', 0.46)}
        {selected && highlight(selected, '#7c5cfa', 'sel', 0.4)}
        {checkSq && highlight(checkSq, '#d23b2b', 'chk', 0.5)}
        {coords}
        {pieces}
        {[...targets].map((t) => {
          const { x, y } = squareXY(t, orientation);
          const occupied = !!chess.get(t as never);
          return occupied ? (
            <circle key={`t${t}`} cx={x + S / 2} cy={y + S / 2} r={S / 2 - 5} fill="none" stroke="#1b2540" strokeOpacity="0.45" strokeWidth="7" pointerEvents="none" />
          ) : (
            <circle key={`t${t}`} cx={x + S / 2} cy={y + S / 2} r={14} fill="#1b2540" fillOpacity="0.35" pointerEvents="none" />
          );
        })}
        {arrows.map((a, i) => {
          const p = squareXY(a.from, orientation);
          const q = squareXY(a.to, orientation);
          const x1 = p.x + S / 2;
          const y1 = p.y + S / 2;
          const x2 = q.x + S / 2;
          const y2 = q.y + S / 2;
          const len = Math.hypot(x2 - x1, y2 - y1) || 1;
          const shorten = 28;
          return (
            <line
              key={`a${i}`}
              x1={x1}
              y1={y1}
              x2={x2 - ((x2 - x1) / len) * shorten}
              y2={y2 - ((y2 - y1) / len) * shorten}
              stroke={TONE[a.tone]}
              strokeWidth="15"
              strokeLinecap="round"
              strokeDasharray={a.tone === 'bad' ? '26 14' : undefined}
              opacity="0.82"
              markerEnd={`url(#cm-head-${a.tone})`}
              pointerEvents="none"
            />
          );
        })}
      </svg>
      {promo && (
        <div className="cm-promo" role="dialog" aria-label="Elige la pieza de coronación">
          {(['q', 'r', 'b', 'n'] as PieceType[]).map((t) => (
            <button
              key={t}
              aria-label={PIECE_LABEL[t]}
              onClick={() => {
                const { from, to } = promo;
                setPromo(null);
                setSelected(null);
                onMove?.(from + to + t);
              }}
            >
              <svg viewBox="0 0 100 100">
                <PieceSvg type={t} color={chess.turn()} />
              </svg>
            </button>
          ))}
          <button className="cm-promo-cancel" onClick={() => setPromo(null)}>
            Cancelar
          </button>
        </div>
      )}
    </div>
  );
}

/** En un enroque también se desliza la torre. */
function castlingRookFrom(a: { from: string; to: string }, sq: string, type: string): string | null {
  if (type !== 'r') return null;
  const kingFrom = a.from;
  const rank = kingFrom[1];
  if (kingFrom[0] !== 'e' || a.to[1] !== rank) return null;
  if (a.to[0] === 'g' && sq === `f${rank}`) return `h${rank}`;
  if (a.to[0] === 'c' && sq === `d${rank}`) return `a${rank}`;
  return null;
}
