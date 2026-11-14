/**
 * Evaluación enriquecida (apartado 2 del diseño): el test de nivel y el perfil del jugador.
 *
 * De cada intento no se guarda solo si acierta. Se guarda también qué medía el problema (su familia táctica,
 * si acaba en mate, cuántas jugadas pide), en qué paso se falló, qué clase de error fue la jugada (según su
 * consecuencia, ver ErrorKind en explain.ts), si hubo ayuda y cuánto se tardó. Con eso se construye un perfil
 * por dimensiones y, a partir de él, un plan: qué dificultad y qué tipos de problema convienen.
 *
 * Qué NO se mide: la comprensión del desarrollo, la seguridad del rey como concepto posicional y la
 * capacidad estratégica. Los problemas tácticos no las miden y aquí no se inventa una medida.
 *
 * Con 8–12 problemas las dimensiones tienen muy pocos datos: el test da el nivel y unas primeras
 * observaciones; el perfil se afina con cada problema del entrenamiento. Por eso los residuos llevan
 * contracción (k) y una dimensión con menos de tres intentos no se califica.
 *
 * Este archivo es la referencia del port a GDScript (godot/core/assessment.gd), que se comprueba con
 * godot/tests/golden/assessment.json (npm run golden).
 */
import type { ErrorKind } from './explain';
import { expectedScore, ratingForSuccess, update, type Rating } from './glicko2';
import { THEMES, primaryTheme } from './themes';
import { PLACEMENT, PRIOR, type Experience } from './training';

// ---------- Qué mide cada problema ----------

/** Familias de motivos tácticos: los temas de Lichess, agrupados para que haya datos suficientes en cada una. */
export type Family = 'doble' | 'linea' | 'defensor' | 'mate' | 'peon' | 'caza' | 'otros';

const FAMILY_KEYS: Record<string, string[]> = {
  doble: ['fork', 'doubleCheck', 'discoveredAttack', 'discoveredCheck'],
  linea: ['pin', 'skewer', 'xRayAttack'],
  defensor: ['deflection', 'attraction', 'capturingDefender', 'interference', 'clearance', 'intermezzo', 'sacrifice'],
  peon: ['advancedPawn', 'promotion', 'underPromotion', 'enPassant'],
  caza: ['hangingPiece', 'trappedPiece'],
};

/** Orden fijo de las familias (para listarlas y para deshacer empates). */
export const FAMILIES: Family[] = ['doble', 'linea', 'defensor', 'mate', 'peon', 'caza', 'otros'];

export const FAMILY_NAME: Record<Family, string> = {
  doble: 'Ataques dobles y descubiertas',
  linea: 'Clavadas y enfiladas',
  defensor: 'Desviar, atraer y quitar defensas',
  mate: 'Mates',
  peon: 'Peones y coronación',
  caza: 'Piezas sin defensa o atrapadas',
  otros: 'Otros',
};

export function familyOf(themeKey: string): Family {
  for (const family of Object.keys(FAMILY_KEYS)) if (FAMILY_KEYS[family].includes(themeKey)) return family as Family;
  if (THEMES[themeKey]?.kind === 'mate' || themeKey === 'mate' || themeKey.startsWith('mateIn')) return 'mate';
  return 'otros';
}

/** Lo que la evaluación necesita saber de un problema. */
export interface Item {
  id: string;
  rating: number;
  rd: number;
  /** Clave del tema principal (Lichess). */
  theme: string;
  family: Family;
  /** La solución termina en jaque mate (etiqueta «mate» de Lichess). */
  mate: boolean;
  /** Jugadas del jugador en la solución. Tres o más: mide el cálculo. */
  steps: number;
}

export function itemOf(p: { id: string; rating: number; rd: number; themes: string[]; moves: string[] }): Item {
  const theme = primaryTheme(p.themes);
  return { id: p.id, rating: p.rating, rd: p.rd, theme, family: familyOf(theme), mate: p.themes.includes('mate'), steps: Math.floor(p.moves.length / 2) };
}

// ---------- Niveles ----------

/**
 * Niveles del 0 al 10, por dificultad (escala de problemas de Lichess). Sirven para ordenar los problemas y
 * para decirle al jugador dónde está sin enseñarle un número suelto. Suelo de cada nivel: el nivel 0 es todo
 * lo que queda por debajo de 600 (los problemas más fáciles que hay, desde unos 400).
 * Decisión de diseño: tramos de 150 puntos abajo, donde se aprende deprisa, y más anchos arriba.
 */
export const LEVEL_FLOORS = [0, 600, 750, 900, 1050, 1200, 1350, 1500, 1650, 1800, 2000];

