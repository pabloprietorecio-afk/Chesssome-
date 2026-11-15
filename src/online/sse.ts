/** Lector de Server-Sent Events de Firebase Realtime Database (eventos put, patch, keep-alive, cancel y auth_revoked). */
export interface SseEvent {
  event: string;
  data: unknown;
}

export class SseParser {
  private buf = '';

  push(text: string): SseEvent[] {
    this.buf += text.replace(/\r\n/g, '\n');
    const out: SseEvent[] = [];
    let i: number;
    while ((i = this.buf.indexOf('\n\n')) >= 0) {
      const block = this.buf.slice(0, i);
      this.buf = this.buf.slice(i + 2);
      let event = '';
      let data = '';
      for (const line of block.split('\n')) {
        if (line.startsWith('event:')) event = line.slice(6).trim();
        else if (line.startsWith('data:')) data += line.slice(5).trim();
      }
      if (!event) continue;
      let parsed: unknown = null;
      try {
        parsed = data ? JSON.parse(data) : null;
      } catch {
        parsed = null;
      }
      out.push({ event, data: parsed });
    }
    return out;
  }
}

/** Copia local de los datos que se están escuchando: aplica los eventos put/patch en su ruta. */
export function applyEvent(root: unknown, e: SseEvent): unknown {
  if (e.event !== 'put' && e.event !== 'patch') return root;
  const d = e.data as { path?: string; data?: unknown } | null;
  if (!d || typeof d.path !== 'string') return root;
  const set = (base: unknown, path: string, value: unknown): unknown => {
    const parts = path.split('/').filter(Boolean);
    if (parts.length === 0) return value;
    const top: Record<string, unknown> = base && typeof base === 'object' ? { ...(Array.isArray(base) ? Object.fromEntries(base.map((v, k) => [k, v]).filter(([, v]) => v != null)) : (base as Record<string, unknown>)) } : {};
    let cur = top;
    for (let k = 0; k < parts.length - 1; k++) {
      const next = cur[parts[k]];
      const copy: Record<string, unknown> = next && typeof next === 'object' ? { ...(next as Record<string, unknown>) } : {};
      cur[parts[k]] = copy;
      cur = copy;
    }
    const last = parts[parts.length - 1];
    if (value === null || value === undefined) delete cur[last];
    else cur[last] = value;
    return top;
  };
  if (e.event === 'put') return set(root, d.path, d.data);
  let r = root;
  for (const [k, v] of Object.entries((d.data ?? {}) as Record<string, unknown>)) r = set(r, `${d.path}/${k}`, v);
  return r;
}
