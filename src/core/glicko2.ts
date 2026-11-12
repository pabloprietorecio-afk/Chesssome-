/**
 * Glicko-2, implementado a partir de la descripción de su autor (Mark Glickman, "Example of the Glicko-2 system").
 * El sistema es de dominio público. Cada intento de un problema se trata como una partida
 * entre el jugador y el problema, igual que hace Lichess.
 */

export interface Rating {
  r: number; // rating
  rd: number; // desviación (incertidumbre)
  vol: number; // volatilidad
}

export interface Result {
  opponent: { r: number; rd: number };
  /** 1 = acierto, 0 = fallo. Admite valores intermedios. */
  score: number;
}

const SCALE = 173.7178;
const g = (phi: number): number => 1 / Math.sqrt(1 + (3 * phi * phi) / (Math.PI * Math.PI));
const E = (mu: number, muJ: number, phiJ: number): number => 1 / (1 + Math.exp(-g(phiJ) * (mu - muJ)));

/** Probabilidad de acierto prevista para un jugador frente a un problema. */
export function expectedScore(player: { r: number; rd?: number }, opponent: { r: number; rd: number }): number {
  return E((player.r - 1500) / SCALE, (opponent.r - 1500) / SCALE, opponent.rd / SCALE);
}

/** Actualiza el rating con los resultados de un periodo (aquí, normalmente un solo problema). */
export function update(player: Rating, results: Result[], tau = 0.5): Rating {
  const mu = (player.r - 1500) / SCALE;
  const phi = player.rd / SCALE;
  if (results.length === 0) {
    return { r: player.r, rd: Math.min(350, Math.sqrt(phi * phi + player.vol * player.vol) * SCALE), vol: player.vol };
  }
  let vInv = 0;
  let sum = 0;
  for (const res of results) {
    const muJ = (res.opponent.r - 1500) / SCALE;
    const phiJ = res.opponent.rd / SCALE;
    const e = E(mu, muJ, phiJ);
    const gj = g(phiJ);
    vInv += gj * gj * e * (1 - e);
    sum += gj * (res.score - e);
  }
  const v = 1 / vInv;
  const delta = v * sum;

  // Nueva volatilidad (algoritmo de Illinois).
  const a = Math.log(player.vol * player.vol);
  const f = (x: number): number => {
    const ex = Math.exp(x);
    const num = ex * (delta * delta - phi * phi - v - ex);
    const den = 2 * (phi * phi + v + ex) * (phi * phi + v + ex);
    return num / den - (x - a) / (tau * tau);
  };
  let A = a;
  let B: number;
  if (delta * delta > phi * phi + v) {
    B = Math.log(delta * delta - phi * phi - v);
  } else {
    let k = 1;
    while (f(a - k * tau) < 0) k++;
    B = a - k * tau;
  }
  let fA = f(A);
  let fB = f(B);
  for (let i = 0; i < 100 && Math.abs(B - A) > 1e-6; i++) {
    const C = A + ((A - B) * fA) / (fB - fA);
    const fC = f(C);
    if (fC * fB <= 0) {
      A = B;
      fA = fB;
    } else {
      fA = fA / 2;
    }
    B = C;
    fB = fC;
  }
  const vol = Math.exp(A / 2);
  const phiStar = Math.sqrt(phi * phi + vol * vol);
  const phiNew = 1 / Math.sqrt(1 / (phiStar * phiStar) + 1 / v);
  const muNew = mu + phiNew * phiNew * sum;
  return { r: muNew * SCALE + 1500, rd: phiNew * SCALE, vol };
}

/**
 * Rating del problema que da al jugador una probabilidad de acierto `p`.
 * Con p = 0,75 el problema queda unos 190 puntos por debajo del jugador.
 */
export function ratingForSuccess(playerRating: number, p: number): number {
  return playerRating - 400 * Math.log10(p / (1 - p));
}