export function levelOf(rating: number): number {
  let level = 0;
  for (let i = 0; i < LEVEL_FLOORS.length; i++) if (rating >= LEVEL_FLOORS[i]) level = i;
  return level;
}

// ---------- Intentos ----------

export type Help = '' | 'hint' | 'step' | 'solution' | 'giveup';

/** Lo que pasó en un intento, además de acertar o fallar. */
export interface Outcome {
  correct: boolean;
  /** Jugada del jugador en la que falló: 0 = la primera. −1 si no hubo jugada equivocada. */
  failStep: number;
  /** Clase de la primera jugada equivocada ('' si no la hubo: acierto, ayuda o «no lo sé»). */
  error: ErrorKind;
  help: Help;
  /** Milisegundos hasta la primera jugada (0 si no llegó a jugar) y hasta terminar el problema. */
  msFirst: number;
  ms: number;
}

export interface Try extends Item, Outcome {
  /** Probabilidad de acierto prevista ANTES del intento. */
  expected: number;
  phase: 'test' | 'train';
}

export interface State {
  rating: Rating;
  tries: Try[];
  /** El test de nivel ha terminado. */
  done: boolean;
}

// ---------- Test de nivel ----------

export const TEST = {
  ...PLACEMENT,
  /** El test incluye, si la muestra lo permite, al menos estos problemas de mate y de tres o más jugadas. */
  mateItems: 2,
  longItems: 2,
  /** Los dos primeros problemas solo buscan el nivel; las cuotas cuentan desde el tercero. */
  quotaFrom: 2,
  /** Cuánto se aleja el test de la dificultad ideal para cubrir una cuota (puntos de rating). */
  quotaBonus: 90,
};

export const startTest = (exp: Experience): State => ({ rating: { ...PRIOR[exp] }, tries: [], done: false });

type Rand = () => number;

/**
 * Siguiente problema del test: el más cercano al nivel estimado (el que más informa), con un pequeño margen
 * aleatorio, sin repetir tema y cubriendo lo que el perfil necesita medir (mates y problemas largos).
 */
export function nextTestItem(state: State, pool: Item[], rand: Rand = Math.random): Item | null {
  const seen = new Set(state.tries.map((t) => t.id));
  const used = new Map<string, number>();
  for (const t of state.tries) used.set(t.theme, (used.get(t.theme) ?? 0) + 1);
  const n = state.tries.length;
  const needMate = n >= TEST.quotaFrom && state.tries.filter((t) => t.mate).length < TEST.mateItems;
  const needLong = n >= TEST.quotaFrom && state.tries.filter((t) => t.steps >= 3).length < TEST.longItems;
  const target = state.rating.r + (rand() - 0.5) * 80;
  let best: Item | null = null;
  let bestCost = Infinity;
  for (const p of pool) {
    if (seen.has(p.id)) continue;
    let cost = Math.abs(p.rating - target) + (used.get(p.theme) ?? 0) * 35;
    // Los problemas largos cansan: solo entran los que hacen falta para medir el cálculo.
    cost += Math.max(0, p.steps - (needLong ? 3 : 2)) * 40;
    if (needMate && p.mate) cost -= TEST.quotaBonus;
    if (needLong && p.steps >= 3) cost -= TEST.quotaBonus;
    if (cost < bestCost) {
      bestCost = cost;
      best = p;
    }
  }
  return best;
}

/** Anota un intento: mueve el rating (Glicko-2) y, en el test, decide si ya hay datos suficientes. */
export function recordTry(state: State, item: Item, outcome: Outcome, phase: 'test' | 'train'): State {
  const expected = expectedScore(state.rating, { r: item.rating, rd: item.rd });
  const rating = update(state.rating, [{ opponent: { r: item.rating, rd: item.rd }, score: outcome.correct ? 1 : 0 }]);
  const tries = [...state.tries, { ...item, ...outcome, expected, phase }];
  let done = state.done;
  if (phase === 'test') {
    const n = tries.filter((t) => t.phase === 'test').length;
    done = n >= TEST.maxItems || (n >= TEST.minItems && rating.rd <= TEST.targetRd);
  }
  return { rating, tries, done };
}

/** Rango de ratings que la muestra de problemas puede medir (se descartan las colas de menos de cinco problemas). */
export function measurableRange(pool: Item[]): { min: number; max: number } {
  const sorted = pool.map((p) => p.rating).sort((a, b) => a - b);
  if (sorted.length === 0) return { min: 0, max: 0 };
  return { min: sorted[Math.min(4, sorted.length - 1)], max: sorted[Math.max(0, sorted.length - 5)] };
}

// ---------- Perfil ----------

export interface Stat {
  n: number;
  correct: number;
  expected: number;
  /** (aciertos − previstos) / (n + k): negativo = peor de lo esperable para su nivel. Con pocos intentos se acerca a cero. */
  residual: number;
}

