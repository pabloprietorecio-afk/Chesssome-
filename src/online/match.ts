/**
 * Emparejamiento automático y partida en directo. Todo el estado compartido vive en Firebase:
 *   abiertas/<id>   {creador, latido}          partidas que esperan rival (lista)
 *   partidas/<id>   {creador, rival, unidoEn, jugadas/<n>}
 * Entrar = mirar la lista, intentar quedarse con el hueco de rival de la partida abierta más antigua y viva (lo decide
 * la base de datos, atómicamente) y, si no hay ninguna, abrir una. Dos jugadores que abren a la vez se encuentran porque
 * el de la partida más reciente se une a la más antigua.
 */
import { colorFor, gesturesOf, movesOf, profileOf, replay, type GameDoc, type Gesture, type GestureEvent, type Profile } from './game';
import { isFresh, newGameId } from './ids';
import { Rtdb, SERVER_TIME } from './rtdb';
import { applyEvent } from './sse';

export type MatchState =
  | { phase: 'idle' }
  | { phase: 'searching' }
  | { phase: 'waiting'; id: string }
  | {
      phase: 'playing' | 'ended';
      id: string;
      color: 'w' | 'b';
      fen: string;
      turn: 'w' | 'b';
      moves: string[];
      lastMove: { from: string; to: string } | null;
      /** Lo que enseña el rival (nivel, icono, foto), cuando llega. */
      rival: Profile | null;
      gestures: GestureEvent[];
      /** Solo en 'ended'. */
      end?: { kind: 'checkmate' | 'draw' | 'abandoned'; winner: 'w' | 'b' | null; why: string };
    }
  | { phase: 'error'; message: string };

export interface MatchOptions {
  heartbeatMs?: number;
  scanMs?: number;
  /** Antigüedad máxima del latido para fiarse de una partida abierta. */
  freshMs?: number;
  /** Espera antes de borrar una partida terminada. */
  cleanupMs?: number;
  rand?: () => number;
  /** Lo que se enseña al rival. */
  profile?: Profile;
}

export class OnlineMatch {
  private state: MatchState = { phase: 'idle' };
  private listeners = new Set<(s: MatchState) => void>();
  private id: string | null = null;
  private uid = '';
  private doc: GameDoc | null = null;
  private seen = false;
  private role: 'creador' | 'rival' | null = null;
  private gameStream: { stop: () => void } | null = null;
  private timers: ReturnType<typeof setInterval>[] = [];
  private closed = false;
  private lobbyCleaned = false;
  private readonly o: Required<MatchOptions>;

  constructor(private readonly db: Rtdb, opts: MatchOptions = {}) {
    this.o = { heartbeatMs: 10000, scanMs: 3000, freshMs: 30000, cleanupMs: 30000, rand: Math.random, profile: { nivel: -1 }, ...opts };
  }

  get current(): MatchState {
    return this.state;
  }

  subscribe(cb: (s: MatchState) => void): () => void {
    this.listeners.add(cb);
    cb(this.state);
    return () => this.listeners.delete(cb);
  }

  private set(s: MatchState): void {
    this.state = s;
    for (const l of this.listeners) l(s);
  }

  /** Busca rival: se une a una partida abierta o abre la suya. */
  async start(): Promise<void> {
    if (this.state.phase !== 'idle' && this.state.phase !== 'error' && this.state.phase !== 'ended') return;
    this.closed = false;
    this.id = null;
    this.doc = null;
    this.seen = false;
    this.role = null;
    this.lobbyCleaned = false;
    this.set({ phase: 'searching' });
    try {
      this.uid = (await this.db.session()).uid;
      for (const c of await this.candidates(null)) {
        if (await this.tryJoin(c)) return;
      }
      await this.open();
    } catch (e) {
      this.set({ phase: 'error', message: e instanceof Error ? e.message : String(e) });
    }
  }

