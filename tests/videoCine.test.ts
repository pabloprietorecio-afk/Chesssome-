import { describe, expect, it } from 'vitest';
import pack from '../src/data/videocine.pack.json';
import { CLIPS } from '../pipeline/video-clips';
import {
  EPS,
  canAutoPause,
  defaultStartPly,
  direct,
  fenAfter,
  initialDirector,
  judgeAnswer,
  marksOf,
  marksProblems,
  moveAt,
  plyAt,
  replay,
  run,
  syncCap,
  syncProblems,
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

  it('Ding–Gukesh: marcas de Pablo en orden y dentro del vídeo', () => {
    expect(marksOf(ding)).toEqual({ start: 200.14, stops: [215.47], end: 233.07, duration: 437 });
    expect(marksProblems(marksOf(ding))).toEqual([]);
  });

  it('Ding–Gukesh: en las tres preguntas solo gana la jugada de la partida', () => {
    const qs = ding.stops[0].questions;
    expect(qs.map((q) => q.played.san)).toEqual(['Rxf2', 'Bd5', 'Ke5']);
    for (const q of qs) {
      expect(q.target).toBe('win');
      expect(q.playedCls).toBe('keeps');
      expect(q.verdicts.filter((v) => v.cls === 'keeps').map((v) => v.uci)).toEqual([q.playedUci]);
    }
    expect(qs[1].bridge.map((m) => m.san)).toEqual(['Kxf2']);
    expect(qs[2].bridge.map((m) => m.san)).toEqual(['Bxd5', 'Kxd5', 'Ke3']);
    expect(qs[0].lead?.san).toBe('Rf2');
  });
});

describe('respuestas', () => {
  const [q1, , q3] = ding.stops[0].questions;
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
    const unmarked = withMarks(ding, { start: null, stops: [null], end: null, duration: null });
    expect(canAutoPause(unmarked)).toBe(false);
    expect(canAutoPause(ding)).toBe(true);
    const marked = withMarks(ding, { start: 0, stops: [8.4], end: 120, duration: 431 });
    expect(canAutoPause(marked)).toBe(true);
    expect(marksOf(marked)).toEqual({ start: 0, stops: [8.4], end: 120, duration: 431 });
  });
});

// ───────────── Director ─────────────

type MiniClip = Pick<Clip, 'start' | 'end' | 'stops' | 'video'>;
const mini = (over: Partial<MiniClip> = {}): MiniClip => ({
  start: 10,
  end: 60,
  video: { ...ding.video, duration: 100 },
  stops: [
    { at: 20, questions: ding.stops[0].questions },
    { at: 40, questions: ding.stops[0].questions },
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
    const noMarks = mini({ start: null, end: null, stops: [{ at: null, questions: ding.stops[0].questions }] });
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
    const noMarks = mini({ start: null, end: null, stops: [{ at: null, questions: ding.stops[0].questions }] });
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
      const clip = mini({ start: 0, end: null, stops: [{ at, questions: ding.stops[0].questions }] });
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
  const q1 = ding.stops[0].questions[0].ply;
  const pause = ding.stops[0].at!;
  const marks = marksOf(ding);

  it('por defecto empieza en la posición de la primera pregunta', () => {
    expect(defaultStartPly(ding)).toBe(q1 - 1);
    expect(moveAt(ding, q1)!.san).toBe(ding.stops[0].questions[0].played.san);
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
    expect(at([{ ply: q1, at: ding.end! + 1 }])).toMatch(/después del fin/);
    expect(at([{ ply: q1, at: ding.start! - 1 }])).toMatch(/antes del inicio/);
    expect(at([{ ply: q1, at: pause - 0.5 }])).toMatch(/antes de la pausa/);
    expect(at([], q1)).toMatch(/destriparía/);
    expect(at([], ding.timeline.fromPly - 1)).toMatch(/fuera de las jugadas/);
  });

  it('mientras se ve el vídeo, el tablero no pasa de la posición de la próxima pregunta', () => {
    expect(syncCap(ding, { phase: 'watching', stop: 0, mode: 'film' })).toBe(q1 - 1);
    expect(syncCap(ding, { phase: 'reveal', stop: 0, mode: 'film' })).toBe(Infinity);
    expect(syncCap(ding, { phase: 'watching', stop: 0, mode: 'free' })).toBe(Infinity);
    const two = { stops: [{ questions: [{ ply: 20 }] }, { questions: [{ ply: 40 }] }] };
    expect(syncCap(two, { phase: 'reveal', stop: 0, mode: 'film' })).toBe(39);
    expect(syncCap(two, { phase: 'ended', stop: 1, mode: 'film' })).toBe(Infinity);
  });

  it('las marcas del tablero viajan con las demás marcas', () => {
    const sync = { startPly: q1 - 1, marks: [{ ply: q1, at: pause }] };
    expect(withMarks(ding, { ...marks, sync }).sync).toEqual(sync);
    expect(withMarks({ ...ding, sync }, { ...marks, sync: null }).sync).toBeUndefined();
    expect(withMarks({ ...ding, sync }, marksOf(ding)).sync).toEqual(sync);
  });
});
