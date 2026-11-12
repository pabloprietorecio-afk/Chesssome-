import { describe, expect, it } from 'vitest';
import { Chess } from 'chess.js';
import { material, passTurn, seeCapture, seeSquare, settleOn } from '../src/core/chessx';
import { count, formatScore, joinY, sanEs, the, toThe } from '../src/core/lang';
import { describeMove, existingPins, matePattern } from '../src/core/motifs';

describe('lenguaje', () => {
  it('traduce la notación a español sin encadenar sustituciones', () => {
    expect(sanEs('Nf7+')).toBe('Cf7+');
    expect(sanEs('Kxe2')).toBe('Rxe2');
    expect(sanEs('Rxd7')).toBe('Txd7');
    expect(sanEs('Qh7#')).toBe('Dh7#');
    expect(sanEs('Bb5')).toBe('Ab5');
    expect(sanEs('e8=Q+')).toBe('e8=D+');
    expect(sanEs('O-O-O')).toBe('O-O-O');
  });
  it('concuerda artículos y números', () => {
    expect(the('q')).toBe('la dama');
    expect(toThe('k')).toBe('al rey');
    expect(toThe('r')).toBe('a la torre');
    expect(count(2, 'r')).toBe('dos torres');
    expect(count(1, 'p')).toBe('un peón');
    expect(joinY(['a', 'b', 'c'])).toBe('a, b y c');
  });
  it('formatea evaluaciones', () => {
    expect(formatScore({ cp: 235 })).toBe('+2,35');
    expect(formatScore({ cp: -80 })).toBe('−0,80');
    expect(formatScore({ mate: 3 })).toBe('mate en 3');
    expect(formatScore({ mate: -2 })).toBe('mate en contra en 2');
  });
});

describe('material y cambios', () => {
  it('cuenta el material inicial', () => {
    expect(material(new Chess())).toEqual({ w: 39, b: 39 });
  });
  it('una pieza indefensa se gana entera; una defendida por un peón, no', () => {
    // Dama blanca ataca un caballo sin defensa en d5.
    expect(seeSquare(new Chess('4k3/8/8/3n4/8/8/3Q4/4K3 w - - 0 1'), 'd5')).toBe(3);
    // El mismo caballo defendido por un peón: capturarlo con la dama pierde material, así que no se captura.
    expect(seeSquare(new Chess('4k3/8/4p3/3n4/8/8/3Q4/4K3 w - - 0 1'), 'd5')).toBe(0);
  });
  it('seeCapture puede ser negativo', () => {
    const c = new Chess('4k3/8/4p3/3n4/8/8/3Q4/4K3 w - - 0 1');
    const m = c.moves({ verbose: true }).find((x) => x.san === 'Qxd5')!;
    expect(seeCapture(m)).toBe(3 - 9);
  });
  it('settleOn resuelve la recaptura pendiente en una casilla', () => {
    // Tras Dxd5 el peón recaptura: se resuelve ese cambio y nada más.
    const c = new Chess('4k3/8/4p3/3n4/8/8/3Q4/4K3 w - - 0 1');
    c.move('Qxd5');
    expect(settleOn(c, 'd5')).toBe(1);
    expect(material(c)).toEqual({ w: 0, b: 1 });
  });
  it('passTurn no permite pasar estando en jaque', () => {
    expect(passTurn(new Chess('4k3/8/8/8/8/8/4R3/4K3 b - - 0 1'))).toBeNull();
    expect(passTurn(new Chess())!.turn()).toBe('b');
  });
});

describe('detectores de hechos', () => {
  it('ataque doble de caballo a rey y dama', () => {
    const f = describeMove('r1q1k2r/1b2bp1p/pp3n2/1N2Q3/3p4/3P3P/PPP2PP1/R3KB1R w KQkq - 1 16', 'b5d6');
    const fork = f.motifs.find((m) => m.kind === 'fork');
    expect(fork && fork.kind === 'fork' && fork.targets.map((t) => t.type)).toEqual(['k', 'q']);
  });
  it('un cambio igualado no cuenta como dejarse una pieza', () => {
    // Axe7 captura un caballo y el alfil es recapturado: alfil por caballo.
    const f = describeMove('8/p2rnpkp/bbpNp1p1/4P1B1/B1p5/7P/PP4P1/3R3K w - - 4 23', 'g5e7');
    const hung = f.motifs.find((m) => m.kind === 'enPrise' && m.isMover);
    expect(hung).toBeUndefined();
  });
  it('dejarse la dama sí cuenta', () => {
    const f = describeMove('r1q1k2r/1b2bp1p/pp3n2/1N2Q3/3p4/3P3P/PPP2PP1/R3KB1R w KQkq - 1 16', 'e5e6');
    const hung = f.motifs.find((m) => m.kind === 'enPrise');
    expect(hung && hung.kind === 'enPrise' && hung.piece.type).toBe('q');
  });
  it('ataque a la descubierta', () => {
    const f = describeMove('8/p2rnpkp/bbpNp1p1/4P1B1/B1p5/7P/PP4P1/3R3K w - - 4 23', 'd6e8');
    const d = f.motifs.find((m) => m.kind === 'discovered');
    expect(d && d.kind === 'discovered' && d.slider.square).toBe('d1');
    expect(d && d.kind === 'discovered' && d.target.square).toBe('d7');
  });
  it('clavada absoluta ya presente en el tablero', () => {
    const pins = existingPins('5rk1/p1qr1pp1/1pp1p2p/8/4Nb2/P4P2/1PQ1BP1P/4K1R1 w - - 0 20', 'w');
    expect(pins).toHaveLength(1);
    expect(pins[0].pinned.square).toBe('g7');
    expect(pins[0].absolute).toBe(true);
  });
  it('amenaza de mate en una', () => {
    // La dama va a h6 y amenaza Dg7#, apoyada por el alfil de f6.
    const f = describeMove('6k1/5p1p/5Bp1/8/8/8/3Q4/6K1 w - - 0 1', 'd2h6');
    expect(f.motifs.some((m) => m.kind === 'mateThreat')).toBe(true);
  });
  it('reconoce el mate del pasillo y el mate de la coz', () => {
    expect(matePattern(new Chess('3R2k1/5ppp/8/8/8/8/8/6K1 b - - 0 1'))).toBe('backRank');
    expect(matePattern(new Chess('6rk/5Npp/8/8/8/8/8/6K1 b - - 0 1'))).toBe('smothered');
  });
});