  /** Partidas abiertas y vivas de otros jugadores, la más antigua primero (con `before`, solo las anteriores a esa id). */
  private async candidates(before: string | null): Promise<string[]> {
    const r = await this.db.request('GET', 'abiertas', undefined, 'orderBy=%22%24key%22&limitToLast=20');
    if (r.status !== 200) throw new Error(`No se pudo leer la lista de partidas (HTTP ${r.status})`);
    const now = r.serverNow ?? Date.now();
    const rows = (r.json ?? {}) as Record<string, { creador?: string; latido?: number }>;
    return Object.keys(rows)
      .filter((id) => rows[id]?.creador !== this.uid && isFresh(rows[id]?.latido, now, this.o.freshMs) && (before === null || id < before))
      .sort();
  }

  private async tryJoin(id: string): Promise<boolean> {
    const r = await this.db.request('PATCH', `partidas/${id}`, { rival: this.uid, unidoEn: SERVER_TIME });
    if (r.status !== 200) return false; // otro jugador se adelantó (o la partida ya no existe)
    this.id = id;
    this.role = 'rival';
    this.listen();
    void this.sendProfile(id);
    return true;
  }

  /** El perfil propio, dentro de la partida (se borra con ella). Si las reglas no lo dejan, la partida sigue igual. */
  private async sendProfile(id: string): Promise<void> {
    try {
      await this.db.request('PUT', `partidas/${id}/perfiles/${this.uid}`, this.o.profile);
    } catch {
      /* sin perfil */
    }
  }

  private lastGesture = 0;

  /** Gesto del chat. Uno cada segundo y medio como mucho. */
  async gesture(g: Gesture): Promise<boolean> {
    const s = this.state;
    if ((s.phase !== 'playing' && s.phase !== 'ended') || !this.id) return false;
    const now = Date.now();
    if (now - this.lastGesture < 1500) return false;
    this.lastGesture = now;
    const r = await this.db.request('POST', `partidas/${this.id}/gestos`, { de: this.uid, g, t: SERVER_TIME });
    return r.status === 200;
  }

  private async open(): Promise<void> {
    const id = newGameId(new Date(), this.o.rand);
    const a = await this.db.request('PUT', `partidas/${id}/creador`, this.uid);
    const b = await this.db.request('PATCH', `abiertas/${id}`, { creador: this.uid, latido: SERVER_TIME });
    if (a.status !== 200 || b.status !== 200) throw new Error(`No se pudo abrir la partida (HTTP ${a.status}/${b.status})`);
    this.id = id;
    this.role = 'creador';
    this.set({ phase: 'waiting', id });
    this.listen();
    void this.sendProfile(id);
    this.timers.push(
      setInterval(() => void this.db.request('PATCH', `abiertas/${id}`, { latido: SERVER_TIME }).catch(() => undefined), this.o.heartbeatMs),
      setInterval(() => void this.scanOlder(), this.o.scanMs),
    );
  }

  /** Si mientras esperaba otro jugador abrió una partida anterior a la mía, me uno a ella (así no esperamos los dos). */
  private async scanOlder(): Promise<void> {
    if (this.closed || this.state.phase !== 'waiting' || !this.id || this.doc?.rival) return;
    const mine = this.id;
    try {
      for (const c of await this.candidates(mine)) {
        if (this.closed || this.state.phase !== 'waiting' || this.doc?.rival) return;
        const r = await this.db.request('PATCH', `partidas/${c}`, { rival: this.uid, unidoEn: SERVER_TIME });
        if (r.status === 200) {
          this.stopTimers();
          this.gameStream?.stop();
          await this.db.request('DELETE', `abiertas/${mine}`);
          await this.db.request('DELETE', `partidas/${mine}`);
          this.id = c;
          this.role = 'rival';
          this.doc = null;
          this.seen = false;
          this.listen();
          void this.sendProfile(c);
          return;
        }
      }
    } catch {
      /* se reintenta en la próxima vuelta */
    }
  }

