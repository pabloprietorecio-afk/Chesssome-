import { describe, expect, it } from 'vitest';
import { CLIPS } from '../pipeline/video-clips';
import { creditAfterMove, parseClock, parseTimeControl, pressTimes, suggestPause, suggestSync, thinkTimes, videoTimes, type ClockData } from '../src/core/clockSync';

const ding = CLIPS.find((c) => c.id === 'ding-gukesh-2024-g14')!;
const clocks = ding.clocks!;

describe('relojes', () => {
  it('lee relojes y controles de tiempo', () => {
    expect(parseClock('1:07:23')).toBe(4043);
    expect(parseClock('9:43')).toBe(583);
    expect(() => parseClock('abc')).toThrow();
    expect(parseTimeControl('40/7200:1800+30')).toEqual([
      { moves: 40, base: 7200, inc: 0 },
      { moves: null, base: 1800, inc: 30 },
    ]);
    expect(parseTimeControl('600+5')).toEqual([{ moves: null, base: 600, inc: 5 }]);
  });

  it('Mundial 2024: sin incremento hasta la 40, 30 min al completar la 40 y 30 s desde la 41', () => {
    const p = parseTimeControl('40/7200:1800+30');
    expect(creditAfterMove(p, 39)).toBe(0);
    expect(creditAfterMove(p, 40)).toBe(1800);
    expect(creditAfterMove(p, 41)).toBe(30);
    expect(creditAfterMove(p, 58)).toBe(30);
  });

  it('Ding–Gukesh: tiempo pensado en cada jugada del final', () => {
    // 55…Txf2 2 min 12 s (Gukesh tardó en verlo); el resto, casi al instante salvo 58.Re3.
    expect(Object.fromEntries(thinkTimes(clocks))).toEqual({ 110: 132, 111: 2, 112: 3, 113: 10, 114: 1, 115: 53, 116: 7 });
    expect(Object.fromEntries(pressTimes(clocks))).toEqual({ 109: 0, 110: 132, 111: 134, 112: 137, 113: 147, 114: 148, 115: 201, 116: 208 });
  });

  it('el error de redondeo no se acumula: la suma se telescopa por bando', () => {
    const base: ClockData = { timeControl: '600+5', firstPly: 1, values: ['9:58', '9:57', '9:55', '9:50', '9:52', '9:51'], source: 'prueba' };
    const t = pressTimes(base);
    // Del ply 2 al 6 solo cuentan la primera y la última lectura de cada bando más los incrementos:
    // blancas (plies 3 y 5): 9:58 → 9:52 + 2 × 5 s; negras (plies 4 y 6): 9:57 → 9:51 + 2 × 5 s.
    expect(t.get(6)! - t.get(2)!).toBe(598 - 592 + 10 + (597 - 591 + 10));
  });

  it('rechaza relojes imposibles', () => {
    expect(() => thinkTimes({ timeControl: '600', firstPly: 1, values: ['9:00', '9:00', '9:30'], source: 'x' })).toThrow(/negativo/);
  });

  it('con un ancla, estima el segundo de vídeo de todas las jugadas', () => {
    const v = videoTimes(clocks, { ply: 110, at: 217 });
    expect(v.get(109)).toBe(85); // 55.Tf2, 2 min 12 s antes
    expect(v.get(114)).toBe(233); // 57…Rxd5
    expect(v.get(116)).toBe(293); // 58…Re5
    expect(() => videoTimes(clocks, { ply: 50, at: 0 })).toThrow();
  });

  it('pausa sugerida: antes de la jugada pero después de la anterior', () => {
    const v = videoTimes(clocks, { ply: 110, at: 217 });
    expect(suggestPause(v, 110)).toBe(214); // 3 s antes de 55…Txf2
    expect(suggestPause(v, 112)).toBe(220.5); // 56…Ad5 llega 3 s después de 56.Rxf2: a mitad de camino
    expect(suggestPause(v, 114)).toBe(232.5); // 1 s entre jugadas: justo en medio
    expect(suggestPause(v, 999)).toBeNull();
  });

  it('tablero estimado: sin inicio, empieza 5 s antes de 55.Tf2 y cada jugada aparece 0,5 s antes de su reloj', () => {
    const v = videoTimes(clocks, { ply: 110, at: 217 });
    const s = suggestSync(v, { start: null, end: null, minStart: 98, maxStart: 109 })!;
    expect(s.start).toBe(79.5);
    expect(s.sync.startPly).toBe(108);
    expect(s.sync.marks.map((m) => [m.ply, m.at])).toEqual([
      [109, 84.5],
      [110, 216.5],
      [111, 218.5],
      [112, 221.5],
      [113, 231.5],
      [114, 232.5],
      [115, 285.5],
      [116, 292.5],
    ]);
  });

  it('Ding–Gukesh: las marcas del clip salen del ancla de Pablo (55…Txf2 en 2:21) y de los relojes', () => {
    const v = videoTimes(clocks, { ply: 110, at: 141 });
    expect(ding.stops[0].at).toBe(suggestPause(v, 110));
    const s = suggestSync(v, { start: null, end: ding.end, minStart: 98, maxStart: 109 })!;
    expect(ding.start).toBe(s.start);
    expect(ding.sync).toEqual(s.sync);
  });

  it('tablero estimado: respeta el inicio y el fin ya marcados', () => {
    const v = videoTimes(clocks, { ply: 110, at: 217 });
    const s = suggestSync(v, { start: 200, end: 240, minStart: 98, maxStart: 109 })!;
    expect(s.start).toBe(200);
    expect(s.sync.startPly).toBe(109); // 55.Tf2 ya se ve al empezar
    expect(s.sync.marks.map((m) => m.ply)).toEqual([110, 111, 112, 113, 114]);
    // Nunca empieza después de la posición de la primera pregunta.
    expect(suggestSync(v, { start: 250, end: null, minStart: 98, maxStart: 109 })!.sync.startPly).toBe(109);
    expect(suggestSync(new Map(), { start: null, end: null, minStart: 98, maxStart: 109 })).toBeNull();
  });
});
