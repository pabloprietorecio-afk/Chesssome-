/**
 * Tipos compartidos por el núcleo, el pipeline y la app.
 * El núcleo (src/core) no depende del DOM ni de React: debe poder ejecutarse en Node.
 */

export type Uci = string; // "e2e4", "e7e8q"
export type Color = 'w' | 'b';
export type PieceType = 'p' | 'n' | 'b' | 'r' | 'q' | 'k';
export type Square = string; // "a1".."h8"

/** Procedencia de un conjunto de problemas. Se muestra en la app y se conserva en cada paquete de datos. */
export interface DatasetSource {
  dataset: string; // p. ej. "lichess-puzzles"
  license: string; // p. ej. "CC0-1.0"
  origin: string; // URL oficial del conjunto de datos
  via: string; // de dónde se descargó ESTA copia
  retrievedAt: string; // fecha ISO
  note?: string;
}

/** Un problema tal y como lo publica Lichess (lichess_db_puzzle.csv). */
export interface Puzzle {
  id: string;
  /** Posición ANTES de la jugada del rival (convención de Lichess). */
  fen: string;
  /** UCI. moves[0] es la jugada del rival; moves[1], moves[3]… son la solución. */
  moves: Uci[];
  rating: number;
  rd: number;
  popularity: number;
  plays: number;
  themes: string[];
  gameUrl: string;
  openingTags: string[];
}

/** Evaluación del motor desde el punto de vista del bando que mueve en la posición analizada. */
export type Score = { cp: number } | { mate: number };

/** Evaluación de UNA jugada candidata. `pv` es la continuación tras la jugada (empieza con la respuesta rival). */
export interface MoveEval {
  uci: Uci;
  score: Score;
  pv: Uci[];
}

/** Posición en la que mueve quien resuelve, con el análisis de todas sus jugadas legales. */
export interface DecisionPoint {
  index: number;
  fen: string;
  solution: Uci;
  /** Todas las jugadas legales, de mejor a peor (pasada amplia). */
  evals: MoveEval[];
  /** Las mejores jugadas con más profundidad (pasada profunda). */
  top: MoveEval[];
  /** El motor coincide con la solución publicada (en mate en 1 se acepta cualquier mate). */
  agree: boolean;
}

export interface EngineInfo {
  name: string;
  depthAll: number;
  depthTop: number;
}

export interface AnalyzedPuzzle extends Puzzle {
  points: DecisionPoint[];
  engine: EngineInfo;
  /** Todos los puntos de decisión coinciden con el motor. */
  verified: boolean;
}

/** Paquete de datos que consume la app. */
export interface PuzzlePack {
  schema: 1;
  /** true mientras el paquete sea una muestra de desarrollo y no el catálogo de producción. */
  provisional: boolean;
  label: string;
  source: DatasetSource;
  engine: EngineInfo;
  generatedAt: string;
  puzzles: PackedPuzzle[];
}

/** Formato compacto: ver src/core/pack.ts */
export interface PackedPuzzle {
  i: string; // id
  f: string; // fen
  m: string; // moves separados por espacio
  r: number; // rating
  d: number; // rd
  p: number; // popularity
  n: number; // plays
  t: string; // themes separados por espacio
  g: string; // game url
  o: string; // opening tags
  /** Un elemento por punto de decisión: [fen, solución, evals empaquetadas, top empaquetado] */
  a: [string, string, string, string][];
}
