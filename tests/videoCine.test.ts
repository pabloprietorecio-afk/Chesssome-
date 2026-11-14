import { describe, expect, it } from 'vitest';
import pack from '../src/data/videocine.pack.json';
import { CLIPS } from '../pipeline/video-clips';
import {
  EPS,
  canAutoPause,
  defaultStartPly,
  direct,
  fenAfter,
  gapPlies,
  lessonPositions,
  initialDirector,
  judgeAnswer,
  marksOf,
  marksProblems,
  moveAt,
  plyAt,
  quickSteps,
  referenceMove,
  replay,
  run,
  syncCap,
  syncGapAt,
  syncProblems,
  syncRemoveFrom,
  syncSetAt,
  watchUrl,
  withMarks,
  youtubeId,
  type Clip,
  type Command,
  type DirectorEvent,
  type DirectorState,
  type PlayerAdapter,
  type VideoCinePack,
} from '../src/core/videoCine';

const PACK = pack as unknown as VideoCinePack;
const ding = PACK.clips.find((c) => c.id === 'ding-gukesh-2024-g14')!;
const dingQs = ding.stops.flatMap((st) => st.questions);

describe('paquete de clips de vídeo', () => {
  it('está al día con las fuentes (si falla: npx tsx pipeline/build-video-cine.ts)', () => {
    expect(PACK.clips.map((c) => c.id)).toEqual(CLIPS.map((c) => c.id));
    for (const src of CLIPS) {
      const clip = PACK.clips.find((c) => c.id === src.id)!;
      const { moves, stops, ...meta } = src;
      const { stops: packedStops, tail, plies, clockLabels: _labels, timeline: _timeline, ...packedMeta } = clip;
      expect(packedMeta).toEqual(meta);
      const game = replay(moves, src.id);
      expect(plies).toBe(game.length);
      expect(packedStops.length).toBe(stops.length);
      stops.forEach((st, i) => {
        expect(packedStops[i].at).toBe(st.at);
        st.questions.forEach((q, k) => {
          const pq = packedStops[i].questions[k];
          expect({ ply: pq.ply, question: pq.question, hint: pq.hint, why: pq.why }).toEqual({ ply: q.ply, question: q.question, hint: q.hint, why: q.why });
          // La posición sale de reproducir la partida, no de un FEN escrito a mano.
          expect(pq.fen).toBe(game[q.ply - 2].fenAfter);
          expect(pq.played.san).toBe(game[q.ply - 1].san);
        });
      });
      expect(tail.length).toBe(game.length - stops.at(-1)!.questions.at(-1)!.ply);
      // El trozo de partida del tablero sincronizado llega hasta el final y coincide con la partida.
      expect(clip.timeline.fromPly + clip.timeline.moves.length - 1).toBe(game.length);
      clip.timeline.moves.forEach((m, i) => expect(m).toEqual(game[clip.timeline.fromPly - 1 + i]));
      expect(fenAfter(clip, defaultStartPly(clip))).toBe(packedStops[0].questions[0].fen);
    }
  });

  it('cada pregunta lleva el veredicto de todas las jugadas legales, sin repetir', () => {
    for (const clip of PACK.clips)
      for (const st of clip.stops)
        for (const q of st.questions) {
          expect(new Set(q.verdicts.map((v) => v.uci)).size).toBe(q.verdicts.length);
          expect(q.verdicts.some((v) => v.uci === q.playedUci)).toBe(true);
          expect(q.verdicts.length).toBeGreaterThan(1);
        }
  });

  it('solo se ofrecen vídeos de canales oficiales y los clips sin marcas no se dan por verificados', () => {
    for (const clip of PACK.clips) {
      expect(clip.video.official).toBe(true);
      expect(clip.video.id).toMatch(/^[\w-]{11}$/);
      if (clip.marks === 'verified') {
        expect(canAutoPause(clip)).toBe(true);
        expect(clip.video.duration).not.toBeNull();
      }
    }
  });

  it('Ding–Gukesh: marcas estimadas con los relojes y comprobadas en el vídeo', () => {
    // Una pausa por pregunta: la primera la comprobó Pablo; las otras dos salen de los relojes, sin comprobar.
    expect(ding.marks).toBe('pending');
    expect(marksOf(ding)).toEqual({ start: 3.5, stops: [138, 144.5, 214], end: 233.07, duration: 437, sync: ding.sync });
    expect(marksProblems(marksOf(ding))).toEqual([]);
    expect(syncProblems(ding, ding.sync!, marksOf(ding))).toEqual([]);
    expect(canAutoPause(ding)).toBe(true);
  });

  it('Ding–Gukesh: en las tres preguntas solo gana la jugada de la partida', () => {
    const qs = dingQs;
    expect(qs.map((q) => q.played.san)).toEqual(['Rxf2', 'Bd5', 'Ke5']);
    for (const q of qs) {
      expect(q.target).toBe('win');
      expect(q.playedCls).toBe('keeps');
      expect(q.verdicts.filter((v) => v.cls === 'keeps').map((v) => v.uci)).toEqual([q.playedUci]);
    }
    // Una pausa por pregunta: el vídeo enseña las jugadas intermedias, así que no hay puente en el tablero.
    expect(qs.map((q) => q.bridge.length)).toEqual([0, 0, 0]);
    expect(qs[0].lead?.san).toBe('Rf2');
  });
});

