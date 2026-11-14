/**
 * Textos del nivel Kids (desde 8 años) para el curso «Aprende a jugar».
 *
 * Mismas lecciones y posiciones que el curso normal (src/course/course.ts); solo cambian las palabras: frases
 * cortas, sin nombres de casillas (salvo en la lección del tablero) y sin notación. Todos se leen en voz alta con
 * audios pregenerados (scripts/export-voice.ts), así que aquí no puede haber textos que dependan de la jugada.
 *
 * Cada lección tiene que tener exactamente tantos textos de ejercicio como ejercicios: la exportación lo comprueba.
 */

export interface KidsLesson {
  title?: string;
  intro: string[];
  exercises: string[];
  takeaway: string;
}

export const KIDS: Record<string, KidsLesson> = {
  tablero: {
    intro: ['¡Hola! Vamos a aprender ajedrez.', 'Se juega en un tablero con 64 casillas, claras y oscuras. Juegan dos: blancas y negras. Siempre empiezan las blancas.'],
    exercises: [
      'Así empieza una partida. Cada jugador tiene 16 piezas. Tú llevas las blancas, las que están cerca de ti.',
      'Cada casilla tiene un nombre: una letra y un número, como en el juego de hundir la flota.',
    ],
    takeaway: '¡Ya conoces el tablero!',
  },
  torre: {
    intro: ['La torre va en línea recta: hacia delante, hacia atrás y a los lados. Todo lo lejos que quiera.', 'Pero no puede saltar por encima de otras piezas.'],
    exercises: [
      'Lleva la torre hasta la estrella.',
      'Ahora recoge las dos estrellas.',
      'Recoge las tres estrellas.',
      'Tus peones están en medio. La torre no puede saltarlos. ¡Busca otro camino!',
    ],
    takeaway: 'La torre va en línea recta.',
  },
  alfil: {
    intro: ['El alfil va en diagonal, como si cortara las casillas por las esquinas. Todo lo lejos que quiera.', 'Por eso siempre pisa casillas del mismo color.'],
    exercises: [
      'Lleva el alfil hasta la estrella.',
      'Recoge las dos estrellas.',
      'Este alfil solo pisa casillas claras. Recoge las tres estrellas.',
      'Un peón le tapa el camino. ¡Busca otro!',
    ],
    takeaway: 'El alfil va en diagonal.',
  },
  dama: {
    intro: ['La dama es la pieza más fuerte de todas.', 'Puede ir en línea recta, como la torre, y en diagonal, como el alfil.'],
    exercises: ['Recoge las dos estrellas.', 'Recoge las tres estrellas.', 'Recoge las cuatro estrellas con las menos jugadas que puedas.'],
    takeaway: 'La dama va recta y en diagonal.',
  },
  rey: {
    intro: ['El rey es la pieza más importante. ¡Hay que cuidarlo mucho!', 'Pero anda despacio: solo una casilla cada vez, hacia cualquier lado.'],
    exercises: ['Lleva el rey hasta la estrella.', 'Recoge las dos estrellas, paso a paso.', 'Recoge las dos estrellas. El rey también puede ir en diagonal.'],
    takeaway: 'El rey anda de una en una casilla.',
  },
  caballo: {
    intro: ['El caballo salta haciendo una ele: dos casillas hacia un lado y una más hacia el otro.', 'Es la única pieza que puede saltar por encima de las demás.'],
    exercises: [
      'Lleva el caballo hasta la estrella.',
      'Recoge las dos estrellas.',
      '¡El caballo salta por encima de tus peones!',
      'Recoge las tres estrellas.',
    ],
    takeaway: 'El caballo salta haciendo una ele.',
  },
  peon: {
    intro: ['El peón anda hacia delante, una casilla. La primera vez que se mueve, puede avanzar dos.', 'Nunca va hacia atrás. Y para capturar, va en diagonal.'],
    exercises: [
      'La primera vez, el peón puede avanzar dos casillas. ¡Hazlo de una vez!',
      'Recoge las dos estrellas.',
      'Captura las dos piezas negras. Recuerda: el peón captura en diagonal.',
      'Captura las tres piezas. Fíjate bien hacia dónde captura el peón.',
    ],
    takeaway: 'El peón anda recto y captura en diagonal.',
  },
  capturar: {
    title: 'Capturar',
    intro: ['Capturar es llevar tu pieza a la casilla de una pieza rival. La quitas del tablero y te pones en su sitio.'],
    exercises: [
      'Captura las dos piezas negras con la torre.',
      'Captura las tres piezas con el alfil.',
      'Captura las tres piezas con el caballo.',
      'Captura las cuatro piezas con la dama, con las menos jugadas que puedas.',
    ],
    takeaway: 'Capturar es quitar una pieza rival.',
  },
  'a-salvo': {
    title: '¡Que no te capturen!',
    intro: ['Las piezas negras también pueden capturar.', 'Antes de mover, mira si la casilla a la que vas está atacada.'],
    exercises: [
      'Captura las dos piezas sin que te capturen. ¿Por cuál empiezas?',
      'El peón negro protege al caballo. Captura los dos sin perder tu dama.',
      'Captura las tres piezas. ¡Cuidado con los peones negros!',
    ],
    takeaway: 'Antes de mover, mira qué ataca el rival.',
  },
  valor: {
    title: 'Lo que vale cada pieza',
    intro: ['Unas piezas valen más que otras. El peón vale 1. El caballo y el alfil, 3. La torre, 5. Y la dama, 9.', 'El rey no se puede capturar nunca.'],
    exercises: ['Puedes capturar tres piezas. ¡Llévate la que más vale!', 'El caballo puede capturar tres piezas. ¿Cuál te llevas?', 'El peón puede capturar a los dos lados. ¡Elige bien!'],
    takeaway: 'La dama vale más que todas.',
  },
  jaque: {
    intro: ['Dar jaque es atacar al rey del rival. Cuando su rey está en jaque, tiene que salvarlo enseguida.'],
    exercises: ['Da jaque al rey negro con la torre.', 'Da jaque con el alfil.', 'Da jaque con el caballo.'],
    takeaway: 'Jaque es atacar al rey.',
  },
  'salir-jaque': {
    intro: ['Para salvar al rey del jaque hay tres maneras: moverlo, capturar la pieza que ataca, o poner otra pieza en medio.'],
    exercises: ['¡Tu rey está en jaque! Aquí solo puedes salvarlo moviéndolo.', '¡Jaque otra vez! Ahora, captura la pieza que ataca.', 'Y ahora, pon una pieza en medio.'],
    takeaway: 'El rey se salva moviéndose, capturando o tapando.',
  },
  mate: {
    intro: ['Jaque mate es un jaque del que el rey no se puede salvar. ¡Quien da jaque mate gana la partida!'],
    exercises: [
      'Da jaque mate. Los peones negros no dejan escapar a su rey.',
      'Da jaque mate con la dama. Tu rey la ayuda.',
      'Da jaque mate con el caballo.',
      'Da jaque mate con la torre.',
    ],
    takeaway: '¡Jaque mate es ganar!',
  },
  ahogado: {
    intro: ['Ojo: si el rey rival no está en jaque, pero no puede moverse a ningún sitio, es ahogado. Y entonces es empate.'],
    exercises: ['Da jaque mate. ¡Pero no lo ahogues!', 'Otra vez: jaque mate, sin ahogarlo.'],
    takeaway: 'Ahogado es empate. ¡Cuidado!',
  },
  enroque: {
    intro: ['El enroque es una jugada especial: mueves el rey y la torre a la vez, para esconder al rey.', 'Para hacerlo, mueve el rey dos casillas hacia la torre. La torre salta sola al otro lado.'],
    exercises: ['Haz el enroque hacia el lado de la torre más cercana.', 'Ahora hazlo hacia el otro lado.'],
    takeaway: 'Con el enroque, el rey se esconde.',
  },
  coronar: {
    intro: ['Si un peón llega hasta el final del tablero, ¡se convierte en otra pieza! Casi siempre, en dama.'],
    exercises: ['Lleva el peón hasta el final y conviértelo en dama.', 'Captura y corona a la vez.'],
    takeaway: 'Un peón que llega al final se convierte en dama.',
  },
  'al-paso': {
    intro: ['Esta jugada es un poco rara. Si un peón rival avanza dos casillas y se pone al lado del tuyo, puedes capturarlo como si solo hubiera avanzado una.', 'Pero solo justo en ese momento.'],
    exercises: ['El peón negro acaba de avanzar dos casillas. ¡Captúralo al paso!', 'Otra vez: el peón negro acaba de llegar. ¡Aprovecha!'],
    takeaway: 'Al paso: solo justo después.',
  },
};

/** Frases del nivel Kids fuera del curso (ánimos, problemas de mate, botones con voz). Todas llevan audio. */
export const KIDS_LINES = {
  perfect: '¡Perfecto!',
  good: '¡Muy bien!',
  tryAgain: 'Casi. ¡Prueba otra vez!',
  attacked: '¡Uy! En esa casilla te capturarían. Prueba otra vez.',
  lessonDone: '¡Lección terminada!',
  courseDone: '¡Has terminado el curso! Ya sabes jugar al ajedrez.',
  matesIntro: 'Ahora, a dar jaque mate. Busca la jugada que gana.',
  mateYes: '¡Jaque mate! ¡Has ganado!',
  mateNo: 'Esa jugada no es jaque mate. ¡Prueba otra vez!',
  mateHint: 'Pista: busca una jugada que dé jaque.',
  mateHint2: 'Mira esta pieza. Con ella se da el jaque mate.',
  welcomeKids: '¡Hola! Soy tu entrenador de ajedrez. ¿Empezamos?',
} as const;
