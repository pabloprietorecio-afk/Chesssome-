import { describe, expect, it } from 'vitest';
import { expectedScore, ratingForSuccess, update } from '../src/core/glicko2';

describe('Glicko-2', () => {
  it('reproduce el ejemplo publicado por Glickman', () => {
    // Jugador 1500 / RD 200 / vol 0,06, tau 0,5, contra 1400 (gana), 1550 (pierde) y 1700 (pierde).
    const r = update({ r: 1500, rd: 200, vol: 0.06 }, [
      { opponent: { r: 1400, rd: 30 }, score: 1 },
      { opponent: { r: 1550, rd: 100 }, score: 0 },
      { opponent: { r: 1700, rd: 300 }, score: 0 },
    ]);
    expect(r.r).toBeCloseTo(1464.06, 1);
    expect(r.rd).toBeCloseTo(151.52, 1);
    expect(r.vol).toBeCloseTo(0.05999, 4);
  });

  it('sin resultados solo crece la incertidumbre', () => {
    const r = update({ r: 1500, rd: 200, vol: 0.06 }, []);
    expect(r.r).toBe(1500);
    expect(r.rd).toBeGreaterThan(200);
  });

  it('acertar sube el rating y fallar lo baja', () => {
    const base = { r: 1300, rd: 150, vol: 0.06 };
    const opp = { r: 1300, rd: 75 };
    expect(update(base, [{ opponent: opp, score: 1 }]).r).toBeGreaterThan(1300);
    expect(update(base, [{ opponent: opp, score: 0 }]).r).toBeLessThan(1300);
  });

  it('la dificultad objetivo da la probabilidad de acierto pedida', () => {
    const target = ratingForSuccess(1500, 0.75);
    expect(target).toBeCloseTo(1309.1, 0);
    // Con la incertidumbre del problema (RD 75) la previsión queda muy cerca del 75 %.
    expect(expectedScore({ r: 1500 }, { r: target, rd: 75 })).toBeCloseTo(0.75, 1);
  });
});