describe('respuestas', () => {
  const [q1, , q3] = dingQs;
  it('la jugada de la partida devuelve la explicación propia', () => {
    const r = judgeAnswer(q1, q1.playedUci);
    expect(r.outcome).toBe('answer');
    expect(r.text).toBe(q1.why);
  });
  it('distingue entre dejar escapar la victoria y perder', () => {
    const draw = judgeAnswer(q3, 'd5d6');
    expect(draw.outcome).toBe('spoils');
    expect(draw.text).toContain('deja escapar la victoria');
    const lose = judgeAnswer(q3, 'd5c6');
    expect(lose.outcome).toBe('spoils');
    expect(lose.text).toContain('Rc6 pierde');
    expect(lose.line).toMatch(/^59\.Rf4/);
  });
  it('una jugada sin análisis no inventa nada', () => {
    expect(judgeAnswer(q1, 'a1a2').outcome).toBe('unknown');
  });
});

describe('utilidades', () => {
  it('extrae el identificador de YouTube', () => {
    expect(youtubeId('W9JtcW_0Sr8')).toBe('W9JtcW_0Sr8');
    expect(youtubeId('https://www.youtube.com/watch?v=W9JtcW_0Sr8&t=12s')).toBe('W9JtcW_0Sr8');
    expect(youtubeId('https://youtu.be/W9JtcW_0Sr8')).toBe('W9JtcW_0Sr8');
    expect(youtubeId('https://www.youtube-nocookie.com/embed/W9JtcW_0Sr8?start=3')).toBe('W9JtcW_0Sr8');
    expect(youtubeId('https://www.youtube.com/live/W9JtcW_0Sr8')).toBe('W9JtcW_0Sr8');
    expect(youtubeId('https://example.com/video')).toBeNull();
  });
  it('enlaza al segundo indicado', () => {
    expect(watchUrl(ding.video)).toBe('https://www.youtube.com/watch?v=W9JtcW_0Sr8');
    expect(watchUrl(ding.video, 83.7)).toBe('https://www.youtube.com/watch?v=W9JtcW_0Sr8&t=83s');
  });
  it('valida el orden de las marcas', () => {
    expect(marksProblems({ start: 0, stops: [12.3], end: 90, duration: 430 })).toEqual([]);
    expect(marksProblems({ start: 20, stops: [12.3], end: 90, duration: 430 })).toHaveLength(1);
    expect(marksProblems({ start: 0, stops: [null], end: null, duration: null })).toEqual(['Falta alguna pausa.']);
    expect(marksProblems({ start: 0, stops: [500], end: null, duration: 430 })).toEqual(['Hay marcas más allá del final del vídeo.']);
  });
  it('un clip sin marcas no puede pausar solo; con marcas locales, sí', () => {
    const unmarked = withMarks(ding, { start: null, stops: [null, null, null], end: null, duration: null });
    expect(canAutoPause(unmarked)).toBe(false);
    const marked = withMarks(ding, { start: 0, stops: [8.4, 20, 40], end: 120, duration: 431 });
    expect(canAutoPause(marked)).toBe(true);
    expect(marksOf(marked)).toEqual({ start: 0, stops: [8.4, 20, 40], end: 120, duration: 431, sync: ding.sync });
  });
});

