/**
 * Temas de los problemas. Las CLAVES son las de la base de problemas de Lichess (CC0).
 * Los nombres y definiciones en español están redactados para Chessome: no se han copiado
 * los textos de Lichess, que forman parte de lila (AGPL).
 *
 * `review: true` marca definiciones que debe validar un entrenador antes de producción.
 */

export type ThemeKind = 'motif' | 'mate' | 'phase' | 'endgame' | 'length' | 'goal' | 'origin';

export interface ThemeInfo {
  name: string;
  kind: ThemeKind;
  /** Definición breve, en una o dos frases, para el nivel "concepto". */
  def?: string;
  review?: boolean;
}

export const THEMES: Record<string, ThemeInfo> = {
  // --- Motivos tácticos ---
  fork: {
    name: 'Ataque doble',
    kind: 'motif',
    def: 'Una sola pieza ataca dos objetivos a la vez. El rival solo puede salvar uno.',
  },
  pin: {
    name: 'Clavada',
    kind: 'motif',
    def: 'Una pieza no puede moverse, o no le conviene, porque dejaría a tiro a otra más valiosa que tiene detrás.',
  },
  skewer: {
    name: 'Ataque a través (enfilada)',
    kind: 'motif',
    def: 'Se ataca una pieza valiosa que, al apartarse, deja a tiro a la que tiene detrás. Es la clavada al revés.',
  },
  discoveredAttack: {
    name: 'Ataque a la descubierta',
    kind: 'motif',
    def: 'Una pieza se aparta y abre la línea de otra que estaba detrás. Se crean dos amenazas con una sola jugada.',
  },
  discoveredCheck: {
    name: 'Jaque a la descubierta',
    kind: 'motif',
    def: 'Una pieza se aparta y la que estaba detrás da jaque. La pieza que se mueve queda libre para hacer daño.',
  },
  doubleCheck: {
    name: 'Jaque doble',
    kind: 'motif',
    def: 'Dos piezas dan jaque a la vez. No se puede capturar ni tapar: el rey está obligado a moverse.',
  },
  deflection: {
    name: 'Desviación',
    kind: 'motif',
    def: 'Se obliga a una pieza rival a abandonar la casilla o la línea desde la que defendía algo importante.',
  },
  attraction: {
    name: 'Atracción',
    kind: 'motif',
    def: 'Se fuerza a una pieza rival, a menudo el rey, a ir a una casilla donde queda expuesta a un golpe.',
  },
  capturingDefender: {
    name: 'Eliminación del defensor',
    kind: 'motif',
    def: 'Se captura la pieza que defendía a otra o a una casilla clave. Lo que protegía queda sin defensa.',
  },
  interference: {
    name: 'Interferencia',
    kind: 'motif',
    def: 'Se coloca una pieza entre dos piezas rivales para cortar la defensa que una daba a la otra.',
  },
  intermezzo: {
    name: 'Jugada intermedia',
    kind: 'motif',
    def: 'En lugar de la respuesta esperada, se intercala antes una amenaza mayor que el rival debe atender.',
  },
  xRayAttack: {
    name: 'Rayos X',
    kind: 'motif',
    def: 'Una pieza ataca o defiende una casilla a través de otra pieza situada en la misma línea.',
  },
  clearance: {
    name: 'Despeje',
    kind: 'motif',
    def: 'Se aparta una pieza propia, a menudo con ganancia de tiempo, para dejar libre una casilla o una línea.',
  },
  trappedPiece: {
    name: 'Pieza atrapada',
    kind: 'motif',
    def: 'Una pieza no tiene ninguna casilla segura a la que ir y acaba capturada.',
  },
  hangingPiece: {
    name: 'Pieza colgada',
    kind: 'motif',
    def: 'Una pieza está atacada y nadie la defiende, o tiene menos defensores que atacantes. Se puede capturar gratis.',
  },
  sacrifice: {
    name: 'Sacrificio',
    kind: 'motif',
    def: 'Se entrega material a propósito para conseguir algo que vale más: mate, más material o una ventaja decisiva.',
  },
  zugzwang: {
    name: 'Zugzwang',
    kind: 'motif',
    def: 'El rival no está amenazado, pero cualquier jugada que haga empeora su posición.',
  },
  quietMove: {
    name: 'Jugada tranquila',
    kind: 'motif',
    def: 'Una jugada que no da jaque ni captura, pero prepara una amenaza que no se puede parar.',
  },
  defensiveMove: {
    name: 'Jugada defensiva',
    kind: 'motif',
    def: 'La única jugada, o la más precisa, para no perder material ni ventaja.',
  },
  promotion: {
    name: 'Coronación',
    kind: 'motif',
    def: 'Un peón llega a la última fila y se convierte en otra pieza, casi siempre una dama.',
  },
  underPromotion: {
    name: 'Coronación menor',
    kind: 'motif',
    def: 'El peón corona en caballo, alfil o torre porque en esa posición es mejor que pedir dama.',
  },
  advancedPawn: {
    name: 'Peón avanzado',
    kind: 'motif',
    def: 'Un peón cerca de coronar crea amenazas por sí solo y obliga al rival a vigilarlo.',
  },
  enPassant: {
    name: 'Captura al paso',
    kind: 'motif',
    def: 'Un peón captura a otro que acaba de avanzar dos casillas y ha quedado a su lado, como si solo hubiera avanzado una.',
  },
  castling: {
    name: 'Enroque',
    kind: 'motif',
    def: 'El rey y una torre se mueven a la vez: el rey se pone a salvo y la torre entra en juego.',
  },
  attackingF2F7: {
    name: 'Ataque a f2 o f7',
    kind: 'motif',
    def: 'Se ataca el peón de f2 o f7, el punto más débil al principio porque solo lo defiende el rey.',
  },
  exposedKing: {
    name: 'Rey expuesto',
    kind: 'motif',
    def: 'El rey tiene pocos defensores cerca y las piezas rivales pueden llegar hasta él.',
  },
  kingsideAttack: {
    name: 'Ataque en el flanco de rey',
    kind: 'motif',
    def: 'El ataque se dirige contra el rey rival enrocado en el flanco de rey.',
  },
  queensideAttack: {
    name: 'Ataque en el flanco de dama',
    kind: 'motif',
    def: 'El ataque se dirige contra el rey rival enrocado en el flanco de dama.',
  },
  collinearMove: { name: 'Jugada en la misma línea', kind: 'motif', review: true },

  // --- Patrones de mate ---
  backRankMate: {
    name: 'Mate del pasillo',
    kind: 'mate',
    def: 'Una torre o una dama da mate en la última fila a un rey encerrado detrás de sus propios peones.',
  },
  smotheredMate: {
    name: 'Mate de la coz',
    kind: 'mate',
    def: 'Un caballo da mate a un rey rodeado por sus propias piezas, que no le dejan ninguna casilla.',
  },
  arabianMate: {
    name: 'Mate árabe',
    kind: 'mate',
    def: 'Una torre y un caballo dan mate a un rey arrinconado: el caballo protege a la torre y quita la casilla de escape.',
  },
  anastasiaMate: {
    name: 'Mate de Anastasia',
    kind: 'mate',
    def: 'Un caballo y una torre o dama atrapan al rey contra el borde del tablero, encerrado además por una pieza propia.',
  },
  bodenMate: {
    name: 'Mate de Boden',
    kind: 'mate',
    def: 'Dos alfiles dan mate por diagonales cruzadas a un rey bloqueado por sus propias piezas.',
  },
  doubleBishopMate: {
    name: 'Mate de los dos alfiles',
    kind: 'mate',
    def: 'Dos alfiles en diagonales contiguas dan mate a un rey al que sus propios peones cortan la salida.',
  },
  dovetailMate: {
    name: 'Mate de cola de milano',
    kind: 'mate',
    def: 'La dama da mate pegada en diagonal al rey; las dos casillas que no cubre están ocupadas por piezas del propio rey.',
  },
  hookMate: {
    name: 'Mate del gancho',
    kind: 'mate',
    def: 'Una torre da mate protegida por un caballo, que a su vez está protegido por un peón.',
  },
  epauletteMate: {
    name: 'Mate de las charreteras',
    kind: 'mate',
    def: 'La dama da mate a un rey flanqueado a ambos lados por dos piezas propias que le quitan las casillas.',
  },
  operaMate: {
    name: 'Mate de la ópera',
    kind: 'mate',
    def: 'Una torre da mate en la última fila protegida por un alfil.',
  },
  blindSwineMate: {
    name: 'Mate de las torres en séptima',
    kind: 'mate',
    def: 'Dos torres en la séptima fila dan mate al rey en su primera fila.',
  },
  balestraMate: { name: 'Mate de Balestra', kind: 'mate', review: true },
  cornerMate: { name: 'Mate en el rincón', kind: 'mate', review: true },
  killBoxMate: { name: 'Mate de la caja', kind: 'mate', review: true },
  pillsburysMate: { name: 'Mate de Pillsbury', kind: 'mate', review: true },
  morphysMate: { name: 'Mate de Morphy', kind: 'mate', review: true },
  swallowstailMate: { name: 'Mate de cola de golondrina', kind: 'mate', review: true },
  triangleMate: { name: 'Mate del triángulo', kind: 'mate', review: true },
  vukovicMate: { name: 'Mate de Vuković', kind: 'mate', review: true },

  // --- Objetivo ---
  mate: { name: 'Mate', kind: 'goal', def: 'La solución termina en jaque mate.' },
  mateIn1: { name: 'Mate en 1', kind: 'goal', def: 'Hay jaque mate en una jugada.' },
  mateIn2: { name: 'Mate en 2', kind: 'goal', def: 'Hay jaque mate forzado en dos jugadas.' },
  mateIn3: { name: 'Mate en 3', kind: 'goal', def: 'Hay jaque mate forzado en tres jugadas.' },
  mateIn4: { name: 'Mate en 4', kind: 'goal', def: 'Hay jaque mate forzado en cuatro jugadas.' },
  mateIn5: { name: 'Mate en 5 o más', kind: 'goal', def: 'Hay jaque mate forzado en cinco jugadas o más.' },
  crushing: { name: 'Ventaja decisiva', kind: 'goal', def: 'La solución deja una ventaja que debería bastar para ganar.' },
  advantage: { name: 'Ventaja clara', kind: 'goal', def: 'La solución deja una ventaja clara, aunque queda partida.' },
  equality: { name: 'Igualar', kind: 'goal', def: 'Desde una posición peor, la solución salva la partida o iguala.' },

  // --- Fase ---
  opening: { name: 'Apertura', kind: 'phase' },
  middlegame: { name: 'Medio juego', kind: 'phase' },
  endgame: { name: 'Final', kind: 'phase' },

  // --- Tipo de final ---
  pawnEndgame: { name: 'Final de peones', kind: 'endgame' },
  rookEndgame: { name: 'Final de torres', kind: 'endgame' },
  bishopEndgame: { name: 'Final de alfiles', kind: 'endgame' },
  knightEndgame: { name: 'Final de caballos', kind: 'endgame' },
  queenEndgame: { name: 'Final de damas', kind: 'endgame' },
  queenRookEndgame: { name: 'Final de dama y torre', kind: 'endgame' },

  // --- Longitud ---
  oneMove: { name: 'Una jugada', kind: 'length' },
  short: { name: 'Corto (dos jugadas)', kind: 'length' },
  long: { name: 'Largo (tres jugadas)', kind: 'length' },
  veryLong: { name: 'Muy largo (cuatro jugadas o más)', kind: 'length' },

  // --- Origen de la partida ---
  master: { name: 'Partida de jugador titulado', kind: 'origin' },
  masterVsMaster: { name: 'Partida entre titulados', kind: 'origin' },
  superGM: { name: 'Partida de la élite mundial', kind: 'origin' },
};