export function stat(tries: Try[], k = 5): Stat {
  let correct = 0;
  let expected = 0;
  for (const t of tries) {
    correct += t.correct ? 1 : 0;
    expected += t.expected;
  }
  const n = tries.length;
  return { n, correct, expected, residual: (correct - expected) / (n + k) };
}

export type Status = 'few' | 'weak' | 'ok' | 'strong';

/** Calificación de una dimensión. Con menos de `minN` intentos no se califica: sería inventar un patrón. */
export function status(s: Stat, minN = 3): Status {
  if (s.n < minN) return 'few';
  if (s.residual <= -0.08) return 'weak';
  if (s.residual >= 0.08) return 'strong';
  return 'ok';
}

const ERROR_KINDS: Exclude<ErrorKind, ''>[] = ['mate', 'hangMoved', 'hangOther', 'material', 'worse', 'missed', 'slower'];

export interface Profile {
  total: Stat;
  /** Familias con algún intento (sin la de mates, que va en `mate`), de más floja a más fuerte. */
  families: (Stat & { family: Family })[];
  /** Visión de mate: problemas cuya solución termina en mate. */
  mate: Stat;
  /** Cálculo: problemas de tres o más jugadas. */
  long: Stat;
  /** En problemas de dos o más jugadas: fallos en la primera jugada y fallos después de acertarla. */
  failFirst: number;
  failLater: number;
  /** Intentos con una jugada equivocada, por clase de error. */
  errors: Record<Exclude<ErrorKind, ''>, number>;
  fails: number;
  /** De ellos, los que la respuesta inmediata del rival castiga (mate, pieza a tiro): no se miró qué podía contestar. */
  replyBlind: number;
  /** Intentos con ayuda o abandonados. */
  helped: number;
  time: {
    /** Intentos con tiempo medido. */
    n: number;
    /** Medianas del tiempo hasta la primera jugada (ms): todos, aciertos y jugadas equivocadas. */
    median: number;
    medianCorrect: number;
    medianWrong: number;
    /** Jugadas equivocadas hechas en menos de la mitad del tiempo que el jugador dedica a las que acierta. */
    rushed: number;
  };
}

function median(values: number[]): number {
  if (values.length === 0) return 0;
  const v = [...values].sort((a, b) => a - b);
  const mid = Math.floor(v.length / 2);
  return v.length % 2 === 1 ? v[mid] : (v[mid - 1] + v[mid]) / 2;
}

export function profile(tries: Try[]): Profile {
  const families = FAMILIES.filter((f) => f !== 'mate')
    .map((family) => ({ family, ...stat(tries.filter((t) => t.family === family)) }))
    .filter((s) => s.n > 0)
    .sort((a, b) => a.residual - b.residual || FAMILIES.indexOf(a.family) - FAMILIES.indexOf(b.family));
  const errors = Object.fromEntries(ERROR_KINDS.map((k) => [k, 0])) as Profile['errors'];
  let fails = 0;
  let replyBlind = 0;
  let failFirst = 0;
  let failLater = 0;
  let helped = 0;
  for (const t of tries) {
    if (t.help !== '') helped++;
    if (t.error === '') continue;
    fails++;
    errors[t.error]++;
    if (t.error === 'mate' || t.error === 'hangMoved' || t.error === 'hangOther') replyBlind++;
    if (t.steps >= 2) {
      if (t.failStep === 0) failFirst++;
      else if (t.failStep > 0) failLater++;
    }
  }
  const timed = tries.filter((t) => t.msFirst > 0);
  const right = timed.filter((t) => t.correct).map((t) => t.msFirst);
  const wrong = timed.filter((t) => t.error !== '').map((t) => t.msFirst);
  const medianCorrect = median(right);
  const rushed = right.length >= 3 ? wrong.filter((ms) => ms < 0.5 * medianCorrect).length : 0;
  return {
    total: stat(tries),
    families,
    mate: stat(tries.filter((t) => t.mate)),
    long: stat(tries.filter((t) => t.steps >= 3)),
    failFirst,
    failLater,
    errors,
    fails,
    replyBlind,
    helped,
    time: { n: timed.length, median: median(timed.map((t) => t.msFirst)), medianCorrect, medianWrong: median(wrong), rushed },
  };
}

// ---------- Plan (itinerario) ----------

export type Focus = { kind: 'family'; family: Family } | { kind: 'mate' } | { kind: 'long' };
export type Habit = 'reply' | 'rushed' | 'followThrough';

