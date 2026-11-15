import { describe, expect, it } from 'vitest';
import { colorFor, movesOf, replay } from '../src/online/game';
import { colorOf, isFresh, newGameId } from '../src/online/ids';
import { OnlineMatch, type MatchState } from '../src/online/match';
import { Rtdb } from '../src/online/rtdb';
import { applyEvent, SseParser } from '../src/online/sse';
import { createFakeFirebase, until } from './helpers/fakeRtdb';

const cfg = (fb: ReturnType<typeof createFakeFirebase>) => ({ apiKey: 'k', databaseURL: fb.base });
const FAST = { heartbeatMs: 40, scanMs: 25, cleanupMs: 60 };
const mem = () => {
  const m = new Map<string, string>();
  return { getItem: (k: string) => m.get(k) ?? null, setItem: (k: string, v: string) => void m.set(k, v) };
};
const player = (fb: ReturnType<typeof createFakeFirebase>, profile?: { nivel: number; icono?: string }) => new OnlineMatch(new Rtdb(cfg(fb), { fetch: fb.fetch }), { ...FAST, profile });
type Live = Extract<MatchState, { phase: 'playing' | 'ended' }>;
const cur = (p: OnlineMatch): MatchState => p.current;
const playing = (s: MatchState): s is Extract<MatchState, { phase: 'playing' | 'ended' }> => s.phase === 'playing' || s.phase === 'ended';

describe('lector SSE', () => {
  it('une los trozos y entiende put, patch y keep-alive', () => {
    const p = new SseParser();
    expect(p.push('event: put\ndata: {"path":"/","da')).toEqual([]);
    const ev = p.push('ta":{"a":1}}\n\nevent: keep-alive\ndata: null\n\nevent: patch\r\ndata: {"path":"/x","data":{"b":2}}\r\n\r\n');
    expect(ev.map((e) => e.event)).toEqual(['put', 'keep-alive', 'patch']);
    expect(ev[0].data).toEqual({ path: '/', data: { a: 1 } });
  });
  it('mantiene la copia local con put, patch y borrados', () => {
    let t: unknown = null;
    t = applyEvent(t, { event: 'put', data: { path: '/', data: { creador: 'a' } } });
    t = applyEvent(t, { event: 'patch', data: { path: '/', data: { rival: 'b', unidoEn: 7 } } });
    t = applyEvent(t, { event: 'put', data: { path: '/jugadas/0', data: 'e2e4' } });
    t = applyEvent(t, { event: 'put', data: { path: '/jugadas/1', data: 'e7e5' } });
    expect(t).toEqual({ creador: 'a', rival: 'b', unidoEn: 7, jugadas: { 0: 'e2e4', 1: 'e7e5' } });
    t = applyEvent(t, { event: 'put', data: { path: '/jugadas/1', data: null } });
    expect(movesOf(t as never)).toEqual(['e2e4']);
    t = applyEvent(t, { event: 'put', data: { path: '/', data: null } });
    expect(t).toBeNull();
  });
  it('acepta que Firebase devuelva las jugadas como array', () => {
    const t = applyEvent(null, { event: 'put', data: { path: '/', data: { jugadas: ['e2e4', 'e7e5'] } } });
    expect(movesOf(t as never)).toEqual(['e2e4', 'e7e5']);
    expect(movesOf({ jugadas: { 0: 'e2e4', 2: 'g1f3' } })).toEqual(['e2e4']);
  });
});

describe('identificadores, colores y latido', () => {
  it('el id lleva la hora al segundo y ordena cronológicamente', () => {
    const a = newGameId(new Date(Date.UTC(2026, 10, 15, 3, 4, 5)), () => 0.5);
    const b = newGameId(new Date(Date.UTC(2026, 10, 15, 3, 4, 6)), () => 0.1);
    expect(a).toMatch(/^20261115-030405-[0-9a-z]{6}$/);
    expect(a < b).toBe(true);
  });
  it('el color depende de la paridad y los dos son distintos', () => {
    expect(colorOf(1000, 'creador')).toBe('w');
    expect(colorOf(1000, 'rival')).toBe('b');
    expect(colorOf(1001, 'creador')).toBe('b');
    expect(colorOf(1001, 'rival')).toBe('w');
    expect(colorFor({ creador: 'a', rival: 'b', unidoEn: 1001 }, 'a')).toBe('b');
    expect(colorFor({ creador: 'a', rival: 'b', unidoEn: 1001 }, 'x')).toBeNull();
    expect(colorFor({ creador: 'a' }, 'a')).toBeNull();
  });
  it('un latido viejo no vale', () => {
    expect(isFresh(100000, 110000)).toBe(true);
    expect(isFresh(100000, 200000)).toBe(false);
    expect(isFresh(undefined, 1)).toBe(false);
  });
});

