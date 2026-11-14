/**
 * Curso «Aprende a jugar»: desde no saber mover las piezas hasta el jaque mate y las reglas especiales.
 *
 * Contenido propio de Chessome (textos y posiciones). Cada ejercicio se comprueba con las reglas del ajedrez al
 * exportarlo (scripts/export-course.ts): que se pueda resolver, cuál es el mínimo de jugadas y qué jugadas valen.
 * Un ejercicio mal planteado hace fallar la exportación y los tests.
 *
 * Tipos de ejercicio:
 *   info     solo texto sobre una posición (sin jugar)
 *   collect  una pieza (el «héroe») recorre el tablero: recoge estrellas y captura las piezas negras, que no se
 *            mueven. El turno vuelve siempre a blancas. Con `safe`, no se puede acabar en una casilla atacada por
 *            una pieza negra (te la capturarían)
 *   move     una jugada en una posición de verdad; `accept` dice cuáles valen (jaque, mate, enroque…)
 *
 * Las posiciones se escriben pieza a pieza (`pos`), no en FEN, para que se lean y no haya errores de cuenta.
 */

export type Accept =
  | { kind: 'check' }
  | { kind: 'mate' }
  | { kind: 'castle'; side: 'k' | 'q' }
  | { kind: 'enPassant' }
  | { kind: 'promote' }
  | { kind: 'mostValuable' }
  /** Salir del jaque de una manera concreta: la posición solo permite esa (se comprueba). */
  | { kind: 'escape'; way: 'king' | 'capture' | 'block' };

export interface Placement {
  /** Piezas blancas y negras: { R: ['a1'], P: ['e2', 'f2'] } (mayúsculas blancas, minúsculas negras). */
  pieces: Record<string, string[]>;
  turn?: 'w' | 'b';
  castling?: string;
  ep?: string;
}

/** Origen de una posición sacada de una partida real (problema de Lichess, CC0). */
export interface Source {
  id: string;
  game: string;
}

/** `fen`, si está, manda sobre `at` (posiciones de partidas reales, que no se escriben pieza a pieza). */
export type Exercise =
  | { kind: 'info'; at: Placement; fen?: string; text: string }
  | { kind: 'collect'; at: Placement; fen?: string; hero: string; stars?: string[]; safe?: boolean; text: string }
  | { kind: 'move'; at: Placement; fen?: string; accept: Accept; text: string; source?: Source };

export interface Lesson {
  id: string;
  title: string;
  /** Icono del atlas de la app (godot/ui/iconos.json). */
  icon: string;
  intro: string[];
  exercises: Exercise[];
  /** Lo que se lleva el jugador al terminar (una frase). */
  takeaway: string;
}

export interface Unit {
  id: string;
  title: string;
  lessons: Lesson[];
}

const at = (pieces: Record<string, string[]>, extra: Omit<Placement, 'pieces'> = {}): Placement => ({ pieces, ...extra });

export const START: Placement = at({
  R: ['a1', 'h1'], N: ['b1', 'g1'], B: ['c1', 'f1'], Q: ['d1'], K: ['e1'],
  P: ['a2', 'b2', 'c2', 'd2', 'e2', 'f2', 'g2', 'h2'],
  r: ['a8', 'h8'], n: ['b8', 'g8'], b: ['c8', 'f8'], q: ['d8'], k: ['e8'],
  p: ['a7', 'b7', 'c7', 'd7', 'e7', 'f7', 'g7', 'h7'],
}, { castling: 'KQkq' });