// ───────────── Director ─────────────

type MiniClip = Pick<Clip, 'start' | 'end' | 'stops' | 'video'>;
const mini = (over: Partial<MiniClip> = {}): MiniClip => ({
  start: 10,
  end: 60,
  video: { ...ding.video, duration: 100 },
  stops: [
    { at: 20, questions: dingQs },
    { at: 40, questions: dingQs },
  ],
  ...over,
});

function drive(clip: MiniClip, events: DirectorEvent[], from: DirectorState = initialDirector()): { state: DirectorState; commands: Command[][] } {
  let state = from;
  const commands: Command[][] = [];
  for (const e of events) {
    const r = direct(clip, state, e);
    state = r.state;
    commands.push(r.commands);
  }
  return { state, commands };
}
const tick = (time: number, now: number, playing = true, duration = 100): DirectorEvent => ({ type: 'tick', time, duration, playing, now });

describe('director', () => {
  it('modo película: carga en el inicio y pausa justo antes de la marca', () => {
    const r = drive(mini(), [{ type: 'start', mode: 'film' }, tick(10.2, 0), tick(19.5, 100), tick(20 - EPS + 0.01, 200)]);
    expect(r.commands).toEqual([[{ type: 'cue', at: 10 }], [], [], [{ type: 'pause' }]]);
    expect(r.state.phase).toBe('asking');
    expect(r.state.stop).toBe(0);
  });

  it('no hace nada mientras el vídeo está parado (el jugador aún no ha pulsado ▶)', () => {
    const r = drive(mini(), [{ type: 'start', mode: 'film' }, tick(20, 0, false), tick(20, 100, false)]);
    expect(r.state.phase).toBe('watching');
    expect(r.commands.slice(1)).toEqual([[], []]);
  });

  it('tras ordenar la pausa da un margen, reintenta una vez y después respeta al jugador', () => {
    const start = drive(mini(), [{ type: 'start', mode: 'film' }, tick(19.95, 1000)]);
    // El reproductor tarda en parar: dentro del margen no pasa nada.
    const grace = drive(mini(), [tick(20.1, 1300)], start.state);
    expect(grace.commands).toEqual([[]]);
    expect(grace.state.phase).toBe('asking');
    // Sigue reproduciendo pasado el margen: un único reintento.
    const retry = drive(mini(), [tick(20.3, 1700)], grace.state);
    expect(retry.commands).toEqual([[{ type: 'pause' }]]);
    // Si aun así sigue, es que el jugador quiere ver: no se le vuelve a parar.
    const resumed = drive(mini(), [tick(20.6, 2000), tick(21.2, 2400)], retry.state);
    expect(resumed.commands).toEqual([[], []]);
    expect(resumed.state.phase).toBe('reveal');
    expect(resumed.state.missed).toBe('resumed');
  });

  it('si el jugador pulsa ▶ durante la pregunta, sigue viendo y puede volver a la pregunta', () => {
    const asking = drive(mini(), [{ type: 'start', mode: 'film' }, tick(19.95, 0), tick(19.97, 300, false)]);
    const resumed = drive(mini(), [tick(20.4, 9000)], asking.state);
    expect(resumed.state.phase).toBe('reveal');
    expect(resumed.state.missed).toBe('resumed');
    expect(resumed.commands).toEqual([[]]);
    const back = drive(mini(), [{ type: 'back', now: 9500 }], resumed.state);
    expect(back.state.phase).toBe('asking');
    expect(back.commands).toEqual([[{ type: 'pause' }]]);
  });

  it('al revelar reproduce sin saltar si el vídeo está donde se paró, y salta si se movió', () => {
    const asking = drive(mini(), [{ type: 'start', mode: 'film' }, tick(19.95, 0)]).state;
    expect(drive(mini(), [{ type: 'reveal', time: 19.97 }], asking).commands).toEqual([[{ type: 'play' }]]);
    expect(drive(mini(), [{ type: 'reveal', time: 55 }], asking).commands).toEqual([[{ type: 'seek', at: 20 }, { type: 'play' }]]);
    expect(drive(mini(), [{ type: 'reveal', time: null }], asking).commands).toEqual([[{ type: 'seek', at: 20 }, { type: 'play' }]]);
  });

  it('segunda parada y final del clip', () => {
    const r = drive(mini(), [
      { type: 'start', mode: 'film' },
      tick(19.95, 0),
      tick(19.97, 400, false),
      { type: 'reveal', time: 19.97 },
      tick(30, 5000),
      tick(39.9, 15000),
    ]);
    expect(r.state.phase).toBe('asking');
    expect(r.state.stop).toBe(1);
    expect(r.commands.at(-1)).toEqual([{ type: 'pause' }]);
    const end = drive(mini(), [tick(39.95, 15400, false), { type: 'reveal', time: 39.95 }, tick(50, 20000), tick(59.9, 30000), tick(61, 31000)], r.state);
    expect(end.state.phase).toBe('ended');
    expect(end.commands).toEqual([[], [{ type: 'play' }], [], [{ type: 'pause' }], []]);
  });

  it('si el jugador salta por delante de la marca, no se le para; puede volver a la pregunta', () => {
    const r = drive(mini(), [{ type: 'start', mode: 'film' }, tick(25, 0)]);
    expect(r.state.phase).toBe('reveal');
    expect(r.state.missed).toBe('skipped');
    expect(r.commands[1]).toEqual([]);
    const back = drive(mini(), [{ type: 'back', now: 100 }], r.state);
    expect(back.state.phase).toBe('asking');
    expect(back.state.stop).toBe(0);
  });

  it('con un anuncio (duración distinta) no actúa; al volver el vídeo, sí', () => {
    const r = drive(mini(), [{ type: 'start', mode: 'film' }, tick(20, 0, true, 30), tick(25, 100, true, 30)]);
    expect(r.state.phase).toBe('watching');
    expect(r.state.adSuspected).toBe(true);
    expect(r.commands.slice(1)).toEqual([[], []]);
    const after = drive(mini(), [tick(10.1, 31000), tick(19.9, 41000)], r.state);
    expect(after.state.adSuspected).toBe(false);
    expect(after.state.phase).toBe('asking');
  });

  it('modo directo: pregunta sin vídeo y, al revelar, carga el vídeo parado en la marca', () => {
    const r = drive(mini(), [{ type: 'start', mode: 'direct' }, tick(50, 0)]);
    expect(r.state.phase).toBe('asking');
    expect(r.state.videoOn).toBe(false);
    expect(r.commands).toEqual([[], []]);
    const rev = drive(mini(), [{ type: 'reveal', time: null }, tick(20.1, 1000, false), tick(30, 9000), tick(39.9, 19000)], r.state);
    expect(rev.commands[0]).toEqual([{ type: 'cue', at: 20 }]);
    expect(rev.state.phase).toBe('asking');
    expect(rev.state.stop).toBe(1);
  });

  it('sin marcas, el modo película se convierte en directo y la revelación empieza donde pueda', () => {
    const noMarks = mini({ start: null, end: null, stops: [{ at: null, questions: dingQs }] });
    const r = drive(noMarks, [{ type: 'start', mode: 'film' }]);
    expect(r.state.phase).toBe('asking');
    expect(r.state.mode).toBe('direct');
    expect(drive(noMarks, [{ type: 'reveal', time: null }], r.state).commands).toEqual([[{ type: 'cue', at: 0 }]]);
  });

  it('el jugador puede pedir la pregunta sin esperar a la marca; al revelar se salta a la marca', () => {
    const r = drive(mini(), [{ type: 'start', mode: 'film' }, tick(12, 0), { type: 'ask', now: 100 }]);
    expect(r.state.phase).toBe('asking');
    expect(r.commands.at(-1)).toEqual([{ type: 'pause' }]);
    expect(drive(mini(), [{ type: 'reveal', time: 12.1 }], r.state).commands).toEqual([[{ type: 'seek', at: 20 }, { type: 'play' }]]);
    expect(drive(mini(), [{ type: 'finish' }], r.state).state.phase).toBe('ended');
  });

  it('ver el vídeo sin marcas: se carga entero y la pregunta queda a un toque', () => {
    const noMarks = mini({ start: null, end: null, stops: [{ at: null, questions: dingQs }] });
    const r = drive(noMarks, [{ type: 'start', mode: 'free' }, tick(30, 0), tick(90, 5000)]);
    expect(r.commands).toEqual([[{ type: 'cue', at: 0 }], [], []]);
    expect(r.state).toMatchObject({ phase: 'reveal', mode: 'free', stop: 0, videoOn: true, missed: 'skipped' });
    const back = drive(noMarks, [{ type: 'back', now: 6000 }], r.state);
    expect(back.state.phase).toBe('asking');
    expect(back.commands).toEqual([[{ type: 'pause' }]]);
    // Con marcas, «ver el vídeo» es el modo película.
    expect(drive(mini(), [{ type: 'start', mode: 'free' }]).state).toMatchObject({ phase: 'watching', mode: 'film' });
  });

  it('si el vídeo falla, la pregunta sigue funcionando', () => {
    const watching = drive(mini(), [{ type: 'start', mode: 'film' }]).state;
    const err = drive(mini(), [{ type: 'error', code: 150 }], watching);
    expect(err.state.phase).toBe('asking');
    expect(err.state.videoOn).toBe(false);
    expect(err.state.errorCode).toBe(150);
    const asking = drive(mini(), [{ type: 'start', mode: 'direct' }, { type: 'reveal', time: null }]).state;
    expect(drive(mini(), [{ type: 'error', code: 153 }], asking).state.phase).toBe('ended');
  });

  it('simulación: con lecturas cada 100 ms la pausa cae entre 0,12 s antes y 0,1 s después de la marca', () => {
    for (const at of [3.07, 12.34, 20, 41.99]) {
      const clip = mini({ start: 0, end: null, stops: [{ at, questions: dingQs }] });
      // Reproductor simulado: avanza solo mientras reproduce.
      let time = 0;
      let playing = false;
      const log: string[] = [];
      const fake: PlayerAdapter = {
        cue: (t) => { time = t; playing = false; log.push('cue'); },
        play: () => { playing = true; },
        pause: () => { playing = false; log.push(`pause@${time.toFixed(2)}`); },
        seek: (t) => { time = t; },
        snapshot: () => ({ time, duration: 100, playing }),
        destroy: () => undefined,
      };
      let state = initialDirector();
      const send = (e: DirectorEvent) => { const r = direct(clip, state, e); state = r.state; run(fake, r.commands); };
      send({ type: 'start', mode: 'film' });
      fake.play(); // el jugador pulsa ▶
      let pausedAt: number | null = null;
      for (let now = 0; now < 60000 && pausedAt == null; now += 100) {
        if (playing) time += 0.1;
        send({ type: 'tick', ...fake.snapshot()!, now });
        if (state.phase === 'asking') pausedAt = time;
      }
      expect(pausedAt).not.toBeNull();
      expect(pausedAt!).toBeGreaterThanOrEqual(at - EPS - 1e-9);
      expect(pausedAt!).toBeLessThanOrEqual(at + 0.1);
      expect(log.filter((l) => l.startsWith('pause')).length).toBe(1);
    }
  });
});

