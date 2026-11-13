import { readFileSync } from 'node:fs';
import { Chess } from 'chess.js';
import { describe, expect, it } from 'vitest';
import { aiShareText, defaultQuestion, googleAiModeUrl, lichessAnalysisUrl } from '../src/core/assist';
import { explain, explainSolved } from '../src/core/explain';
import { unpackPuzzle } from '../src/core/pack';
import type { PuzzlePack } from '../src/core/types';

const pack = JSON.parse(readFileSync(new URL('../src/data/puzzles.pack.json', import.meta.url), 'utf8')) as PuzzlePack;
const puzzles = pack.puzzles.map((p) => unpackPuzzle(p, pack.engine));

describe('Analizar en Lichess', () => {
  it('usa el formato lichess.org/analysis/<FEN> con los espacios como %20', () => {
    expect(lichessAnalysisUrl('6K1/8/8/8/6k1/8/7P/8 w - - 0 1')).toBe('https://lichess.org/analysis/6K1/8/8/8/6k1/8/7P/8%20w%20-%20-%200%201');
  });
});

describe('Pregunta a una IA', () => {
  const sample = puzzles.slice(0, 15);

  it('el texto lleva la posición exacta, la solución y el análisis, y la URL de Lichess de esa posición', () => {
    for (const p of sample) {
      const pt = p.points[0];
      const wrong = new Chess(pt.fen).moves({ verbose: true }).find((m) => m.lan !== pt.solution)!;
      for (const exp of [explainSolved(p), explain(p, 0, wrong.lan)]) {
        const text = aiShareText({ puzzle: p, exp, levelLabel: 'Iniciado (1150 en Chessome)' });
        expect(text).toContain(`Posición (FEN): ${pt.fen}`);
        expect(text).toContain(lichessAnalysisUrl(pt.fen));
        expect(text).toContain(exp.bestSan);
        expect(text).toContain(`Análisis de ${p.engine.name}`);
        expect(text).toContain('Mi nivel: Iniciado (1150 en Chessome).');
        expect(text).toContain(`Mi pregunta: ${defaultQuestion(exp)}`);
        // Nada que no sea texto plano: ni HTML ni campos vacíos.
        expect(text).not.toMatch(/undefined|NaN|\[object|<\w/);
      }
    }
  });

  it('distingue una jugada probada en «¿Y si juego…?» de una jugada hecha', () => {
    const p = sample[1];
    const pt = p.points[0];
    const wrong = new Chess(pt.fen).moves({ verbose: true }).find((m) => m.lan !== pt.solution)!;
    const exp = explain(p, 0, wrong.lan);
    expect(aiShareText({ puzzle: p, exp, tried: true })).toContain(`Estoy probando ${exp.playedSan}; la mejor es ${exp.bestSan}.`);
    expect(aiShareText({ puzzle: p, exp })).toContain(`He jugado ${exp.playedSan}, pero la mejor era ${exp.bestSan}.`);
  });

  it('la pregunta del usuario sustituye a la pregunta por defecto', () => {
    const exp = explainSolved(sample[0]);
    const text = aiShareText({ puzzle: sample[0], exp, question: '  ¿Y si el rey huye?  ' });
    expect(text).toContain('Mi pregunta: ¿Y si el rey huye?');
    expect(text).not.toContain(defaultQuestion(exp));
  });

  it('la pregunta por defecto distingue acierto y fallo', () => {
    const p = sample[0];
    const pt = p.points[0];
    const wrong = new Chess(pt.fen).moves({ verbose: true }).find((m) => m.lan !== pt.solution)!;
    expect(defaultQuestion(explainSolved(p))).toMatch(/^¿Por qué .+ es la mejor jugada/);
    expect(defaultQuestion(explain(p, 0, wrong.lan))).toMatch(/^¿Por qué .+ no funciona y .+ sí\?/);
  });

  it('el enlace a Google codifica el texto completo', () => {
    const url = googleAiModeUrl('a b\nc&d');
    expect(url).toBe('https://www.google.com/search?udm=50&q=a%20b%0Ac%26d');
    expect(decodeURIComponent(url.split('q=')[1])).toBe('a b\nc&d');
  });
});
