// Saldo de la API de Claude agotado: Anthropic contesta 400 «Your credit balance is too low…» (no 402). Se reconoce
// para no reintentar en vano (el 400 se reintentaba con más tokens) y para que la app diga «tutor no disponible» en
// vez de «sin conexión» (22 nov).
export async function noCredit(r) {
  if (r.status !== 400) return false;
  try {
    return /credit balance/i.test(await r.clone().text());
  } catch {
    return false;
  }
}

export function noCreditError() {
  return Object.assign(new Error("tutor no disponible (sin saldo)"), { status: 503 });
}