describe('tablero sincronizado', () => {
  const q1 = dingQs[0].ply;
  // Marcas de ejemplo (el clip del paquete está por marcar).
  const marks = { start: 200, end: 240, stops: [215.5], duration: 437 };
  const pause = marks.stops[0];

  it('por defecto empieza en la posición de la primera pregunta', () => {
    expect(defaultStartPly(ding)).toBe(q1 - 1);
    expect(moveAt(ding, q1)!.san).toBe(dingQs[0].played.san);
    expect(fenAfter(ding, 0)).toMatch(/^rnbqkbnr\/pppppppp/);
    expect(fenAfter(ding, ding.timeline.fromPly - 1)).toBeNull();
  });

  it('cada jugada aparece en su segundo; antes, la posición de partida', () => {
    const sync = { startPly: 109, marks: [{ ply: 110, at: 216 }, { ply: 111, at: 218.5 }] };
    expect(plyAt(sync, 200)).toBe(109);
    expect(plyAt(sync, 215.99)).toBe(109);
    expect(plyAt(sync, 216)).toBe(110);
    expect(plyAt(sync, 230)).toBe(111);
    expect(plyAt(sync, Infinity)).toBe(111);
  });

  it('acepta marcas seguidas, en orden y sin destripar', () => {
    const ok = { startPly: q1 - 1, marks: [{ ply: q1, at: pause }, { ply: q1 + 1, at: pause + 3 }] };
    expect(syncProblems(ding, ok, marks)).toEqual([]);
    expect(syncProblems(ding, { startPly: q1 - 1, marks: [] }, marks)).toEqual([]);
  });

  it('rechaza huecos, desorden, marcas fuera del clip y destripes', () => {
    const at = (ms: { ply: number; at: number }[], startPly = q1 - 1) => syncProblems(ding, { startPly, marks: ms }, marks).join(' ');
    expect(at([{ ply: q1 + 1, at: pause + 1 }])).toMatch(/sin huecos/);
    expect(at([{ ply: q1, at: pause + 3 }, { ply: q1 + 1, at: pause + 1 }])).toMatch(/orden de tiempo/);
    expect(at([{ ply: q1, at: marks.end + 1 }])).toMatch(/después del fin/);
    expect(at([{ ply: q1, at: marks.start - 1 }])).toMatch(/antes del inicio/);
    expect(at([{ ply: q1, at: pause - 0.5 }])).toMatch(/antes de la pausa/);
    expect(at([], q1)).toMatch(/destriparía/);
    expect(at([], ding.timeline.fromPly - 1)).toMatch(/fuera de las jugadas/);
  });

  it('mientras se ve el vídeo, el tablero no pasa de la posición de la próxima pregunta', () => {
    expect(syncCap(ding, { phase: 'watching', stop: 0, mode: 'film' })).toBe(q1 - 1);
    // Tras la primera pausa, el vídeo sigue hasta la siguiente: el tablero no pasa de su posición.
    expect(syncCap(ding, { phase: 'reveal', stop: 0, mode: 'film' })).toBe(dingQs[1].ply - 1);
    expect(syncCap(ding, { phase: 'reveal', stop: 2, mode: 'film' })).toBe(Infinity);
    expect(syncCap(ding, { phase: 'watching', stop: 0, mode: 'free' })).toBe(Infinity);
    const two = { stops: [{ questions: [{ ply: 20 }] }, { questions: [{ ply: 40 }] }] };
    expect(syncCap(two, { phase: 'reveal', stop: 0, mode: 'film' })).toBe(39);
    expect(syncCap(two, { phase: 'ended', stop: 1, mode: 'film' })).toBe(Infinity);
  });

  it('las marcas del tablero viajan con las demás marcas', () => {
    const sync = { startPly: q1 - 1, marks: [{ ply: q1, at: pause }] };
    expect(withMarks(ding, { ...marks, sync }).sync).toEqual(sync);
    expect(withMarks({ ...ding, sync }, { ...marks, sync: null }).sync).toBeUndefined();
    expect(withMarks({ ...ding, sync }, marks).sync).toEqual(sync); // marcas sin tablero: se queda el del clip
  });
});

