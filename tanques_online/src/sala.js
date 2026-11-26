// Reglas de una sala de A Tank Story online (prueba): quién entra, en qué bando y qué mensajes se reenvían.
// Funciones puras: las usa el Durable Object (index.js) y las prueban los tests (test.mjs).

export const MAX_PLAYERS = 8;
// El bot de prueba del servidor lleva siempre este número (los jugadores, del 1 al 8).
export const BOT_ID = 9;
export const MAX_MESSAGE = 600;
// Mensajes por segundo que se le aceptan a cada jugador (el juego manda 15 de estado y alguno suelto).
export const MAX_RATE = 40;
// Lo que se reenvía: estado (e), disparo (f), impacto (i), muerto (m), vuelve a la vida (v) y presentación (yo).
export const RELAYED = new Set(["e", "f", "i", "m", "v", "yo"]);

const CODE = /^[A-Z0-9]{3,8}$/;
export const cleanCode = (v) => {
  const code = String(v ?? "").toUpperCase();
  return CODE.test(code) ? code : null;
};

export const cleanChoice = (v, max, fallback = 0) => {
  const n = Number.parseInt(String(v ?? ""), 10);
  return Number.isInteger(n) && n >= 0 && n <= max ? n : fallback;
};

// Semilla del mapa: positiva y de 31 bits (el juego la usa como semilla de su generador).
export const newSeed = (rand = Math.random) => 1 + Math.floor(rand() * 2147483646);

// Puesto de quien entra: el número libre más bajo y el bando con menos tanques (a igualdad, el contrario del
// que creó la sala, para que el segundo jugador siempre sea rival del primero).
export function assignSeat(seated, hostSide) {
  const taken = new Set(seated.map((s) => s.id));
  let id = 0;
  for (let n = 1; n <= MAX_PLAYERS; n++) {
    if (!taken.has(n)) {
      id = n;
      break;
    }
  }
  if (id === 0) return null;
  if (seated.length === 0) return { id, bando: hostSide };
  const count = [0, 0];
  for (const s of seated) count[s.bando] += 1;
  let bando = 1 - hostSide;
  if (count[hostSide] < count[1 - hostSide]) bando = hostSide;
  return { id, bando };
}

// Mensaje de un jugador listo para reenviar (con su número en «de»), o null si no vale.
export function relayable(text, from) {
  if (typeof text !== "string" || text.length > MAX_MESSAGE) return null;
  let msg;
  try {
    msg = JSON.parse(text);
  } catch {
    return null;
  }
  if (msg === null || typeof msg !== "object" || Array.isArray(msg) || !RELAYED.has(msg.t)) return null;
  msg.de = from;
  return msg;
}

// Cuenta de mensajes por segundo de cada jugador: true si este aún cabe.
export class RateGate {
  constructor(limit = MAX_RATE) {
    this.limit = limit;
    this.windows = new Map();
  }
  allow(id, now) {
    const second = Math.floor(now / 1000);
    const w = this.windows.get(id);
    if (!w || w.second !== second) {
      this.windows.set(id, { second, count: 1 });
      return true;
    }
    w.count += 1;
    return w.count <= this.limit;
  }
  forget(id) {
    this.windows.delete(id);
  }
}

// Bot de prueba: un tanque que da vueltas en el centro del campo, apunta al último jugador del que tiene noticias
// y le dispara de vez en cuando. No conoce el mapa (atraviesa lo que haya): solo sirve para probar la conexión
// sin tener a nadie con quien jugar. `tick(dt, now)` devuelve los mensajes que manda.
export class TestBot {
  constructor(bando, rand = Math.random) {
    this.bando = bando;
    this.rand = rand;
    this.center = { x: 0, z: -40 };
    this.radius = 34;
    this.speed = 5.0;
    this.angle = 0;
    this.hp = 100;
    this.deadFor = -1;
    this.target = null;
    this.reload = 3;
    this.seq = 0;
    this.sendEvery = 0.1;
    this.sendDue = 0;
  }

