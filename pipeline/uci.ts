/**
 * Cliente UCI mínimo para hablar con Stockfish como proceso separado.
 *
 * Stockfish es GPLv3. Aquí se ejecuta SOLO en el pipeline (herramienta de desarrollo):
 * la app no lo incluye, únicamente consume los datos que produce.
 */
import { spawn, type ChildProcessWithoutNullStreams } from 'node:child_process';
import { createRequire } from 'node:module';
import type { MoveEval, Score } from '../src/core/types';

const require = createRequire(import.meta.url);

export interface AnalyseOptions {
  depth: number;
  multipv: number;
  /** Máximo de medias jugadas de la variante que se conservan. */
  maxPv?: number;
}

export class UciEngine {
  private child: ChildProcessWithoutNullStreams;
  private buffer = '';
  private listeners: ((line: string) => void)[] = [];
  public name = 'desconocido';

  private constructor(child: ChildProcessWithoutNullStreams) {
    this.child = child;
    child.stdout.on('data', (chunk: Buffer) => {
      this.buffer += chunk.toString();
      let i: number;
      while ((i = this.buffer.indexOf('\n')) >= 0) {
        const line = this.buffer.slice(0, i).trim();
        this.buffer = this.buffer.slice(i + 1);
        for (const l of [...this.listeners]) l(line);
      }
    });
    child.stderr.on('data', (chunk: Buffer) => process.stderr.write(chunk));
  }

  /** Arranca el motor WASM de stockfish.js ("lite-single" por defecto) bajo Node. */
  static async start(flavor = 'lite-single', hashMb = 64): Promise<UciEngine> {
    const enginePath: string = require('stockfish').findEngine(flavor);
    const child = spawn(process.execPath, [enginePath], { stdio: 'pipe' });
    const engine = new UciEngine(child);
    // Los dos escuchadores se registran ANTES de enviar "uci": las líneas llegan en el mismo bloque.
    const idLine = engine.waitFor((l) => l.startsWith('id name '));
    const uciOk = engine.waitFor((l) => l === 'uciok');
    engine.send('uci');
    engine.name = (await idLine).replace('id name ', '');
    await uciOk;
    engine.send(`setoption name Hash value ${hashMb}`);
    await engine.ready();
    return engine;
  }

  private send(cmd: string): void {
    this.child.stdin.write(cmd + '\n');
  }

  private waitFor(pred: (line: string) => boolean): Promise<string> {
    return new Promise((resolve) => {
      const l = (line: string) => {
        if (pred(line)) {
          this.listeners.splice(this.listeners.indexOf(l), 1);
          resolve(line);
        }
      };
      this.listeners.push(l);
    });
  }

  async ready(): Promise<void> {
    const p = this.waitFor((l) => l === 'readyok');
    this.send('isready');
    await p;
  }

  /**
   * Analiza una posición con MultiPV y devuelve una línea por jugada raíz,
   * ordenadas de mejor a peor. Solo se aceptan líneas de la última profundidad completada.
   */
  async analyse(fen: string, opts: AnalyseOptions): Promise<MoveEval[]> {
    const maxPv = opts.maxPv ?? 12;
    this.send(`setoption name MultiPV value ${opts.multipv}`);
    await this.ready();
    const byDepth = new Map<number, Map<number, MoveEval>>();
    const onInfo = (line: string) => {
      if (!line.startsWith('info ') || !line.includes(' pv ')) return;
      const depth = Number(/ depth (\d+)/.exec(line)?.[1]);
      const idx = Number(/ multipv (\d+)/.exec(line)?.[1] ?? 1);
      const sc = / score (cp|mate) (-?\d+)/.exec(line);
      const pvStr = / pv (.+)$/.exec(line)?.[1];
      if (!sc || !pvStr || !Number.isFinite(depth)) return;
      const moves = pvStr.trim().split(/\s+/);
      const score: Score = sc[1] === 'cp' ? { cp: Number(sc[2]) } : { mate: Number(sc[2]) };
      if (!byDepth.has(depth)) byDepth.set(depth, new Map());
      byDepth.get(depth)!.set(idx, { uci: moves[0], score, pv: moves.slice(1, 1 + maxPv) });
    };
    this.listeners.push(onInfo);
    const done = this.waitFor((l) => l.startsWith('bestmove'));
    this.send('ucinewgame');
    this.send(`position fen ${fen}`);
    this.send(`go depth ${opts.depth}`);
    await done;
    this.listeners.splice(this.listeners.indexOf(onInfo), 1);
    if (byDepth.size === 0) return [];
    // Última profundidad con el mayor número de líneas (la final puede quedar incompleta si hay mate forzado).
    const depths = [...byDepth.keys()].sort((a, b) => b - a);
    const maxLines = Math.max(...depths.map((d) => byDepth.get(d)!.size));
    const best = depths.find((d) => byDepth.get(d)!.size === maxLines)!;
    const lines = byDepth.get(best)!;
    return [...lines.keys()].sort((a, b) => a - b).map((k) => lines.get(k)!);
  }

  quit(): void {
    try {
      this.send('quit');
    } catch {
      /* ya cerrado */
    }
    this.child.kill();
  }
}