describe('pregunta en la que la partida tuvo un error (Gukesh–Carlsen, 52…Ce2+??)', () => {
  const gc = PACK.clips.find((c) => c.id === 'gukesh-carlsen-2025-norway-r6-error')!;
  const q = gc.stops[0].questions[0];

  it('la jugada de la partida se presenta como error y una que mantiene el resultado es la respuesta', () => {
    expect(q.played.san).toBe('Ne2+');
    expect(q.playedCls).toBe('spoils');
    expect(judgeAnswer(q, q.playedUci).outcome).toBe('played-error');
    const keep = q.verdicts.find((v) => v.cls === 'keeps')!;
    const a = judgeAnswer(q, keep.uci);
    expect(a.outcome).toBe('answer');
    expect(a.text).toContain(q.why);
  });

  it('«Ver la respuesta» enseña una jugada buena, no la de la partida', () => {
    const ref = referenceMove(q);
    expect(ref.fromGame).toBe(false);
    expect(q.verdicts.find((v) => v.uci === ref.uci)?.cls).toBe('keeps');
    const ding0 = dingQs[0];
    expect(referenceMove(ding0)).toEqual({ uci: ding0.playedUci, san: ding0.played.san, fromGame: true });
  });

  it('la pregunta es de las negras, aunque el tablero se vea desde las blancas', () => {
    expect(q.mover).toBe('b');
    expect(gc.orientation).toBe('w');
  });
});