export interface Plan {
  /** Dificultad de los problemas: la que da la probabilidad de acierto objetivo. */
  target: number;
  /** Como mucho dos dimensiones flojas, de más a menos: sus problemas salen más a menudo. */
  focus: Focus[];
  /** Hábitos que los datos señalan: mirar la respuesta del rival, no precipitarse, seguir la variante hasta el final. */
  habits: Habit[];
}

/** Probabilidad de acierto con la que se eligen los problemas (decisión de diseño: 0,75). */
export const TARGET_SUCCESS = 0.75;

export function plan(rating: Rating, pr: Profile): Plan {
  const cands: { focus: Focus; residual: number; order: number }[] = [];
  pr.families.forEach((f) => {
    if (status(f) === 'weak') cands.push({ focus: { kind: 'family', family: f.family }, residual: f.residual, order: 2 + FAMILIES.indexOf(f.family) });
  });
  if (status(pr.mate) === 'weak') cands.push({ focus: { kind: 'mate' }, residual: pr.mate.residual, order: 0 });
  if (status(pr.long) === 'weak') cands.push({ focus: { kind: 'long' }, residual: pr.long.residual, order: 1 });
  cands.sort((a, b) => a.residual - b.residual || a.order - b.order);
  const habits: Habit[] = [];
  if (pr.fails >= 3 && pr.replyBlind * 2 >= pr.fails) habits.push('reply');
  if (pr.time.rushed >= 2) habits.push('rushed');
  if (pr.failLater >= 2 && pr.failLater >= pr.failFirst) habits.push('followThrough');
  return { target: ratingForSuccess(rating.r, TARGET_SUCCESS), focus: cands.slice(0, 2).map((c) => c.focus), habits };
}

// ---------- Entrenamiento ----------

/** Peso de un problema al elegir: más alto si pertenece a una dimensión en la que el jugador rinde menos de lo previsto. */
export function trainingWeight(item: Item, pr: Profile, boost = 1.5): number {
  let lack = 0;
  const fam = pr.families.find((f) => f.family === item.family);
  if (fam) lack += Math.max(0, -fam.residual);
  if (item.mate) lack += Math.max(0, -pr.mate.residual);
  if (item.steps >= 3) lack += Math.max(0, -pr.long.residual);
  return 1 + boost * lack * 5;
}

/** Elige uno al azar, con más probabilidad cuanto mayor es su peso. */
function weightedPick(cands: Item[], pr: Profile, rand: Rand): Item {
  const weights = cands.map((p) => trainingWeight(p, pr));
  const total = weights.reduce((s, w) => s + w, 0);
  let x = rand() * total;
  for (let i = 0; i < cands.length; i++) {
    x -= weights[i];
    if (x <= 0) return cands[i];
  }
  return cands[cands.length - 1];
}

/**
 * Siguiente problema del entrenamiento: no visto, cerca de la dificultad objetivo y, entre los que cumplen,
 * con más probabilidad los de las dimensiones flojas. null si ya no quedan problemas sin ver.
 */
export function pickTrainingItem(rating: Rating, tries: Try[], pool: Item[], rand: Rand = Math.random): Item | null {
  const seen = new Set(tries.map((t) => t.id));
  const unseen = pool.filter((p) => !seen.has(p.id));
  if (unseen.length === 0) return null;
  const target = ratingForSuccess(rating.r, TARGET_SUCCESS);
  const pr = profile(tries);
  for (const window of [60, 120, 200, 400]) {
    const cands = unseen.filter((p) => Math.abs(p.rating - target) <= window);
    if (cands.length >= Math.min(6, unseen.length)) return weightedPick(cands, pr, rand);
  }
  // No hay bastantes cerca (le pasa a quien queda por debajo o por encima de la muestra): los seis más próximos.
  const nearest = unseen
    .map((p, i) => ({ p, i, d: Math.abs(p.rating - target) }))
    .sort((a, b) => a.d - b.d || a.i - b.i)
    .slice(0, 6)
    .map((x) => x.p);
  return weightedPick(nearest, pr, rand);
}

/**
 * Repaso: cuando no quedan problemas sin ver, vuelve el que se falló hace más tiempo y no se ha resuelto
 * después; si no hay ninguno pendiente, el que hace más que no se ve.
 */
export function pickReviewItem(tries: Try[], pool: Item[]): Item | null {
  const last = new Map<string, { index: number; correct: boolean }>();
  tries.forEach((t, index) => last.set(t.id, { index, correct: t.correct }));
  let best: Item | null = null;
  let bestKey = Infinity;
  for (const p of pool) {
    const l = last.get(p.id);
    if (!l) return p;
    // Primero los fallados (índice tal cual); después los acertados (índice + un desplazamiento grande).
    const key = l.index + (l.correct ? 1e9 : 0);
    if (key < bestKey) {
      bestKey = key;
      best = p;
    }
  }
  return best;
}
