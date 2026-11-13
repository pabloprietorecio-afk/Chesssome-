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
    // Comprobadas por Pablo en su móvil (13 nov 2026): pausa antes de 55…Txf2 y tablero sincronizado con el vídeo.
    start: 3.5,
    end: 233.07,
    marks: 'verified',
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
          {
            ply: 112,
            question: 'Las blancas han recapturado con el rey. ¿Y ahora?',
            hint: 'Mira el alfil de a8: solo tiene una diagonal.',
            why: 'Ad5: el alfil negro se planta en la única diagonal del alfil de a8. No hay casilla donde esconderse, así que las blancas tienen que cambiar. Queda un final de reyes y peones con un peón más para las negras.',
          },
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
    // La posición está quieta hasta ~280 s; Carlsen juega 52…Ce2+ en ~281 s. Las jugadas 53–59 no se pueden fechar
    // con fiabilidad en el vídeo (cortes de cámara y manos), así que tras las preguntas el vídeo se reanuda en 364,4 s,
    // justo antes de 60.Cb2, y el tablero salta a esa posición.
    start: 257,
    end: 378.8,
    marks: 'pending',
    sync: {
      startPly: 103,
      marks: [
        { ply: 104, at: 281.0 },
        { ply: 105, at: 364.4 },
        { ply: 106, at: 364.4 },
        { ply: 107, at: 364.4 },
        { ply: 108, at: 364.4 },
        { ply: 109, at: 364.4 },
        { ply: 110, at: 364.4 },
        { ply: 111, at: 364.4 },
        { ply: 112, at: 364.4 },
        { ply: 113, at: 364.4 },
        { ply: 114, at: 364.4 },
        { ply: 115, at: 364.4 },
        { ply: 116, at: 364.4 },
        { ply: 117, at: 364.4 },
        { ply: 118, at: 364.4 },
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
      'Stavanger, 1 de junio de 2025. Sexta ronda de Norway Chess. Carlsen, con negras, ha llevado ventaja casi toda la partida, pero los dos llegan al final con muy poco tiempo en el reloj.',
    stops: [
      {
        at: 277.5,
        resumeAt: 364.4,
        questions: [
          {
            ply: 104,
            question: 'Juegan las negras: Carlsen, con segundos en el reloj. ¿Qué jugarías?',
            hint: 'Tu torre de f8 está atacada.',
            why: 'La torre de f8 está atacada por el caballo de d7. Según el motor, apartarla (Te8, Tg8, Th8 o Ta8) mantiene el equilibrio, y 52…g5 también. En la partida, Carlsen jugó 52…Ce2+??: tras 53.Txe2+ Rxe2 54.Cxf8, las blancas quedaron con una pieza de más.',
          },
          {
            ply: 113,
            question: 'Juegan las blancas: Gukesh. Los peones negros de d3 y e5 avanzan. ¿Qué jugarías?',
            hint: 'El caballo tiene que llegar a tiempo para frenar los peones.',
            why: '57.Ca4: según el motor, es la única que gana. El caballo se dirige a b2 y c3 para frenar los peones negros; en la partida llegó a b2 y después dio jaque en c4. Comerse el peón con 57.Cxd3 parece lógico, pero el motor lo da por tablas.',
          },
          {
            ply: 121,
            question: 'Los peones negros siguen avanzando. ¿Y ahora?',
            hint: 'Busca un jaque que, además, ataque un peón.',
            why: '61.Cc4+: jaque al rey de d2 y, a la vez, el caballo ataca el peón de e3. Según el motor, es la única que gana. Tras 61…Re2 62.Rf4, Carlsen abandonó.',
          },
        ],
      },
    ],
    outro: 'Carlsen abandonó tras 62.Rf4 y dio un golpe en la mesa. Fue la primera victoria de Gukesh contra Carlsen en una partida clásica.',
    notes:
      'Vídeo de ChessBase India grabado en la sala; el título dice que gana Gukesh. Marcas medidas sobre una grabación de pantalla de Pablo, sin comprobar aún en el móvil: tablero quieto hasta ~280 s, 52…Ce2+ en ~281 s (pausa en 277,5), y el final fechado al segundo (60.Cb2 365,9; 60…e3 371,2; 61.Cc4+ 372,1; 61…Re2 375,6; 62.Rf4 376,4; golpe ~377,5; fin 378,8). Las jugadas 53–59 no se pueden fechar con fiabilidad, así que el vídeo se reanuda en 364,4 s y el tablero salta a la posición de 60.Cb2. Sin relojes: la retransmisión de Lichess no se puede descargar (robots.txt). En las preguntas, el tablero se orienta hacia quien juega (negras en la primera, blancas en las otras dos).',
  },
];