describe('marcado rápido', () => {
  const gc = PACK.clips.find((c) => c.id === 'gukesh-carlsen-2025-norway-r6-error')!;

  it('los pasos van en el orden del vídeo: inicio, jugadas, pausa antes de la pregunta, fin', () => {
    const steps = quickSteps(gc, 101);
    expect(steps.slice(0, 5)).toEqual([{ kind: 'start' }, { kind: 'ply', ply: 102 }, { kind: 'ply', ply: 103 }, { kind: 'pause', stop: 0 }, { kind: 'ply', ply: 104 }]);
    expect(steps.at(-1)).toEqual({ kind: 'end' });
    expect(steps.length).toBe(1 + (gc.plies - 101) + 1 + 1);
  });

  it('una jugada saltada se marca con la siguiente y se puede quitar', () => {
    let sy = syncSetAt({ startPly: 103, marks: [] }, 104, 10);
    sy = syncSetAt(sy, 106, 12);
    expect(sy.marks).toEqual([
      { ply: 104, at: 10 },
      { ply: 105, at: 12 },
      { ply: 106, at: 12 },
    ]);
    expect(syncRemoveFrom(sy, 105).marks).toEqual([{ ply: 104, at: 10 }]);
  });
});

describe('Gukesh–Carlsen en dos clips: marcas medidas sobre la grabación', () => {
  const err = PACK.clips.find((c) => c.id === 'gukesh-carlsen-2025-norway-r6-error')!;
  const bang = PACK.clips.find((c) => c.id === 'gukesh-carlsen-2025-norway-r6')!;
  it('los dos pueden pararse solos, con marcas coherentes y sin tramos sin seguimiento', () => {
    for (const c of [err, bang]) {
      expect(canAutoPause(c)).toBe(true);
      expect(marksProblems(marksOf(c))).toEqual([]);
      expect(syncProblems(c, c.sync!, marksOf(c))).toEqual([]);
      expect(c.sync!.gaps ?? []).toEqual([]);
      expect(c.marks).toBe('pending'); // medidas por Claude sobre vídeo, sin comprobar por una persona
      expect(c.video.id).toBe('xbX88PgcaYc');
    }
  });
  it('«El error de Carlsen»: pausa antes de 52…Ce2+, que se ve en el vídeo, y acaba antes de las jugadas sin fechar', () => {
    expect(err.stops.map((s) => s.questions.map((q) => q.ply))).toEqual([[104]]);
    expect(plyAt(err.sync!, err.start!)).toBe(103);
    expect(plyAt(err.sync!, err.stops[0].at!)).toBe(103);
    expect(plyAt(err.sync!, err.end!)).toBe(104);
  });
  it('«El golpe en la mesa»: empieza antes de 60.Cb2, pausa tras 60…e3 y antes de 61.Cc4+, y sigue hasta 62.Rf4', () => {
    expect(bang.stops.map((s) => s.questions.map((q) => q.ply))).toEqual([[121]]);
    expect(plyAt(bang.sync!, bang.start!)).toBe(118);
    const at = bang.stops[0].at!;
    expect(plyAt(bang.sync!, at)).toBe(120); // 60…e3 ya en el tablero
    expect(bang.sync!.marks.find((m) => m.ply === 121)!.at).toBeGreaterThan(at); // 61.Cc4+ todavía no
    expect(plyAt(bang.sync!, 366)).toBe(119);
    expect(plyAt(bang.sync!, bang.end!)).toBe(123);
  });
});