describe('reglas del ajedrez sobre las jugadas recibidas', () => {
  it('reconoce el mate del loco y quién gana', () => {
    const r = replay(['f2f3', 'e7e5', 'g2g4', 'd8h4']);
    expect(r.over).toMatchObject({ kind: 'checkmate', winner: 'b' });
  });
  it('ignora desde la primera jugada ilegal', () => {
    const r = replay(['e2e4', 'e2e4', 'e7e5']);
    expect(r.moves).toEqual(['e2e4']);
    expect(r.illegalAt).toBe(1);
  });
  it('entiende la promoción', () => {
    const r = replay(['a2a4', 'b7b5', 'a4b5', 'a7a6', 'b5a6', 'c8b7', 'a6b7', 'b8c6', 'b7a8q']);
    expect(r.illegalAt).toBeNull();
    expect(r.fen).toContain('Q');
  });
});

describe('sesión anónima', () => {
  it('recuerda al jugador entre visitas gracias al token guardado', async () => {
    const fb = createFakeFirebase();
    const store = mem();
    const uid1 = (await new Rtdb(cfg(fb), { fetch: fb.fetch, store }).session()).uid;
    const uid2 = (await new Rtdb(cfg(fb), { fetch: fb.fetch, store }).session()).uid;
    const uid3 = (await new Rtdb(cfg(fb), { fetch: fb.fetch, store: mem() }).session()).uid;
    expect(uid2).toBe(uid1);
    expect(uid3).not.toBe(uid1);
  });
  it('renueva el token antes de que caduque', async () => {
    const fb = createFakeFirebase();
    let t = 0;
    const db = new Rtdb(cfg(fb), { fetch: fb.fetch, store: mem(), now: () => t });
    const a = await db.session();
    t = 3300 * 1000; // quedan menos de 5 minutos
    const b = await db.session();
    expect(b.uid).toBe(a.uid);
    expect(b.idToken).not.toBe(a.idToken);
  });
});

