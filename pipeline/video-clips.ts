/**
 * Fuentes del «Cine de finales» con vídeo real.
 *
 * Normas para añadir un clip:
 * 1. El vídeo es del canal del titular de los derechos (organizador, federación o productora que lo grabó),
 *    nunca una copia subida por terceros, y se comprueba con oEmbed que se puede incrustar.
 * 2. Las jugadas se cotejan en dos fuentes y se reproducen enteras con chess.js (pipeline/build-video-cine.ts).
 * 3. Los textos son propios. Los hechos que citan (fecha, marcador, quién gana) llevan fuente en docs/cine-finales.md.
 * 4. Las marcas de tiempo (start, at, end) solo se ponen tras ver el vídeo. Sin verlas, se dejan en null
 *    y marks queda en 'pending': el clip funciona en modo «directo a la pregunta» y no pausa solo.
 */
import type { ClipSource } from '../src/core/videoCine';

export const CLIPS: ClipSource[] = [
  {
    id: 'ding-gukesh-2024-g14',
    title: 'El error que decidió un Mundial',
    subtitle: 'Ding Liren – Gukesh · Mundial 2024, partida 14',
    event: 'Campeonato del Mundo de la FIDE 2024, Singapur',
    year: 2024,
    white: 'Ding Liren',
    black: 'Gukesh D',
    video: {
      provider: 'youtube',
      id: 'W9JtcW_0Sr8',
      title: 'Gukesh wins! - The final minutes of the FIDE World Championship 2024',
      channel: 'FIDE chess',
      channelUrl: 'https://www.youtube.com/@FIDE_chess',
      published: '2024-12-12',
      official: true,
      checked: '2026-11-13',
      duration: 437,
      // Probablemente sin cortes entre 2:21 y 3:53: con el ancla de Pablo, los relojes sitúan 58.Re3 (el rey
      // blanco avanza una casilla) en 3:30 y 58…Re5 en 3:37, que es lo que Pablo vio en su primer clip (3:20–3:53,
      // apretón de manos en 3:53). 55.Tf2 en 0:09 sale de los relojes y está sin comprobar.
    },
    // Marcas estimadas (13 nov 2026) con un ancla de Pablo, 55…Txf2: Gukesh pulsa el reloj en 2:21 (141 s), y los
    // relojes de la retransmisión (ver `clocks`). Fin: el apretón de manos que marcó Pablo (233,07 s).
    // Comprobadas por Pablo en su móvil (13 nov 2026): pausa antes de 55…Txf2 y tablero sincronizado con el vídeo. Las
    // pausas de las preguntas 2 y 3 (14 nov 2026) están sin comprobar: por eso el clip vuelve a «pending».
    start: 3.5,
    end: 233.07,
    marks: 'pending',
    // Tablero sincronizado: cada jugada 0,5 s antes de que se pulse su reloj (suggestSync).
    sync: {
      startPly: 108,
      marks: [
        { ply: 109, at: 8.5 },
        { ply: 110, at: 140.5 },
        { ply: 111, at: 142.5 },
        { ply: 112, at: 145.5 },
        { ply: 113, at: 155.5 },
        { ply: 114, at: 156.5 },
        { ply: 115, at: 209.5 },
        { ply: 116, at: 216.5 },
      ],
    },
    moves:
      '1. Nf3 d5 2. g3 c5 3. Bg2 Nc6 4. d4 e6 5. O-O cxd4 6. Nxd4 Nge7 7. c4 Nxd4 8. Qxd4 Nc6 9. Qd1 d4 10. e3 Bc5 11. exd4 Bxd4 12. Nc3 O-O 13. Nb5 Bb6 14. b3 a6 15. Nc3 Bd4 16. Bb2 e5 17. Qd2 Be6 18. Nd5 b5 19. cxb5 axb5 20. Nf4 exf4 21. Bxc6 Bxb2 22. Qxb2 Rb8 23. Rfd1 Qb6 24. Bf3 fxg3 25. hxg3 b4 26. a4 bxa3 27. Rxa3 g6 28. Qd4 Qb5 29. b4 Qxb4 30. Qxb4 Rxb4 31. Ra8 Rxa8 32. Bxa8 g5 33. Bd5 Bf5 34. Rc1 Kg7 35. Rc7 Bg6 36. Rc4 Rb1+ 37. Kg2 Re1 38. Rb4 h5 39. Ra4 Re5 40. Bf3 Kh6 41. Kg1 Re6 42. Rc4 g4 43. Bd5 Rd6 44. Bb7 Kg5 45. f3 f5 46. fxg4 hxg4 47. Rb4 Bf7 48. Kf2 Rd2+ 49. Kg1 Kf6 50. Rb6+ Kg5 51. Rb4 Be6 52. Ra4 Rb2 53. Ba8 Kf6 54. Rf4 Ke5 55. Rf2 Rxf2 56. Kxf2 Bd5 57. Bxd5 Kxd5 58. Ke3 Ke5 0-1',
    gameSource: 'Partida pública, cotejada jugada a jugada en dos fuentes: Wikipedia («World Chess Championship 2024») y ChessBase India (análisis de S. Kidambi).',
    orientation: 'b',
    intro:
      'Singapur, 12 de diciembre de 2024. Última partida del Mundial, con 6,5 a 6,5 en el marcador. El final de torre y alfil parece encaminado a las tablas… hasta que Ding Liren juega 55.Tf2.',
    // Lección comprobada con Stockfish 19 Lite (profundidad 26, 14 nov 2026): antes de 55.Tf2, igualdad (55.Ag2 −0,1;
    // 55.Ta4 −0,1); tras 55.Tf2, 55…Txf2 +6,4; tras 56.Rxf2, 56…Ad5 es la única que gana (+5,9; el resto 0,0); tras 58.Re3,
    // 58…Re5 es la única que gana (+6,0; Re6 y Rd6 0,0); tras 58…Re5, todas las blancas pierden (−13,9).
    lesson: {
      title: 'Cómo se ganó el Mundial con un final de peones',
      takeaway: 'Antes de cambiar piezas, mira el final que queda: en los finales de peones, la oposición puede decidir la partida.',
      from: 108,
      steps: [
        {
          moves: '',
          text: 'Final de torre y alfil igualado. El alfil blanco de a8 tiene poco sitio, pero mientras haya torres no corre peligro.',
        },
        {
          moves: 'Rf2',
          text: '55.Tf2? ofrece cambiar las torres. Parece prudente, pero es el error: con 55.Ag2 o 55.Ta4, Ding seguía en tablas.',
          arrows: [{ from: 'f2', to: 'b2', tone: 'bad' }],
        },
        {
          moves: 'Rf2 Rxf2',
          text: '55…Txf2: Gukesh acepta el cambio.',
        },
        {
          moves: 'Rf2 Rxf2 Kxf2',
          text: '56.Rxf2. Sin torres, el problema del alfil de a8 se ve claro: solo tiene una diagonal.',
          arrows: [{ from: 'a8', to: 'd5', tone: 'info' }],
        },
        {
          moves: 'Rf2 Rxf2 Kxf2 Bd5',
          text: '56…Ad5: el alfil negro se planta en esa diagonal. Es la única jugada que gana; con cualquier otra, tablas.',
          arrows: [{ from: 'd5', to: 'a8', tone: 'good' }],
        },
        {
          moves: 'Rf2 Rxf2 Kxf2 Bd5 Bxd5 Kxd5',
          text: '57.Axd5 Rxd5: el alfil blanco no tenía escapatoria, porque en b7 o c6 también lo capturaban. Queda un final de reyes y peones con un peón más para las negras.',
        },
        {
          moves: 'Rf2 Rxf2 Kxf2 Bd5 Bxd5 Kxd5 Ke3',
          text: '58.Re3: el rey blanco se pone delante para frenar al negro.',
        },
        {
          moves: 'Rf2 Rxf2 Kxf2 Bd5 Bxd5 Kxd5 Ke3 Ke5',
          text: '58…Re5: la oposición. Los reyes quedan frente a frente, con una casilla en medio, y le toca mover a las blancas. Era la única que ganaba: 58…Re6 o 58…Rd6 dejaban tablas.',
          arrows: [{ from: 'e5', to: 'e3', tone: 'good' }],
        },
        {
          moves: 'Rf2 Rxf2 Kxf2 Bd5 Bxd5 Kxd5 Ke3 Ke5',
          text: 'Mueva lo que mueva, el rey blanco tiene que ceder el paso y el rey negro entra en su campo. Por eso Ding se rindió aquí.',
        },
      ],
    },
    // Una pausa antes de cada pregunta (14 nov 2026): respondes, el vídeo enseña la jugada y se para antes de la siguiente.
    // 138 la comprobó Pablo; 144,5 (entre 56.Rxf2, reloj en 143,0, y 56…Ad5, reloj en 146,0) y 214 (3 s antes del reloj de
    // 58…Re5, en 217,0) los calcula suggestPause con los relojes, como 138, y están sin comprobar.
    stops: [
      {
        at: 138,
        questions: [
          {
            ply: 110,
            question: 'Ding acaba de jugar 55.Tf2. Juegan las negras: ¿qué jugarías?',
            hint: 'Imagina el tablero sin las torres. Y después, sin los alfiles.',
            why: 'Txf2: cambiar las torres es el primer paso. El alfil blanco está arrinconado en a8, así que después se podrá forzar también el cambio de alfiles y entrar en un final de peones ganado.',
          },
        ],
      },
      {
        at: 144.5,
        questions: [
          {
            ply: 112,
            question: 'Las blancas han recapturado con el rey. ¿Y ahora?',
            hint: 'Mira el alfil de a8: solo tiene una diagonal.',
            why: 'Ad5: el alfil negro se planta en la única diagonal del alfil de a8. No hay casilla donde esconderse, así que las blancas tienen que cambiar. Queda un final de reyes y peones con un peón más para las negras.',
          },
        ],
      },
      {
        at: 214,
        questions: [
          {
            ply: 116,
            question: 'Final de reyes y peones. Juegan las negras: ¿qué jugarías?',
            hint: 'Los dos reyes, frente a frente.',
            why: 'Re5: el rey negro toma la oposición. Ahora mueve el blanco y tiene que ceder el paso. Ding Liren se rindió aquí.',
          },
        ],
      },
    ],
    outro: 'Con esta partida, Gukesh ganó el Mundial por 7,5 a 6,5 y se convirtió, con 18 años, en el campeón del mundo más joven de la historia.',
    resignation: {
      by: 'Ding',
      hook: '¿Por qué, si solo tiene un peón menos?',
      outcome: 'El peón de g corona: las negras tienen dama y las blancas, solo el rey. Por eso Ding abandonó.',
      why: 'El final de peones está perdido. El rey negro rodea al blanco por d4 y d3; el peón de f se adelanta hasta f2 para desviar al rey blanco, el rey negro se come el peón de g3 y el peón de g corona. Así habría seguido con la mejor defensa de las blancas:',
      line: 'Kd3 f4 Ke2 f3+ Ke3 Kd5 Kf2 Kd4 Kf1 Ke3 Ke1 Kd3 Kf1 f2 Kxf2 Kd2 Kf1 Ke3 Kg2 Ke2 Kg1 Kf3 Kh2 Kf2 Kh1 Kxg3 Kg1 Kh3 Kf2 g3+ Kg1 g2 Kf2 Kh2 Kf3 g1=Q',
      source:
        'Stockfish 19 Lite WASM, profundidad 30 por jugada (14 nov 2026). Las blancas, siempre la mejor jugada del motor; las negras, 59…f4, 60…f3+, 61…Rd5 y 62…Rd4 (todas dadas por ganadoras) y después la mejor del motor. Desde 65…Rd2 el motor da mate forzado.',
    },
    clocks: {
      timeControl: '40/7200:1800+30',
      firstPly: 108,
      // 54…Re5, 55.Tf2, 55…Txf2, 56.Rxf2, 56…Ad5, 57.Axd5, 57…Rxd5, 58.Re3, 58…Re5
      values: ['1:07:23', '0:09:43', '1:05:41', '0:10:11', '1:06:08', '0:10:31', '1:06:37', '0:10:08', '1:07:00'],
      source:
        'Retransmisión oficial en Lichess, «FIDE World Championship 2024», game 14 (lichess.org/broadcast/fide-world-championship-2024/game-14/LtsCRK9D), leída del texto que indexa el buscador: la página no se pudo descargar (robots.txt).',
    },
    notes:
      'El título del vídeo en YouTube dice quién gana, pero no la jugada. En modo «directo a la pregunta» el reproductor no se carga hasta después de responder. Vídeo de 437 s. Las primeras marcas (3:20 a 3:53, pausa en 3:35) dejaban la pausa antes de 58…Re5 y no antes de 55…Txf2. Marcas actuales estimadas con los relojes y un ancla de Pablo (55…Txf2 en 2:21): 55.Tf2 en 0:09, pausa en 2:18, fin en 3:53. Comprobadas por Pablo en su móvil.',
  },
  {
    id: 'gukesh-carlsen-2025-norway-r6-error',
    title: 'El error de Carlsen',
    subtitle: 'Gukesh – Carlsen · Norway Chess 2025, ronda 6',
    event: 'Norway Chess 2025, ronda 6 · Stavanger',
    year: 2025,
    white: 'Gukesh D',
    black: 'Magnus Carlsen',
    video: {
      provider: 'youtube',
      id: 'xbX88PgcaYc',
      title: 'The LOUDEST BANG you will ever hear in chess | Gukesh beats Magnus Carlsen in Norway',
      channel: 'ChessBase India',
      channelUrl: 'https://www.youtube.com/@ChessBaseIndiachannel',
      // Grabado en la sala por ChessBase India (su crónica de la ronda lo acredita: «Video: ChessBase India»).
      official: true,
      checked: '2026-11-13',
      duration: 759,
    },
    // Marcas medidas por Claude sobre la grabación de pantalla de Pablo (13 nov 2026), sin comprobar aún en el móvil.
    // El tablero está quieto (tras 52.Cd7) hasta que Carlsen juega 52…Ce2+ en ~281 s. 52.Cd7 se jugó antes de lo grabado.
    start: 271,
    end: 283,
    marks: 'pending',
    sync: { startPly: 103, marks: [{ ply: 104, at: 281.0 }] },
    moves:
      '1. e4 e5 2. Nf3 Nc6 3. Bb5 Nf6 4. d3 Bc5 5. c3 O-O 6. O-O d6 7. h3 a6 8. Ba4 h6 9. Re1 b5 10. Bc2 Bb6 11. Nbd2 Ne7 12. a4 Rb8 13. d4 Ng6 14. Nf1 c5 15. Ng3 cxd4 16. cxd4 bxa4 17. Bxa4 Bb7 18. d5 a5 19. Be3 Bc8 20. b3 Bxe3 21. Rxe3 Nf4 22. Bc6 Rb4 23. Qc2 g6 24. Kh1 Ba6 25. Qa2 Bd3 26. Nd2 h5 27. Qxa5 Qxa5 28. Rxa5 h4 29. Ra4 Rfb8 30. Ra2 Kg7 31. Ra7 Rd4 32. Nf3 hxg3 33. fxg3 Nxh3 34. gxh3 Bxe4 35. Kh2 Rd1 36. g4 Bxd5 37. Bxd5 Nxd5 38. Re2 Nf4 39. Rc2 Kf6 40. h4 Ke6 41. Ng5+ Kd5 42. Ra5+ Kd4 43. Ra4+ Kd3 44. Rf2 f6 45. Rf3+ Ke2 46. Ra2+ Rd2 47. Rxd2+ Kxd2 48. Ne4+ Ke2 49. Kg3 d5 50. Nxf6 Rf8 51. Rf2+ Ke1 52. Nd7 Ne2+ 53. Rxe2+ Kxe2 54. Nxf8 d4 55. Ne6 d3 56. Nc5 Ke3 57. Na4 e4 58. h5 gxh5 59. gxh5 Kd2 60. Nb2 e3 61. Nc4+ Ke2 62. Kf4 1-0',
    gameSource:
      'Partida pública, cotejada jugada a jugada en dos fuentes: The Washington Times (10 de junio de 2025) y Chess Trap Guide. El final (52…Ce2+ 53.Txe2+ Rxe2 54.Cxf8 y 62.Rf4) coincide con ChessBase India y Wikipedia.',
    orientation: 'w',
    intro:
      'Stavanger, 1 de junio de 2025. Sexta ronda de Norway Chess. Carlsen, con negras, ha llevado ventaja casi toda la partida, pero los dos llegan al final con muy poco tiempo en el reloj. Gukesh acaba de jugar 52.Cd7.',
    // Lección comprobada con Stockfish 19 Lite (profundidad 26, 14 nov 2026): tras 52.Cd7, 52…Te8 +1,0 para las negras;
    // 52…g5 0,0; Tg8, Th8 y Ta8 entre −0,3 y −0,5. Tras 52…Ce2+, 53.Txe2+ +6,8 para las blancas.
    lesson: {
      title: 'Por qué 52…Ce2+ fue un error',
      takeaway: 'Antes de dar un jaque, mira qué piezas tuyas quedan atacadas.',
      from: 103,
      steps: [
        {
          moves: '',
          text: 'El caballo de d7 ataca la torre de f8.',
          arrows: [{ from: 'd7', to: 'f8', tone: 'bad' }],
        },
        {
          moves: 'Ne2+',
          text: '52…Ce2+?? Con segundos en el reloj, Carlsen da jaque en vez de salvar la torre.',
          arrows: [{ from: 'e2', to: 'g3', tone: 'info' }],
        },
        {
          moves: 'Ne2+ Rxe2+',
          text: '53.Txe2+: la torre blanca se come el caballo, y con jaque, porque el rey negro está en e1.',
        },
        {
          moves: 'Ne2+ Rxe2+ Kxe2 Nxf8',
          text: '53…Rxe2 54.Cxf8: el rey recupera la pieza, pero el caballo se come la torre. Las blancas quedan con un caballo de más, y ganan.',
        },
        {
          moves: 'Re8',
          text: 'Volvamos atrás. Lo correcto era salvar la torre: con 52…Te8 la partida seguía equilibrada, incluso algo mejor para las negras. También valían Tg8, Th8, Ta8 o 52…g5.',
        },
      ],
    },
    stops: [
      {
        at: 277.5,
        questions: [
          {
            ply: 104,
            question: 'Juegan las negras: Carlsen, con segundos en el reloj. ¿Qué jugarías?',
            hint: 'Tu torre de f8 está atacada.',
            why: 'La torre de f8 está atacada por el caballo de d7. Apartarla (Te8, Tg8, Th8 o Ta8) mantiene el equilibrio, y 52…g5 también. En la partida, Carlsen jugó 52…Ce2+??: tras 53.Txe2+ Rxe2 54.Cxf8, las blancas quedaron con una pieza de más.',
          },
        ],
      },
    ],
    outro: 'Tras 52…Ce2+?? 53.Txe2+ Rxe2 54.Cxf8, Gukesh quedó con una pieza de más. Cómo acabó, en «El golpe en la mesa».',
    notes:
      'Vídeo de ChessBase India grabado en la sala; el título dice que gana Gukesh. Marcas medidas sobre una grabación de pantalla de Pablo, sin comprobar aún en el móvil: tablero quieto hasta ~280 s y 52…Ce2+ en ~281 s (pausa en 277,5). El clip acaba en 283 s: las jugadas 53–59 no se pueden fechar en el vídeo (cortes de cámara). Sin relojes: la retransmisión de Lichess no se puede descargar (robots.txt).',
  },
  {
    id: 'gukesh-carlsen-2025-norway-r6',
    title: 'El golpe en la mesa',
    subtitle: 'Gukesh – Carlsen · Norway Chess 2025, ronda 6',
    event: 'Norway Chess 2025, ronda 6 · Stavanger',
    year: 2025,
    white: 'Gukesh D',
    black: 'Magnus Carlsen',
    video: {
      provider: 'youtube',
      id: 'xbX88PgcaYc',
      title: 'The LOUDEST BANG you will ever hear in chess | Gukesh beats Magnus Carlsen in Norway',
      channel: 'ChessBase India',
      channelUrl: 'https://www.youtube.com/@ChessBaseIndiachannel',
      // Grabado en la sala por ChessBase India (su crónica de la ronda lo acredita: «Video: ChessBase India»).
      official: true,
      checked: '2026-11-13',
      duration: 759,
    },
    // Marcas medidas por Claude sobre la grabación de pantalla de Pablo (13 nov 2026), sin comprobar aún en el móvil.
    // 60.Cb2 en 365,9 s; 60…e3 en 371,2 (la mano de Carlsen deja el tablero hacia 371,3); la mano de Gukesh sale hacia
    // 371,5, así que la pausa (371,4) tiene muy poco margen. 61.Cc4+ en 372,1; 61…Re2 en 375,6; 62.Rf4 en 376,4; golpe ~377,5.
    start: 362,
    end: 378.8,
    marks: 'pending',
    sync: {
      startPly: 118,
      marks: [
        { ply: 119, at: 365.9 },
        { ply: 120, at: 371.2 },
        { ply: 121, at: 372.1 },
        { ply: 122, at: 375.6 },
        { ply: 123, at: 376.4 },
      ],
    },
    moves:
      '1. e4 e5 2. Nf3 Nc6 3. Bb5 Nf6 4. d3 Bc5 5. c3 O-O 6. O-O d6 7. h3 a6 8. Ba4 h6 9. Re1 b5 10. Bc2 Bb6 11. Nbd2 Ne7 12. a4 Rb8 13. d4 Ng6 14. Nf1 c5 15. Ng3 cxd4 16. cxd4 bxa4 17. Bxa4 Bb7 18. d5 a5 19. Be3 Bc8 20. b3 Bxe3 21. Rxe3 Nf4 22. Bc6 Rb4 23. Qc2 g6 24. Kh1 Ba6 25. Qa2 Bd3 26. Nd2 h5 27. Qxa5 Qxa5 28. Rxa5 h4 29. Ra4 Rfb8 30. Ra2 Kg7 31. Ra7 Rd4 32. Nf3 hxg3 33. fxg3 Nxh3 34. gxh3 Bxe4 35. Kh2 Rd1 36. g4 Bxd5 37. Bxd5 Nxd5 38. Re2 Nf4 39. Rc2 Kf6 40. h4 Ke6 41. Ng5+ Kd5 42. Ra5+ Kd4 43. Ra4+ Kd3 44. Rf2 f6 45. Rf3+ Ke2 46. Ra2+ Rd2 47. Rxd2+ Kxd2 48. Ne4+ Ke2 49. Kg3 d5 50. Nxf6 Rf8 51. Rf2+ Ke1 52. Nd7 Ne2+ 53. Rxe2+ Kxe2 54. Nxf8 d4 55. Ne6 d3 56. Nc5 Ke3 57. Na4 e4 58. h5 gxh5 59. gxh5 Kd2 60. Nb2 e3 61. Nc4+ Ke2 62. Kf4 1-0',
    gameSource:
      'Partida pública, cotejada jugada a jugada en dos fuentes: The Washington Times (10 de junio de 2025) y Chess Trap Guide. El final (52…Ce2+ 53.Txe2+ Rxe2 54.Cxf8 y 62.Rf4) coincide con ChessBase India y Wikipedia.',
    orientation: 'w',
    intro:
      'Stavanger, 1 de junio de 2025. Sexta ronda de Norway Chess. Tras el error de Carlsen en la jugada 52, Gukesh tiene un caballo contra dos peones negros que avanzan, y a los dos les quedan segundos en el reloj.',
    // Lección comprobada con Stockfish 19 Lite (profundidad 26, 13 nov 2026): tras 61.h6? e2 ganan las negras; tras 61.Cc4+
    // pierden todas las jugadas de rey negro; tras 61…Re2, 62.Rf4 es la mejor (62.h6? queda igualada); tras 62.Rf4, la mejor
    // defensa es 62…d2 63.Cxe3 Rd3 64.b4 d1=D 65.Cxd1, con ventaja decisiva de las blancas.
    lesson: {
      title: 'Por qué 61.Cc4+ gana y por qué abandonó Carlsen',
      takeaway: 'Contra peones que avanzan, gana el jaque que además ataca un peón y vigila su camino.',
      from: 120,
      steps: [
        {
          moves: '',
          text: 'Los peones negros de d3 y e3 están a dos pasos de coronar. Si las blancas no los frenan ya, …e2 y no hay forma de pararlos: por ejemplo, tras 61.h6? e2, ganan las negras.',
          arrows: [
            { from: 'e3', to: 'e1', tone: 'bad' },
            { from: 'd3', to: 'd1', tone: 'bad' },
          ],
        },
        {
          moves: 'Nc4+',
          text: '61.Cc4+ hace tres cosas a la vez. Da jaque, así que las negras tienen que mover el rey y no pueden avanzar un peón. Ataca el peón de e3. Y vigila d2, la casilla por la que tiene que pasar el peón de d3.',
          arrows: [
            { from: 'c4', to: 'e3', tone: 'good' },
            { from: 'c4', to: 'd2', tone: 'good' },
          ],
        },
        {
          moves: 'Nc4+ Ke2',
          text: 'Carlsen apartó el rey a e2, desde donde defiende los dos peones. Cualquier jugada de rey pierde aquí.',
          arrows: [
            { from: 'e2', to: 'e3', tone: 'info' },
            { from: 'e2', to: 'd3', tone: 'info' },
          ],
        },
        {
          moves: 'Nc4+ Ke2 Kf4',
          text: '62.Rf4: el rey blanco también ataca e3. Ahora ese peón está atacado dos veces (rey y caballo) y defendido una sola (rey negro). Ojo: correr con el peón, 62.h6?, habría dejado la posición igualada.',
          arrows: [
            { from: 'f4', to: 'e3', tone: 'good' },
            { from: 'c4', to: 'e3', tone: 'good' },
          ],
        },
        {
          moves: 'Nc4+ Ke2 Kf4 d2',
          text: 'Por qué abandonó Carlsen. Su mejor defensa era 62…d2: el peón amenaza coronar en d1.',
          arrows: [{ from: 'd2', to: 'd1', tone: 'bad' }],
        },
        {
          moves: 'Nc4+ Ke2 Kf4 d2 Nxe3',
          text: '63.Cxe3: el caballo se come el peón de e3 y, desde e3, vigila d1. Si el peón corona, el caballo se come la dama.',
          arrows: [{ from: 'e3', to: 'd1', tone: 'good' }],
        },
        {
          moves: 'Nc4+ Ke2 Kf4 d2 Nxe3 Kd3 b4',
          text: '63…Rd3 64.b4: el rey negro no puede comerse el caballo, porque lo defiende el rey blanco. Las blancas tienen tiempo de avanzar su peón.',
          arrows: [{ from: 'f4', to: 'e3', tone: 'info' }],
        },
        {
          moves: 'Nc4+ Ke2 Kf4 d2 Nxe3 Kd3 b4 d1=Q Nxd1',
          text: '64…d1=D 65.Cxd1: la dama nueva cae enseguida. Quedan caballo y dos peones contra el rey solo, una victoria clara. Por eso abandonó Carlsen.',
        },
      ],
    },
    stops: [
      {
        at: 371.4,
        questions: [
          {
            ply: 121,
            question: 'Juegan las blancas: Gukesh. Carlsen acaba de empujar 60…e3. ¿Qué jugarías?',
            hint: 'Busca un jaque que, además, ataque un peón.',
            why: '61.Cc4+: jaque al rey de d2 y, a la vez, el caballo ataca el peón de e3. Es la única que gana. Tras 61…Re2 62.Rf4, Carlsen abandonó.',
          },
        ],
      },
    ],
    outro: 'Carlsen abandonó tras 62.Rf4 y dio un golpe en la mesa. Fue la primera victoria de Gukesh contra Carlsen en una partida clásica.',
    resignation: {
      by: 'Carlsen',
      hook: '¿Por qué, si tiene dos peones a punto de coronar?',
      outcome: 'El peón de h corona: las blancas tienen dama, caballo y peón contra el rey solo. Por eso Carlsen abandonó.',
      why: 'Su mejor intento era 62…d2, pero no basta: el caballo frena el peón en d1 y el peón blanco de h corona. Así habría seguido con la mejor defensa de las negras:',
      line: 'd2 Nxe3 Kd3 h6 Kc3 h7 d1=Q Nxd1+ Kd4 h8=Q+',
      source: 'Stockfish 19 Lite WASM, profundidad 30 (14 nov 2026): primera línea del análisis de la posición final; el motor da mate en 13 para las blancas.',
    },
    notes:
      'Vídeo de ChessBase India grabado en la sala; el título dice que gana Gukesh. Marcas medidas sobre una grabación de pantalla de Pablo, sin comprobar aún en el móvil (60.Cb2 365,9; 60…e3 371,2; pausa 371,4; 61.Cc4+ 372,1; 61…Re2 375,6; 62.Rf4 376,4; golpe ~377,5; fin 378,8). La pausa tiene ~0,3 s de margen antes de que Gukesh mueva la mano. La pregunta de 57.Ca4 se retiró: el vídeo no enseña esa jugada. Sin relojes: la retransmisión de Lichess no se puede descargar (robots.txt).',
  },
  {
    id: 'nepomniachtchi-ding-2023-wch-tb4',
    title: 'El último error del Mundial',
    subtitle: 'Nepomniachtchi – Ding · Mundial 2023, desempate 4',
    event: 'Campeonato del Mundo de la FIDE 2023, desempate (partida rápida 4) · Astana',
    year: 2023,
    white: 'Ian Nepomniachtchi',
    black: 'Ding Liren',
    video: {
      provider: 'youtube',
      id: 'W79Fse7LZQA',
      title: 'DING is the new KING',
      channel: 'ChessBase India',
      channelUrl: 'https://www.youtube.com/@ChessBaseIndiachannel',
      // Canal y duración comprobados en la página del vídeo (14 nov 2026): ChessBase India, 4:23, 30 de abril de 2023.
      official: true,
      checked: '2026-11-14',
      duration: 263,
    },
    // Marcas medidas por Claude (14 nov 2026) sobre dos grabaciones de pantalla de Pablo, sin comprobar aún en el móvil:
    // la primera cubre de 0:00,6 a 1:50 y la segunda de 1:45,75 a 3:42 (desfases sacados del contador del reproductor).
    // El tablero no se lee en el plano de la sala: cada jugada sale de la mano que mueve, en el orden de la partida, y
    // cuadra con la pantalla de la sala que se ve en 0:16–0:20 (posición tras 58…a3, relojes Ding 1:24, Nepo 0:21) y con
    // los relojes: Nepo, en apuros, no podía pensar 62.Rg2 cincuenta segundos; Ding sí 62…h5 (1:08 → 1:56).
    start: 11,
    end: 217,
    marks: 'pending',
    sync: {
      startPly: 116,
      marks: [
        { ply: 117, at: 23.6 },
        { ply: 118, at: 31.6 },
        { ply: 119, at: 51.6 },
        { ply: 120, at: 54.6 },
        { ply: 121, at: 55.9 },
        { ply: 122, at: 64.6 },
        { ply: 123, at: 68.2 },
        { ply: 124, at: 116.2 },
        { ply: 125, at: 117.4 },
        { ply: 126, at: 121.3 },
        { ply: 127, at: 140.0 },
        { ply: 128, at: 143.3 },
        { ply: 129, at: 150.4 },
        { ply: 130, at: 152.5 },
        { ply: 131, at: 162.3 },
        { ply: 132, at: 173.7 },
        { ply: 133, at: 176.1 },
        { ply: 134, at: 191.3 },
        { ply: 135, at: 198.6 },
        { ply: 136, at: 212.6 },
      ],
    },
    moves:
      '1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 4. Ba4 Nf6 5. O-O Be7 6. d3 b5 7. Bb3 d6 8. a4 Bd7 9. h3 O-O 10. Be3 Na5 11. Ba2 bxa4 12. Nc3 Rb8 13. Bb1 Qe8 14. b3 c5 15. Nxa4 Nc6 16. Nc3 a5 17. Nd2 Be6 18. Nc4 d5 19. exd5 Nxd5 20. Bd2 Nxc3 21. Bxc3 Bxc4 22. bxc4 Bd8 23. Bd2 Bc7 24. c3 f5 25. Re1 Rd8 26. Ra2 Qg6 27. Qe2 Qd6 28. g3 Rde8 29. Qf3 e4 30. dxe4 Ne5 31. Qg2 Nd3 32. Bxd3 Qxd3 33. exf5 Rxe1+ 34. Bxe1 Qxc4 35. Ra1 Rxf5 36. Bd2 h6 37. Qc6 Rf7 38. Re1 Kh7 39. Be3 Be5 40. Qe8 Bxc3 41. Rc1 Rf6 42. Qd7 Qe2 43. Qd5 Bb4 44. Qe4+ Kg8 45. Qd5+ Kh7 46. Qe4+ Rg6 47. Qf5 c4 48. h4 Qd3 49. Qf3 Rf6 50. Qg4 c3 51. Rd1 Qg6 52. Qc8 Rc6 53. Qa8 Rd6 54. Rxd6 Qxd6 55. Qe4+ Qg6 56. Qc4 Qb1+ 57. Kh2 a4 58. Bd4 a3 59. Qc7 Qg6 60. Qc4 c2 61. Be3 Bd6 62. Kg2 h5 63. Kf1 Be5 64. g4 hxg4 65. h5 Qf5 66. Qd5 g3 67. f4 a2 68. Qxa2 Bxf4 0-1',
    gameSource:
      'Partida pública, cotejada jugada a jugada en dos fuentes: The Washington Times (2 de mayo de 2023) y The Spectator (6 de mayo de 2023). El final (de 57.Rh2 a 68…Axf4) coincide con la crónica en directo de The Guardian, y la posición tras 58…a3 con la pantalla de la sala que se ve en el vídeo.',
    orientation: 'b',
    intro:
      'Astana, 30 de abril de 2023. Cuarta y última partida rápida del desempate del Mundial: si acaba en tablas, se jugarán partidas relámpago. Las negras de Ding tienen dos peones pasados, pero a Nepomniachtchi le basta con no fallar… y le quedan unos 20 segundos.',
    // Comprobado con Stockfish 19 Lite (profundidad 26, 14 nov 2026): tras 58…a3, 59.Axg7 y 59.h5 hacen tablas y 59.Dc7
    // pierde; tras 59.Axg7 Rxg7 60.Dc7+, jaque perpetuo (0,00). Tras 59.Dc7, solo 59…Dg6 gana (59…Af8 hace tablas;
    // el resto pierde, la mayoría con mate). 62…h5 es la mejor de la posición (+3,4; la siguiente, +2,2).
    lesson: {
      title: 'Cómo pudo salvarse Nepo y cómo ganó Ding',
      takeaway: 'Con poco tiempo, mira primero los jaques: a veces un sacrificio da tablas por jaque perpetuo.',
      from: 116,
      steps: [
        {
          moves: '',
          text: 'Las negras tienen dos peones pasados, en a3 y c3, muy cerca de coronar. Nepo, con unos 20 segundos, tiene que encontrar cómo salvarse.',
          arrows: [
            { from: 'a3', to: 'a1', tone: 'bad' },
            { from: 'c3', to: 'c1', tone: 'bad' },
          ],
        },
        {
          moves: 'Bxg7',
          text: '59.Axg7!: un sacrificio. El alfil se come el peón que protege al rey negro.',
        },
        {
          moves: 'Bxg7 Kxg7 Qc7+',
          text: '59…Rxg7 60.Dc7+: la dama da jaque tras jaque y el rey negro no tiene dónde esconderse. Tablas por jaque perpetuo.',
          arrows: [{ from: 'c7', to: 'g7', tone: 'good' }],
        },
        {
          moves: 'Qc7',
          text: 'En la partida, Nepo jugó 59.Dc7??. Amenaza Dxg7 mate: la dama y el alfil de d4 apuntan a g7.',
          arrows: [
            { from: 'c7', to: 'g7', tone: 'bad' },
            { from: 'd4', to: 'g7', tone: 'bad' },
          ],
        },
        {
          moves: 'Qc7 Qg6',
          text: '59…Dg6!: defiende g7 y la dama negra vuelve al juego. Era la única jugada que ganaba.',
          arrows: [{ from: 'g6', to: 'g7', tone: 'good' }],
        },
        {
          moves: 'Qc7 Qg6 Qc4 c2',
          text: '60.Dc4 c2: el peón de c ya está a un paso de coronar.',
          arrows: [{ from: 'c2', to: 'c1', tone: 'bad' }],
        },
        {
          moves: 'Qc7 Qg6 Qc4 c2 Be3 Bd6',
          text: '61.Ae3 Ad6: los dos peones negros quedan protegidos, el de a3 por el alfil y el de c2 por la dama.',
          arrows: [
            { from: 'd6', to: 'a3', tone: 'good' },
            { from: 'g6', to: 'c2', tone: 'good' },
          ],
        },
        {
          moves: 'Qc7 Qg6 Qc4 c2 Be3 Bd6 Kg2 h5',
          text: '62.Rg2 h5!: frena el peón blanco de h4 y deja al rey negro a salvo. Con el rey seguro, los peones deciden.',
          arrows: [{ from: 'h5', to: 'h4', tone: 'good' }],
        },
      ],
    },
    // Una pausa por pregunta. 21,4: Nepo empieza a mover la mano hacia 22,1. 28,6: Nepo pulsa el reloj hacia 25,1 y la
    // mano de Ding sale hacia 30,6. 113,5: Ding piensa 62…h5 desde 68,2 y mueve hacia 115,8.
    stops: [
      {
        at: 21.4,
        questions: [
          {
            ply: 117,
            question: 'Juega Nepo, con blancas y unos 20 segundos en el reloj. Si no pierde, habrá partidas relámpago. ¿Qué jugarías?',
            hint: 'Mira el peón de g7: es lo único que protege al rey negro.',
            why: '59.Axg7! Rxg7 60.Dc7+ y jaque perpetuo: tablas. También 59.h5 y 59.Dd5 mantenían las tablas. En la partida, Nepo jugó 59.Dc7??, que amenaza Dxg7 mate, pero pierde.',
          },
        ],
      },
      {
        at: 28.6,
        questions: [
          {
            ply: 118,
            question: 'Nepo ha jugado 59.Dc7 y amenaza Dxg7 mate. Juega Ding: ¿qué jugarías?',
            hint: 'Defiende g7, pero sin dejar tu dama fuera de juego.',
            why: '59…Dg6!: defiende g7 y la dama vuelve al centro de la partida. Es la única que gana: con 59…Af8 también se defiende g7, pero solo se hacen tablas.',
          },
        ],
      },
      {
        at: 113.5,
        questions: [
          {
            ply: 124,
            question: 'Nepo acaba de jugar 62.Rg2. Ding pensó casi un minuto. ¿Qué jugarías?',
            hint: 'Antes de correr con los peones, asegura tu rey.',
            why: '62…h5: frena el peón blanco de h4 y deja al rey negro a salvo. Con el rey seguro, los peones de a y c deciden la partida.',
          },
        ],
      },
    ],
    outro: 'Nepomniachtchi abandonó tras 68…Axf4. Ding Liren se convirtió en el 17.º campeón del mundo, el primero de China.',
    resignation: {
      by: 'Nepo',
      hook: '¿Por qué, si todavía tiene dama y alfil?',
      outcome: 'Mate. Con la mejor defensa, las negras coronan el peón de c y dan mate en ocho jugadas. Por eso Nepo abandonó.',
      why: 'El alfil negro se come el de e3 con jaque, el peón de c corona y la dama blanca no basta para frenar los peones negros. Así habría seguido con la mejor defensa de las blancas:',
      line: 'Qa6 Bxe3+ Kg2 c1=Q Qg6+ Qxg6 hxg6+ Kxg6 Kf3 Kf5 Kxg3 Qf1 Kh4 g5+ Kg3 Bf4#',
      source: 'Stockfish 19 Lite WASM, profundidad 28 por jugada (14 nov 2026), la mejor de cada bando; el motor da mate en 8 para las negras con cualquier defensa.',
    },
    notes:
      'Vídeo de ChessBase India grabado en la sala; plano lateral en el que no se lee el tablero. En 0:16–0:20 sale la pantalla de la sala con la posición tras 58…a3 y los relojes. Marcas medidas sobre dos grabaciones de pantalla de Pablo, sin comprobar aún en el móvil. La jugada 59…Dg6 llega a los 8 s de 59.Dc7: la pausa de 28,6 tiene unos 2 s de margen. Sin relojes de la retransmisión: Lichess no se puede descargar (robots.txt).',
  },
];
