// Servidor de partidas de A Tank Story online (prueba, 26 nov): un Durable Object por sala que reenvía los mensajes
// de cada jugador a los demás por WebSocket. No simula la partida: cada móvil manda la posición de su tanque y
// sus disparos, y decide sus impactos (ver docs en el repositorio del juego, «Online (prueba)»).
//
//   GET /                                  → {ok: true}
//   GET /sala/<CÓDIGO>?frente=0..2&bando=0..1&bot=0|1   (WebSocket)
//       El primero que entra crea la sala: elige frente, bando y si hay bot de prueba; la semilla del mapa la
//       sortea el servidor. Los demás reciben lo mismo en «hola». Cuando sale el último, la sala se borra.
//
// Mensajes del servidor: hola {id, bando, frente, semilla, jugadores:[{id, bando, bot}]}, entra {id, bando},
// sale {id}, pong {c} (respuesta inmediata a ping {c}, para medir el retraso). El resto, de los jugadores, con
// su número en «de» (ver sala.js).

import { BOT_ID, MAX_PLAYERS, RateGate, TestBot, assignSeat, cleanChoice, cleanCode, newSeed, relayable } from "./sala.js";

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname === "/" || url.pathname === "") {
      return Response.json({ ok: true, servicio: "atankstory-online" });
    }
    const match = url.pathname.match(/^\/sala\/([^/]+)$/);
    if (!match) return new Response("no encontrado", { status: 404 });
    const code = cleanCode(match[1]);
    if (!code) return new Response("código de sala no válido", { status: 400 });
    if (request.headers.get("Upgrade") !== "websocket") return new Response("se espera un WebSocket", { status: 426 });
    const stub = env.SALAS.get(env.SALAS.idFromName(code));
    return stub.fetch(request);
  },
};

export class Sala {
  constructor(ctx, env) {
    this.ctx = ctx;
    this.env = env;
    this.gate = new RateGate();
    this.bot = null;
    this.botTimer = null;
    this.botLast = 0;
  }

  // Jugadores conectados (sin el que se está yendo).
  seated(except = null) {
    const list = [];
    for (const ws of this.ctx.getWebSockets()) {
      if (ws === except) continue;
      const seat = ws.deserializeAttachment();
      if (seat && seat.id) list.push({ ws, id: seat.id, bando: seat.bando });
    }
    return list;
  }

  async fetch(request) {
    const url = new URL(request.url);
    const humans = this.seated();
    let room = await this.ctx.storage.get("sala");
    if (humans.length === 0 || !room) {
      room = {
        frente: cleanChoice(url.searchParams.get("frente"), 2),
        bando: cleanChoice(url.searchParams.get("bando"), 1),
        bot: url.searchParams.get("bot") === "1",
        semilla: newSeed(),
        creada: Date.now(),
      };
      await this.ctx.storage.put("sala", room);
      this.stopBot();
    }
    if (humans.length >= MAX_PLAYERS) return new Response("sala llena", { status: 409 });
    const others = humans.map((h) => ({ id: h.id, bando: h.bando }));
    if (room.bot) others.push({ id: BOT_ID, bando: 1 - room.bando, bot: true });
    // El bot cuenta para el reparto de bandos, pero no ocupa número de jugador.
    const seat = assignSeat(others.map((o) => ({ id: o.id === BOT_ID ? 0 : o.id, bando: o.bando })), room.bando);
    if (!seat) return new Response("sala llena", { status: 409 });

    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);
    this.ctx.acceptWebSocket(server);
    server.serializeAttachment({ id: seat.id, bando: seat.bando });
    server.send(JSON.stringify({ t: "hola", id: seat.id, bando: seat.bando, frente: room.frente, semilla: room.semilla, bot: room.bot, jugadores: others }));
    const hello = JSON.stringify({ t: "entra", id: seat.id, bando: seat.bando });
    for (const h of humans) safeSend(h.ws, hello);
    if (room.bot && !this.bot) this.startBot(1 - room.bando);
    else if (this.bot) safeSend(server, JSON.stringify(this.bot.hello()));
    return new Response(null, { status: 101, webSocket: client });
  }

  async webSocketMessage(ws, message) {
    const seat = ws.deserializeAttachment();
    if (!seat || typeof message !== "string") return;
    if (!this.gate.allow(seat.id, Date.now())) return;
    if (message.startsWith('{"t":"ping"')) {
      try {
        const ping = JSON.parse(message);
        safeSend(ws, JSON.stringify({ t: "pong", c: ping.c }));
      } catch {}
      return;
    }
    const msg = relayable(message, seat.id);
    if (!msg) return;
    const text = JSON.stringify(msg);
    for (const other of this.seated(ws)) safeSend(other.ws, text);
    if (this.bot) this.botSay(this.bot.heard(msg));
  }

  async webSocketClose(ws, code) {
    await this.leave(ws);
    try {
      ws.close(code === 1005 ? 1000 : code, "adiós");
    } catch {}
  }

  async webSocketError(ws) {
    await this.leave(ws);
  }

  async leave(ws) {
    const seat = ws.deserializeAttachment();
    if (!seat || !seat.id) return;
    ws.serializeAttachment({});
    this.gate.forget(seat.id);
    const rest = this.seated(ws);
    const bye = JSON.stringify({ t: "sale", id: seat.id });
    for (const other of rest) safeSend(other.ws, bye);
    if (rest.length === 0) {
      this.stopBot();
      await this.ctx.storage.deleteAll();
    }
  }

  startBot(bando) {
    this.bot = new TestBot(bando);
    this.botLast = Date.now();
    this.botSay([this.bot.hello()]);
    this.botTimer = setInterval(() => {
      const now = Date.now();
      const dt = Math.min(0.5, (now - this.botLast) / 1000);
      this.botLast = now;
      if (this.seated().length === 0) {
        this.stopBot();
        return;
      }
      this.botSay(this.bot.tick(dt));
    }, 100);
  }

  stopBot() {
    if (this.botTimer) clearInterval(this.botTimer);
    this.botTimer = null;
    this.bot = null;
  }

  botSay(messages) {
    if (!messages.length) return;
    const players = this.seated();
    for (const msg of messages) {
      const text = JSON.stringify(msg);
      for (const p of players) safeSend(p.ws, text);
    }
  }
}

function safeSend(ws, text) {
  try {
    ws.send(text);
  } catch {}
}
