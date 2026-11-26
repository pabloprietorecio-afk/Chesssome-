// Pruebas del servidor de partidas. Las de las reglas no necesitan nada; las de la sala de verdad arrancan el
// servidor en local (wrangler dev) o usan el desplegado si se da SERVIDOR=https://… (lo hace el CI tras desplegar).
import { test } from "node:test";
import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { BOT_ID, RateGate, TestBot, assignSeat, cleanCode, relayable } from "./src/sala.js";

test("códigos de sala", () => {
  assert.equal(cleanCode("ab12"), "AB12");
  assert.equal(cleanCode("a"), null);
  assert.equal(cleanCode("ABCD/../x"), null);
});

test("puestos y bandos: el segundo es rival del primero, luego se equilibra", () => {
  assert.deepEqual(assignSeat([], 1), { id: 1, bando: 1 });
  assert.deepEqual(assignSeat([{ id: 1, bando: 1 }], 1), { id: 2, bando: 0 });
  assert.deepEqual(assignSeat([{ id: 1, bando: 1 }, { id: 2, bando: 0 }], 1), { id: 3, bando: 0 });
  assert.deepEqual(assignSeat([{ id: 1, bando: 1 }, { id: 2, bando: 0 }, { id: 3, bando: 0 }], 1), { id: 4, bando: 1 });
  // Hueco libre: se reutiliza el número más bajo.
  assert.equal(assignSeat([{ id: 2, bando: 0 }], 1).id, 1);
  const full = Array.from({ length: 8 }, (_, i) => ({ id: i + 1, bando: i % 2 }));
  assert.equal(assignSeat(full, 0), null);
});

test("solo se reenvían mensajes conocidos y pequeños, con el número de quien los manda", () => {
  assert.deepEqual(relayable('{"t":"e","p":[1,2,3]}', 3), { t: "e", p: [1, 2, 3], de: 3 });
  // Nadie puede hacerse pasar por otro: «de» lo pone el servidor.
  assert.equal(relayable('{"t":"f","de":7}', 2).de, 2);
  assert.equal(relayable('{"t":"hola"}', 1), null);
  assert.equal(relayable("no es json", 1), null);
  assert.equal(relayable("[1,2]", 1), null);
  assert.equal(relayable(JSON.stringify({ t: "e", x: "a".repeat(700) }), 1), null);
});

test("límite de mensajes por segundo", () => {
  const gate = new RateGate(3);
  assert.ok(gate.allow(1, 1000) && gate.allow(1, 1100) && gate.allow(1, 1200));
  assert.equal(gate.allow(1, 1300), false);
  assert.ok(gate.allow(2, 1300));
  assert.ok(gate.allow(1, 2000));
});

test("bot de prueba: se mueve, apunta, dispara, muere y vuelve", () => {
  let r = 0.3;
  const bot = new TestBot(1, () => r);
  let states = 0;
  let shots = 0;
  bot.heard({ t: "e", de: 1, p: [0, 0, 60] });
  for (let i = 0; i < 100; i++) {
    for (const m of bot.tick(0.1)) {
      if (m.t === "e") states += 1;
      if (m.t === "f") {
        shots += 1;
        assert.equal(m.de, BOT_ID);
        assert.ok(Math.abs(Math.hypot(...m.d) - 1) < 0.01, "dirección unitaria");
      }
    }
  }
  assert.ok(states >= 95, `estado a 10 por segundo (${states})`);
  assert.ok(shots >= 1, "dispara al jugador");
  const killed = bot.heard({ t: "i", de: 1, a: BOT_ID, d: 150 });
  assert.deepEqual(killed, [{ t: "m", de: BOT_ID, por: 1 }]);
  assert.equal(bot.tick(1).length, 0, "muerto no manda nada");
  const back = bot.tick(5);
  assert.equal(back[0].t, "v");
  assert.equal(bot.hp, 100);
});

// ---- Sala de verdad ----

