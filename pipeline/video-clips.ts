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
    notes:
      'Vídeo de ChessBase India grabado en la sala; el título dice que gana Gukesh. Marcas medidas sobre una grabación de pantalla de Pablo, sin comprobar aún en el móvil (60.Cb2 365,9; 60…e3 371,2; pausa 371,4; 61.Cc4+ 372,1; 61…Re2 375,6; 62.Rf4 376,4; golpe ~377,5; fin 378,8). La pausa tiene ~0,3 s de margen antes de que Gukesh mueva la mano. La pregunta de 57.Ca4 se retiró: el vídeo no enseña esa jugada. Sin relojes: la retransmisión de Lichess no se puede descargar (robots.txt).',
  },
];
