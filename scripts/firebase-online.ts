// Prueba real (contra Firebase) del módulo src/online: emparejamiento automático, partida en directo y limpieza.
import { readFileSync } from 'node:fs';
import { OnlineMatch, type MatchState } from '../src/online/match';
import { Rtdb } from '../src/online/rtdb';

const cfg = JSON.parse(readFileSync(new URL('./firebase-config.json', import.meta.url), 'utf8'));
let fallos = 0;
const res = (n: string, ok: boolean, d = '') => {
  if (!ok) fallos++;
  console.log(`${ok ? 'OK    ' : 'FALLO '} ${n}${d ? ' — ' + d : ''}`);
};
const until = async (p: () => boolean, ms: number) => {
  const t0 = Date.now();
  while (!p()) {
    if (Date.now() - t0 > ms) return false;
    await new Promise((r) => setTimeout(r, 20));
  }
  return true;
};
const mk = (nivel = 3) => new OnlineMatch(new Rtdb(cfg), { cleanupMs: 1500, profile: { nivel, icono: 'piece_bishop' } });
const ph = (m: OnlineMatch) => m.current.phase;

const A = mk();
const B = mk();
const t0 = Date.now();
await A.start();
res('A abre partida y espera', ph(A) === 'waiting');
await B.start();
const juntos = await until(() => ph(A) === 'playing' && ph(B) === 'playing', 15000);
res('B entra y los dos pasan a jugar', juntos, `${Date.now() - t0} ms desde que A empezó`);
if (!juntos) {
  console.log('RESULTADO: FALLOS');
  process.exit(1);
}
type Live = Extract<MatchState, { phase: 'playing' | 'ended' }>;
const sa = A.current as Live;
const sb = B.current as Live;
res('colores opuestos y misma partida', sa.color !== sb.color && sa.id === sb.id, `A=${sa.color} B=${sb.color}`);

// Perfiles y gestos (reglas publicadas el 15 nov).
const perfiles = await until(() => !!(A.current as Live).rival && !!(B.current as Live).rival, 8000);
res('cada uno ve el perfil del rival', perfiles, JSON.stringify((A.current as Live).rival));
const g1 = await A.gesture('aplauso');
const llega = await until(() => ((B.current as Live).gestures ?? []).some((g) => g.g === 'aplauso' && !g.mine), 8000);
res('un gesto llega al rival', g1 && llega);
const db0 = new Rtdb(cfg);
const malo = await db0.request('POST', `partidas/${sa.id}/gestos`, { de: 'otro', g: 'insulto' });
res('un gesto que no está en la lista se rechaza', malo.status === 401, `HTTP ${malo.status}`);
const white = sa.color === 'w' ? A : B;
const black = white === A ? B : A;
const lat: number[] = [];
for (const [who, m] of [[white, 'f2f3'], [black, 'e7e5'], [white, 'g2g4'], [black, 'd8h4']] as [OnlineMatch, string][]) {
  const other = who === A ? B : A;
  const turn = who === white ? 'w' : 'b';
  await until(() => (who.current as { turn?: string }).turn === turn, 8000);
  const n = (who.current as { moves: string[] }).moves.length;
  const t = Date.now();
  const ok = await who.play(m);
  await until(() => ((other.current as { moves?: string[] }).moves?.length ?? 0) > n || ph(other) === 'ended', 8000);
  lat.push(Date.now() - t);
  if (!ok) res(`jugada ${m}`, false);
}
res('mate del loco: los dos ven el final', await until(() => ph(A) === 'ended' && ph(B) === 'ended', 8000));
const e = (A.current as { end?: { kind: string; winner: string } }).end;
res('resultado: jaque mate y ganan negras', e?.kind === 'checkmate' && e.winner === 'b');
res('latencia de cada jugada (escribir + llegar al rival)', lat.every((x) => x < 3000), lat.map((x) => x + ' ms').join(', '));

// La partida se borra sola y la lista de abiertas queda vacía.
const db = new Rtdb(cfg);
await new Promise((r) => setTimeout(r, 2500));
const p = await db.request('GET', `partidas/${sa.id}`);
res('la partida terminada se borra', p.status === 200 && p.json === null, `HTTP ${p.status}`);
await A.leave();
await B.leave();

// Abandono: C y D juegan; D se va y C se entera.
const C = mk();
const D = mk();
await C.start();
await D.start();
await until(() => ph(C) === 'playing' && ph(D) === 'playing', 15000);
await D.leave();
const av = await until(() => ph(C) === 'ended', 8000);
res('abandono: el otro se entera', av && (C.current as { end?: { kind: string } }).end?.kind === 'abandoned');
await C.leave();

// Dos que entran a la vez se encuentran.
const E = mk();
const F = mk();
await Promise.all([E.start(), F.start()]);
const enc = await until(() => ph(E) === 'playing' && ph(F) === 'playing', 20000);
res('dos jugadores a la vez se encuentran', enc && (E.current as Live).id === (F.current as Live).id);
await E.leave();
await F.leave();

const l = await db.request('GET', 'abiertas', undefined, 'orderBy=%22%24key%22&limitToLast=20');
const resto = Object.keys((l.json ?? {}) as object).length;
res('la lista de abiertas queda sin restos de esta prueba', l.status === 200 && resto === 0, `${resto} partidas abiertas`);
console.log(fallos ? 'RESULTADO: FALLOS' : 'RESULTADO: TODO OK');
process.exit(fallos ? 1 : 0);