async function withServer(run) {
  if (process.env.SERVIDOR) return run(process.env.SERVIDOR.replace(/\/$/, ""));
  const port = 8800 + Math.floor(Math.random() * 100);
  const dev = spawn("npx", ["wrangler", "dev", "--port", String(port), "--ip", "127.0.0.1"], {
    stdio: ["ignore", "pipe", "pipe"],
    detached: true,
    env: { ...process.env, WRANGLER_SEND_METRICS: "false" },
  });
  let log = "";
  dev.stdout.on("data", (d) => (log += d));
  dev.stderr.on("data", (d) => (log += d));
  try {
    const base = `http://127.0.0.1:${port}`;
    for (let i = 0; i < 120; i++) {
      try {
        const r = await fetch(base + "/");
        if (r.ok) break;
      } catch {}
      await sleep(500);
    }
    await run(base);
  } catch (e) {
    console.log(log.slice(-3000));
    throw e;
  } finally {
    // wrangler arranca más procesos (workerd): se para el grupo entero.
    try {
      process.kill(-dev.pid, "SIGTERM");
    } catch {}
  }
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function join(base, code, query = "") {
  const url = base.replace(/^http/, "ws") + `/sala/${code}${query}`;
  const ws = new WebSocket(url);
  const inbox = [];
  const waiters = [];
  ws.addEventListener("message", (ev) => {
    const msg = JSON.parse(ev.data);
    inbox.push(msg);
    for (const w of [...waiters]) {
      if (w.when(msg)) {
        waiters.splice(waiters.indexOf(w), 1);
        w.resolve(msg);
      }
    }
  });
  const opened = new Promise((resolve, reject) => {
    ws.addEventListener("open", resolve, { once: true });
    ws.addEventListener("error", reject, { once: true });
  });
  return {
    ws,
    inbox,
    opened,
    send: (m) => ws.send(JSON.stringify(m)),
    wait(when, ms = 8000) {
      const found = inbox.find(when);
      if (found) return Promise.resolve(found);
      return new Promise((resolve, reject) => {
        const w = { when, resolve };
        waiters.push(w);
        setTimeout(() => reject(new Error("no llegó el mensaje esperado; recibidos: " + JSON.stringify(inbox.slice(-5)))), ms);
      });
    },
  };
}

test("sala: dos jugadores se ven, se reenvía el estado y el ping responde", { timeout: 90000 }, async () => {
  await withServer(async (base) => {
    const code = "T" + Math.random().toString(36).slice(2, 7).toUpperCase();
    const a = join(base, code, "?frente=2&bando=1");
    await a.opened;
    const helloA = await a.wait((m) => m.t === "hola");
    assert.equal(helloA.id, 1);
    assert.equal(helloA.bando, 1);
    assert.equal(helloA.frente, 2);
    assert.ok(helloA.semilla > 0);

    // El segundo recibe la misma sala aunque pida otra cosa.
    const b = join(base, code, "?frente=0&bando=1");
    await b.opened;
    const helloB = await b.wait((m) => m.t === "hola");
    assert.equal(helloB.id, 2);
    assert.equal(helloB.bando, 0);
    assert.equal(helloB.frente, 2);
    assert.equal(helloB.semilla, helloA.semilla);
    assert.deepEqual(helloB.jugadores, [{ id: 1, bando: 1 }]);
    await a.wait((m) => m.t === "entra" && m.id === 2);

    a.send({ t: "e", s: 1, p: [1, 0, 2], r: 0.5 });
    const seen = await b.wait((m) => m.t === "e");
    assert.equal(seen.de, 1);
    assert.deepEqual(seen.p, [1, 0, 2]);
    // No se reenvían mensajes desconocidos.
    a.send({ t: "trampa" });
    a.send({ t: "f", o: [0, 2, 0], d: [0, 0, -1] });
    await b.wait((m) => m.t === "f");
    assert.equal(b.inbox.some((m) => m.t === "trampa"), false);
    // Quien manda no recibe su propio mensaje.
    await sleep(300);
    assert.equal(a.inbox.some((m) => m.t === "e" || m.t === "f"), false);

    const t0 = Date.now();
    // Como lo manda Godot (JSON.stringify ordena las claves): «c» antes que «t».
    b.ws.send(JSON.stringify({ c: t0, t: "ping" }));
    const pong = await b.wait((m) => m.t === "pong");
    assert.equal(pong.c, t0);
    console.log(`  ping al servidor: ${Date.now() - t0} ms`);

    b.ws.close();
    await a.wait((m) => m.t === "sale" && m.id === 2);
    a.ws.close();
  });
});

test("sala con bot de prueba: el bot se presenta, manda su estado y vuelve tras morir", { timeout: 90000 }, async () => {
  await withServer(async (base) => {
    const code = "B" + Math.random().toString(36).slice(2, 7).toUpperCase();
    const a = join(base, code, "?frente=0&bando=0&bot=1");
    await a.opened;
    const hello = await a.wait((m) => m.t === "hola");
    assert.equal(hello.bot, true);
    assert.deepEqual(hello.jugadores, [{ id: BOT_ID, bando: 1, bot: true }]);
    await a.wait((m) => m.t === "yo" && m.de === BOT_ID);
    a.send({ t: "e", s: 1, p: [0, 0, 20] });
    await a.wait((m) => m.t === "e" && m.de === BOT_ID);
    a.send({ t: "i", a: BOT_ID, d: 200 });
    await a.wait((m) => m.t === "m" && m.de === BOT_ID && m.por === 1);
    await a.wait((m) => m.t === "v" && m.de === BOT_ID, 9000);
    a.ws.close();
  });
});
