/** Identificador de partida: hora UTC con segundos + trozo aleatorio. Ordena cronológicamente por clave. */
export function newGameId(now: Date = new Date(), rand: () => number = Math.random): string {
  const p = (n: number) => String(n).padStart(2, '0');
  const r = Math.floor(rand() * 36 ** 6).toString(36).padStart(6, '0');
  return `${now.getUTCFullYear()}${p(now.getUTCMonth() + 1)}${p(now.getUTCDate())}-${p(now.getUTCHours())}${p(now.getUTCMinutes())}${p(now.getUTCSeconds())}-${r}`;
}

/** El color sale de la paridad de la hora del servidor al unirse el rival: par, el creador juega con blancas. */
export function colorOf(unidoEn: number, role: 'creador' | 'rival'): 'w' | 'b' {
  const creatorWhite = unidoEn % 2 === 0;
  return (role === 'creador') === creatorWhite ? 'w' : 'b';
}

/** Una partida abierta sigue viva si su latido es reciente respecto al reloj del servidor. */
export function isFresh(latido: unknown, serverNow: number, maxAgeMs = 30000): boolean {
  return typeof latido === 'number' && Math.abs(serverNow - latido) <= maxAgeMs;
}
