/**
 * Cliente mínimo de Firebase Realtime Database y Firebase Auth (anónimo) por REST, solo con fetch.
 * Sirve en el navegador y en Node 22. Guarda el token de renovación para que el jugador sea el mismo en la próxima visita.
 */
import { SseParser, type SseEvent } from './sse';

export interface FirebaseConfig {
  apiKey: string;
  databaseURL: string;
}
export interface Session {
  uid: string;
  idToken: string;
  /** Instante (ms) en que caduca el token. */
  expiresAt: number;
}
export interface KeyValueStore {
  getItem(k: string): string | null;
  setItem(k: string, v: string): void;
}
export interface RtdbOptions {
  fetch?: typeof fetch;
  store?: KeyValueStore;
  now?: () => number;
}
export interface Reply {
  status: number;
  json: unknown;
  /** Hora del servidor (cabecera Date), en ms; null si no llega. */
  serverNow: number | null;
}

export const SERVER_TIME = { '.sv': 'timestamp' } as const;
const STORE_KEY = 'chessome.online.refresh';
const MARGIN_MS = 5 * 60 * 1000;

export class Rtdb {
  private readonly f: typeof fetch;
  private readonly store?: KeyValueStore;
  private readonly now: () => number;
  private current: Session | null = null;
  private pending: Promise<Session> | null = null;
  private readonly base: string;

  constructor(private readonly cfg: FirebaseConfig, opts: RtdbOptions = {}) {
    this.f = opts.fetch ?? ((...a) => fetch(...a));
    this.store = opts.store;
    this.now = opts.now ?? Date.now;
    this.base = cfg.databaseURL.replace(/\/$/, '');
  }

  /** Sesión válida: la reutiliza, la renueva con el token guardado o abre una anónima nueva. */
  session(): Promise<Session> {
    if (this.current && this.current.expiresAt - this.now() > MARGIN_MS) return Promise.resolve(this.current);
    this.pending ??= this.open().finally(() => (this.pending = null));
    return this.pending;
  }

  private async open(): Promise<Session> {
    const saved = this.store?.getItem(STORE_KEY) || null;
    if (saved) {
      const r = await this.f(`https://securetoken.googleapis.com/v1/token?key=${this.cfg.apiKey}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: `grant_type=refresh_token&refresh_token=${encodeURIComponent(saved)}`,
      });
      if (r.ok) {
        const j = (await r.json()) as { id_token: string; refresh_token: string; user_id: string; expires_in: string };
        this.store?.setItem(STORE_KEY, j.refresh_token);
        return (this.current = { uid: j.user_id, idToken: j.id_token, expiresAt: this.now() + Number(j.expires_in) * 1000 });
      }
    }
    const r = await this.f(`https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${this.cfg.apiKey}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ returnSecureToken: true }),
    });
    const j = (await r.json()) as { idToken?: string; refreshToken?: string; localId?: string; expiresIn?: string; error?: { message?: string } };
    if (!r.ok || !j.idToken || !j.localId) throw new Error(`No se pudo abrir sesión anónima: ${j.error?.message ?? r.status}`);
    this.store?.setItem(STORE_KEY, j.refreshToken ?? '');
    return (this.current = { uid: j.localId, idToken: j.idToken, expiresAt: this.now() + Number(j.expiresIn ?? 3600) * 1000 });
  }

  async request(method: 'GET' | 'PUT' | 'PATCH' | 'DELETE', path: string, body?: unknown, query = ''): Promise<Reply> {
    const s = await this.session();
    const url = `${this.base}/${path}.json?${[query, `auth=${s.idToken}`].filter(Boolean).join('&')}`;
    const r = await this.f(url, { method, body: body === undefined ? undefined : JSON.stringify(body) });
    const text = await r.text();
    let json: unknown = null;
    try {
      json = JSON.parse(text);
    } catch {
      /* vacío */
    }
    const date = r.headers.get('date');
    return { status: r.status, json, serverNow: date ? Date.parse(date) : null };
  }

  /**
   * Escucha en directo una ruta (SSE). Se reconecta sola si se corta y renueva el token antes de que caduque.
   * `onEvent` recibe put/patch; al reconectar llega de nuevo el estado completo (put en «/»).
   */
  stream(path: string, onEvent: (e: SseEvent) => void): { stop: () => void } {
    let stopped = false;
    let ctl: AbortController | null = null;
    let timer: ReturnType<typeof setTimeout> | null = null;
    const run = async () => {
      let wait = 300;
      while (!stopped) {
        try {
          const s = await this.session();
          ctl = new AbortController();
          const renew = Math.max(1000, s.expiresAt - this.now() - MARGIN_MS + 1000);
          timer = setTimeout(() => ctl?.abort(), renew);
          const r = await this.f(`${this.base}/${path}.json?auth=${s.idToken}`, { headers: { Accept: 'text/event-stream' }, signal: ctl.signal });
          if (r.ok && r.body) {
            wait = 300;
            const reader = r.body.getReader();
            const dec = new TextDecoder();
            const p = new SseParser();
            for (;;) {
              const { value, done } = await reader.read();
              if (done) break;
              for (const e of p.push(dec.decode(value, { stream: true }))) if (!stopped) onEvent(e);
            }
          }
        } catch {
          /* cortado: se reconecta */
        }
        if (timer) clearTimeout(timer);
        if (stopped) break;
        await new Promise((res) => setTimeout(res, wait));
        wait = Math.min(wait * 2, 5000);
      }
    };
    void run();
    return {
      stop: () => {
        stopped = true;
        if (timer) clearTimeout(timer);
        ctl?.abort();
      },
    };
  }
}