describe('emparejamiento y partida', () => {
  it('el segundo jugador que entra se une a la partida abierta y los colores son opuestos', async () => {
    const fb = createFakeFirebase();
    const A = player(fb);
    const B = player(fb);
    await A.start();
    expect(A.current.phase).toBe('waiting');
    await B.start();
    await until(() => A.current.phase === 'playing' && B.current.phase === 'playing', 3000, 'los dos en juego');
    const a = cur(A) as Live;
    const b = cur(B) as Live;
    expect(a.color).not.toBe(b.color);
    expect(a.id).toBe(b.id);
    await until(() => fb.read('abiertas') === null, 1000, 'lista de abiertas vacía');
    await A.leave();
    await B.leave();
  });

  it('juegan el mate del loco en directo y los dos ven el final', async () => {
    const fb = createFakeFirebase();
    const A = player(fb);
    const B = player(fb);
    await A.start();
    await B.start();
    await until(() => A.current.phase === 'playing' && B.current.phase === 'playing');
    const white = (A.current as { color: 'w' | 'b' }).color === 'w' ? A : B;
    const black = white === A ? B : A;
    const line: [OnlineMatch, string][] = [[white, 'f2f3'], [black, 'e7e5'], [white, 'g2g4'], [black, 'd8h4']];
    for (const [who, m] of line) {
      await until(() => (who.current as { turn?: string }).turn === (who === white ? 'w' : 'b'), 2000, 'su turno');
      expect(await who.play(m)).toBe(true);
    }
    await until(() => A.current.phase === 'ended' && B.current.phase === 'ended', 2000, 'fin');
    for (const p of [A, B]) {
      const s = p.current;
      expect(playing(s) && s.end).toMatchObject({ kind: 'checkmate', winner: 'b' });
    }
    await until(() => fb.read('partidas') === null, 2000, 'partida borrada');
  });

  it('no deja jugar fuera de turno ni jugadas ilegales', async () => {
    const fb = createFakeFirebase();
    const A = player(fb);
    const B = player(fb);
    await A.start();
    await B.start();
    await until(() => A.current.phase === 'playing' && B.current.phase === 'playing');
    const white = (A.current as { color: 'w' | 'b' }).color === 'w' ? A : B;
    const black = white === A ? B : A;
    expect(await black.play('e7e5')).toBe(false); // no es su turno
    expect(await white.play('e2e5')).toBe(false); // ilegal
    expect(await white.play('e2e4')).toBe(true);
    expect(await white.play('d2d4')).toBe(false); // ya movió
    await until(() => (black.current as { moves: string[] }).moves.length === 1, 1000, 'la jugada llega');
    await A.leave();
    await B.leave();
  });

  it('si dos jugadores abren a la vez, se encuentran', async () => {
    const fb = createFakeFirebase();
    const A = player(fb);
    const B = player(fb);
    await Promise.all([A.start(), B.start()]);
    await until(() => A.current.phase === 'playing' && B.current.phase === 'playing', 3000, 'se encuentran');
    expect((A.current as { id: string }).id).toBe((B.current as { id: string }).id);
    await until(() => fb.read('abiertas') === null && Object.keys((fb.read('partidas') as object) ?? {}).length === 1, 1500, 'sin restos');
    await A.leave();
    await B.leave();
  });

  it('con tres jugadores solo uno entra en la partida abierta y el otro abre la suya', async () => {
    const fb = createFakeFirebase();
    const A = player(fb);
    await A.start();
    const [B, C] = [player(fb), player(fb)];
    await Promise.all([B.start(), C.start()]);
    await until(() => [A, B, C].filter((p) => p.current.phase === 'playing').length === 2 && [A, B, C].filter((p) => p.current.phase === 'waiting').length === 1, 3000, 'dos juegan y uno espera');
    expect(A.current.phase).toBe('playing');
    for (const p of [A, B, C]) await p.leave();
  });

  it('ignora partidas abiertas con el latido viejo (fantasmas)', async () => {
    const fb = createFakeFirebase();
    fb.write('abiertas/20200101-000000-aaaaaa', { creador: 'fantasma', latido: Date.now() - 10 * 60 * 1000 });
    const A = player(fb);
    await A.start();
    expect(A.current.phase).toBe('waiting');
    await A.leave();
  });

  it('si el rival se va, se avisa de que ha abandonado y gana quien se queda', async () => {
    const fb = createFakeFirebase();
    const A = player(fb);
    const B = player(fb);
    await A.start();
    await B.start();
    await until(() => A.current.phase === 'playing' && B.current.phase === 'playing');
    const color = (B.current as { color: 'w' | 'b' }).color;
    await A.leave();
    await until(() => B.current.phase === 'ended', 2000, 'aviso de abandono');
    expect((B.current as { end?: unknown }).end).toMatchObject({ kind: 'abandoned', winner: color });
    await B.leave();
  });

  it('cada uno ve el nivel y el icono del rival, y los gestos llegan a los dos', async () => {
    const fb = createFakeFirebase();
    const A = player(fb, { nivel: 5, icono: 'piece_bishop' });
    const B = player(fb, { nivel: 2 });
    await A.start();
    await B.start();
    await until(() => !!(A.current as Live).rival && !!(B.current as Live).rival, 2000, 'perfiles');
    expect((A.current as Live).rival).toEqual({ nivel: 2, icono: undefined, foto: undefined });
    expect((B.current as Live).rival).toMatchObject({ nivel: 5, icono: 'piece_bishop' });
    expect(await A.gesture('aplauso')).toBe(true);
    expect(await A.gesture('genial')).toBe(false); // demasiado seguido
    await until(() => (B.current as Live).gestures.length === 1, 2000, 'gesto');
    expect((B.current as Live).gestures[0]).toMatchObject({ g: 'aplauso', mine: false });
    expect((A.current as Live).gestures[0]).toMatchObject({ g: 'aplauso', mine: true });
    await A.leave();
    await B.leave();
  });

  it('salir mientras se espera deja la base limpia', async () => {
    const fb = createFakeFirebase();
    const A = player(fb);
    await A.start();
    await A.leave();
    expect(fb.read('abiertas')).toBeNull();
    expect(fb.read('partidas')).toBeNull();
  });
});
