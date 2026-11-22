// Stockfish propio del profesor (Dockerfile + servidor.py), en un contenedor de Cloudflare. No tiene dirección
// pública: el servidor del profesor (worker/src) llega aquí por un «service binding» (MOTOR).
import { Container, getContainer } from "@cloudflare/containers";

export class Motor extends Container {
  defaultPort = 8080;
  // Se apaga tras 3 minutos sin consultas (la memoria se paga mientras está encendido).
  sleepAfter = "3m";
}

export default {
  async fetch(request, env) {
    return getContainer(env.MOTOR, "motor").fetch(request);
  },
};