export const COURSE: Unit[] = [
  {
    id: 'piezas',
    title: 'Cómo se mueven las piezas',
    lessons: [
      {
        id: 'tablero',
        title: 'El tablero',
        icon: 'piece_pawn',
        intro: [
          'El ajedrez se juega en un tablero de 8 × 8 casillas, claras y oscuras.',
          'Juegan dos: blancas y negras. Empiezan siempre las blancas y después se mueve por turnos, una jugada cada uno.',
        ],
        exercises: [
          {
            kind: 'info',
            at: START,
            text: 'Así empieza una partida. Cada bando tiene 16 piezas: 8 peones, 2 torres, 2 caballos, 2 alfiles, una dama y un rey. La casilla de la esquina derecha, junto a ti, es siempre clara.',
          },
          {
            kind: 'info',
            at: START,
            text: 'Las filas van del 1 al 8 y las columnas de la «a» a la «h». Así cada casilla tiene un nombre: el rey blanco está en e1 y la dama negra en d8.',
          },
        ],
        takeaway: 'Cada casilla tiene nombre: una letra y un número.',
      },
      {
        id: 'torre',
        title: 'La torre',
        icon: 'piece_rook',
        intro: ['La torre se mueve en línea recta: hacia delante, hacia atrás y a los lados, tantas casillas como quieras.', 'No puede saltar por encima de otras piezas.'],
        exercises: [
          { kind: 'collect', at: at({ R: ['a1'] }), hero: 'a1', stars: ['a6'], text: 'Lleva la torre hasta la estrella.' },
          { kind: 'collect', at: at({ R: ['a1'] }), hero: 'a1', stars: ['a6', 'f6'], text: 'Recoge las dos estrellas.' },
          { kind: 'collect', at: at({ R: ['d4'] }), hero: 'd4', stars: ['d8', 'h8', 'h1'], text: 'Recoge las tres estrellas.' },
          { kind: 'collect', at: at({ R: ['a1'], P: ['a4', 'c3'] }), hero: 'a1', stars: ['a8', 'c8'], text: 'Tus peones estorban: la torre no puede saltar por encima.' },
        ],
        takeaway: 'La torre: líneas rectas, sin saltar.',
      },
      {
        id: 'alfil',
        title: 'El alfil',
        icon: 'piece_bishop',
        intro: ['El alfil se mueve en diagonal, tantas casillas como quieras.', 'Por eso se queda siempre en casillas del mismo color.'],
        exercises: [
          { kind: 'collect', at: at({ B: ['c1'] }), hero: 'c1', stars: ['g5'], text: 'Lleva el alfil hasta la estrella.' },
          { kind: 'collect', at: at({ B: ['c1'] }), hero: 'c1', stars: ['f4', 'b8'], text: 'Recoge las dos estrellas.' },
          { kind: 'collect', at: at({ B: ['f1'] }), hero: 'f1', stars: ['b5', 'e8', 'h5'], text: 'Este alfil va por casillas claras. Recoge las tres estrellas.' },
          { kind: 'collect', at: at({ B: ['c1'], P: ['d2'] }), hero: 'c1', stars: ['h6'], text: 'Tu peón le tapa el camino directo. Busca otro.' },
        ],
        takeaway: 'El alfil: diagonales, siempre del mismo color.',
      },
      {
        id: 'dama',
        title: 'La dama',
        icon: 'piece_queen',
        intro: ['La dama es la pieza más fuerte: se mueve como la torre y como el alfil a la vez.', 'En línea recta o en diagonal, tantas casillas como quieras.'],
        exercises: [
          { kind: 'collect', at: at({ Q: ['d1'] }), hero: 'd1', stars: ['d6', 'h2'], text: 'Recoge las dos estrellas.' },
          { kind: 'collect', at: at({ Q: ['a1'] }), hero: 'a1', stars: ['h8', 'h1', 'a8'], text: 'Recoge las tres estrellas.' },
          { kind: 'collect', at: at({ Q: ['e4'] }), hero: 'e4', stars: ['b7', 'g6', 'c2', 'h3'], text: 'Recoge las cuatro estrellas en las menos jugadas posibles.' },
        ],
        takeaway: 'La dama: como la torre y como el alfil.',
      },
      {
        id: 'rey',
        title: 'El rey',
        icon: 'piece_king',
        intro: ['El rey es la pieza más importante, pero se mueve poco: una sola casilla, en cualquier dirección.'],
        exercises: [
          { kind: 'collect', at: at({ K: ['e1'] }), hero: 'e1', stars: ['e3'], text: 'Lleva el rey hasta la estrella.' },
          { kind: 'collect', at: at({ K: ['d4'] }), hero: 'd4', stars: ['d5', 'e5'], text: 'Recoge las dos estrellas, una casilla cada vez.' },
          { kind: 'collect', at: at({ K: ['a1'] }), hero: 'a1', stars: ['c3', 'e3'], text: 'Recoge las dos estrellas. En diagonal también se avanza.' },
        ],
        takeaway: 'El rey: una casilla en cualquier dirección.',
      },
      {
        id: 'caballo',
        title: 'El caballo',
        icon: 'piece_knight',
        intro: ['El caballo salta en forma de L: dos casillas en una dirección y una hacia el lado.', 'Es la única pieza que salta por encima de las demás.'],
        exercises: [
          { kind: 'collect', at: at({ N: ['b1'] }), hero: 'b1', stars: ['c3'], text: 'Lleva el caballo hasta la estrella.' },
          { kind: 'collect', at: at({ N: ['b1'] }), hero: 'b1', stars: ['d2', 'f3'], text: 'Recoge las dos estrellas.' },
          { kind: 'collect', at: at({ N: ['b1'], P: ['a2', 'b2', 'c2', 'd2'] }), hero: 'b1', stars: ['c3', 'e4'], text: 'El caballo salta por encima de tus peones.' },
          { kind: 'collect', at: at({ N: ['g1'] }), hero: 'g1', stars: ['f3', 'g5', 'e6'], text: 'Recoge las tres estrellas.' },
        ],
        takeaway: 'El caballo: salta en L.',
      },
      {
        id: 'peon',
        title: 'El peón',
        icon: 'piece_pawn',
        intro: [
          'El peón avanza recto, una casilla. Desde su casilla de salida puede avanzar dos de golpe.',
          'Nunca retrocede. Y captura de forma distinta a como avanza: en diagonal, una casilla hacia delante.',
        ],
        exercises: [
          { kind: 'collect', at: at({ P: ['e2'] }), hero: 'e2', stars: ['e4'], text: 'Desde su casilla de salida, el peón puede avanzar dos. Hazlo de una vez.' },
          { kind: 'collect', at: at({ P: ['e2'] }), hero: 'e2', stars: ['e4', 'e6'], text: 'Recoge las dos estrellas.' },
          { kind: 'collect', at: at({ P: ['e4'], n: ['d5'], r: ['c6'] }), hero: 'e4', text: 'Captura las dos piezas negras: el peón captura en diagonal.' },
          { kind: 'collect', at: at({ P: ['d2'], b: ['c3', 'd4'], n: ['e5'] }), hero: 'd2', text: 'Captura las tres piezas. Fíjate en qué casillas puede capturar el peón.' },
        ],
        takeaway: 'El peón avanza recto y captura en diagonal.',
      },
    ],
  },
  {
    id: 'capturar',
    title: 'Capturar',
    lessons: [
      {
        id: 'capturar',
        title: 'Capturar piezas',
        icon: 'target',
        intro: ['Capturar es mover tu pieza a la casilla de una pieza rival: la quitas del tablero y ocupas su sitio.', 'Cada pieza captura igual que se mueve (menos el peón, que captura en diagonal).'],
        exercises: [
          { kind: 'collect', at: at({ R: ['a1'], p: ['a6'], n: ['f6'] }), hero: 'a1', text: 'Captura las dos piezas negras con la torre.' },
          { kind: 'collect', at: at({ B: ['c1'], p: ['f4', 'b8', 'd6'] }), hero: 'c1', text: 'Captura las tres piezas con el alfil.' },
          { kind: 'collect', at: at({ N: ['b1'], p: ['c3', 'e4', 'f6'] }), hero: 'b1', text: 'Captura las tres piezas con el caballo.' },
          { kind: 'collect', at: at({ Q: ['d1'], p: ['d7', 'a4', 'h5', 'g2'] }), hero: 'd1', text: 'Captura las cuatro piezas con la dama, en las menos jugadas posibles.' },
        ],
        takeaway: 'Capturar es ocupar la casilla de una pieza rival.',
      },
      {
        id: 'a-salvo',
        title: 'Captura sin que te capturen',
        icon: 'eye',
        intro: [
          'Las piezas negras también atacan. Si terminas en una casilla que ataca una pieza rival, te la capturan.',
          'Antes de mover, mira qué casillas atacan sus piezas.',
        ],
        exercises: [
          { kind: 'collect', at: at({ R: ['a1'], n: ['a6'], p: ['b7'] }), hero: 'a1', safe: true, text: 'Captura las dos piezas sin acabar en una casilla atacada. ¿Por cuál empiezas?' },
          { kind: 'collect', at: at({ Q: ['d1'], n: ['d5'], p: ['e6'] }), hero: 'd1', safe: true, text: 'El peón protege al caballo. Captura los dos sin que te capturen la dama.' },
          { kind: 'collect', at: at({ R: ['h1'], p: ['c6', 'd5'], b: ['h7'] }), hero: 'h1', safe: true, text: 'Captura las tres piezas. Cuidado con los peones: capturan en diagonal hacia abajo.' },
        ],
        takeaway: 'Antes de mover, mira qué ataca el rival.',
      },
      {
        id: 'valor',
        title: 'Lo que vale cada pieza',
        icon: 'chart',
        intro: [
          'No todas las piezas valen lo mismo. Como guía: peón 1, caballo 3, alfil 3, torre 5 y dama 9.',
          'El rey no tiene valor: no se puede capturar. Perderlo es perder la partida.',
        ],
        exercises: [
          { kind: 'move', at: at({ Q: ['d4'], K: ['h1'], k: ['h8'], p: ['d6'], n: ['b6'], r: ['g7'] }), accept: { kind: 'mostValuable' }, text: 'Puedes capturar tres piezas. Captura la que más vale.' },
          { kind: 'move', at: at({ N: ['e4'], K: ['a1'], k: ['h8'], p: ['c5'], b: ['d6'], q: ['f6'] }), accept: { kind: 'mostValuable' }, text: 'El caballo puede capturar tres piezas. ¿Cuál te llevas?' },
          { kind: 'move', at: at({ P: ['e4'], K: ['a1'], k: ['h8'], n: ['d5'], r: ['f5'] }), accept: { kind: 'mostValuable' }, text: 'El peón puede capturar a los dos lados. Elige bien.' },
        ],
        takeaway: 'Peón 1, caballo y alfil 3, torre 5, dama 9.',
      },
    ],
  },
  {
    id: 'jaque',
    title: 'Jaque y jaque mate',
    lessons: [
      {
        id: 'jaque',
        title: 'El jaque',
        icon: 'target',
        intro: ['Dar jaque es atacar al rey rival. Quien recibe jaque está obligado a salir de él en su siguiente jugada.'],
        exercises: [
          { kind: 'move', at: at({ K: ['g1'], R: ['a1'], k: ['e8'], p: ['d7', 'e7', 'f7'] }), accept: { kind: 'check' }, text: 'Da jaque al rey negro con la torre.' },
          { kind: 'move', at: at({ K: ['g1'], B: ['f1'], k: ['e8'], p: ['e7', 'f7'] }), accept: { kind: 'check' }, text: 'Da jaque con el alfil.' },
          { kind: 'move', at: at({ K: ['g1'], N: ['e4'], k: ['e8'], p: ['e7'] }), accept: { kind: 'check' }, text: 'Da jaque con el caballo.' },
        ],
        takeaway: 'Jaque: atacar al rey.',
      },
      {
        id: 'salir-jaque',
        title: 'Salir del jaque',
        icon: 'eye',
        intro: ['Hay tres maneras de salir del jaque: mover el rey, capturar la pieza que da jaque o poner una pieza en medio.', 'Si no hay ninguna, es jaque mate.'],
        exercises: [
          { kind: 'move', at: at({ K: ['e1'], P: ['d2', 'f2'], k: ['e8'], r: ['a1'] }), accept: { kind: 'escape', way: 'king' }, text: 'Tu rey está en jaque. Aquí solo puedes salir moviendo el rey.' },
          { kind: 'move', at: at({ K: ['h1'], P: ['g2', 'h2'], R: ['a1'], k: ['e8'], r: ['e1'] }), accept: { kind: 'escape', way: 'capture' }, text: 'Jaque otra vez. Ahora la salida es capturar la pieza que lo da.' },
          { kind: 'move', at: at({ K: ['h1'], P: ['g2', 'h2'], B: ['d3'], k: ['e8'], r: ['e1'] }), accept: { kind: 'escape', way: 'block' }, text: 'Y ahora, pon una pieza en medio.' },
        ],
        takeaway: 'Del jaque se sale moviendo el rey, capturando o tapando.',
      },
      {
        id: 'mate',
        title: 'El jaque mate',
        icon: 'flag',
        intro: ['Jaque mate es un jaque del que no se puede salir. Quien da jaque mate gana la partida.'],
        exercises: [
          { kind: 'move', at: at({ K: ['g1'], R: ['a1'], k: ['g8'], p: ['f7', 'g7', 'h7'] }), accept: { kind: 'mate' }, text: 'Da jaque mate en una jugada. Los peones negros encierran a su rey.' },
          { kind: 'move', at: at({ K: ['e6'], Q: ['a7'], k: ['e8'] }), accept: { kind: 'mate' }, text: 'Da jaque mate con la dama. Tu rey la ayuda.' },
          { kind: 'move', at: at({ K: ['a1'], N: ['g5'], k: ['h8'], r: ['g8'], p: ['g7', 'h7'] }), accept: { kind: 'mate' }, text: 'Da jaque mate con el caballo: las piezas negras no dejan escapar a su rey.' },
          { kind: 'move', at: at({ K: ['g6'], R: ['a2'], k: ['h8'] }), accept: { kind: 'mate' }, text: 'Da jaque mate con la torre.' },
        ],
        takeaway: 'Jaque mate: un jaque sin salida. Gana la partida.',
      },
      {
        id: 'ahogado',
        title: 'El ahogado',
        icon: 'info',
        intro: ['Si el bando que mueve no está en jaque pero no tiene ninguna jugada posible, es ahogado: la partida acaba en tablas, empate.', 'Cuando vas ganando, cuidado con ahogar al rival.'],
        exercises: [
          { kind: 'move', at: at({ K: ['g6'], Q: ['f1'], k: ['h8'] }), accept: { kind: 'mate' }, text: 'Da jaque mate. Ojo: alguna jugada deja al rey negro sin movimientos y sin jaque.' },
          { kind: 'move', at: at({ K: ['c6'], Q: ['b1'], k: ['a8'] }), accept: { kind: 'mate' }, text: 'Otra vez: jaque mate, no ahogado.' },
        ],
        takeaway: 'Sin jaque y sin jugadas: ahogado, tablas.',
      },
    ],
  },
  {
    id: 'especiales',
    title: 'Jugadas especiales',
    lessons: [
      {
        id: 'enroque',
        title: 'El enroque',
        icon: 'piece_king',
        intro: [
          'El enroque mueve dos piezas a la vez: el rey va dos casillas hacia una torre y la torre salta al otro lado del rey.',
          'Solo se puede si ni el rey ni esa torre se han movido, no hay piezas entre ellos, y el rey no está en jaque ni pasa por una casilla atacada.',
          'Para enrocar, mueve el rey dos casillas.',
        ],
        exercises: [
          { kind: 'move', at: at({ K: ['e1'], R: ['a1', 'h1'], P: ['f2', 'g2', 'h2'], k: ['e8'] }, { castling: 'KQ' }), accept: { kind: 'castle', side: 'k' }, text: 'Enroca hacia el lado del rey (enroque corto).' },
          { kind: 'move', at: at({ K: ['e1'], R: ['a1', 'h1'], P: ['a2', 'b2', 'c2'], k: ['e8'] }, { castling: 'KQ' }), accept: { kind: 'castle', side: 'q' }, text: 'Ahora enroca hacia el lado de la dama (enroque largo).' },
        ],
        takeaway: 'Enrocar: el rey dos casillas, la torre al otro lado.',
      },
      {
        id: 'coronar',
        title: 'Coronar',
        icon: 'piece_queen',
        intro: ['Cuando un peón llega a la última fila se convierte en la pieza que elijas, menos rey. Casi siempre, en dama.'],
        exercises: [
          { kind: 'move', at: at({ P: ['e7'], K: ['a1'], k: ['h3'] }), accept: { kind: 'promote' }, text: 'Lleva el peón a la última fila y conviértelo en dama.' },
          { kind: 'move', at: at({ P: ['b7'], K: ['h1'], k: ['h8'], r: ['a8'], n: ['b8'] }), accept: { kind: 'promote' }, text: 'Captura y corona a la vez.' },
        ],
        takeaway: 'Un peón que llega al final se convierte en dama.',
      },
      {
        id: 'al-paso',
        title: 'La captura al paso',
        icon: 'piece_pawn',
        intro: [
          'Si un peón rival avanza dos casillas y se queda justo al lado de tu peón, puedes capturarlo como si hubiera avanzado solo una.',
          'Solo vale en la jugada siguiente: después ya no.',
        ],
        exercises: [
          { kind: 'move', at: at({ P: ['e5'], K: ['e1'], k: ['e8'], p: ['d5'] }, { ep: 'd6' }), accept: { kind: 'enPassant' }, text: 'El peón negro acaba de avanzar de d7 a d5. Captúralo al paso.' },
          { kind: 'move', at: at({ P: ['b5'], K: ['e1'], k: ['e8'], p: ['c5', 'h6'] }, { ep: 'c6' }), accept: { kind: 'enPassant' }, text: 'El peón negro acaba de llegar a c5 desde c7. Aprovecha.' },
        ],
        takeaway: 'Al paso: solo justo después del avance doble.',
      },
    ],
  },
];

/** FEN de una colocación. */
export function toFen(p: Placement): string {
  const board: string[][] = Array.from({ length: 8 }, () => Array(8).fill(''));
  for (const [piece, squares] of Object.entries(p.pieces)) {
    for (const sq of squares) {
      const f = sq.charCodeAt(0) - 97;
      const r = Number(sq[1]) - 1;
      if (f < 0 || f > 7 || r < 0 || r > 7 || sq.length !== 2) throw new Error(`Casilla mal escrita: ${sq}`);
      if (board[r][f]) throw new Error(`Dos piezas en ${sq}`);
      board[r][f] = piece;
    }
  }
  const rows: string[] = [];
  for (let r = 7; r >= 0; r--) {
    let row = '';
    let empty = 0;
    for (let f = 0; f < 8; f++) {
      if (board[r][f]) {
        if (empty) row += empty;
        empty = 0;
        row += board[r][f];
      } else empty++;
    }
    if (empty) row += empty;
    rows.push(row);
  }
  return `${rows.join('/')} ${p.turn ?? 'w'} ${p.castling || '-'} ${p.ep ?? '-'} 0 1`;
}
