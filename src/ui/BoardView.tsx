/**
 * Elige el tablero según el modo. El 3D se carga aparte para que el 2D no pague su peso.
 */
import { Suspense, lazy, type JSX } from 'react';
import type { BoardMode } from '../core/experiment';
import { Board2D } from './Board2D';
import type { BoardProps } from './boardTypes';

const Board3D = lazy(() => import('./Board3D'));

export function BoardView({ mode, ...props }: BoardProps & { mode: BoardMode }): JSX.Element {
  if (mode === '3d') {
    return (
      <Suspense fallback={<Board2D {...props} />}>
        <Board3D {...props} />
      </Suspense>
    );
  }
  return <Board2D {...props} />;
}