  hello() {
    return { t: "yo", de: BOT_ID, bot: true, n: "BOT", bando: this.bando };
  }

  position() {
    return {
      x: this.center.x + Math.cos(this.angle) * this.radius,
      z: this.center.z + Math.sin(this.angle) * this.radius,
    };
  }

  // Rumbo del juego (Godot): 0 mira al norte (-z); atan2(-dx, -dz).
  static yawTowards(from, to) {
    return Math.atan2(-(to.x - from.x), -(to.z - from.z));
  }

  // Noticias de los jugadores: su estado (para apuntar) y los impactos que le dan.
  heard(msg) {
    const out = [];
    if (msg.t === "e" && Array.isArray(msg.p) && msg.p.length >= 3) {
      this.target = { id: msg.de, x: Number(msg.p[0]) || 0, y: Number(msg.p[1]) || 0, z: Number(msg.p[2]) || 0 };
    } else if (msg.t === "i" && msg.a === BOT_ID && this.deadFor < 0) {
      this.hp -= Math.max(0, Math.min(200, Number(msg.d) || 0));
      if (this.hp <= 0) {
        this.deadFor = 0;
        out.push({ t: "m", de: BOT_ID, por: msg.de });
      }
    } else if (msg.t === "m" && this.target && msg.de === this.target.id) {
      this.target = null;
    }
    return out;
  }

  tick(dt) {
    const out = [];
    if (this.deadFor >= 0) {
      this.deadFor += dt;
      if (this.deadFor < 5) return out;
      this.deadFor = -1;
      this.hp = 100;
      this.angle += Math.PI;
      out.push({ t: "v", de: BOT_ID });
    }
    this.angle += (this.speed / this.radius) * dt;
    const pos = this.position();
    // Avanza en sentido antihorario: su rumbo es la tangente del círculo.
    const ahead = {
      x: this.center.x + Math.cos(this.angle + 0.05) * this.radius,
      z: this.center.z + Math.sin(this.angle + 0.05) * this.radius,
    };
    const hull = TestBot.yawTowards(pos, ahead);
    let turret = 0;
    let distance = Infinity;
    if (this.target) {
      const aim = TestBot.yawTowards(pos, this.target);
      turret = aim - hull;
      distance = Math.hypot(this.target.x - pos.x, this.target.z - pos.z);
    }
    this.reload -= dt;
    if (this.target && this.reload <= 0 && distance < 260) {
      this.reload = 4 + this.rand() * 2;
      const hits = distance < 200 && this.rand() < 0.5;
      const spread = hits ? 0 : (this.rand() < 0.5 ? -1 : 1) * (0.04 + this.rand() * 0.04);
      const from = { x: pos.x, y: 2.2, z: pos.z };
      const to = { x: this.target.x, y: this.target.y + 1.2, z: this.target.z };
      const flat = Math.hypot(to.x - from.x, to.z - from.z) || 1;
      const yaw = Math.atan2(to.x - from.x, to.z - from.z) + spread;
      const dir = [Math.sin(yaw) * flat, to.y - from.y, Math.cos(yaw) * flat];
      const len = Math.hypot(dir[0], dir[1], dir[2]) || 1;
      out.push({ t: "f", de: BOT_ID, o: [round(from.x), from.y, round(from.z)], d: dir.map((v) => round(v / len, 4)) });
      if (hits) out.push({ t: "i", de: BOT_ID, a: this.target.id, d: 18 });
    }
    this.sendDue -= dt;
    if (this.sendDue <= 0) {
      this.sendDue = this.sendEvery;
      this.seq += 1;
      // y: null = sobre el terreno (el bot no conoce el relieve; lo pone el juego).
      out.push({ t: "e", de: BOT_ID, s: this.seq, k: Date.now(), p: [round(pos.x), null, round(pos.z)], r: round(hull, 3), ty: round(turret, 3), gp: 0, hp: this.hp });
    }
    return out;
  }
}

const round = (v, digits = 2) => {
  const k = 10 ** digits;
  return Math.round(v * k) / k;
};
