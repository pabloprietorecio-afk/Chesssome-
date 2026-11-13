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
      duration: null,
    },
    start: null,
    end: null,
    marks: 'pending',
    moves:
      '1. Nf3 d5 2. g3 c5 3. Bg2 Nc6 4. d4 e6 5. O-O cxd4 6. Nxd4 Nge7 7. c4 Nxd4 8. Qxd4 Nc6 9. Qd1 d4 10. e3 Bc5 11. exd4 Bxd4 12. Nc3 O-O 13. Nb5 Bb6 14. b3 a6 15. Nc3 Bd4 16. Bb2 e5 17. Qd2 Be6 18. Nd5 b5 19. cxb5 axb5 20. Nf4 exf4 21. Bxc6 Bxb2 22. Qxb2 Rb8 23. Rfd1 Qb6 24. Bf3 fxg3 25. hxg3 b4 26. a4 bxa3 27. Rxa3 g6 28. Qd4 Qb5 29. b4 Qxb4 30. Qxb4 Rxb4 31. Ra8 Rxa8 32. Bxa8 g5 33. Bd5 Bf5 34. Rc1 Kg7 35. Rc7 Bg6 36. Rc4 Rb1+ 37. Kg2 Re1 38. Rb4 h5 39. Ra4 Re5 40. Bf3 Kh6 41. Kg1 Re6 42. Rc4 g4 43. Bd5 Rd6 44. Bb7 Kg5 45. f3 f5 46. fxg4 hxg4 47. Rb4 Bf7 48. Kf2 Rd2+ 49. Kg1 Kf6 50. Rb6+ Kg5 51. Rb4 Be6 52. Ra4 Rb2 53. Ba8 Kf6 54. Rf4 Ke5 55. Rf2 Rxf2 56. Kxf2 Bd5 57. Bxd5 Kxd5 58. Ke3 Ke5 0-1',
    gameSource: 'Partida pública, cotejada jugada a jugada en dos fuentes: Wikipedia («World Chess Championship 2024») y ChessBase India (análisis de S. Kidambi).',
    orientation: 'b',
    intro:
      'Singapur, 12 de diciembre de 2024. Última partida del Mundial, con 6,5 a 6,5 en el marcador. El final de torre y alfil parece encaminado a las tablas… hasta que Ding Liren juega 55.Tf2.',
    stops: [
      {
        at: null,
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
    notes:
      'El título del vídeo en YouTube dice quién gana, pero no la jugada. En modo «directo a la pregunta» el reproductor no se carga hasta después de responder. Según una reseña, el vídeo dura algo más de siete minutos y empieza justo cuando Ding juega 55.Tf2: la pausa tendrá que ir en los primeros segundos. Sin verificar.',
  },
];