describe('tramos sin seguimiento del tablero', () => {
  // Un clip de prueba con todo el final de la partida: del 52…Ce2+ al 62.Rf4.
  const base = PACK.clips.find((c) => c.id === 'gukesh-carlsen-2025-norway-r6-error')!;
  const gc = { ...base, timeline: base.timeline, end: 378.8, sync: { startPly: 103, marks: [{ ply: 104, at: 281 }, ...Array.from({ length: 14 }, (_, i) => ({ ply: 105 + i, at: 364.4 })), { ply: 119, at: 365.9 }] } };
  const m = marksOf(gc);
  it('se rechazan tramos al revés, solapados, fuera del clip o sin jugadas', () => {
    const bad = (gaps: { from: number; to: number }[]) => syncProblems(gc, { ...gc.sync!, gaps }, m);
    expect(bad([{ from: 300, to: 290 }]).length).toBeGreaterThan(0);
    expect(bad([{ from: 283, to: 320 }, { from: 310, to: 364.4 }]).length).toBeGreaterThan(0);
    expect(bad([{ from: 200, to: 300 }]).length).toBeGreaterThan(0);
    expect(bad([{ from: 290, to: 300 }]).length).toBeGreaterThan(0); // ninguna jugada cambia dentro
    expect(bad([{ from: 283, to: 364.4 }])).toEqual([]);
  });
  it('dice qué jugadas caen dentro', () => {
    const sy = { ...gc.sync, gaps: [{ from: 283, to: 364.4 }] };
    expect(syncGapAt(sy, 282)).toBeNull();
    expect(gapPlies(sy, syncGapAt(sy, 300)!)).toEqual({ first: 105, last: 118 });
    expect(syncGapAt(sy, 364.4)).toBeNull();
  });
});

