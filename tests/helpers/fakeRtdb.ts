/**
 * Servidor falso de Firebase (Auth anónima + Realtime Database por REST y SSE), en memoria, para probar sin red.
 * Solo imita lo que usa el cliente: no valida las reglas de seguridad reales (eso lo hace la prueba contra Firebase
 * en scripts/firebase-prueba.mjs), salvo que «rival» solo puede escribirse una vez (primero en llegar).
 */
type Json = unknown;
interface Watcher {
  path: string;
  send: (event: string, data: Json) => void;
}

export function createFakeFirebase(base = 'https://fake.firebaseio.test') {
  let root: Json = null;
  let users = 0;
  const tokens = new Map<string, string>(); // idToken → uid
  const refresh = new Map<string, string>(); // refreshToken → uid
  const watchers = new Set<Watcher>();
  const enc = new TextEncoder();

  const parts = (p: string) => p.split('/').filter(Boolean);
  const getAt = (path: string): Json => {
    let cur: any = root;
    for (const k of parts(path)) {
      if (cur == null || typeof cur !== 'object') return null;
      cur = cur[k];
    }
    return cur ?? null;
  };
  const setAt = (path: string, value: Json): void => {
    const ps = parts(path);
    if (ps.length === 0) {
      root = value;
      return;
    }
    if (root == null || typeof root !== 'object') root = {};
    let cur: any = root;
    for (let i = 0; i < ps.length - 1; i++) {
      if (cur[ps[i]] == null || typeof cur[ps[i]] !== 'object') cur[ps[i]] = {};
      cur = cur[ps[i]];
    }
    const last = ps[ps.length - 1];
    if (value === null) delete cur[last];
    else cur[last] = value;
    // limpia padres vacíos como hace Firebase
    for (let n = ps.length - 1; n > 0; n--) {
      const parent = getAt(ps.slice(0, n).join('/'));
      if (parent && typeof parent === 'object' && Object.keys(parent as object).length === 0) {
        const up: any = getAt(ps.slice(0, n - 1).join('/')) ?? root;
        delete up[ps[n - 1]];
      } else break;
    }
  };

  const stamp = (v: Json, now: number): Json => {
    if (v && typeof v === 'object') {
      if ((v as any)['.sv'] === 'timestamp') return now;
      return Object.fromEntries(Object.entries(v).map(([k, x]) => [k, stamp(x, now)]));
    }
    return v;
  };

  /** Avisa a quien escucha una ruta que contiene (o está dentro de) la escrita. */
  const notify = (path: string, kind: 'put' | 'patch', data: Json) => {
    for (const w of watchers) {
      const wp = parts(w.path);
      const ep = parts(path);
      const n = Math.min(wp.length, ep.length);
      if (wp.slice(0, n).join('/') !== ep.slice(0, n).join('/')) continue;
      if (ep.length >= wp.length) w.send(kind, { path: '/' + ep.slice(wp.length).join('/'), data });
      else w.send('put', { path: '/', data: getAt(w.path) });
    }
  };

  const json = (status: number, body: Json, headers: Record<string, string> = {}) =>
    new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json', date: new Date().toUTCString(), ...headers } });

  const fetchFn = async (input: RequestInfo | URL, init: RequestInit = {}): Promise<Response> => {
    const url = new URL(String(input));
    const method = (init.method ?? 'GET').toUpperCase();
    if (url.host === 'identitytoolkit.googleapis.com') {
      const uid = `u${++users}`;
      const idToken = `id-${uid}`;
      tokens.set(idToken, uid);
      refresh.set(`rf-${uid}`, uid);
      return json(200, { idToken, refreshToken: `rf-${uid}`, localId: uid, expiresIn: '3600' });
    }
    if (url.host === 'securetoken.googleapis.com') {
      const rt = new URLSearchParams(String(init.body)).get('refresh_token') ?? '';
      const uid = refresh.get(rt);
      if (!uid) return json(400, { error: { message: 'INVALID_REFRESH_TOKEN' } });
      const idToken = `id-${uid}-${Math.random().toString(36).slice(2, 6)}`;
      tokens.set(idToken, uid);
      return json(200, { id_token: idToken, refresh_token: rt, user_id: uid, expires_in: '3600' });
    }
    if (!String(input).startsWith(base)) return new Response('no', { status: 404 });
    const uid = tokens.get(url.searchParams.get('auth') ?? '');
    if (!uid) return json(401, { error: 'Permission denied' });
    const path = url.pathname.replace(/\.json$/, '');
    const body = init.body ? JSON.parse(String(init.body)) : undefined;
    const now = Date.now();
    if (method === 'GET') {
      const accept = (init.headers as Record<string, string> | undefined)?.Accept;
      if (accept === 'text/event-stream') {
        let w!: Watcher;
        const stream = new ReadableStream<Uint8Array>({
          start(ctl) {
            w = { path, send: (event, data) => ctl.enqueue(enc.encode(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`)) };
            watchers.add(w);
            w.send('put', { path: '/', data: getAt(path) });
            init.signal?.addEventListener('abort', () => {
              watchers.delete(w);
              try {
                ctl.error(new DOMException('aborted', 'AbortError'));
              } catch {
                /* ya cerrado */
              }
            });
          },
          cancel() {
            watchers.delete(w);
          },
        });
        return new Response(stream, { status: 200, headers: { 'content-type': 'text/event-stream' } });
      }
      return json(200, getAt(path));
    }
    if (method === 'DELETE') {
      setAt(path, null);
      notify(path, 'put', null);
      return json(200, null);
    }
    if (method === 'PUT') {
      const v = stamp(body, now);
      setAt(path, v);
      notify(path, 'put', v);
      return json(200, v);
    }
    if (method === 'PATCH') {
      const v = stamp(body, now) as Record<string, Json>;
      if ('rival' in v && getAt(`${path}/rival`) !== null) return json(401, { error: 'Permission denied' });
      for (const [k, x] of Object.entries(v)) setAt(`${path}/${k}`, x);
      notify(path, 'patch', v);
      return json(200, v);
    }
    return json(405, null);
  };

  return {
    base,
    fetch: fetchFn as typeof fetch,
    read: (path: string) => getAt(path),
    write: (path: string, value: Json) => {
      setAt(path, value);
      notify(path, 'put', value);
    },
  };
}

export async function until(pred: () => boolean, ms = 3000, what = 'condición'): Promise<void> {
  const t0 = Date.now();
  while (!pred()) {
    if (Date.now() - t0 > ms) throw new Error(`Tiempo agotado esperando: ${what}`);
    await new Promise((r) => setTimeout(r, 5));
  }
}