  private listen(): void {
    const id = this.id!;
    let tree: unknown = null;
    this.gameStream = this.db.stream(`partidas/${id}`, (e) => {
      if (this.closed || this.id !== id) return;
      tree = applyEvent(tree, e);
      this.doc = (tree && typeof tree === 'object' ? tree : null) as GameDoc | null;
      this.refresh();
    });
  }

  private refresh(): void {
    if (!this.id) return;
    const doc = this.doc;
    if (!doc) {
      // La partida desapareció: si estaba en juego y no había terminado, el rival se fue.
      if (this.seen && this.state.phase === 'playing') {
        const s = this.state;
        this.set({ ...s, phase: 'ended', end: { kind: 'abandoned', winner: s.color, why: 'Tu rival ha abandonado la partida' } });
        this.finish();
      }
      return;
    }
    const color = colorFor(doc, this.uid);
    if (!color) {
      if (this.state.phase === 'searching' || this.state.phase === 'waiting') return;
      return;
    }
    this.seen = true;
    if (this.role === 'creador' && !this.lobbyCleaned) {
      this.lobbyCleaned = true;
      this.stopTimers();
      void this.db.request('DELETE', `abiertas/${this.id}`).catch(() => undefined);
    }
    const other = doc.creador === this.uid ? doc.rival ?? '' : doc.creador ?? '';
    const rival = profileOf(doc, other);
    const gestures = gesturesOf(doc, this.uid);
    if (this.state.phase === 'ended') {
      // Terminada: ya no cambian las jugadas, pero aún llegan gestos («buena partida»).
      this.set({ ...this.state, rival: rival ?? this.state.rival, gestures });
      return;
    }
    const rp = replay(movesOf(doc));
    const base = { id: this.id, color, fen: rp.fen, turn: rp.turn, moves: rp.moves, lastMove: rp.lastMove, rival, gestures };
    if (rp.over) {
      this.set({ ...base, phase: 'ended', end: rp.over });
      this.finish();
    } else this.set({ ...base, phase: 'playing' });
  }

  /** Jugada propia (UCI). Devuelve false si no es tu turno, no es legal o no se pudo escribir. */
  async play(uci: string): Promise<boolean> {
    const s = this.state;
    if (s.phase !== 'playing' || s.turn !== s.color || !this.doc) return false;
    const n = s.moves.length;
    const check = replay([...s.moves, uci]);
    if (check.illegalAt !== null) return false;
    const r = await this.db.request('PUT', `partidas/${s.id}/jugadas/${n}`, uci);
    if (r.status !== 200) return false;
    // Se ve al instante; el directo trae lo mismo enseguida.
    const jug = { ...((this.doc.jugadas && !Array.isArray(this.doc.jugadas) ? this.doc.jugadas : Object.fromEntries(movesOf(this.doc).map((m, i) => [i, m]))) as Record<string, string>), [String(n)]: uci };
    this.doc = { ...this.doc, jugadas: jug };
    this.refresh();
    return true;
  }

  /** Rendirse o salir: la partida se borra y el rival se entera. */
  async leave(): Promise<void> {
    const id = this.id;
    const phase = this.state.phase;
    this.closed = true;
    this.stopTimers();
    this.gameStream?.stop();
    this.gameStream = null;
    if (id && (phase === 'waiting' || phase === 'playing' || phase === 'ended')) {
      await Promise.allSettled([this.role === 'creador' ? this.db.request('DELETE', `abiertas/${id}`) : Promise.resolve(), this.db.request('DELETE', `partidas/${id}`)]);
    }
    this.id = null;
    this.set({ phase: 'idle' });
  }

  private finish(): void {
    this.stopTimers();
    const id = this.id;
    // Se deja un momento para que el rival reciba la última jugada y luego se limpia.
    setTimeout(() => {
      if (id) void this.db.request('DELETE', `partidas/${id}`).catch(() => undefined);
      this.gameStream?.stop();
      this.gameStream = null;
    }, this.o.cleanupMs);
  }

  private stopTimers(): void {
    for (const t of this.timers) clearInterval(t);
    this.timers = [];
  }
}
