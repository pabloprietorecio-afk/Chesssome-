/**
 * Contrato común de los tableros. El 2D y el 3D reciben exactamente lo mismo,
 * de modo que el resto de la app no sabe cuál está pintando.
 */
import type { AnimMode } from '../core/experiment';
import type { Arrow } from '../core/explain';

export interface MoveAnim {
  from: string;
  to: string;
  /** Cambia en cada jugada para relanzar la animación aunque se repitan casillas. */
  key: number;
  captured?: boolean;
}

export type TapKind = 'select' | 'deselect' | 'illegal';

export interface BoardProps {
  fen: string;
  orientation: 'w' | 'b';
  interactive: boolean;
  lastMove?: { from: string; to: string } | null;
  arrows?: Arrow[];
  animate?: MoveAnim | null;
  animMode: AnimMode;
  coordinates: boolean;
  onMove?: (uci: string) => void;
  onTap?: (kind: TapKind) => void;
}

/** El tablero 3D se construye en su propia fase. Hasta entonces, la app usa solo el 2D y no alterna. */
export const BOARD_3D_READY = false;

/** Duración del desplazamiento de una pieza en 2D, en milisegundos. */
export const SLIDE_MS: Record<AnimMode, number> = { full: 260, fast: 150, minimal: 90, none: 0 };
