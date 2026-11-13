import { describe, expect, it } from 'vitest';
import pack from '../src/data/cine.pack.json';
import { FILMS } from '../pipeline/cine-films';
import { classify, frames, judgePause, lineText, type CinemaPack, type FilmPacked } from '../src/core/cinema';

const PACK = pack as unknown as CinemaPack;
const film = (id: string): FilmPacked => PACK.films.find((f) => f.id === id)!;

function pauseAt(f: FilmPacked, san: string) {
  const fr = frames(f).find((x) => x.kind === 'move' && x.san === san && x.pause);
  if (!fr || fr.kind !== 'move' || !fr.pause) throw new Error(`sin pausa en ${san}`);
  const pp = f.pauses.find((p) => p.step === fr.step)!;
  return { fr, pp, pause: fr.pause };
}

describe('paquete del cine', () => {
  it('está al día con las fuentes (si falla: npx tsx pipeline/build-cine.ts)', () => {
    expect(PACK.films.map((f) => f.id)).toEqual(FILMS.map((f) => f.id));
    for (const src of FILMS) {
      const { pauses: _p, certificate: _c, ...rest } = film(src.id);
      expect(rest).toEqual(src);
    }
  });

  it('todas las jugadas son legales y cada pausa tiene análisis de todas las jugadas', () => {
    for (const f of PACK.films) {
      const fr = frames(f);
      for (const p of f.pauses) {
        const step = fr.find((x) => x.kind === 'move' && x.step === p.step);
        expect(step && step.kind === 'move' && step.uci).toBe(p.answerUci);
        const answer = p.verdicts.find((v) => v.uci === p.answerUci)!;
        expect(answer.cls).toBe('keeps');
        expect(new Set(p.verdicts.map((v) => v.uci)).size).toBe(p.verdicts.length);
      }
    }
  });

  it('las películas de victoria llevan prueba de mate; las de tablas lo dicen', () => {
    for (const f of PACK.films) {
      if (f.result === 'win') expect(f.certificate.kind).toBe('mate');
      else expect(f.certificate.kind).toBe('engine-draw');
    }
  });
});

describe('respuestas en las pausas', () => {
  it('Saavedra: coronar en dama acaba en ahogado', () => {
    const { fr, pp, pause } = pauseAt(film('saavedra'), 'c8=R');
    const r = judgePause(pp, fr.before, 'c7c8q', pause, 'win');
    expect(r.outcome).toBe('spoils');
    expect(r.text).toContain('ahogado');
    expect(r.line).toMatch(/Tc4\+ 7\.Dxc4/);
    expect(judgePause(pp, fr.before, 'c7c8r', pause, 'win').outcome).toBe('answer');
  });

  it('Lucena: otra jugada que también gana se reconoce como tal', () => {
    const { fr, pp, pause } = pauseAt(film('lucena'), 'Rb4');
    const kc6 = pp.verdicts.find((v) => v.san === 'Kc6')!;
    expect(kc6.cls).toBe('keeps');
    const r = judgePause(pp, fr.before, kc6.uci, pause, 'win');
    expect(r.outcome).toBe('also-good');
    expect(r.text).toContain('Tb4');
  });

  it('Oposición: solo Re5 gana', () => {
    const { pp } = pauseAt(film('oposicion'), 'Ke5');
    expect(pp.verdicts.filter((v) => v.cls === 'keeps').map((v) => v.san)).toEqual(['Ke5']);
  });
});

describe('utilidades', () => {
  it('clasifica según el resultado buscado', () => {
    expect(classify({ cp: 350 }, 'win')).toBe('keeps');
    expect(classify({ cp: 200 }, 'win')).toBe('unclear');
    expect(classify({ cp: 0 }, 'win')).toBe('spoils');
    expect(classify({ cp: 0 }, 'draw')).toBe('keeps');
    expect(classify({ mate: -3 }, 'draw')).toBe('spoils');
  });

  it('numera las líneas en notación española', () => {
    expect(lineText('8/8/8/8/8/8/8/K6k b - - 0 6', ['Kg2', 'Kb2', 'Kf3'])).toBe('6…Rg2 7.Rb2 Rf3');
  });
});
