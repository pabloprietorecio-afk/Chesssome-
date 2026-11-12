/**
 * PROVISIONAL. El tablero 3D se implementa en la fase 3D del proyecto.
 * Mientras tanto se muestra el tablero 2D con un aviso, para que el resto de la app funcione.
 */
import type { JSX } from 'react';
import { Board2D } from './Board2D';
import type { BoardProps } from './boardTypes';

export default function Board3D(props: BoardProps): JSX.Element {
  return (
    <div className="cm-3d-pending">
      <Board2D {...props} />
      <p className="cm-note">Tablero 3D en construcción: de momento se muestra el 2D.</p>
    </div>
  );
}