/**
 * Orden de prioridad para elegir el tema PRINCIPAL de un problema: primero lo más específico
 * (un patrón de mate con nombre), después los motivos tácticos y por último los genéricos.
 */
const PRIORITY: string[] = [
  'smotheredMate', 'backRankMate', 'anastasiaMate', 'arabianMate', 'bodenMate', 'doubleBishopMate', 'dovetailMate',
  'hookMate', 'epauletteMate', 'operaMate', 'blindSwineMate', 'balestraMate', 'cornerMate', 'killBoxMate',
  'pillsburysMate', 'morphysMate', 'swallowstailMate', 'triangleMate', 'vukovicMate',
  'doubleCheck', 'discoveredCheck', 'discoveredAttack', 'fork', 'pin', 'skewer', 'deflection', 'attraction',
  'capturingDefender', 'interference', 'intermezzo', 'xRayAttack', 'clearance', 'trappedPiece', 'hangingPiece',
  'zugzwang', 'underPromotion', 'promotion', 'enPassant', 'castling', 'quietMove', 'defensiveMove', 'sacrifice',
  'advancedPawn', 'attackingF2F7', 'exposedKing', 'kingsideAttack', 'queensideAttack',
  'mateIn1', 'mateIn2', 'mateIn3', 'mateIn4', 'mateIn5', 'mate',
  'pawnEndgame', 'rookEndgame', 'bishopEndgame', 'knightEndgame', 'queenEndgame', 'queenRookEndgame',
  'equality', 'crushing', 'advantage', 'endgame', 'middlegame', 'opening',
];

/** Temas del problema que enseñan un concepto (motivo táctico o patrón de mate), por prioridad. */
export function conceptThemes(themes: string[]): string[] {
  return PRIORITY.filter((t) => themes.includes(t) && (THEMES[t]?.kind === 'motif' || THEMES[t]?.kind === 'mate'));
}

/** Tema principal: el primero de la lista de prioridad que tenga el problema. */
export function primaryTheme(themes: string[]): string {
  return PRIORITY.find((t) => themes.includes(t)) ?? themes[0] ?? 'mix';
}

export const themeName = (key: string): string => THEMES[key]?.name ?? key;