describe('lección de «El golpe en la mesa»', () => {
  const bang = PACK.clips.find((c) => c.id === 'gukesh-carlsen-2025-norway-r6')!;
  const pos = lessonPositions(bang);
  it('empieza en la posición de la pregunta y todas las jugadas son legales', () => {
    expect(pos.length).toBe(bang.lesson!.steps.length);
    expect(pos[0].fen).toBe(bang.stops[0].questions[0].fen);
    expect(pos[1].fen).toBe(bang.stops[0].questions[0].played.fenAfter); // 61.Cc4+
    expect(pos[3].fen).toBe(bang.tail[1].fenAfter); // 62.Rf4, como en la partida
  });
  it.each(PACK.clips.filter((c) => c.lesson).map((c) => [c.id, c] as const))('%s: jugadas legales y flechas que salen de casillas con pieza', (_id, c) => {
    const pos = lessonPositions(c);
    c.lesson!.steps.forEach((st, i) => {
      const board = new Map<string, boolean>();
      const rows = pos[i].fen.split(' ')[0].split('/');
      rows.forEach((r, ri) => { let f = 0; for (const ch of r) { if (/\d/.test(ch)) f += Number(ch); else { board.set('abcdefgh'[f] + (8 - ri), true); f++; } } });
      for (const a of st.arrows ?? []) expect(board.has(a.from)).toBe(true);
    });
  });
  it('una jugada ilegal se detecta', () => {
    expect(() => lessonPositions({ ...bang, lesson: { ...bang.lesson!, steps: [{ moves: 'Nc4+ Kd1 Kxh5', text: '' }] } })).toThrow();
  });
});

describe('regla de las lecciones: sin saltos bruscos', () => {
  // Pablo, 14 nov 2026: cada paso de una lección añade como mucho dos medias jugadas, para que no se pierda.
  for (const c of PACK.clips.filter((x) => x.lesson)) {
    it(`${c.id}: cada paso continúa el anterior con 0, 1 o 2 medias jugadas, o vuelve al principio con 1 o 2`, () => {
      const steps = c.lesson!.steps.map((s) => s.moves.split(/\s+/).filter(Boolean));
      steps.forEach((m, i) => {
        const prev = i === 0 ? [] : steps[i - 1];
        const continues = m.length >= prev.length && prev.every((x, k) => m[k] === x);
        if (continues) expect(m.length - prev.length).toBeLessThanOrEqual(2);
        else expect(m.length).toBeLessThanOrEqual(2); // otra línea desde la posición de partida («volvamos atrás»)
      });
    });
  }
});
