/**
 * Piezas 2D dibujadas para Chessome (diseño propio). No se usan los juegos de piezas de Lichess
 * ni de Wikimedia, que tienen licencias con copyleft o atribución.
 * Cada pieza ocupa una caja de 100 × 100.
 */
import type { JSX } from 'react';
import type { PieceType } from '../core/types';

interface Ink {
  fill: string;
  stroke: string;
  detail: string;
}

const WHITE: Ink = { fill: '#f6f1e7', stroke: '#2a2622', detail: '#2a2622' };
const BLACK: Ink = { fill: '#2c2925', stroke: '#0f0d0b', detail: '#cfc6b6' };

const base = (k: Ink) => <path d="M27 76h46a3 3 0 0 1 3 3v6a3 3 0 0 1-3 3H27a3 3 0 0 1-3-3v-6a3 3 0 0 1 3-3z" fill={k.fill} stroke={k.stroke} strokeWidth="3" />;

const SHAPES: Record<PieceType, (k: Ink) => JSX.Element> = {
  p: (k) => (
    <g>
      <path d="M41 52h18c-1 9 2 16 9 24H32c7-8 10-15 9-24z" fill={k.fill} stroke={k.stroke} strokeWidth="3" strokeLinejoin="round" />
      <path d="M37 52c0-4 6-7 13-7s13 3 13 7z" fill={k.fill} stroke={k.stroke} strokeWidth="3" strokeLinejoin="round" />
      <circle cx="50" cy="33" r="11.5" fill={k.fill} stroke={k.stroke} strokeWidth="3" />
      {base(k)}
    </g>
  ),
  r: (k) => (
    <g>
      <path d="M30 18h9v7h6v-7h10v7h6v-7h9v20H30z" fill={k.fill} stroke={k.stroke} strokeWidth="3" strokeLinejoin="round" />
      <path d="M35 38h30l-3 30H38z" fill={k.fill} stroke={k.stroke} strokeWidth="3" strokeLinejoin="round" />
      <path d="M31 68h38v8H31z" fill={k.fill} stroke={k.stroke} strokeWidth="3" strokeLinejoin="round" />
      <path d="M38 46h24" stroke={k.detail} strokeWidth="2.5" />
      {base(k)}
    </g>
  ),
  n: (k) => (
    <g>
      <path
        d="M69 76H31c1-9 6-15 14-21l4-4c-4 0-9 1-13 4-4 3-9 2-11-2-2-5 1-9 6-13 6-5 9-11 11-18l2-8 6 6c9-1 18 3 23 12 7 12 6 30-4 44z"
        fill={k.fill}
        stroke={k.stroke}
        strokeWidth="3"
        strokeLinejoin="round"
      />
      <circle cx="43" cy="33" r="2.8" fill={k.detail} />
      <path d="M57 26c6 6 9 15 8 26" fill="none" stroke={k.detail} strokeWidth="2.5" strokeLinecap="round" />
      <path d="M27 46l4-1" stroke={k.detail} strokeWidth="2.5" strokeLinecap="round" />
      {base(k)}
    </g>
  ),
  b: (k) => (
    <g>
      <circle cx="50" cy="14" r="4.5" fill={k.fill} stroke={k.stroke} strokeWidth="3" />
      <path d="M50 19c11 9 15 21 9 32H41c-6-11-2-23 9-32z" fill={k.fill} stroke={k.stroke} strokeWidth="3" strokeLinejoin="round" />
      <path d="M55 28l-9 11" stroke={k.detail} strokeWidth="2.5" strokeLinecap="round" />
      <path d="M40 51h20v6H40z" fill={k.fill} stroke={k.stroke} strokeWidth="3" strokeLinejoin="round" />
      <path d="M42 57h16c0 8 3 14 9 19H33c6-5 9-11 9-19z" fill={k.fill} stroke={k.stroke} strokeWidth="3" strokeLinejoin="round" />
      {base(k)}
    </g>
  ),
  q: (k) => (
    <g>
      <path d="M32 64L25 34l11 15 3-23 9 21 2-25 2 25 9-21 3 23 11-15-7 30z" fill={k.fill} stroke={k.stroke} strokeWidth="3" strokeLinejoin="round" />
      <circle cx="25" cy="32" r="4" fill={k.fill} stroke={k.stroke} strokeWidth="2.5" />
      <circle cx="39" cy="24" r="4" fill={k.fill} stroke={k.stroke} strokeWidth="2.5" />
      <circle cx="50" cy="19" r="4" fill={k.fill} stroke={k.stroke} strokeWidth="2.5" />
      <circle cx="61" cy="24" r="4" fill={k.fill} stroke={k.stroke} strokeWidth="2.5" />
      <circle cx="75" cy="32" r="4" fill={k.fill} stroke={k.stroke} strokeWidth="2.5" />
      <path d="M32 64h36l2 12H30z" fill={k.fill} stroke={k.stroke} strokeWidth="3" strokeLinejoin="round" />
      <path d="M35 70h30" stroke={k.detail} strokeWidth="2.5" />
      {base(k)}
    </g>
  ),
  k: (k) => (
    <g>
      <path d="M47 7h6v7h7v6h-7v8h-6v-8h-7v-6h7z" fill={k.fill} stroke={k.stroke} strokeWidth="2.5" strokeLinejoin="round" />
      <path d="M50 30c-14 0-24 6-22 16 1 6 5 11 8 18h28c3-7 7-12 8-18 2-10-8-16-22-16z" fill={k.fill} stroke={k.stroke} strokeWidth="3" strokeLinejoin="round" />
      <path d="M50 31v32" stroke={k.detail} strokeWidth="2.5" />
      <path d="M36 64h28l3 12H33z" fill={k.fill} stroke={k.stroke} strokeWidth="3" strokeLinejoin="round" />
      {base(k)}
    </g>
  ),
};

export function PieceSvg({ type, color }: { type: PieceType; color: 'w' | 'b' }): JSX.Element {
  return SHAPES[type](color === 'w' ? WHITE : BLACK);
}

/** Nombre accesible de la pieza en español. */
export const PIECE_LABEL: Record<PieceType, string> = { p: 'peón', n: 'caballo', b: 'alfil', r: 'torre', q: 'dama', k: 'rey' };
