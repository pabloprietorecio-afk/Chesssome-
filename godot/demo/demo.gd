extends Control
## Pantalla de problema de la app: problemas reales de Lichess sobre el tablero 3D, con su explicación.
## Todavía no es el entrenamiento completo (falta el test de nivel y la elección de problemas según el
## jugador), pero ya enseña lo que distingue a A Chess Way: cuando fallas, te explica qué tenía de bueno tu
## jugada y qué permite; cuando aciertas o pides la solución, por qué funciona, en cuatro niveles de
## profundidad. Las explicaciones vienen ya redactadas y verificadas (core/explain_data.gd).
## El estilo: aire de app móvil (letra grande, tonos pastel, iconos grandes y botones con su ilustración);
## ver docs/sistema-3d.md, «Diseño de la interfaz».
##
## Composición en un móvil alto: barra arriba, el tablero de lado a lado, debajo la tarjeta del entrenador
## (qué toca, qué ha pasado y la explicación, con desplazamiento si es larga) y, al pie, los botones, en la
## zona del pulgar. Las opciones no ocupan pantalla: se abren en una hoja inferior.

## STEP: se ha resuelto solo una jugada («Un paso») y se enseña su explicación; el jugador sigue con el resto.
enum Phase { INTRO, SOLVING, WRONG, REPLY, SOLVED, SHOWING, SHOWN, STEP }

const LIGHT := {
	"bg": Color("eaf1fb"), "surface": Color("ffffff"), "ink": Color("1b2540"), "quiet": Color("5b6782"),
	"accent": Color("ffa366"), "accent_ink": Color("1b2540"), "accent_text": Color("b84a0c"),
	"accent_soft": Color("ffe6d3"), "good": Color("1f7a44"), "bad": Color("c0392b"),
	"track": Color("c9d5e8"), "field": Color("eef3fb"), "scrim": Color(0.07, 0.1, 0.22, 0.42),
	"shadow": Color(0.16, 0.3, 0.6, 0.16), "sky": Color("cfe1fb"), "cloud": Color("f7fbff"),
	"glow": Color(1.0, 0.55, 0.25, 0.32),
	"wash_top": Color("dfe9ff"), "wash_mid": Color("efe9ff"), "wash_bottom": Color("fff2e8"),
}
const DARK := {
	"bg": Color("0a0f1e"), "surface": Color("161e38"), "ink": Color("edeff7"), "quiet": Color("a3acc4"),
	"accent": Color("ffa366"), "accent_ink": Color("1b2540"), "accent_text": Color("ffab73"),
	"accent_soft": Color("3a2416"), "good": Color("4cbf7a"), "bad": Color("ff7b7f"),
	"track": Color("2c3759"), "field": Color("1f2946"), "scrim": Color(0.0, 0.0, 0.03, 0.6),
	"shadow": Color(0.0, 0.0, 0.0, 0.36), "sky": Color("141d44"), "cloud": Color("f4e6b6"),
	"glow": Color(1.0, 0.5, 0.2, 0.22),
	"wash_top": Color("0d1330"), "wash_mid": Color("15173a"), "wash_bottom": Color("1c1530"),
}
## Tonos pastel para las teselas de los iconos y los botones ilustrados: [fondo, tinta].
const TINTS_LIGHT := {
	"peach": [Color("ffe3d3"), Color("d9591e")], "mint": [Color("dcf3e6"), Color("1b8a5a")],
	"lilac": [Color("e7e1fb"), Color("5b48c8")], "sky": [Color("d9e9ff"), Color("236fd1")],
	"butter": [Color("fff0c4"), Color("a86e00")], "rose": [Color("ffdde6"), Color("c93a6c")],
}
const TINTS_DARK := {
	"peach": [Color("472a1b"), Color("ffb48a")], "mint": [Color("173a2c"), Color("7fe0b0")],
	"lilac": [Color("2c2754"), Color("b9adff")], "sky": [Color("17304f"), Color("8fc2ff")],
	"butter": [Color("3f3312"), Color("ffd772")], "rose": [Color("47202f"), Color("ff9dbd")],
}
## Tamaños de letra, en unidades del lienzo (1080 de ancho). Un móvil corriente mide unos 393 puntos de
## ancho, así que un punto son unas 2,75 unidades: el cuerpo va a unos 15 puntos (antes iba a 12 y se leía
## pequeño en el teléfono).
const F_LARGE := 100
const F_TITLE := 66
const F_TITLE2 := 58
const F_HEAD := 46
const F_BODY := 42
const F_SUB := 38
const F_FOOT := 34
const F_CAP := 30
## Alto de la fila de botones del pie.
const BAR_HEIGHT := 142.0
## La vista 3D es algo más alta que el hueco del tablero y se funde con el fondo por arriba y por abajo:
## así caben la sombra del tablero y las cabezas de las piezas del fondo, y no se nota dónde acaba la vista.
const VIEW_BLEED_TOP := 64.0
const VIEW_BLEED_BOTTOM := 110.0
const VIEW_FADE := 48.0
## Alto mínimo que se reserva siempre a la tarjeta del entrenador. Lo que sobra por encima de lo que la
## tarjeta necesita en cada momento va de cielo, sobre el tablero (ver _card_room y _layout).
const CARD_MIN := 350.0
const SETTINGS_PATH := "user://chessome.cfg"
const WHY_LABELS := {1: "Explícame por qué", 2: "Ver la variante", 3: "Ver el análisis"}
const SOURCE_NAMES := {"motor": "Motor", "reglas": "Reglas", "lichess": "Lichess"}

var puzzles: Array = []
var index := 0
var puzzle: Dictionary = {}
## Índice de la jugada de la solución que toca jugar ahora.
var step := 0
## Índice de la jugada que se le pidió al jugador la última vez (para volver a ella).
var ask_step := 0
var fen_before := ""
var run_id := 0
var dark := false
var phase: Phase = Phase.INTRO
var options_open := false
var top_view := false
## Acabado del tablero (ver Board3D.FINISHES). El contorno de las piezas va puesto por defecto en toda la app.
const STYLES := ["madera", "marmol", "metal", "ilustrado"]
const STYLE_NAMES := ["Madera", "Mármol", "Metal", "Ilustrado"]
var board_style := "madera"
var board_outline := true
## Juego de piezas: figuras o fichas planas con el icono en relieve (Board3D.PIECE_SETS).
const SETS := ["clasico", "fichas", "simple"]
const SET_NAMES := ["Figuras", "Fichas", "Simple"]
var piece_set := "clasico"
## Mundos de piezas del nivel Kids (Board3D.FLAT_ATLAS): se ven en las partidas; las lecciones siguen con las piezas
## normales, para que el niño aprenda las de verdad. "" = sin mundo.
const WORLDS := ["", "aventura", "reino", "safari", "espacio", "piratas", "dino"]
const WORLD_NAMES := ["Normales", "Aventura 3D", "Reino", "Safari", "Espacio", "Piratas", "Dinos"]
var kids_world := ""
## «Retroceder» en un problema: cuántas jugadas atrás se está mirando (0 = la posición de ahora).
var browse_back := 0
## Entrenamiento por categoría: familia de problemas elegida en «Entrenar» ("" = lo que recomiende el entrenador).
var train_family := ""
## Repaso de un nivel ya superado (−1: entrenamiento normal) y el aviso bajo el camino de niveles.
var train_level := -1
var _path_hint: Label
## Explicación de la última jugada (la del rival, o la que se está repasando) a la vista.
var move_why_open := false
## Explicación paso a paso de una jugada (core/move_why.gd): sus párrafos, el que se ve y si el tablero se ha
## cambiado para enseñarlo (con lo que había antes, para volver).
var why_paras: Array = []
var why_idx := 0
var why_board := false
var why_saved := {}
## Paso a paso de la solución entera, tras resolver («Jugada a jugada»).
var why_story_open := false
## Al resolver: primero solo una ventana «¡Resuelto!» con «OK» (aparece un instante después de la última jugada,
## para verla); al cerrarla, debajo del tablero, «Paso a paso», «Resumen» y «¿Por qué?». El resumen, plegado.
var result_popup := false
var result_popup_at := 0
var result_popup_node: Control
var summary_open := false
## Al cargar un problema, el tablero queda quieto hasta pulsar «Comenzar»: entonces juega el rival.
var intro_waiting := false
## Para las pruebas automáticas: «Comenzar» se pulsa solo.
var auto_begin := false
## Icono del jugador dentro de su insignia: "" = la pieza de su rango, "piece_…" = una pieza fija, "foto" = su foto.
const AVATAR_PATH := "user://chessome_avatar.png"
var avatar := ""
var _avatar_tex: Texture2D
var sound_on := true
## Pista animada sobre el tablero: recuerda que se puede ampliar y girar. Viene activada y se apaga sola
## la primera vez que el jugador amplía, gira o desplaza el tablero (se puede volver a activar en Opciones).
var gesture_hint := true
## Pistas pedidas en la jugada actual: 0 ninguna, 1 el tema del problema, 2 además la pieza que hay que mover.
var hint_level := 0
## Posición tras la jugada que se resolvió con «Un paso» (para seguir desde ella).
var step_fen := ""

## Modo de la pantalla: "free" (los problemas en orden y sin nivel: es lo que usan las pruebas), "test" (test
## de nivel: un intento por problema y sin ayudas) o "train" (entrenamiento adaptado al nivel y al perfil).
var mode := "free":
	set(value):
		mode = value
		if view != null and view.board.piece_set != _shown_set():
			_sync_piece_set()
## Lo que la evaluación sabe de cada problema (Assessment.item_of), en el orden de la lista, y dónde está cada id.
var pool: Array = []
var _index_of := {}
## Número de cada problema dentro de su nivel, del más fácil al más difícil: id → [nivel, número].
var _numbers := {}
## El jugador: {rating, tries, done} (ver Assessment). Vacío hasta que hace el test o lo salta.
var player := {}
## Lo que dijo de su experiencia ("never", "rules", "casual" o "regular") y si saltó el test.
var experience := ""
var test_skipped := false
## El intento en curso: {item, t0, ms_first, fail_step, error, help, recorded} (ver _record).
var _try := {}
## Nivel antes y después del intento anotado en este problema (para enseñar el cambio al terminar).
var _rating_shown: Array = []
## Repaso de errores: en el entrenamiento, cada pocos problemas vuelve uno que se falló (los del test, los
## primeros), ahora con todas las ayudas y la explicación completa. No mueve el nivel. `reviewed` guarda los
## que ya se han repasado; `is_review`, si el problema en pantalla es un repaso.
var reviewed := {}
var is_review := false
var _since_review := 0
## «Repasar mis fallos» (Entrenar): una sesión solo con fallos sin resolver, del más antiguo al más reciente. En la
## sesión, cada fallo sale una vez (`_review_session_seen`); el que se salta sin resolver vuelve la próxima vez.
var review_session := false
var _review_session_seen := {}
var _review_session_total := 0
## Cada cuántos problemas nuevos toca un repaso, y cuántos problemas tienen que haber pasado desde el fallo.
const REVIEW_EVERY := 3
const REVIEW_GAP := 4
var _rng := RandomNumberGenerator.new()
const PLAYER_PATH := "user://chessome_jugador.json"

## Curso «Aprende a jugar» (data/curso.json, que genera scripts/export-course.ts con cada ejercicio comprobado).
const COURSE_PATH := "user://chessome_curso.json"
var course: Array = []
## Frases fijas del nivel Kids (curso.json → kidsLines).
var kids_lines := {}
## Nivel Kids (desde 8 años): textos muy sencillos con voz, solo el curso; salir pide la puerta para adultos.
var kids := false
## El vídeo de un final dentro de la app (fase 2 del cine; core/cine_film.gd y core/cine_player.gd). {} si no hay:
## {lesson, data (film del clip), st (estado del director), plies (pregunta de cada pausa), ply (posición enseñada),
## answered (pausas respondidas), err}. Sin el complemento de Android, nunca se activa.
var film := {}
var cine_player: CinePlayer = null
## Hueco del vídeo, arriba, entre la barra y el tablero: el reproductor nativo se coloca encima.
var video_slot: Control
## Anuncios entre actividades (core/ads.gd); sin el plugin de Android no hacen nada.
var ads := Ads.new()
## Pantalla de inicio que ha elegido el jugador: «lista» o «rejilla» (ui/home_screens.gd). Kids tiene la suya.
var home_style := "lista"
## Intro animada del arranque (ui/intro.gd): «always», «once» o «never» (Opciones → Intro).
var intro_mode := "always"
var intro_seen := false
## Vídeo del caballo de la próxima espera del análisis (en ciclo; se guarda).
var wait_clip := 0
const INTRO_MODES: Array[String] = ["always", "once", "never"]
const INTRO_NAMES: Array[String] = ["Siempre", "Una vez", "Nunca"]
var voice_on := true
## Voz del nivel Kids: texto exacto → id del audio (data/voz.json; los OGG en res://voz/, de Kokoro).
var voice_index := {}
## Índice de voces del idioma que no es el español (se carga al pedir la primera frase).
var _voice_lang := ""
var _voice_lang_index := {}
var voice_player: AudioStreamPlayer
var _voice_queue: Array = []
var _voice_last: Array = []
## «¡Muy bien!» grabado (Pixabay, TomyEducaST, licencia de contenido de Pixabay; ver godot/voz/humana/LEEME.md):
## suena delante de cada acierto en el nivel Kids. En las listas de _say se pide con BRAVO.
const BRAVO := "#bravo"
## Efectos de la interfaz (acierto, error, lección terminada) y música del nivel Kids: godot/sounds/ui/LEEME.md.
var music_on := true
var sfx_player: AudioStreamPlayer
var music_player: AudioStreamPlayer
var _sfx_cache := {}
const MUSIC_DB := -15.0
const MUSIC_DUCK_DB := -26.0
const BRAVO_PATH := "res://voz/humana/muy_bien.ogg"
## Modo Kids oculto (decisión de Pablo, 18 nov: la primera versión en Google Play es para mayores de 13 años). El
## código sigue aquí; sus voces, mundos, música y fondo no van en el paquete (export_presets.cfg, exclude_filter).
## Para volver a enseñarlo: true aquí y quitar esas exclusiones.
const KIDS_ENABLED := false
## Partida contra el rival (core/bot.gd): ajustes ({variant, level, fen, title, text, kids, unit}), color del
## jugador, posiciones tras cada jugada (para deshacer y para las repeticiones), estado ("play", "think", "over"),
## resultado (1 gana, 0 tablas, −1 pierde) y lo que se cuenta en la tarjeta.
var game := {}
var game_color := 0
var game_pick_color := 0
## Modalidad elegida en la página de partida: false = ajedrez clásico, true = War Chess (core/war_chess.gd).
var game_war := false
var game_bot: Bot
## Partida online (core/online.gd): el cliente de Firebase, si se está buscando rival, y el aviso de la pantalla.
var online: Online
var online_busy := false
## Cuándo empezó la búsqueda de rival (Time.get_ticks_msec), para el reloj de espera.
var online_wait_ms := 0
## Enseñar la foto propia al rival (solo si el icono es una foto). Desactivado salvo que se elija.
var online_photo := false
## Nombre con el que se juega online (se pide la primera vez).
var online_name := ""
## Espacios online (ritmos): el último elegido, el personalizado [minutos, segundos], los que esperan en cada uno
## (última consulta: {ritmo: n}) y si ya se ha consultado. Normas aceptadas (versión) y bloqueados (uid → nombre).
var online_space := "0+0"
## Modalidad de la lista de espacios online: War Chess (espacios «w5+3») o la clásica.
var online_war := false
var online_custom := [7, 2]
var online_spaces := {}
var online_spaces_ok := false
var _lobby_polling := false
const ONLINE_RULES_VERSION := 1
var online_rules_ok := 0
var online_blocked := {}
var _name_edit: LineEdit
var _name_error := ""
## Historial de partidas (core/game_log.gd), cargado la primera vez que hace falta; y si la partida de ahora ya se
## anotó.
var game_log := {}
var game_recorded := false
## Número de la partida (solo cambia al empezar otra; `run_id` cambia también al deshacer): las partidas gratis con
## el tutor se cuentan con él, para que deshacer no gaste otra.
var game_serial := 0
## La partida ha tenido ayudas (deshacer, pista, «Prueba otra vez»): se guarda, pero no cuenta para el nivel de juego.
var game_helped := false
## «Prueba otra vez»: la jugada mala que se puede repetir {fen (antes de jugarla), best (UCI)}; y, tras deshacerla, la
## posición que se está repitiendo (para celebrarlo si ahora aciertas).
var _retry := {}
var _retry_target := {}
## Pista del tutor tras deshacer («Busca algo mejor…») y la línea de celebración del nuevo intento.
var coach_hint := ""
var coach_retry_line := ""
## Adónde vuelve «Mis partidas»: "online" o "setup" (la página de jugar contra el ordenador).
var my_games_back := "online"
## Filtros de «Mis partidas»: resultado ("", "ganadas", "tablas", "perdidas") y cómo terminó (GameLog.reason).
var my_games_result := ""
var my_games_why := ""
## Fotos de rivales ya decodificadas, por identificador.
var _photo_cache := {}
## Lo que enseña el rival y su foto ya decodificada.
var online_rival := {}
var _rival_tex: Texture2D
## Partida online: cuántas jugadas se ha ido hacia atrás (0 = en directo) y las del rival que llegan mientras.
var game_back := 0
var _online_pending: Array = []
var online_status := ""
## Aviso (no de error) de la búsqueda: «Has entrado en su partida; esperando a que vuelva…».
var online_note := ""
## Espera online sin nadie (core/wait_bot.gd): pasado un rato se ofrece jugar contra Robi, un bot de la app.
var online_bot_offer := false
var _wait_gen := 0
var _bot_cheer_at := -99
var game_history: Array = []
## Jugadas de la partida (UCI), una menos que game_history.
var game_moves: Array = []
## Análisis educativo (core/review.gd): momentos, si ya está hecho, el que se está viendo en el tablero, y el
## hilo que lo calcula. Problemas pendientes de una práctica pedida desde el análisis.
var review: Array = []
var review_done := false
var review_at := -1
var _review_thread: Thread
## Detalle de la partida jugada a jugada (core/game_detail.gd): las entradas, la que se ve y el cálculo en marcha.
var detail: Array = []
var detail_done := false
var detail_at := -1
var _detail_progress: Label
## Animación de las pantallas de espera del análisis: el caballo del logo (ui/knight_wait.gd).
var _wait_anim: KnightWait
var practice_queue: Array = []
const GAMES_PATH := "user://chessome_partidas.json"
var game_state := ""
var game_won := 0
var game_result := ""
var game_note := ""
## Profesor IA (premium, core/coach_ai.gd): la corrección de la última jugada del jugador, aparte de game_note
## (que dice qué ha jugado el rival). coach_from_ai: la ha redactado la IA (si no, es el texto comprobado).
var coach: CoachAI
## Compras en Google Play (Premium y recargas).
var pagos: Pagos
var coach_note := ""
var coach_from_ai := false
var coach_waiting := false
## La explicación entera (se abre en una ventana con «Ver completa»); en la tarjeta va `coach_note`, más corta.
var coach_full := ""
var _coach_short := ""
var _coach_verified := ""
## Tutor con Stockfish: la valoración llega del servidor (CoachAI.judge_remote); mientras, el motor local analiza
## por si no llega. `coach_lesson`: lo que hace falta para enseñar la jugada sobre el tablero ({fen, uci, verdict,
## lines: {played, best} con {uci, fen, arrows, text}, summary, advice, asked, ready}).
## Preguntas libres al tutor (petición de Pablo, 21 nov): "" cerrada, "edit" escribiendo, "listen" escuchando por
## voz, "wait" esperando la respuesta, "answer" con respuesta, "error".
var ask_state := ""
var ask_text := ""
var ask_answer := {}
var ask_error := 0
var ask_edit: LineEdit
## La ventana de preguntas sirve al tutor («tutor») y al asistente de la app («assistant»).
var ask_mode := "tutor"
## Botón flotante del asistente (en todas las pantallas, menos en Kids).
var assistant_button: Button
## Preguntas y respuestas de esta partida ({q, a}), para que el tutor siga el hilo.
var ask_history: Array = []
var tutor_voice: TutorVoice
## La voz del tutor (core/tutor_speech.gd): lee sus respuestas con el lector de texto del móvil. Opciones → Premium.
var tutor_speech: TutorSpeech
var tutor_speech_on := true
## Lo que dijo el tutor la última vez (para el botón «Escuchar»).
var _speech_text := ""
## Stockfish 19 dentro del móvil (android_motor/): valora las jugadas del tutor sin depender del servidor.
var local_engine: LocalEngine
var _ask_gen := 0
## Probabilidad de ganar del jugador tras su jugada anterior (la última valoración); −1 si no hay. Sirve para
## distinguir la oportunidad perdida del error.
var _coach_prev_win := -1
## Partida gratis con profesor en curso (1…5), o 0 (premium, o sin prueba).
var coach_trial_game := 0
var coach_lesson := {}
var _coach_local := {}
var _coach_local_uci := ""
var _coach_remote_wait := false
const COACH_REMOTE_S := 6.0
## La lección sobre el tablero: abierta, qué línea («played» o «best») y qué jugada se está viendo.
var lesson_open := false
var lesson_line := "played"
var lesson_step := 0
var _lesson_token := 0
## Solo en el APK de pruebas: qué ha decidido el profesor con la última jugada y por qué.
var coach_debug := ""
## Valoración de la última jugada (GameDetail: best, good, inaccuracy, mistake, blunder) y su chapa en el tablero.
var coach_verdict := ""
var _coach_badge_sq := -1
var _coach_badge_uci := ""
## El análisis de la última jugada sigue en marcha: el rival espera a que salga la valoración antes de mover.
var _coach_pending := false
## Leyenda de las chapas, encima del tablero (con el profesor): las cinco valoraciones, con la de tu última jugada
## resaltada. Flota en el hueco entre la barra y el tablero, como la pista de gestos; si no cabe, no sale y la
## valoración va en la tarjeta.
var coach_legend: HBoxContainer
## El rival del Campeonato encima del tablero (ver _sync_camp_tag).
var camp_tag: Control
var _camp_tag_key := ""
var _camp_tag_top := 0.0
var _coach_legend_key := ""
var _coach_legend_was := false
const COACH_LEGEND_H := 112.0
## Lado de la cara del rival del Campeonato encima del tablero (px).
const CAMP_TAG_FACE := 116.0
const COACH_LEGEND := [GameDetail.BEST, GameDetail.GOOD, GameDetail.INACCURACY, GameDetail.MISTAKE, GameDetail.BLUNDER]
var _coach_badge_kind := ""
var _coach_gen := 0
var _coach_threads: Array[Thread] = []
const COACH_SECONDS := 0.8
## Opacidad del fondo de la ventana de la explicación (las demás ventanas: 0,86).
const COACH_WINDOW_ALPHA := 0.62
## Ventanas con texto largo (respuestas, explicación entera): casi opacas, para leer sin las piezas detrás (Pablo,
## 22 nov). Las cortas (escribir, esperando) siguen al COACH_WINDOW_ALPHA para ver el tablero.
const READING_WINDOW_ALPHA := 0.88
## Largo máximo de una frase del asistente en el aviso breve (más larga, en la ventana).
const TOAST_MAX := 60
## La ventana de la explicación se puede arrastrar (para destapar el tablero); se acuerda de dónde se dejó.
var _coach_window_pos := Vector2.INF
var _coach_window_drag := false
var _coach_key_edit: LineEdit
var _game_thread: Thread
## Reloj: ritmo elegido (índice de TIME_CONTROLS), el personalizado, y en la partida el tiempo que le queda a
## cada bando (ms; 0 blancas, 1 negras) y el incremento por jugada.
var game_tc_pick := 0
var custom_minutes := 10
var custom_increment := 0
var game_clocked := false
var game_clock := [0.0, 0.0]
var game_inc_ms := 0.0
var _clock_labels: Array = []
## El reloj «de verdad» de la tarjeta (se rehace con la tarjeta) y la altura de tu pulsador (1 arriba, 0 abajo),
## que baja o sube poco a poco cuando cambia el lado que corre.
var chess_clock: ChessClock
var clock_up := 1.0
var _digits_font: FontVariation
## Ventana de confirmación abierta (rendirse, salir).
var confirm_node: Control
## La ventana de preguntas (o del asistente) está abierta.
var _ask_window_up := false
## Pulsar el reloj tras cada jugada, como en una partida de verdad (ajuste; por defecto, sí), y avisar si no se
## pulsa en PRESS_REMINDER segundos (ajuste; por defecto, sí). Bando cuyo reloj corre ahora.
var press_clock := true
var press_reminder := true
const PRESS_REMINDER := 15.0
var game_clock_side := 0
var _press_since := 0
var _press_warned := false
## Respuesta correcta de la puerta para adultos abierta (−1 si no hay ninguna).
var _gate_answer := -1
var _gate_then: Callable
## Lecciones terminadas: id → estrellas (1–3).
var course_done := {}
var lesson := {}
## Paso de la lección: −1 la introducción; 0…n−1 los ejercicios; n el final.
var lesson_ex := -1
var ex := {}
## "intro", "info", "play", "fail", "done" o "end".
var ex_state := ""
var ex_moves := 0
var ex_fails := 0
var ex_text := ""
## Lecciones: la última jugada del ejercicio y si se está viendo su «¿Por qué?» (con flechas en el tablero).
var ex_last_uci := ""
var learn_why_open := false
var ex_good := false
var ex_stars: Array = []
## Piezas negras que quedan en un ejercicio de recoger (para sonar al capturar una).
var _ex_blacks := 0
## Problemas resueltos seguidos en el entrenamiento (para los ánimos).
var _streak := 0
var _celebration: Control
## Con false no se leen ni se guardan los ajustes ni se enseña la bienvenida (lo usan las pruebas).
var use_settings := true
## Idioma de la app (Loc.LANGUAGES). La primera vez, el del móvil si la app lo tiene; si no, inglés.
var language := "es"
## La hoja de idiomas se abrió desde Opciones (al elegir se vuelve a Opciones) o desde el tablerito del inicio.
var _lang_from_options := false
var welcome_seen := false
## Se ha enseñado ya la ventana de idioma de la primera vez (sale sola una vez, sobre la bienvenida).
var lang_asked := false
var app_version := ""
## Reto del día, racha, reto semanal e insignias (core/progress.gd), cargado la primera vez que hace falta.
var prog := {}

## Explicaciones del problema actual y lo que se está enseñando de ellas.
var explain: ExplainData
## Explicación a la vista ({} si no hay), nivel abierto (1–4) y punto de decisión al que se refiere.
var expl: Dictionary = {}
var exp_level := 1
var exp_point := 0
## El jugador todavía puede reintentar: se le cuenta qué hace su jugada y qué permite, no cuál era la mejor.
var exp_partial := false
## Último fallo en el punto de decisión actual: {point, uci}.
var last_wrong: Dictionary = {}
## «¿Y si juego…?»: el jugador prueba jugadas en la posición de decisión y recibe su explicación.
var whatif := false
var whatif_exp: Dictionary = {}
var whatif_level := 1
var facts_open := false
## Variante que se está viendo en el tablero ({} si ninguna) y por qué jugada va (−1 = al principio).
var line_on: Dictionary = {}
var line_ply := -1
var sheet_kind := ""
var _keep_scroll := false
var _gap_tween: Tween
## Mientras se decide una misma jugada el tablero solo sube (cuando la explicación pide sitio); vuelve a bajar
## cuando toca la jugada siguiente o empieza otro problema. Así no se mueve bajo el dedo entre un intento y otro.
var _gap_limit := INF
## Alto de todo lo que no es tablero, cielo ni tarjeta (barra, botones y márgenes), según el último reparto.
var _fixed_height := 0.0
var _ai_status: Label
var _saved_anim := int(Board3D.Anim.FULL)
## Si el jugador eligió las animaciones él mismo (si no, valen las de por defecto, aunque cambien).
var _anim_chosen := false
var _saved_lock := false

var view: BoardView3D
var bg: SkyBackdrop
var bar_row: Control
var chrome: VBoxContainer
var board_slot: Control
## En las partidas, las piezas comidas: arriba las que ha comido el bando de arriba, abajo las del de abajo.
var cap_top: CaptureStrip
var cap_bottom: CaptureStrip
var _cap_key := ""
const CAP_H := 64.0
var top_gap: Control
var card_pad: MarginContainer
var card: PanelContainer
var card_scroll: ScrollContainer
var card_style: StyleBoxFlat
## Cuánto sube ahora la tarjeta por encima de su sitio, sobre el tablero (0 = en su sitio).
var _card_float := 0.0
## Alto del tablero y del cielo de encima que da _layout, antes de que una explicación larga los recorte (_fit_card).
var _natural_board_h := 0.0
var _natural_gap := 0.0
var card_body: VBoxContainer
var counter: Label
## Interruptor «Tutor IA» de la barra, en las partidas (ver _sync_tutor_toggle).
var tutor_toggle: Button
var _tutor_switch: Switch
## Marca verde junto al nombre del problema si ya está resuelto.
var counter_check: TextureRect
var title: Label
var turn_dot: TurnMark
## Botones del pie. left_button es «Solución» (o «Repetir» al terminar); right_button, «Saltar» («Siguiente»
## al terminar, «Seguir» tras resolver un paso). hint_button y step_button solo existen mientras se resuelve.
var actions: HBoxContainer
var left_button: Button
var right_button: Button
var hint_button: Button
var step_button: Button
var pin_button: Button
var home_button: Button
var view_button: Button
var options_button: Button
var gesture_tip: GestureHint
var _actions_mode := ""
var _tip_note := false
var _tip_note_id := 0
var overlay: Control
## Zona desplazable de la hoja abierta (opciones o ayuda).
var sheet_scroll: ScrollContainer
var welcome: Control
## Fondo de juguetes del nivel Kids sobre el cielo, y la ventana con el resultado de un ejercicio de lección.
var kids_wall: TextureRect
var learn_popup: Control
var _popup_row: Array = []
## Página a pantalla completa abierta: la pregunta de experiencia ("experience"), el resultado del test
## ("result") o el progreso ("progress"). Y su zona desplazable.
var progress: Control
var progress_kind := ""
var progress_scroll: ScrollContainer
## Píldora de la barra con el nivel del jugador (solo en el entrenamiento): abre el progreso.
var level_pill: Button
var level_slot: Button

var font_regular: Font
var font_medium: Font
var font_semibold: Font
var font_display: Font


## Fondo de la pantalla: cielo. Arriba es algo más intenso y se va fundiendo con el color de fondo; en el
## hueco que queda sobre el tablero en los móviles altos hay unas nubes (de día) o la luna y estrellas (de noche).
## Es el sitio previsto para los paisajes con el tiempo real (docs/estilo-2d.md); de momento, un cielo quieto.
class SkyBackdrop extends Control:
	var base := Color.WHITE
	var top := Color.WHITE
	var ornament := Color.WHITE
	var night := false
	## Franja libre para los adornos: desde debajo de la barra hasta donde empieza la vista del tablero.
	var band_top := 0.0
	var band_bottom := 0.0
	## Si es mayor que cero, los adornos no bajan de aquí (debajo va la pista de gestos).
	var ornament_bottom := -1.0

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), base)
		var fade_end := clampf(band_bottom, 0.0, size.y)
		if fade_end > 8.0:
			draw_polygon(
				PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0.0), Vector2(size.x, fade_end), Vector2(0.0, fade_end)]),
				PackedColorArray([top, top, base, base]))
		var band := (ornament_bottom if ornament_bottom > 0.0 else band_bottom) - band_top
		if band < 200.0:
			return
		if night:
			_stars(band)
			_moon(Vector2(size.x * 0.2, band_top + band * 0.42))
		else:
			_cloud(Vector2(size.x * 0.25, band_top + band * 0.4), 1.2)
			_cloud(Vector2(size.x * 0.74, band_top + band * 0.68), 0.84)
			_cloud(Vector2(size.x * 0.58, band_top + band * 0.15), 0.54)

	func _sky_at(y: float) -> Color:
		return top.lerp(base, clampf(y / maxf(band_bottom, 1.0), 0.0, 1.0))

	func _cloud(c: Vector2, k: float) -> void:
		var body := StyleBoxFlat.new()
		body.bg_color = ornament
		body.set_corner_radius_all(int(24.0 * k))
		draw_style_box(body, Rect2(c + Vector2(-96.0, -8.0) * k, Vector2(196.0, 48.0) * k))
		for puff: Vector3 in [Vector3(-56.0, -4.0, 32.0), Vector3(-14.0, -22.0, 46.0), Vector3(36.0, -10.0, 38.0), Vector3(70.0, 8.0, 26.0)]:
			draw_circle(c + Vector2(puff.x, puff.y) * k, puff.z * k, ornament, true, -1.0, true)

	func _moon(c: Vector2) -> void:
		draw_circle(c, 30.0, ornament, true, -1.0, true)
		# El mordisco de la luna: un círculo del color del cielo en ese punto.
		draw_circle(c + Vector2(13.0, -9.0), 26.0, _sky_at(c.y - 9.0), true, -1.0, true)

	func _stars(band: float) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 20261113
		for i in 26:
			var p := Vector2(rng.randf_range(36.0, size.x - 36.0), band_top + rng.randf_range(0.02, 0.86) * band)
			var r := rng.randf_range(1.6, 3.4)
			var a := rng.randf_range(0.28, 0.9)
			draw_circle(p, r, Color(0.86, 0.91, 1.0, a), true, -1.0, true)


## Fondo de la bienvenida: un degradado pastel de arriba abajo con unas manchas de color muy suaves.
class PastelBackdrop extends Control:
	var top := Color.WHITE
	var mid := Color.WHITE
	var bottom := Color.WHITE
	## Manchas: [centro (0–1, 0–1), radio (en anchos de pantalla), color].
	var blobs: Array = []

	func _draw() -> void:
		var h := size.y * 0.5
		draw_polygon(
			PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0.0), Vector2(size.x, h), Vector2(0.0, h)]),
			PackedColorArray([top, top, mid, mid]))
		draw_polygon(
			PackedVector2Array([Vector2(0.0, h), Vector2(size.x, h), Vector2(size.x, size.y), Vector2(0.0, size.y)]),
			PackedColorArray([mid, mid, bottom, bottom]))
		for blob: Array in blobs:
			var c := Vector2(float(blob[0].x) * size.x, float(blob[0].y) * size.y)
			var r := float(blob[1]) * size.x
			var inner: Color = blob[2]
			var outer := Color(inner.r, inner.g, inner.b, 0.0)
			# Abanico de triángulos: opaco en el centro y transparente en el borde.
			var steps := 40
			for i in steps:
				var a0 := TAU * float(i) / float(steps)
				var a1 := TAU * float(i + 1) / float(steps)
				draw_polygon(
					PackedVector2Array([c, c + Vector2(cos(a0), sin(a0)) * r, c + Vector2(cos(a1), sin(a1)) * r]),
					PackedColorArray([inner, outer, outer]))


## Pista animada sobre el tablero: dos dedos que primero se separan (el tablero crece) y luego giran (el
## tablero gira con ellos), junto a un texto. También sirve para avisos breves (por ejemplo, al fijar el giro).
## Insignia del nivel: un círculo del color del rango con su pieza (peón, caballo, alfil, torre, dama, rey), un
## aro que se va llenando hasta el nivel siguiente y el número del nivel en una burbuja.
class LevelBadge extends Control:
	var fill := Color.WHITE
	var ring := Color.BLACK
	var track := Color.GRAY
	var bubble := Color.WHITE
	var bubble_ink := Color.BLACK
	var progress := 0.0
	var level := 0
	## Texto de la burbuja en vez del nivel (el Elo de juego, «1566»): una píldora más ancha.
	var label := ""
	## Sin la burbuja del número (el ordenador o un rival sin nivel).
	var no_level := false
	var font: Font

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		draw_circle(c, r, Color(0, 0, 0, 0.08))
		draw_circle(c, r - 2.0, fill)
		var w := maxf(5.0, r * 0.1)
		draw_arc(c, r - w * 0.5 - 1.0, 0.0, TAU, 64, track, w, true)
		if progress > 0.0:
			draw_arc(c, r - w * 0.5 - 1.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(progress, 0.0, 1.0), 64, ring, w, true)
		# Burbuja con el número, abajo a la derecha.
		if no_level:
			return
		if label != "" and font != null:
			# Píldora abajo, centrada, con el Elo de juego.
			var lfs := int(r * 0.36)
			var ltw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs).x
			var ph := lfs * 1.35
			var rect := Rect2(c.x - ltw * 0.5 - lfs * 0.45, c.y + r - ph - 3.0, ltw + lfs * 0.9, ph)
			var edge := StyleBoxFlat.new()
			edge.bg_color = fill
			edge.set_corner_radius_all(int(ph * 0.5 + 3.0))
			draw_style_box(edge, rect.grow(3.0))
			var pill := StyleBoxFlat.new()
			pill.bg_color = bubble
			pill.set_corner_radius_all(int(ph * 0.5))
			draw_style_box(pill, rect)
			draw_string(font, Vector2(c.x - ltw * 0.5, rect.position.y + ph * 0.5 + lfs * 0.36), label, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs, bubble_ink)
			return
		var br := r * 0.36
		var bc := c + Vector2(r * 0.7, r * 0.7)
		draw_circle(bc, br + 3.0, fill)
		draw_circle(bc, br, bubble)
		if font != null:
			var t := str(level)
			var fs := int(br * 1.15)
			var tw := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(font, bc + Vector2(-tw * 0.5, fs * 0.36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, bubble_ink)


## Camino de niveles ilustrado: un sendero entre montañas con un disco por nivel (del 0 al 10), del «Inicio» a la
## «Meta». Los niveles superados van en oro con una marca verde; el actual brilla, lleva la pieza del jugador y su
## avance hacia el siguiente; los que faltan, en plata con candado. Se pulsa un disco: señal level_pressed.
class LevelPath extends Control:
	signal level_pressed(level: int)

	const COUNT := 11
	var level := 0
	var progress := 0.0
	var light := Color.WHITE
	var dark := Color.GRAY
	var done := Color.ORANGE
	var ink := Color.BLACK
	var quiet := Color.GRAY
	var good := Color("1f7a44")
	var night := false
	var font: Font
	var marker: Texture2D
	var goal: Texture2D
	var _press := Vector2(-1.0, -1.0)

	func _unit() -> float:
		return minf(size.x / 7.0, size.y / 3.95)

	func _left() -> float:
		return (size.x - _unit() * 7.0) * 0.5

	## Centro de cada punto del camino: −1 el inicio, 0…10 los niveles, 11 la meta.
	func _spot(i: int) -> Vector2:
		var u := _unit()
		var x0 := _left()
		if i < 0:
			return Vector2(x0 + 0.55 * u, 1.38 * u)
		if i <= 5:
			return Vector2(x0 + (1.45 + float(i)) * u, (1.38 + 0.12 * sin(float(i) * 1.3)) * u)
		if i <= 10:
			return Vector2(x0 + (6.05 - float(i - 6) * 1.0) * u, (3.0 + 0.1 * sin(float(i) * 1.1)) * u)
		return Vector2(x0 + 1.0 * u, 3.0 * u)

	func _radius(i: int) -> float:
		return _unit() * (0.36 if i <= 5 else 0.4)

	## Puntos del sendero, suavizados (Catmull-Rom), con su recorrido acumulado.
	func _road() -> Array:
		var u := _unit()
		var keys: Array[Vector2] = [_spot(-1)]
		for i in 6:
			keys.append(_spot(i))
		keys.append(Vector2(_left() + 6.85 * u, 2.2 * u))
		for i in range(6, 11):
			keys.append(_spot(i))
		keys.append(_spot(11))
		var pts := PackedVector2Array()
		for k in keys.size() - 1:
			var p0: Vector2 = keys[maxi(k - 1, 0)]
			var p1: Vector2 = keys[k]
			var p2: Vector2 = keys[k + 1]
			var p3: Vector2 = keys[mini(k + 2, keys.size() - 1)]
			for s in 10:
				var t := float(s) / 10.0
				var t2 := t * t
				var t3 := t2 * t
				pts.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
		pts.append(keys[keys.size() - 1])
		return [pts, keys]

	func _ellipse(c: Vector2, r: float, squash: float, col: Color) -> void:
		var pts := PackedVector2Array()
		for k in 36:
			var a := TAU * float(k) / 36.0
			pts.append(c + Vector2(cos(a) * r, sin(a) * r * squash))
		draw_colored_polygon(pts, col)

	func _hills(base_y: float, amp: float, col: Color, phase: float, bottom: float) -> void:
		var pts := PackedVector2Array()
		var steps := 40
		for k in steps + 1:
			var x := size.x * float(k) / float(steps)
			var y := base_y - amp * (0.55 + 0.45 * sin(x / size.x * TAU * 1.3 + phase)) - amp * 0.35 * sin(x / size.x * TAU * 3.1 + phase * 2.0)
			pts.append(Vector2(x, y))
		pts.append(Vector2(size.x, bottom))
		pts.append(Vector2(0.0, bottom))
		draw_colored_polygon(pts, col)

	func _draw() -> void:
		var u := _unit()
		var sky := Color("eaf2ff") if not night else Color("141b3a")
		var far := Color("c6d3f0") if not night else Color("26315a")
		var far2 := Color("d8e2f6") if not night else Color("1e2850")
		var rock := Color("d9d2c5") if not night else Color("2c3350")
		var rock_dark := Color("c4bba9") if not night else Color("252b45")
		var grass := Color("cfe6c0") if not night else Color("1f3a35")
		var grass2 := Color("bcdcaa") if not night else Color("1b332e")
		var cloud := Color(1, 1, 1, 0.8) if not night else Color(0.75, 0.8, 1.0, 0.12)
		# Paisaje: cielo, montañas al fondo, una repisa de roca con hierba por fila y nubes abajo.
		draw_rect(Rect2(Vector2.ZERO, size), sky)
		_hills(0.9 * u, 0.6 * u, far2, 2.6, size.y)
		_hills(1.15 * u, 0.7 * u, far, 0.4, size.y)
		_hills(2.35 * u, 0.2 * u, rock_dark, 1.7, size.y)
		_hills(2.2 * u, 0.25 * u, rock, 1.1, size.y)
		_hills(1.9 * u, 0.5 * u, grass, 2.3, 2.2 * u)
		_hills(3.95 * u, 0.25 * u, rock_dark, 0.9, size.y)
		_hills(3.3 * u, 0.42 * u, grass2, 3.1, 3.85 * u)
		for c: Array in [[0.1, 3.82, 0.6], [0.48, 3.92, 0.8], [0.92, 3.8, 0.62], [0.95, 0.45, 0.4], [0.3, 0.35, 0.32]]:
			_ellipse(Vector2(size.x * float(c[0]), u * float(c[1])), u * float(c[2]), 0.35, cloud)
		# El sendero: sombra, tramo ya recorrido en oro y tramo que falta en blanco.
		var road: Array = _road()
		var pts: PackedVector2Array = road[0]
		var reach := 10 * (1 + clampi(level, 0, 10)) # el inicio + un tramo por nivel alcanzado
		if level >= 6:
			reach += 10 # la curva del lado derecho
		reach = mini(reach, pts.size() - 1)
		var w := u * 0.2
		draw_polyline(pts, Color(0, 0, 0, 0.12 if not night else 0.3), w + 10.0, true)
		draw_polyline(pts, Color(1, 1, 1, 0.92) if not night else Color(0.8, 0.84, 0.95, 0.35), w, true)
		if reach > 0:
			var gold := pts.slice(0, reach + 1)
			draw_polyline(gold, Color("f0b93a"), w, true)
			draw_polyline(gold, Color(1.0, 0.93, 0.7, 0.8), w * 0.3, true)
		# Inicio y meta.
		_flag(_spot(-1), "Inicio", ink)
		_flag(_spot(11), "Meta", done if level >= 10 else quiet)
		# Los discos, de atrás adelante.
		for i in COUNT:
			_disc(i)
		var top := clampi(level, 0, 10)
		_marker(top)

	func _flag(c: Vector2, label: String, col: Color) -> void:
		var u := _unit()
		_ellipse(c + Vector2(0.0, u * 0.18), u * 0.32, 0.35, Color(0, 0, 0, 0.12))
		if goal != null:
			draw_texture_rect(goal, Rect2(c - Vector2(u * 0.3, u * 0.5), Vector2(u * 0.6, u * 0.6)), false, col)
		if font != null:
			var fs := int(u * 0.2)
			var tw := font.get_string_size(Loc.t(label), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(font, c + Vector2(-tw * 0.5, u * 0.38), Loc.t(label), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

	func _disc(i: int) -> void:
		var c := _spot(i)
		var r := _radius(i)
		var thick := r * 0.28
		var top_col: Color
		var side_col: Color
		var num_col: Color
		if i < level:
			top_col = Color("f4c95d")
			side_col = Color("c58b22")
			num_col = Color("6b4810")
		elif i == level:
			top_col = Color("ffd75e")
			side_col = Color("d39a1f")
			num_col = Color("5e3d06")
			for g in 3:
				_ellipse(c, r * (1.55 - 0.18 * float(g)), 0.62, Color(1.0, 0.85, 0.3, 0.12 + 0.07 * float(g)))
		else:
			top_col = Color("eef1f6") if not night else Color("8a93a8")
			side_col = Color("aab3c2") if not night else Color("596278")
			num_col = Color("5b6476") if not night else Color("1c2236")
		_ellipse(c + Vector2(0.0, thick + r * 0.22), r * 1.05, 0.5, Color(0, 0, 0, 0.16))
		_ellipse(c + Vector2(0.0, thick), r, 0.62, side_col)
		draw_rect(Rect2(c.x - r, c.y, r * 2.0, thick), side_col)
		_ellipse(c, r, 0.62, top_col)
		_ellipse(c + Vector2(-r * 0.18, -r * 0.14), r * 0.62, 0.45, Color(1, 1, 1, 0.28))
		if i == level and i < 10:
			# Avance hacia el siguiente nivel: un anillo sobre el disco.
			var ring := PackedVector2Array()
			var steps := maxi(2, int(40.0 * clampf(progress, 0.02, 1.0)))
			for k in steps + 1:
				var a := -PI * 0.5 + TAU * clampf(progress, 0.02, 1.0) * float(k) / float(steps)
				ring.append(c + Vector2(cos(a) * r * 1.12, sin(a) * r * 1.12 * 0.62))
			draw_polyline(ring, good, 5.0, true)
		if font != null:
			var t := str(i)
			var fs := int(r * 0.78)
			var tw := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(font, c + Vector2(-tw * 0.5, fs * 0.33), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, num_col)
		if i < level:
			_badge_check(c + Vector2(r * 0.62, -r * 0.62))
		elif i > level:
			_badge_lock(c + Vector2(r * 0.62, -r * 0.62), r * 0.34)

	func _badge_check(c: Vector2) -> void:
		var r := _unit() * 0.13
		draw_circle(c, r + 3.0, Color(1, 1, 1, 0.95))
		draw_circle(c, r, good)
		draw_polyline(PackedVector2Array([c + Vector2(-r * 0.48, 0.0), c + Vector2(-r * 0.1, r * 0.4), c + Vector2(r * 0.52, -r * 0.38)]), Color.WHITE, maxf(2.0, r * 0.26), true)

	func _badge_lock(c: Vector2, r: float) -> void:
		var bg := Color("5b6476") if not night else Color("2a3048")
		draw_circle(c, r + 3.0, Color(1, 1, 1, 0.9) if not night else Color(0.6, 0.65, 0.8, 0.4))
		draw_circle(c, r, bg)
		var bw := r * 0.9
		var bh := r * 0.7
		draw_arc(c + Vector2(0.0, -r * 0.12), r * 0.32, PI, TAU, 12, Color.WHITE, maxf(2.0, r * 0.16), true)
		draw_rect(Rect2(c + Vector2(-bw * 0.5, -r * 0.12), Vector2(bw, bh)), Color.WHITE)

	func _marker(i: int) -> void:
		var c := _spot(i)
		var r := _radius(i)
		var u := _unit()
		var side := r * 1.5
		var base := c.y - r * 0.3
		if marker != null:
			# La pieza del jugador, de pie detrás del número del disco.
			_ellipse(Vector2(c.x, base), side * 0.32, 0.4, Color(0, 0, 0, 0.18))
			draw_texture_rect(marker, Rect2(Vector2(c.x - side * 0.5, base - side), Vector2(side, side)), false, ink)
		if font != null:
			var label := "Nivel actual"
			var fs := int(u * 0.17)
			var tw := font.get_string_size(Loc.t(label), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var h := float(fs) * 1.5
			var y := maxf(2.0, base - side - h - 6.0)
			var pill := Rect2(c.x - tw * 0.5 - 14.0, y, tw + 28.0, h)
			pill.position.x = clampf(pill.position.x, 2.0, size.x - pill.size.x - 2.0)
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color("fff4cf") if not night else Color("4a3b12")
			sb.border_color = Color("e6b43c")
			sb.set_border_width_all(2)
			sb.set_corner_radius_all(int(h * 0.5))
			draw_style_box(sb, pill)
			draw_string(font, Vector2(pill.position.x + 14.0, y + h * 0.5 + fs * 0.36), Loc.t(label), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("5e3d06") if not night else Color("ffe6a3"))

	## Disco bajo un punto (−1 si ninguno).
	func level_at(p: Vector2) -> int:
		var best := -1
		var best_d := INF
		for i in COUNT:
			var d := p.distance_to(_spot(i))
			if d < _radius(i) * 1.35 and d < best_d:
				best = i
				best_d = d
		return best

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			var mb := event as InputEventMouseButton
			if mb.pressed:
				_press = mb.position
			elif _press.x >= 0.0:
				if mb.position.distance_to(_press) < 24.0:
					var i := level_at(mb.position)
					if i >= 0:
						level_pressed.emit(i)
				_press = Vector2(-1.0, -1.0)


## Confeti: papelitos de colores que saltan desde un punto y caen girando. Se borra solo al acabar.
class Confetti extends Control:
	var bits: Array = []
	var life := 0.0
	var duration := 2.6

	func burst(origin: Vector2, count: int, colors: Array, power: float) -> void:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		for i in count:
			var angle := rng.randf_range(-PI * 0.95, -PI * 0.05)
			var speed := rng.randf_range(0.45, 1.0) * power
			bits.append({
				"p": origin, "v": Vector2(cos(angle), sin(angle)) * speed,
				"c": colors[rng.randi() % colors.size()], "r": rng.randf() * TAU, "w": rng.randf_range(-9.0, 9.0),
				"s": Vector2(rng.randf_range(14.0, 26.0), rng.randf_range(8.0, 14.0)),
			})

	func _process(delta: float) -> void:
		life += delta
		for b: Dictionary in bits:
			b["v"] = (b["v"] as Vector2) * pow(0.35, delta) + Vector2(0.0, 1500.0 * delta)
			b["p"] = (b["p"] as Vector2) + (b["v"] as Vector2) * delta
			b["r"] = float(b["r"]) + float(b["w"]) * delta
		queue_redraw()
		if life > duration:
			queue_free()

	func _draw() -> void:
		var fade := clampf((duration - life) / 0.6, 0.0, 1.0)
		for b: Dictionary in bits:
			var col: Color = b["c"]
			col.a = fade
			var sz: Vector2 = b["s"]
			# Papelito que gira: se estrecha según el giro, como si diera vueltas.
			var squash := absf(cos(float(b["r"]) * 1.7))
			draw_set_transform(b["p"], float(b["r"]), Vector2(1.0, maxf(squash, 0.15)))
			draw_rect(Rect2(-sz * 0.5, sz), col)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


class GestureHint extends Control:
	var paper := Color.WHITE
	var ink := Color.BLACK
	var quiet := Color.GRAY
	var accent := Color.ORANGE
	var board_light := Color.WHITE
	var board_dark := Color.GRAY
	var shadow := Color(0, 0, 0, 0.2)
	var font: Font
	var font_size := 34
	var text := ""
	## Con true se dibuja la animación de los dedos; con false, solo el texto (un aviso).
	var animated := true
	var _t := 0.0

	const ANIM_W := 150.0
	const PAD := 26.0

	func fit() -> void:
		var w := PAD * 2.0
		if animated:
			w += ANIM_W + 8.0
		if font != null and text != "":
			w += font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
		custom_minimum_size = Vector2(w, 124.0)
		size = custom_minimum_size

	func _process(delta: float) -> void:
		if visible and animated:
			_t = fmod(_t + delta, 4.4)
			queue_redraw()

	func _draw() -> void:
		var pill := StyleBoxFlat.new()
		pill.bg_color = paper
		pill.set_corner_radius_all(int(size.y * 0.5))
		pill.shadow_color = shadow
		pill.shadow_size = 18
		pill.shadow_offset = Vector2(0.0, 6.0)
		draw_style_box(pill, Rect2(Vector2.ZERO, size))
		var x := PAD
		if animated:
			_draw_gesture(Vector2(x + ANIM_W * 0.5, size.y * 0.5))
			x += ANIM_W + 8.0
		if font != null and text != "":
			var ascent := font.get_ascent(font_size)
			var descent := font.get_descent(font_size)
			draw_string(font, Vector2(x, (size.y + ascent - descent) * 0.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, ink)

	func _draw_gesture(c: Vector2) -> void:
		# Dos tiempos: ampliar (0–1,9 s) y girar (2,2–4,1 s), con una pausa entre ellos.
		var grow := 0.0
		var turn := 0.0
		if _t < 1.9:
			grow = sin(PI * _t / 1.9)
		elif _t >= 2.2 and _t < 4.1:
			turn = sin(PI * (_t - 2.2) / 1.9)
		grow = grow * grow
		turn = turn * turn
		var k := 1.0 + 0.36 * grow
		var angle := deg_to_rad(36.0) * turn
		# El tablerito: cuatro casillas, que crecen y giran con los dedos.
		draw_set_transform(c, angle, Vector2(k, k))
		var half := 25.0
		var frame := StyleBoxFlat.new()
		frame.bg_color = board_dark
		frame.set_corner_radius_all(7)
		draw_style_box(frame, Rect2(Vector2(-half - 3.0, -half - 3.0), Vector2(half * 2.0 + 6.0, half * 2.0 + 6.0)))
		draw_rect(Rect2(Vector2(-half, -half), Vector2(half, half)), board_light)
		draw_rect(Rect2(Vector2(0.0, 0.0), Vector2(half, half)), board_light)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# Los dos dedos, en diagonal: se separan al ampliar y giran alrededor del centro al girar.
		var reach := 34.0 + 22.0 * grow
		var base := deg_to_rad(-40.0) + angle
		for side: float in [-1.0, 1.0]:
			var p := c + Vector2(cos(base), sin(base)) * reach * side
			draw_circle(p, 15.0, Color(accent.r, accent.g, accent.b, 0.28), true, -1.0, true)
			draw_circle(p, 9.5, accent, true, -1.0, true)


## Muestra de un acabado: una pieza clara y otra oscura, como dos discos que se solapan.
class SwatchMark extends Control:
	var light := Color.WHITE
	var dark := Color.BLACK
	var rim := Color(0, 0, 0, 0.18)

	func _draw() -> void:
		var r := minf(size.y * 0.5 - 3.0, size.x * 0.3)
		var c := size * 0.5
		for def: Array in [[c + Vector2(r * 0.55, 0.0), dark], [c - Vector2(r * 0.55, 0.0), light]]:
			draw_circle(def[0], r + 3.0, rim, true, -1.0, true)
			draw_circle(def[0], r, def[1], true, -1.0, true)


## Marca del turno: un peón pequeño con el color del bando que juega.
class TurnMark extends Control:
	var fill := Color.WHITE
	var line := Color.BLACK
	var k := 1.0

	func _draw() -> void:
		draw_set_transform(Vector2((size.x - 40.0 * k) * 0.5, (size.y - 44.0 * k) * 0.5), 0.0, Vector2(k, k))
		var o := Vector2.ZERO
		# Primero la silueta engordada, en el color de la línea; encima, el relleno.
		for pass_index in 2:
			var grow := 3.0 if pass_index == 0 else 0.0
			var color := line if pass_index == 0 else fill
			var base := StyleBoxFlat.new()
			base.bg_color = color
			base.set_corner_radius_all(int(4.0 + grow))
			draw_style_box(base, Rect2(o + Vector2(6.0 - grow, 33.0 - grow), Vector2(28.0 + grow * 2.0, 8.0 + grow * 2.0)))
			draw_colored_polygon(PackedVector2Array([
				o + Vector2(14.0 - grow, 18.0 - grow), o + Vector2(26.0 + grow, 18.0 - grow),
				o + Vector2(30.0 + grow, 35.0), o + Vector2(10.0 - grow, 35.0)]), color)
			draw_circle(o + Vector2(20.0, 12.0), 9.0 + grow, color, true, -1.0, true)


## Piezas comidas, en fila y agrupadas por tipo, con la ventaja de material al final («+3»).
class CaptureStrip extends Control:
	const GLYPHS := ["", "piece_pawn", "piece_knight", "piece_bishop", "piece_rook", "piece_queen", "piece_king"]
	var pieces: Array = []
	var fill := Color.WHITE
	var line := Color.BLACK
	var lead := 0
	var ink := Color.BLACK
	var font: Font
	var font_size := 40
	var pad_x := 56.0
	## Desplazamiento vertical al dibujar: la fila de arriba baja un poco hacia el tablero (el encuadre deja aire
	## sobre las piezas del fondo) y la de abajo sube; así quedan pegadas a su bando.
	var dy := 0.0

	func _draw() -> void:
		var s := size.y
		var y := dy
		var x := pad_x
		var prev := -1
		for t: int in pieces:
			if prev != -1:
				x += s * (0.42 if t == prev else 0.8)
			prev = t
			var tex := UiIcons.texture(str(GLYPHS[t]))
			if tex == null:
				continue
			var r := Rect2(Vector2(x, y), Vector2(s, s))
			# Un contorno (la silueta desplazada alrededor) y encima el relleno: se lee sobre cualquier fondo y
			# separa las piezas que se solapan.
			for o: Vector2 in [Vector2(-2.5, 0.0), Vector2(2.5, 0.0), Vector2(0.0, -2.5), Vector2(0.0, 2.5), Vector2(-1.8, -1.8), Vector2(1.8, -1.8), Vector2(-1.8, 1.8), Vector2(1.8, 1.8)]:
				draw_texture_rect(tex, Rect2(r.position + o, r.size), false, line)
			draw_texture_rect(tex, r, false, fill)
		if lead > 0 and font != null:
			if prev != -1:
				x += s + 12.0
			draw_string(font, Vector2(x, dy + size.y * 0.5 + font_size * 0.36), "+%d" % lead, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)


## Interruptor de dos posiciones.
class Switch extends Button:
	var on := false
	var on_color := Color.ORANGE
	var off_color := Color.GRAY
	var knob_color := Color.WHITE

	func _draw() -> void:
		var track := StyleBoxFlat.new()
		track.bg_color = on_color if on else off_color
		track.set_corner_radius_all(int(size.y * 0.5))
		draw_style_box(track, Rect2(Vector2.ZERO, size))
		var d := size.y - 14.0
		var knob := StyleBoxFlat.new()
		knob.bg_color = knob_color
		knob.set_corner_radius_all(int(d * 0.5))
		var x := (size.x - d - 7.0) if on else 7.0
		draw_style_box(knob, Rect2(Vector2(x, 7.0), Vector2(d, d)))


func _ready() -> void:
	font_regular = _load_font("Inter-Regular.woff2")
	font_medium = _load_font("Inter-Medium.woff2")
	font_semibold = _load_font("Inter-SemiBold.woff2")
	font_display = _load_font("InterDisplay-Bold.woff2")
	if font_display != null:
		_digits_font = FontVariation.new()
		_digits_font.base_font = font_display
		_digits_font.opentype_features = {"tnum": 1}
	Loc.add_fallbacks([font_regular, font_medium, font_semibold, font_display])
	_load_puzzles()
	_load_course()
	_load_version()
	online = Online.new()
	add_child(online)
	online.started.connect(_online_started)
	online.move_received.connect(_online_move)
	online.ended.connect(_online_ended)
	online.failed.connect(_online_failed)
	online.rival_profile.connect(_online_rival_profile)
	online.gesture.connect(_online_gesture)
	online.clock_changed.connect(_online_clock_changed)
	online.matched.connect(_online_matched)
	online.retry.connect(_online_retry)
	Premium.load_state()
	coach = CoachAI.new()
	add_child(coach)
	coach.answered.connect(_on_coach_answered)
	coach.judged.connect(_on_coach_judged)
	coach.lesson_ready.connect(_on_coach_lesson)
	coach.asked.connect(_on_tutor_answer)
	coach.assisted.connect(_on_assistant_reply)
	coach.quota.connect(_on_quota)
	pagos = Pagos.new()
	add_child(pagos)
	pagos.setup(coach)
	pagos.changed.connect(_on_pagos_changed)
	pagos.note.connect(_on_pagos_note)
	tutor_voice = TutorVoice.new()
	add_child(tutor_voice)
	tutor_voice.server_url = CoachAI.voice_url(coach.cfg)
	tutor_voice.transcribing.connect(_on_voice_transcribing)
	local_engine = LocalEngine.new()
	add_child(local_engine)
	tutor_voice.heard_partial.connect(_on_voice_partial)
	tutor_voice.heard.connect(_on_voice_heard)
	tutor_voice.failed.connect(_on_voice_failed)
	tutor_speech = TutorSpeech.new()
	add_child(tutor_speech)
	tutor_speech.speaking_changed.connect(_on_speech_changed)
	voice_player = AudioStreamPlayer.new()
	add_child(voice_player)
	voice_player.finished.connect(_voice_next)
	sfx_player = AudioStreamPlayer.new()
	sfx_player.volume_db = -4.0
	add_child(sfx_player)
	music_player = AudioStreamPlayer.new()
	music_player.volume_db = MUSIC_DB
	add_child(music_player)
	if use_settings:
		_load_settings()
		_load_course_progress()
		# Compras y estado de la cuenta (Premium, cupo): al abrir la app, sin esperar a nada.
		pagos.start()
		if CoachAI.tutor_url(coach.cfg) != "":
			coach.premium_call("/premium/estado", {})
	Loc.apply(language)

	bg = SkyBackdrop.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	kids_wall = _kids_wall()
	add_child(kids_wall)
	# El tablero 3D pinta su propio fondo con el color de esta pantalla (ver BoardView3D.set_board_theme).
	view = BoardView3D.new()
	view.move_played.connect(_on_move_played)
	view.tapped.connect(_on_view_tapped)
	view.view_gesture.connect(_on_view_gesture)
	add_child(view)
	view.armor_text = Loc.t("Blindar")
	view.armor_font = font_semibold
	view.set_piece_set(_shown_set())
	view.set_sound_enabled(sound_on)
	view.set_view_locked(_saved_lock)
	view.board.anim_mode = _saved_anim as Board3D.Anim
	if top_view and use_settings:
		view.board.set_view(90.0, 0.0)
	_apply_simple_view()

	_rng.randomize()
	_build_chrome()
	resized.connect(_layout)
	if not use_settings:
		# Sin jugador (las pruebas): los problemas en orden.
		_start(0)
		return
	_load_player()
	_aviso_setup()
	# Los anuncios (y el aviso de consentimiento de Google) no arrancan aquí: esperan a que se vea el inicio
	# (Pablo, 23 nov: la primera vez salía encima de la animación de entrada). Ver _ads_start_later.
	_idle()
	if not welcome_seen:
		_open_welcome()
		# La primera vez que se abre la app, lo primero es elegir el idioma (ya viene marcado el del móvil).
		if not lang_asked:
			_open_language_dialog()
	else:
		# Cada vez que se abre la app: la pantalla de inicio, con todo lo que se puede hacer.
		_open_home()
	_play_intro()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		_aviso_refresh()
	# El botón «atrás» de Android cierra lo que haya abierto encima de la pantalla.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if confirm_node != null and is_instance_valid(confirm_node):
			_close_confirm()
		elif welcome != null and is_instance_valid(welcome):
			_close_welcome()
		elif progress != null and is_instance_valid(progress):
			_leave_progress()
		elif sheet_kind != "":
			_close_options()
		elif whatif:
			_toggle_whatif()
		elif mode == "learn":
			_learn_back()
		elif mode == "game":
			_ask_leave()
		elif use_settings:
			_open_home()


func _load_font(file: String) -> Font:
	var path := "res://fonts/" + file
	if ResourceLoader.exists(path):
		return load(path) as Font
	return null


func _load_puzzles() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/demo_puzzles.json"))
	if typeof(data) == TYPE_DICTIONARY:
		puzzles = data.get("puzzles", [])
	pool = []
	_index_of = {}
	for i in puzzles.size():
		var item := Assessment.item_of(puzzles[i])
		pool.append(item)
		_index_of[item["id"]] = i
	_numbers = {}
	for lv: int in _level_lists():
		var list: Array = _level_lists()[lv]
		for k in list.size():
			_numbers[str((list[k] as Dictionary)["id"])] = [lv, k + 1]


## Problemas de cada nivel, ordenados del más fácil al más difícil (el orden fija su número): nivel → [items].
var _levels_cache := {}


func _level_lists() -> Dictionary:
	if not _levels_cache.is_empty() or pool.is_empty():
		return _levels_cache
	for item: Dictionary in pool:
		var lv := Assessment.level_of(float(item["rating"]))
		if not _levels_cache.has(lv):
			_levels_cache[lv] = []
		(_levels_cache[lv] as Array).append(item)
	for lv: int in _levels_cache:
		(_levels_cache[lv] as Array).sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if float(a["rating"]) != float(b["rating"]):
				return float(a["rating"]) < float(b["rating"])
			return str(a["id"]) < str(b["id"]))
	return _levels_cache


## 2 resuelto (alguna vez, sin ayuda), 1 intentado, 0 sin ver.
func _puzzle_state(id: String) -> int:
	if not _has_player():
		return 0
	var state := 0
	for t: Dictionary in player["tries"]:
		if str(t["id"]) == id:
			if bool(t.get("correct", false)):
				return 2
			state = 1
	return state


## «Nivel 4 · n.º 12»: el nombre de un problema (su nivel y su número dentro del nivel).
func _puzzle_name(id: String) -> String:
	var n: Array = _numbers.get(id, [])
	if n.is_empty():
		return ""
	return Loc.f("Nivel %d · n.º %d", [int(n[0]), int(n[1])])


## Versión de la app, para enseñarla en Opciones: la escribe la CI en data/version.json al generar el APK.
func _load_version() -> void:
	app_version = "versión de desarrollo"
	if not FileAccess.file_exists("res://data/version.json"):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/version.json"))
	if typeof(data) == TYPE_DICTIONARY and str(data.get("version", "")) != "":
		app_version = Loc.f("versión %s", str(data["version"]))
		if str(data.get("commit", "")) != "":
			app_version += " · %s" % str(data["commit"])


# ---------------------------------------------------------------- ajustes guardados

func _load_settings() -> void:
	# Por defecto (decisión de Pablo, 14 nov): fichas y tablero visto desde arriba, en toda la app.
	piece_set = "fichas"
	top_view = true
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		language = Loc.device_language()
		return
	# Quien ya tenía ajustes de antes de los idiomas sigue en español; quien no, empieza en el idioma del móvil.
	language = str(cfg.get_value("app", "idioma", "es"))
	if not language in Loc.LANGUAGES:
		language = "es"
	# Quien ya tenía ajustes guardados de antes pasa una vez a lo nuevo por defecto; después manda lo que elija.
	var fresh_defaults := not cfg.has_section_key("app", "vista_por_defecto_2")
	var style := str(cfg.get_value("tablero", "acabado", board_style))
	if STYLES.has(style):
		board_style = style
	# El contorno va puesto por defecto: quien tenía ajustes de antes pasa una vez a tenerlo; después manda lo que elija.
	if cfg.has_section_key("app", "contorno_por_defecto"):
		board_outline = bool(cfg.get_value("tablero", "contorno", true))
	var pieces := str(cfg.get_value("tablero", "piezas", piece_set))
	if SETS.has(pieces) and not fresh_defaults:
		piece_set = pieces
	if not fresh_defaults:
		top_view = bool(cfg.get_value("vista", "en_picado", true))
	dark = bool(cfg.get_value("pantalla", "oscuro", dark))
	sound_on = bool(cfg.get_value("sonido", "activo", sound_on))
	welcome_seen = bool(cfg.get_value("app", "bienvenida_vista", false))
	lang_asked = bool(cfg.get_value("app", "idioma_preguntado", false))
	kids = bool(cfg.get_value("app", "kids", false)) and KIDS_ENABLED
	home_style = str(cfg.get_value("app", "inicio", home_style))
	var fab: Variant = cfg.get_value("app", "asistente_sitio", Vector2(-1.0, -1.0))
	if fab is Vector2:
		assistant_spot = fab
	intro_mode = str(cfg.get_value("app", "intro", intro_mode))
	if not intro_mode in INTRO_MODES:
		intro_mode = INTRO_MODES[0]
	intro_seen = bool(cfg.get_value("app", "intro_vista", false))
	wait_clip = int(cfg.get_value("app", "espera", 0))
	var subs: Variant = cfg.get_value("partida", "subniveles", {})
	game_sublevels = subs if subs is Dictionary else {}
	if not home_style in HomeScreens.STYLES:
		home_style = HomeScreens.STYLES[0]
	avatar = str(cfg.get_value("app", "icono", ""))
	online_photo = bool(cfg.get_value("online", "foto", false))
	online_name = str(cfg.get_value("online", "nombre", ""))
	online_space = str(cfg.get_value("online", "ritmo", "0+0"))
	if not Online.rhythm_ok(online_space):
		online_space = "0+0"
	online_war = bool(cfg.get_value("online", "war", false))
	var oc: Variant = cfg.get_value("online", "personalizado", [7, 2])
	if oc is Array and (oc as Array).size() == 2:
		online_custom = [int(oc[0]), int(oc[1])]
	online_rules_ok = int(cfg.get_value("online", "normas", 0))
	var ob: Variant = cfg.get_value("online", "bloqueados", {})
	if ob is Dictionary:
		online_blocked = ob
	var world := str(cfg.get_value("app", "mundo", ""))
	if WORLDS.has(world):
		kids_world = world
	press_clock = bool(cfg.get_value("partida", "pulsar_reloj", true))
	press_reminder = bool(cfg.get_value("partida", "aviso_reloj", true))
	voice_on = bool(cfg.get_value("sonido", "voz", true))
	tutor_speech_on = bool(cfg.get_value("sonido", "voz_tutor", true))
	if tutor_speech != null:
		tutor_speech.enabled = tutor_speech_on
	music_on = bool(cfg.get_value("sonido", "musica", true))
	gesture_hint = bool(cfg.get_value("vista", "pista_de_gestos", gesture_hint))
	_saved_lock = bool(cfg.get_value("vista", "giro_fijado", false))
	_anim_chosen = bool(cfg.get_value("tablero", "animaciones_elegidas", false))
	if _anim_chosen:
		_saved_anim = clampi(int(cfg.get_value("tablero", "animaciones", _saved_anim)), 0, 3)


func _save_settings() -> void:
	if not use_settings:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("tablero", "acabado", board_style)
	cfg.set_value("tablero", "contorno", board_outline)
	cfg.set_value("tablero", "piezas", piece_set)
	cfg.set_value("vista", "en_picado", top_view)
	cfg.set_value("app", "vista_por_defecto_2", true)
	cfg.set_value("app", "contorno_por_defecto", true)
	cfg.set_value("tablero", "animaciones", int(view.board.anim_mode) if view != null else _saved_anim)
	cfg.set_value("tablero", "animaciones_elegidas", _anim_chosen)
	cfg.set_value("pantalla", "oscuro", dark)
	cfg.set_value("app", "asistente_sitio", assistant_spot)
	cfg.set_value("online", "foto", online_photo)
	cfg.set_value("online", "nombre", online_name)
	cfg.set_value("online", "ritmo", online_space)
	cfg.set_value("online", "war", online_war)
	cfg.set_value("online", "personalizado", online_custom)
	cfg.set_value("online", "normas", online_rules_ok)
	cfg.set_value("online", "bloqueados", online_blocked)
	cfg.set_value("sonido", "activo", sound_on)
	cfg.set_value("app", "bienvenida_vista", welcome_seen)
	cfg.set_value("app", "idioma_preguntado", lang_asked)
	cfg.set_value("app", "kids", kids)
	cfg.set_value("app", "inicio", home_style)
	cfg.set_value("app", "intro", intro_mode)
	cfg.set_value("app", "intro_vista", intro_seen)
	cfg.set_value("app", "espera", wait_clip)
	cfg.set_value("app", "idioma", language)
	cfg.set_value("app", "mundo", kids_world)
	cfg.set_value("app", "icono", avatar)
	cfg.set_value("partida", "pulsar_reloj", press_clock)
	cfg.set_value("partida", "subniveles", game_sublevels)
	cfg.set_value("partida", "aviso_reloj", press_reminder)
	cfg.set_value("sonido", "voz", voice_on)
	cfg.set_value("sonido", "voz_tutor", tutor_speech_on)
	cfg.set_value("sonido", "musica", music_on)
	cfg.set_value("vista", "pista_de_gestos", gesture_hint)
	cfg.set_value("vista", "giro_fijado", _saved_lock)
	cfg.save(SETTINGS_PATH)


# ---------------------------------------------------------------- el jugador

func _has_player() -> bool:
	return player.has("rating")


func _load_player() -> void:
	if not FileAccess.file_exists(PLAYER_PATH):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PLAYER_PATH))
	if typeof(data) != TYPE_DICTIONARY or typeof(data.get("rating")) != TYPE_DICTIONARY or typeof(data.get("tries")) != TYPE_ARRAY:
		return
	var rating: Dictionary = data["rating"]
	if not (rating.has("r") and rating.has("rd") and rating.has("vol")):
		return
	player = {"rating": rating, "tries": data["tries"], "done": bool(data.get("done", false))}
	experience = str(data.get("experience", ""))
	test_skipped = bool(data.get("skipped", false))
	reviewed = {}
	for id: Variant in data.get("reviewed", []):
		reviewed[str(id)] = true


func _save_player() -> void:
	if not use_settings or not _has_player():
		return
	var file := FileAccess.open(PLAYER_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"version": 1, "experience": experience, "skipped": test_skipped, "rating": player["rating"], "tries": player["tries"], "done": bool(player.get("done", false)), "reviewed": reviewed.keys()}))
	file.close()


## Problemas del test ya contestados.
func _test_count() -> int:
	var n := 0
	for t: Dictionary in player.get("tries", []):
		if str(t.get("phase", "")) == "test":
			n += 1
	return n


# ---------------------------------------------------------------- piezas de la interfaz

func _c(key: String) -> Color:
	var palette: Dictionary = DARK if dark else LIGHT
	return palette[key]


## Tono pastel por su nombre: [fondo, tinta].
func _tint(tint_name: String) -> Array:
	var tints: Dictionary = TINTS_DARK if dark else TINTS_LIGHT
	return tints.get(tint_name, tints["peach"])


## Cursor de escritura bien visible (el del tema por defecto es casi blanco y no se veía sobre las cajas claras;
## lo vio Pablo, 22 nov): del color de acento, más grueso y parpadeando.
func _show_caret(edit: LineEdit) -> void:
	edit.add_theme_color_override("caret_color", _tint("peach")[1])
	edit.add_theme_constant_override("caret_width", 5)
	edit.caret_blink = true
	edit.caret_blink_interval = 0.55


## Línea que mide lo que su texto (no se recorta): para filas cortas dentro de un contenedor horizontal.
func _line(text: String, font_size: int, color: Color, font: Font) -> Label:
	var l := _text(text, font_size, color, font)
	l.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	return l


func _text(text: String, font_size: int, color: Color, font: Font) -> Label:
	var l := Label.new()
	l.text = Loc.t(text)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if font != null:
		l.add_theme_font_override("font", font)
	# Una sola línea, siempre: si el texto cambia, nada se mueve de sitio.
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return l


func _pad(left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", left)
	m.add_theme_constant_override("margin_top", top)
	m.add_theme_constant_override("margin_right", right)
	m.add_theme_constant_override("margin_bottom", bottom)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return m


func _spacer(height: float, grow: bool = false) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0.0, height)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if grow:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


func _style_button(b: Button, fill: Color, fg: Color, radius: int, font_size: int, font: Font, glow: Color = Color(0, 0, 0, 0), border: Color = Color(0, 0, 0, 0), candy: bool = false) -> void:
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = fill.darkened(0.08) if state == "pressed" else fill
		sb.set_corner_radius_all(radius)
		sb.content_margin_left = 26.0
		sb.content_margin_right = 26.0
		sb.content_margin_top = 16.0
		sb.content_margin_bottom = 16.0
		if border.a > 0.0:
			sb.border_color = border
			sb.set_border_width_all(5)
		if candy:
			# Canto inferior más oscuro y un borde blanco: aspecto de botón de juguete. Al pulsarlo, el canto se
			# encoge, como si se hundiera.
			sb.border_color = fill.darkened(0.22)
			sb.border_width_bottom = 4 if state == "pressed" else 12
			sb.border_width_left = 0
			sb.border_width_right = 0
			sb.border_width_top = 0
			sb.expand_margin_top = 0.0
			sb.content_margin_top = 16.0 + (8.0 if state == "pressed" else 0.0)
		if glow.a > 0.0 and state != "pressed":
			sb.shadow_color = glow
			sb.shadow_size = 18
			sb.shadow_offset = Vector2(0.0, 8.0)
		b.add_theme_stylebox_override(state, sb)
	for c: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color", "font_disabled_color"]:
		b.add_theme_color_override(c, fg)
	b.add_theme_font_size_override("font_size", font_size)
	if font != null:
		b.add_theme_font_override("font", font)


## Icono de la interfaz (ver UiIcons), con el color que se le pida.
## Fondo de juguetes en mosaico (solo se ve en el nivel Kids).
func _kids_wall() -> TextureRect:
	var w := TextureRect.new()
	w.texture = UiIcons.kids_wall()
	w.stretch_mode = TextureRect.STRETCH_TILE
	w.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	w.set_anchors_preset(Control.PRESET_FULL_RECT)
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	w.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	w.visible = kids
	return w


## Iconos que solo existen a color (Fluent Emoji): el polluelo de «Aprende desde cero».
const COLOR_ICONS := ["chick"]


func _icon(icon_name: String, side: float, color: Color) -> TextureRect:
	var t := TextureRect.new()
	# Nivel Kids: el icono a color, si lo hay (y sin teñir). Algunos iconos van siempre a color.
	var kid_tex := UiIcons.kids_texture(icon_name) if kids or COLOR_ICONS.has(icon_name) else null
	if kid_tex != null:
		t.texture = kid_tex
		color = Color(1.0, 1.0, 1.0, color.a)
	else:
		t.texture = UiIcons.texture(icon_name)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(side, side)
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	t.modulate = color
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return t


## Tesela pastel con un icono grande dentro.
func _icon_tile(icon_name: String, tint_name: String, side: float, icon_side: float) -> PanelContainer:
	var colors := _tint(tint_name)
	var tile := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = colors[0]
	sb.set_corner_radius_all(int(side * 0.3))
	tile.add_theme_stylebox_override("panel", sb)
	tile.custom_minimum_size = Vector2(side, side)
	tile.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	tile.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(_icon(icon_name, icon_side, colors[1]))
	return tile


## Botón ilustrado: icono y texto, en fila o (vertical = true) con el icono encima. Deja pasar el arrastre:
## si el dedo empieza encima, la lista de debajo se desplaza igual. Opciones: font_size, icon (lado del
## icono), vertical, trailing (icono detrás del texto), radius, height, glow, border, font, icon_color, wrap.
func _button(icon_name: String, text: String, on_press: Callable, fill: Color, fg: Color, opt: Dictionary = {}) -> Button:
	var vertical := bool(opt.get("vertical", false))
	var font_size := int(opt.get("font_size", F_BODY))
	var height := float(opt.get("height", 112.0))
	# Nivel Kids: botones de caramelo, más grandes, con letra redonda y un canto más oscuro debajo (como si se
	# pudieran apretar). Los enlaces sin fondo y los botones redondos de la barra solo crecen un poco.
	var candy := kids and fill.a > 0.5 and text != ""
	if kids:
		var grow := 1.22 if candy else 1.08
		height *= grow
		font_size += 6 if candy else 2
		opt = opt.duplicate()
		opt["icon"] = float(opt.get("icon", 52.0)) * (1.45 if candy else 1.2)
		if candy:
			opt["font"] = font_display
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.pressed.connect(on_press)
	var radius := int(opt.get("radius", 40 if vertical else int(height * 0.5)))
	if candy:
		radius = int(minf(height * 0.5, 64.0)) if vertical else int(height * 0.5)
	_style_button(b, fill, fg, radius, font_size, font_semibold, opt.get("glow", Color(0, 0, 0, 0)), opt.get("border", Color(0, 0, 0, 0)), candy)
	var box: BoxContainer = VBoxContainer.new() if vertical else HBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 4 if vertical else 16)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.add_child(box)
	var label: Label = null
	if text != "":
		label = Label.new()
		label.text = Loc.t(text)
		label.add_theme_font_size_override("font_size", font_size)
		label.add_theme_color_override("font_color", fg)
		var font: Font = opt.get("font", font_semibold)
		if font != null:
			label.add_theme_font_override("font", font)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if bool(opt.get("wrap", false)):
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.add_theme_constant_override("line_spacing", -2)
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var picture: TextureRect = null
	if icon_name != "":
		picture = _icon(icon_name, float(opt.get("icon", 52.0)), opt.get("icon_color", fg))
	if bool(opt.get("trailing", false)):
		if label != null:
			box.add_child(label)
		if picture != null:
			box.add_child(picture)
	else:
		if picture != null:
			box.add_child(picture)
		if label != null:
			box.add_child(label)
	b.set_meta("label", text)
	b.set_meta("label_node", label)
	# Un botón no mide a sus hijos: su tamaño mínimo se le da a mano, el del contenido más el relleno.
	var pad_x := float(opt.get("pad_x", 22.0 if vertical else 40.0))
	# squeeze: el texto no ensancha el botón (cuenta solo el icono) y, si no cabe, la letra encoge. Así una barra de
	# muchos botones nunca es más ancha que la pantalla, aunque el idioma tenga palabras largas o sea el modo Kids.
	var squeeze := bool(opt.get("squeeze", false)) and label != null
	var fit := func() -> void:
		if is_instance_valid(b) and is_instance_valid(box):
			var need := box.get_combined_minimum_size()
			var w := need.x
			if squeeze and is_instance_valid(label):
				w = picture.custom_minimum_size.x if picture != null else 0.0
			b.custom_minimum_size = Vector2(w + pad_x * 2.0, maxf(height, need.y + 24.0))
	box.minimum_size_changed.connect(fit)
	fit.call()
	if squeeze:
		label.clip_text = true
		label.custom_minimum_size.x = 1.0
		var shrink := func() -> void:
			if not is_instance_valid(b) or not is_instance_valid(label) or b.size.x < 2.0:
				return
			var f: Font = label.get_theme_font("font")
			var room := b.size.x - 12.0
			var fs := font_size
			while fs > 16 and f.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room:
				fs -= 1
			if label.get_theme_font_size("font_size") != fs:
				label.add_theme_font_size_override("font_size", fs)
		b.resized.connect(shrink)
	return b


## Texto de un botón ilustrado (lo usan las pruebas).
func button_label(b: Button) -> String:
	if b == null or not is_instance_valid(b):
		return ""
	return str(b.get_meta("label", b.text))


## Botón de texto (con icono opcional) dentro de la tarjeta.
func _card_button(text: String, on_press: Callable, fill: Color, fg: Color, font_size: int = F_SUB, icon_name: String = "") -> Button:
	return _button(icon_name, text, on_press, fill, fg, {"font_size": font_size, "height": 100.0, "icon": 48.0})


## Botón redondo con un icono.
func _round_button(icon_name: String, on_press: Callable, side: float = 112.0, fill: Variant = null, fg: Variant = null, with_shadow: bool = true) -> Button:
	var paper: Color = _c("surface") if fill == null else fill
	var tone: Color = _c("ink") if fg == null else fg
	var b := _button(icon_name, "", on_press, paper, tone, {"height": side, "icon": side * 0.54, "pad_x": side * 0.23, "radius": int(side * 0.5), "glow": _c("shadow") if with_shadow else Color(0, 0, 0, 0)})
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	return b


## Etiqueta en forma de píldora.
func _chip(text: String, fill: Color, fg: Color, icon_name: String = "") -> PanelContainer:
	var chip := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(36)
	sb.content_margin_left = 26.0
	sb.content_margin_right = 26.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	chip.add_theme_stylebox_override("panel", sb)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l := Label.new()
	l.text = Loc.t(text)
	l.add_theme_font_size_override("font_size", F_CAP + 2)
	l.add_theme_color_override("font_color", fg)
	if font_medium != null:
		l.add_theme_font_override("font", font_medium)
	if icon_name != "" and UiIcons.has(icon_name):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(_icon(icon_name, float(F_CAP) + 10.0, fg))
		row.add_child(l)
		chip.add_child(row)
	else:
		chip.add_child(l)
	return chip


## Párrafo: texto que salta de línea para caber en el ancho que tenga.
func _para(text: String, font_size: int, color: Color, font: Font) -> Label:
	var l := Label.new()
	l.text = Loc.t(text)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("line_spacing", 8)
	if font != null:
		l.add_theme_font_override("font", font)
	return l


func _insets() -> Vector2:
	# Margen seguro arriba y abajo (muesca de la cámara, barra de gestos), en unidades del lienzo.
	var win := DisplayServer.window_get_size()
	var safe := DisplayServer.get_display_safe_area()
	var canvas := get_viewport_rect().size
	if win.y <= 0 or safe.size.y <= 0 or canvas.y <= 0.0:
		return Vector2.ZERO
	var k := canvas.y / float(win.y)
	var top := clampf(float(safe.position.y) * k, 0.0, 170.0)
	var bottom := clampf(float(win.y - safe.end.y) * k, 0.0, 130.0)
	return Vector2(top, bottom)


# ---------------------------------------------------------------- pantalla

## Construye todo menos el tablero. Se rehace entero al cambiar de tema: es barato y no deja estilos a medias.
func _build_chrome() -> void:
	# Al rehacerla (p. ej., al cambiar de tema) va al mismo sitio: debajo de las páginas, ventanas y avisos que
	# estuvieran abiertos. Si no, la tarjeta y los botones del problema quedaban por encima del inicio.
	var chrome_at := -1
	var tip_at := -1
	if chrome != null:
		chrome_at = chrome.get_index()
		chrome.visible = false
		chrome.queue_free()
	if gesture_tip != null and is_instance_valid(gesture_tip):
		tip_at = gesture_tip.get_index()
		gesture_tip.queue_free()
	var th := Theme.new()
	if font_regular != null:
		th.default_font = font_regular
	th.default_font_size = F_BODY
	theme = th
	bg.base = _c("bg")
	bg.top = _c("sky")
	bg.ornament = _c("cloud")
	bg.night = dark
	bg.queue_redraw()
	view.set_board_style(board_style, board_outline)
	view.set_board_theme("dark" if dark else "light", _c("bg"))

	var inset := _insets()
	chrome = VBoxContainer.new()
	chrome.set_anchors_preset(Control.PRESET_FULL_RECT)
	chrome.add_theme_constant_override("separation", 0)
	chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(chrome)
	if chrome_at >= 0:
		move_child(chrome, chrome_at)

	# Barra superior: contador y botones redondos (chincheta del giro, vista y opciones).
	# En pantalla completa la zona de la barra de estado sigue teniendo la cámara y los avisos del sistema:
	# se deja siempre un margen arriba, aunque el sistema no informe de ninguno.
	chrome.add_child(_spacer(maxf(inset.x, 60.0) + 18.0))
	var bar_pad := _pad(40, 0, 36, 0)
	chrome.add_child(bar_pad)
	bar_row = bar_pad
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 18)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_pad.add_child(bar)
	# Inicio, siempre a mano (en todas las pantallas con tablero).
	home_button = _round_button("home", _go_home)
	bar.add_child(home_button)
	var lilac := _tint("lilac")
	level_pill = _button("cap", "Nivel", _open_progress.bind("progress"), lilac[0], lilac[1], {"font_size": F_SUB, "height": 100.0, "icon": 54.0, "pad_x": 30.0})
	level_pill.mouse_filter = Control.MOUSE_FILTER_STOP
	level_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	level_pill.visible = false
	# Insignia del nivel, siempre a la vista cuando ya hay nivel (toca para ver «Mi nivel y mi plan»).
	level_slot = Button.new()
	level_slot.flat = true
	level_slot.focus_mode = Control.FOCUS_NONE
	level_slot.custom_minimum_size = Vector2(112.0, 112.0)
	level_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	level_slot.pressed.connect(_open_avatar)
	level_slot.visible = false
	bar.add_child(level_slot)
	counter_check = _icon("check", 46.0, _c("good"))
	counter_check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	counter_check.visible = false
	bar.add_child(counter_check)
	counter = _text("", F_SUB, _c("quiet"), font_medium)
	counter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	counter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(counter)
	# Interruptor «Tutor IA», en todas las partidas (petición de Pablo, 21 nov): encender y apagar sin ir a Opciones.
	tutor_toggle = _tutor_toggle_button()
	bar.add_child(tutor_toggle)
	pin_button = _pin_button()
	bar.add_child(pin_button)
	view_button = _round_button("view", _on_toggle_view)
	bar.add_child(view_button)
	options_button = _round_button("sliders", _open_options)
	bar.add_child(options_button)

	# Hueco del vídeo de los finales (el reproductor de YouTube, nativo, va encima). Solo con un vídeo abierto.
	video_slot = Control.new()
	video_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	video_slot.visible = false
	chrome.add_child(video_slot)

	# Cielo sobre el tablero: mientras se resuelve, el tablero queda más cerca del pulgar; cuando llega la
	# explicación completa, este hueco se cierra y el tablero sube (ver _layout).
	top_gap = _spacer(0.0)
	chrome.add_child(top_gap)

	cap_top = CaptureStrip.new()
	cap_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap_top.dy = 36.0
	chrome.add_child(cap_top)

	# Hueco del tablero: el tablero 3D se coloca encima de este hueco (ver _place_board).
	board_slot = Control.new()
	board_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_slot.item_rect_changed.connect(_place_board)
	chrome.add_child(board_slot)

	cap_bottom = CaptureStrip.new()
	cap_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap_bottom.dy = -18.0
	chrome.add_child(cap_bottom)

	# Tarjeta del entrenador, bajo el tablero. Ocupa lo que necesita su contenido y, si no cabe, se desplaza.
	card_pad = _pad(28, 20, 28, 0)
	card_pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_pad.resized.connect(_fit_card)
	chrome.add_child(card_pad)
	card = PanelContainer.new()
	card_style = StyleBoxFlat.new()
	card_style.bg_color = _c("surface")
	card_style.set_corner_radius_all(52)
	card_style.content_margin_left = 42.0
	card_style.content_margin_right = 28.0
	card_style.content_margin_top = 32.0
	card_style.content_margin_bottom = 32.0
	card_style.shadow_color = _c("shadow")
	card_style.shadow_size = 30
	card_style.shadow_offset = Vector2(0.0, 12.0)
	card.add_theme_stylebox_override("panel", card_style)
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	card_pad.add_child(card)
	card_scroll = ScrollContainer.new()
	card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	card.add_child(card_scroll)
	var body_pad := _pad(0, 0, 14, 0)
	body_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_scroll.add_child(body_pad)
	card_body = VBoxContainer.new()
	card_body.add_theme_constant_override("separation", 16)
	card_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_body.minimum_size_changed.connect(_fit_card)
	body_pad.add_child(card_body)

	chrome.add_child(_spacer(26.0))

	# Acciones, abajo: los botones cambian con la fase del problema (ver _build_actions).
	var actions_pad := _pad(32, 0, 32, 0)
	chrome.add_child(actions_pad)
	actions = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 14)
	actions.custom_minimum_size = Vector2(0.0, BAR_HEIGHT)
	actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actions_pad.add_child(actions)
	_actions_mode = ""
	chrome.add_child(_spacer(inset.y + 34.0))

	# Pista de gestos, sobre el tablero (ver _place_tip).
	gesture_tip = GestureHint.new()
	gesture_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gesture_tip.paper = _c("surface")
	gesture_tip.ink = _c("ink")
	gesture_tip.accent = _c("accent_text")
	gesture_tip.board_light = Color("f3ead8")
	gesture_tip.board_dark = Color("a97f5f")
	gesture_tip.shadow = _c("shadow")
	gesture_tip.font = font_medium
	gesture_tip.font_size = F_SUB
	gesture_tip.text = Loc.t("Amplía y gira con dos dedos")
	gesture_tip.visible = false
	gesture_tip.fit()
	add_child(gesture_tip)
	if tip_at >= 0:
		move_child(gesture_tip, tip_at)

	_refresh(false)
	_place_board.call_deferred()
	# La página abierta, con los colores nuevos (sin cerrar la hoja de opciones desde la que se cambió el tema).
	var keep_sheet := sheet_kind
	var keep_open := options_open
	if progress_kind == "home" and progress != null and is_instance_valid(progress):
		_open_home()
		sheet_kind = keep_sheet
		options_open = keep_open
	if sheet_kind == "options":
		_build_sheet()
	elif sheet_kind == "ai":
		_build_ai_sheet()
	elif sheet_kind == "language":
		_build_language_sheet()


## Chincheta de la barra: fija el giro del tablero (ni los dedos ni el móvil lo giran) o lo vuelve a soltar.
func _pin_button() -> Button:
	var locked := view.view_locked
	var tint := _tint("peach")
	var b := _round_button("pin_on", _on_toggle_pin, 112.0, tint[0], tint[1]) if locked else _round_button("pin", _on_toggle_pin)
	# Con «Simple» el tablero no gira: la chincheta no pinta nada y se esconde.
	b.visible = not view.board.is_simple()
	return b


func _on_toggle_pin() -> void:
	if view.board.is_simple():
		_note("Con «Simple» el tablero no gira")
		return
	_set_lock(not view.view_locked)
	_note("Giro fijado" if view.view_locked else "Giro libre")


## Aviso breve en el hueco de encima del tablero.
func _note(text: String) -> void:
	if gesture_tip == null or not is_instance_valid(gesture_tip):
		return
	_tip_note_id += 1
	var my_note := _tip_note_id
	gesture_tip.animated = false
	gesture_tip.text = Loc.t(text)
	gesture_tip.fit()
	_tip_note = true
	_place_tip()
	await _wait(1.7)
	if my_note != _tip_note_id or not is_instance_valid(gesture_tip):
		return
	_tip_note = false
	gesture_tip.animated = true
	gesture_tip.text = Loc.t("Amplía y gira con dos dedos")
	gesture_tip.fit()
	_place_tip()


## En las partidas del Campeonato, el rival va arriba a la izquierda, entre la barra y el tablero (como en
## chess.com): su cara, su nombre y «Bot». Solo si cabe; si no, el reloj ya lleva su nombre. Dice si se ve.
func _sync_camp_tag() -> bool:
	var key := str(game.get("campeonato", "")) if mode == "game" else ""
	var id := str(game.get("rival_id", ""))
	var room := 0.0
	var floor_y := 0.0
	if key != "" and id != "" and not _tip_note and board_slot != null and is_instance_valid(board_slot) and board_slot.is_inside_tree():
		# Hasta lo más alto del tablero que se ve (con la perspectiva, el tablero no llena su hueco por arriba). Las
		# piezas que ha comido el rival van a su derecha, en la misma franja (ver _sync_cap_pad).
		floor_y = view.get_global_rect().position.y + view.board_top() if view != null and view.is_inside_tree() else board_slot.get_global_rect().position.y
		room = floor_y - _coach_legend_floor()
	# Dos tamaños (grande o compacto), para no rehacerlo a cada fotograma si el tablero se amplía.
	var side := CAMP_TAG_FACE if room >= CAMP_TAG_FACE + 60.0 else (84.0 if room >= 144.0 else 0.0)
	_camp_tag_top = floor_y
	if side <= 0.0:
		if camp_tag != null and is_instance_valid(camp_tag):
			camp_tag.visible = false
		_sync_cap_pad(0.0)
		return false
	var thinking := game_state == "think"
	var tag_key := "%s|%s|%d|%s|%s|%s" % [key, id, int(side), str(thinking), str(dark), Loc.language]
	if tag_key != _camp_tag_key or camp_tag == null or not is_instance_valid(camp_tag):
		_camp_tag_key = tag_key
		if camp_tag != null and is_instance_valid(camp_tag):
			camp_tag.queue_free()
		camp_tag = CampeonatoUI.game_tag(self, key, id, thinking, side)
		add_child(camp_tag)
		if gesture_tip != null and is_instance_valid(gesture_tip):
			# Al nivel de la pista de gestos: por debajo de las páginas y ventanas.
			move_child(camp_tag, gesture_tip.get_index())
	camp_tag.visible = true
	camp_tag.reset_size()
	# Pegado al tablero (encima de las piezas comidas), alineado con su borde izquierdo.
	camp_tag.position = Vector2(24.0, maxf(_coach_legend_floor() + 12.0, floor_y - camp_tag.size.y - 18.0))
	_sync_cap_pad(camp_tag.position.x + camp_tag.size.x + 24.0)
	return true


## Las piezas comidas de arriba empiezan a la derecha del rival del Campeonato (`after`: su borde derecho; 0, sin él).
func _sync_cap_pad(after: float) -> void:
	if cap_top == null or not is_instance_valid(cap_top):
		return
	var pad := maxf(56.0, after)
	if absf(cap_top.pad_x - pad) > 0.5:
		cap_top.pad_x = pad
		cap_top.queue_redraw()


## El jugador ha ampliado, girado o desplazado el tablero: ya sabe hacerlo y la pista sobra.
func _on_view_gesture(_kind: String) -> void:
	if not gesture_hint:
		return
	gesture_hint = false
	_save_settings()
	_place_tip()
	_sync_sheet()


## Coloca la pista de gestos (o el aviso) en el hueco entre la barra y el tablero, si cabe.
func _place_tip() -> void:
	if gesture_tip == null or not is_instance_valid(gesture_tip) or board_slot == null or not is_instance_valid(board_slot):
		return
	var slot_top := board_slot.get_global_rect().position.y
	if cap_top != null and is_instance_valid(cap_top) and cap_top.visible:
		slot_top = cap_top.get_global_rect().position.y
	var bar_bottom := bar_row.get_global_rect().end.y if bar_row != null and is_instance_valid(bar_row) else 0.0
	var room := slot_top - bar_bottom
	var fits := room >= gesture_tip.size.y + 56.0
	var tag_on := _sync_camp_tag()
	gesture_tip.visible = _tip_note or (gesture_hint and not view.view_locked and welcome == null and progress == null and fits and not tag_on)
	if not film.is_empty():
		# Con el vídeo arriba no hay sitio: la pista quedaría debajo del reproductor (que va encima de todo).
		gesture_tip.visible = false
	var y := slot_top - gesture_tip.size.y - 34.0
	if not fits:
		y = bar_bottom + 14.0
	gesture_tip.position = Vector2((size.x - gesture_tip.size.x) * 0.5, y)
	# Las nubes (o la luna) se quedan por encima de la pista.
	bg.ornament_bottom = gesture_tip.position.y - 12.0 if gesture_tip.visible and fits else -1.0
	_sync_coach_legend()
	if coach_legend != null and coach_legend.visible:
		bg.ornament_bottom = coach_legend.position.y - 12.0
	bg.queue_redraw()


## Sitio que pide la tarjeta según lo que enseña: poco mientras se resuelve, más con la explicación de un
## fallo o de la solución, y todo el que haya cuando se profundiza o se prueban otras jugadas.
func _card_room() -> float:
	# En las lecciones y en las partidas el tablero no se mueve: la tarjeta tiene siempre el mismo sitio (si el texto
	# no cabe, se desplaza dentro) y el resultado de cada ejercicio sale en una ventana encima del tablero.
	if mode == "learn":
		return 620.0
	if mode == "game":
		return 560.0
	# En los problemas, igual: el tablero no se mueve. Una explicación larga sale en una ventana semitransparente
	# que sube por encima del tablero (ver _fit_card).
	return CARD_MIN + 230.0


## Reparte el alto: el hueco del tablero es tan alto como hace falta para que el tablero vaya de lado a lado
## (y no más); la tarjeta se queda con lo que sobra, salvo el trozo de cielo que va encima del tablero
## mientras se resuelve.
func _layout(animate: bool = false) -> void:
	if chrome == null or board_slot == null or top_gap == null:
		return
	var canvas := get_viewport_rect().size
	if video_slot != null and is_instance_valid(video_slot):
		# A todo el ancho y en 16:9, con un respiro debajo (YouTube pide al menos 200 × 200 px).
		video_slot.visible = not film.is_empty()
		video_slot.custom_minimum_size = Vector2(0.0, roundf(canvas.x * 9.0 / 16.0) + 18.0) if video_slot.visible else Vector2.ZERO
	var fixed := 0.0
	for child in chrome.get_children():
		if child != board_slot and child != top_gap and child != card_pad and child is Control:
			fixed += (child as Control).get_combined_minimum_size().y
	_fixed_height = fixed
	var board_h := clampf(canvas.y - fixed - CARD_MIN, 320.0, maxf(canvas.x, 320.0))
	if not film.is_empty():
		# Con el vídeo arriba, el tablero cede algo de alto a la tarjeta (la pregunta tiene que verse entera).
		board_h = minf(board_h, maxf(canvas.x * 0.84, 320.0))
	board_slot.custom_minimum_size = Vector2(0.0, board_h)
	_natural_board_h = board_h
	var free := maxf(canvas.y - fixed - board_h, CARD_MIN)
	var gap := minf(maxf(0.0, (free - _card_room()) * 0.86), _gap_limit)
	_gap_limit = gap
	_natural_gap = gap
	if _gap_tween != null and _gap_tween.is_valid():
		_gap_tween.kill()
	if animate and view.board.anim_mode != Board3D.Anim.NONE and absf(top_gap.custom_minimum_size.y - gap) > 2.0:
		_gap_tween = create_tween()
		_gap_tween.tween_property(top_gap, "custom_minimum_size:y", gap, 0.26).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		top_gap.custom_minimum_size = Vector2(0.0, gap)
	_fit_card()


## La tarjeta mide lo que su contenido, hasta el sitio que hay; a partir de ahí, el contenido se desplaza.
func _fit_card() -> void:
	if card_scroll == null or not is_instance_valid(card_scroll) or card_pad == null:
		return
	# Sitio entre el tablero y los botones con el hueco de cielo que hay ahora mismo (puede estar cerrándose),
	# menos el margen de la tarjeta y su relleno.
	var room := get_viewport_rect().size.y - _fixed_height - board_slot.custom_minimum_size.y - top_gap.custom_minimum_size.y - 20.0 - 64.0
	var need := card_body.get_combined_minimum_size().y
	# Con reloj, el reloj se encoge (hasta 170) para que la tarjeta quepa sin desplazarse.
	if chess_clock != null and is_instance_valid(chess_clock) and chess_clock.is_inside_tree():
		var base: float = chess_clock.get_meta("base_h", chess_clock.custom_minimum_size.y)
		chess_clock.set_meta("base_h", base)
		var other := need - chess_clock.custom_minimum_size.y
		var h := clampf(room - other - 24.0, 170.0, base)
		if absf(h - chess_clock.custom_minimum_size.y) > 0.5:
			chess_clock.custom_minimum_size = Vector2(0.0, h)
			need = other + h
	# Si no cabe (una explicación larga en los problemas o en el análisis), la tarjeta no tapa el tablero: primero
	# desaparece el cielo de encima del tablero y después el tablero se encoge (hasta un 60 % del ancho), así se ve
	# entero con sus flechas; lo que siga sin caber se desplaza dentro de la tarjeta. Con poco texto, vuelve a su tamaño.
	var lift := 0.0
	if mode != "learn" and (mode != "game" or game_state == "review" or game_state == "detail"):
		var canvas_w := get_viewport_rect().size.x
		var nat_room := room + board_slot.custom_minimum_size.y + top_gap.custom_minimum_size.y - _natural_board_h - _natural_gap
		var deficit := maxf(need - nat_room, 0.0)
		var gap := _natural_gap
		var bh := _natural_board_h
		if deficit > 0.0:
			var take := minf(gap, deficit)
			gap -= take
			deficit -= take
			bh -= minf(maxf(bh - maxf(canvas_w * 0.6, 320.0), 0.0), deficit)
		var tweening := _gap_tween != null and _gap_tween.is_valid() and _gap_tween.is_running()
		if absf(bh - board_slot.custom_minimum_size.y) > 0.5:
			board_slot.custom_minimum_size = Vector2(0.0, bh)
		if need > nat_room or not tweening:
			if tweening:
				_gap_tween.kill()
			if absf(gap - top_gap.custom_minimum_size.y) > 0.5:
				top_gap.custom_minimum_size = Vector2(0.0, gap)
		room = nat_room + (_natural_board_h - board_slot.custom_minimum_size.y) + (_natural_gap - top_gap.custom_minimum_size.y)
	elif mode == "game" and game_clocked and game_state in ["play", "think", "press"] and view != null and view.is_inside_tree():
		# Con reloj: la tarjeta sube hasta justo debajo del tablero (con la perspectiva, el tablero no llena su
		# hueco) y el reloj gana ese sitio.
		var spare := board_slot.get_global_rect().end.y - (view.get_global_rect().position.y + view.board_bottom()) - 24.0
		if spare > 0.0:
			lift = spare
			room += spare
			if chess_clock != null and is_instance_valid(chess_clock):
				var base2: float = chess_clock.get_meta("base_h", chess_clock.custom_minimum_size.y)
				var other2 := need - chess_clock.custom_minimum_size.y
				var h2 := clampf(room - other2 - 24.0, 170.0, base2)
				if absf(h2 - chess_clock.custom_minimum_size.y) > 0.5:
					chess_clock.custom_minimum_size = Vector2(0.0, h2)
					need = other2 + h2
	if absf(lift - _card_float) > 0.5:
		_card_float = lift
		card_pad.add_theme_constant_override("margin_top", int(20.0 - lift))
		var paper := _c("surface")
		card_style.bg_color = Color(paper.r, paper.g, paper.b, 0.9 if lift > 0.0 and not game_clocked else 1.0)
	var want := clampf(need, 60.0, maxf(room + lift, 60.0))
	if absf(card_scroll.custom_minimum_size.y - want) > 0.5:
		card_scroll.custom_minimum_size = Vector2(0.0, want)


func _place_board() -> void:
	if board_slot == null or not is_instance_valid(board_slot):
		return
	var rect := board_slot.get_global_rect()
	var top := clampf(rect.position.y, 0.0, VIEW_BLEED_TOP)
	var bottom := clampf(size.y - rect.end.y, 0.0, VIEW_BLEED_BOTTOM)
	view.position = Vector2(rect.position.x, rect.position.y - top)
	view.size = Vector2(rect.size.x, rect.size.y + top + bottom)
	view.edge_fade = VIEW_FADE
	# El tablero se encuadra dentro del hueco; lo que sobra por arriba y por abajo es solo fondo y sombra.
	var h := maxf(view.size.y, 1.0)
	view.board.fit_pad = Vector4(0.012, (top + 6.0) / h, 0.012, (bottom + 6.0) / h)
	view.board.apply_camera()
	# El cielo se funde con el fondo justo antes de la vista del tablero; sus adornos van entre la barra y ella.
	bg.band_top = bar_row.get_global_rect().end.y + 16.0 if bar_row != null and is_instance_valid(bar_row) else 0.0
	bg.band_bottom = view.position.y
	bg.queue_redraw()
	_place_tip()


# ---------------------------------------------------------------- tarjeta del entrenador

## Explicación que toca enseñar ahora ({} si ninguna) y a qué nivel.
func _shown_exp() -> Dictionary:
	if whatif:
		return whatif_exp
	if phase == Phase.WRONG or phase == Phase.SOLVED or phase == Phase.SHOWN or phase == Phase.STEP:
		return expl
	return {}


func _shown_level() -> int:
	return whatif_level if whatif else exp_level


func _tone_color(e: Dictionary) -> Color:
	if bool(e.get("correct", false)):
		return _c("good")
	var verdict := str(e.get("verdict", ""))
	return _c("accent_text") if verdict == "alsoWins" or verdict == "slower" else _c("bad")


## Pone los textos y los botones que corresponden a la fase del problema.
func _refresh(animate: bool = true) -> void:
	_war_sync_seen()
	if card_body == null or not is_instance_valid(card_body):
		return
	# La leyenda de las chapas (y la pista de gestos) dependen del modo y de la última valoración.
	_place_tip.call_deferred()
	var total := puzzles.size()
	level_pill.visible = false
	_sync_level_badge()
	if counter_check != null:
		counter_check.visible = (mode == "train" or mode == "free") and not puzzle.is_empty() and _puzzle_state(str(puzzle.get("id", ""))) == 2
	if mode == "learn":
		counter.text = Loc.t("Finales de campeones") if Cine.is_lesson(str(lesson.get("id", ""))) else Loc.t("Aprende desde cero")
	elif mode == "game":
		# Con el interruptor del tutor no cabe el título: «Partida» ya se ve en la tarjeta.
		counter.text = "" if _tutor_toggle_shown() else Loc.t("Partida")
	elif mode == "train" and _has_player():
		var lv := Assessment.level_of(float(player["rating"]["r"]))
		counter.text = Loc.f("Nivel %d · %s", [lv, str(_rank(lv)[1])])
		if train_family != "":
			counter.text = Loc.f("Nivel %d · %s", [lv, str(FAMILY_KIDS[train_family]) if kids else str(Assessment.FAMILY_NAME[train_family])])
		# Cada problema, con su nombre: nivel, número y si ya está resuelto.
		if not puzzle.is_empty() and _puzzle_name(str(puzzle.get("id", ""))) != "":
			counter.text = _puzzle_name(str(puzzle.get("id", "")))
	elif mode == "test":
		var answered := not _try.is_empty() and bool(_try.get("recorded", false))
		counter.text = Loc.f("Test de nivel · problema %d", (_test_count() + (0 if answered else 1)))
	else:
		counter.text = (Loc.f("Problema %d de %d", [index + 1, total])) if total > 0 else "Sin problemas"
		if not puzzle.is_empty() and _puzzle_name(str(puzzle.get("id", ""))) != "":
			counter.text = _puzzle_name(str(puzzle.get("id", "")))
	if kids_wall != null and is_instance_valid(kids_wall):
		kids_wall.visible = kids
	_sync_tutor_toggle()
	_sync_assistant_button()
	_sync_music()
	_build_card()
	_build_actions()
	_sync_learn_popup()
	_sync_result_popup()
	_layout(animate)


## Botones del pie. Mientras se resuelve: Pista, Un paso, Solución y Saltar. Tras resolver un paso: Solución y
## Seguir. Con el problema terminado: Repetir y Siguiente (el color pleno solo aparece cuando toca avanzar).
## En el test de nivel no hay ayudas: «No lo sé» mientras se resuelve y «Siguiente» al terminar cada problema.
func _build_actions() -> void:
	if actions == null or not is_instance_valid(actions):
		return
	if mode == "learn":
		_build_learn_actions()
		return
	if mode == "game":
		_build_game_actions()
		return
	var done := phase == Phase.SOLVED or phase == Phase.SHOWN
	var kind := "done" if done else ("step" if phase == Phase.STEP else "solve")
	var last_test := mode == "test" and done and bool(player.get("done", false))
	if browse_back > 0:
		kind = "browse"
	var key := "%s:%s:%s" % [mode, kind, str(last_test)]
	var can_help := phase == Phase.SOLVING or phase == Phase.WRONG
	if key != _actions_mode:
		_actions_mode = key
		for old in actions.get_children():
			(old as CanvasItem).visible = false
			old.queue_free()
		hint_button = null
		step_button = null
		var wide := {"font_size": F_BODY, "height": BAR_HEIGHT, "icon": 56.0, "radius": 60}
		var go := wide.duplicate()
		go["glow"] = _c("glow")
		go["trailing"] = true
		var row: Array[Button] = []
		if mode == "test":
			if kind == "solve":
				var quiet := wide.duplicate()
				quiet["glow"] = _c("shadow")
				var skip := _button("skip", "Saltar test", _skip_test, _c("field"), _c("quiet"), wide)
				left_button = _button("why", "No lo sé", _on_left, _c("surface"), _c("ink"), quiet)
				right_button = left_button
				row = [skip, left_button]
			else:
				left_button = _button("next", "Ver mi nivel" if last_test else "Siguiente", _on_right, _c("accent"), _c("accent_ink"), go)
				right_button = left_button
				row = [left_button]
		elif kind == "browse":
			# Repasando posiciones anteriores: atrás, adelante y volver a jugar.
			left_button = _tool_button("back", "Retroceder", _browse.bind(1), "peach")
			right_button = _tool_button("next", "Avanzar", _browse.bind(-1), "mint")
			row = [left_button, right_button, _tool_button("play", "Volver a jugar", _browse.bind(-99), "sky")]
		elif kind == "solve":
			hint_button = _tool_button("bulb", "Pista", _on_hint, "butter", F_FOOT - 6)
			step_button = _tool_button("step", "Un paso", _on_step, "mint", F_FOOT - 6)
			left_button = _tool_button("eye", "Solución", _on_left, "lilac", F_FOOT - 6)
			right_button = _tool_button("skip", "Saltar", _on_right, "sky", F_FOOT - 6)
			row = [_tool_button("back", "Retroceder", _browse.bind(1), "peach", F_FOOT - 6), hint_button, step_button, left_button, right_button]
		else:
			if kind == "done":
				left_button = _button("retry", "Repetir", _on_left, _c("accent_soft"), _c("accent_text"), wide)
			else:
				left_button = _button("eye", "Solución", _on_left, _c("accent_soft"), _c("accent_text"), wide)
			right_button = _button("next", "Siguiente" if kind == "done" else "Seguir", _on_right, _c("accent"), _c("accent_ink"), go)
			row = [left_button, right_button]
		for b: Button in row:
			b.mouse_filter = Control.MOUSE_FILTER_STOP
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			# Al pulsar (antes de soltar), el tablero vuelve de la explicación a la partida.
			b.button_down.connect(_why_close_for_action)
			actions.add_child(b)
	# La pista y el paso solo tienen sentido cuando le toca jugar al jugador.
	for b: Button in [hint_button, step_button]:
		if b != null and is_instance_valid(b):
			b.disabled = not can_help
			b.modulate.a = 1.0 if can_help else 0.42
	if kind == "solve" and left_button != null and is_instance_valid(left_button):
		var can_show := phase != Phase.INTRO and phase != Phase.SHOWING
		if mode == "test":
			can_show = phase == Phase.SOLVING
		left_button.disabled = not can_show
		left_button.modulate.a = 1.0 if can_show else 0.42


## Botón de la barra de ayuda: una tesela pastel con su icono grande y el nombre debajo.
func _tool_button(icon_name: String, text: String, on_press: Callable, tint_name: String, font_size: int = F_FOOT) -> Button:
	var tint := _tint(tint_name)
	var b := _button(icon_name, text, on_press, tint[0], _c("ink"), {"vertical": true, "font_size": font_size, "height": BAR_HEIGHT, "icon": 62.0, "radius": 44, "icon_color": tint[1], "pad_x": 8.0, "squeeze": true})
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b


func _build_card() -> void:
	var scroll_to := card_scroll.scroll_vertical if _keep_scroll else 0
	_keep_scroll = false
	for old in card_body.get_children():
		card_body.remove_child(old)
		old.queue_free()
	if mode == "learn":
		_build_learn_card()
		_fit_card.call_deferred()
		card_scroll.set_deferred("scroll_vertical", scroll_to)
		return
	if mode == "game":
		_build_game_card()
		_fit_card.call_deferred()
		return
	if not line_on.is_empty():
		# Viendo una variante jugada a jugada: la ficha se recoge y deja solo sus mandos, para que se vea el tablero.
		var bad_line := str(line_on.get("tone", "")) != "good"
		if bad_line and line_ply <= 0:
			# Antes de recorrer lo que pasaría, qué hace la jugada del jugador (sin decir cuál era la buena).
			var shown := _shown_exp()
			var lv: Array = shown.get("levels", [])
			if lv.size() > 0 and not bool(shown.get("correct", false)):
				var paras: Array = (lv[0] as Dictionary).get("paragraphs", [])
				if paras.size() > 1:
					card_body.add_child(_para(str(paras[0]), F_SUB, _c("ink"), font_regular))
		card_body.add_child(_line_block(line_on, str(line_on.get("label", "")) if not (exp_partial and bad_line) else "Qué pasaría"))
		_fit_card.call_deferred()
		return
	var total := puzzles.size()
	var theme_name := str(puzzle.get("theme", ""))
	var rating := int(puzzle.get("rating", 0))
	var e := _shown_exp()
	var done := phase == Phase.SOLVED or phase == Phase.SHOWN

	var head := ""
	var sub := ""
	var tone := _c("ink")
	var show_dot := false
	match phase:
		Phase.INTRO:
			if intro_waiting:
				head = Loc.f("Juegas con %s", ("negras" if view.board.chess.turn == 0 else "blancas"))
				sub = "Mira la posición con calma. Al pulsar «Comenzar», el rival hace su jugada."
			else:
				head = "Mira al rival"
				sub = "Fíjate en su jugada: después te toca a ti."
		Phase.SOLVING:
			head = Loc.f("Juegan %s", ("blancas" if view.board.chess.turn == 0 else "negras"))
			sub = "Encuentra la mejor jugada." if ask_step <= 1 else "Sigue: todavía hay más."
			if mode == "test" and ask_step <= 1:
				sub = "Encuentra la mejor jugada. Solo hay un intento."
			show_dot = true
		Phase.WRONG:
			head = "No es la mejor"
			sub = "Vuelve a intentarlo."
			tone = _c("bad")
		Phase.REPLY:
			head = "¡Bien!"
			sub = "Mira cómo responde el rival…"
			tone = _c("good")
		Phase.SOLVED:
			head = "¡Resuelto!"
			sub = "Puedes repetirlo o pasar al siguiente."
			tone = _c("good")
		Phase.SHOWING:
			head = "La solución"
			sub = "Mira cómo sigue…"
		Phase.SHOWN:
			head = "La solución"
			sub = "Puedes repetirlo o pasar al siguiente."
		Phase.STEP:
			head = "Este paso"
			sub = "Pulsa «Seguir» y continúa tú."
	if whatif:
		head = "¿Y si juego…?"
		tone = _c("ink")
		show_dot = false
	if not e.is_empty():
		head = str(e.get("headline", head))
		tone = _c("ink") if bool(e.get("asked", false)) else _tone_color(e)
		if whatif:
			head = "Es la mejor jugada" if bool(e.get("correct", false)) else head
	if total == 0:
		head = "Sin problemas"
		sub = "No se ha encontrado data/demo_puzzles.json."

	# Titular, con el peón del bando que juega mientras se resuelve.
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 20)
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_body.add_child(title_row)
	turn_dot = TurnMark.new()
	turn_dot.k = 1.3
	turn_dot.custom_minimum_size = Vector2(60.0, 64.0)
	turn_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	turn_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var white_to_move := view.board.chess.turn == 0
	var swatches: Array = view.board.piece_swatches()
	var mark_fill: Color = swatches[0] if white_to_move else swatches[1]
	turn_dot.fill = mark_fill
	if white_to_move:
		turn_dot.line = mark_fill.darkened(0.72)
	else:
		turn_dot.line = mark_fill.lightened(0.6) if dark else mark_fill.darkened(0.6)
	turn_dot.visible = show_dot
	title_row.add_child(turn_dot)
	title = _para(head, F_TITLE2 if not e.is_empty() or whatif else F_TITLE, tone, font_display)
	title.add_theme_constant_override("line_spacing", 0)
	title_row.add_child(title)
	if phase == Phase.INTRO and intro_waiting and not puzzle.is_empty():
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var go := _button("play", "Comenzar", _begin, _c("accent"), _c("accent_ink"), {"font_size": F_SUB, "height": 104.0, "icon": 50.0, "radius": 52, "glow": _c("glow")})
		go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		title_row.add_child(go)

	if whatif:
		_add_whatif(e)
	elif not e.is_empty():
		_add_explanation(e, exp_level, exp_partial)
		if mode == "test":
			# El test es breve: la explicación a fondo llega después, en el entrenamiento.
			if done and not bool(e.get("correct", false)):
				card_body.add_child(_para("Lo repasaremos con calma en el entrenamiento.", F_SUB, _c("quiet"), font_regular))
		elif done and not why_story_open and not result_popup and (exp_level >= 2 or not _solved_compact(e)):
			_add_tools()
		elif phase == Phase.STEP:
			card_body.add_child(_para("Pulsa «Seguir» y continúa tú con el resto.", F_SUB, _c("quiet"), font_regular))
	else:
		card_body.add_child(_para(sub, F_BODY, _c("quiet"), font_regular))
		if mode != "test" and not kids and (phase == Phase.SOLVING or browse_back > 0):
			_add_move_why()
	if hint_level > 0 and not whatif and (phase == Phase.SOLVING or phase == Phase.WRONG):
		card_body.add_child(_hint_block())

	# Ficha del problema. El tema es una pista: solo se enseña cuando ya está resuelto o mostrado.
	# Con una explicación o una pista a la vista no se repite: el sitio es para ellas.
	if total > 0 and not whatif and not why_story_open and not result_popup and (done or (e.is_empty() and hint_level == 0)):
		var chips := HFlowContainer.new()
		chips.add_theme_constant_override("h_separation", 12)
		chips.add_theme_constant_override("v_separation", 10)
		chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if done and theme_name != "":
			chips.add_child(_chip(theme_name, _c("accent_soft"), _c("accent_text")))
		if mode == "test":
			# En el test no se enseña la dificultad: no hay que saber por dónde va la estimación.
			chips.add_child(_chip("Test de nivel", _c("field"), _c("ink"), "cap"))
		else:
			if is_review:
				var review_tint := _tint("lilac")
				var review_label := Loc.f("Repaso %d de %d", [_review_session_seen.size(), maxi(_review_session_total, _review_session_seen.size())]) if review_session else Loc.t("Repaso de un fallo")
				chips.add_child(_chip(review_label, review_tint[0], review_tint[1], "retry"))
			if done and _rating_shown.size() == 2:
				var up := float(_rating_shown[1]) >= float(_rating_shown[0])
				var chip_tint := _tint("mint" if up else "peach")
				var lv0 := Assessment.level_of(float(_rating_shown[0]))
				var lv1 := Assessment.level_of(float(_rating_shown[1]))
				if lv1 > lv0:
					chips.add_child(_chip((Loc.t("¡Subes al nivel %d!") if kids else Loc.t("¡Táctica: nivel %d!")) % lv1, chip_tint[0], chip_tint[1], "trend"))
				chips.add_child(_chip(Loc.f("Puntuación %d → %d", [int(round(float(_rating_shown[0]))), int(round(float(_rating_shown[1])))]), chip_tint[0], chip_tint[1]))
			chips.add_child(_chip(Loc.f("Nivel %d · %d", [Assessment.level_of(float(rating)), rating]), _c("field"), _c("ink")))
			chips.add_child(_chip("Problema real de Lichess", _c("field"), _c("quiet"), "open"))
		var chips_pad := _pad(0, 8, 0, 0)
		chips_pad.add_child(chips)
		card_body.add_child(chips_pad)

	_fit_card.call_deferred()
	card_scroll.set_deferred("scroll_vertical", scroll_to)


func _section(text: String) -> MarginContainer:
	var m := _pad(0, 14, 0, 0)
	m.add_child(_text(Loc.t(text).to_upper(), F_CAP, _c("quiet"), font_semibold))
	return m


## Fila con una tesela de icono a la izquierda y texto a la derecha.
func _icon_row(icon_name: String, tint_name: String, heading: String, text: String, side: float = 92.0, heading_size: int = F_BODY, text_size: int = F_SUB) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tile := _icon_tile(icon_name, tint_name, side, side * 0.6)
	tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(tile)
	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", 2)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if heading != "":
		texts.add_child(_para(heading, heading_size, _c("ink"), font_semibold))
	if text != "":
		texts.add_child(_para(text, text_size, _c("ink") if heading == "" else _c("quiet"), font_regular))
	row.add_child(texts)
	return row


## Pista de la jugada: primero el tema del problema; después, además, qué pieza hay que mover.
func _hint_block() -> PanelContainer:
	var paper: Color = _tint("butter")[0]
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(paper.r, paper.g, paper.b, 0.6)
	sb.set_corner_radius_all(36)
	sb.content_margin_left = 22.0
	sb.content_margin_right = 26.0
	sb.content_margin_top = 20.0
	sb.content_margin_bottom = 20.0
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme_name := _hint_theme()
	var lines := PackedStringArray()
	if theme_name != "":
		lines.append(Loc.f("Busca esto: %s.", Loc.t(theme_name).to_lower()))
	if hint_level >= 2 or theme_name == "":
		lines.append(Loc.f("Mueve %s.", _hint_piece()))
	panel.add_child(_icon_row("bulb", "butter", "Pista", " ".join(lines), 84.0))
	return panel


## Tema del problema, si sirve de pista ("" si no dice nada sobre qué buscar).
func _hint_theme() -> String:
	var theme_name := str(puzzle.get("theme", ""))
	return "" if theme_name.begins_with("Ventaja") else theme_name


## «la torre de d1»: la pieza de la jugada que toca.
func _hint_piece() -> String:
	var moves: Array = puzzle.get("moves", [])
	if ask_step < 1 or ask_step >= moves.size() or fen_before == "":
		return "otra pieza"
	var from := Chess.sq_index(str(moves[ask_step]).substr(0, 2))
	var names := ["", "el peón", "el caballo", "el alfil", "la torre", "la dama", "el rey"]
	var piece := Chess.type_of(Chess.from_fen(fen_before).b[from])
	return Loc.f("%s de %s", [names[clampi(piece, 0, 6)], Chess.sq_name(from)])


## Los bloques de una explicación hasta el nivel abierto. Con partial = true solo se cuenta qué hace la jugada
## y qué permite (el jugador todavía puede reintentar): ni la mejor jugada ni los niveles siguientes.
func _add_explanation(e: Dictionary, level: int, partial: bool) -> void:
	var levels: Array = e.get("levels", [])
	if levels.size() < 4:
		return
	var first: Array = (levels[0] as Dictionary)["paragraphs"]
	var count := first.size()
	if kids:
		# Nivel Kids: una frase sencilla y a seguir. Sin variantes, sin análisis y sin enlaces a fuera de la app.
		card_body.add_child(_para(_kid_explain(e, partial), F_BODY, _c("ink"), font_regular))
		if partial and not bool(e.get("correct", false)):
			card_body.add_child(_para("Flecha roja: tu jugada. Flecha morada: lo que haría el rival.", F_FOOT, _c("quiet"), font_regular))
			card_body.add_child(_card_button("Probar otra vez", _retry_position, _c("accent_soft"), _c("accent_text"), F_SUB, "retry"))
		return
	if partial and not bool(e.get("correct", false)) and count > 1:
		# La última frase dice cuál era la mejor jugada.
		count -= 1
	var board_why := _board_why_for(e, partial)
	if why_story_open and not board_why.is_empty():
		# Paso a paso abierto: solo él, para que la tarjeta no tape el tablero.
		card_body.add_child(_why_block({"paras": why_paras}, "Jugada a jugada"))
		card_body.add_child(_card_button("Cerrar el paso a paso", _toggle_story, _c("field"), _c("quiet"), F_FOOT, "close"))
		return
	if _solved_compact(e):
		# Resuelto: la tarjeta pequeña, para que el tablero se siga viendo. Con la ventana «¡Resuelto!» abierta,
		# nada más; después, tres botones y lo que se haya abierto.
		if result_popup:
			return
		card_body.add_child(_tool_tiles([
			["step", "Paso a paso", _toggle_story, "mint"],
			["info", "Ocultar resumen" if summary_open else "Resumen", _toggle_summary, "sky"],
			["why", "¿Por qué?" if level < 2 else ("Más a fondo" if level < 4 else "Ya no hay más"), _on_why, "lilac"],
		]))
		if summary_open:
			for p: Dictionary in board_why:
				card_body.add_child(_para(str(p["text"]), F_BODY, _c("ink"), font_regular))
		if level < 2:
			return
	elif not board_why.is_empty() and mode != "test":
		# Qué ha conseguido la jugada, sacado del tablero (ataque doble, mate, qué casillas quedan…).
		for p: Dictionary in board_why:
			card_body.add_child(_para(str(p["text"]), F_BODY, _c("ink"), font_regular))
	else:
		for i in count:
			card_body.add_child(_para(str(first[i]), F_BODY, _c("ink"), font_regular))
	if mode == "test":
		return
	if not board_why.is_empty() and not partial and not whatif and not _solved_compact(e):
		# La solución entera, jugada a jugada y con flechas.
		if not why_story_open:
			var tint := _tint("mint")
			var story := _button("step", "Jugada a jugada, con flechas", _toggle_story, tint[0], tint[1], {"font_size": F_BODY, "height": 116.0, "icon": 60.0})
			var story_pad := _pad(0, 8, 0, 0)
			story_pad.add_child(story)
			card_body.add_child(story_pad)
	var lines: Array = (levels[2] as Dictionary)["lines"]
	if partial:
		# Lo que pasaría tras la jugada, para verlo en el tablero.
		for line: Dictionary in lines:
			if str(line.get("tone", "")) == "bad":
				card_body.add_child(_line_block(line, "Qué pasaría"))
		if hint_level == 0:
			card_body.add_child(_para("Prueba otra jugada. Si te atascas, pide una pista o que resuelva solo este paso.", F_SUB, _c("quiet"), font_regular))
		if phase == Phase.WRONG:
			card_body.add_child(_card_button("Reiniciar la posición", _retry_position, _c("accent_soft"), _c("accent_text"), F_SUB, "retry"))
		return
	if level >= 2:
		var concept: Dictionary = levels[1]
		card_body.add_child(_section(str(concept["title"])))
		var named := _board_concept(e)
		for text: Variant in concept["paragraphs"]:
			var t := str(text)
			if named != "" and t.contains("no tiene un motivo táctico con nombre"):
				t = named
			card_body.add_child(_para(t, F_BODY, _c("ink"), font_regular))
	if level >= 3:
		card_body.add_child(_section(str((levels[2] as Dictionary)["title"])))
		for line: Dictionary in lines:
			card_body.add_child(_line_block(line, str(line.get("label", ""))))
	if level >= 4:
		var engine: Dictionary = levels[3]
		card_body.add_child(_section(str(engine["title"])))
		for row: PackedStringArray in engine["rows"]:
			if row.size() >= 5:
				card_body.add_child(_engine_row(row))
		for text: Variant in engine["paragraphs"]:
			card_body.add_child(_para(str(text), F_FOOT, _c("quiet"), font_regular))
	if level < 4 and not _solved_compact(e):
		var tint := _tint("lilac")
		var why := _button(["why", "line", "chart"][level - 1], str(WHY_LABELS[level]), _on_why, tint[0], tint[1], {"font_size": F_BODY, "height": 116.0, "icon": 60.0})
		var why_pad := _pad(0, 8, 0, 0)
		why_pad.add_child(why)
		card_body.add_child(why_pad)
	if level >= 4:
		# Solo al fondo del todo, para quien quiera comprobarlo: de dónde sale cada dato.
		var facts: Array = e.get("facts", [])
		var toggle := _card_button("Datos de la posición" if not facts_open else "Ocultar los datos", _on_toggle_facts, _c("field"), _c("quiet"), F_FOOT, "info")
		card_body.add_child(toggle)
		if facts_open:
			for fact: Array in facts:
				var source := str(SOURCE_NAMES.get(str(fact[0]), str(fact[0])))
				card_body.add_child(_para("%s · %s" % [source, str(fact[1])], F_FOOT, _c("quiet"), font_regular))


## ¿Se enseña la tarjeta pequeña de «resuelto»? Con el problema terminado (resuelto o con la solución a la vista),
## fuera del test y de Kids, y si hay explicación sacada del tablero.
func _solved_compact(e: Dictionary) -> bool:
	if kids or mode == "test" or whatif or not (phase == Phase.SOLVED or phase == Phase.SHOWN):
		return false
	return not _board_why_for(e, false).is_empty()


func _toggle_summary() -> void:
	summary_open = not summary_open
	_keep_scroll = true
	_refresh()


func _close_result_popup() -> void:
	result_popup = false
	_refresh()


## Ventana «¡Resuelto!» sobre el tablero, semitransparente, con «OK». No tapa la barra de abajo: «Siguiente»
## sigue funcionando.
func _sync_result_popup() -> void:
	var want := result_popup and phase == Phase.SOLVED and mode != "learn" and mode != "game"
	if want and (result_popup_node == null or not is_instance_valid(result_popup_node)) and view.board.is_animating():
		var my_run0 := run_id
		_when_board_still(func() -> void:
			if my_run0 == run_id and result_popup:
				_sync_result_popup())
		return
	if want and Time.get_ticks_msec() < result_popup_at:
		# Un instante para ver la última jugada.
		var my_run := run_id
		get_tree().create_timer(float(result_popup_at - Time.get_ticks_msec()) / 1000.0 + 0.02).timeout.connect(func() -> void:
			if my_run == run_id and result_popup:
				_sync_result_popup())
		want = false
	if result_popup_node != null and is_instance_valid(result_popup_node):
		if want:
			return
		result_popup_node.queue_free()
	result_popup_node = null
	if not want:
		return
	result_popup_node = Control.new()
	result_popup_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_popup_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(result_popup_node)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	var paper := _c("surface")
	sb.bg_color = Color(paper.r, paper.g, paper.b, 0.82)
	sb.set_corner_radius_all(60)
	sb.shadow_color = _c("shadow")
	sb.shadow_size = 30
	sb.shadow_offset = Vector2(0.0, 12.0)
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	result_popup_node.add_child(panel)
	var pad := _pad(50, 40, 50, 40)
	panel.add_child(pad)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 22)
	pad.add_child(column)
	var tick := _icon("check", 120.0, _c("good"))
	tick.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(tick)
	column.add_child(_centered(_para("¡Resuelto!", F_TITLE + 16, _c("good"), font_display)))
	var ok := _button("check", "OK", _close_result_popup, _c("accent"), _c("accent_ink"), {"font_size": F_HEAD, "height": 120.0, "radius": 60, "glow": _c("glow")})
	ok.custom_minimum_size = Vector2(360.0, 120.0)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(ok)
	# Pequeña, centrada sobre el tablero; aparece con un leve rebote.
	var place := func() -> void:
		if not is_instance_valid(panel) or board_slot == null or not is_instance_valid(board_slot):
			return
		var w := minf(size.x - 160.0, 640.0)
		panel.size = Vector2(w, 0.0)
		panel.reset_size()
		panel.size.x = w
		var h := panel.get_combined_minimum_size().y
		var rect := board_slot.get_global_rect()
		panel.position = Vector2((size.x - w) * 0.5, clampf(rect.get_center().y - h * 0.5, 40.0, size.y - h - 40.0))
		panel.pivot_offset = panel.size * 0.5
	panel.minimum_size_changed.connect(place)
	place.call_deferred()
	panel.scale = Vector2(0.85, 0.85)
	panel.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(panel, "modulate:a", 1.0, 0.18)


## Si en la solución hay un ataque doble (lo ve el tablero, aunque el problema no lo tenga como tema), el concepto.
func _board_concept(e: Dictionary) -> String:
	if not bool(e.get("correct", false)) or puzzle.is_empty():
		return ""
	var moves: Array = puzzle.get("moves", [])
	var pos := _puzzle_pos(1)
	for i in range(1, moves.size()):
		var m := pos.find_uci(str(moves[i]))
		if m < 0:
			break
		if i % 2 == 1 and MoveWhy.short_tag(pos, m).begins_with("ataque doble"):
			return "Ataque doble: una sola pieza ataca dos cosas a la vez y el rival solo puede salvar una. Si una de ellas es el rey (un jaque), ni siquiera puede elegir: tiene que salir del jaque y pierde la otra."
		pos.apply(m)
	return ""


## Párrafos sacados del tablero para una jugada acertada de quien resuelve: los de la última jugada de la solución
## que se ha visto (lo que ha conseguido). Vacío si no toca (fallo, niños, otra pantalla).
func _board_why_for(e: Dictionary, partial: bool) -> Array:
	if kids or partial or whatif or not bool(e.get("correct", false)) or puzzle.is_empty() or mode == "learn":
		return []
	var moves: Array = puzzle.get("moves", [])
	# La última jugada de quien resuelve que ya está en el tablero.
	var last := -1
	var upto := moves.size() if phase == Phase.SOLVED or phase == Phase.SHOWN else mini(ask_step, moves.size())
	for i in range(1, upto):
		if i % 2 == 1:
			last = i
	if last < 0:
		return []
	var w := _puzzle_move_why(last)
	return w.get("paras", [])


## Una variante con sus botones para verla jugada a jugada en el tablero.
func _line_block(line: Dictionary, label: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var good := str(line.get("tone", "")) == "good"
	box.add_child(_para(label, F_SUB, _c("good") if good else _c("bad"), font_semibold))
	box.add_child(_para(str(line.get("text", "")), F_SUB, _c("ink"), font_medium))
	var note := _ply_note(line, line_ply) if (not line_on.is_empty() and line_on == line) else ""
	if note != "":
		var tint := _tint("lilac")
		var note_panel := PanelContainer.new()
		var nsb := StyleBoxFlat.new()
		nsb.bg_color = tint[0]
		nsb.set_corner_radius_all(28)
		nsb.content_margin_left = 26.0
		nsb.content_margin_right = 26.0
		nsb.content_margin_top = 16.0
		nsb.content_margin_bottom = 18.0
		note_panel.add_theme_stylebox_override("panel", nsb)
		note_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		note_panel.add_child(_para(note, F_FOOT + 2, _c("ink"), font_regular))
		box.add_child(note_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var active := not line_on.is_empty() and line_on == line
	var ucis: Array = line.get("ucis", [])
	var steps := [["first", -1], ["prev", maxi(-1, line_ply - 1) if active else -1], ["play", mini(ucis.size() - 1, line_ply + 1) if active else 0]]
	for step_def: Array in steps:
		var kind := str(step_def[0])
		var b := _round_button("play" if kind == "prev" else kind, _step_line.bind(line, int(step_def[1])), 96.0, _c("field"), _c("ink"), false)
		b.mouse_filter = Control.MOUSE_FILTER_PASS
		if kind == "prev":
			# El mismo triángulo de «siguiente», mirando al otro lado.
			for child in b.get_child(0).get_children():
				if child is TextureRect:
					(child as TextureRect).flip_h = true
		row.add_child(b)
	if active:
		var where := "inicio" if line_ply < 0 else Loc.f("%d de %d", [line_ply + 1, ucis.size()])
		var mark := _text(where, F_FOOT, _c("quiet"), font_medium)
		mark.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(mark)
		# Con una jugada fallada, se vuelve a la posición para reintentar; si no, a la explicación.
		var again := phase == Phase.WRONG and not whatif
		var back := _button("retry" if again else "back", "Reiniciar" if again else "Explicación", _leave_line, _c("accent_soft"), _c("accent_text"), {"font_size": F_SUB, "height": 96.0, "icon": 44.0})
		row.add_child(back)
	box.add_child(row)
	return box


## Nota de la jugada «ply» de una variante de «Qué pasaría» (data/notas, tools/notas/generar.py): solo hechos de
## las reglas (jaque, pieza atacada, captura…) y lo que dice el motor (casi obligada o casi igual que otras, con sus
## valoraciones). Nunca un «porque»: el motor no da motivos. "" si no hay nada que decir.
func _ply_note(line: Dictionary, ply: int) -> String:
	var notes: Array = line.get("notes", [])
	if ply < 1 or ply >= notes.size():
		return ""
	var n: Dictionary = notes[ply]
	if n.is_empty():
		return ""
	var sans := _line_sans(str(line.get("text", "")))
	var san := str(sans[ply]) if ply < sans.size() else ""
	var names := {"p": "el peón", "n": "el caballo", "b": "el alfil", "r": "la torre", "q": "la dama", "k": "el rey"}
	var parts: Array[String] = []
	for f: Array in n.get("r", []):
		match str(f[0]):
			"j":
				parts.append(Loc.t("Estaba en jaque."))
			"t":
				var moved := str(names.get(str(f[1]), ""))
				var by := Loc.f("%s de %s", [str(names.get(str(f[3]), "")), str(f[2])])
				var tpl := "%s estaba atacada por %s." if moved.begins_with("la ") else "%s estaba atacado por %s."
				var said := Loc.f(tpl, [moved, by])
				parts.append(said.substr(0, 1).to_upper() + said.substr(1))
			"x":
				parts.append(Loc.f("Captura %s.", Loc.f("%s de %s", [str(names.get(str(f[1]), "")), str(f[2])])))
			"re":
				parts.append(Loc.t("Recupera material en la misma casilla."))
			"+":
				parts.append(Loc.t("Da jaque."))
			"#":
				parts.append(Loc.t("Da mate."))
	match str(n.get("k", "")):
		"o":
			parts.append(Loc.t("Es la única jugada legal."))
		"f":
			parts.append(Loc.t("Según el motor, casi obligada: cualquier otra es mucho peor."))
		"s":
			var alts: Array[String] = []
			for a: Array in n.get("a", []):
				alts.append("%s (%s)" % [Loc.san_text(str(a[0])), str(a[1])])
			parts.append(Loc.f("Según el motor, da casi igual: %s también (esta, %s).", [Loc.list_sep().join(alts), str(n.get("v", ""))]))
	if parts.is_empty():
		return ""
	return "%s: %s" % [san, " ".join(parts)]


## Las jugadas de una variante escrita («6. Cxf7 Dh4 7. d3…»), sin los números.
static func _line_sans(text: String) -> Array:
	var out: Array = []
	for token: String in text.split(" ", false):
		var bare := token.rstrip(".…")
		if bare.is_valid_int() and bare != token:
			continue
		out.append(token)
	return out


## Fila de la tabla del motor: etiqueta, jugada, evaluación y profundidad; debajo, la continuación.
func _engine_row(row: PackedStringArray) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_para(Loc.f("%s · %s · %s · prof. %s", [row[0], row[1], row[2], row[3]]), F_SUB, _c("ink"), font_medium))
	box.add_child(_para(row[4], F_FOOT, _c("quiet"), font_regular))
	return box


## Ayudas de después del problema: probar otra jugada, analizar en Lichess y preguntar a una IA.
## Tres teselas ilustradas, una al lado de otra.
func _add_tools() -> void:
	if explain == null or not explain.ok or kids:
		return
	card_body.add_child(_section("Más ayuda"))
	card_body.add_child(_tool_tiles([
		["whatif", "¿Y si juego…?", _toggle_whatif, "sky"],
		["spark", "Pregunta a una IA", _open_ai, "rose"],
	]))


func _tool_tiles(defs: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for def: Array in defs:
		var tint := _tint(str(def[3]))
		var b := _button(str(def[0]), str(def[1]), def[2], tint[0], _c("ink"), {"vertical": true, "wrap": true, "font_size": F_FOOT, "height": 214.0, "icon": 76.0, "radius": 44, "icon_color": tint[1], "pad_x": 10.0, "font": font_medium})
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	return row


func _add_whatif(e: Dictionary) -> void:
	if e.is_empty():
		var fen := _decision_fen()
		var side := "blancas" if fen != "" and Chess.from_fen(fen).turn == 0 else "negras"
		card_body.add_child(_para(Loc.f("Mueve cualquier pieza de las %s y te explico qué pasaría con esa jugada.", side), F_BODY, _c("ink"), font_regular))
	else:
		card_body.add_child(_para(Loc.f("Probando %s", str(e.get("san", ""))), F_SUB, _c("quiet"), font_semibold))
		_add_explanation(e, whatif_level, false)
		card_body.add_child(_para("Prueba otra jugada en el tablero o vuelve a la explicación.", F_SUB, _c("quiet"), font_regular))
	var back := _card_button("Volver a la explicación", _toggle_whatif, _c("field"), _c("ink"), F_SUB, "back")
	card_body.add_child(back)
	if not e.is_empty():
		card_body.add_child(_tool_tiles([
			["spark", "Pregunta a una IA", _open_ai, "rose"],
		]))


func _set_phase(p: Phase) -> void:
	phase = p
	result_popup = p == Phase.SOLVED and mode != "test" and not kids and not whatif
	if result_popup:
		summary_open = false
		result_popup_at = Time.get_ticks_msec() + 450
	# Un repaso queda hecho cuando el problema termina, resuelto o con la solución a la vista.
	var review_done := is_review and (p == Phase.SOLVED or p == Phase.SHOWN) and not puzzle.is_empty() and not reviewed.has(str(puzzle["id"]))
	if review_done:
		reviewed[str(puzzle["id"])] = true
		_save_player()
	if p == Phase.SOLVED or p == Phase.SHOWN:
		_prog_finish(p == Phase.SOLVED, review_done)
	_refresh()


# ---------------------------------------------------------------- explicación en el tablero

## Flechas que acompañan a una explicación: las del nivel más profundo abierto que tenga alguna (solo de los
## dos primeros niveles; los demás enseñan variantes). Mientras se puede reintentar, nunca la de la solución.
func _arrows_for(e: Dictionary, level: int, partial: bool) -> Array:
	var levels: Array = e.get("levels", [])
	var out: Array = []
	for i in mini(mini(level, 2), levels.size()):
		var arrows: Array = (levels[i] as Dictionary)["arrows"]
		if not arrows.is_empty():
			out = arrows
	var seen := {}
	var unique: Array = []
	for a: Dictionary in out:
		var key := int(a["from"]) * 64 + int(a["to"])
		if seen.has(key) or (partial and str(a["tone"]) == "good"):
			continue
		seen[key] = true
		unique.append(a)
	return unique


## Enseña la posición en la que había que decidir, con la jugada del rival resaltada y unas flechas.
func _show_decision(arrows: Array) -> void:
	var fen := explain.point_fen(exp_point) if explain != null and explain.ok else fen_before
	if fen == "":
		return
	view.set_fen(fen)
	var moves: Array = puzzle.get("moves", [])
	if 2 * exp_point < moves.size():
		var rival := str(moves[2 * exp_point])
		view.board.mark_last_move(Chess.sq_index(rival.substr(0, 2)), Chess.sq_index(rival.substr(2, 2)))
	view.board.set_arrows(arrows)
	view.interactive = whatif or phase == Phase.WRONG


## Deja el tablero como corresponde a lo que se está explicando. En el primer nivel no se toca: sigue a la
## vista la posición final (el mate, la pieza ganada). Desde el segundo, se vuelve a la posición de la decisión.
func _sync_board_to_explanation() -> void:
	if not line_on.is_empty():
		return
	var e := _shown_exp()
	if whatif:
		_show_decision(_arrows_for(e, whatif_level, false) if not e.is_empty() else [])
	elif phase == Phase.WRONG:
		_show_decision(_arrows_for(e, 1, true))
	elif not e.is_empty() and exp_level >= 2:
		_show_decision(_arrows_for(e, exp_level, false))


## Botón «Explícame por qué» / «Ver la variante» / «Ver el análisis»: un nivel más de profundidad.
func _on_why() -> void:
	_why_close_for_action()
	if whatif:
		whatif_level = mini(whatif_level + 1, 4)
	else:
		exp_level = mini(exp_level + 1, 4)
	_keep_scroll = true
	_refresh()
	_sync_board_to_explanation()


func _on_toggle_facts() -> void:
	facts_open = not facts_open
	_keep_scroll = true
	_refresh()


## Enseña una variante en el tablero: ply = −1 la posición de partida; n, la jugada n (se ve moverse).
func _step_line(line: Dictionary, ply: int) -> void:
	var ucis: Array = line.get("ucis", [])
	if ucis.is_empty():
		return
	run_id += 1
	line_on = line
	line_ply = clampi(ply, -1, ucis.size() - 1)
	view.interactive = false
	view.board.set_arrows([])
	if line_ply < 0:
		view.set_fen(str(line.get("fen", "")))
	else:
		var before := ExplainData.line_fen(line, line_ply)
		if before == "":
			return
		view.set_fen(before)
		view.show_move(str(ucis[line_ply]))
	_keep_scroll = true
	_refresh()


## Deja de ver la variante y vuelve a la posición de la decisión.
func _leave_line() -> void:
	line_on = {}
	line_ply = -1
	_keep_scroll = true
	_refresh()
	var e := _shown_exp()
	if whatif:
		_show_decision(_arrows_for(e, whatif_level, false) if not e.is_empty() else [])
	elif phase == Phase.WRONG:
		# De vuelta a la posición para intentarlo otra vez: limpia, sin la flecha de la jugada fallada.
		_show_decision([])
	else:
		_show_decision(_arrows_for(e, maxi(exp_level, 1), false))


# ---------------------------------------------------------------- retroceder y «¿por qué esa jugada?»

## Posición del problema tras sus primeras `ply` jugadas (0 = la de partida).
func _puzzle_pos(ply: int) -> Chess:
	var pos := Chess.from_fen(str(puzzle.get("fen", "")))
	var moves: Array = puzzle.get("moves", [])
	for i in mini(ply, moves.size()):
		var m := pos.find_uci(str(moves[i]))
		if m < 0:
			break
		pos.apply(m)
	return pos


## «Retroceder» / «Avanzar»: enseña posiciones anteriores del problema sin perder la de ahora. Con −99 vuelve a ella.
func _browse(delta: int) -> void:
	if mode == "test" or (phase != Phase.SOLVING and phase != Phase.WRONG):
		return
	var was := browse_back
	browse_back = 0 if delta <= -99 else clampi(browse_back + delta, 0, ask_step)
	if browse_back == was:
		if was == 0:
			_note("Es la primera posición")
		return
	run_id += 1
	line_on = {}
	line_ply = -1
	move_why_open = false
	why_board = false
	why_story_open = false
	summary_open = false
	result_popup = false
	why_paras = []
	if phase == Phase.WRONG:
		_clear_explanation()
		phase = Phase.SOLVING
	if browse_back == 0:
		_restore_position()
		view.board.set_arrows([])
		view.interactive = true
		_note("De vuelta: te toca")
	else:
		var ply := ask_step - browse_back
		view.set_fen(_puzzle_pos(ply).fen())
		var moves: Array = puzzle.get("moves", [])
		if ply >= 1 and ply - 1 < moves.size():
			var last := str(moves[ply - 1])
			view.board.mark_last_move(Chess.sq_index(last.substr(0, 2)), Chess.sq_index(last.substr(2, 2)))
		view.board.set_arrows([])
		view.interactive = false
		_note("Posición de partida" if ply == 0 else (Loc.t("Hace 1 jugada") if browse_back == 1 else Loc.f("Hace %d jugadas", browse_back)))
	_actions_mode = ""
	_refresh()


## Bando de quien resuelve: el que no mueve en la posición de partida (la primera jugada es la del rival).
func _solver_color() -> int:
	var fen := str(puzzle.get("fen", ""))
	if fen == "":
		return 0
	return 1 - Chess.from_fen(fen).turn


## Explicación de la jugada `i` de la línea del problema, con su veredicto: la primera del rival es el error que
## abre el problema; las demás del rival, su defensa (o su única jugada); las de quien resuelve, las mejores.
## Explicaciones ya calculadas (las del rival usan una búsqueda corta del motor): por problema y jugada.
var _why_cache := {}


## Con `reveal` = false (el problema aún no está resuelto) la explicación no cuenta lo que sigue en la solución.
func _puzzle_move_why(i: int, reveal: bool = true) -> Dictionary:
	var moves: Array = puzzle.get("moves", [])
	if i < 0 or i >= moves.size():
		return {}
	var key := "%s|%s|%d|%s" % [str(puzzle.get("id", "")), str(puzzle.get("fen", "")), i, str(reveal)]
	if _why_cache.has(key):
		return _why_cache[key]
	if _why_cache.size() > 200:
		_why_cache.clear()
	var e := _puzzle_move_why_now(i, reveal)
	_why_cache[key] = e
	return e


func _puzzle_move_why_now(i: int, reveal: bool = true) -> Dictionary:
	var moves: Array = puzzle.get("moves", [])
	var before := _puzzle_pos(i)
	var m := before.find_uci(str(moves[i]))
	if m < 0:
		return {}
	var role := "solution" if i % 2 == 1 else ("blunder" if i == 0 else "reply")
	return MoveWhy.explain(before, m, _solver_color(), role, moves.slice(i + 1), reveal)


## «¿Por qué ha jugado eso?» mientras se resuelve: se explica la jugada sin dar lo que sigue en la solución (antes
## decía «Pero es un error: permite…» con la solución entera, y el problema contaba como resuelto sin ayuda).
func _why_reveal() -> bool:
	return phase == Phase.SOLVED or phase == Phase.SHOWN


## Botón «¿Por qué esa jugada?» y, abierto, la explicación de la última jugada que se ve en el tablero (la del rival
## mientras se resuelve; la que toque al retroceder), párrafo a párrafo y con flechas.
func _add_move_why() -> void:
	var moves: Array = puzzle.get("moves", [])
	var ply := ask_step - browse_back  # jugadas hechas en la posición que se ve
	if ply < 1 or ply - 1 >= moves.size():
		return
	var mine := (ply - 1) % 2 == 1
	if not move_why_open:
		card_body.add_child(_card_button("¿Por qué jugaste eso?" if mine else "¿Por qué ha jugado eso el rival?", _toggle_move_why, _c("field"), _c("ink"), F_SUB, "why"))
		return
	var e := _puzzle_move_why(ply - 1, _why_reveal())
	if e.is_empty():
		return
	card_body.add_child(_why_block(e, (Loc.t("Tu jugada: %s") if mine else Loc.t("La jugada del rival: %s")) % str(e["san"])))
	card_body.add_child(_card_button("Ocultar", _toggle_move_why, _c("field"), _c("quiet"), F_FOOT, "close"))


const WHY_TONES := {"only": "info", "best": "good", "defense": "info", "error": "bad", "plain": "quiet"}


## Tarjeta de una explicación paso a paso: el veredicto, el párrafo que toca y los botones para pasar de uno a otro.
## Cada párrafo trae sus flechas: se ven en el tablero.
func _why_block(e: Dictionary, heading: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if heading != "":
		box.add_child(_section(heading))
	var paras: Array = e.get("paras", [])
	if paras.is_empty():
		return box
	if why_paras != paras:
		why_paras = paras
		why_idx = 0
	var p: Dictionary = paras[clampi(why_idx, 0, paras.size() - 1)]
	var verdict := str(p.get("verdict", e.get("verdict", "")))
	var label := str(p.get("label", e.get("label", "")))
	var tone := str(WHY_TONES.get(verdict, "quiet"))
	var color := _c("good") if tone == "good" else (_c("bad") if tone == "bad" else ((Color("a593ff") if dark else Color("5b3fd0")) if tone == "info" else _c("quiet")))
	if label != "":
		var title := label if not p.has("san") else "%s · %s" % [str(p["san"]), label]
		box.add_child(_para(title, F_BODY, color, font_semibold))
	box.add_child(_para(str(p["text"]), F_BODY, _c("ink"), font_regular))
	if paras.size() > 1:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var prev := _round_button("play", _why_go.bind(-1), 96.0, _c("field"), _c("ink"), false)
		for child in prev.get_child(0).get_children():
			if child is TextureRect:
				(child as TextureRect).flip_h = true
		prev.disabled = why_idx <= 0
		prev.modulate.a = 0.4 if why_idx <= 0 else 1.0
		row.add_child(prev)
		var where := _text(Loc.f("%d de %d", [why_idx + 1, paras.size()]), F_SUB, _c("quiet"), font_medium)
		where.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		where.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		where.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(where)
		var next := _round_button("play", _why_go.bind(1), 96.0, _c("accent_soft"), _c("accent_text"), false)
		next.disabled = why_idx >= paras.size() - 1
		next.modulate.a = 0.4 if why_idx >= paras.size() - 1 else 1.0
		row.add_child(next)
		box.add_child(row)
	return box


## Enseña en el tablero el párrafo que se está leyendo: su posición, la jugada resaltada y sus flechas.
func _why_apply() -> void:
	if why_paras.is_empty():
		return
	var p: Dictionary = why_paras[clampi(why_idx, 0, why_paras.size() - 1)]
	if not why_board:
		why_saved = {"fen": view.board.chess.fen(), "from": view.board.last_from, "to": view.board.last_to, "interactive": view.interactive}
		why_board = true
	view.set_fen(str(p["fen"]))
	var mv: Array = p.get("move", [])
	if mv.size() == 2:
		view.board.mark_last_move(int(mv[0]), int(mv[1]))
	view.board.set_arrows(p.get("arrows", []))
	view.interactive = false
	# El rey «intenta» ir a cada casilla, una detrás de otra.
	var tries: Array = p.get("tries", [])
	if not tries.is_empty():
		var my_idx := why_idx
		var my_paras := why_paras
		for i in tries.size():
			var tr: Array = tries[i]
			get_tree().create_timer(0.35 + 1.0 * float(i)).timeout.connect(func() -> void:
				if why_board and why_idx == my_idx and why_paras == my_paras:
					view.board.try_square(int(tr[0]), int(tr[1])))


func _why_go(delta: int) -> void:
	if why_paras.is_empty():
		return
	why_idx = clampi(why_idx + delta, 0, why_paras.size() - 1)
	_why_apply()
	_keep_scroll = true
	_refresh()


## Deja el tablero como estaba antes de la explicación.
func _why_restore() -> void:
	if not why_board:
		return
	why_board = false
	view.set_fen(str(why_saved.get("fen", view.board.chess.fen())))
	view.board.mark_last_move(int(why_saved.get("from", -1)), int(why_saved.get("to", -1)))
	view.board.set_arrows([])
	view.interactive = bool(why_saved.get("interactive", false))


## Antes de cualquier botón de la barra: si se estaba enseñando una explicación en el tablero, se cierra.
func _why_close_for_action() -> void:
	if move_why_open or why_story_open:
		_why_restore()
		move_why_open = false
		why_story_open = false
		summary_open = false
		result_popup = false
		why_paras = []


## La solución entera, jugada a jugada: cada jugada con su veredicto y sus párrafos.
func _story_paras() -> Array:
	var out: Array = []
	var moves: Array = puzzle.get("moves", [])
	for i in range(1, moves.size()):
		var e := _puzzle_move_why(i)
		if e.is_empty():
			break
		for p: Dictionary in e["paras"]:
			var q := p.duplicate()
			q["verdict"] = e["verdict"]
			q["label"] = e["label"]
			q["san"] = e["san"]
			out.append(q)
	return out


func _toggle_story() -> void:
	why_story_open = not why_story_open
	if why_story_open:
		why_paras = _story_paras()
		why_idx = 0
		_why_apply()
	else:
		_why_restore()
		why_paras = []
	_keep_scroll = true
	_refresh()


## Explicación para niños de una jugada de un problema: una frase fija (con voz) según la clase de error que
## calculó el análisis, o según la idea del problema si se ha resuelto. Sin notación: lo demás lo enseñan las flechas.
const KID_ERRORS := {"mate": "trainMate", "hangMoved": "trainHangMoved", "hangOther": "trainHangOther", "material": "trainMaterial", "worse": "trainWorse", "missed": "trainMissed", "slower": "trainSlower"}
const KID_SOLVED := {"mate": "solvedMate", "doble": "solvedDoble", "linea": "solvedLinea", "defensor": "solvedDefensor", "peon": "solvedPeon", "caza": "solvedCaza", "otros": "solvedOtros"}


func _kid_explain(e: Dictionary, partial: bool) -> String:
	var line := ""
	if partial and not bool(e.get("correct", false)):
		line = _kid_line(str(KID_ERRORS.get(str(e.get("error", "")), "trainWorse")))
		return line if line != "" else _kid_line("tryAgain")
	if bool(e.get("asked", false)) or not bool(e.get("correct", false)):
		line = _kid_line("trainShown")
		return line if line != "" else "Mira cuál era la jugada buena."
	# Resuelto: si acaba en mate, eso es lo que se cuenta; si no, la idea de su categoría.
	var fam := "mate" if view.board.chess.is_checkmate() else str(puzzle.get("family", "otros"))
	if fam == "mate" and not view.board.chess.is_checkmate():
		fam = "otros"
	if fam == "peon" and not _solution_promotes():
		fam = "otros"
	line = _kid_line(str(KID_SOLVED.get(fam, "solvedOtros")))
	return line if line != "" else _kid_line("good")


func _solution_promotes() -> bool:
	for uci: Variant in puzzle.get("moves", []):
		if str(uci).length() > 4:
			return true
	return false


## Para niños: tras una jugada fallada, además de su jugada (en rojo), la respuesta del rival que la castiga.
func _kid_wrong_arrows(e: Dictionary) -> Array:
	var arrows := _arrows_for(e, 1, true)
	var levels: Array = e.get("levels", [])
	if levels.size() >= 3:
		for line: Dictionary in (levels[2] as Dictionary).get("lines", []):
			var ucis: Array = line.get("ucis", [])
			if str(line.get("tone", "")) == "bad" and ucis.size() >= 2:
				var reply := str(ucis[1])
				arrows.append({"from": Chess.sq_index(reply.substr(0, 2)), "to": Chess.sq_index(reply.substr(2, 2)), "tone": "info"})
				break
	return arrows


## Chapa con la valoración de la jugada en su casilla de destino, con los signos de anotación de siempre:
## «!» buena jugada (aquí, la de la solución), «?» error, «??» error grave (pierde material o permite mate).
## Signo (o «@icono») y color de cada chapa.
const BADGES := {"miss": ["@close", Color("d9577a")], "brilliant": ["!!", Color("1aa3a3")], "best": ["!", Color("2f9e63")], "excellent": ["@g_arriba", Color("2a9d7f")], "good": ["@check", Color("3fa06a")], "only": ["@target", Color("7c5cfa")], "wrong": ["?", Color("e08a2b")], "blunder": ["??", Color("d1453b")], "dubious": ["?!", Color("d9a521")]}


func _move_badge(uci: String, kind: String) -> void:
	if kids or uci.length() < 4 or not BADGES.has(kind):
		return
	var def: Array = BADGES[kind]
	var glyph := str(def[0])
	if glyph.begins_with("@"):
		view.board.set_badge(Chess.sq_index(uci.substr(2, 2)), "", def[1], UiIcons.texture(glyph.substr(1)))
	else:
		view.board.set_badge(Chess.sq_index(uci.substr(2, 2)), glyph, def[1])


func _toggle_move_why() -> void:
	move_why_open = not move_why_open
	why_paras = []
	why_idx = 0
	if move_why_open:
		var ply := ask_step - browse_back
		var e := _puzzle_move_why(ply - 1, _why_reveal())
		if not e.is_empty():
			why_paras = e["paras"]
			_why_apply()
	else:
		_why_restore()
	_refresh()


## «Reiniciar» tras una jugada que no era la mejor: la posición vuelve a estar como al pedir la jugada, sin flechas
## ni explicación, lista para probar otra.
func _retry_position() -> void:
	if phase != Phase.WRONG:
		return
	run_id += 1
	line_on = {}
	line_ply = -1
	_clear_explanation()
	hint_level = 0
	_restore_position()
	view.board.set_arrows([])
	view.interactive = true
	_set_phase(Phase.SOLVING)


## «¿Y si juego…?»: entra o sale del modo de probar jugadas.
func _toggle_whatif() -> void:
	if explain == null or not explain.ok:
		return
	_why_close_for_action()
	run_id += 1
	whatif = not whatif
	whatif_exp = {}
	whatif_level = 1
	line_on = {}
	line_ply = -1
	facts_open = false
	if whatif:
		_show_decision([])
	else:
		_show_decision(_arrows_for(expl, maxi(exp_level, 1), false))
	_refresh()


## Posición sobre la que se pregunta: la de la decisión que se está explicando.
func _decision_fen() -> String:
	if explain != null and explain.ok:
		return explain.point_fen(exp_point)
	return fen_before


## Tablero de análisis de Lichess con la posición cargada (lichess.org/analysis/<FEN con %20 por espacio>).
func _lichess_url(fen: String) -> String:
	return "https://lichess.org/analysis/" + "%20".join(fen.strip_edges().split(" ", false))


func _open_lichess() -> void:
	var fen := _decision_fen()
	if fen != "":
		OS.shell_open(_lichess_url(fen))


## Texto que se lleva a una IA general: la posición exacta y el análisis del motor, no una captura. Las IA
## generales leen mal los tableros en imagen y se equivocan al calcular: así parten de datos ciertos.
func _ai_text() -> String:
	var e := _shown_exp()
	if e.is_empty():
		e = expl
	var fen := _decision_fen()
	if e.is_empty() or fen == "":
		return ""
	var side := Loc.t("las blancas") if Chess.from_fen(fen).turn == 0 else Loc.t("las negras")
	var played := str(e.get("san", ""))
	var best := str(e.get("best", ""))
	var correct := bool(e.get("correct", false))
	var out := PackedStringArray([
		Loc.t("Estoy aprendiendo ajedrez y tengo una duda sobre esta posición de un problema real de Lichess."),
		"",
		Loc.f("Posición (FEN): %s", fen),
		Loc.f("Juegan %s.", side),
	])
	var question := ""
	if whatif:
		out.append(Loc.f("Estoy probando %s%s", [played, Loc.t(", que es la mejor jugada.") if correct else Loc.t("; la mejor es %s.") % best]))
	elif bool(e.get("asked", false)):
		out.append(Loc.f("La mejor jugada es %s.", best))
	elif correct:
		out.append(Loc.f("He jugado %s, que es la mejor jugada.", played))
	else:
		out.append(Loc.f("He jugado %s, pero la mejor era %s.", [played, best]))
	if correct or bool(e.get("asked", false)):
		question = Loc.f("¿Por qué %s es la mejor jugada en esta posición? Explícamelo de forma sencilla.", best)
	else:
		question = Loc.f("¿Por qué %s no funciona y %s sí? Explícamelo de forma sencilla.", [played, best])
	var levels: Array = e.get("levels", [])
	if levels.size() >= 4:
		for line: Dictionary in (levels[2] as Dictionary)["lines"]:
			if str(line.get("tone", "")) == "good":
				out.append(Loc.f("Solución: %s", str(line.get("text", ""))))
				break
		var rows: Array = (levels[3] as Dictionary)["rows"]
		if not rows.is_empty():
			out.append("")
			out.append(Loc.f("Análisis de %s (positivo = ventaja para quien mueve):", explain.engine))
			for row: PackedStringArray in rows:
				if row.size() >= 5:
					out.append(Loc.f("- %s: %s, profundidad %s. Sigue: %s", [row[1], row[2], row[3], row[4]]))
	out.append("")
	out.append(Loc.f("Tablero: %s", _lichess_url(fen)))
	out.append("")
	out.append(Loc.f("Mi pregunta: %s", question))
	out.append("")
	out.append(Loc.t("Usa solo jugadas legales en esta posición, apóyate en el análisis del motor y, si no estás seguro de algo, dilo."))
	return "\n".join(out)


func _open_ai() -> void:
	sheet_kind = "ai"
	options_open = false
	_build_ai_sheet()
	overlay.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(overlay, "modulate:a", 1.0, 0.14)


func _copy_ai_text() -> void:
	DisplayServer.clipboard_set(_ai_text())
	if _ai_status != null and is_instance_valid(_ai_status):
		_ai_status.text = Loc.t("Copiado. Pégalo en la IA que prefieras.")
		_ai_status.visible = true


## Abre la búsqueda de Google en Modo IA con la pregunta. El parámetro udm=50 no está documentado por Google
## (lo han observado terceros): si deja de funcionar, la búsqueda se abre en modo normal.
func _open_google_ai() -> void:
	OS.shell_open("https://www.google.com/search?udm=50&q=" + _ai_text().uri_encode())


func _build_ai_sheet() -> void:
	var box := _sheet("Pregunta a una IA")
	if box == null:
		return
	box.add_child(_para("Las IA generales se equivocan a menudo en ajedrez, sobre todo al calcular jugadas. Comprueba en el tablero cualquier jugada que te propongan.", F_SUB, _c("ink"), font_regular))
	var copy := _button("copy", "Copiar el texto", _copy_ai_text, _c("accent"), _c("accent_ink"), {"font_size": F_BODY, "height": 124.0, "icon": 56.0, "glow": _c("glow")})
	box.add_child(copy)
	var tint := _tint("sky")
	var google := _button("open", "Abrir en Google (Modo IA)", _open_google_ai, tint[0], tint[1], {"font_size": F_SUB, "height": 112.0, "icon": 52.0})
	box.add_child(google)
	_ai_status = _para("", F_SUB, _c("good"), font_medium)
	_ai_status.visible = false
	box.add_child(_ai_status)
	box.add_child(_caption("Texto que se copia"))
	var preview := _para(_ai_text(), F_CAP, _c("quiet"), font_regular)
	box.add_child(preview)


# ---------------------------------------------------------------- hojas inferiores (opciones y ayuda)

func _open_options() -> void:
	options_open = true
	sheet_kind = "options"
	_build_sheet()
	overlay.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(overlay, "modulate:a", 1.0, 0.14)


## Cierra la hoja que haya abierta (opciones o ayuda).
func _close_options() -> void:
	options_open = false
	sheet_kind = ""
	if overlay != null and is_instance_valid(overlay):
		overlay.visible = false
		overlay.queue_free()
	overlay = null


func _sync_sheet() -> void:
	if sheet_kind == "options":
		_build_sheet.call_deferred()


func _on_scrim_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed):
		_close_options()


## Arma una hoja inferior vacía, con su título y su botón de cerrar, y devuelve la caja donde va el contenido.
## Si el contenido no cabe en la pantalla, se desplaza.
func _sheet(heading_text: String) -> VBoxContainer:
	# Al rehacer la hoja (tras cambiar un ajuste), se queda en la misma altura en la que estaba.
	var scroll_at := 0
	if overlay != null and is_instance_valid(overlay) and overlay.visible and sheet_scroll != null and is_instance_valid(sheet_scroll):
		scroll_at = sheet_scroll.scroll_vertical
	if overlay != null and is_instance_valid(overlay):
		overlay.visible = false
		overlay.queue_free()
	if sheet_kind == "":
		overlay = null
		return null
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var scrim := ColorRect.new()
	scrim.color = _c("scrim")
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.gui_input.connect(_on_scrim_input)
	overlay.add_child(scrim)

	var sheet := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = _c("surface")
	sb.corner_radius_top_left = 60
	sb.corner_radius_top_right = 60
	sb.content_margin_left = 44.0
	sb.content_margin_right = 30.0
	sb.content_margin_top = 20.0
	sb.content_margin_bottom = 44.0 + _insets().y
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.3)
	sb.shadow_size = 40
	sheet.add_theme_stylebox_override("panel", sb)
	sheet.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	sheet.grow_vertical = Control.GROW_DIRECTION_BEGIN
	overlay.add_child(sheet)

	var frame := VBoxContainer.new()
	frame.add_theme_constant_override("separation", 14)
	sheet.add_child(frame)
	var grab_row := CenterContainer.new()
	var grab := Panel.new()
	grab.custom_minimum_size = Vector2(92.0, 9.0)
	var grab_style := StyleBoxFlat.new()
	grab_style.bg_color = _c("track")
	grab_style.set_corner_radius_all(5)
	grab.add_theme_stylebox_override("panel", grab_style)
	grab_row.add_child(grab)
	frame.add_child(grab_row)

	var header_pad := _pad(0, 0, 14, 0)
	var header := HBoxContainer.new()
	var heading := _text(heading_text, F_TITLE2, _c("ink"), font_display)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(heading)
	header.add_child(_round_button("close", _close_options, 100.0, _c("field"), _c("ink"), false))
	header_pad.add_child(header)
	frame.add_child(header_pad)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(scroll)
	sheet_scroll = scroll
	var box_pad := _pad(0, 0, 14, 0)
	box_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box_pad)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box_pad.add_child(box)
	# La hoja mide lo que su contenido, hasta dejar a la vista un poco de la pantalla de detrás.
	var fit := _fit_sheet.bind(scroll, box)
	box.minimum_size_changed.connect(fit)
	fit.call_deferred()
	if scroll_at > 0:
		_restore_scroll(scroll, scroll_at)
	return box


## Devuelve una lista a la altura en la que estaba, cuando su contenido ya tiene medida.
func _restore_scroll(scroll: ScrollContainer, at: int) -> void:
	for i in 3:
		await get_tree().process_frame
		if not is_instance_valid(scroll):
			return
		scroll.scroll_vertical = at


func _fit_sheet(scroll: ScrollContainer, box: VBoxContainer) -> void:
	if not is_instance_valid(scroll) or not is_instance_valid(box):
		return
	var room := get_viewport_rect().size.y - 330.0 - _insets().x - _insets().y
	var want := clampf(box.get_combined_minimum_size().y, 80.0, maxf(room, 240.0))
	if absf(scroll.custom_minimum_size.y - want) > 0.5:
		scroll.custom_minimum_size = Vector2(0.0, want)


func _build_sheet() -> void:
	var box := _sheet("Opciones")
	if box == null:
		return
	if use_settings:
		var home_tint := _tint("peach")
		box.add_child(_button("home", "Inicio", _open_home, home_tint[0], home_tint[1], {"font_size": F_SUB, "height": 112.0, "icon": 56.0}))
	box.add_child(_caption("Idioma"))
	box.add_child(_language_row())
	if KIDS_ENABLED and not course.is_empty():
		box.add_child(_switch_row("party", "butter", "Modo Kids", "Desde 8 años: solo el curso, con frases muy sencillas y voz. Para salir hace falta un adulto.", kids, _set_kids))
		if kids:
			box.add_child(_switch_row("sound", "sky", "Voz", "Lee en voz alta las lecciones y lo que pasa en cada jugada.", voice_on, _set_voice))
			box.add_child(_switch_row("party", "rose", "Música", "Una melodía infantil de fondo, en bucle. Baja sola cuando habla la voz.", music_on, _set_music))
	# «Mi nivel y mi plan», «Jugar una partida» y «Aprende desde cero» están en el inicio: aquí solo opciones.
	if not kids:
		box.add_child(_caption("Partidas con reloj"))
		box.add_child(_switch_row("clock", "peach", "Pulsar el reloj", "Después de cada jugada, pulsa el reloj para que empiece a pensar el rival, como en una partida de verdad.", press_clock, _set_press_clock))
		if press_clock:
			box.add_child(_switch_row("bulb", "butter", "Aviso si no lo pulsas", Loc.f("A los %d segundos sin pulsarlo, te lo recuerda (y vibra). Tu tiempo sigue corriendo.", int(PRESS_REMINDER)), press_reminder, _set_press_reminder))
	if not kids:
		_premium_rows(box)
	if kids:
		box.add_child(_caption("Mundo de las partidas"))
		box.add_child(_world_tiles())
	box.add_child(_caption("Piezas"))
	box.add_child(_picture_tiles([["piece_knight", "Figuras"], ["token_pawn", "Fichas"], ["piece_rook", "Simple"]], SETS.find(piece_set), _set_pieces_index))
	box.add_child(_caption("Material"))
	box.add_child(_swatch_tiles(STYLES.find(board_style)))
	box.add_child(_switch_row("outline", "lilac", "Contorno de las piezas", "Una línea de tinta alrededor de cada pieza.", board_outline, _set_outline))
	box.add_child(_switch_row("sound", "mint", "Sonido", "Piezas, jaque y caída del rey; aciertos, errores y final de lección.", sound_on, _set_sound))
	box.add_child(_caption("Animaciones"))
	box.add_child(_segments(["Completas", "Rápidas", "Mínimas", "Sin"], int(view.board.anim_mode), _set_anim, ["film", "skip", "step", "close"], true))
	box.add_child(_caption("Vista"))
	if view.board.is_simple():
		box.add_child(_para("Con las piezas «Simple», el tablero se ve siempre desde arriba: solo se puede ampliar con dos dedos.", F_SUB, _c("quiet"), font_regular))
	else:
		box.add_child(_segments(["Inclinada", "En picado"], 1 if top_view else 0, _set_top_view, ["view", "eye"]))
		box.add_child(_switch_row("pin", "peach", "Fijar el giro", "El tablero no gira con los dedos ni con el móvil. Ampliar sigue funcionando.", view.view_locked, _set_lock))
		box.add_child(_switch_row("zoom", "sky", "Pista de gestos", "Recuerda, sobre el tablero, que se puede ampliar y girar con dos dedos.", gesture_hint, _set_gesture_hint))
		box.add_child(_switch_row("phone", "butter", "Seguir al móvil", "La vista acompaña la inclinación y el giro del teléfono.", view.tilt_enabled, _set_tilt))
	box.add_child(_caption("Tema"))
	box.add_child(_segments(["Claro", "Oscuro"], 1 if dark else 0, _set_theme_index, ["sun", "moon"]))
	box.add_child(_caption("Intro"))
	box.add_child(_segments(INTRO_NAMES, INTRO_MODES.find(intro_mode), _set_intro_mode))
	if not kids:
		box.add_child(_caption("Pantalla de inicio"))
		box.add_child(_segments(HomeScreens.NAMES, maxi(HomeScreens.STYLES.find(home_style), 0), _set_home_style, ["rows", "tiles"]))
	var tint := _tint("lilac")
	var how := _button("book", "Cómo se usa A Chess Way", _open_welcome, tint[0], tint[1], {"font_size": F_SUB, "height": 112.0, "icon": 54.0})
	var how_pad := _pad(0, 18, 0, 0)
	how_pad.add_child(how)
	box.add_child(how_pad)
	var licences := _button("info", "Licencias", _open_licences, _c("field"), _c("ink"), {"font_size": F_SUB, "height": 104.0, "icon": 50.0})
	box.add_child(licences)
	var about := _para(Loc.f("A Chess Way · %s", app_version), F_CAP, _c("quiet"), font_regular)
	about.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(about)


## Licencias del software de terceros que va dentro de la app. Stockfish (GPL v3): el aviso de copyright, la
## licencia entera (data/licencias/gpl-3.0.txt) y dónde está el código de la versión exacta que lleva la app
## (sf_19, sin cambios). Ver android_motor/LEEME.md.
const STOCKFISH_SOURCE := "https://github.com/official-stockfish/Stockfish/tree/sf_19"
const LICENCE_FILE := "res://data/licencias/gpl-3.0.txt"


func _open_licences() -> void:
	var column := _popup("Licencias", "")
	column.add_child(_para("Stockfish 19", F_BODY, _c("ink"), font_semibold))
	column.add_child(_para("Copyright (C) 2004-2026 The Stockfish developers (see AUTHORS file)", F_SUB, _c("ink"), font_regular))
	column.add_child(_para("La app lleva Stockfish 19 sin cambios para analizar las jugadas en el móvil. Stockfish es software libre: se puede redistribuir y modificar según la Licencia Pública General de GNU, versión 3 o posterior. Se distribuye SIN NINGUNA GARANTÍA.", F_SUB, _c("quiet"), font_regular))
	var tint := _tint("sky")
	var btn := {"font_size": F_SUB, "height": 96.0, "icon": 46.0, "radius": 48}
	column.add_child(_button("open", "Código fuente de Stockfish 19", func() -> void: OS.shell_open(STOCKFISH_SOURCE), tint[0], tint[1], btn))
	column.add_child(_button("book", "Texto de la licencia (GPL v3)", _open_licence_text, tint[0], tint[1], btn))
	# Campeonato: fotos hechas con IA y sonidos de terceros (tools/campeonato/sonidos.sh). Los de BudgetPixel son
	# CC BY 4.0: hay que citarlos así.
	column.add_child(_para("Campeonato", F_BODY, _c("ink"), font_semibold))
	column.add_child(_para("Fotos de las salas y de los rivales (personas inventadas) hechas con IA: FLUX.2 [dev] de Black Forest Labs, en Cloudflare Workers AI.", F_SUB, _c("quiet"), font_regular))
	column.add_child(_para("Murmullo y aplausos: BigSoundBank.com, de Joseph Sardin (CC0, dominio público).", F_SUB, _c("quiet"), font_regular))
	column.add_child(_para("«Impressed Crowd Ooh», «Collective Crowd Gasp», «Surprised Crowd Gasp» y «Near Miss Crowd Aww», de BudgetPixel AI (budgetpixel.com/sfx), con licencia CC BY 4.0.", F_SUB, _c("quiet"), font_regular))
	column.add_child(_button("check", "Entendido", _close_confirm, _c("field"), _c("ink"), btn))


func _open_licence_text() -> void:
	var column := _popup("GNU GPL v3", "")
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0.0, 1100.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var text := Label.new()
	text.text = FileAccess.get_file_as_string(LICENCE_FILE)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override("font_size", F_CAP)
	text.add_theme_color_override("font_color", _c("ink"))
	scroll.add_child(text)
	column.add_child(scroll)
	column.add_child(_button("check", "Entendido", _close_confirm, _c("field"), _c("ink"), {"font_size": F_SUB, "height": 96.0, "icon": 46.0, "radius": 48}))


func _caption(text: String) -> MarginContainer:
	var m := _pad(4, 18, 0, 0)
	m.add_child(_text(Loc.t(text).to_upper(), F_CAP, _c("quiet"), font_semibold))
	return m


## Estilo de una opción de elegir una entre varias: la elegida, en el tono de acento y con su borde.
func _choice_colors(chosen: bool) -> Array:
	if chosen:
		return [_c("accent_soft"), _c("accent_text"), _c("accent")]
	return [_c("field"), _c("quiet"), Color(0, 0, 0, 0)]


## Fila de botones en la que solo uno está elegido. Con iconos, cada botón lleva el suyo delante.
func _segments(names: Array, selected: int, on_pick: Callable, icons: Array = [], stacked: bool = false) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	for i in names.size():
		var colors := _choice_colors(i == selected)
		var b := _button(str(icons[i]) if i < icons.size() else "", str(names[i]), on_pick.bind(i), colors[0], colors[1], {"font_size": F_FOOT, "height": 150.0 if stacked else 108.0, "icon": 48.0, "pad_x": 12.0, "vertical": stacked, "border": colors[2], "font": font_semibold if i == selected else font_medium})
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	return row


## Teselas con un dibujo grande y su nombre: para elegir entre figuras y fichas.
func _picture_tiles(defs: Array, selected: int, on_pick: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	for i in defs.size():
		var def: Array = defs[i]
		var colors := _choice_colors(i == selected)
		var b := _button(str(def[0]), str(def[1]), on_pick.bind(i), colors[0], colors[1], {"vertical": true, "font_size": F_SUB, "height": 214.0, "icon": 104.0, "radius": 44, "border": colors[2], "font": font_semibold if i == selected else font_medium})
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	return row


## Teselas de los acabados: cada una enseña sus dos colores de pieza.
func _swatch_tiles(selected: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	for i in STYLES.size():
		var colors := _choice_colors(i == selected)
		var b := _button("", str(STYLE_NAMES[i]), _set_style_index.bind(i), colors[0], colors[1], {"vertical": true, "font_size": F_FOOT, "height": 178.0, "radius": 40, "pad_x": 6.0, "border": colors[2], "font": font_semibold if i == selected else font_medium})
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var mark := SwatchMark.new()
		var swatch: Array = [Color("f8f0e0"), Color("2a3557")]
		if Board3D.FINISHES.has(STYLES[i]):
			swatch = Board3D.FINISHES[STYLES[i]]["swatch"]
		mark.light = swatch[0]
		mark.dark = swatch[1]
		mark.custom_minimum_size = Vector2(120.0, 76.0)
		mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var inner := b.get_child(0)
		inner.add_child(mark)
		inner.move_child(mark, 0)
		row.add_child(b)
	return row


func _switch_row(icon_name: String, tint_name: String, label: String, hint: String, value: bool, on_change: Callable) -> MarginContainer:
	var row := _icon_row(icon_name, tint_name, label, hint, 96.0)
	var sw := Switch.new()
	sw.on = value
	sw.on_color = _c("accent")
	sw.off_color = _c("track")
	sw.knob_color = Color.WHITE
	sw.custom_minimum_size = Vector2(124.0, 72.0)
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sw.focus_mode = Control.FOCUS_NONE
	sw.mouse_filter = Control.MOUSE_FILTER_PASS
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		sw.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	sw.pressed.connect(on_change.bind(not value))
	row.add_child(sw)
	var spaced := _pad(0, 10, 0, 10)
	spaced.add_child(row)
	return spaced


func _set_pieces_index(i: int) -> void:
	piece_set = SETS[clampi(i, 0, SETS.size() - 1)]
	_sync_piece_set()
	_save_settings()
	_sync_sheet()


## Juego de piezas que toca enseñar: en una partida Kids, el mundo elegido; si no, el del jugador.
func _shown_set() -> String:
	if kids and kids_world != "" and mode == "game":
		return kids_world
	return piece_set


func _sync_piece_set() -> void:
	if view == null:
		return
	view.set_piece_set(_shown_set())
	_apply_simple_view()


## Teselas de los mundos Kids: dos filas, cada una con el rey de su mundo.
func _world_tiles() -> VBoxContainer:
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 12)
	var row: HBoxContainer = null
	for i in WORLDS.size():
		if i % 4 == 0:
			row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 12)
			rows.add_child(row)
		var colors := _choice_colors(WORLDS[i] == kids_world)
		var b := _button("piece_king" if i == 0 else ("piece_knight" if WORLDS[i] == "aventura" else ""), str(WORLD_NAMES[i]), _set_world.bind(i), colors[0], colors[1], {"vertical": true, "font_size": F_SUB, "height": 200.0, "icon": 96.0, "radius": 44, "border": colors[2], "font": font_semibold if WORLDS[i] == kids_world else font_medium})
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if i > 0 and Board3D.FLAT_ATLAS.has(WORLDS[i]):
			var pic := TextureRect.new()
			pic.texture = _world_picture(WORLDS[i])
			pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			pic.custom_minimum_size = Vector2(104.0, 104.0)
			pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var inner := b.get_child(0)
			inner.add_child(pic)
			inner.move_child(pic, 0)
		row.add_child(b)
	return rows


var _world_pics := {}


## El rey blanco de un mundo, recortado de su atlas.
func _world_picture(world: String) -> Texture2D:
	if not _world_pics.has(world):
		var bytes := FileAccess.get_file_as_bytes(str(Board3D.FLAT_ATLAS[world]))
		var img := Image.new()
		if bytes.is_empty() or img.load_png_from_buffer(bytes) != OK:
			return null
		var cell := img.get_height() / 2
		var region := img.get_region(Rect2i(cell * 5, 0, cell, cell))
		region.generate_mipmaps()
		_world_pics[world] = ImageTexture.create_from_image(region)
	return _world_pics[world]


func _set_world(i: int) -> void:
	kids_world = WORLDS[clampi(i, 0, WORLDS.size() - 1)]
	_sync_piece_set()
	_save_settings()
	if sheet_kind != "":
		_sync_sheet()
	else:
		_game_options_changed()


## «Simple» es el tablero plano visto desde arriba: solo se amplía, no se gira ni se inclina. Al salir de él, el
## giro vuelve a como lo tenía el jugador.
var _flat_view := false


func _apply_simple_view() -> void:
	if pin_button != null and is_instance_valid(pin_button):
		pin_button.visible = not view.board.is_simple()
	if view.board.is_simple():
		view.set_tilt_enabled(false)
		view.set_view_locked(true)
		top_view = true
		view.center_view()
		_flat_view = false
	elif view.board.is_standee() or view.board.is_rigged():
		# Mundos Kids: el tablero se inclina para que los personajes se pongan de pie. Se puede seguir cambiando
		# la vista con su botón; la preferencia del jugador no se toca.
		view.set_view_locked(_saved_lock)
		if not _flat_view:
			view.default_view()
		_flat_view = true
	else:
		view.set_view_locked(_saved_lock)
		# Al salir de un mundo Kids, la vista vuelve a la que tenía el jugador.
		if _flat_view and top_view:
			view.center_view()
		_flat_view = false


func _set_style_index(i: int) -> void:
	board_style = STYLES[clampi(i, 0, STYLES.size() - 1)]
	# El contorno no cambia con el acabado: se queda como lo tenga el jugador (puesto, por defecto).
	view.set_board_style(board_style, board_outline)
	_save_settings()
	_keep_scroll = true
	_refresh(false)
	_sync_sheet()


func _set_outline(on: bool) -> void:
	board_outline = on
	view.board.set_outline(on)
	_save_settings()
	_sync_sheet()


func _set_press_clock(on: bool) -> void:
	press_clock = on
	_save_settings()
	_sync_sheet()
	# Si se quita a mitad de una jugada sin pulsar, se pulsa solo.
	if not on and mode == "game" and game_state == "press":
		_press_game_clock()


func _set_press_reminder(on: bool) -> void:
	press_reminder = on
	_save_settings()
	_sync_sheet()


func _set_sound(on: bool) -> void:
	sound_on = on
	view.set_sound_enabled(on)
	_sync_music()
	_save_settings()
	_sync_sheet()


func _set_anim(mode: int) -> void:
	view.board.anim_mode = mode as Board3D.Anim
	_saved_anim = mode
	_anim_chosen = true
	_save_settings()
	_sync_sheet()


func _set_top_view(i: int) -> void:
	if view.board.is_simple():
		return
	top_view = i == 1
	_save_settings()
	if top_view:
		view.center_view()
	else:
		view.default_view()
	_sync_sheet()


## Botón de vista: si el tablero está ampliado, lo devuelve a su tamaño; si no, cambia entre inclinada y en picado.
func _on_toggle_view() -> void:
	if view.is_zoomed():
		view.reset_zoom()
		return
	if view.board.is_simple():
		return
	_set_top_view(0 if top_view else 1)


func _set_tilt(on: bool) -> void:
	if view.board.is_simple():
		return
	view.set_tilt_enabled(on)
	if on and view.view_locked:
		_set_lock(false)
		return
	_sync_sheet()


func _set_lock(on: bool) -> void:
	if view.board.is_simple():
		return
	_saved_lock = on
	view.set_view_locked(on)
	_save_settings()
	# La chincheta de la barra cambia de aspecto: se pone una nueva en su sitio.
	if pin_button != null and is_instance_valid(pin_button):
		var bar := pin_button.get_parent()
		var at := pin_button.get_index()
		var fresh := _pin_button()
		pin_button.visible = false
		pin_button.queue_free()
		bar.add_child(fresh)
		bar.move_child(fresh, at)
		pin_button = fresh
	_place_tip()
	_sync_sheet()


func _set_gesture_hint(on: bool) -> void:
	gesture_hint = on
	_save_settings()
	_place_tip()
	_sync_sheet()


func _set_theme_index(i: int) -> void:
	_set_dark(i == 1)


# ---------------------------------------------------------------- idiomas

## Tablerito con los colores de la bandera del idioma, arriba a la derecha del inicio: abre la hoja de idiomas.
func _flag_button() -> Button:
	var side := 132.0
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	b.custom_minimum_size = Vector2(side, side)
	b.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	var top := maxf(_insets().x, 60.0) + 24.0
	b.offset_right = -40.0
	b.offset_left = -40.0 - side
	b.offset_top = top
	b.offset_bottom = top + side
	b.tooltip_text = Loc.NAMES.get(language, "")
	var board := LangBoard.new()
	board.code = language
	board.set_anchors_preset(Control.PRESET_FULL_RECT)
	board.offset_left = 10.0
	board.offset_top = 10.0
	board.offset_right = -10.0
	board.offset_bottom = -10.0
	b.add_child(board)
	b.pressed.connect(_open_language_dialog)
	return b


## Ventana emergente con los diez idiomas, centrada sobre un fondo semitransparente. Tocar fuera la cierra.
var lang_dialog: Control


func _open_language_dialog() -> void:
	_close_language_dialog()
	_lang_from_options = false
	lang_dialog = Control.new()
	lang_dialog.set_anchors_preset(Control.PRESET_FULL_RECT)
	lang_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(lang_dialog)
	var scrim := ColorRect.new()
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0.03, 0.05, 0.14, 0.42 if dark else 0.3)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventMouseButton and (e as InputEventMouseButton).pressed) or (e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed):
			_close_language_dialog())
	lang_dialog.add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lang_dialog.add_child(center)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	var paper := _c("surface")
	sb.bg_color = Color(paper.r, paper.g, paper.b, 0.975)
	sb.set_corner_radius_all(64)
	sb.shadow_color = _c("shadow")
	sb.shadow_size = 36
	sb.shadow_offset = Vector2(0.0, 14.0)
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.custom_minimum_size = Vector2(minf(size.x - 100.0, 900.0), 0.0)
	center.add_child(panel)
	var pad := _pad(44, 36, 44, 44)
	panel.add_child(pad)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 20)
	pad.add_child(column)

	var header := HBoxContainer.new()
	var heading := _para("Idioma", F_TITLE, _c("ink"), font_display)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(heading)
	header.add_child(_round_button("close", _close_language_dialog, 100.0, _c("field"), _c("ink"), false))
	column.add_child(header)

	# Si el móvil es bajo, la lista se desplaza dentro de la ventana.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0.0, minf(1180.0, maxf(size.y - 560.0, 600.0)))
	column.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	for code: String in Loc.LANGUAGES:
		var chosen := code == language
		var colors := _choice_colors(chosen)
		var b := _button("", str(Loc.NAMES[code]), _pick_language_dialog.bind(code), colors[0], colors[1], {"vertical": true, "font_size": F_SUB, "height": 214.0, "radius": 44, "border": colors[2], "font": font_semibold if chosen else font_medium})
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# El nombre del idioma no se traduce: cada uno se ve en su idioma.
		for l in b.find_children("*", "Label", true, false):
			(l as Label).auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		var mark := LangBoard.new()
		mark.code = code
		mark.custom_minimum_size = Vector2(108.0, 108.0)
		mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var inner := b.get_child(0)
		inner.add_child(mark)
		inner.move_child(mark, 0)
		grid.add_child(b)

	panel.pivot_offset = panel.get_combined_minimum_size() * 0.5
	panel.scale = Vector2(0.92, 0.92)
	lang_dialog.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(panel, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lang_dialog, "modulate:a", 1.0, 0.15)


func _close_language_dialog() -> void:
	if lang_dialog != null and is_instance_valid(lang_dialog):
		if not lang_asked:
			lang_asked = true
			if use_settings:
				_save_settings()
		lang_dialog.visible = false
		lang_dialog.queue_free()
	lang_dialog = null


func _pick_language_dialog(code: String) -> void:
	_close_language_dialog()
	_set_language(code)


## Fila de Opciones con el idioma actual: su tablerito y su nombre. Abre la hoja de idiomas.
func _language_row() -> Button:
	var b := _button("", str(Loc.NAMES.get(language, language)), _open_language.bind(true), _c("field"), _c("ink"), {"font_size": F_BODY, "height": 120.0, "font": font_semibold})
	var mark := LangBoard.new()
	mark.code = language
	mark.custom_minimum_size = Vector2(80.0, 80.0)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var inner := b.get_child(0)
	inner.add_child(mark)
	inner.move_child(mark, 0)
	return b


func _open_language(from_options: bool) -> void:
	_lang_from_options = from_options
	options_open = from_options
	sheet_kind = "language"
	_build_language_sheet()
	if not from_options:
		overlay.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(overlay, "modulate:a", 1.0, 0.14)


## Hoja con los diez idiomas, de dos en dos: tablerito con su bandera y el nombre en su propio idioma.
func _build_language_sheet() -> void:
	var box := _sheet("Idioma")
	if box == null:
		return
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for code: String in Loc.LANGUAGES:
		var chosen := code == language
		var colors := _choice_colors(chosen)
		var b := _button("", str(Loc.NAMES[code]), _set_language.bind(code), colors[0], colors[1], {"vertical": true, "font_size": F_SUB, "height": 220.0, "radius": 44, "border": colors[2], "font": font_semibold if chosen else font_medium})
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# El nombre del idioma no se traduce: cada uno se ve en su idioma.
		for l in b.find_children("*", "Label", true, false):
			(l as Label).auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		var mark := LangBoard.new()
		mark.code = code
		mark.custom_minimum_size = Vector2(112.0, 112.0)
		mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var inner := b.get_child(0)
		inner.add_child(mark)
		inner.move_child(mark, 0)
		grid.add_child(b)
	box.add_child(grid)
	if _lang_from_options:
		var back_tint := _tint("sky")
		box.add_child(_button("sliders", "Opciones", _open_options, back_tint[0], back_tint[1], {"font_size": F_SUB, "height": 108.0, "icon": 52.0}))


## Cambia el idioma: se guarda y se rehace la pantalla (como al cambiar de tema).
func _set_language(code: String) -> void:
	if not code in Loc.LANGUAGES:
		return
	var changed := code != language
	language = code
	if changed:
		Loc.apply(language)
		_save_settings()
	if _lang_from_options:
		sheet_kind = "options"
		options_open = true
	else:
		sheet_kind = ""
		options_open = false
		if overlay != null and is_instance_valid(overlay):
			overlay.visible = false
			overlay.queue_free()
		overlay = null
	if changed:
		_keep_scroll = true
		_build_chrome.call_deferred()
		if welcome != null and is_instance_valid(welcome):
			_open_welcome.call_deferred()
	elif sheet_kind == "options":
		_build_sheet()


func _set_dark(on: bool) -> void:
	if dark == on:
		return
	dark = on
	_save_settings()
	_keep_scroll = true
	_build_chrome.call_deferred()


# ---------------------------------------------------------------- bienvenida

## Pantalla de bienvenida: qué es A Chess Way y cómo se usa. Sale la primera vez y desde Opciones.
## Emblema, nombre y cuatro ideas con su icono grande; el botón, siempre a la vista al pie.
func _open_welcome() -> void:
	if sheet_kind != "":
		_close_options()
	if welcome != null and is_instance_valid(welcome):
		welcome.queue_free()
	welcome = Control.new()
	welcome.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(welcome)
	var back := PastelBackdrop.new()
	back.top = _c("wash_top")
	back.mid = _c("wash_mid")
	back.bottom = _c("wash_bottom")
	var glow := 0.5 if not dark else 0.22
	var rose: Color = _tint("rose")[0]
	var sky: Color = _tint("sky")[0]
	var butter: Color = _tint("butter")[0]
	back.blobs = [
		[Vector2(0.95, 0.1), 0.62, Color(rose.r, rose.g, rose.b, glow)],
		[Vector2(0.02, 0.34), 0.5, Color(sky.r, sky.g, sky.b, glow)],
		[Vector2(0.9, 0.78), 0.56, Color(butter.r, butter.g, butter.b, glow * 0.9)],
	]
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_STOP
	welcome.add_child(back)
	var inset := _insets()
	var pad := _pad(60, int(maxf(inset.x, 60.0)) + 20, 60, int(inset.y) + 44)
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	welcome.add_child(pad)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	pad.add_child(column)

	# Lo de arriba se desplaza si el móvil es bajo; el botón no se mueve.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 0)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)

	body.add_child(_spacer(10.0, true))
	# El logo de la app: el caballo marfil en 3D sobre la tesela naranja (el mismo icono que el del móvil).
	var emblem := HomeScreens._icon_mark(340.0)
	emblem.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(emblem)
	body.add_child(_spacer(26.0))
	var name_label := _para("A Chess Way", F_LARGE, _c("ink"), font_display)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(name_label)
	body.add_child(_spacer(6.0))
	var claim := _para("Aprende ajedrez\nentendiendo cada jugada.", F_HEAD + 4, _c("quiet"), font_medium)
	claim.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(claim)
	body.add_child(_spacer(54.0, true))
	var rows := [
		["book", "peach", "Desde cero", "Si nunca has jugado, empieza por lecciones cortas."],
		["bulb", "butter", "Si fallas, te lo explico", "Verás qué pasaría y podrás volver a intentarlo."],
		["why", "lilac", "Pregunta «por qué»", "Cada solución, explicada paso a paso."],
		["sliders", "mint", "A tu gusto", "Figuras o fichas, materiales, sonido y animaciones."],
	]
	for i in rows.size():
		var def: Array = rows[i]
		if i > 0:
			body.add_child(_spacer(42.0))
		body.add_child(_welcome_row(str(def[0]), str(def[1]), str(def[2]), str(def[3])))
	body.add_child(_spacer(20.0, true))

	column.add_child(_spacer(26.0))
	var go := _button("next", "Empezar", _close_welcome, _c("accent"), _c("accent_ink"), {"font_size": F_HEAD, "height": 148.0, "icon": 60.0, "trailing": true, "glow": _c("glow")})
	go.mouse_filter = Control.MOUSE_FILTER_STOP
	column.add_child(go)
	if KIDS_ENABLED and not kids and not course.is_empty():
		column.add_child(_spacer(18.0))
		var tint := _tint("butter")
		var kid := _button("party", "Modo Kids · desde 8 años", _start_kids, tint[0], _c("ink"), {"font_size": F_SUB, "height": 112.0, "icon": 56.0, "icon_color": tint[1]})
		kid.mouse_filter = Control.MOUSE_FILTER_STOP
		column.add_child(kid)
	# La bandera va la última para quedar por encima del contenedor de la pantalla, que si no se come el toque.
	welcome.add_child(_flag_button())
	_place_tip()


## Una idea de la bienvenida: tesela pastel con un icono grande, titular y una línea de texto.
func _welcome_row(icon_name: String, tint_name: String, heading: String, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 34)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tile := _icon_tile(icon_name, tint_name, 152.0, 94.0)
	tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(tile)
	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", 2)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(_para(heading, F_HEAD + 6, _c("ink"), font_semibold))
	texts.add_child(_para(text, F_BODY, _c("quiet"), font_regular))
	row.add_child(texts)
	return row


func _close_welcome() -> void:
	if welcome != null and is_instance_valid(welcome):
		welcome.visible = false
		welcome.queue_free()
	welcome = null
	if not welcome_seen:
		welcome_seen = true
		_save_settings()
	_place_tip()
	# Primera vez: tras la bienvenida, la pregunta de experiencia y el test de nivel.
	if use_settings and not _has_player() and progress == null:
		_open_experience()


# ---------------------------------------------------------------- problema

func _wait(seconds: float) -> Signal:
	return get_tree().create_timer(seconds).timeout


## Punto de decisión en el que está el jugador (0 = su primera jugada).
func _point() -> int:
	return maxi(ask_step - 1, 0) >> 1


func _explanation_for(k: int, uci: String) -> Dictionary:
	if explain == null or not explain.ok:
		return {}
	return explain.for_move(k, uci)


## Vuelve a la posición en la que se pidió la jugada, con la del rival resaltada.
func _restore_position() -> void:
	view.set_fen(fen_before)
	var moves: Array = puzzle.get("moves", [])
	if ask_step >= 1 and ask_step - 1 < moves.size():
		var rival := str(moves[ask_step - 1])
		view.board.mark_last_move(Chess.sq_index(rival.substr(0, 2)), Chess.sq_index(rival.substr(2, 2)))


func _clear_explanation() -> void:
	expl = {}
	exp_level = 1
	exp_point = 0
	exp_partial = false
	whatif = false
	whatif_exp = {}
	whatif_level = 1
	facts_open = false
	line_on = {}
	line_ply = -1


func _start(i: int, review: bool = false) -> void:
	run_id += 1
	var my_run := run_id
	is_review = review
	if puzzles.is_empty():
		_refresh()
		return
	index = posmod(i, puzzles.size())
	puzzle = puzzles[index]
	explain = ExplainData.load_for(str(puzzle.get("id", "")))
	_clear_explanation()
	_gap_limit = INF
	last_wrong = {}
	hint_level = 0
	step_fen = ""
	step = 0
	ask_step = 0
	_rating_shown = []
	_try = {}
	view.board.only_square = -1
	view.board.set_goals([])
	if mode != "free" and _has_player() and index < pool.size():
		var item: Dictionary = pool[index]
		# Un problema ya anotado (al repetirlo, o en un repaso) no vuelve a mover el nivel.
		var seen := false
		for t: Dictionary in player["tries"]:
			if str(t["id"]) == str(item["id"]):
				seen = true
				break
		_try = {"item": item, "t0": 0, "ms_first": 0.0, "fail_step": -1, "error": "", "help": "", "recorded": seen}
	view.sounds.stop_all()
	view.board.set_arrows([])
	browse_back = 0
	move_why_open = false
	why_board = false
	why_story_open = false
	summary_open = false
	result_popup = false
	why_paras = []
	view.set_fen(puzzle["fen"])
	# Juega quien responde a la primera jugada (la del rival).
	view.set_orientation(1 - view.board.chess.turn)
	view.interactive = false
	intro_waiting = true
	_set_phase(Phase.INTRO)
	if auto_begin:
		await _wait(0.45)
		if my_run == run_id:
			_begin()


## «Comenzar»: el rival hace su jugada y después te toca.
func _begin() -> void:
	if phase != Phase.INTRO or not intro_waiting or puzzle.is_empty():
		return
	intro_waiting = false
	_refresh()
	var my_run := run_id
	await _wait(0.25)
	if my_run != run_id:
		return
	var moves: Array = puzzle["moves"]
	view.show_move(str(moves[0]))
	step = 1
	await _wait(0.55)
	if my_run != run_id:
		return
	_ask()


func _ask() -> void:
	browse_back = 0
	move_why_open = false
	why_board = false
	why_story_open = false
	summary_open = false
	result_popup = false
	why_paras = []
	fen_before = view.board.chess.fen()
	ask_step = step
	hint_level = 0
	# Jugada nueva: el tablero vuelve a bajar a su sitio de resolver (pudo subir para dejar sitio a una explicación).
	_gap_limit = INF
	# El reloj del intento empieza cuando el jugador puede mover por primera vez.
	if not _try.is_empty() and int(_try["t0"]) == 0:
		_try["t0"] = Time.get_ticks_msec()
	view.interactive = true
	_set_phase(Phase.SOLVING)


## «Pista»: la primera vez, el tema del problema; la segunda, además, la pieza que hay que mover (queda
## elegida en el tablero, con sus destinos a la vista). No dice la jugada.
func _on_hint() -> void:
	if mode == "test" or (phase != Phase.SOLVING and phase != Phase.WRONG):
		return
	var moves: Array = puzzle.get("moves", [])
	if ask_step < 1 or ask_step >= moves.size():
		return
	_mark_help("hint")
	if hint_level < 2:
		hint_level += 1
	if hint_level == 1 and _hint_theme() == "":
		hint_level = 2
	if hint_level >= 2:
		# La pieza se señala en la posición de la decisión: si se estaba viendo otra cosa, se vuelve a ella.
		run_id += 1
		line_on = {}
		line_ply = -1
		_restore_position()
		if phase == Phase.WRONG:
			view.board.set_arrows(_arrows_for(expl, 1, true))
		view.interactive = true
		view.board.select(Chess.sq_index(str(moves[ask_step]).substr(0, 2)))
	_keep_scroll = true
	_refresh()
	card_scroll.set_deferred("scroll_vertical", 100000)


## «Un paso»: juega solo la jugada que toca y explica por qué es esa. El resto lo sigue resolviendo el jugador.
func _on_step() -> void:
	if mode == "test" or (phase != Phase.SOLVING and phase != Phase.WRONG):
		return
	var moves: Array = puzzle.get("moves", [])
	if ask_step < 1 or ask_step >= moves.size():
		return
	_mark_help("step")
	run_id += 1
	var my_run := run_id
	var k := _point()
	var uci := str(moves[ask_step])
	view.interactive = false
	_clear_explanation()
	hint_level = 0
	view.board.set_arrows([])
	_restore_position()
	step = ask_step
	await _wait(0.25)
	if my_run != run_id:
		return
	# La posición de después del paso se calcula con las reglas, no se lee del tablero (que está animando).
	var before := Chess.from_fen(fen_before)
	var move := before.find_uci(uci)
	if move < 0:
		_ask()
		return
	var after := before.after(move)
	step_fen = after.fen()
	view.show_move(uci)
	step += 1
	if explain != null and explain.ok:
		expl = explain.for_move(k, uci)
		if not expl.is_empty():
			expl["headline"] = Loc.f("Este paso: %s", str(expl.get("san", "")))
			expl["asked"] = true
		exp_point = k
	# Si era la última jugada, el problema queda resuelto: no hay nada más que seguir.
	_set_phase(Phase.SHOWN if step >= moves.size() or after.is_checkmate() else Phase.STEP)


## «Seguir», tras «Un paso»: responde el rival y vuelve a tocarle al jugador.
func _on_continue() -> void:
	if phase != Phase.STEP:
		return
	var moves: Array = puzzle.get("moves", [])
	run_id += 1
	var my_run := run_id
	_clear_explanation()
	view.board.set_arrows([])
	view.interactive = false
	# El tablero puede estar enseñando la posición de la decisión o una variante: vuelve a la de después del paso.
	if step_fen != "":
		view.set_fen(step_fen)
		if step >= 1 and step - 1 < moves.size():
			var mine := str(moves[step - 1])
			view.board.mark_last_move(Chess.sq_index(mine.substr(0, 2)), Chess.sq_index(mine.substr(2, 2)))
	last_wrong = {}
	_set_phase(Phase.INTRO)
	await _wait(0.5)
	if my_run != run_id:
		return
	if step < moves.size():
		view.show_move(str(moves[step]))
		step += 1
	await _wait(0.5)
	if my_run != run_id:
		return
	_ask()


func _on_move_played(uci: String) -> void:
	if mode == "learn":
		_learn_move(uci)
		return
	if mode == "game":
		_game_move(uci)
		return
	var my_run := run_id
	view.board.set_arrows([])
	if whatif:
		# «¿Y si juego…?»: se explica la jugada probada y el tablero vuelve a la posición de la decisión.
		view.interactive = false
		whatif_exp = _explanation_for(exp_point, uci)
		whatif_level = 1
		facts_open = false
		_refresh()
		await _wait(0.9)
		if my_run != run_id or not whatif:
			return
		_show_decision(_arrows_for(whatif_exp, 1, false))
		return
	var moves: Array = puzzle["moves"]
	if step >= moves.size():
		return
	if not _try.is_empty() and float(_try["ms_first"]) <= 0.0 and int(_try["t0"]) > 0:
		_try["ms_first"] = maxf(1.0, float(Time.get_ticks_msec() - int(_try["t0"])))
	var mate := view.board.chess.is_checkmate()
	if uci != str(moves[step]) and not mate:
		# Fallo: se cuenta qué hace la jugada y qué permite, y se deja reintentar.
		view.interactive = false
		_sfx("error")
		var k := _point()
		last_wrong = {"point": k, "uci": uci}
		_clear_explanation()
		hint_level = 0
		expl = _explanation_for(k, uci)
		exp_point = k
		var slip := str(expl.get("error", ""))
		_move_badge(uci, "blunder" if ["mate", "hangMoved", "hangOther", "material"].has(slip) else ("dubious" if ["missed", "slower"].has(slip) else "wrong"))
		# La primera jugada equivocada decide el intento: en qué paso fue y qué clase de error.
		if not _try.is_empty() and not bool(_try["recorded"]):
			_try["fail_step"] = k
			_try["error"] = str(expl.get("error", ""))
			_record(false)
		if mode == "test":
			# En el test hay un solo intento: se explica el fallo, con la jugada buena, y se pasa al siguiente.
			exp_partial = false
			_set_phase(Phase.SHOWN)
			await _wait(0.9)
			if my_run != run_id:
				return
			_show_decision(_arrows_for(expl, 1, false))
			return
		exp_partial = true
		_set_phase(Phase.WRONG)
		_say([_kid_explain(expl, true)])
		await _wait(0.9)
		if my_run != run_id:
			return
		_restore_position()
		view.board.set_arrows(_kid_wrong_arrows(expl) if kids else _arrows_for(expl, 1, true))
		view.interactive = true
		return
	step += 1
	_move_badge(uci, "best")
	_clear_explanation()
	hint_level = 0
	if mate or step >= moves.size():
		view.interactive = false
		if explain != null and explain.ok:
			expl = explain.solved()
		# Resuelto sin fallos ni ayudas: acierto. (Si antes hubo un fallo o una ayuda, ya está anotado.)
		_record(true)
		_sfx("leccion")
		_set_phase(Phase.SOLVED)
		_say([BRAVO, _kid_explain(expl, false)])
		return
	_sfx("acierto")
	last_wrong = {}
	view.interactive = false
	_set_phase(Phase.REPLY)
	await _wait(0.55)
	if my_run != run_id:
		return
	view.show_move(str(moves[step]))
	step += 1
	await _wait(0.45)
	if my_run != run_id:
		return
	_ask()


func _show_solution() -> void:
	var moves: Array = puzzle.get("moves", [])
	if phase == Phase.INTRO or phase == Phase.SHOWING or ask_step < 1 or ask_step >= moves.size():
		return
	_mark_help("solution")
	run_id += 1
	var my_run := run_id
	var k := _point()
	view.interactive = false
	_clear_explanation()
	hint_level = 0
	view.board.set_arrows([])
	_restore_position()
	step = ask_step
	_set_phase(Phase.SHOWING)
	while step < moves.size():
		await _wait(0.75)
		if my_run != run_id:
			return
		view.show_move(str(moves[step]))
		step += 1
	# La explicación: si el jugador había fallado aquí, la de su jugada (qué permitía y cuál era la mejor);
	# si pidió la solución sin probar, la de la solución.
	if explain != null and explain.ok:
		if int(last_wrong.get("point", -1)) == k:
			expl = explain.for_move(k, str(last_wrong.get("uci", "")))
		else:
			expl = explain.solved() if k == 0 else explain.for_move(k, explain.point_solution(k))
			if not expl.is_empty():
				expl["headline"] = "La solución"
				expl["asked"] = true
		exp_point = k
	_set_phase(Phase.SHOWN)


## «Solución» mientras se resuelve; «Repetir» cuando el problema ha terminado. En el test, «No lo sé».
func _on_left() -> void:
	if mode == "test":
		_on_right()
	elif phase == Phase.SOLVED or phase == Phase.SHOWN:
		_start(index)
	else:
		_show_solution()


## «Saltar» o «Siguiente»; tras «Un paso», «Seguir». En el test: «No lo sé» mientras se resuelve y, al
## terminar cada problema, el siguiente (o el resultado, si ya hay datos suficientes).
func _on_right() -> void:
	if mode == "test":
		if phase == Phase.SOLVED or phase == Phase.SHOWN:
			if bool(player.get("done", false)):
				_finish_test()
			else:
				_next_test()
		elif phase == Phase.SOLVING:
			_give_up()
	elif phase == Phase.STEP:
		_on_continue()
	elif mode == "train":
		_next_training()
	elif not practice_queue.is_empty():
		_start(int(practice_queue.pop_front()))
	else:
		_start(index + 1)


# ---------------------------------------------------------------- test de nivel y entrenamiento

## Tablero quieto mientras se enseñan la bienvenida y la pregunta de experiencia.
func _idle() -> void:
	run_id += 1
	puzzle = {}
	explain = null
	_clear_explanation()
	_try = {}
	view.board.set_arrows([])
	view.set_fen(Board3D.START_FEN)
	view.set_orientation(0)
	view.interactive = false
	_set_phase(Phase.INTRO)


## Empieza el test de nivel desde lo que el jugador dice de su experiencia.
func _start_test(exp: String) -> void:
	experience = exp
	test_skipped = false
	reviewed = {}
	_since_review = 0
	player = Assessment.start_test(exp)
	mode = "test"
	_close_progress()
	_save_player()
	_next_test()


## Sin test (desde la pregunta de experiencia o a mitad del test): se empieza desde el nivel más bajo, con
## los problemas más fáciles, y el nivel se va afinando con cada problema. Lo ya contestado se conserva.
func _skip_test() -> void:
	experience = "never"
	test_skipped = true
	var kept: Array = player.get("tries", [])
	player = Assessment.start_test("never")
	player["tries"] = kept
	player["done"] = true
	mode = "train"
	review_session = false
	_close_progress()
	_save_player()
	_next_training()
	# Y a la pantalla de inicio, no directos a un problema (Pablo, 23 nov): desde ahí elige qué hacer.
	if use_settings:
		_open_home()


func _next_test() -> void:
	var item := Assessment.next_test_item(player, pool, _rng.randf())
	if item.is_empty():
		player["done"] = true
		_finish_test()
		return
	_start(int(_index_of[item["id"]]))


## El test ha terminado: se enseña el resultado. Detrás queda el modo de entrenamiento.
func _finish_test() -> void:
	mode = "train"
	_save_player()
	_open_progress("result")


## Siguiente problema del entrenamiento: según el nivel y los puntos flojos; agotados los nuevos, un repaso.
func _next_training() -> void:
	if review_session:
		_review_session_next(_pending_fails())
		return
	# Práctica pedida desde el análisis de una partida: esos problemas primero.
	if not practice_queue.is_empty():
		_start(int(practice_queue.pop_front()))
		return
	if pool.is_empty() or not _has_player():
		_start(index + 1)
		return
	# Repaso de un nivel superado: sus problemas, primero los que no ha visto.
	if train_level >= 0:
		var of_level: Array = pool.filter(func(p: Dictionary) -> bool: return Assessment.level_of(float(p["rating"])) == train_level)
		if not of_level.is_empty():
			var seen_ids := {}
			for t: Dictionary in player["tries"]:
				seen_ids[str(t["id"])] = true
			var fresh: Array = of_level.filter(func(p: Dictionary) -> bool: return not seen_ids.has(str(p["id"])))
			var from_level: Array = fresh if not fresh.is_empty() else of_level
			if from_level.size() > 1 and index >= 0 and index < pool.size():
				var now_id := str(pool[index]["id"])
				from_level = from_level.filter(func(p: Dictionary) -> bool: return str(p["id"]) != now_id)
			var picked: Dictionary = from_level[_rng.randi_range(0, from_level.size() - 1)]
			_start(int(_index_of[picked["id"]]))
			return
	# Cada pocos problemas, un repaso de un fallo anterior; si no toca o no hay, un problema nuevo.
	var due := _due_review()
	if not due.is_empty():
		_since_review = 0
		_start(int(_index_of[due["id"]]), true)
		return
	_since_review += 1
	var from: Array = pool
	if train_family != "":
		from = pool.filter(func(p: Dictionary) -> bool: return str(p.get("family", "")) == train_family)
		if from.is_empty():
			from = pool
	var item := Assessment.pick_training_item(player["rating"], player["tries"], from, _rng.randf())
	if item.is_empty():
		item = Assessment.pick_review_item(player["tries"], from)
	if item.is_empty():
		item = Assessment.pick_review_item(player["tries"], pool)
	_start(int(_index_of[item["id"]]))


## Problema que toca repasar ({} si ninguno): el fallo más antiguo que no se ha repasado, cuando han pasado
## al menos REVIEW_EVERY problemas nuevos desde el último repaso y REVIEW_GAP problemas desde ese fallo.
func _due_review() -> Dictionary:
	if _since_review < REVIEW_EVERY or not _has_player():
		return {}
	var tries: Array = player["tries"]
	var solved := {}
	for t: Dictionary in tries:
		if bool(t["correct"]):
			solved[str(t["id"])] = true
	for i in tries.size():
		var t: Dictionary = tries[i]
		var id := str(t["id"])
		if bool(t["correct"]) or solved.has(id) or reviewed.has(id) or not _index_of.has(id):
			continue
		if tries.size() - i < REVIEW_GAP:
			break
		return pool[int(_index_of[id])]
	return {}


## Anota el intento en curso (una sola vez por problema): mueve el nivel y lo guarda.
func _record(correct: bool) -> void:
	if mode == "free" or _try.is_empty() or bool(_try.get("recorded", true)) or not _has_player():
		return
	_try["recorded"] = true
	var t0 := int(_try["t0"])
	var outcome := {
		"correct": correct,
		"failStep": int(_try["fail_step"]),
		"error": str(_try["error"]),
		"help": str(_try["help"]),
		"msFirst": float(_try["ms_first"]),
		"ms": float(Time.get_ticks_msec() - t0) if t0 > 0 else 0.0,
	}
	var before := float(player["rating"]["r"])
	player = Assessment.record_try(player, _try["item"], outcome, mode)
	_rating_shown = [before, float(player["rating"]["r"])]
	_save_player()
	_prog_problem(correct)
	if mode == "train":
		_streak = _streak + 1 if correct else 0
		var now := float(player["rating"]["r"])
		if now > before + 0.5:
			_celebrate.call_deferred(before, now)


## Pedir ayuda decide el intento: cuenta como no resuelto por uno mismo.
func _mark_help(kind: String) -> void:
	if _try.is_empty() or bool(_try.get("recorded", true)):
		return
	_try["help"] = kind
	_record(false)


## «No lo sé» (en el test): se anota y se enseña la solución.
func _give_up() -> void:
	if phase != Phase.SOLVING:
		return
	_mark_help("giveup")
	_show_solution()


# ---------------------------------------------------------------- curso «Aprende a jugar»

func _load_course() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/curso.json"))
	course = data.get("units", []) if typeof(data) == TYPE_DICTIONARY else []
	kids_lines = data.get("kidsLines", {}) if typeof(data) == TYPE_DICTIONARY else {}
	var index: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/voz.json")) if FileAccess.file_exists("res://data/voz.json") else null
	voice_index = index if typeof(index) == TYPE_DICTIONARY else {}


func _load_course_progress() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(COURSE_PATH)) if FileAccess.file_exists(COURSE_PATH) else null
	course_done = data.get("done", {}) if typeof(data) == TYPE_DICTIONARY else {}


func _save_course_progress() -> void:
	if not use_settings:
		return
	var file := FileAccess.open(COURSE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"version": 1, "done": course_done}))
		file.close()


func _course_lessons() -> Array:
	var out: Array = []
	for unit: Dictionary in course:
		for l: Dictionary in unit["lessons"]:
			out.append(l)
	return out


## «Nunca he jugado»: el curso desde la primera lección (la primera que no esté hecha).
func _start_from_zero() -> void:
	experience = "never"
	for l: Dictionary in _course_lessons():
		if not course_done.has(str(l["id"])):
			_start_lesson(str(l["id"]))
			return
	_open_course()


## Mapa del curso: las unidades y sus lecciones, con las hechas marcadas.
func _open_course() -> void:
	var page := _page("course")
	var body: VBoxContainer = page["body"]
	var footer: VBoxContainer = page["footer"]
	var tile := _icon_tile("book", "butter", 156.0, 98.0)
	tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(tile)
	body.add_child(_spacer(20.0))
	body.add_child(_centered(_para("Aprende desde cero", F_TITLE + 12, _c("ink"), font_display)))
	var lessons := _course_lessons()
	var done := 0
	for l: Dictionary in lessons:
		if course_done.has(str(l["id"])):
			done += 1
	var sub := Loc.f("%d de %d lecciones", [done, lessons.size()]) if kids else Loc.f("%d de %d lecciones · desde cero hasta el jaque mate", [done, lessons.size()])
	body.add_child(_centered(_para(sub, F_SUB, _c("quiet"), font_medium)))
	var tints := ["peach", "mint", "lilac", "sky", "butter", "rose"]
	var n := 0
	for unit: Dictionary in course:
		body.add_child(_spacer(34.0))
		body.add_child(_text(Loc.t(str(unit["title"])).to_upper(), F_CAP, _c("quiet"), font_semibold))
		body.add_child(_spacer(12.0))
		for l: Dictionary in unit["lessons"]:
			var id := str(l["id"])
			var line := _lesson_line(l)
			if course_done.has(id):
				line = Loc.t("Hecha") + " · " + "★".repeat(int(course_done[id])) + "☆".repeat(3 - int(course_done[id]))
			body.add_child(_option_button(str(l["icon"]), str(tints[n % tints.size()]), _lesson_title(l), line, _start_lesson.bind(id)))
			body.add_child(_spacer(14.0))
			n += 1
	body.add_child(_spacer(10.0, true))
	if not kids and not _has_player():
		footer.add_child(_button("cap", "Ya sé mover las piezas: test de nivel", _open_experience, _tint("mint")[0], _c("ink"), {"font_size": F_SUB, "height": 96.0, "icon": 44.0, "font": font_medium}))
	if use_settings:
		footer.add_child(_button("home", "Inicio", _open_home, _c("field"), _c("ink"), {"font_size": F_SUB, "height": 96.0, "icon": 44.0, "font": font_medium}))
	if mode == "learn" and not lesson.is_empty():
		footer.add_child(_button("back", "Volver a la lección", _close_progress, _c("field"), _c("ink"), {"font_size": F_SUB, "height": 96.0, "icon": 44.0, "font": font_medium}))


func _start_lesson(id: String) -> void:
	for l: Dictionary in (Cine.lessons() if Cine.is_lesson(id) else _course_lessons()):
		if str(l["id"]) == id:
			lesson = l
	if lesson.is_empty():
		return
	mode = "learn"
	ex_stars = []
	lesson_ex = -1
	_film_close()
	_close_progress()
	_film_open()
	_show_lesson_step()
	if not film.is_empty():
		# Se carga el vídeo parado en el inicio del clip, cuando el hueco ya tiene su sitio en la pantalla.
		_layout()
		_film_event.call_deferred({"type": "start", "mode": "film"})


## Enseña el paso actual de la lección: la introducción, un ejercicio o el final.
func _show_lesson_step() -> void:
	run_id += 1
	_clear_explanation()
	learn_why_open = false
	why_board = false
	why_paras = []
	_try = {}
	_gap_limit = INF
	var exercises: Array = lesson.get("exercises", [])
	view.board.set_arrows([])
	view.board.set_goals([])
	view.board.only_square = -1
	view.set_orientation(int(lesson.get("orientation", 0)))
	view.interactive = false
	ex_text = ""
	_cine_hint_shown = false
	ex_good = false
	ex_moves = 0
	ex_fails = 0
	if lesson_ex < 0:
		ex = {}
		ex_state = "intro"
		var said: Array = [_lesson_title(lesson)] + (_lesson_text("intro") as Array)
		if course_done.is_empty() and kids:
			said.push_front(_kid_line("welcomeKids"))
		_say(said)
		view.set_fen(str(exercises[0]["fen"]) if not exercises.is_empty() else Board3D.START_FEN)
		if not exercises.is_empty() and str(exercises[0]["kind"]) == "collect":
			view.board.set_goals(_squares(exercises[0].get("stars", [])))
	elif lesson_ex >= exercises.size():
		ex = {}
		ex_state = "end"
		var total := 0
		for st: Variant in ex_stars:
			total += int(st)
		var stars := clampi(int(round(float(total) / maxf(1.0, float(ex_stars.size())))), 1, 3) if not ex_stars.is_empty() else 3
		var id := str(lesson["id"])
		course_done[id] = maxi(stars, int(course_done.get(id, 0)))
		_save_course_progress()
		_prog_lesson()
		_sfx("leccion")
		var said := [BRAVO, _kid_line("lessonDone"), str(_lesson_text("takeaway"))]
		if _is_last_lesson():
			said.append(_kid_line("courseDone"))
		elif _unit_of(id).has("game") and _is_last_of_unit(id):
			said.append(_kid_line("unitGame"))
		_say(said)
	else:
		ex = exercises[lesson_ex]
		view.set_fen(str(ex["fen"]))
		_lesson_marks()
		_say([_ex_text(ex)])
		match str(ex["kind"]):
			"info":
				ex_state = "info"
			"collect":
				ex_state = "play"
				_ex_blacks = _black_left()
				view.board.set_goals(_squares(ex.get("stars", [])))
				view.board.only_square = Chess.sq_index(str(ex["hero"]))
				view.interactive = true
			_:
				ex_state = "play"
				view.interactive = true
	phase = Phase.SOLVING
	_refresh()


## La última jugada y las flechas del paso (las lecciones del cine las traen; las del curso, no).
func _lesson_marks() -> void:
	var last: Array = ex.get("last", [])
	if last.size() == 2:
		view.board.mark_last_move(Chess.sq_index(str(last[0])), Chess.sq_index(str(last[1])))
	var arrows: Array = []
	for a: Dictionary in ex.get("arrows", []):
		arrows.append({"from": Chess.sq_index(str(a["from"])), "to": Chess.sq_index(str(a["to"])), "tone": str(a.get("tone", "info"))})
	if not arrows.is_empty():
		view.board.set_arrows(arrows)


func _squares(names: Array) -> Array:
	var out: Array = []
	for n: Variant in names:
		out.append(Chess.sq_index(str(n)))
	return out


func _black_left() -> int:
	var n := 0
	for p in view.board.chess.b:
		if p != 0 and Chess.color_of(p) == 1:
			n += 1
	return n


## Una jugada en una lección.
func _learn_move(uci: String) -> void:
	if ex.is_empty() or ex_state != "play":
		return
	var my_run := run_id
	var board := view.board
	if str(ex["kind"]) == "collect":
		ex_moves += 1
		var to := Chess.sq_index(uci.substr(2, 2))
		# Las negras no mueven: el turno vuelve a blancas y solo se mueve la pieza de la lección.
		board.chess.turn = 0
		board.chess.ep = -1
		board.only_square = to
		if bool(ex.get("safe", false)) and board.chess.attacked(to, 1):
			ex_state = "fail"
			ex_good = false
			_sfx("error")
			ex_text = _kid_line("attacked") if kids else "Esa casilla la ataca una pieza negra: te capturarían. Mira antes qué casillas atacan."
			_say([ex_text])
			view.interactive = false
			_refresh()
			return
		if board.has_goal(to) or _black_left() < _ex_blacks:
			_sfx("acierto")
		_ex_blacks = _black_left()
		if board.has_goal(to):
			board.take_goal(to)
		if board.goals_left() == 0 and _black_left() == 0:
			var par := int(ex["par"])
			var stars := 3 if ex_moves <= par else (2 if ex_moves <= par + 2 else 1)
			ex_stars.append(stars)
			ex_state = "done"
			ex_good = true
			view.interactive = false
			ex_text = (Loc.f("¡Perfecto! En %d jugadas, el mínimo posible.", ex_moves)) if ex_moves <= par else (Loc.f("¡Hecho! En %d jugadas. Se puede en %d: prueba a repetirlo.", [ex_moves, par]))
			if kids:
				ex_text = _kid_line("good") if ex_moves <= par else _kid_line("fewer")
				_say([BRAVO] if ex_moves <= par else [BRAVO, ex_text])
			else:
				_say([ex_text])
		_refresh()
		return
	var verdict: Dictionary = (ex.get("moves", {}) as Dictionary).get(uci, {})
	ex_last_uci = uci
	ex_text = str(verdict.get("k" if kids else "t", verdict.get("t", "")))
	if ex.has("cine"):
		ex_text = Cine.answer(ex, uci)
	_say([BRAVO, ex_text] if bool(verdict.get("ok", false)) else [ex_text])
	_sfx("acierto" if bool(verdict.get("ok", false)) else "error")
	view.interactive = false
	if bool(verdict.get("ok", false)):
		ex_stars.append(clampi(3 - ex_fails, 1, 3))
		ex_state = "done"
		ex_good = true
		_refresh()
		return
	ex_fails += 1
	ex_good = false
	_refresh()
	await _wait(1.6)
	if my_run != run_id:
		return
	view.set_fen(str(ex["fen"]))
	_lesson_marks()
	view.interactive = true


func _build_learn_card() -> void:
	var exercises: Array = lesson.get("exercises", [])
	var head := _lesson_title(lesson)
	var tone := _c("ink")
	if ex_state == "done":
		head = "¡Bien!"
		tone = _c("good")
	elif ex_state == "fail":
		head = "¡Cuidado!"
		tone = _c("bad")
	elif ex_state == "end":
		head = "Lección terminada"
		tone = _c("good")
	elif ex_state == "film":
		head = "Mira el vídeo"
	title = _para(head, F_TITLE, tone, font_display)
	if kids and voice_on and _has_voice(_voice_last):
		# El título con el botón de volver a oír.
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 16)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(title)
		top.add_child(_round_button("sound", _say_again, 96.0, _c("field"), _c("ink"), false))
		card_body.add_child(top)
	else:
		card_body.add_child(title)
	if ex_state == "film":
		card_body.add_child(_para(_film_card_text(), F_BODY, _c("ink"), font_regular))
		return
	if ex_state == "intro":
		# Con el vídeo, primero qué hacer (pulsar ▶): con el vídeo arriba, la tarjeta tiene poco sitio.
		if not film.is_empty():
			card_body.add_child(_para(_film_card_text(), F_BODY, _c("accent_text"), font_medium))
		for t: Variant in _lesson_text("intro"):
			card_body.add_child(_para(str(t), F_BODY, _c("ink"), font_regular))
		var chips := HFlowContainer.new()
		chips.add_theme_constant_override("h_separation", 12)
		chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if Cine.is_lesson(str(lesson.get("id", ""))):
			var questions := 0
			for e0: Dictionary in exercises:
				if str(e0.get("kind", "")) == "move":
					questions += 1
			chips.add_child(_chip(Loc.f("%d preguntas", questions), _c("field"), _c("ink"), "target"))
			var clip := Cine.clip_of(str(lesson["id"]))
			var channel := str((clip.get("video", {}) as Dictionary).get("channel", "YouTube"))
			chips.add_child(_chip(Loc.f("Vídeo: %s" if not film.is_empty() else "Vídeo al final: %s", channel), _c("field"), _c("quiet"), "play"))
		else:
			chips.add_child(_chip(Loc.f("%d ejercicios", exercises.size()), _c("field"), _c("ink"), "book"))
		card_body.add_child(chips)
		return
	if ex_state == "end":
		var id := str(lesson["id"])
		var stars := int(course_done.get(id, 3))
		card_body.add_child(_para("★".repeat(stars) + "☆".repeat(3 - stars), F_TITLE, _tint("butter")[1], font_display))
		card_body.add_child(_para(str(_lesson_text("takeaway")), F_BODY, _c("ink"), font_regular))
		return
	var step_text := Loc.f("Ejercicio %d de %d", [lesson_ex + 1, exercises.size()])
	if Cine.is_lesson(str(lesson.get("id", ""))):
		# En los finales: «Pregunta 2 de 3» y, después, «Explicación 4 de 11».
		var kind := str(ex.get("kind", ""))
		var nth := 0
		var total := 0
		for i in exercises.size():
			if str((exercises[i] as Dictionary).get("kind", "")) == kind:
				total += 1
				if i <= lesson_ex:
					nth += 1
		step_text = Loc.f("Pregunta %d de %d" if kind == "move" else "Explicación %d de %d", [nth, total])
	var step := _chip(step_text, _c("field"), _c("quiet"))
	step.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	card_body.add_child(step)
	if learn_why_open:
		# Con el «¿Por qué?» abierto, solo él: así no se sale de la tarjeta.
		var e0 := _learn_why()
		if not e0.is_empty():
			card_body.add_child(_why_block(e0, "Por qué"))
			return
	card_body.add_child(_para(_ex_text(ex), F_BODY, _c("ink"), font_regular if ex_state != "play" else font_medium))
	if str(ex.get("kind", "")) == "collect" and ex_state == "play":
		var stars_total: int = (ex.get("stars", []) as Array).size()
		var line := Loc.f("Jugadas: %d", ex_moves)
		if stars_total > 0:
			line = Loc.f("Estrellas: %d de %d · %s", [stars_total - view.board.goals_left(), stars_total, line])
		card_body.add_child(_para(line, F_SUB, _c("quiet"), font_medium))
	if ex_text != "":
		card_body.add_child(_para(ex_text, F_BODY, _c("good") if ex_good else _c("bad"), font_medium))
	if learn_why_open and ex_state in ["done", "fail", "info"]:
		var e := _learn_why()
		if not e.is_empty():
			card_body.add_child(_why_block(e, "Por qué"))


## ¿Tiene el ejercicio un «¿Por qué?» sacado del tablero? En los de jugada (fuera de Kids) y, también en Kids, cuando
## hay mate o ahogado (en un ejemplo o tras tu jugada).
func _learn_why_ok() -> bool:
	if not _learn_box().is_empty():
		return true
	return not kids and str(ex.get("kind", "")) == "move" and ex_last_uci != "" and Chess.from_fen(str(ex.get("fen", ""))).find_uci(ex_last_uci) >= 0


## Mate o ahogado en la lección (la posición de un ejemplo, o la que deja tu jugada): por qué el rey no tiene salida,
## paso a paso y con el rey intentando escapar. [] si no hay ni mate ni ahogado.
func _learn_box() -> Array:
	var kind := str(ex.get("kind", ""))
	var pos := Chess.from_fen(str(ex.get("fen", "")))
	if kind == "move":
		if ex_last_uci == "" or not ex_state in ["done", "fail"]:
			return []
		var m := pos.find_uci(ex_last_uci)
		if m < 0:
			return []
		var me := pos.turn
		pos.apply(m)
		return MoveWhy.king_box(pos, me, kids)
	if kind == "info":
		return MoveWhy.king_box(pos, 1 - pos.turn, kids)
	return []


func _learn_why() -> Dictionary:
	var box := _learn_box()
	if not box.is_empty():
		return {"paras": box}
	var before := Chess.from_fen(str(ex.get("fen", "")))
	var m := before.find_uci(ex_last_uci)
	if m < 0:
		return {}
	return MoveWhy.explain(before, m, before.turn, "solution")


func _learn_why_toggle() -> void:
	learn_why_open = not learn_why_open
	why_paras = []
	why_idx = 0
	if learn_why_open:
		var e := _learn_why()
		if not e.is_empty():
			why_paras = e["paras"]
			_why_apply()
	else:
		_why_restore()
	_refresh()


func _build_learn_actions() -> void:
	var last_lesson := _is_last_lesson()
	var film_key := "" if film.is_empty() else "%s:%d:%s:%d" % [film["st"]["phase"], int(film["st"]["stop"]), film["st"]["missed"], int(film["st"]["error"])]
	var key := "learn:%s:%d:%s:%s:%s:%s" % [ex_state, lesson_ex, str(last_lesson), str(kids), str(learn_why_open), film_key]
	if key == _actions_mode:
		return
	_actions_mode = key
	for old in actions.get_children():
		(old as CanvasItem).visible = false
		old.queue_free()
	hint_button = null
	step_button = null
	var wide := {"font_size": F_BODY, "height": BAR_HEIGHT, "icon": 56.0, "radius": 60}
	var go := wide.duplicate()
	go["glow"] = _c("glow")
	go["trailing"] = true
	var quiet := wide.duplicate()
	var row: Array[Button] = []
	var on_film := not film.is_empty()
	match ex_state:
		"intro":
			row = [_learn_back_button(quiet), _button("next", "Empezar", _next_lesson_step, _c("accent"), _c("accent_ink"), go)]
			if on_film:
				row = [_learn_back_button(quiet), _button("next", "Ir a la pregunta", _film_ask, _c("accent_soft"), _c("accent_text"), wide)]
		"film":
			var st_f: Dictionary = film.get("st", {}) if on_film else {}
			if not on_film:
				row = [_learn_back_button(quiet), _button("next", "Siguiente", _next_lesson_step, _c("accent"), _c("accent_ink"), go)]
			elif st_f["missed"] != "none":
				row = [_learn_back_button(quiet), _button("back", "Volver a la pregunta", _film_back, _c("accent"), _c("accent_ink"), go)]
			elif int(st_f["stop"]) + 1 < (film["plies"] as Array).size():
				row = [_learn_back_button(quiet), _button("next", "Ir a la pregunta", _film_ask, _c("accent_soft"), _c("accent_text"), wide)]
			else:
				row = [_learn_back_button(quiet), _button("next", "Terminar el vídeo", _film_end_now, _c("accent_soft"), _c("accent_text"), wide)]
		"info":
			row = [_learn_back_button(quiet), _button("next", "Siguiente", _next_lesson_step, _c("accent"), _c("accent_ink"), go)]
			if _learn_why_ok():
				if learn_why_open:
					row = [_button("back", "Volver", _learn_why_toggle, _c("field"), _c("ink"), quiet), _button("next", "Siguiente", _next_lesson_step, _c("accent"), _c("accent_ink"), go)]
				else:
					var tint0 := _tint("lilac")
					var why0 := wide.duplicate()
					why0["icon_color"] = tint0[1]
					row.insert(1, _button("why", "¿Por qué?", _learn_why_toggle, tint0[0], _c("ink"), why0))
		"play":
			row = [_learn_back_button(quiet)]
			if str(ex.get("kind", "")) == "move":
				var tint := _tint("butter")
				var help := wide.duplicate()
				help["icon_color"] = tint[1]
				row.append(_button("bulb", "Pista", _learn_hint, tint[0], _c("ink"), help))
			if on_film and str(ex.get("kind", "")) == "move":
				# Responder es opcional: se puede seguir viendo sin contestar.
				row.append(_button("play", "Seguir el vídeo", _film_continue, _c("accent_soft"), _c("accent_text"), wide))
			else:
				row.append(_button("retry", "Reiniciar", _show_lesson_step, _c("accent_soft"), _c("accent_text"), wide))
		"fail":
			row = [_learn_back_button(quiet), _button("retry", "Reintentar", _show_lesson_step, _c("accent"), _c("accent_ink"), go)]
			if on_film and str(ex.get("kind", "")) == "move":
				row[0] = _button("play", "Seguir el vídeo", _film_continue, _c("accent_soft"), _c("accent_text"), wide)
			if _learn_why_ok():
				if learn_why_open:
					row = [_button("back", "Volver", _learn_why_toggle, _c("field"), _c("ink"), quiet), _button("retry", "Reintentar", _show_lesson_step, _c("accent"), _c("accent_ink"), go)]
				else:
					var tint1 := _tint("lilac")
					var why1 := wide.duplicate()
					why1["icon_color"] = tint1[1]
					row.insert(1, _button("why", "¿Por qué?", _learn_why_toggle, tint1[0], _c("ink"), why1))
		"done":
			row = [_button("retry", "Repetir", _show_lesson_step, _c("accent_soft"), _c("accent_text"), wide), _button("next", "Siguiente", _next_lesson_step, _c("accent"), _c("accent_ink"), go)]
			if on_film and str(ex.get("kind", "")) == "move":
				row[1] = _button("play", "Seguir el vídeo", _next_lesson_step, _c("accent"), _c("accent_ink"), go)
			if _learn_why_ok():
				if learn_why_open:
					row = [_button("back", "Volver", _learn_why_toggle, _c("field"), _c("ink"), quiet), _button("next", "Siguiente", _next_lesson_step, _c("accent"), _c("accent_ink"), go)]
				else:
					var tint := _tint("lilac")
					var why := wide.duplicate()
					why["icon_color"] = tint[1]
					row.insert(1, _button("why", "¿Por qué?", _learn_why_toggle, tint[0], _c("ink"), why))
		"end":
			var unit := _unit_of(str(lesson.get("id", "")))
			if Cine.is_lesson(str(lesson.get("id", ""))):
				var red := _tint("rose")
				var vid := wide.duplicate()
				vid["icon_color"] = red[1]
				row = [_button("play", "Ver el vídeo", _open_cine_video, red[0], _c("ink"), vid), _button("next", "Siguiente final" if _next_cine_id() != "" else "Finales", _next_lesson, _c("accent"), _c("accent_ink"), go)]
			elif not unit.is_empty() and unit.has("game") and _is_last_of_unit(str(lesson.get("id", ""))):
				row = [_learn_back_button(quiet), _button("piece_knight", "Partida", _start_unit_game.bind(str(unit["id"])), _c("accent"), _c("accent_ink"), go)]
			elif last_lesson and kids:
				row = [_button("retry", "Repetir", _start_lesson.bind(str(lesson.get("id", ""))), _c("accent_soft"), _c("accent_text"), wide), _button("next", "Curso", _open_course, _c("accent"), _c("accent_ink"), go)]
			elif last_lesson:
				row = [_learn_back_button(quiet), _button("next", "Test de nivel", _after_course, _c("accent"), _c("accent_ink"), go)]
			else:
				row = [_learn_back_button(quiet), _button("next", "Siguiente lección", _next_lesson, _c("accent"), _c("accent_ink"), go)]
	left_button = row[0]
	right_button = row[row.size() - 1]
	for b: Button in row:
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Al acabar un ejercicio (o la lección), los botones van en la ventana del resultado, encima del tablero.
	if ex_state in ["done", "fail", "end"] and not learn_why_open:
		_popup_row = row
		return
	_popup_row = []
	for b: Button in row:
		actions.add_child(b)


## Llama a `cb` cuando el tablero termina de moverse (la jugada, el rey que cae…), con una pausa para verlo.
func _when_board_still(cb: Callable) -> void:
	if not view.board.is_animating():
		cb.call()
		return
	view.board.animations_finished.connect(func() -> void:
		get_tree().create_timer(0.35).timeout.connect(cb), CONNECT_ONE_SHOT)


var _learn_popup_wait := false


## Ventana semitransparente con el resultado del ejercicio o de la lección y sus botones, encima del tablero.
func _sync_learn_popup() -> void:
	var want := mode == "learn" and ex_state in ["done", "fail", "end"] and not _popup_row.is_empty() and not learn_why_open
	# Primero se ve la jugada entera (y el rey que cae); después, la ventana.
	if want and (learn_popup == null or not is_instance_valid(learn_popup)) and view.board.is_animating():
		if not _learn_popup_wait:
			_learn_popup_wait = true
			_when_board_still(func() -> void:
				_learn_popup_wait = false
				_sync_learn_popup())
		return
	if learn_popup != null and is_instance_valid(learn_popup):
		if want and str(learn_popup.get_meta("key", "")) == _actions_mode:
			return
		learn_popup.visible = false
		learn_popup.queue_free()
	learn_popup = null
	if not want:
		return
	learn_popup = Control.new()
	learn_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	learn_popup.set_meta("key", _actions_mode)
	learn_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(learn_popup)
	var scrim := ColorRect.new()
	scrim.color = Color(1.0, 1.0, 1.0, 0.18) if not dark else Color(0.0, 0.0, 0.0, 0.28)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	learn_popup.add_child(scrim)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	var paper := _c("surface")
	sb.bg_color = Color(paper.r, paper.g, paper.b, 0.86)
	sb.set_corner_radius_all(60)
	sb.shadow_color = _c("shadow")
	sb.shadow_size = 30
	sb.shadow_offset = Vector2(0.0, 12.0)
	panel.add_theme_stylebox_override("panel", sb)
	panel.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW if kids else CanvasItem.CLIP_CHILDREN_DISABLED
	learn_popup.add_child(panel)
	if kids:
		var wall := _kids_wall()
		wall.set_anchors_preset(Control.PRESET_TOP_LEFT)
		wall.modulate.a = 0.8
		panel.add_child(wall)
	var pad := _pad(44, 44, 40, 40)
	panel.add_child(pad)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	pad.add_child(column)
	var good := ex_state != "fail"
	var head := "¡Bien!" if ex_state == "done" else ("¡Cuidado!" if ex_state == "fail" else ("¡Lección terminada!" if kids else "Lección terminada"))
	column.add_child(_centered(_para(head, F_TITLE + 10, _c("good") if good else _c("bad"), font_display)))
	var stars := -1
	if ex_state == "end":
		stars = int(course_done.get(str(lesson.get("id", "")), 3))
	elif ex_state == "done" and not ex_stars.is_empty():
		stars = int(ex_stars[ex_stars.size() - 1])
	if stars >= 0:
		column.add_child(_centered(_para("★".repeat(stars) + "☆".repeat(3 - stars), F_TITLE + 14, _tint("butter")[1], font_display)))
	var line := str(_lesson_text("takeaway")) if ex_state == "end" else ex_text
	if line != "":
		column.add_child(_centered(_para(line, F_BODY, _c("ink"), font_medium)))
	column.add_child(_spacer(6.0))
	# Con tres botones no caben en una fila: los dos primeros arriba y el principal, solo, debajo.
	var rows_of: Array = [_popup_row] if _popup_row.size() <= 2 else [_popup_row.slice(0, _popup_row.size() - 1), [_popup_row[_popup_row.size() - 1]]]
	for group: Array in rows_of:
		var buttons := HBoxContainer.new()
		buttons.add_theme_constant_override("separation", 16)
		for b: Button in group:
			buttons.add_child(b)
		column.add_child(buttons)
	# Centrada sobre el tablero, con un margen a los lados.
	var place := func() -> void:
		if not is_instance_valid(panel) or board_slot == null or not is_instance_valid(board_slot):
			return
		var w := minf(size.x - 80.0, 980.0)
		panel.size = Vector2(w, 0.0)
		panel.reset_size()
		panel.size.x = w
		var h := panel.get_combined_minimum_size().y
		var rect := board_slot.get_global_rect()
		panel.position = Vector2((size.x - w) * 0.5, clampf(rect.get_center().y - h * 0.5, 40.0, size.y - h - 40.0))
		for child in panel.get_children():
			if child is TextureRect:
				(child as TextureRect).size = panel.size
	panel.minimum_size_changed.connect(place)
	place.call_deferred()
	# Aparece con un pequeño salto.
	panel.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.18)


## «Curso» en las lecciones del curso; «Finales» en las del cine.
func _learn_back_button(opts: Dictionary) -> Button:
	if Cine.is_lesson(str(lesson.get("id", ""))):
		return _button("back", "Finales", _open_cine, _c("field"), _c("ink"), opts)
	return _button("back", "Curso", _open_course, _c("field"), _c("ink"), opts)


func _learn_back() -> void:
	if Cine.is_lesson(str(lesson.get("id", ""))):
		_open_cine()
	else:
		_open_course()


func _is_last_lesson() -> bool:
	var lessons := _course_lessons()
	return not lessons.is_empty() and str(lessons[lessons.size() - 1]["id"]) == str(lesson.get("id", ""))


## Pista en una jugada de lección: se señala la pieza que hay que mover (la de la primera jugada que vale).
var _cine_hint_shown := false


func _learn_hint() -> void:
	if ex.is_empty() or ex_state != "play" or str(ex.get("kind", "")) != "move":
		return
	if str(ex.get("hint", "")) != "" and not _cine_hint_shown:
		# En el cine, primero la pista del clip; la segunda vez, la pieza.
		_cine_hint_shown = true
		ex_fails = maxi(ex_fails, 1)
		ex_text = Loc.t("Pista:") + " " + Loc.t(str(ex["hint"]))
		ex_good = true
		_refresh()
		return
	var moves: Dictionary = ex.get("moves", {})
	for uci: Variant in moves.keys():
		if bool((moves[uci] as Dictionary).get("ok", false)):
			view.set_fen(str(ex["fen"]))
			view.interactive = true
			view.board.select(Chess.sq_index(str(uci).substr(0, 2)))
			ex_fails = maxi(ex_fails, 1)
			ex_text = _kid_line("hint") if kids else "Pista: esta es la pieza que hay que mover."
			ex_good = true
			_say([ex_text])
			_refresh()
			return


func _next_lesson_step() -> void:
	learn_why_open = false
	why_board = false
	why_paras = []
	if not film.is_empty() and str(ex.get("kind", "")) == "move":
		# Con el vídeo: tras una pregunta, el vídeo sigue hasta la siguiente pausa (o hasta el final).
		_film_continue()
		return
	lesson_ex += 1
	_show_lesson_step()


func _next_lesson() -> void:
	if Cine.is_lesson(str(lesson.get("id", ""))):
		var nxt := _next_cine_id()
		if nxt != "":
			_start_lesson(nxt)
		else:
			_open_cine()
		return
	var lessons := _course_lessons()
	for i in lessons.size():
		if str(lessons[i]["id"]) == str(lesson.get("id", "")) and i + 1 < lessons.size():
			_start_lesson(str(lessons[i + 1]["id"]))
			return
	_open_course()


## Curso terminado: si aún no tiene nivel, el test (con lo aprendido, desde «sé mover las piezas»).
func _after_course() -> void:
	if _has_player():
		_start_training()
	else:
		_start_test("rules")





# ---------------------------------------------------------------- pantalla de inicio

## Raíz de una pantalla de inicio propia (las de ui/home_screens.gd): como _page("home"), pero vacía.
func _home_root() -> Control:
	_close_progress()
	if sheet_kind != "":
		_close_options()
	progress_kind = "home"
	progress_scroll = null
	progress = Control.new()
	progress.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(progress)
	return progress


## Lo que ofrece el inicio, en orden: [icono, tono, título, detalle, qué abre].
func _home_items() -> Array:
	var lessons := _course_lessons()
	var done := 0
	for l: Dictionary in lessons:
		if course_done.has(str(l["id"])):
			done += 1
	var items: Array = []
	if not kids and _has_player():
		items.append(["flag", "butter", "Reto del día", _prog_home_text(), _open_day])
	if not kids and _has_player():
		var lvl := Assessment.level_of(float(player["rating"]["r"]))
		if bool(player.get("done", false)):
			items.append(["target", "peach", "Entrenar", "Problemas a tu nivel.", _home_train])
		else:
			items.append(["cap", "peach", "Seguir con el test de nivel", "Lo dejaste a medias.", _home_test])
	if kids and not pool.is_empty():
		items.append(["target", "peach", "Entrenar", "Problemas para pensar, a tu nivel.", _home_train])
	# En el nivel Kids el curso es lo principal y va primero; fuera de él, es la última opción.
	if kids and not course.is_empty():
		items.append(["chick", "butter", "Aprende desde cero", Loc.f("%d de %d lecciones hechas.", [done, lessons.size()]) if done > 0 else "Cómo se mueve cada pieza.", _open_course])
	items.append(["piece_knight", "mint", "Jugar una partida", "Contra el ordenador, 13 niveles.", _open_game_setup.bind(true)])
	if not kids:
		items.append(["crown", "butter", "Campeonato", "Copa, liga, suizo…: de la escuela al gran hotel.", _open_campeonato])
		items.append(["piece_queen", "sky", "Partida online", "Contra otra persona, en directo.", _open_online_home])
	if not kids and not _has_player():
		items.append(["cap", "lilac", "Test de nivel", "Unos problemas para saber por dónde empezar.", _open_experience])
	if not kids and _has_player():
		items.append(["trend", "lilac", "Mi nivel y mi plan", "En qué fallas y qué toca.", _open_progress.bind("progress")])
	if KIDS_ENABLED and not kids and not course.is_empty():
		items.append(["party", "sky", "Modo Kids", "Desde 8 años, con voz.", _set_kids.bind(true)])
	if not kids and not course.is_empty():
		items.append(["chick", "butter", "Aprende desde cero", Loc.f("%d de %d lecciones hechas.", [done, lessons.size()]) if done > 0 else "Cómo se mueve cada pieza.", _open_course])
	return items


## Opciones → «Intro».
func _set_intro_mode(i: int) -> void:
	intro_mode = INTRO_MODES[clampi(i, 0, INTRO_MODES.size() - 1)]
	_save_settings()
	_sync_sheet()


## Intro del arranque: encima de todo, una sola vez por arranque y según la opción (nunca en las pruebas).
func _play_intro() -> void:
	if not use_settings or intro_mode == "never" or (intro_mode == "once" and intro_seen) or not Intro.available():
		return
	intro_seen = true
	_save_settings()
	var intro := Intro.new()
	intro.sound = sound_on
	add_child(intro)


## Opciones → «Pantalla de inicio».
func _set_home_style(i: int) -> void:
	var style: String = HomeScreens.STYLES[clampi(i, 0, HomeScreens.STYLES.size() - 1)]
	if style == home_style:
		return
	home_style = style
	_save_settings()
	# Con el inicio debajo de Opciones, se cambia a la vista: se cierra la hoja y aparece la pantalla elegida.
	if progress_kind == "home" and not kids:
		_open_home()
	else:
		_sync_sheet()


var _ads_waiting := false


## Arranca los anuncios (y con ellos el aviso de consentimiento de Google, si hace falta) la primera vez que el
## inicio está en pantalla, ya elegido el idioma y acabada la animación de entrada; con un respiro para que el
## inicio se vea antes. Si mientras tanto el jugador sale del inicio, espera a que vuelva.
func _ads_start_later() -> void:
	if kids or ads.started() or _ads_waiting or not use_settings:
		return
	_ads_waiting = true
	await _wait(1.5)
	while is_inside_tree() and (_intro_on_screen() or progress_kind != "home" or kids):
		await _wait(0.5)
	_ads_waiting = false
	if is_inside_tree() and not kids and progress_kind == "home":
		ads.start()


func _intro_on_screen() -> bool:
	for c in get_children():
		if c is Intro:
			return true
	return false


## Inicio: lo que se puede hacer en la app, con lo que estaba haciendo el jugador en primer lugar.
func _open_home() -> void:
	_film_close()
	if sheet_kind != "":
		_close_options()
	_stop_voice()
	# Fuera del nivel Kids, el inicio es una de las dos pantallas que elige el jugador.
	if not kids:
		if home_style == "rejilla":
			HomeScreens.build_grid(self)
		else:
			HomeScreens.build_list(self, _home_items())
		_place_tip()
		_ads_start_later()
		# Entre actividades y solo aquí (core/ads.gd): nunca en Kids, online ni en mitad de nada.
		ads.maybe_show(kids or (online != null and online.phase != "idle") or online_busy)
		return
	var page := _page("home")
	var body: VBoxContainer = page["body"]
	var footer: VBoxContainer = page["footer"]
	progress.add_child(_flag_button())
	body.add_child(_spacer(6.0, true))
	var emblem := HomeScreens._icon_mark(210.0)
	emblem.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(emblem)
	body.add_child(_spacer(40.0))
	body.add_child(_centered(_para("A Chess Way", F_LARGE, _c("ink"), font_display)))
	var sub := "¿A qué jugamos hoy?" if kids else "¿Qué quieres hacer?"
	body.add_child(_centered(_para(sub, F_HEAD, _c("quiet"), font_medium)))
	if _has_player():
		# Tu insignia: nivel, rango y lo que falta para el siguiente.
		var r := float(player["rating"]["r"])
		var lv := Assessment.level_of(r)
		var rank_row := HBoxContainer.new()
		rank_row.alignment = BoxContainer.ALIGNMENT_CENTER
		rank_row.add_theme_constant_override("separation", 22)
		var mine := Button.new()
		mine.flat = true
		mine.focus_mode = Control.FOCUS_NONE
		mine.custom_minimum_size = Vector2(168.0, 168.0)
		mine.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mine.pressed.connect(_open_avatar)
		var mine_badge := _level_badge(r, 168.0)
		mine_badge.set_anchors_preset(Control.PRESET_FULL_RECT)
		mine.add_child(mine_badge)
		rank_row.add_child(mine)
		var words := VBoxContainer.new()
		words.alignment = BoxContainer.ALIGNMENT_CENTER
		words.add_theme_constant_override("separation", 0)
		# El nivel que sale de los problemas mide la táctica, no la fuerza en partidas (eso es el nivel de juego).
		words.add_child(_para((Loc.t("Nivel %d de %d · %s") if kids else Loc.t("Táctica: nivel %d de %d · %s")) % [lv, Assessment.LEVEL_FLOORS.size() - 1, Loc.t(str(_rank(lv)[1]))], F_TITLE2, _c("ink"), font_display))
		var left_text := "¡Nivel máximo!"
		if lv + 1 < Assessment.LEVEL_FLOORS.size():
			left_text = Loc.f("Te faltan %d puntos para el nivel %d", [maxi(1, int(ceil(float(Assessment.LEVEL_FLOORS[lv + 1]) - r))), lv + 1])
		words.add_child(_line(left_text, F_SUB + 2, _c("quiet"), font_medium))
		if not kids:
			var gr := GameLog.game_rating(_log())
			if int(gr["n"]) > 0:
				words.add_child(_line(Loc.f("Juego: %d%s", [roundi(float(gr["r"])), " (provisional)" if bool(gr["provisional"]) else ""]), F_SUB + 2, _c("quiet"), font_medium))
		rank_row.add_child(words)
		body.add_child(_spacer(22.0))
		body.add_child(rank_row)
	body.add_child(_spacer(36.0))
	var items := _home_items()
	for def: Array in items:
		body.add_child(_option_button(str(def[0]), str(def[1]), str(def[2]), str(def[3]), def[4], true))
		body.add_child(_spacer(20.0))
	body.add_child(_spacer(8.0, true))
	if kids:
		# Salida a la vista (pide la multiplicación para mayores).
		footer.add_child(_button("close", "Salir del modo Kids (para mayores)", _set_kids.bind(false), _c("field"), _c("ink"), {"font_size": F_SUB, "height": 96.0, "icon": 40.0, "font": font_medium}))
	footer.add_child(_button("sliders", "Opciones", _open_options, _tint("sky")[0], _c("ink"), {"font_size": F_BODY, "height": 104.0, "icon": 52.0, "font": font_medium}))


## Iconos de la barra al entrar o salir del nivel Kids (a color o los normales).
func _sync_bar_icons() -> void:
	for pair: Array in [[home_button, "home"], [view_button, "view"], [options_button, "sliders"]]:
		var b: Button = pair[0]
		if b == null or not is_instance_valid(b):
			continue
		for pic in b.find_children("*", "TextureRect", true, false):
			var kid_tex := UiIcons.kids_texture(str(pair[1])) if kids else null
			(pic as TextureRect).texture = kid_tex if kid_tex != null else UiIcons.texture(str(pair[1]))
			(pic as TextureRect).modulate = Color.WHITE if kid_tex != null else _c("ink")
	if pin_button != null and is_instance_valid(pin_button):
		var bar := pin_button.get_parent()
		var at := pin_button.get_index()
		var fresh := _pin_button()
		pin_button.visible = false
		pin_button.queue_free()
		bar.add_child(fresh)
		bar.move_child(fresh, at)
		pin_button = fresh


## Botón de inicio de la barra: deja lo que se esté haciendo (una partida en curso se abandona) y abre el inicio.
func _go_home() -> void:
	if _game_live():
		_ask_leave(_go_home_now)
		return
	_go_home_now()


func _go_home_now() -> void:
	CampeonatoUI.ambient_stop()
	if online.phase != "idle":
		online.leave()
	online_busy = false
	if mode == "game" and game_state != "over" and game_state != "":
		_stop_game_thread()
		run_id += 1
		game_state = ""
		view.interactive = false
		view.board.set_arrows([])
	view.set_orientation(0)
	_stop_voice()
	_open_home()


func _home_train() -> void:
	_open_train_hub()


const FAMILY_ICONS := {"doble": ["whatif", "sky"], "linea": ["line", "lilac"], "defensor": ["pin", "peach"], "mate": ["target", "rose"], "peon": ["piece_pawn", "mint"], "caza": ["search", "butter"], "otros": ["spark", "sky"]}
const FAMILY_KIDS := {"doble": "Atacar dos piezas a la vez", "linea": "Piezas en fila", "defensor": "Quitar al que defiende", "mate": "Jaque mate", "peon": "Peones que coronan", "caza": "Capturar piezas sueltas", "otros": "De todo un poco"}


## «Entrenar»: primero se ve dónde está el jugador (el camino de niveles sobre un tablero) y los problemas por
## categoría, con cuántos ha visto de cada una. Desde aquí elige el entrenamiento recomendado o una categoría.
func _open_train_hub() -> void:
	_film_close()
	if sheet_kind != "":
		_close_options()
	if not _has_player():
		# Sin test hecho (nivel Kids, o quien entra directo): se empieza desde abajo y el nivel se afina solo.
		player = Assessment.start_test("never")
		player["done"] = true
		_save_player()
	var page := _page("train_hub")
	var body: VBoxContainer = page["body"]
	var footer: VBoxContainer = page["footer"]
	var r := float(player["rating"]["r"])
	var lv := Assessment.level_of(r)
	var top := Assessment.LEVEL_FLOORS.size() - 1
	body.add_child(_centered(_para("Entrenar", F_TITLE + 12, _c("ink"), font_display)))
	body.add_child(_centered(_para("Problemas de partidas de verdad, a tu nivel." if not kids else "¡Problemas para pensar!", F_SUB, _c("quiet"), font_medium)))
	body.add_child(_spacer(14.0))
	var path := LevelPath.new()
	var rank := _rank(lv)
	var tint := _tint(str(rank[2]))
	path.level = lv
	path.progress = _level_progress(r)
	path.light = _c("field")
	path.dark = _c("track")
	path.done = tint[1]
	path.ink = _c("ink")
	path.quiet = _c("quiet")
	path.good = _c("good")
	path.night = dark
	path.font = font_semibold
	path.marker = UiIcons.texture(avatar if avatar.begins_with("piece_") and UiIcons.has(avatar) else str(rank[0]))
	path.goal = UiIcons.texture("flag")
	path.custom_minimum_size = Vector2(0.0, 560.0)
	path.mouse_filter = Control.MOUSE_FILTER_PASS
	path.level_pressed.connect(_on_level_pressed.bind(lv))
	# Un marco redondeado recorta el paisaje, como una ilustración.
	var frame := PanelContainer.new()
	var frame_sb := StyleBoxFlat.new()
	frame_sb.bg_color = _c("field")
	frame_sb.set_corner_radius_all(44)
	frame.add_theme_stylebox_override("panel", frame_sb)
	frame.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	frame.mouse_filter = Control.MOUSE_FILTER_PASS
	frame.add_child(path)
	body.add_child(frame)
	_path_hint = _centered(_para("Toca un nivel para ver sus problemas, numerados.", F_FOOT, _c("quiet"), font_regular))
	body.add_child(_path_hint)
	body.add_child(_spacer(10.0))
	var seen := {}
	var solved := {}
	for t: Dictionary in player["tries"]:
		seen[str(t["id"])] = str(t.get("family", "otros"))
		if bool(t["correct"]):
			solved[str(t["id"])] = true
	var where := (Loc.t("Nivel %d de %d · %s") if kids else Loc.t("Táctica: nivel %d de %d · %s")) % [lv, top, Loc.t(str(rank[1]))]
	body.add_child(_centered(_para(where, F_HEAD, _c("ink"), font_display)))
	var left_text := "¡Nivel máximo!"
	if lv < top:
		left_text = Loc.f("Te faltan %d puntos para el nivel %d.", [maxi(1, int(ceil(float(Assessment.LEVEL_FLOORS[lv + 1]) - r))), lv + 1])
	body.add_child(_centered(_para(Loc.f("%s Has visto %d problemas de %d.", [left_text, seen.size(), pool.size()]), F_SUB, _c("quiet"), font_medium)))
	body.add_child(_spacer(18.0))
	var go := _button("play", "Entrenamiento recomendado" if not kids else "¡A entrenar!", _train_family.bind(""), _c("accent"), _c("accent_ink"), {"font_size": F_BODY, "height": 132.0, "icon": 56.0, "radius": 60, "glow": _c("glow")})
	body.add_child(go)
	body.add_child(_centered(_para("Mezcla las categorías y refuerza lo que más fallas." if not kids else "Problemas de todo tipo, a tu nivel.", F_FOOT, _c("quiet"), font_regular)))
	body.add_child(_spacer(10.0))
	# Repasar los fallos cuando uno quiera (un usuario, 17-11: «¿dónde se repasan los fallos antiguos?»). Además
	# siguen saliendo solos en el entrenamiento (uno cada pocos problemas) y en el reto de «Tu día».
	var fails := _pending_fails().size()
	var fails_text := Loc.t("No te queda ninguno: los que falles aparecerán aquí.")
	if fails == 1:
		fails_text = Loc.t("1 problema sin resolver.")
	elif fails > 1:
		fails_text = Loc.f("%d problemas sin resolver, del más antiguo al más reciente.", fails)
	body.add_child(_text("TUS FALLOS", F_CAP, _c("quiet"), font_semibold))
	body.add_child(_spacer(8.0))
	body.add_child(_option_button("retry", "lilac", "Repasar mis fallos", fails_text, _start_review_session))
	body.add_child(_spacer(18.0))
	if not kids and not Cine.clips().is_empty():
		body.add_child(_text("FINALES DE CAMPEONES", F_CAP, _c("quiet"), font_semibold))
		body.add_child(_spacer(8.0))
		body.add_child(_option_button("film", "rose", "Finales de campeones", Loc.f("%d momentos de partidas famosas: ¿qué jugarías tú?", Cine.clips().size()), _open_cine))
		body.add_child(_spacer(18.0))
	body.add_child(_text("POR CATEGORÍA", F_CAP, _c("quiet"), font_semibold))
	body.add_child(_spacer(8.0))
	for fam: String in Assessment.FAMILIES:
		var total := 0
		var near := 0
		var lo := 99
		var hi := 0
		for p: Dictionary in pool:
			if str(p.get("family", "")) != fam:
				continue
			total += 1
			var plv := Assessment.level_of(float(p["rating"]))
			lo = mini(lo, plv)
			hi = maxi(hi, plv)
			if absi(plv - lv) <= 1 and not seen.has(str(p["id"])):
				near += 1
		if total == 0:
			continue
		var mine := 0
		var right := 0
		for id: String in seen:
			if seen[id] == fam:
				mine += 1
				if solved.has(id):
					right += 1
		var text := Loc.f("Vistos %d de %d", [mine, total])
		if mine > 0:
			text += Loc.f(" · %d resueltos", right)
		text += Loc.f(". Niveles %d a %d; %s.", [lo, hi, (Loc.t("%d nuevos cerca de tu nivel") % near) if near > 0 else "ninguno nuevo cerca de tu nivel"])
		var look: Array = FAMILY_ICONS.get(fam, ["spark", "sky"])
		var fam_name := str(FAMILY_KIDS[fam]) if kids else str(Assessment.FAMILY_NAME[fam])
		body.add_child(_option_button(str(look[0]), str(look[1]), fam_name, text, _train_family.bind(fam)))
		body.add_child(_spacer(14.0))
	footer.add_child(_button("home", "Inicio", _open_home, _c("field"), _c("ink"), {"font_size": F_SUB, "height": 92.0, "icon": 44.0, "font": font_medium}))


## Finales de campeones: momentos de partidas famosas. En cada uno, primero las preguntas («¿Qué jugarías?»), después
## la explicación y, al final, el vídeo oficial en YouTube (fuera de la app; dentro llegará en la fase 2).
func _open_cine() -> void:
	_film_close()
	if kids:
		_open_train_hub()
		return
	var page := _page("cine")
	var body: VBoxContainer = page["body"]
	var footer: VBoxContainer = page["footer"]
	var tile := _icon_tile("film", "rose", 156.0, 98.0)
	tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(tile)
	body.add_child(_spacer(20.0))
	body.add_child(_centered(_para("Finales de campeones", F_TITLE + 12, _c("ink"), font_display)))
	var inside := CinePlayer.available()
	body.add_child(_centered(_para("Momentos que decidieron partidas famosas. Ves el vídeo y se para justo antes de la jugada: ¿qué jugarías tú?" if inside else "Momentos que decidieron partidas famosas. Primero piensas qué jugarías; después ves por qué y, al final, el vídeo.", F_SUB, _c("quiet"), font_medium)))
	var tints := ["rose", "peach", "butter", "mint", "sky", "lilac"]
	var n := 0
	for c: Dictionary in Cine.clips():
		body.add_child(_spacer(30.0 if n == 0 else 14.0))
		var l: Dictionary = c["lesson"]
		var id := str(l["id"])
		var line := Loc.t(str(c["subtitle"]))
		if course_done.has(id):
			line = Loc.t("Hecho") + " · " + "★".repeat(int(course_done[id])) + "☆".repeat(3 - int(course_done[id])) + " · " + line
		body.add_child(_option_button("film", str(tints[n % tints.size()]), str(c["title"]), line, _start_lesson.bind(id)))
		n += 1
	body.add_child(_spacer(20.0))
	body.add_child(_centered(_para("Vídeos de los canales oficiales, con el reproductor de YouTube." if inside else "Los vídeos son de los canales oficiales y se abren en YouTube.", F_FOOT, _c("quiet"), font_regular)))
	body.add_child(_spacer(10.0, true))
	footer.add_child(_button("back", "Entrenar", _open_train_hub, _c("field"), _c("ink"), {"font_size": F_SUB, "height": 96.0, "icon": 44.0, "font": font_medium}))


## El siguiente final de la lista ("" si es el último).
func _next_cine_id() -> String:
	var all := Cine.lessons()
	for i in all.size():
		if str(all[i]["id"]) == str(lesson.get("id", "")) and i + 1 < all.size():
			return str(all[i + 1]["id"])
	return ""


## El vídeo del final, en YouTube (la app de YouTube o el navegador).
func _open_cine_video() -> void:
	var clip := Cine.clip_of(str(lesson.get("id", "")))
	if not clip.is_empty():
		OS.shell_open(Cine.video_url(clip))


# ───────────── El vídeo del final dentro de la app (cine, fase 2) ─────────────
# Arriba, el reproductor oficial de YouTube (nativo, encima de su hueco); debajo, el tablero, que sigue las jugadas
# del vídeo sin pasar nunca de la próxima pregunta. El vídeo se para solo justo antes de cada pregunta
# (core/cine_film.gd, portado de la rama cine-video). Responder es opcional: con ▶ en el reproductor se sigue viendo.
# Sin el complemento de Android (o sin marcas), la lección es la de la fase 1 y el vídeo se abre fuera, al final.

## Prepara el vídeo de la lección del cine abierta, si se puede verlo aquí.
func _film_open() -> void:
	if not Cine.is_lesson(str(lesson.get("id", ""))) or not CinePlayer.available():
		return
	var clip := Cine.clip_of(str(lesson["id"]))
	var data: Variant = clip.get("film")
	if not CineFilm.can_auto_pause(data):
		return
	var plies: Array = []
	for e: Dictionary in lesson.get("exercises", []):
		if str(e.get("kind", "")) == "move":
			plies.append(int(e.get("ply", 0)))
	if plies.size() != ((data as Dictionary)["stops"] as Array).size():
		return
	film = {"lesson": str(lesson["id"]), "data": data, "st": CineFilm.initial(), "plies": plies, "ply": -999, "answered": {}, "err": 0}
	cine_player = CinePlayer.new(str((clip["video"] as Dictionary)["id"]), Loc.language)


func _film_close() -> void:
	if cine_player != null:
		cine_player.close()
	cine_player = null
	if not film.is_empty():
		film = {}
		if video_slot != null and is_instance_valid(video_slot):
			_layout()


## Hueco del vídeo en píxeles de la ventana (donde se coloca la vista nativa).
func _film_rect() -> Rect2i:
	if video_slot == null or not is_instance_valid(video_slot):
		return Rect2i()
	var r := video_slot.get_global_rect()
	r.size.y -= 18.0
	var xf := get_viewport().get_final_transform() * video_slot.get_viewport().get_canvas_transform()
	var p := xf * r.position
	var q := xf * r.end
	return Rect2i(Vector2i(roundi(p.x), roundi(p.y)), Vector2i(roundi(q.x - p.x), roundi(q.y - p.y)))


## Cada fotograma: coloca u oculta el reproductor, le lee el tiempo y mueve el tablero.
func _film_tick() -> void:
	# Fuera de su lección (inicio, otra pantalla), el vídeo se cierra.
	if mode != "learn" or str(lesson.get("id", "")) != str(film["lesson"]) or cine_player == null:
		_film_close()
		return
	var covered := sheet_kind != "" or (confirm_node != null and is_instance_valid(confirm_node)) \
			or (progress != null and is_instance_valid(progress)) or (welcome != null and is_instance_valid(welcome))
	cine_player.show(not covered)
	cine_player.place(_film_rect())
	var snap := cine_player.snapshot()
	if snap.is_empty():
		return
	var err := int(snap.get("error", 0))
	if err != 0 and int(film["err"]) == 0:
		film["err"] = err
		_film_event({"type": "error", "code": err})
		return
	if not bool(snap.get("ready", false)):
		return
	_film_event({"type": "tick", "time": float(snap["time"]), "duration": float(snap["duration"]), "playing": int(snap["state"]) == 1, "now": float(Time.get_ticks_msec())})
	if film.is_empty():
		return
	var st: Dictionary = film["st"]
	if st["phase"] == "watching" or st["phase"] == "reveal":
		_film_board(float(snap["time"]))


## El tablero sigue al vídeo: la posición de cada segundo, con la jugada animada si es la siguiente.
func _film_board(t: float) -> void:
	var data: Dictionary = film["data"]
	var fr := CineFilm.frame_at(data, t, CineFilm.sync_cap(film["plies"], film["st"]))
	var ply := int(fr["ply"])
	if ply == int(film["ply"]) or str(fr["fen"]) == "":
		return
	var prev := int(film["ply"])
	film["ply"] = ply
	view.interactive = false
	view.board.set_arrows([])
	if ply == prev + 1 and str(fr["from"]) != "" and view.show_move(str(fr["from"]) + str(fr["to"])):
		return
	view.set_fen(str(fr["fen"]))
	if str(fr["from"]) != "":
		view.board.mark_last_move(Chess.sq_index(str(fr["from"])), Chess.sq_index(str(fr["to"])))


## Un evento para el director: ejecuta sus órdenes en el reproductor y cambia la pantalla si cambia la fase.
func _film_event(e: Dictionary) -> void:
	if film.is_empty():
		return
	var before: Dictionary = film["st"]
	var r := CineFilm.direct(film["data"], before, e)
	var now: Dictionary = r["state"]
	film["st"] = now
	if cine_player != null:
		cine_player.run(r["commands"], _film_rect())
	if now["phase"] != before["phase"] or int(now["stop"]) != int(before["stop"]) or now["missed"] != before["missed"] or int(now["error"]) != int(before["error"]):
		_film_changed(before, now)


func _film_changed(before: Dictionary, now: Dictionary) -> void:
	var stop := int(now["stop"])
	if before["phase"] == "asking" and ex_state in ["done", "fail"] and str(ex.get("kind", "")) == "move":
		film["answered"][int(before["stop"])] = true
	match str(now["phase"]):
		"asking":
			# Pausa: la pregunta de esta parada, en el tablero.
			var idx := _film_question_index(stop)
			if idx >= 0 and (lesson_ex != idx or not ex_state in ["play", "done", "fail"]):
				lesson_ex = idx
				film["ply"] = -999
				_show_lesson_step()
			elif int(now["error"]) != 0:
				_refresh()
		"reveal":
			if now["missed"] == "resumed" and (film["answered"] as Dictionary).has(stop):
				_film_event({"type": "answered"})
				return
			_film_watch()
		"watching":
			_film_watch()
		"ended":
			_film_finish()


## Índice en la lección de la pregunta de la parada `stop` (-1 si no hay).
func _film_question_index(stop: int) -> int:
	var n := 0
	var exercises: Array = lesson.get("exercises", [])
	for i in exercises.size():
		if str((exercises[i] as Dictionary).get("kind", "")) == "move":
			if n == stop:
				return i
			n += 1
	return -1


## Mientras se ve el vídeo: la tarjeta dice qué pasa y el tablero sigue las jugadas.
func _film_watch() -> void:
	run_id += 1
	_clear_explanation()
	learn_why_open = false
	ex = {}
	ex_text = ""
	ex_state = "film" if lesson_ex >= 0 else "intro"
	film["ply"] = -999
	view.interactive = false
	view.board.set_goals([])
	view.board.only_square = -1
	_refresh()


## Tras una pregunta, «Continuar»: el vídeo sigue desde la pausa.
func _film_continue() -> void:
	if film.is_empty():
		return
	var snap := cine_player.snapshot() if cine_player != null else {}
	var t: Variant = float(snap["time"]) if bool(snap.get("ready", false)) else null
	if ex_state in ["done", "fail"]:
		film["answered"][int(film["st"]["stop"])] = true
	if film["st"]["phase"] == "asking":
		_film_event({"type": "reveal", "time": t})
		if film["st"]["phase"] == "asking":
			# Sin vídeo (error): directamente a la siguiente pregunta, o a la explicación.
			if int(film["st"]["stop"]) + 1 < (film["plies"] as Array).size():
				_film_event({"type": "next"})
				lesson_ex = _film_question_index(int(film["st"]["stop"]))
				_show_lesson_step()
			else:
				_film_finish()
	else:
		_film_watch()


## «Ir a la pregunta» (sin esperar a la pausa), «Volver a la pregunta» (tras pasarla de largo) y «Terminar el vídeo».
func _film_ask() -> void:
	_film_event({"type": "ask", "now": float(Time.get_ticks_msec())})


func _film_back() -> void:
	_film_event({"type": "back", "now": float(Time.get_ticks_msec())})


func _film_end_now() -> void:
	_film_event({"type": "finish"})


## Acaba el vídeo: se cierra el reproductor y sigue la lección con la explicación de la partida.
func _film_finish() -> void:
	var exercises: Array = lesson.get("exercises", [])
	var first_info := exercises.size()
	for i in exercises.size():
		if str((exercises[i] as Dictionary).get("kind", "")) != "move":
			first_info = i
			break
	_film_close()
	lesson_ex = first_info
	_show_lesson_step()


## Texto de la tarjeta mientras se ve el vídeo.
func _film_card_text() -> String:
	var st: Dictionary = film["st"]
	if int(st["error"]) != 0:
		return "El vídeo no se puede ver aquí. Sigue con las preguntas; al final podrás abrirlo en YouTube."
	if st["missed"] == "resumed":
		return "Has seguido viendo el vídeo. Responder es opcional: si quieres pensarla, vuelve a la pregunta."
	if st["missed"] == "skipped":
		return "Has pasado de largo la pregunta. Responder es opcional: si quieres pensarla, vuelve a la pregunta."
	if st["phase"] == "watching":
		return "Pulsa ▶ en el vídeo: se parará solo justo antes de la jugada para preguntarte."
	if int(st["stop"]) + 1 < (film["plies"] as Array).size():
		return "Así siguió la partida. El vídeo se parará en la siguiente pregunta."
	return "Así acabó la partida."


func _train_family(fam: String) -> void:
	train_family = fam
	train_level = -1
	_start_training()


## Un disco del camino de niveles: uno superado se repasa; el actual, entrenamiento normal; los demás, bloqueados.
func _on_level_pressed(i: int, current: int) -> void:
	if i <= current:
		_open_level_list(i)
	elif _path_hint != null and is_instance_valid(_path_hint):
		_path_hint.text = Loc.f("El nivel %d se desbloquea cuando llegues a él.", i)


## Los problemas de un nivel, numerados del más fácil al más difícil, con una marca en los resueltos. Se toca uno
## para jugarlo.
func _open_level_list(lv: int) -> void:
	var list: Array = _level_lists().get(lv, [])
	var page := _page("levels")
	var body: VBoxContainer = page["body"]
	var footer: VBoxContainer = page["footer"]
	body.add_child(_spacer(20.0))
	body.add_child(_centered(_para(Loc.f("Nivel %d · %s", [lv, str(_rank(lv)[1])]), F_TITLE + 6, _c("ink"), font_display)))
	var solved := 0
	for item: Dictionary in list:
		if _puzzle_state(str(item["id"])) == 2:
			solved += 1
	body.add_child(_centered(_para(Loc.f("%d problemas · %d resueltos", [list.size(), solved]), F_BODY, _c("quiet"), font_medium)))
	body.add_child(_spacer(30.0))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(grid)
	for k in list.size():
		var item: Dictionary = list[k]
		var st := _puzzle_state(str(item["id"]))
		var tint := _tint("mint") if st == 2 else (_tint("butter") if st == 1 else [_c("surface"), _c("ink")])
		var b := _button("", "", _start_level_puzzle.bind(str(item["id"]), lv), tint[0], _c("ink"), {"height": 150.0, "radius": 40, "glow": _c("shadow")})
		b.custom_minimum_size = Vector2(160.0, 150.0)
		var num := _text(str(k + 1), F_HEAD, _c("ink"), font_display)
		num.set_anchors_preset(Control.PRESET_FULL_RECT)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(num)
		if st == 2:
			var tick := _icon("check", 40.0, _c("good"))
			tick.position = Vector2(112.0, 8.0)
			tick.size = Vector2(40.0, 40.0)
			tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(tick)
		grid.add_child(b)
	body.add_child(_spacer(26.0))
	body.add_child(_centered(_para("Verde, con marca: resuelto. Amarillo: intentado. Toca uno para jugarlo.", F_FOOT, _c("quiet"), font_regular)))
	body.add_child(_spacer(10.0, true))
	footer.add_child(_button("back", "Volver", _open_train_hub, _c("field"), _c("ink"), {"font_size": F_BODY, "height": 104.0, "icon": 48.0, "font": font_medium}))


## Juega un problema concreto de la lista de un nivel; después, el entrenamiento sigue con ese nivel.
func _start_level_puzzle(id: String, lv: int) -> void:
	if not _index_of.has(id):
		return
	mode = "train"
	train_family = ""
	train_level = lv
	review_session = false
	_close_progress()
	_start(int(_index_of[id]))


func _home_test() -> void:
	mode = "test"
	_close_progress()
	_next_test()


# ---------------------------------------------------------------- partidas contra el rival


## Ritmos de juego: nombre, minutos y segundos de incremento por jugada (como en las partidas oficiales y en las
## webs de ajedrez: «10+0» son 10 minutos por jugador; «15+10», 15 minutos y 10 segundos más por jugada).
const TIME_CONTROLS := [["Sin reloj", 0, 0], ["3+2", 3, 2], ["5+0", 5, 0], ["10+0", 10, 0], ["15+10", 15, 10], ["30+0", 30, 0], ["90+30", 90, 30], ["Otro", -1, -1]]

const GAME_LEVEL_TEXT := [
	"Se equivoca a menudo. Para tus primeras partidas.",
	"Ve las capturas sencillas, pero se despista.",
	"Calcula un par de jugadas y no regala piezas.",
	"Calcula más lejos y casi no falla en lo sencillo.",
	"Lo más fuerte que tiene la app. Piensa unos segundos.",
	"Stockfish, el motor de ajedrez, dentro de tu móvil. De muy fuerte a imbatible.",
]


func _unit_of(lesson_id: String) -> Dictionary:
	for unit: Dictionary in course:
		for l: Dictionary in unit["lessons"]:
			if str(l["id"]) == lesson_id:
				return unit
	return {}


func _is_last_of_unit(lesson_id: String) -> bool:
	var unit := _unit_of(lesson_id)
	if unit.is_empty():
		return false
	var lessons: Array = unit["lessons"]
	return str(lessons[lessons.size() - 1]["id"]) == lesson_id


const GROUP_TINTS := ["mint", "sky", "butter", "peach", "rose", "lilac"]
const GROUP_ICONS := ["piece_pawn", "piece_knight", "piece_bishop", "piece_rook", "piece_queen", "piece_king"]


## Grupos de nivel que se ofrecen: los cinco de la app y «Experto» (Stockfish) si está en el móvil, fuera de Kids
## y de War Chess (Stockfish no sabe jugar con blindajes).
func _level_groups() -> Array:
	var out: Array = range(Bot.APP_GROUPS)
	if local_engine != null and local_engine.available() and not kids and not game_war:
		out.append(Bot.APP_GROUPS)
	return out
## Último subnivel elegido en cada grupo (se guarda): sale marcado en la ventana de subniveles.
var game_sublevels := {}


## «Elo 1200–1590» de un grupo (solo con los subniveles medidos).
func _group_elo_span(g: int) -> String:
	var elos: Array = []
	for lv: int in Bot.group_levels(g):
		if Bot.level_elo(lv) < 0:
			return ""
		elos.append(Bot.level_elo(lv))
	if elos.is_empty():
		return ""
	if elos.size() == 1:
		return Loc.f("Elo %d", int(elos[0]))
	return Loc.f("Elo %d–%d", [int(elos[0]), int(elos[-1])])


## Al tocar un nivel: sus subniveles, con su Elo, en una ventana semitransparente con «Cancelar». Un nivel de un
## solo escalón («Muy difícil») empieza directamente.
func _pick_sublevel(g: int) -> void:
	# «Experto» (Stockfish) es de Premium.
	if g == Bot.APP_GROUPS and not Premium.active():
		_close_confirm()
		_open_premium_offer("experto")
		return
	var levels := Bot.group_levels(g)
	if levels.size() == 1:
		_start_level(int(levels[0]))
		return
	var column := _popup(Loc.t(str(Bot.GROUPS[g])), Loc.t("Elige un subnivel."))
	var last := int(game_sublevels.get(str(g), -1))
	for lv: int in levels:
		var elo := Bot.level_elo(lv)
		var text := Loc.f("Elo %d", elo) if elo >= 0 else Loc.t("Elo por medir")
		if Bot.uses_stockfish(lv) and Bot.sf_elo(lv) == 0:
			text = Loc.t("Fuerza máxima: no cuenta para tu nivel")
		var icon := "check" if lv == last else str(GROUP_ICONS[g])
		var b := _option_button(icon, str(GROUP_TINTS[g]), Bot.level_name(lv), text, func() -> void:
			_close_confirm()
			_start_level(lv))
		column.add_child(b)
	column.add_child(_para(Loc.f("Elo medido contra %s: escala de motores, no Elo FIDE.", "Stockfish"), F_FOOT, _c("quiet"), font_regular))
	var opts := {"font_size": F_BODY, "height": 116.0, "icon": 56.0, "radius": 58}
	column.add_child(_button("back", "Cancelar", _close_confirm, _c("field"), _c("ink"), opts))


func _start_level(lv: int) -> void:
	game_sublevels[str(Bot.group_of(lv))] = lv
	_save_settings()
	var cfg := {"variant": "", "level": lv, "title": Loc.f("Partida · %s", Bot.level_name(lv)), "text": "", "kids": "", "unit": "", "clock": []}
	if game_war and not kids:
		cfg["variant"] = "war"
		cfg["title"] = Loc.f("War Chess · %s", Bot.level_name(lv))
		cfg["text"] = WAR_RULES
	_start_game(cfg, -1)


## Elegir rival: color y cinco niveles (cada uno con sus subniveles).
## Elegir rival. Las opciones de la partida (modalidad, piezas, ritmo; en Kids, piezas y mundo) van en una ventana
## emergente con «OK» (Pablo, 17-11), que sale sola al entrar desde el inicio (`ask`); en la página queda una ficha
## con lo elegido para volver a abrirla. Debajo, los cinco niveles (cada uno con sus subniveles).
func _open_game_setup(ask: bool = false) -> void:
	if sheet_kind != "":
		_close_options()
	var page := _page("game_setup")
	var body: VBoxContainer = page["body"]
	var footer: VBoxContainer = page["footer"]
	var tile := _icon_tile("piece_knight", "mint", 156.0, 98.0)
	tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(tile)
	body.add_child(_spacer(20.0))
	body.add_child(_centered(_para("Juega una partida", F_TITLE + 12, _c("ink"), font_display)))
	body.add_child(_centered(_para("Pon en práctica lo que has aprendido.", F_SUB, _c("quiet"), font_medium)))
	body.add_child(_spacer(30.0))
	body.add_child(_text("TU PARTIDA", F_CAP, _c("quiet"), font_semibold))
	body.add_child(_spacer(12.0))
	body.add_child(_option_button("shield" if game_war and not kids else "sliders", "lilac", _game_options_summary(), Loc.t("Toca para cambiar"), _open_game_options))
	body.add_child(_spacer(30.0))
	body.add_child(_text("RIVAL", F_CAP, _c("quiet"), font_semibold))
	body.add_child(_spacer(12.0))
	# Los cinco grupos de siempre (y «Experto» con Stockfish); cada uno abre sus subniveles (Bot.group_levels).
	for g: int in _level_groups():
		var text := Loc.t(str(GAME_LEVEL_TEXT[g]))
		var span := _group_elo_span(g)
		if span != "":
			text += "\n" + span
		body.add_child(_option_button(str(GROUP_ICONS[g]), str(GROUP_TINTS[g]), str(Bot.GROUPS[g]), text, _pick_sublevel.bind(g)))
		body.add_child(_spacer(14.0))
	body.add_child(_spacer(10.0, true))
	var frow := HBoxContainer.new()
	frow.add_theme_constant_override("separation", 16)
	footer.add_child(frow)
	if not kids:
		frow.add_child(_button("trend", "Mis partidas", _open_my_games_from.bind("setup"), _tint("lilac")[0], _c("ink"), {"font_size": F_SUB, "height": 96.0, "icon": 44.0, "font": font_medium}))
	frow.add_child(_button("close", "Cancelar", _close_game_setup, _c("field"), _c("ink"), {"font_size": F_SUB, "height": 96.0, "icon": 40.0, "font": font_medium}))
	for c: Node in frow.get_children():
		(c as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if ask:
		_open_game_options()


## «War Chess · Blancas · 5+0» (en Kids, piezas y mundo).
func _game_options_summary() -> String:
	var parts: Array = []
	if not kids:
		parts.append(Loc.t("War Chess" if game_war else "Clásica"))
	parts.append(Loc.t(str(["Blancas", "Negras", "Al azar"][clampi(game_pick_color, 0, 2)])))
	if kids:
		parts.append(Loc.t(str(WORLD_NAMES[maxi(0, WORLDS.find(kids_world))])))
	else:
		var tc := _time_control()
		parts.append(Loc.t("Sin reloj") if tc[0] == 0 else ("%d+%d" % [tc[0], tc[1]]))
	return " · ".join(parts)


var _game_opts_box: VBoxContainer
var _game_opts_scroll: ScrollContainer


## La ventana de las opciones de la partida (semitransparente, con «OK»). Los cambios valen al momento; al cerrarla
## (con «OK» o tocando fuera) la página se rehace con lo elegido.
func _open_game_options() -> void:
	var column := _popup(Loc.t("Tu partida"), "")
	_game_opts_scroll = ScrollContainer.new()
	_game_opts_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_game_opts_scroll)
	_game_opts_box = VBoxContainer.new()
	_game_opts_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_game_opts_scroll.add_child(_game_opts_box)
	_fill_game_options()
	column.add_child(_spacer(6.0))
	# «OK» lleva al paso siguiente, elegir el nivel, en otra ventana igual (Pablo, 22 nov: la página de después
	# despistaba). Tocar fuera solo cierra.
	var ok := _button("check", "OK", func() -> void:
		_pick_level_next = true
		_close_confirm(), _c("accent"), _c("ink"), {"font_size": F_BODY, "height": 116.0, "icon": 56.0, "radius": 58})
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(ok)
	_confirm_on_close = func() -> void:
		_game_opts_box = null
		_game_opts_scroll = null
		if progress != null and is_instance_valid(progress) and progress_kind == "game_setup":
			_reopen_game_setup()
			if _pick_level_next:
				_open_level_picker.call_deferred()
		_pick_level_next = false


var _pick_level_next := false


## Elegir el nivel del rival, en una ventana: los cinco niveles (cada uno abre sus subniveles).
func _open_level_picker() -> void:
	var column := _popup(Loc.t("Elige el nivel del rival"), "")
	for g: int in _level_groups():
		var text := Loc.t(str(GAME_LEVEL_TEXT[g]))
		var span := _group_elo_span(g)
		if span != "":
			text += "\n" + span
		column.add_child(_option_button(str(GROUP_ICONS[g]), str(GROUP_TINTS[g]), str(Bot.GROUPS[g]), text, _pick_sublevel.bind(g)))
	column.add_child(_button("back", "Cancelar", _close_confirm, _c("field"), _c("ink"), {"font_size": F_BODY, "height": 116.0, "icon": 56.0, "radius": 58}))


func _fill_game_options() -> void:
	if _game_opts_box == null or not is_instance_valid(_game_opts_box):
		return
	for c in _game_opts_box.get_children():
		_game_opts_box.remove_child(c)
		c.queue_free()
	var box := _game_opts_box
	if not kids:
		box.add_child(_text("MODALIDAD", F_CAP, _c("quiet"), font_semibold))
		box.add_child(_spacer(12.0))
		box.add_child(_segments(["Clásica", "War Chess"], 1 if game_war else 0, _set_game_war, ["piece_knight", "shield"]))
		if game_war:
			box.add_child(_spacer(10.0))
			box.add_child(_para(WAR_RULES, F_FOOT, _c("quiet"), font_regular))
		box.add_child(_spacer(26.0))
	box.add_child(_text("TUS PIEZAS", F_CAP, _c("quiet"), font_semibold))
	box.add_child(_spacer(12.0))
	box.add_child(_segments(["Blancas", "Negras", "Al azar"], game_pick_color, _set_game_color, ["sun", "moon", "why"]))
	if kids:
		box.add_child(_spacer(26.0))
		box.add_child(_text("MUNDO", F_CAP, _c("quiet"), font_semibold))
		box.add_child(_spacer(12.0))
		box.add_child(_world_tiles())
	else:
		box.add_child(_spacer(26.0))
		box.add_child(_text("RITMO", F_CAP, _c("quiet"), font_semibold))
		box.add_child(_spacer(12.0))
		box.add_child(_segments(TIME_CONTROLS.slice(0, 4).map(func(t: Array) -> String: return str(t[0])), game_tc_pick, _set_time_control))
		box.add_child(_spacer(10.0))
		box.add_child(_segments(TIME_CONTROLS.slice(4).map(func(t: Array) -> String: return str(t[0])), game_tc_pick - 4, _set_time_control_from.bind(4)))
		if int(TIME_CONTROLS[game_tc_pick][1]) < 0:
			box.add_child(_spacer(14.0))
			box.add_child(_stepper("Minutos por jugador", custom_minutes, _step_minutes))
			box.add_child(_stepper("Segundos más por jugada", custom_increment, _step_increment))
		var tc := _time_control()
		var about := "Sin prisa: piensa lo que necesites. Puedes deshacer y pedir pistas." if tc[0] == 0 else Loc.f("%d minutos por jugador%s. Con reloj no hay deshacer ni pistas, como en una partida oficial; si se te acaba el tiempo, pierdes.", [tc[0], Loc.t(" y %d segundos más por jugada") % tc[1] if tc[1] > 0 else ""])
		box.add_child(_spacer(10.0))
		box.add_child(_para(about, F_FOOT, _c("quiet"), font_regular))
	_fit_game_options.call_deferred()


## La ventana no puede salirse de la pantalla: si las opciones no caben, se desplazan.
func _fit_game_options() -> void:
	if _game_opts_scroll == null or not is_instance_valid(_game_opts_scroll):
		return
	var want := _game_opts_box.get_combined_minimum_size().y
	_game_opts_scroll.custom_minimum_size.y = minf(want, maxf(400.0, size.y - 560.0))


## Tras cambiar una opción: se rehace la ventana si está abierta y, si no, la página.
func _game_options_changed() -> void:
	if _game_opts_box != null and is_instance_valid(_game_opts_box):
		_fill_game_options()
	else:
		_reopen_game_setup()


func _set_game_color(i: int) -> void:
	game_pick_color = i
	_game_options_changed()


## Reglas de War Chess, en corto (página de partida y comienzo de la partida). Ver docs/war-chess.md.
const WAR_RULES := "War Chess: se juega como el ajedrez, pero en lugar de mover puedes blindar una pieza (no el rey): selecciónala y toca «Blindar». Atacar una pieza blindada no la captura: le rompe el blindaje y la atacante se queda en su casilla. Cada pieza se blinda una vez y pierde el blindaje si se mueve. Un peón blindado es una trinchera: solo otro peón la rompe de un golpe; las piezas necesitan dos. No se puede blindar dos turnos seguidos ni repetir una posición por tercera vez."


## Nombre en español de la pieza (para Loc.t): «caballo», «dama»…
static func _piece_noun(p: int) -> String:
	return str(["", "peón", "caballo", "alfil", "torre", "dama", "rey"][p & 7])


func _set_game_war(i: int) -> void:
	game_war = i == 1 and not kids
	_game_options_changed()


func _set_time_control(i: int) -> void:
	game_tc_pick = clampi(i, 0, TIME_CONTROLS.size() - 1)
	_game_options_changed()


func _set_time_control_from(i: int, offset: int) -> void:
	_set_time_control(i + offset)


func _step_minutes(d: int) -> void:
	var steps := [1, 2, 3, 5, 10, 15, 20, 25, 30, 45, 60, 90, 120]
	var at := steps.find(custom_minutes)
	custom_minutes = int(steps[clampi((at if at >= 0 else 4) + d, 0, steps.size() - 1)])
	_game_options_changed()


func _step_increment(d: int) -> void:
	var steps := [0, 1, 2, 3, 5, 10, 15, 20, 30, 60]
	var at := steps.find(custom_increment)
	custom_increment = int(steps[clampi((at if at >= 0 else 0) + d, 0, steps.size() - 1)])
	_game_options_changed()


## Minutos e incremento (segundos) del ritmo elegido; [0, 0] sin reloj (y siempre en el nivel Kids).
func _time_control() -> Array:
	if kids:
		return [0, 0]
	var t: Array = TIME_CONTROLS[game_tc_pick]
	if int(t[1]) < 0:
		return [custom_minutes, custom_increment]
	return [int(t[1]), int(t[2])]


## Vuelve a dibujar la página de elegir partida sin perder por dónde iba.
func _reopen_game_setup() -> void:
	var scroll := progress_scroll.scroll_vertical if progress_scroll != null and is_instance_valid(progress_scroll) else 0
	_open_game_setup()
	if progress_scroll != null:
		progress_scroll.set_deferred("scroll_vertical", scroll)


## Fila con un número y sus botones de menos y más.
func _stepper(label: String, value: int, on_step: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var name_label := _para(label, F_SUB, _c("ink"), font_medium)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_label)
	var minus := _button("", "−", on_step.bind(-1), _c("field"), _c("ink"), {"font_size": F_TITLE, "height": 96.0, "font": font_display})
	minus.custom_minimum_size.x = 110.0
	row.add_child(minus)
	var shown := _para(str(value), F_TITLE, _c("ink"), font_display)
	shown.custom_minimum_size.x = 110.0
	shown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(shown)
	var plus := _button("", "+", on_step.bind(1), _c("field"), _c("ink"), {"font_size": F_TITLE, "height": 96.0, "font": font_display})
	plus.custom_minimum_size.x = 110.0
	row.add_child(plus)
	return row


func _close_game_setup() -> void:
	_close_progress()
	if mode != "game" or game_state == "":
		_open_home()


# ---------------------------------------------------------------- partida online

func _open_online_home() -> void:
	online_status = ""
	_open_online()


func _open_online() -> void:
	if sheet_kind != "":
		_close_options()
	var scroll := progress_scroll.scroll_vertical if progress_kind == "online" and progress_scroll != null and is_instance_valid(progress_scroll) else 0
	var page := _page("online")
	var body: VBoxContainer = page["body"]
	var footer: VBoxContainer = page["footer"]
	body.add_child(_spacer(10.0, true))
	if online_busy:
		var tile := _icon_tile("piece_queen", "sky", 200.0, 124.0)
		tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		body.add_child(tile)
		body.add_child(_spacer(24.0))
	body.add_child(_centered(_para("Buscando rival" if online_busy else "Partida online", F_LARGE, _c("ink"), font_display)))
	var about := "Elige un ritmo. Si alguien espera en ese espacio, jugáis ya; si no, esperas tú a que entre un rival." if online_name != "" else ""
	if online_busy:
		about = Loc.f("Espacio %s. La partida empieza en cuanto entre otro jugador.", Online.space_label(online_space))
	if about != "":
		body.add_child(_spacer(10.0))
		body.add_child(_centered(_para(about, F_BODY + 2, _c("quiet"), font_medium)))
	if online_busy:
		# Reloj de láminas con el tiempo de espera.
		body.add_child(_spacer(56.0))
		var clock := FlipClock.new()
		clock.start_ms = online_wait_ms
		clock.font = font_display
		clock.ink = _c("ink")
		clock.dots = _c("quiet")
		if dark:
			clock.set_dark(true)
		clock.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		body.add_child(clock)
		body.add_child(_spacer(10.0))
		body.add_child(_centered(_para("Tiempo de espera", F_SUB, _c("quiet"), font_medium)))
	if online_busy and online_note != "":
		body.add_child(_spacer(20.0))
		body.add_child(_centered(_para(online_note, F_BODY, _c("accent_text"), font_semibold)))
	if online_busy and online_bot_offer:
		body.add_child(_spacer(30.0))
		body.add_child(_bot_offer_block())
	if online_status != "":
		body.add_child(_spacer(20.0))
		body.add_child(_centered(_para(online_status, F_BODY, _c("bad"), font_medium)))
	body.add_child(_spacer(30.0))
	if not online_busy and online_name == "":
		# La primera vez: el nombre con el que te verán tus rivales.
		body.add_child(_name_block())
	elif not online_busy:
		# Modalidad: cada una tiene sus espacios (los de War Chess llevan una «w» delante del ritmo).
		body.add_child(_caption("Modalidad"))
		body.add_child(_segments(["Clásica", "War Chess"], 1 if online_war else 0, _set_online_war, ["piece_knight", "shield"]))
		if online_war:
			body.add_child(_spacer(10.0))
			body.add_child(_para(WAR_RULES, F_FOOT + 2, _c("quiet"), font_regular))
		body.add_child(_spacer(26.0))
		body.add_child(_caption("Espacios"))
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 22)
		grid.add_theme_constant_override("v_separation", 22)
		var shown: Array = Online.SPACES.map(func(r: String) -> String: return Online.space_of(r, online_war))
		# Los personalizados donde alguien espera (de esta modalidad), y el mío.
		var extra: Array = []
		for r in online_spaces.keys():
			if not shown.has(str(r)) and Online.is_war(str(r)) == online_war:
				extra.append(str(r))
		var mine := Online.space_of("%d+%d" % [int(online_custom[0]), int(online_custom[1])], online_war)
		if online_space == mine and not shown.has(mine) and not extra.has(mine):
			extra.append(mine)
		extra.sort_custom(func(a: String, b: String) -> bool: return _rhythm_secs(a) < _rhythm_secs(b))
		shown.append_array(extra)
		for r: String in shown:
			grid.add_child(_space_tile(r, int(online_spaces.get(r, 0))))
		grid.add_child(_space_tile("", 0))
		body.add_child(grid)
		body.add_child(_spacer(20.0))
		body.add_child(_centered(_para(Loc.f("Juegas como «%s». Tu rival verá tu nombre, tu nivel de táctica y tu icono.", online_name), F_SUB, _c("quiet"), font_regular)))
		body.add_child(_spacer(20.0))
		body.add_child(_option_button("trend", "mint", "Mis partidas", "Rivales, resultados y estadísticas.", _open_my_games_from.bind("online")))
		body.add_child(_spacer(16.0))
		body.add_child(_card_button("Cambiar mi nombre", _change_online_name, _c("field"), _c("ink"), F_SUB, "sliders"))
		if avatar == "foto" and _avatar_photo() != null:
			body.add_child(_spacer(10.0))
			body.add_child(_card_button(Loc.f("Enseñar mi foto al rival: %s", ("sí" if online_photo else "no")), _toggle_online_photo, _c("field"), _c("ink"), F_SUB, "check" if online_photo else "eye"))
		body.add_child(_spacer(10.0))
		body.add_child(_card_button("Normas de las partidas online", _open_online_rules.bind(""), _c("field"), _c("ink"), F_SUB, "rules"))
		if not online_blocked.is_empty():
			body.add_child(_spacer(10.0))
			body.add_child(_card_button(Loc.f("Jugadores bloqueados: %d", online_blocked.size()), _open_blocked, _c("field"), _c("ink"), F_SUB, "block"))
		_poll_lobby()
	body.add_child(_spacer(10.0, true))
	footer.add_child(_button("close", "Cancelar" if online_busy else "Volver", _close_online, _c("field"), _c("ink"), {"font_size": F_BODY, "height": 104.0, "icon": 48.0, "font": font_medium}))
	if scroll > 0 and progress_scroll != null:
		progress_scroll.set_deferred("scroll_vertical", scroll)


## Nombre de un ritmo: «Sin reloj», «5+3», «20 min».
func _rhythm_name(r: String) -> String:
	return Online.rhythm_label(r)


## Duración estimada (segundos): minutos más 40 veces el incremento, como en Lichess.
func _rhythm_secs(r: String) -> int:
	var p := Online.rhythm_parts(r)
	return int(p[0]) * 60 + 40 * int(p[1])


## Tipo de partida por su duración estimada (los cortes de Lichess): [nombre, icono].
func _rhythm_kind(r: String) -> Array:
	var secs := _rhythm_secs(r)
	if secs == 0:
		return ["Sin prisa", "infinity"]
	if secs < 180:
		return ["Bala", "fast"]
	if secs < 480:
		return ["Blitz", "fast"]
	if secs < 1500:
		return ["Rápida", "clock"]
	return ["Clásica", "slow"]


## Un espacio: el ritmo en grande, su tipo y si hay alguien esperando (en verde: juegas ya). "" = otro ritmo.
func _space_tile(r: String, waiting: int) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var mint := _tint("mint")
	var live := waiting > 0
	_style_button(b, mint[0] if live else _c("surface"), _c("ink"), 44, F_BODY, font_semibold, _c("shadow"), mint[1] if live else Color(0, 0, 0, 0))
	b.pressed.connect(_online_enter.bind(r) if r != "" else _open_online_custom)
	var pad := _pad(26, 24, 26, 24)
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(pad)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(col)
	var kind := _rhythm_kind(r) if r != "" else ["Elige minutos y segundos", "sliders"]
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_icon(str(kind[1]), 54.0, mint[1] if live else _c("quiet")))
	var big := _para(_rhythm_name(r) if r != "" else "Otro ritmo", F_TITLE2 if r != "" else F_HEAD, _c("ink"), font_display)
	big.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	big.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(big)
	col.add_child(top)
	col.add_child(_para(str(kind[0]), F_SUB, _c("quiet"), font_medium))
	var state := ""
	if r == "":
		state = "Personalizado"
	elif not online_spaces_ok:
		state = "Mirando…"
	elif waiting == 1:
		state = "1 esperando · juegas ya"
	elif waiting > 1:
		state = Loc.f("%d esperando · juegas ya", waiting)
	else:
		state = "Nadie: esperas tú"
	col.add_child(_para(state, F_SUB, mint[1] if live else _c("quiet"), font_semibold if live else font_regular))
	var fit := func() -> void:
		if is_instance_valid(b) and is_instance_valid(pad):
			b.custom_minimum_size = Vector2(0.0, pad.get_combined_minimum_size().y)
	pad.minimum_size_changed.connect(fit)
	fit.call()
	b.set_meta("label", r if r != "" else "otro")
	if live and (view == null or view.board.anim_mode != Board3D.Anim.NONE):
		_wiggle(b)
	return b


## Sacudida ligera y suave, de vez en cuando, para que se vea dónde hay alguien esperando (Pablo, 16 nov). Gira un
## poco alrededor del centro (los contenedores no tocan el giro); con «Sin animaciones», nada.
func _wiggle(c: Control) -> void:
	c.resized.connect(func() -> void: c.pivot_offset = c.size * 0.5)
	c.pivot_offset = c.size * 0.5
	var tw := c.create_tween().set_loops()
	tw.tween_interval(0.5 + randf() * 0.4)
	for deg: float in [1.6, -1.3, 0.9, -0.5, 0.2, 0.0]:
		tw.tween_property(c, "rotation_degrees", deg, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_interval(2.2)


## Mientras se ve la lista de espacios, se mira cada 3 s quién espera en cada uno.
func _poll_lobby() -> void:
	if _lobby_polling:
		return
	_lobby_polling = true
	while progress_kind == "online" and not online_busy and progress != null and is_instance_valid(progress) and online_name != "":
		var l: Dictionary = await online.lobby()
		if not (progress_kind == "online" and not online_busy and progress != null and is_instance_valid(progress)):
			break
		var counts := {}
		var spaces: Dictionary = l.get("spaces", {})
		for r in spaces.keys():
			counts[str(r)] = (spaces[r] as Array).size()
		var was_ok := online_spaces_ok
		if bool(l.get("ok", false)) and (counts != online_spaces or not was_ok):
			online_spaces = counts
			online_spaces_ok = true
			_open_online()
		await get_tree().create_timer(3.0).timeout
	_lobby_polling = false


## Entrar en un espacio: la primera vez, antes, las normas.
func _online_enter(space: String) -> void:
	if online_rules_ok < ONLINE_RULES_VERSION:
		_open_online_rules(space)
		return
	_online_search(space)


## Normas de las partidas online. Con `space`, para aceptarlas y entrar en ese espacio.
func _open_online_rules(space: String) -> void:
	var page := _page("online_rules")
	var body: VBoxContainer = page["body"]
	var footer: VBoxContainer = page["footer"]
	body.add_child(_spacer(10.0))
	var tile := _icon_tile("rules", "lilac", 180.0, 112.0)
	tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(tile)
	body.add_child(_spacer(20.0))
	body.add_child(_centered(_para("Normas de las partidas online", F_TITLE, _c("ink"), font_display)))
	body.add_child(_spacer(24.0))
	var rules := [
		["g_buena", "mint", "Respeto", "Juega con deportividad. Los gestos son para animar, no para molestar."],
		["sliders", "sky", "Tu nombre", "Sin insultos, sin datos personales y sin hacerte pasar por otra persona."],
		["bot", "peach", "Sin ayudas", "Nada de programas, motores ni otra persona que te diga las jugadas."],
		["clock", "butter", "No hagas perder el tiempo", "Si no puedes seguir, ríndete en lugar de dejar al rival esperando. Si te toca, no juegas y no contestas a «¿Sigues ahí?», tu rival puede ganar la partida por abandono."],
		["report", "rose", "Denuncias", "Puedes denunciar o bloquear a un rival desde su nombre, en la partida. Revisamos las denuncias y podemos impedir jugar online a quien no cumpla."],
		["eye", "lilac", "Lo que se comparte", "Tu rival ve tu nombre, tu nivel, tu icono y tu foto si la enseñas. Las partidas se borran del servidor al terminar."],
	]
	for r: Array in rules:
		body.add_child(_icon_row(str(r[0]), str(r[1]), str(r[2]), str(r[3])))
		body.add_child(_spacer(18.0))
	body.add_child(_spacer(10.0, true))
	if space != "":
		var tint := _tint("mint")
		footer.add_child(_button("check", "Acepto, a jugar", _accept_online_rules.bind(space), tint[0], tint[1], {"font_size": F_BODY, "height": 116.0, "icon": 56.0}))
		footer.add_child(_spacer(14.0))
	footer.add_child(_button("back", "Volver", _open_online, _c("field"), _c("ink"), {"font_size": F_BODY, "height": 104.0, "icon": 48.0, "font": font_medium}))


func _accept_online_rules(space: String) -> void:
	online_rules_ok = ONLINE_RULES_VERSION
	_save_settings()
	_online_search(space)


## Otro ritmo: minutos y segundos por jugada.
const ONLINE_MINUTES := [1, 2, 3, 4, 5, 6, 7, 8, 10, 12, 15, 20, 25, 30, 40, 45, 60, 90, 120, 180]
const ONLINE_SECONDS := [0, 1, 2, 3, 5, 8, 10, 15, 20, 30, 45, 60]


func _open_online_custom() -> void:
	var page := _page("online_custom")
	var body: VBoxContainer = page["body"]
	var footer: VBoxContainer = page["footer"]
	body.add_child(_spacer(10.0, true))
	body.add_child(_centered(_para("Otro ritmo", F_LARGE, _c("ink"), font_display)))
	body.add_child(_spacer(10.0))
	body.add_child(_centered(_para("Tu propio espacio: entrará quien elija el mismo ritmo.", F_BODY + 2, _c("quiet"), font_medium)))
	body.add_child(_spacer(40.0))
	body.add_child(_stepper("Minutos por jugador", int(online_custom[0]), _step_online_custom.bind(0)))
	body.add_child(_spacer(20.0))
	body.add_child(_stepper("Segundos más por jugada", int(online_custom[1]), _step_online_custom.bind(1)))
	body.add_child(_spacer(30.0))
	var r := Online.space_of("%d+%d" % [int(online_custom[0]), int(online_custom[1])], online_war)
	body.add_child(_centered(_para(Loc.f("%s · %s", [Online.space_label(r), str(_rhythm_kind(r)[0])]), F_HEAD, _c("ink"), font_semibold)))
	body.add_child(_spacer(10.0, true))
	var tint := _tint("sky")
	footer.add_child(_button("shield" if online_war else "piece_queen", Loc.f("Buscar rival · %s", Online.space_label(r)), _online_enter.bind(r), tint[0], tint[1], {"font_size": F_BODY, "height": 116.0, "icon": 56.0}))
	footer.add_child(_spacer(14.0))
	footer.add_child(_button("back", "Volver", _open_online, _c("field"), _c("ink"), {"font_size": F_BODY, "height": 104.0, "icon": 48.0, "font": font_medium}))


func _step_online_custom(d: int, which: int) -> void:
	var steps: Array = ONLINE_MINUTES if which == 0 else ONLINE_SECONDS
	var at := steps.find(int(online_custom[which]))
	online_custom[which] = int(steps[clampi((at if at >= 0 else 0) + d, 0, steps.size() - 1)])
	_save_settings()
	_open_online_custom()


## Jugadores bloqueados, para desbloquearlos.
func _open_blocked() -> void:
	var page := _page("online_blocked")
	var body: VBoxContainer = page["body"]
	var footer: VBoxContainer = page["footer"]
	body.add_child(_spacer(10.0))
	body.add_child(_centered(_para("Jugadores bloqueados", F_TITLE, _c("ink"), font_display)))
	body.add_child(_spacer(10.0))
	body.add_child(_centered(_para("No te emparejamos con ellos. Si desbloqueas a alguien, podréis volver a jugar.", F_SUB, _c("quiet"), font_regular)))
	body.add_child(_spacer(24.0))
	if online_blocked.is_empty():
		body.add_child(_centered(_para("No has bloqueado a nadie.", F_BODY, _c("quiet"), font_medium)))
	for id in online_blocked.keys():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		var l := _para(str(online_blocked[id]), F_BODY, _c("ink"), font_semibold)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(l)
		row.add_child(_button("close", "Desbloquear", _unblock.bind(str(id)), _c("field"), _c("ink"), {"font_size": F_SUB, "height": 96.0, "icon": 44.0, "font": font_medium}))
		body.add_child(row)
		body.add_child(_spacer(14.0))
	body.add_child(_spacer(10.0, true))
	footer.add_child(_button("back", "Volver", _open_online, _c("field"), _c("ink"), {"font_size": F_BODY, "height": 104.0, "icon": 48.0, "font": font_medium}))


func _unblock(id: String) -> void:
	online_blocked.erase(id)
	_save_settings()
	if online_blocked.is_empty():
		_open_online()
	else:
		_open_blocked()


func _online_search(space: String = "") -> void:
	if space != "":
		online_space = space
		_save_settings()
	online_status = ""
	online_note = ""
	online_busy = true
	online_wait_ms = Time.get_ticks_msec()
	online_bot_offer = false
	_wait_gen += 1
	var elsewhere := 0
	for r in online_spaces.keys():
		if str(r) != online_space:
			elsewhere += int(online_spaces[r])
	_offer_bot_later(_wait_gen, Online.bot_offer_s(elsewhere))
	online_rival = {}
	_rival_tex = null
	online.my_profile = _online_profile()
	online.blocked = online_blocked
	var gr := GameLog.game_rating(_log())
	online.my_game_rating = {} if kids or int(gr["n"]) == 0 else {"r": roundi(float(gr["r"])), "rd": clampi(roundi(float(gr["rd"])), 30, 350), "n": int(gr["n"])}
	_open_online()
	online.start(online_space)


func _set_online_war(i: int) -> void:
	online_war = i == 1
	_save_settings()
	_open_online()


func _close_online() -> void:
	online.leave()
	online_busy = false
	online_bot_offer = false
	_wait_gen += 1
	_close_progress()
	_open_home()


## Me he unido a una partida: si quien esperaba tarda en volver a la app (la tenía minimizada), se dice.
func _online_matched() -> void:
	await get_tree().create_timer(1.5).timeout
	if online.phase == "joining" and online_busy and progress_kind == "online":
		var who := str(online.rival.get("nombre", ""))
		online_note = Loc.f("Has entrado en la partida de %s. Esperando a que vuelva a la app (como mucho, un minuto)…", who) if who != "" else Loc.t("Has entrado en una partida. Esperando a que tu rival vuelva a la app (como mucho, un minuto)…")
		_open_online()


func _online_retry() -> void:
	if online_busy and progress_kind == "online":
		online_note = Loc.t("Tu rival no volvió a tiempo. Seguimos buscando…")
		_open_online()


func _online_started(color: int) -> void:
	_ping_at = -1
	online_busy = false
	online_note = ""
	online_bot_offer = false
	_wait_gen += 1
	var clock: Array = Online.rhythm_parts(online.rhythm)
	var war := Online.is_war(online.rhythm)
	_start_game({"variant": "war" if war else "", "level": 0, "title": "War Chess online" if war else "Partida online", "text": WAR_RULES if war else "", "kids": "", "unit": "", "clock": clock if int(clock[0]) > 0 else [], "online": true}, color)


## Jugada del rival, que llega por la red.
func _online_move(uci: String) -> void:
	# «Tu rival está pensando»: ya ha movido.
	_close_thinking()
	if mode != "game" or not bool(game.get("online", false)) or game_state != "think":
		return
	if game_back > 0:
		# Mirando jugadas anteriores: vuelve al directo y se ve la jugada del rival.
		_online_pending.append(uci)
		_game_browse(-99)
		return
	var pos := view.board.chess.copy()
	var m := pos.find_uci(uci)
	if m < 0:
		return
	var san := SanEs.san(pos, m)
	view.show_move(uci)
	game_history.append(view.board.chess.fen())
	game_moves.append(uci)
	game_note = Loc.f("El rival ha jugado %s.", san)
	var war_note := _war_rival_note(pos, m)
	if war_note != "":
		game_note = war_note
	if _game_check_end(pos, m):
		return
	if view.board.chess.in_check():
		game_note = Loc.f("El rival ha jugado %s: tu rey está en jaque.", san)
	if game_clocked and not online.my_turn_open():
		# Con reloj: ves su jugada, pero tu turno empieza cuando él pulsa su reloj.
		game_state = "think"
		view.interactive = false
		_refresh()
		return
	game_state = "play"
	game_clock_side = game_color
	view.interactive = true
	_refresh()


## Ha cambiado el reloj online (una pulsación): si el rival ya ha pulsado tras su jugada, me toca.
func _online_clock_changed() -> void:
	if mode != "game" or not bool(game.get("online", false)) or not game_clocked:
		return
	if game_state == "think" and game_back == 0 and view.board.chess.turn == game_color and online.my_turn_open():
		game_state = "play"
		game_clock_side = game_color
		view.interactive = true
	_refresh()


func _online_ended(reason: String, winner: int) -> void:
	if mode != "game" or not bool(game.get("online", false)) or game_state == "over":
		return
	if game_back > 0:
		game_back = 0
		_online_pending = []
		view.set_fen(str(game_history[game_history.size() - 1]))
	_close_idle_popups()
	if reason == "tiempo":
		# Se le acabó el tiempo a uno (lo calculan los dos con las horas del servidor).
		_game_flag(1 - winner)
		_sfx("leccion" if winner == game_color else "error")
		return
	game_state = "over"
	if reason == "ausencia" and winner != game_color:
		game_won = -1
		game_result = "No contestabas y tu rival ha ganado por abandono."
		view.interactive = false
		_sfx("error")
		_refresh()
		return
	game_won = 1
	game_result = "Tu rival no contestaba: has ganado por abandono." if reason == "ausencia" else "Tu rival ha abandonado la partida: ¡has ganado!"
	view.interactive = false
	_sfx("leccion")
	_refresh()


## «¿Sigues ahí?»: a quien le toca y lleva idle_limit_ms sin jugar se le pregunta (con vibración); si no contesta,
## a su rival se le ofrece ganar por abandono pasado el tiempo de respuesta y un margen. Cerrar la pregunta tocando
## fuera también vale como «Sigo aquí»; cerrar la oferta, como «Seguir esperando».
var _idle_ask_node: Control = null
var _idle_offer_node: Control = null
var _idle_snooze_until := 0


func _online_idle_tick() -> void:
	if online.phase != "playing":
		return
	_ping_tick()
	var limit := Online.idle_limit_ms(online.base_ms)
	var mover := online.on_move()
	if _idle_ask_node != null and not is_instance_valid(_idle_ask_node):
		# Se cerró tocando fuera: estaba ahí.
		_idle_ask_node = null
		online.still_here()
	if _idle_offer_node != null and not is_instance_valid(_idle_offer_node):
		_idle_offer_node = null
		_idle_snooze_until = Time.get_ticks_msec() + 60000
	if mover == game_color:
		if not _ping_offer:
			_close_idle_offer()
		var idle := online.idle_ms(game_color)
		if idle > limit and _idle_ask_node == null:
			_ask_still_here()
		elif idle <= limit and _idle_ask_node != null:
			_close_idle_ask()
	else:
		_close_idle_ask()
		var idle2 := online.idle_ms(mover)
		if idle2 > limit + Online.IDLE_ANSWER_MS + Online.IDLE_GRACE_MS and _idle_offer_node == null and Time.get_ticks_msec() >= _idle_snooze_until:
			_offer_idle_win(idle2)
		elif idle2 <= limit and _idle_offer_node != null and not _ping_offer:
			_close_idle_offer()


func _ask_still_here() -> void:
	if confirm_node != null and is_instance_valid(confirm_node):
		return
	var column := _popup("¿Sigues ahí?", Loc.f("Tu rival espera tu jugada. Si no contestas en %d segundos, podrá dar la partida por ganada.", int(Online.IDLE_ANSWER_MS / 1000.0)))
	column.add_child(_button("check", "Sigo aquí", _still_here, _c("accent"), _c("accent_ink"), {"font_size": F_BODY, "height": 116.0, "icon": 56.0, "radius": 58}))
	_idle_ask_node = confirm_node
	Input.vibrate_handheld(400)
	_sfx("error")


func _still_here() -> void:
	_close_idle_ask()
	online.still_here()


func _offer_idle_win(idle: float) -> void:
	if confirm_node != null and is_instance_valid(confirm_node):
		return
	var minutes := int(idle / 60000.0)
	var how_long := Loc.f("%d min", minutes) if minutes >= 1 else Loc.f("%d s", int(idle / 1000.0))
	var column := _popup("Tu rival no contesta", Loc.f("Lleva %s sin jugar y no ha contestado a «¿Sigues ahí?». Puedes ganar la partida por abandono o seguir esperando.", how_long))
	var opts := {"font_size": F_BODY, "height": 116.0, "icon": 56.0, "radius": 58}
	column.add_child(_button("check", "Ganar por abandono", _claim_idle_win, _c("accent"), _c("accent_ink"), opts))
	column.add_child(_button("clock", "Seguir esperando", _keep_waiting, _c("field"), _c("ink"), opts))
	_idle_offer_node = confirm_node
	Input.vibrate_handheld(200)


func _claim_idle_win() -> void:
	_close_idle_offer()
	online.claim_abandon(1 - game_color)


func _keep_waiting() -> void:
	_close_idle_offer()
	_idle_snooze_until = Time.get_ticks_msec() + 60000


func _close_idle_ask() -> void:
	if _idle_ask_node != null and is_instance_valid(_idle_ask_node) and confirm_node == _idle_ask_node:
		_close_confirm()
	_idle_ask_node = null


func _close_idle_offer() -> void:
	_ping_offer = false
	if _idle_offer_node != null and is_instance_valid(_idle_offer_node) and confirm_node == _idle_offer_node:
		_close_confirm()
	_idle_offer_node = null


func _close_idle_popups() -> void:
	_close_idle_ask()
	_close_idle_offer()
	_idle_snooze_until = 0


## Pide el nombre para jugar online: un campo de texto y «Guardar».
func _name_block() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	box.add_child(_centered(_para("¿Cómo quieres que te vean tus rivales?", F_HEAD, _c("ink"), font_semibold)))
	_name_edit = LineEdit.new()
	_show_caret(_name_edit)
	_name_edit.placeholder_text = "Tu nombre (2 a 16 letras)"
	_name_edit.max_length = 16
	_name_edit.text = online_name
	_name_edit.add_theme_font_size_override("font_size", F_HEAD)
	_name_edit.add_theme_font_override("font", font_medium)
	_name_edit.custom_minimum_size = Vector2(0.0, 120.0)
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = _c("surface")
	sb.set_corner_radius_all(40)
	sb.border_color = _c("track")
	sb.set_border_width_all(3)
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	_name_edit.add_theme_stylebox_override("normal", sb)
	_name_edit.add_theme_stylebox_override("focus", sb)
	_name_edit.add_theme_color_override("font_color", _c("ink"))
	_name_edit.text_submitted.connect(func(_t: String) -> void: _save_online_name())
	box.add_child(_name_edit)
	if _name_error != "":
		box.add_child(_centered(_para(_name_error, F_SUB, _c("bad"), font_medium)))
	box.add_child(_centered(_para("Es lo único que verán de ti, junto con tu nivel y tu icono. No pongas tu nombre completo.", F_FOOT, _c("quiet"), font_regular)))
	var tint := _tint("sky")
	box.add_child(_button("check", "Guardar", _save_online_name, tint[0], tint[1], {"font_size": F_BODY, "height": 116.0, "icon": 56.0}))
	return box


func _save_online_name() -> void:
	if _name_edit == null or not is_instance_valid(_name_edit):
		return
	var problem := GameLog.name_problem(_name_edit.text)
	if problem != "":
		_name_error = problem
		_open_online()
		return
	_name_error = ""
	online_name = _name_edit.text.strip_edges()
	_save_settings()
	_open_online()


func _change_online_name() -> void:
	online_name = ""
	_open_online()


## Lo que se enseña al rival: nivel, icono y, si se ha elegido, una foto pequeña.
func _online_profile() -> Dictionary:
	var p := {"nivel": Assessment.level_of(float(player["rating"]["r"])) if _has_player() else -1}
	if online_name != "":
		p["nombre"] = online_name
	if avatar.begins_with("piece_"):
		p["icono"] = avatar
	elif _has_player():
		p["icono"] = str(_rank(int(p["nivel"]))[0])
	if online_photo and avatar == "foto" and not kids:
		var b64 := _photo_b64()
		if b64 != "":
			p["foto"] = b64
	return p


## La foto de la insignia, a 96 px, sobre blanco y en JPEG: unos pocos KB.
func _photo_b64() -> String:
	if not FileAccess.file_exists(AVATAR_PATH):
		return ""
	var img := Image.new()
	if img.load_png_from_buffer(FileAccess.get_file_as_bytes(AVATAR_PATH)) != OK:
		return ""
	img.resize(96, 96, Image.INTERPOLATE_LANCZOS)
	var flat := Image.create(96, 96, false, Image.FORMAT_RGBA8)
	flat.fill(Color.WHITE)
	img.convert(Image.FORMAT_RGBA8)
	flat.blend_rect(img, Rect2i(0, 0, 96, 96), Vector2i.ZERO)
	flat.convert(Image.FORMAT_RGB8)
	var jpg := flat.save_jpg_to_buffer(0.7)
	return Marshalls.raw_to_base64(jpg) if jpg.size() < 14000 else ""


func _toggle_online_photo() -> void:
	online_photo = not online_photo
	_save_settings()
	_open_online()


func _online_rival_profile(p: Dictionary) -> void:
	online_rival = p
	_rival_tex = null
	var b64 := str(p.get("foto", ""))
	if b64 != "":
		var img := Image.new()
		if img.load_jpg_from_buffer(Marshalls.base64_to_raw(b64)) == OK:
			img.convert(Image.FORMAT_RGBA8)
			var w := img.get_width()
			for y in img.get_height():
				for x in w:
					var d := Vector2(float(x) - w * 0.5 + 0.5, float(y) - w * 0.5 + 0.5).length()
					var px := img.get_pixel(x, y)
					px.a = clampf(w * 0.5 - 0.5 - d, 0.0, 1.0)
					img.set_pixel(x, y, px)
			img.generate_mipmaps()
			_rival_tex = ImageTexture.create_from_image(img)
	if mode == "game" and bool(game.get("online", false)):
		_refresh()


## Insignia del rival: su foto o su icono dentro del anillo del color de su nivel, con el número.
func _rival_badge(side: float) -> Control:
	var lv := int(online_rival.get("nivel", -1))
	var rank := _rank(maxi(lv, 0))
	var tint := _tint(str(rank[2])) if lv >= 0 else [_c("field"), _c("quiet")]
	var badge := LevelBadge.new()
	badge.custom_minimum_size = Vector2(side, side)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.fill = tint[0]
	badge.ring = tint[1]
	badge.track = Color(tint[1].r, tint[1].g, tint[1].b, 0.18)
	badge.bubble = tint[1]
	badge.bubble_ink = Color.WHITE
	badge.progress = 1.0
	badge.level = lv if lv >= 0 else 0
	badge.font = font_display
	if _rival_tex != null:
		var pic := TextureRect.new()
		pic.texture = _rival_tex
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pic.set_anchors_preset(Control.PRESET_FULL_RECT)
		var inset := side * 0.11
		pic.offset_left = inset
		pic.offset_top = inset
		pic.offset_right = -inset
		pic.offset_bottom = -inset
		pic.show_behind_parent = true
		badge.fill = Color(tint[0].r, tint[0].g, tint[0].b, 0.0)
		badge.add_child(pic)
		return badge
	var glyph := str(online_rival.get("icono", ""))
	if not (glyph.begins_with("piece_") and UiIcons.has(glyph)):
		glyph = str(rank[0])
	var icon := _icon(glyph, side * 0.5, tint[1])
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = side * 0.25
	icon.offset_top = side * 0.22
	icon.offset_right = -side * 0.25
	icon.offset_bottom = -side * 0.28
	badge.add_child(icon)
	return badge


## Historial de partidas, cargado la primera vez.
func _log() -> Dictionary:
	if game_log.is_empty():
		game_log = GameLog.load_log()
	return game_log


## Anota la partida terminada (una vez): online y contra el ordenador; no las del curso, las variantes ni Kids.
func _record_game() -> void:
	if game_recorded or kids or game_moves.is_empty() or str(game.get("unit", "")) != "" or str(game.get("variant", "")) != "" or bool(game.get("saved", false)):
		return
	game_recorded = true
	var is_online := bool(game.get("online", false))
	var rid := ""
	var rname := ""
	var rival_info := {}
	if is_online:
		rid = online.rival_uid if online.rival_uid != "" else "online:?"
		rival_info = online_rival.duplicate()
		rname = str(online_rival.get("nombre", "Rival anónimo"))
	else:
		var lv := int(game.get("level", 0))
		rid = "bot:%d" % lv
		rname = Loc.f("Ordenador · %s", Bot.level_name(lv))
		if str(game.get("campeonato", "")) != "":
			rname = Loc.f("%s (bot) · %s", [str(game.get("rival_nombre", "")), Loc.t(str(Campeonato.tournament(str(game["campeonato"])).get("name", "")))])
	var g := {
		"fecha": int(Time.get_unix_time_from_system()),
		"tipo": "online" if is_online else "ordenador",
		"rival_id": rid,
		"rival_nombre": rname,
		"rival_nivel": int(rival_info.get("nivel", -1)),
		"color": game_color,
		"resultado": game_won,
		"motivo": game_result,
		"rival_juego": (rival_info.get("juego", {}) as Dictionary).duplicate() if rival_info.get("juego", {}) is Dictionary else {},
		"inicio": str(game_history[0]) if not game_history.is_empty() else Board3D.START_FEN,
		"jugadas": game_moves.duplicate(),
	}
	if game_helped:
		g["ayudas"] = true
	GameLog.add(_log(), g, rival_info)
	GameLog.save_log(_log())
	# Una partida que abandonas no cuenta para el reto del día (si abandona el rival, sí: tú la has jugado).
	if not (game_won < 0 and GameLog.reason(g) == "abandono"):
		_prog_game()


## Insignia de un rival guardado (o del de ahora): su foto o su icono dentro del anillo del color de su nivel.
func _profile_badge(p: Dictionary, side: float, key: String = "") -> Control:
	var lv := int(p.get("nivel", -1))
	var bot := key.begins_with("bot:")
	var rank := _rank(maxi(lv, 0))
	var tint := _tint(str(rank[2])) if lv >= 0 else ([_tint("sky")[0], _tint("sky")[1]] if bot else [_c("field"), _c("quiet")])
	var badge := LevelBadge.new()
	badge.custom_minimum_size = Vector2(side, side)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.fill = tint[0]
	badge.ring = tint[1]
	badge.track = Color(tint[1].r, tint[1].g, tint[1].b, 0.18)
	badge.bubble = tint[1]
	badge.bubble_ink = Color.WHITE
	badge.progress = 1.0
	badge.level = maxi(lv, 0)
	badge.no_level = lv < 0
	badge.font = font_display
	var tex: Texture2D = null
	var b64 := str(p.get("foto", ""))
	if b64 != "":
		var ck := key if key != "" else str(b64.hash())
		if not _photo_cache.has(ck):
			_photo_cache[ck] = _decode_photo(b64)
		tex = _photo_cache[ck]
	if tex != null:
		var pic := TextureRect.new()
		pic.texture = tex
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pic.set_anchors_preset(Control.PRESET_FULL_RECT)
		var inset := side * 0.11
		pic.offset_left = inset
		pic.offset_top = inset
		pic.offset_right = -inset
		pic.offset_bottom = -inset
		pic.show_behind_parent = true
		badge.fill = Color(tint[0].r, tint[0].g, tint[0].b, 0.0)
		badge.add_child(pic)
		return badge
	var glyph := str(p.get("icono", ""))
	if bot:
		glyph = "bot"
	elif not (glyph.begins_with("piece_") and UiIcons.has(glyph)):
		glyph = str(rank[0])
	var icon := _icon(glyph, side * 0.5, tint[1])
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = side * 0.25
	icon.offset_top = side * 0.22
	icon.offset_right = -side * 0.25
	icon.offset_bottom = -side * 0.28
	badge.add_child(icon)
	return badge


func _decode_photo(b64: String) -> Texture2D:
	var img := Image.new()
	if img.load_jpg_from_buffer(Marshalls.base64_to_raw(b64)) != OK:
		return null
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	for y in img.get_height():
		for x in w:
			var d := Vector2(float(x) - w * 0.5 + 0.5, float(y) - w * 0.5 + 0.5).length()
			var px := img.get_pixel(x, y)
			px.a = clampf(w * 0.5 - 0.5 - d, 0.0, 1.0)
			img.set_pixel(x, y, px)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


const RESULT_WORDS := {1: ["Ganada", "mint"], 0: ["Tablas", "sky"], -1: ["Perdida", "rose"]}


## «Mis partidas»: el resumen en números, los rivales y las últimas partidas (se toca una para analizarla).
func _open_my_games() -> void:
	var log := _log()
	var st := GameLog.stats(log)
	var page := _page("my_games")
	var body: VBoxContainer = page["body"]
	var footer: VBoxContainer = page["footer"]
	var tile := _icon_tile("trend", "mint", 156.0, 98.0)
	tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(tile)
	body.add_child(_spacer(16.0))
	body.add_child(_centered(_para("Mis partidas", F_LARGE, _c("ink"), font_display)))
	body.add_child(_spacer(20.0))
	if not kids:
		body.add_child(_levels_row(log))
		body.add_child(_spacer(18.0))
	if int(st["total"]) == 0:
		body.add_child(_centered(_para("Todavía no has terminado ninguna partida. Aquí verás contra quién has jugado, tus resultados y tus estadísticas.", F_BODY, _c("quiet"), font_regular)))
	else:
		# Cuatro teselas con los números grandes; se tocan para ver solo esas partidas.
		var tiles := HBoxContainer.new()
		tiles.add_theme_constant_override("separation", 14)
		for def: Array in [["Jugadas", "total", "lilac", ""], ["Ganadas", "ganadas", "mint", "ganadas"], ["Tablas", "tablas", "sky", "tablas"], ["Perdidas", "perdidas", "rose", "perdidas"]]:
			var t := _tint(str(def[2]))
			var key := str(def[3])
			var on := my_games_result == key
			var btn := Button.new()
			btn.focus_mode = Control.FOCUS_NONE
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
				var sb := StyleBoxFlat.new()
				sb.bg_color = t[0]
				sb.set_corner_radius_all(40)
				if on and key != "":
					sb.set_border_width_all(6)
					sb.border_color = t[1]
				btn.add_theme_stylebox_override(state, sb)
			btn.modulate.a = 1.0 if on or my_games_result == "" else 0.6
			btn.pressed.connect(_filter_my_games.bind(key, my_games_why if key != "" else ""))
			var col := VBoxContainer.new()
			col.add_theme_constant_override("separation", 0)
			col.mouse_filter = Control.MOUSE_FILTER_IGNORE
			col.set_anchors_preset(Control.PRESET_FULL_RECT)
			col.alignment = BoxContainer.ALIGNMENT_CENTER
			col.add_child(_centered(_para(str(int(st[str(def[1])])), F_TITLE + 8, t[1], font_display)))
			col.add_child(_centered(_para(str(def[0]), F_FOOT, _c("ink"), font_medium)))
			for c: Node in col.get_children():
				(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.custom_minimum_size = Vector2(0.0, 180.0)
			btn.add_child(col)
			tiles.add_child(btn)
		body.add_child(tiles)
		body.add_child(_spacer(14.0))
		# Cómo terminaron: chips que filtran (con cuántas hay de cada).
		var counts := {}
		for g0: Dictionary in log["partidas"]:
			var k := GameLog.reason(g0)
			counts[k] = int(counts.get(k, 0)) + 1
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 12)
		flow.add_theme_constant_override("v_separation", 12)
		for def2: Array in [["mate", "Jaque mate", "target"], ["tiempo", "Por tiempo", "clock"], ["abandono", "Abandono", "close"], ["rendicion", "Rendición", "flag"], ["tablas", "Tablas", "info"], ["otros", "Otros", "spark"]]:
			var k2 := str(def2[0])
			if int(counts.get(k2, 0)) == 0:
				continue
			flow.add_child(_filter_chip("%s · %d" % [str(def2[1]), int(counts[k2])], str(def2[2]), my_games_why == k2, _filter_my_games.bind(my_games_result, "" if my_games_why == k2 else k2)))
		body.add_child(flow)
		body.add_child(_spacer(18.0))
		var total := maxi(int(st["total"]), 1)
		var lines: Array = []
		lines.append(Loc.f("Ganas el %d %% de tus partidas.", roundi(100.0 * float(st["ganadas"]) / float(total))))
		var w: Array = st["blancas"]
		var b: Array = st["negras"]
		lines.append(Loc.f("Con blancas: %d ganadas, %d tablas, %d perdidas. Con negras: %d, %d y %d.", [w[0], w[1], w[2], b[0], b[1], b[2]]))
		lines.append(Loc.f("Online: %d · contra el ordenador: %d.", [int(st["online"]), int(st["ordenador"])]))
		var run := int(st["racha"])
		if run >= 2:
			lines.append(Loc.f("Llevas %d victorias seguidas. Tu mejor racha: %d.", [run, int(st["mejor_racha"])]))
		elif int(st["mejor_racha"]) >= 2:
			lines.append(Loc.f("Tu mejor racha: %d victorias seguidas.", int(st["mejor_racha"])))
		for t2: String in lines:
			body.add_child(_para(t2, F_SUB, _c("quiet"), font_medium))
		_add_evolution(body, log)
		# Rivales.
		body.add_child(_section("Rivales"))
		for pair: Array in GameLog.rivals_by_date(log).slice(0, 20):
			var id := str(pair[0])
			var r: Dictionary = pair[1]
			var panel_rows := _panel()
			var rows: VBoxContainer = panel_rows[1]
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 22)
			row.add_child(_profile_badge(r, 110.0, id))
			var texts := VBoxContainer.new()
			texts.add_theme_constant_override("separation", 2)
			texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var lv := int(r.get("nivel", -1))
			var who := str(r.get("nombre", "Rival"))
			if lv >= 0 and not id.begins_with("bot:"):
				who += Loc.f(" · táctica %d", lv)
			texts.add_child(_para(who, F_BODY, _c("ink"), font_semibold))
			var n := int(r.get("partidas", 0))
			var g := int(r.get("ganadas", 0))
			var d := int(r.get("tablas", 0))
			var l2 := int(r.get("perdidas", 0))
			texts.add_child(_para("%d %s · %d %s, %d %s, %d %s" % [n, "partida" if n == 1 else "partidas", g, "ganada" if g == 1 else "ganadas", d, "tablas", l2, "perdida" if l2 == 1 else "perdidas"], F_SUB, _c("quiet"), font_regular))
			texts.add_child(_para(Loc.f("Última: %s", _date_text(int(r.get("ultima", 0)))), F_FOOT, _c("quiet"), font_regular))
			row.add_child(texts)
			rows.add_child(row)
			body.add_child(panel_rows[0])
			body.add_child(_spacer(12.0))
		# Últimas partidas (con el filtro que esté puesto).
		var games: Array = log["partidas"]
		var shown := GameLog.filtered(log, my_games_result, my_games_why)
		var head := "Últimas partidas"
		if my_games_result != "" or my_games_why != "":
			head = Loc.f("Partidas filtradas · %d", shown.size())
		body.add_child(_section(head))
		if shown.is_empty():
			body.add_child(_para("Ninguna partida con ese filtro.", F_BODY, _c("quiet"), font_regular))
		for i: int in shown.slice(0, 30):
			var g: Dictionary = games[i]
			var res := int(g.get("resultado", 0))
			var word: Array = RESULT_WORDS.get(res, RESULT_WORDS[0])
			var moves_n := (g.get("jugadas", []) as Array).size()
			var line := Loc.f("%s · %s · %d jugadas · %s", [str(g.get("rival_nombre", "Rival")), "blancas" if int(g.get("color", 0)) == 0 else "negras", (moves_n + 1) / 2, _date_text(int(g.get("fecha", 0)))])
			var btn := _option_button("check" if res > 0 else ("info" if res == 0 else "wrong"), str(word[1]), str(word[0]), line, _open_saved_game.bind(i))
			body.add_child(btn)
			body.add_child(_spacer(10.0))
	body.add_child(_spacer(10.0, true))
	footer.add_child(_button("back", "Volver", _close_my_games, _c("field"), _c("ink"), {"font_size": F_BODY, "height": 104.0, "icon": 48.0, "font": font_medium}))


## Los dos niveles, uno al lado del otro: táctica (problemas) y juego (partidas contra el ordenador).
func _levels_row(log: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var defs: Array = []
	if _has_player():
		var r := float(player["rating"]["r"])
		defs.append(["target", "peach", "Táctica", Loc.f("Nivel %d · %d", [Assessment.level_of(r), roundi(r)]), "Sale de los problemas"])
	else:
		defs.append(["target", "peach", "Táctica", "Sin medir", "Haz el test de nivel"])
	var gr := GameLog.game_rating(log)
	if int(gr["n"]) == 0:
		defs.append(["piece_knight", "sky", "Juego", "Sin medir", "Juega contra el ordenador"])
	elif bool(gr["provisional"]):
		defs.append(["piece_knight", "sky", "Juego", Loc.f("%d (provisional)", roundi(float(gr["r"]))), Loc.f("%d de %d partidas", [int(gr["n"]), GameLog.RATED_MIN])])
	else:
		defs.append(["piece_knight", "sky", "Juego", "%d" % roundi(float(gr["r"])), "Sale de tus partidas"])
	for d: Array in defs:
		var t := _tint(str(d[1]))
		var panel := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = t[0]
		sb.set_corner_radius_all(40)
		sb.content_margin_left = 26.0
		sb.content_margin_right = 20.0
		sb.content_margin_top = 18.0
		sb.content_margin_bottom = 18.0
		panel.add_theme_stylebox_override("panel", sb)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var inner := HBoxContainer.new()
		inner.add_theme_constant_override("separation", 16)
		inner.add_child(_icon(str(d[0]), 64.0, t[1]))
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(_para(str(d[2]), F_FOOT, _c("quiet"), font_medium))
		col.add_child(_para(str(d[3]), F_BODY, t[1], font_display))
		col.add_child(_para(str(d[4]), F_FOOT, _c("quiet"), font_regular))
		inner.add_child(col)
		panel.add_child(inner)
		row.add_child(panel)
	return row


## Pone un filtro en «Mis partidas» y la vuelve a dibujar.
func _filter_my_games(result: String, why: String) -> void:
	my_games_result = result
	my_games_why = why
	_open_my_games()


func _filter_chip(text: String, icon_name: String, on: bool, on_press: Callable) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	var fill := _c("accent") if on else _c("field")
	var fg := _c("accent_ink") if on else _c("ink")
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = fill
		sb.set_corner_radius_all(40)
		sb.content_margin_left = 26.0
		sb.content_margin_right = 26.0
		sb.content_margin_top = 14.0
		sb.content_margin_bottom = 14.0
		b.add_theme_stylebox_override(state, sb)
	b.text = Loc.t(text)
	b.add_theme_font_size_override("font_size", F_SUB)
	if font_medium != null:
		b.add_theme_font_override("font", font_medium)
	for k: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, fg)
	if UiIcons.has(icon_name):
		b.icon = UiIcons.texture(icon_name)
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", F_SUB + 8)
		for k: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
			b.add_theme_color_override(k, fg)
	b.pressed.connect(on_press)
	return b


## «Tu evolución»: la puntuación tras cada problema (con las bandas de nivel) y la forma en las últimas partidas.
func _add_evolution(body: VBoxContainer, log: Dictionary) -> void:
	body.add_child(_section("Tu evolución"))
	var tries: Array = player.get("tries", []) if not player.is_empty() else []
	var hist := Assessment.history(experience, tries)
	if hist.size() >= 2:
		var chart := EvolutionChart.new()
		chart.values = hist
		chart.small_font = font_medium
		chart.ink = _c("ink")
		chart.quiet = _c("quiet")
		chart.line = _c("accent")
		chart.custom_minimum_size = Vector2(0.0, 420.0)
		chart.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var pr := _panel()
		(pr[1] as VBoxContainer).add_child(_para("Tu puntuación, problema a problema", F_SUB, _c("ink"), font_semibold))
		(pr[1] as VBoxContainer).add_child(chart)
		body.add_child(pr[0])
	else:
		body.add_child(_para("Resuelve unos cuantos problemas y aquí verás cómo sube tu puntuación.", F_SUB, _c("quiet"), font_regular))
	# Forma: las últimas partidas, de la más antigua a la más reciente.
	var games: Array = log["partidas"]
	if games.size() >= 2:
		body.add_child(_spacer(12.0))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.add_child(_para("Forma", F_SUB, _c("quiet"), font_medium))
		var last := games.slice(0, 15)
		last.reverse()
		for g: Dictionary in last:
			var res := int(g.get("resultado", 0))
			var t := _tint("mint" if res > 0 else ("sky" if res == 0 else "rose"))
			var dot := PanelContainer.new()
			var sb := StyleBoxFlat.new()
			sb.bg_color = t[1]
			sb.set_corner_radius_all(16)
			dot.add_theme_stylebox_override("panel", sb)
			dot.custom_minimum_size = Vector2(34.0, 34.0)
			dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			dot.tooltip_text = str(RESULT_WORDS.get(res, RESULT_WORDS[0])[0])
			row.add_child(dot)
		body.add_child(row)
	body.add_child(_spacer(8.0))


func _back_to_my_games() -> void:
	_stop_game_thread()
	run_id += 1
	game_state = ""
	mode = "free"
	view.board.set_arrows([])
	view.set_orientation(0)
	_idle()
	_open_my_games()


func _open_my_games_from(where: String) -> void:
	my_games_back = where
	_open_my_games()


func _close_my_games() -> void:
	_close_progress()
	if mode == "game" and bool(game.get("saved", false)):
		_leave_game()
		return
	if my_games_back == "setup":
		_open_game_setup()
	else:
		_open_online()


## «15 nov · 10:42» con la hora local.
func _date_text(unix: int) -> String:
	if unix <= 0:
		return "—"
	var d := Time.get_datetime_dict_from_unix_time(unix + int(Time.get_time_zone_from_system().get("bias", 0)) * 60)
	var months := ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"]
	return "%d %s · %02d:%02d" % [int(d["day"]), months[int(d["month"]) - 1], int(d["hour"]), int(d["minute"])]


## Una partida guardada, en el tablero y con su análisis (resumen y detalle).
func _open_saved_game(i: int) -> void:
	var games: Array = _log()["partidas"]
	if i < 0 or i >= games.size():
		return
	var g: Dictionary = games[i]
	_close_progress()
	_stop_game_thread()
	run_id += 1
	_clear_explanation()
	mode = "game"
	game = {"variant": "", "level": 0, "title": str(g.get("rival_nombre", "Partida")), "text": "", "kids": "", "unit": "", "clock": [], "online": false, "saved": true}
	game_color = int(g.get("color", 0))
	game_clocked = false
	var pos := Chess.from_fen(str(g.get("inicio", Board3D.START_FEN)))
	game_history = [pos.fen()]
	game_moves = []
	for u: Variant in g.get("jugadas", []):
		var m := pos.find_uci(str(u))
		if m < 0:
			break
		pos.apply(m)
		game_moves.append(str(u))
		game_history.append(pos.fen())
	game_won = int(g.get("resultado", 0))
	game_result = str(g.get("motivo", ""))
	game_state = "over"
	game_recorded = true
	game_back = 0
	_online_pending = []
	review = []
	review_done = false
	review_at = -1
	detail = []
	detail_done = false
	detail_at = -1
	view.board.set_arrows([])
	view.set_orientation(game_color)
	view.set_fen(pos.fen())
	if not game_moves.is_empty():
		var last := str(game_moves[game_moves.size() - 1])
		view.board.mark_last_move(Chess.sq_index(last.substr(0, 2)), Chess.sq_index(last.substr(2, 2)))
	view.interactive = false
	_actions_mode = ""
	_refresh()
	_open_review()


## Fila del rival en la tarjeta de la partida online. `compact`: con reloj no caben los gestos en su fila; van en
## un botón que los abre.
func _rival_row(compact: bool = false) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16 if compact else 20)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_rival_badge(88.0 if compact else 104.0))
	var text := _rival_line() if not online_rival.is_empty() else "Rival · …"
	var l := _para(text, F_SUB if compact else F_BODY, _c("ink"), font_semibold)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if compact:
		# Una sola línea: si no cabe, con puntos suspensivos.
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.clip_text = true
	row.add_child(l)
	if compact:
		var tint := _tint("sky")
		var g := _round_button("g_saludo", _gesture_menu, 88.0, tint[0], tint[1], false)
		g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(g)
	if online.rival_uid != "":
		# Denunciar o bloquear al rival.
		var more := _round_button("more", _rival_menu, 88.0 if compact else 96.0, _c("field"), _c("ink"), false)
		more.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(more)
	return row


## «Lucía · Táctica 4 · Alfil · Juego 1240».
func _rival_line() -> String:
	if online_rival.is_empty():
		return ""
	var lv := int(online_rival.get("nivel", -1))
	var who := str(online_rival.get("nombre", "Rival"))
	var text := (Loc.f("%s · Táctica %d · %s", [who, lv, str(_rank(lv)[1])])) if lv >= 0 else Loc.f("%s · todavía sin nivel", who)
	var rj: Variant = online_rival.get("juego", {})
	if rj is Dictionary and (rj as Dictionary).has("r"):
		text += Loc.f(" · Juego %d", int((rj as Dictionary)["r"]))
	return text


## Fila de debajo del reloj en las partidas online: insignia del rival, gestos, «¡Tu tiempo!» y opciones.
func _rival_tools() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var side := 120.0
	var parts: Array[Control] = []
	var badge := _rival_badge(side)
	parts.append(badge)
	var sky := _tint("sky")
	parts.append(_round_button("g_saludo", _gesture_menu, side, sky[0], sky[1], false))
	var peach := _tint("peach")
	parts.append(_round_button("g_tiempo", _hurry_rival, side, peach[0], peach[1], false))
	if online.rival_uid != "":
		parts.append(_round_button("more", _rival_menu, side, _c("field"), _c("ink"), false))
	for p: Control in parts:
		# Repartidos a lo ancho, cada uno centrado en su hueco.
		var cell := CenterContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(p)
		row.add_child(cell)
	return row


## «¡Tu tiempo!»: avisa al rival de que le toca. Solo tiene sentido cuando le toca a él; como mucho, uno cada
## 10 segundos.
var _hurry_at := -100000


func _hurry_rival() -> void:
	if online.on_move() == game_color:
		_board_bubble("g_tiempo", "Ahora te toca a ti.", "peach", false)
		return
	var now := Time.get_ticks_msec()
	if now - _hurry_at < 10000:
		_board_bubble("g_tiempo", "Ya se lo has dicho. Espera un poco.", "peach", false)
		return
	_hurry_at = now
	online.send_gesture("tiempo")


## Los gestos, en una ventana (en las partidas con reloj, que no tienen sitio para su fila): grandes, en dos filas.
func _gesture_menu() -> void:
	var column := _popup("Gestos", "")
	column.add_child(_gesture_row(true))
	column.add_child(_button("back", "Cerrar", _close_confirm, _c("field"), _c("ink"), {"font_size": F_BODY, "height": 104.0, "icon": 48.0, "radius": 52}))


## Opciones con el rival: denunciarlo o bloquearlo.
func _rival_menu() -> void:
	var who := str(online_rival.get("nombre", "Rival"))
	var column := _popup(who, "¿Ha hecho algo que no está bien? Puedes denunciarlo, bloquearlo o las dos cosas.")
	var info := _rival_line()
	if info != "":
		column.add_child(_para(info, F_SUB, _c("ink"), font_semibold))
	var opts := {"font_size": F_BODY, "height": 116.0, "icon": 56.0, "radius": 58}
	var rose := _tint("rose")
	column.add_child(_button("report", "Denunciar", _report_menu, rose[0], rose[1], opts))
	if online_blocked.has(online.rival_uid):
		column.add_child(_para(Loc.f("Has bloqueado a %s: no volveréis a jugar juntos.", who), F_SUB, _c("quiet"), font_medium))
	else:
		column.add_child(_button("block", "Bloquear", _block_rival, _c("field"), _c("ink"), opts))
	column.add_child(_button("back", "Cerrar", _close_confirm, _c("field"), _c("ink"), opts))


## Motivos de la denuncia.
func _report_menu() -> void:
	var column := _popup("Denunciar", "¿Qué ha pasado? La denuncia es anónima para tu rival.")
	var opts := {"font_size": F_SUB, "height": 104.0, "icon": 48.0, "radius": 52, "font": font_medium}
	var reasons := [["nombre", "sliders", "Nombre ofensivo"], ["trampas", "bot", "Usa ayudas o un programa"], ["abandono", "clock", "Me hace perder el tiempo"], ["conducta", "g_abajo", "Gestos molestos"], ["otro", "info", "Otra cosa"]]
	for r: Array in reasons:
		column.add_child(_button(str(r[1]), str(r[2]), _send_report.bind(str(r[0])), _c("field"), _c("ink"), opts))
	column.add_child(_button("back", "Cancelar", _close_confirm, _c("field"), _c("ink"), opts))


func _send_report(reason: String) -> void:
	var who := str(online_rival.get("nombre", ""))
	var against := online.rival_uid
	var game_id := online.game_id
	var column := _popup("Enviando…", "")
	var ok: bool = await online.report(against, who, reason, game_id)
	if confirm_node == null or not is_instance_valid(confirm_node) or not is_instance_valid(column):
		return
	column = _popup("Denuncia enviada" if ok else "No se pudo enviar", "Gracias. La revisaremos. Si no quieres volver a jugar con este jugador, bloquéalo." if ok else "Revisa tu conexión a Internet y vuelve a intentarlo.")
	var opts := {"font_size": F_BODY, "height": 116.0, "icon": 56.0, "radius": 58}
	if ok and not online_blocked.has(against):
		column.add_child(_button("block", "Bloquear también", _block_rival, _c("field"), _c("ink"), opts))
	column.add_child(_button("check", "Vale", _close_confirm, _c("field"), _c("ink"), opts))


func _block_rival() -> void:
	var who := str(online_rival.get("nombre", "Rival"))
	if online.rival_uid == "":
		return
	online_blocked[online.rival_uid] = who
	_save_settings()
	var column := _popup("Bloqueado", Loc.f("No volverás a jugar con %s. Puedes desbloquearlo en «Partida online».", who))
	column.add_child(_button("check", "Vale", _close_confirm, _c("field"), _c("ink"), {"font_size": F_BODY, "height": 116.0, "icon": 56.0, "radius": 58}))


const GESTURE_TINTS := {"saludo": "sky", "aplauso": "butter", "genial": "peach", "arriba": "mint", "abajo": "rose", "buena": "lilac", "tiempo": "peach", "pregunta": "sky"}


## Dibujo de un gesto: «?» para «¿Sigues ahí?».
func _gesture_icon(kind: String) -> String:
	return "why" if kind == "pregunta" else "g_" + kind


## Los gestos del chat: botones redondos con su dibujo, grandes y en dos filas (Pablo, 22 nov: «que se vean bien»).
## En la ventana (`big`), un poco más grandes que en la tarjeta.
func _gesture_row(big: bool = false) -> Control:
	var side := 168.0 if big else 150.0
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 18)
	var box: Container = grid
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for g: String in Online.GESTURES:
		if g == "tiempo":
			continue
		var tint := _tint(str(GESTURE_TINTS[g]))
		var b := _button(_gesture_icon(g), "", _send_gesture.bind(g), tint[0], tint[1], {"height": side, "icon": side * 0.64, "pad_x": side * 0.18, "radius": int(side * 0.5)})
		b.custom_minimum_size = Vector2(side, side)
		b.tooltip_text = Loc.t(str(Online.GESTURE_TEXT[g]))
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(b)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(box)
	return center


func _send_gesture(kind: String) -> void:
	_close_confirm()
	if kind == "pregunta":
		_ask_rival_here()
		return
	online.send_gesture(kind)


## «¿Sigues ahí?» al rival: su app contesta sola si está abierta. Sin respuesta en PING_SILENT_MS, sale la ventana de
## abandono (ganar o seguir esperando). Si contesta después, la ventana se cierra y sale «Tu rival está pensando».
const PING_SILENT_MS := 20000
## Cuándo pregunté «¿Sigues ahí?» (ms) o −1.
var _ping_at := -1
var _ping_told := false
## La ventana de abandono abierta viene del «?» (la lógica del turno no la cierra).
var _ping_offer := false


func _ask_rival_here(again: bool = false) -> void:
	var now := Time.get_ticks_msec()
	if not again and _ping_at != -1 and now - _ping_at < 30000:
		_board_bubble("why", "Ya se lo has preguntado. Espera un poco.", "sky", false)
		return
	var ok: bool = await online.send_gesture("pregunta")
	if not ok:
		_board_bubble("why", "No se ha podido preguntar. Revisa tu conexión.", "rose", false)
		return
	_ping_at = Time.get_ticks_msec()
	_ping_told = false


## Su app ha contestado: «Tu rival está pensando» (o, si me toca a mí, que sigue en la partida), con «Volver a
## comprobar» que se habilita a los RECHECK_MS con cuenta atrás. Se quita sola si el rival mueve o al tocar fuera.
const RECHECK_MS := 20000
var _thinking_node: Control
var _recheck_button: Button
var _recheck_at := 0


func _show_rival_thinking() -> void:
	if confirm_node != null and is_instance_valid(confirm_node):
		_board_bubble("check", "Tu rival sigue en la partida.", "mint", true)
		return
	var thinking := online.on_move() != game_color
	var column := _popup("Tu rival está pensando" if thinking else "Tu rival sigue en la partida", "Su app ha contestado: sigue ahí." if thinking else "Su app ha contestado: sigue ahí. Ahora te toca a ti.")
	_recheck_at = Time.get_ticks_msec() + RECHECK_MS
	_recheck_button = _button("why", _recheck_label(), _recheck_rival, _c("field"), _c("ink"), {"font_size": F_BODY, "height": 116.0, "icon": 56.0, "radius": 58})
	_recheck_button.disabled = true
	_recheck_button.modulate.a = 0.55
	column.add_child(_recheck_button)
	_thinking_node = confirm_node


func _recheck_label() -> String:
	var left := ceili(float(_recheck_at - Time.get_ticks_msec()) / 1000.0)
	return Loc.t("Volver a comprobar") if left <= 0 else Loc.f("Volver a comprobar (%d)", left)


func _recheck_tick() -> void:
	if _thinking_node == null:
		return
	if not is_instance_valid(_thinking_node) or confirm_node != _thinking_node:
		_thinking_node = null
		return
	if _recheck_button != null and is_instance_valid(_recheck_button) and _recheck_button.disabled:
		var label := _recheck_label()
		var node: Variant = _recheck_button.get_meta("label_node", null)
		if node is Label and (node as Label).text != label:
			(node as Label).text = label
		if Time.get_ticks_msec() >= _recheck_at:
			_recheck_button.disabled = false
			_recheck_button.modulate.a = 1.0


func _recheck_rival() -> void:
	_close_thinking()
	_ask_rival_here(true)


func _close_thinking() -> void:
	if _thinking_node != null and is_instance_valid(_thinking_node) and confirm_node == _thinking_node:
		_close_confirm()
	_thinking_node = null


func _ping_tick() -> void:
	_recheck_tick()
	if _ping_at == -1 or online.phase != "playing":
		_ping_at = -1
		return
	var now := Time.get_ticks_msec()
	if online.rival_alive_at > _ping_at:
		_ping_at = -1
		if _ping_told and confirm_node != null and is_instance_valid(confirm_node) and confirm_node == _idle_offer_node:
			_close_idle_offer()
		_show_rival_thinking()
		return
	# Sin respuesta: la ventana de abandono de siempre («Ganar por abandono» / «Seguir esperando»), al momento y sea
	# el turno de quien sea (Pablo, 22 nov). Si hay otra ventana abierta, espera a que se cierre.
	if not _ping_told and now - _ping_at >= PING_SILENT_MS and _idle_offer_node == null and (confirm_node == null or not is_instance_valid(confirm_node)):
		_ping_told = true
		var column := _popup("Tu rival no contesta", Loc.t("Tu rival no contesta: parece que ha cerrado la app o se ha quedado sin conexión.") + " " + Loc.t("Puedes ganar la partida por abandono o seguir esperando."))
		var opts := {"font_size": F_BODY, "height": 116.0, "icon": 56.0, "radius": 58}
		column.add_child(_button("check", "Ganar por abandono", _claim_idle_win, _c("accent"), _c("accent_ink"), opts))
		column.add_child(_button("clock", "Seguir esperando", _keep_waiting, _c("field"), _c("ink"), opts))
		_idle_offer_node = confirm_node
		_ping_offer = true
		Input.vibrate_handheld(200)


## Globo con el gesto, encima del tablero: arriba los del rival, abajo los míos.
func _online_gesture(mine: bool, kind: String) -> void:
	if mode != "game" or not bool(game.get("online", false)):
		return
	var who := Loc.t("Tú") if mine else Loc.t("Rival")
	_board_bubble(_gesture_icon(kind), "%s: %s" % [who, Loc.t(str(Online.GESTURE_TEXT.get(kind, "")))], str(GESTURE_TINTS.get(kind, "sky")), not mine)
	if kind == "pregunta" and not mine:
		# Contesta la app sola: estoy aquí (si no, el rival creería que la he cerrado).
		online.still_here()
	if not mine:
		_sfx("acierto")
		if kind == "tiempo":
			Input.vibrate_handheld(250)


## Globo encima del tablero (arriba o abajo): aparece, se queda `stay` segundos y se desvanece subiendo.
func _board_bubble(icon_name: String, text: String, tint_name: String, top: bool, stay: float = 2.0) -> void:
	if board_slot == null or not is_instance_valid(board_slot):
		return
	var tint := _tint(tint_name)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	var paper := _c("surface")
	sb.bg_color = Color(paper.r, paper.g, paper.b, 0.94)
	sb.set_corner_radius_all(60)
	sb.shadow_color = _c("shadow")
	sb.shadow_size = 18
	sb.content_margin_left = 30
	sb.content_margin_right = 38
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_icon(icon_name, 76.0, tint[1]))
	var l := _text(text, F_BODY, _c("ink"), font_semibold)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Un texto largo (los avisos del rival) va en varias líneas, sin salirse de la pantalla.
	var max_w := maxf(300.0, size.x - 260.0)
	if l.get_theme_font("font").get_string_size(Loc.t(text), HORIZONTAL_ALIGNMENT_LEFT, -1, F_BODY).x > max_w:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = max_w
	row.add_child(l)
	panel.add_child(row)
	add_child(panel)
	var rect := board_slot.get_global_rect()
	var place := func() -> void:
		if not is_instance_valid(panel):
			return
		panel.reset_size()
		var w := panel.get_combined_minimum_size()
		var y := rect.position.y + rect.size.y * (0.12 if top else 0.78)
		panel.position = Vector2((size.x - w.x) * 0.5, y - w.y * 0.5)
		panel.pivot_offset = w * 0.5
	place.call_deferred()
	panel.scale = Vector2(0.6, 0.6)
	panel.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(panel, "scale", Vector2(1.06, 1.06), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(panel, "modulate:a", 1.0, 0.15)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.1)
	tw.tween_interval(stay)
	tw.tween_property(panel, "modulate:a", 0.0, 0.6)
	tw.parallel().tween_property(panel, "position:y", -40.0, 0.6).as_relative()
	tw.tween_callback(panel.queue_free)


## Partida online: mirar jugadas anteriores sin perder la partida. delta −99 vuelve al directo.
## Un toque en el tablero cuando no se puede mover: si se miraban jugadas anteriores y te toca, vuelve al directo.
func _on_view_tapped(kind: String) -> void:
	if kind == "locked" and mode == "game" and game_back > 0 and game_state in ["play", "think", "press"]:
		_game_browse(-99)
	elif kind == "illegal" and mode == "game" and game_state == "play" and view.board.chess is WarChess \
			and (view.board.chess as WarChess).repetition_filters():
		# Puede que el jugador intentara justo la jugada que repetiría la posición: se le dice por qué no vale.
		game_note = "En War Chess no se puede repetir una posición por tercera vez."
		_refresh()


## War Chess: el tablero sabe qué posiciones han salido ya en la partida (regla de la tercera repetición).
func _war_sync_seen() -> void:
	if mode != "game" or game_back > 0 or view == null or not (view.board.chess is WarChess) or game_history.is_empty():
		return
	(view.board.chess as WarChess).seen = WarChess.count_positions(game_history)


func _game_browse(delta: int) -> void:
	if mode != "game" or game_history.is_empty():
		return
	var was := game_back
	game_back = 0 if delta <= -99 else clampi(game_back + delta, 0, game_history.size() - 1)
	if game_back == was and delta > -99:
		return
	var ply := game_history.size() - 1 - game_back
	view.set_fen(str(game_history[ply]))
	view.board.set_arrows([])
	if ply >= 1 and ply - 1 < game_moves.size():
		var last := str(game_moves[ply - 1])
		view.board.mark_last_move(Chess.sq_index(last.substr(0, 2)), Chess.sq_index(last.substr(2, 2)))
	if game_back == 0:
		view.interactive = game_state == "play"
		_coach_place_badge()
		# Lo que llegó mientras se miraba atrás.
		var pending := _online_pending.duplicate()
		_online_pending = []
		for uci: String in pending:
			_online_move(uci)
	else:
		view.interactive = false
	_actions_mode = ""
	_refresh()


func _online_failed(message: String) -> void:
	online_busy = false
	online_status = message
	if progress_kind == "online" and progress != null and is_instance_valid(progress):
		_open_online()


## La partida del final de una unidad del curso.
func _start_unit_game(unit_id: String) -> void:
	for unit: Dictionary in course:
		if str(unit["id"]) == unit_id and unit.has("game"):
			var cfg: Dictionary = (unit["game"] as Dictionary).duplicate()
			cfg["unit"] = unit_id
			_start_game(cfg, 0)
			return


## Empieza una partida. color: 0 blancas, 1 negras, −1 lo elegido en la página (con «Al azar»).
func _start_game(cfg: Dictionary, color: int) -> void:
	detail_from_over = false
	_close_progress()
	_stop_game_thread()
	run_id += 1
	_clear_explanation()
	_try = {}
	_gap_limit = INF
	mode = "game"
	game = cfg
	ask_state = ""
	ask_answer = {}
	_ask_gen += 1
	ask_history = []
	_coach_prev_win = -1
	# Las chapas miden los puntos esperados según el nivel del jugador (su Elo de juego; sin partidas, 1500).
	var gr := GameLog.game_rating(_log())
	coach.player_elo = float(gr["r"]) if int(gr["n"]) > 0 else CoachAI.DEFAULT_ELO
	game_serial += 1
	game_helped = false
	_retry = {}
	_retry_target = {}
	if color < 0:
		color = game_pick_color if game_pick_color < 2 else _rng.randi_range(0, 1)
		# Partida elegida en la página: con el ritmo elegido allí.
		cfg = cfg.duplicate()
		cfg["clock"] = _time_control()
	game_color = color
	var clock: Array = cfg.get("clock", [])
	game = cfg
	game_clocked = clock.size() == 2 and int(clock[0]) > 0
	_flag_claimed = false
	game_clock = [float(clock[0]) * 60000.0, float(clock[0]) * 60000.0] if game_clocked else [0.0, 0.0]
	game_inc_ms = float(clock[1]) * 1000.0 if game_clocked else 0.0
	clock_up = 1.0 if game_color == 0 else 0.0
	game_bot = Bot.new(int(cfg.get("level", 0)), str(cfg.get("variant", "")))
	var fen := str(cfg.get("fen", ""))
	if fen == "":
		fen = Board3D.START_FEN
	if str(cfg.get("variant", "")) == "war" and not WarChess.is_war_fen(fen):
		fen = WarChess.start_fen(fen)
	view.armor_text = Loc.t("Blindar")
	view.board.set_arrows([])
	view.board.set_goals([])
	view.board.only_square = -1
	view.set_fen(fen)
	view.set_orientation(color)
	game_history = [view.board.chess.fen()]
	game_moves = []
	game_back = 0
	_online_pending = []
	review = []
	review_done = false
	review_at = -1
	detail = []
	detail_done = false
	detail_at = -1
	game_recorded = false
	game_clock_side = view.board.chess.turn
	game_state = "play"
	game_won = 0
	game_result = ""
	game_note = ""
	_clear_coach()
	var line := str(cfg.get("kids", ""))
	if line == "":
		line = _kid_line("gameWhite" if color == 0 else "gameBlack")
	_say([line])
	if bool(cfg.get("online", false)):
		# Partida online: el rival llega por la red, no hay hilo del rival.
		game_clock_side = view.board.chess.turn
		if view.board.chess.turn != game_color:
			game_state = "think"
			view.interactive = false
		else:
			view.interactive = true
		_refresh()
		return
	if view.board.chess.turn != game_color:
		_game_bot_turn()
	else:
		view.interactive = true
		_refresh()


## Jugada del jugador (el tablero ya la ha hecho).
func _game_move(uci: String) -> void:
	if game_state != "play":
		return
	var before := WarChess.parse(str(game_history[game_history.size() - 1]))
	var m := before.find_uci(uci)
	game_history.append(view.board.chess.fen())
	game_moves.append(uci)
	view.board.set_arrows([])
	game_note = ""
	if WarChess.is_break_move(m) and (view.board.chess as WarChess).is_armored(Chess.move_to(m)):
		game_note = Loc.f("Has agrietado el blindaje del peón de %s: un golpe más y cae.", Chess.sq_name(Chess.move_to(m)))
	var is_online := bool(game.get("online", false))
	if is_online:
		# Con reloj y pulsado automático, la jugada y la pulsación van juntas; a mano, la pulsación va después.
		online.play(uci, game_clocked and not press_clock)
	if str(game.get("campeonato", "")) != "" and m >= 0:
		CampeonatoUI.react(self, before, m)
	if _game_check_end(before, m):
		return
	_coach_move(str(game_history[game_history.size() - 2]), uci, game_history.size() - 2)
	_wait_bot_react(str(game_history[game_history.size() - 2]), str(game_history[-1]), uci)
	if is_online and not (game_clocked and press_clock):
		game_clock_side = 1 - game_color
		game_state = "think"
		view.interactive = false
		_refresh()
		return
	if game_clocked and press_clock:
		# Como en una partida de verdad: tu reloj sigue corriendo hasta que lo pulsas.
		game_state = "press"
		view.interactive = false
		game_clock_side = game_color
		_press_since = Time.get_ticks_msec()
		_press_warned = false
		_refresh()
		return
	if game_clocked:
		game_clock[game_color] += game_inc_ms
	_game_bot_turn()


## El jugador pulsa su reloj: se suma su incremento y empieza a correr el del rival.
func _press_game_clock() -> void:
	if mode != "game" or game_state != "press":
		return
	game_note = ""
	if sound_on:
		view.board.sound.emit("place", 0.5)
	if bool(game.get("online", false)):
		online.press()
		game_clock_side = 1 - game_color
		game_state = "think"
		view.interactive = false
		_refresh()
		return
	game_clock[game_color] += game_inc_ms
	_game_bot_turn()


func _game_bot_turn() -> void:
	game_clock_side = 1 - game_color
	game_state = "think"
	view.interactive = false
	_refresh()
	var pos := view.board.chess.copy()
	var my_run := run_id
	_stop_game_thread()
	# Con reloj, el rival reparte su tiempo: una treintava parte de lo que le queda, más casi todo el incremento.
	if game_clocked:
		game_bot.time_cap = maxf(0.2, game_clock[1 - game_color] / 1000.0 / 30.0 + game_inc_ms / 1000.0 * 0.8)
	var started := Time.get_ticks_msec()
	if Bot.uses_stockfish(game_bot.level) and str(game.get("variant", "")) == "" and local_engine.available():
		_game_sf_turn(pos, my_run, started)
		return
	_game_thread = Thread.new()
	_game_thread.start(_game_think.bind(game_bot, pos, my_run, started))


## Rival «Experto»: juega Stockfish del móvil con su Elo. Si falla, el rival de la app.
func _game_sf_turn(pos: Chess, my_run: int, started: int) -> void:
	var ms := int(float(Bot.LEVELS[game_bot.level]["think"]) * 1000.0)
	if game_clocked:
		ms = mini(ms, int(maxf(0.2, game_clock[1 - game_color] / 1000.0 / 30.0 + game_inc_ms / 1000.0 * 0.8) * 1000.0))
	var uci := await local_engine.play(pos.fen(), maxi(100, ms), Bot.sf_elo(game_bot.level))
	if my_run != run_id or mode != "game":
		return
	var m := pos.find_uci(uci)
	if m < 0:
		_game_thread = Thread.new()
		_game_thread.start(_game_think.bind(game_bot, pos, my_run, started))
		return
	_game_bot_done(pos, m, my_run, started)



## El reloj de la partida corre para el bando que mueve.
## Piezas comidas: se ven en las partidas (también al mirar jugadas anteriores o al analizar). Se recalculan solo
## cuando cambia la posición, el bando de abajo o los colores.
func _sync_captures() -> void:
	if cap_top == null or not is_instance_valid(cap_top):
		return
	var on := mode == "game" and not game_history.is_empty()
	var h := CAP_H if on else 0.0
	if absf(cap_top.custom_minimum_size.y - h) > 0.5:
		cap_top.custom_minimum_size = Vector2(0.0, h)
		cap_bottom.custom_minimum_size = Vector2(0.0, h)
		_cap_key = ""
		_layout()
	cap_top.visible = on
	cap_bottom.visible = on
	if not on:
		return
	var now: Chess = view.board.chess
	var bottom := view.board.orientation
	var swatches: Array = view.board.piece_swatches()
	var key := "%d|%d|%s|%s|%s" % [hash(now.b), bottom, str(game_history[0]), str(swatches), str(dark)]
	if key == _cap_key:
		return
	_cap_key = key
	var r := Captures.of(Chess.from_fen(str(game_history[0])), now)
	var lost: Array = r["lost"]
	var lead := int(r["lead"])
	# Arriba, lo que ha comido el de arriba (piezas del color de abajo); abajo, al revés.
	for i in 2:
		var strip: CaptureStrip = cap_top if i == 0 else cap_bottom
		var eater := 1 - bottom if i == 0 else bottom
		var victim := 1 - eater
		var fill: Color = swatches[victim]
		strip.pieces = lost[victim]
		strip.fill = fill
		if victim == 0:
			strip.line = fill.darkened(0.72)
		else:
			strip.line = fill.lightened(0.6) if dark else fill.darkened(0.6)
		strip.lead = lead if eater == 0 else -lead
		strip.ink = _c("quiet")
		strip.font = font_semibold
		strip.font_size = F_SUB
		strip.queue_redraw()


## Pantalla encendida (decisión de Pablo, 22 nov; antes no se apagaba nunca con la app abierta): siempre en una
## partida online o con reloj; en el tablero (partida sin reloj, problemas, lecciones, vídeos) mientras se use, hasta
## SCREEN_IDLE_MS sin tocar; en los menús, como cualquier app.
const SCREEN_IDLE_MS := 300000
const SCREEN_OVER_IDLE_MS := 60000
var _last_touch_ms := 0
var _screen_kept := false
var _screen_check := 0.0


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventMouseButton or event is InputEventKey:
		_last_touch_ms = Time.get_ticks_msec()


func _screen_wanted(now_ms: int) -> bool:
	var page := progress != null and is_instance_valid(progress)
	if page:
		return false
	if mode == "game" and game_state in ["play", "think", "press"] and (bool(game.get("online", false)) or game_clocked):
		return true
	if not film.is_empty():
		return true
	# Partida terminada (p. ej. online, se fue y perdió por tiempo): a un minuto sin tocar, se deja apagar.
	if mode == "game" and game_state == "over":
		return now_ms - _last_touch_ms < SCREEN_OVER_IDLE_MS
	var on_board := mode in ["game", "train", "test", "learn", "free", "tutor"]
	return on_board and now_ms - _last_touch_ms < SCREEN_IDLE_MS


func _sync_keep_screen(delta: float) -> void:
	_screen_check -= delta
	if _screen_check > 0.0:
		return
	_screen_check = 1.0
	var want := _screen_wanted(Time.get_ticks_msec())
	if want != _screen_kept:
		_screen_kept = want
		DisplayServer.screen_set_keep_on(want)


func _process(delta: float) -> void:
	ads.tick(delta)
	_sync_keep_screen(delta)
	if not film.is_empty():
		_film_tick()
	_sync_captures()
	if mode == "game" and game.has("rival_id") and view != null and view.is_inside_tree():
		# Al ampliar, girar o inclinar el tablero, el rival de encima se recoloca (o se esconde si no cabe).
		var top := view.get_global_rect().position.y + view.board_top()
		if absf(top - _camp_tag_top) > 1.5:
			_sync_camp_tag()
	if mode == "game" and bool(game.get("online", false)) and game_state in ["play", "think", "press"]:
		_online_idle_tick()
	if mode != "game" or not game_clocked or not (game_state in ["play", "think", "press"]):
		return
	if bool(game.get("online", false)):
		_online_clock_tick(delta)
		return
	var side := game_clock_side
	clock_up = move_toward(clock_up, 1.0 if side == game_color else 0.0, delta / 0.12)
	game_clock[side] = maxf(0.0, float(game_clock[side]) - delta * 1000.0)
	if float(game_clock[side]) <= 0.0:
		_game_flag(side)
		return
	if game_state == "press" and press_reminder and not _press_warned and Time.get_ticks_msec() - _press_since > int(PRESS_REMINDER * 1000.0):
		_press_nag()
	_show_clocks()


## Han pasado PRESS_REMINDER segundos sin pulsar el reloj: globo sobre el tablero, vibración y sonido. Con la
## tarjeta de reloj no se ve la nota de la partida, así que el globo es lo que avisa.
func _press_nag() -> void:
	_press_warned = true
	game_note = "¡Pulsa el reloj! Tu tiempo sigue corriendo."
	_board_bubble("clock", "¡Pulsa el reloj! Tu tiempo sigue corriendo.", "peach", false, 3.0)
	Input.vibrate_handheld(300)
	_sfx("error")
	_refresh()


## Reloj online: lo que dicen las horas del servidor. Si se me acaba el tiempo, pierdo; si se le acaba al rival,
## se espera un margen por si su pulsación viene de camino y se apunta.
var _flag_claimed := false


func _online_clock_tick(delta: float) -> void:
	var now: Dictionary = online.clock_now()
	var left: Array = now["left"]
	var side := int(now["side"])
	game_clock = [maxf(0.0, float(left[0])), maxf(0.0, float(left[1]))]
	game_clock_side = side
	clock_up = move_toward(clock_up, 1.0 if side == game_color else 0.0, delta / 0.12)
	if float(left[side]) <= 0.0 and side == game_color:
		online.claim_time(game_color)
		_game_flag(game_color)
		_sfx("error")
		return
	if float(left[side]) <= -Online.FLAG_GRACE_MS and side != game_color and not _flag_claimed:
		_flag_claimed = true
		online.claim_time(side)
	if game_state == "press" and press_reminder and not _press_warned and Time.get_ticks_msec() - _press_since > int(PRESS_REMINDER * 1000.0):
		_press_nag()
	_show_clocks()


func _show_clocks() -> void:
	if chess_clock != null and is_instance_valid(chess_clock):
		chess_clock.times = [float(game_clock[game_color]), float(game_clock[1 - game_color])]
		chess_clock.running = -1 if game_state == "over" else (0 if game_clock_side == game_color else 1)
		chess_clock.up_mine = clock_up
		chess_clock.call_press = game_state == "press"
		chess_clock.can_press = game_state == "press"
		chess_clock.queue_redraw()
	if _clock_labels.size() != 2:
		return
	var side := game_clock_side
	for i in 2:
		var l: Label = _clock_labels[i]
		if not is_instance_valid(l):
			continue
		var color := game_color if i == 0 else 1 - game_color
		var ms := float(game_clock[color])
		var text := ""
		if ms < 10000.0:
			text = "%.1f" % (ms / 1000.0)
		else:
			var secs := int(ceil(ms / 1000.0))
			text = "%d:%02d" % [secs / 60, secs % 60]
		l.text = "%s  %s" % [str(l.get_meta("who")), text]
		var running := side == color and game_state != "over"
		l.modulate.a = 1.0 if running else 0.45
		l.add_theme_color_override("font_color", _c("bad") if ms < 10000.0 else _c("ink"))


## Se le acaba el tiempo a `side`. Pierde, salvo que el rival no tenga con qué dar mate (entonces, tablas).
func _game_flag(side: int) -> void:
	_stop_game_thread()
	run_id += 1
	game_clock[side] = 0.0
	game_state = "over"
	view.interactive = false
	var mater := false
	var minors := 0
	for p in view.board.chess.b:
		if p != 0 and Chess.color_of(p) != side:
			var t := Chess.type_of(p)
			if t == Chess.PAWN or t == Chess.ROOK or t == Chess.QUEEN:
				mater = true
			elif t == Chess.KNIGHT or t == Chess.BISHOP:
				minors += 1
	mater = mater or minors >= 2
	if not mater:
		game_won = 0
		game_result = "Se acabó el tiempo, pero no queda material para dar mate: tablas."
	elif side == game_color:
		game_won = -1
		game_result = "Se te ha acabado el tiempo."
	else:
		game_won = 1
		game_result = "Al rival se le ha acabado el tiempo: ¡has ganado!"
	_wait_bot_farewell()
	_refresh()


## En otro hilo: el rival piensa sin congelar la pantalla.
func _game_think(bot: Bot, pos: Chess, my_run: int, started: int) -> void:
	var m := bot.choose(pos)
	_game_bot_done.call_deferred(pos, m, my_run, started)


func _game_bot_done(pos: Chess, m: int, my_run: int, started: int) -> void:
	_stop_game_thread()
	if my_run != run_id or mode != "game" or game_state == "over":
		return
	# Que no conteste de golpe: medio segundo como mínimo (Robi, el de la espera online, piensa como una persona).
	var waited := Time.get_ticks_msec() - started
	var least := 550.0
	if bool(game.get("wait_bot", false)):
		least = WaitBot.think_ms(_rng.randf(), game_history.size(), game_clock[1 - game_color] if game_clocked else 0.0)
	if waited < least:
		await _wait((least - float(waited)) / 1000.0)
		if my_run != run_id or mode != "game" or game_state == "over":
			return
	# Con el profesor: el rival espera a que salga la valoración de tu jugada (y medio segundo más, para que se
	# vea la chapa sobre tu pieza antes de que el tablero cambie). Como mucho, 7,5 segundos (con Stockfish en el
	# servidor; si no contesta a los 6, vale el motor local).
	var held := 0
	while _coach_pending and held < 150:
		held += 1
		await _wait(0.05)
		if my_run != run_id or mode != "game" or game_state == "over":
			return
	if held > 0:
		await _wait(0.5)
		if my_run != run_id or mode != "game" or game_state == "over":
			return
	if m < 0:
		_game_check_end(null, -1)
		return
	if str(game.get("campeonato", "")) != "":
		CampeonatoUI.react(self, pos, m)
	if game_back > 0:
		# Mirando jugadas anteriores: al directo, para ver la jugada del rival.
		game_back = 0
		view.set_fen(pos.fen())
		_actions_mode = ""
	var san := SanEs.san(pos, m)
	view.show_move(Chess.uci(m))
	# El tablero quita la chapa con cada jugada: la del profesor se vuelve a poner, para que se vea hasta tu
	# siguiente jugada (salvo que el rival haya capturado esa pieza).
	_coach_place_badge()
	game_history.append(view.board.chess.fen())
	game_moves.append(Chess.uci(m))
	if game_clocked:
		game_clock[1 - game_color] += game_inc_ms
	game_note = "Ha movido el rival. ¡Te toca!" if kids else Loc.f("El rival ha jugado %s.", san)
	var war_note := _war_rival_note(pos, m)
	if war_note != "":
		game_note = war_note
	if _game_check_end(pos, m):
		return
	game_state = "play"
	game_clock_side = game_color
	view.interactive = true
	if str(game.get("variant", "")) != "peones" and view.board.chess.in_check():
		game_note = _kid_line("inCheck") if kids else Loc.f("El rival ha jugado %s: tu rey está en jaque.", san)
		_say([_kid_line("inCheck")])
	_refresh()


## War Chess: qué ha hecho el rival si ha blindado o ha roto (o agrietado) un blindaje; "" si no. `pos`, antes de su
## jugada; el tablero, ya con ella.
func _war_rival_note(pos: Chess, m: int) -> String:
	if not (view.board.chess is WarChess):
		return ""
	if WarChess.is_armor_move(m):
		return Loc.f("El rival ha blindado su %s de %s.", [Loc.t(_piece_noun(pos.b[Chess.move_from(m)])), Chess.sq_name(Chess.move_from(m))])
	if WarChess.is_break_move(m):
		if (view.board.chess as WarChess).is_armored(Chess.move_to(m)):
			return Loc.f("El rival ha agrietado el blindaje de tu peón en %s: aguanta un golpe más.", Chess.sq_name(Chess.move_to(m)))
		return Loc.f("El rival ha roto el blindaje de tu %s en %s.", [Loc.t(_piece_noun(pos.b[Chess.move_to(m)])), Chess.sq_name(Chess.move_to(m))])
	return ""


# ---------------------------------------------------------------- espera online: Robi, el bot (core/wait_bot.gd)

## Si en `seconds` no ha empezado la partida (y nadie está entrando), se ofrece jugar contra el bot.
func _offer_bot_later(gen: int, seconds: int) -> void:
	await get_tree().create_timer(float(seconds)).timeout
	if gen != _wait_gen or not online_busy or online.phase == "joining" or online.phase == "playing":
		return
	online_bot_offer = true
	if progress_kind == "online":
		_open_online()


func _bot_offer_block() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.add_child(_centered(_para("Ahora no hay nadie más conectado en este espacio.", F_BODY, _c("ink"), font_semibold)))
	var tint := _tint("peach")
	box.add_child(_button("bot", Loc.f("Jugar contra %s, un bot de la app", WaitBot.NAME), _play_wait_bot, tint[0], tint[1], {"font_size": F_BODY, "height": 116.0, "icon": 56.0}))
	box.add_child(_centered(_para("Es un bot, no una persona: juega a tu nivel y con el mismo ritmo. Dejas de buscar rival; al acabar puedes volver a buscar.", F_FOOT + 2, _c("quiet"), font_regular)))
	return box


func _play_wait_bot() -> void:
	var space := online_space
	online.leave()
	online_busy = false
	online_bot_offer = false
	_wait_gen += 1
	var gr := GameLog.game_rating(_log())
	var lvl := Bot.closest_level(float(gr["r"]) if int(gr["n"]) > 0 else 0.0)
	var war := Online.is_war(space)
	var clock: Array = Online.rhythm_parts(space)
	var title := Loc.f("%s (bot) · %s", [WaitBot.NAME, Online.space_label(space)])
	_bot_cheer_at = -99
	_start_game({"variant": "war" if war else "", "level": lvl, "title": title, "text": WAR_RULES if war else "", "kids": "", "unit": "", "clock": clock if int(clock[0]) > 0 else [], "wait_bot": true}, _rng.randi_range(0, 1))
	var run := run_id
	await _wait(1.4)
	if run == run_id and mode == "game":
		_bot_bubble("saludo")


func _bot_bubble(kind: String) -> void:
	var tints := {"saludo": "sky", "aplauso": "butter", "genial": "peach", "arriba": "mint", "buena": "lilac"}
	_board_bubble("g_" + kind, "%s (bot): %s" % [WaitBot.NAME, Loc.t(str(Online.GESTURE_TEXT.get(kind, "")))], str(tints.get(kind, "sky")), true)


func _wait_bot_react(fen_before: String, fen_after: String, uci: String) -> void:
	if not bool(game.get("wait_bot", false)) or str(game.get("variant", "")) != "":
		return
	var ply := game_history.size() - 2
	var captured := WaitBot.captured_value(fen_before, fen_after, game_color)
	if captured < 3:
		return
	var blunder := not GameReview.analyze_move(fen_before, uci, ply).is_empty()
	var kind := WaitBot.cheer_for(captured, blunder, (ply - _bot_cheer_at) / 2, _rng.randf())
	if kind == "":
		return
	_bot_cheer_at = ply
	var run := run_id
	await _wait(0.7)
	if run == run_id and mode == "game":
		_bot_bubble(kind)


func _wait_bot_farewell() -> void:
	if not bool(game.get("wait_bot", false)):
		return
	var run := run_id
	for kind: String in WaitBot.farewell(game_won):
		await _wait(1.2)
		if run != run_id or mode != "game":
			return
		_bot_bubble(kind)


# ---------------------------------------------------------------- campeonato (core/campeonato.gd, ui/campeonato_ui.gd)

var _camp_state := {}
var _camp_loaded := false
## Lo que se elige al empezar un torneo: formato (Campeonato.FORMATS), ritmo (0 = el de la sala, 1–6 = los de
## TIME_CONTROLS, 7 = «Otro» con camp_min + camp_inc). Se acuerda la última elección.
var camp_fmt := "copa"
var camp_tc := 0
var camp_min := 10
var camp_inc := 5
var _camp_news := ""


func campeonato_state() -> Dictionary:
	if not _camp_loaded:
		_camp_state = Campeonato.load_state()
		_camp_loaded = true
		var last: Dictionary = _camp_state.get("ultimo", {})
		if not Campeonato.format_def(str(last.get("formato", ""))).is_empty():
			camp_fmt = str(last["formato"])
		camp_tc = clampi(int(last.get("ritmo", camp_tc)), 0, TIME_CONTROLS.size() - 1)
		camp_min = clampi(int(last.get("min", camp_min)), 1, 180)
		camp_inc = clampi(int(last.get("inc", camp_inc)), 0, 60)
	return _camp_state


func campeonato_save() -> void:
	Campeonato.save_state(campeonato_state())


## Tu Elo para el cuadro y para abrir salas: tu nivel de juego (0 si aún no has jugado partidas).
func campeonato_elo() -> float:
	var gr := GameLog.game_rating(_log())
	return float(gr["r"]) if int(gr["n"]) > 0 else 0.0


## Stockfish en el móvil (los rivales del hotel son «Experto»).
func campeonato_stockfish() -> bool:
	return local_engine != null and local_engine.available()


func _open_campeonato() -> void:
	CampeonatoUI.ambient_stop()
	CampeonatoUI.open_list(self)


func _open_campeonato_room(key: String, news: String = "", animate: bool = false) -> void:
	_camp_news = news
	CampeonatoUI.open_room(self, key, news, animate)


var _camp_opts_box: VBoxContainer
var _camp_opts_scroll: ScrollContainer
const CAMP_FMT_TINTS := {"copa": "butter", "copa_match": "peach", "cuadrangular": "mint", "suizo": "sky", "liga": "lilac"}
## Nombre del tipo de ritmo bajo cada casilla (índices de TIME_CONTROLS; 0 es el de la sala).
const CAMP_TC_KIND := ["De la sala", "Blitz", "Blitz", "Rápida", "Rápida", "Clásica", "Clásica", "A tu gusto"]


## La ventana de «Empezar el torneo»: formato y ritmo en grande y con su color, y «Empezar» al final. Los cambios
## valen al momento; tocar fuera solo la cierra.
func _campeonato_options(key: String) -> void:
	campeonato_state()
	var column := _popup(Loc.t("Tu torneo"), "")
	_camp_opts_scroll = ScrollContainer.new()
	_camp_opts_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_camp_opts_scroll)
	_camp_opts_box = VBoxContainer.new()
	_camp_opts_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_camp_opts_box.add_theme_constant_override("separation", 14)
	_camp_opts_scroll.add_child(_camp_opts_box)
	_fill_camp_options(key)
	column.add_child(_spacer(6.0))
	var go := _button("play", "Empezar el torneo", func() -> void:
		_close_confirm()
		_campeonato_new(key), _c("accent"), _c("accent_ink"), {"font_size": F_BODY, "height": 124.0, "icon": 56.0, "radius": 62, "trailing": true, "glow": _c("glow")})
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(go)
	_confirm_on_close = func() -> void:
		_camp_opts_box = null
		_camp_opts_scroll = null


func _fill_camp_options(key: String) -> void:
	if _camp_opts_box == null or not is_instance_valid(_camp_opts_box):
		return
	for c in _camp_opts_box.get_children():
		_camp_opts_box.remove_child(c)
		c.queue_free()
	var box := _camp_opts_box
	var quiet := _c("quiet")
	box.add_child(_line(Loc.t("Formato").to_upper(), F_SUB, quiet, font_semibold))
	for f: Dictionary in Campeonato.FORMATS:
		var id := str(f["id"])
		box.add_child(_choice_card(str(f["icon"]), str(CAMP_FMT_TINTS.get(id, "peach")), Loc.t(str(f["name"])), Loc.t(str(f["short"])), id == camp_fmt, _camp_set_format.bind(key, id), _camp_format_info.bind(key, id)))
	box.add_child(_spacer(12.0))
	box.add_child(_line(Loc.t("Ritmo").to_upper(), F_SUB, quiet, font_semibold))
	var room: Array = Campeonato.tournament(key)["clock"]
	for row_i in 2:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		for col_i in 4:
			var i := row_i * 4 + col_i
			var big := "%d+%d" % [int(room[0]), int(room[1])] if i == 0 else (str(TIME_CONTROLS[i][0]) if i < TIME_CONTROLS.size() - 1 else "···")
			var tile := _rhythm_tile(big, Loc.t(str(CAMP_TC_KIND[i])), i == camp_tc, _camp_set_tc_at.bind(i, key))
			row.add_child(tile)
		box.add_child(row)
	if camp_tc == TIME_CONTROLS.size() - 1:
		box.add_child(_stepper("Minutos por jugador", camp_min, _camp_step_minutes.bind(key)))
		box.add_child(_stepper("Segundos más por jugada", camp_inc, _camp_step_increment.bind(key)))
	var tc := _camp_clock(key)
	box.add_child(_para(Loc.f("%d minutos por jugador%s. Con reloj no hay deshacer ni pistas, como en una partida oficial; si se te acaba el tiempo, pierdes.", [tc[0], Loc.t(" y %d segundos más por jugada") % tc[1] if tc[1] > 0 else ""]), F_FOOT, quiet, font_regular))
	if not Premium.active():
		box.add_child(_para("Todo este torneo es de Premium (juega Stockfish)." if Campeonato.premium_from(key) == 0 else "Las dos primeras rondas son gratis; desde la tercera, Premium.", F_FOOT, quiet, font_regular))
	_fit_camp_options.call_deferred()


## La explicación de un formato, en otra ventana. «OK» (o tocar fuera) vuelve a la de elegir.
func _camp_format_info(key: String, id: String) -> void:
	var f := Campeonato.format_def(id)
	var column := _popup(Loc.t("Formato"), "")
	var head := _icon_row(str(f["icon"]), str(CAMP_FMT_TINTS.get(id, "peach")), Loc.t(str(f["name"])), Loc.t(str(f["short"])), 132.0, F_HEAD, F_SUB)
	column.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 16)
	scroll.add_child(box)
	for para: String in f["info"]:
		box.add_child(_para(para, F_BODY, _c("ink"), font_regular))
	column.add_child(_spacer(6.0))
	var ok := _button("check", "OK", _close_confirm, _c("accent"), _c("accent_ink"), {"font_size": F_BODY, "height": 116.0, "icon": 56.0, "radius": 58})
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(ok)
	_confirm_on_close = func() -> void:
		_campeonato_options.call_deferred(key)
	var fit := func() -> void:
		if is_instance_valid(scroll) and is_instance_valid(box):
			scroll.custom_minimum_size.y = minf(box.get_combined_minimum_size().y, maxf(400.0, size.y - 760.0))
	box.minimum_size_changed.connect(fit)
	fit.call_deferred()


func _fit_camp_options() -> void:
	if _camp_opts_scroll == null or not is_instance_valid(_camp_opts_scroll):
		return
	var want := _camp_opts_box.get_combined_minimum_size().y
	_camp_opts_scroll.custom_minimum_size.y = minf(want, maxf(400.0, size.y - 560.0))


## Tarjeta grande de una opción: su icono de color, el nombre en grande y lo que es; la elegida, con borde y marca.
func _choice_card(icon_name: String, tint_name: String, heading: String, text: String, chosen: bool, on_press: Callable, on_info: Callable = Callable()) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.pressed.connect(on_press)
	_style_button(b, _c("accent_soft") if chosen else _c("field"), _c("ink"), 44, F_BODY, font_semibold, Color(0, 0, 0, 0), _c("accent") if chosen else Color(0, 0, 0, 0))
	var pad := _pad(22, 22, 24, 22)
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.add_child(pad)
	var row := _icon_row(icon_name, tint_name, heading, text, 132.0, F_HEAD, F_SUB)
	pad.add_child(row)
	if chosen:
		row.add_child(_icon("check", 60.0, _c("accent_text")))
	if on_info.is_valid():
		var sky := _tint("sky")
		var info := _button("info", "", on_info, sky[0], sky[1], {"height": 104.0, "icon": 60.0, "radius": 52})
		info.custom_minimum_size.x = 104.0
		info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(info)
	var fit := func() -> void:
		if is_instance_valid(b) and is_instance_valid(pad):
			b.custom_minimum_size = Vector2(0.0, pad.get_combined_minimum_size().y)
	pad.minimum_size_changed.connect(fit)
	fit.call()
	b.set_meta("label", heading)
	return b


## Casilla de un ritmo: el número grande y debajo qué tipo es.
func _rhythm_tile(big: String, small: String, chosen: bool, on_press: Callable) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.pressed.connect(on_press)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0.0, 158.0)
	var colors := _choice_colors(chosen)
	_style_button(b, colors[0], colors[1], 40, F_BODY, font_semibold, Color(0, 0, 0, 0), colors[2])
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(col)
	var top := _line(big, F_HEAD, _c("accent_text") if chosen else _c("ink"), font_display)
	top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(top)
	var bottom := _line(small, F_FOOT, colors[1], font_medium)
	bottom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(bottom)
	b.set_meta("label", big)
	return b


func _camp_remember() -> void:
	campeonato_state()["ultimo"] = {"formato": camp_fmt, "ritmo": camp_tc, "min": camp_min, "inc": camp_inc}
	campeonato_save()


func _camp_set_format(key: String, id: String) -> void:
	camp_fmt = id
	_camp_remember()
	_fill_camp_options(key)


## Los botones de _stepper añaden su valor delante de lo que ya llevan atado: (paso, clave).
func _camp_set_tc_at(i: int, key: String) -> void:
	_camp_set_tc(i, key)


func _camp_set_tc(i: int, key: String) -> void:
	camp_tc = clampi(i, 0, TIME_CONTROLS.size() - 1)
	_camp_remember()
	_fill_camp_options(key)


func _camp_step_minutes(dir: int, key: String) -> void:
	var steps := [1, 2, 3, 5, 10, 15, 20, 25, 30, 45, 60, 90, 120]
	var at := steps.find(camp_min)
	camp_min = int(steps[clampi((at if at >= 0 else 4) + dir, 0, steps.size() - 1)])
	_camp_remember()
	_fill_camp_options(key)


func _camp_step_increment(dir: int, key: String) -> void:
	var steps := [0, 1, 2, 3, 5, 10, 15, 20, 30, 60]
	var at := steps.find(camp_inc)
	camp_inc = int(steps[clampi((at if at >= 0 else 0) + dir, 0, steps.size() - 1)])
	_camp_remember()
	_fill_camp_options(key)


## Ritmo elegido para el torneo de una sala: [minutos, incremento]. Siempre con reloj.
func _camp_clock(key: String) -> Array:
	campeonato_state()
	if camp_tc <= 0:
		var room: Array = Campeonato.tournament(key)["clock"]
		return [int(room[0]), int(room[1])]
	var t: Array = TIME_CONTROLS[camp_tc]
	if int(t[1]) < 0:
		return [camp_min, camp_inc]
	return [int(t[1]), int(t[2])]


func _campeonato_locked(text: String) -> void:
	var column := _popup(Loc.t("Sala cerrada"), text)
	column.add_child(_button("check", "Entendido", _close_confirm, _c("field"), _c("ink"), {"font_size": F_BODY, "height": 116.0, "icon": 56.0, "radius": 58}))


func _campeonato_new(key: String) -> void:
	var you := campeonato_elo()
	if you <= 0.0:
		# Sin partidas: entras al cuadro como el rival más flojo de la sala.
		you = float(CampeonatoUI._elo_span(key)[0])
	Campeonato.start(campeonato_state(), key, you, _rng, camp_fmt, _camp_clock(key))
	campeonato_save()
	_campeonato_play(key)


## «Abandonar el torneo» (Pablo, 23 nov): con confirmación; pierdes lo que te queda y vuelves al cuadro terminado.
func _campeonato_abandon(key: String) -> void:
	_confirm("¿Abandonar el torneo?", "Pierdes las partidas que te quedan y el torneo sigue sin ti hasta el final.", "close", "Abandonar", func() -> void:
		Campeonato.abandon(campeonato_state(), key, _rng)
		campeonato_save()
		_open_campeonato_room(key, Loc.t("Has abandonado el torneo.")))


func _campeonato_play(key: String) -> void:
	var tour: Dictionary = (campeonato_state()["torneos"] as Dictionary).get(key, {})
	if tour.is_empty() or Campeonato.current_match(tour, key).is_empty():
		_open_campeonato_room(key)
		return
	if Campeonato.needs_premium(tour, Premium.active(), key):
		_open_premium_offer("campeonato")
		return
	_close_progress()
	CampeonatoUI.walk(self, key)


func _campeonato_start_game(key: String, lv: int) -> void:
	var tour: Dictionary = (campeonato_state()["torneos"] as Dictionary)[key]
	var m := Campeonato.current_match(tour, key)
	var rival := Campeonato.rival(key, str(m["rival"]))
	var round_name := str(m["titulo"])
	# Durante la partida el murmullo se oye de fondo, sin tapar el tablero (Pablo, 23 nov: «más murmullos»).
	CampeonatoUI.ambient_volume(-19.0)
	var cfg := {"variant": "", "level": lv, "title": Loc.f("%s · %s (bot)", [round_name, str(rival.get("name", ""))]), "text": "", "kids": "",
		"unit": "", "clock": m["clock"], "campeonato": key, "rival_nombre": str(rival.get("name", "")), "rival_id": str(m["rival"])}
	_start_game(cfg, int(m["color"]))


## Apunta el resultado en el torneo una sola vez (al acabar o al abandonar) y hace sonar a la sala.
func _campeonato_record_once() -> void:
	var key := str(game.get("campeonato", ""))
	if key == "" or bool(game.get("camp_done", false)):
		return
	game["camp_done"] = true
	var score := 1.0 if game_won > 0 else (0.5 if game_won == 0 else 0.0)
	var r := Campeonato.record(campeonato_state(), key, score, _rng)
	game["camp_decided"] = bool(r.get("decided", false))
	campeonato_save()
	game["camp_news"] = _campeonato_news(key, r)
	CampeonatoUI.ambient_volume(-18.0)
	if game_won > 0:
		# El archivo de la sala pequeña está grabado unos 5 dB más bajo: se compensa casi todo.
		var big := CampeonatoUI.big_room(key)
		CampeonatoUI.effect(self, "aplausos_grande" if big else "aplausos_pequeno", CampeonatoUI.CHEER_DB + (0.0 if big else 3.0))
	elif game_won < 0:
		CampeonatoUI.effect(self, "lamento", CampeonatoUI.CROWD_DB)
		CampeonatoUI.ambient_swell(3.0, 1.8)
	else:
		CampeonatoUI.effect(self, "exclamacion", CampeonatoUI.CROWD_DB)
		CampeonatoUI.ambient_swell(3.0, 1.8)


func _campeonato_news(key: String, r: Dictionary) -> String:
	if r.is_empty():
		return ""
	var tour: Dictionary = (campeonato_state()["torneos"] as Dictionary)[key]
	if not bool(r["decided"]):
		if int(r.get("mini", 0)) == 1:
			return "Primera partida del mini-match jugada. Ahora, la segunda, con los colores cambiados."
		if int(r.get("mini", 0)) == 2:
			return "Mini-match empatado a un punto: desempate rápido, con los colores cambiados."
		return "Tablas: toca desempate, con los colores cambiados." if int(r["tiebreak"]) == 1 else "Tablas otra vez: armagedón. Si hay tablas, pasan las negras."
	if str(r["estado"]) == "campeon":
		return Loc.f("¡Campeón! %s", Loc.t(str(Campeonato.tournament(key)["name"])))
	if bool(r.get("tabla", false)):
		if str(r["estado"]) == "terminado":
			return Loc.f("Has acabado en el puesto %d de %d.", [int(r["puesto"]), (tour["cuadro"] as Array).size()])
		return Loc.f("Partida apuntada. Siguiente: %s.", Campeonato.round_title(tour, int(tour["ronda"])))
	if bool(r["won"]):
		return Loc.f("¡Has ganado! Siguiente ronda: %s.", Campeonato.round_title(tour, int(tour["ronda"])))
	return "Te has quedado fuera esta vez. ¡A por el siguiente!"


func _campeonato_after_game() -> void:
	var key := str(game.get("campeonato", ""))
	_campeonato_record_once()
	var news := str(game.get("camp_news", ""))
	var decided := bool(game.get("camp_decided", false))
	CampeonatoUI.ambient_stop()
	_stop_game_thread()
	run_id += 1
	view.interactive = false
	view.board.set_arrows([])
	game_state = ""
	view.set_orientation(0)
	mode = "free"
	_idle()
	_open_campeonato_room(key, news, decided)


# ---------------------------------------------------------------- profesor IA (premium)

func _exit_tree() -> void:
	for t: Thread in _coach_threads:
		if t.is_started():
			t.wait_to_finish()
	_coach_threads.clear()


func _clear_coach() -> void:
	# Con la lección abierta (p. ej. se apaga el tutor desde la barra), primero el tablero vuelve a la partida: si no,
	# se quedaba el ejemplo en pantalla con la tarjeta de la partida (lo vio Pablo, 21 nov).
	if lesson_open:
		_close_lesson()
	coach_note = ""
	coach_from_ai = false
	coach_waiting = false
	coach_full = ""
	coach_verdict = ""
	coach_lesson = {}
	coach_hint = ""
	coach_retry_line = ""
	_retry = {}
	_coach_local = {}
	_coach_remote_wait = false
	lesson_open = false
	_coach_badge_sq = -1
	_coach_pending = false
	_coach_gen += 1


## Tras cada jugada del jugador, el motor de la app la valora (GameDetail.entry: la mejor, buena, imprecisión,
## error, error grave) en otro hilo, sin parar la partida. Sale la chapa («!», «?!», «?», «??») en el tablero y en la
## tarjeta; si es un error o un error grave, el profesor lo explica a partir de los hechos del análisis.
func _coach_move(fen_before: String, uci: String, ply: int) -> void:
	_clear_coach()
	view.board.set_focus([])
	coach_debug = ""
	coach_verdict = ""
	if _coach_badge_sq >= 0:
		view.board.set_badge(-1, "")
		_coach_badge_sq = -1
	if Premium.test_allowed():
		coach_debug = "Profesor (prueba) · %s · premium %s · activo %s · kids %s · online %s · reloj %s · variante «%s»" % [uci, Premium.active(), Premium.coach_on, kids, bool(game.get("online", false)), game_clocked, str(game.get("variant", ""))]
	if not Premium.coach_applies(kids, bool(game.get("online", false)), game_clocked, str(game.get("variant", "")), game_serial):
		coach_debug += " → no se aplica"
		return
	coach_trial_game = Premium.use_trial(game_serial)
	coach_debug += " → analizando…"
	_coach_gen += 1
	_coach_pending = true
	var t := Thread.new()
	_coach_threads.append(t)
	t.start(_coach_think.bind(fen_before, uci, ply, game_color, run_id, _coach_gen))
	var sf := local_engine.available()
	if sf or CoachAI.tutor_url(coach.cfg) != "":
		# Stockfish manda: el del móvil si lo hay (0,8 s por posición) y, si no, el del servidor. Si no llega a
		# tiempo, vale el motor de la app.
		_coach_remote_wait = true
		coach_waiting = true
		if sf:
			coach_debug += " (Stockfish del móvil)"
			_coach_with_local_sf(fen_before, uci, run_id, _coach_gen)
		else:
			coach.judge_remote(fen_before, uci, run_id, _coach_gen, {}, _coach_prev_win)
		_coach_remote_deadline(_coach_gen, COACH_REMOTE_S + (4.0 if sf else 0.0))


## Se acabaron las partidas gratis con profesor: se avisa una vez, en el bloque del profesor de la tarjeta.
func _coach_trial_over() -> void:
	if Premium.explain_allowed(game_serial) or Premium.trial_told or not Premium.coach_on:
		return
	if kids or bool(game.get("online", false)) or game_clocked or str(game.get("variant", "")) != "":
		return
	Premium.trial_told = true
	Premium.save_state()
	coach_trial_game = 0
	# Debajo de la chapa de la jugada (las chapas siguen siendo gratis).
	var told := Loc.f("Has jugado tus %d partidas gratis con explicaciones. Las chapas de cada jugada siguen gratis; para las explicaciones y las preguntas, hazte Premium.", [Premium.TRIAL_GAMES])
	coach_note = (coach_note + "\n\n" + told) if coach_note != "" else told
	coach_full = coach_note


## En otro hilo: el análisis de la jugada (unos segundos como mucho).
func _coach_think(fen_before: String, uci: String, ply: int, color: int, run: int, gen: int) -> void:
	var e := CoachAI.judge(fen_before, uci, color, ply, COACH_SECONDS)
	_coach_entry_done.call_deferred(e, uci, run, gen)


func _coach_entry_done(e: Dictionary, uci: String, run: int, gen: int) -> void:
	_reap_coach_threads()
	if run != run_id or gen != _coach_gen or mode != "game":
		return
	_coach_local = e
	_coach_local_uci = uci
	if _coach_remote_wait:
		# Se espera a Stockfish; el motor local queda de reserva.
		return
	if coach_lesson.is_empty():
		_coach_apply_local()


## A los COACH_REMOTE_S segundos sin respuesta del servidor, vale el motor local.
## Stockfish del móvil: la posición de antes y la de después de la jugada; luego el servidor prepara las líneas
## con esos análisis (o, sin conexión, se valora aquí mismo: CoachAI.local_judge).
func _coach_with_local_sf(fen: String, uci: String, run: int, gen: int) -> void:
	var a: Dictionary = await local_engine.analyze(fen)
	var after := Chess.from_fen(fen)
	var m := after.find_uci(uci)
	var b := {}
	if m >= 0:
		after.apply(m)
		if not after.legal_moves().is_empty():
			b = await local_engine.analyze(after.fen())
	if run != run_id or gen != _coach_gen:
		return
	coach.judge_remote(fen, uci, run, gen, {} if a.is_empty() else {"A": a, "B": b}, _coach_prev_win)


func _coach_remote_deadline(gen: int, seconds: float = COACH_REMOTE_S) -> void:
	await get_tree().create_timer(seconds).timeout
	if gen != _coach_gen or not _coach_remote_wait:
		return
	_coach_remote_wait = false
	coach_debug += " · Stockfish no contestó a tiempo"
	if not _coach_local.is_empty():
		_coach_apply_local()


func _coach_rating() -> float:
	if player.has("rating") and player["rating"] is Dictionary:
		return float((player["rating"] as Dictionary).get("r", 0.0))
	return 0.0


## Chapa del tablero y nombre de una valoración (las de GameDetail, más «brillante», que solo da Stockfish).
func _coach_badge_for(verdict: String) -> String:
	if verdict == "brilliant" or verdict == "miss":
		return verdict
	return str(GameDetail.BADGE.get(verdict, ""))


func _coach_label(verdict: String) -> String:
	if verdict == "miss":
		return Loc.t("Oportunidad perdida")
	return Loc.t("Brillante") if verdict == "brilliant" else Loc.t(str(GameDetail.LABELS.get(verdict, "")))


func _coach_set_verdict(verdict: String, uci: String) -> void:
	coach_verdict = verdict
	var badge := _coach_badge_for(verdict)
	if badge != "":
		_coach_badge_sq = Chess.sq_index(uci.substr(2, 2))
		_coach_badge_uci = uci
		_coach_badge_kind = badge
		_coach_place_badge()


## Valoración del motor local (sin red o sin respuesta del servidor).
func _coach_apply_local() -> void:
	var e := _coach_local
	_coach_pending = false
	coach_waiting = false
	if e.is_empty():
		_refresh()
		return
	var verdict := str(e.get("verdict", ""))
	coach_debug = coach_debug.replace(" → analizando…", " → %s (motor local: pierde %d%s)" % [verdict, int(e.get("loss", 0)), (" · a la vista: " + str(e["moment"])) if e.has("moment") else ""])
	_coach_set_verdict(verdict, _coach_local_uci)
	_coach_retry_after(str(e.get("fen", "")), verdict, str(e.get("best_uci", "")))
	var verified := str(e.get("full", ""))
	_coach_verified = verified
	_coach_short = str(e.get("short", verified))
	if verdict == GameDetail.INACCURACY:
		# Imprecisión: basta con el texto comprobado, sin gastar una consulta.
		coach_note = _coach_short
		coach_full = verified
		coach_from_ai = false
	elif verdict == GameDetail.MISTAKE or verdict == GameDetail.BLUNDER:
		var facts := CoachAI.facts_for({"fen": str(e.get("fen", "")), "kind": verdict, "text": verified.left(580)}, str(e.get("san", "")), str(e.get("best_san", "")), _coach_rating(), Loc.language)
		coach_waiting = true
		coach.ask(facts, run_id, int(e.get("ply", 0)))
	_refresh()


## Llega la valoración de Stockfish (o {} si no ha podido ser).
func _on_coach_judged(run: int, gen: int, data: Dictionary) -> void:
	if run != run_id or gen != _coach_gen or mode != "game" or not _coach_remote_wait:
		return
	_coach_remote_wait = false
	if data.is_empty():
		coach_debug += " · sin Stockfish"
		if not _coach_local.is_empty():
			_coach_apply_local()
		return
	_coach_apply_remote(data)


func _coach_apply_remote(data: Dictionary) -> void:
	_coach_pending = false
	coach_waiting = false
	var lines: Dictionary = data["lines"]
	var first: Dictionary = (lines["played"] as Array)[0]
	var fen := str(first["fen"])
	var uci := str(first["uci"])
	var verdict := str(data["verdict"])
	coach_lesson = {
		"fen": fen, "uci": uci, "verdict": verdict, "best": str(data.get("best", "")),
		"win_best": int(data.get("win_best", -1)), "win_played": int(data.get("win_played", -1)),
		"lines": {"played": (lines["played"] as Array).duplicate(true), "best": (lines["best"] as Array).duplicate(true)},
		"summary": "", "advice": "", "asked": false, "ready": false,
	}
	coach_debug = coach_debug.replace(" → analizando…", " → %s (Stockfish: de %d%% a %d%%)" % [verdict, int(data.get("win_best", -1)), int(data.get("win_played", -1))])
	_coach_set_verdict(verdict, uci)
	coach_from_ai = false
	coach_full = ""
	_coach_prev_win = int(data.get("win_played", -1))
	var bad := [GameDetail.INACCURACY, GameDetail.MISTAKE, GameDetail.BLUNDER, "miss"].has(verdict)
	if bad:
		var pos := Chess.from_fen(fen)
		var bm := pos.find_uci(str(data.get("best", "")))
		coach_note = (Loc.f("La mejor era %s", SanEs.san(pos, bm)) + ".") if bm >= 0 else ""
		if verdict == "miss" and bm >= 0:
			coach_note = Loc.f("No pierdes nada, pero el rival te había dejado algo mucho mejor: %s.", SanEs.san(pos, bm))
		# Premium: el profesor prepara ya la explicación (estará lista al abrirla). En las partidas gratis, solo si
		# se pide con «Explícamelo» (decisión de Pablo, 21 nov: cada lección cuesta ~0,6 céntimos).
		if Premium.active():
			_coach_request_lesson()
	else:
		coach_note = Loc.t({"brilliant": "¡Brillante! Era la mejor jugada, y entregando material.", "best": "La mejor jugada.", "excellent": "Excelente jugada.", "good": "Buena jugada."}.get(verdict, "Buena jugada."))
	_coach_retry_after(fen, verdict, str(data.get("best", "")))
	_refresh()


## Pide la lección de Claude para la última jugada valorada (una vez).
func _coach_request_lesson() -> void:
	if coach_lesson.is_empty() or bool(coach_lesson.get("asked", false)):
		return
	coach_lesson["asked"] = true
	coach.lesson_remote(CoachAI.lesson_payload(coach_lesson, _coach_rating(), Loc.language), run_id, _coach_gen)


## Llegan los textos del profesor: uno por jugada de cada línea, un resumen y un consejo.
func _on_coach_lesson(run: int, gen: int, data: Dictionary) -> void:
	if run != run_id or gen != _coach_gen or mode != "game" or coach_lesson.is_empty():
		return
	coach_lesson["ready"] = true
	if int(data.get("_error", 0)) == 402:
		_close_lesson()
		_open_premium_offer(str(data.get("_motivo", "premium")))
		return
	if data.is_empty():
		_refresh()
		return
	var lines: Dictionary = coach_lesson["lines"]
	for key: String in ["played", "best"]:
		var texts: Variant = data.get(key, [])
		var steps: Array = lines[key]
		if texts is Array:
			for i in mini(steps.size(), (texts as Array).size()):
				if str((texts as Array)[i]) != "":
					(steps[i] as Dictionary)["text"] = str((texts as Array)[i])
	coach_lesson["summary"] = str(data.get("summary", ""))
	coach_lesson["advice"] = str(data.get("advice", ""))
	if str(coach_lesson["summary"]) != "":
		coach_note = str(coach_lesson["summary"])
		coach_from_ai = true
	if lesson_open and not _lesson_steps().is_empty():
		var now: Dictionary = _lesson_steps()[clampi(lesson_step, 0, _lesson_steps().size() - 1)]
		view.board.set_focus(_tutor_focus(now))
		# Llega el texto del profesor con la lección ya abierta: se dice ese, no el que la app tenía preparado.
		if _tutor_text(now) != _speech_text:
			_speak_tutor(_tutor_text(now))
	_refresh()


# ---------------------------------------------------------------- la lección sobre el tablero

func _lesson_steps(line: String = "") -> Array:
	var which := line if line != "" else lesson_line
	if which == "answer":
		var show: Variant = ask_answer.get("show")
		return (show as Dictionary).get("steps", []) if show is Dictionary else []
	if coach_lesson.is_empty():
		return []
	return (coach_lesson["lines"] as Dictionary).get(which, [])


## Abre la lección: el tablero vuelve a la posición de antes de tu jugada y el profesor la repite, jugada a
## jugada, con flechas; después, si había una mejor, enseña la mejor. Solo en tu turno (el rival no se interrumpe).
func _open_lesson() -> void:
	if coach_lesson.is_empty() or mode != "game" or game_state != "play" or _lesson_steps("played").is_empty():
		return
	if not Premium.explain_allowed(game_serial):
		_open_premium_offer("premium")
		return
	_close_confirm()
	_coach_request_lesson()
	lesson_open = true
	lesson_line = "played"
	game_back = 0
	view.interactive = false
	_lesson_show(0)


func _lesson_show(i: int) -> void:
	var steps := _lesson_steps()
	if steps.is_empty():
		return
	lesson_step = clampi(i, 0, steps.size() - 1)
	var step: Dictionary = steps[lesson_step]
	_lesson_token += 1
	_speak_tutor(_tutor_text(step))
	var token := _lesson_token
	view.set_fen(str(step["fen"]))
	view.board.set_arrows([])
	view.show_move(str(step["uci"]))
	_actions_mode = ""
	_refresh()
	# Las flechas, cuando la pieza ya ha llegado.
	await _wait(0.0 if view.board.anim_mode == Board3D.Anim.NONE else 0.45)
	if token == _lesson_token and lesson_open:
		view.board.set_arrows(CoachAI.board_arrows(step))
		view.board.set_focus(_tutor_focus(step))


## Casillas de las que habla el profesor en un paso (las que nombra el texto, menos las de la propia jugada, que
## ya van marcadas): parpadean en rosa en el tablero, con su pieza. Idea de Pablo (21 nov): a muchos jugadores les
## cuesta localizar «e5» por la notación.
func _tutor_focus(step: Dictionary) -> Array:
	var uci := str(step.get("uci", ""))
	var skip := [uci.substr(0, 2), uci.substr(2, 2)]
	var names: Array = []
	for name: String in CoachAI.squares_in(_tutor_text(step)):
		if not skip.has(name):
			names.append(name)
	return CoachAI.threatened(view.board.chess, names)


func _lesson_has_next() -> bool:
	return lesson_step < _lesson_steps().size() - 1 or (lesson_line == "played" and not _lesson_steps("best").is_empty())


func _lesson_next() -> void:
	if lesson_step < _lesson_steps().size() - 1:
		_lesson_show(lesson_step + 1)
	elif lesson_line == "played" and not _lesson_steps("best").is_empty():
		lesson_line = "best"
		_lesson_show(0)
	else:
		_close_lesson()


func _lesson_prev() -> void:
	if lesson_step > 0:
		_lesson_show(lesson_step - 1)
	elif lesson_line == "best":
		lesson_line = "played"
		_lesson_show(_lesson_steps().size() - 1)


## Cierra la lección: el tablero vuelve a la partida, tal como estaba.
func _close_lesson() -> void:
	if not lesson_open:
		return
	lesson_open = false
	_stop_tutor_speech()
	_lesson_token += 1
	view.set_fen(str(game_history[-1]))
	view.board.set_arrows([])
	if not game_moves.is_empty():
		var last := str(game_moves[-1])
		view.board.mark_last_move(Chess.sq_index(last.substr(0, 2)), Chess.sq_index(last.substr(2, 2)))
	view.interactive = game_state == "play"
	_coach_place_badge()
	_actions_mode = ""
	_refresh()


# ---------------------------------------------------------------- preguntas libres al tutor

## Se puede preguntar: partida con tutor (premium o partida gratis), contra la app.
func _tutor_can_ask() -> bool:
	return mode == "game" and not kids and not game.is_empty() and game_state != "over" and CoachAI.tutor_url(coach.cfg) != "" \
		and Premium.coach_applies(kids, bool(game.get("online", false)), game_clocked, str(game.get("variant", "")), game_serial)


func _open_ask() -> void:
	if not _tutor_can_ask():
		return
	if not Premium.explain_allowed(game_serial):
		_open_premium_offer("premium")
		return
	if ask_mode != "tutor":
		ask_mode = "tutor"
		ask_state = ""
	if ask_state == "" or ask_state == "answer" or ask_state == "error":
		if ask_state != "answer" and ask_state != "error":
			ask_text = ""
		if ask_state == "":
			ask_state = "edit"
	_build_ask_window()


## Ventana de las preguntas: semitransparente y arrastrable, como la de la explicación.
func _build_ask_window() -> void:
	_confirm_on_close = Callable()
	var column := _glass_popup("Asistente" if ask_mode == "assistant" else "Pregunta al tutor", ask_state == "answer" or ask_state == "error")
	_confirm_on_close = _ask_closed
	_ask_window_up = true
	var tint := _tint("lilac")
	var btn := {"font_size": F_SUB, "height": 104.0, "icon": 50.0, "radius": 52}
	match ask_state:
		"edit", "listen":
			ask_edit = LineEdit.new()
			_show_caret(ask_edit)
			ask_edit.text = ask_text
			# El cursor, al final de lo escrito (también tras dictar).
			ask_edit.caret_column = ask_text.length()
			ask_edit.placeholder_text = Loc.t("Habla o escríbeme") if ask_mode == "assistant" and tutor_voice.available() else Loc.t("Pídeme lo que quieras") if ask_mode == "assistant" else (Loc.t("Escribe tu pregunta") if not tutor_voice.available() else Loc.t("Escribe o pulsa «Hablar»"))
			ask_edit.max_length = 400
			ask_edit.add_theme_font_size_override("font_size", F_BODY)
			ask_edit.add_theme_font_override("font", font_medium)
			ask_edit.add_theme_color_override("font_color", _c("ink"))
			ask_edit.custom_minimum_size = Vector2(0.0, 116.0)
			var sb := StyleBoxFlat.new()
			sb.bg_color = _c("surface")
			sb.set_corner_radius_all(40)
			sb.border_color = _c("accent") if ask_state == "listen" else _c("track")
			sb.set_border_width_all(3)
			sb.content_margin_left = 28
			sb.content_margin_right = 28
			ask_edit.add_theme_stylebox_override("normal", sb)
			ask_edit.add_theme_stylebox_override("focus", sb)
			ask_edit.text_changed.connect(func(t: String) -> void: ask_text = t)
			ask_edit.text_submitted.connect(func(_t: String) -> void: _send_question())
			column.add_child(ask_edit)
			if ask_state == "listen":
				column.add_child(_para("Te escucho… habla con calma.", F_SUB, _c("accent_text"), font_semibold))
			elif ask_text == "":
				# Ideas para empezar: tocar una la pregunta tal cual.
				var ideas := HFlowContainer.new()
				ideas.add_theme_constant_override("h_separation", 12)
				ideas.add_theme_constant_override("v_separation", 12)
				for q: String in _ask_ideas():
					var chip := _button("", q, _ask_idea.bind(q), _c("field"), _c("ink"), {"font_size": F_FOOT, "height": 80.0, "radius": 40})
					ideas.add_child(chip)
				column.add_child(ideas)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 16)
			if tutor_voice.available():
				var talk := _button("mic", "Parar" if ask_state == "listen" else "Hablar", _toggle_listen, tint[0], tint[1], btn)
				talk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row.add_child(talk)
			var send := _button("send", "Preguntar", _send_question, _c("accent"), _c("accent_ink"), btn)
			send.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(send)
			column.add_child(row)
			if ask_state == "edit" and not tutor_voice.available():
				column.add_child(_para("También puedes dictar con el micrófono del teclado.", F_CAP, _c("quiet"), font_medium))
		"wait":
			column.add_child(_para("«%s»" % ask_text, F_SUB, _c("quiet"), font_medium))
			column.add_child(_thinking_row())
		"answer":
			column.add_child(_para("«%s»" % ask_text, F_SUB, _c("quiet"), font_medium))
			column.add_child(_para(str(ask_answer.get("answer", "")), F_BODY, _c("ink"), font_medium))
			var listen := _speech_button(str(ask_answer.get("answer", "")))
			if listen != null:
				column.add_child(listen)
			if ask_mode == "tutor" and not _lesson_steps("answer").is_empty():
				var show := _button("play", "Enséñamelo en el tablero", _open_answer_lesson, _c("accent"), _c("accent_ink"), btn)
				show.disabled = game_state != "play"
				column.add_child(show)
			var row2 := HBoxContainer.new()
			row2.add_theme_constant_override("separation", 16)
			var again := _button("ask", "Otra cosa" if ask_mode == "assistant" else "Otra pregunta", _ask_again, tint[0], tint[1], btn)
			again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row2.add_child(again)
			var ok := _button("check", "Entendido", _close_confirm, _c("field"), _c("ink"), btn)
			ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row2.add_child(ok)
			column.add_child(row2)
			# Lo que nombra la respuesta parpadea en el tablero.
			if ask_mode == "tutor":
				view.board.set_focus(_answer_focus())
		"error":
			column.add_child(_para(_ask_error_text(), F_BODY, _c("ink"), font_medium))
			var row3 := HBoxContainer.new()
			row3.add_theme_constant_override("separation", 16)
			var retry := _button("retry", "Reintentar", _send_question, _c("accent"), _c("accent_ink"), btn)
			retry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row3.add_child(retry)
			var close := _button("close", "Cerrar", _close_confirm, _c("field"), _c("ink"), btn)
			close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row3.add_child(close)
			column.add_child(row3)
	var hint := _para("Arrastra la ventana para moverla", F_CAP, _c("quiet"), font_medium)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)


## Mientras el tutor prepara la respuesta: la bombilla se balancea y tres puntos laten, uno detrás de otro.
func _thinking_row() -> HBoxContainer:
	var tint := _tint("lilac")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	var bulb := _icon("bulb", 76.0, tint[1])
	bulb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bulb.pivot_offset = Vector2(38.0, 70.0)
	row.add_child(bulb)
	var rock := bulb.create_tween().set_loops()
	rock.tween_property(bulb, "rotation", 0.22, 0.5).set_trans(Tween.TRANS_SINE)
	rock.tween_property(bulb, "rotation", -0.22, 0.5).set_trans(Tween.TRANS_SINE)
	var label := _para("El tutor está preparando tu respuesta", F_BODY, _c("ink"), font_medium)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	var dots := HBoxContainer.new()
	dots.add_theme_constant_override("separation", 10)
	dots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for i in 3:
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(18.0, 18.0)
		var sb := StyleBoxFlat.new()
		sb.bg_color = tint[1]
		sb.set_corner_radius_all(9)
		dot.add_theme_stylebox_override("panel", sb)
		dot.modulate.a = 0.25
		dots.add_child(dot)
		var beat := dot.create_tween().set_loops()
		beat.tween_interval(0.2 * i)
		beat.tween_property(dot, "modulate:a", 1.0, 0.3)
		beat.tween_property(dot, "modulate:a", 0.25, 0.3)
		beat.tween_interval(0.4 - 0.2 * i)
	row.add_child(dots)
	return row


func _ask_idea(q: String) -> void:
	ask_text = Loc.t(q)
	_send_question()


func _ask_again() -> void:
	ask_state = "edit"
	ask_text = ""
	view.board.set_focus([])
	_build_ask_window()


func _ask_error_text() -> String:
	if ask_error == 429:
		return Loc.t("Has hecho muchas preguntas seguidas. Espera un minuto y vuelve a preguntar.")
	if ask_error == 400:
		return Loc.t("No he entendido la pregunta. Prueba a decirla de otra forma.")
	# 503: el servidor no puede usar la IA (p. ej. sin saldo en la API). No es la conexión del jugador.
	if ask_error == 503:
		return Loc.t("El tutor no está disponible en este momento. Vuelve a intentarlo más tarde.")
	return Loc.t("No he podido contestar: sin conexión o el servidor tarda. Prueba otra vez.")


## Casillas de la respuesta que tienen pieza en el tablero de la partida (las que tiene sentido señalar).
func _answer_focus() -> Array:
	return CoachAI.threatened(view.board.chess, CoachAI.squares_in(str(ask_answer.get("answer", ""))))


func _send_question() -> void:
	if ask_mode == "assistant":
		_send_to_assistant()
		return
	var q := ask_text.strip_edges()
	if q.length() < 2 or not _tutor_can_ask():
		return
	tutor_voice.cancel()
	ask_text = q
	ask_state = "wait"
	ask_answer = {}
	_ask_gen += 1
	view.board.set_focus([])
	coach.ask_remote(CoachAI.ask_payload(game_history, game_moves, game_color, q, _coach_rating(), Loc.language, _ask_shown(), ask_history, _ask_judged()), run_id, _ask_gen)
	_build_ask_window()


# ---------------------------------------------------------------- asistente: el jugador pide cosas con sus palabras

## Ideas para empezar, según el modo de la ventana.
func _ask_ideas() -> Array:
	if ask_mode == "tutor":
		return ["¿Por qué es buena o mala mi última jugada?", "¿Qué planea el rival?", "Dame una pista, sin decirme la jugada"]
	if mode == "game" and game_state == "play":
		return ["Peón de rey dos pasos", "Pon las piezas de mármol", "Dame una pista"]
	return ["Empieza una partida en nivel medio", "Pon el tablero de mármol y en picado", "¿Hay alguien esperando online?"]


func _assistant_available() -> bool:
	return not kids and CoachAI.assistant_url(coach.cfg) != ""


func _open_assistant(listen: bool = false) -> void:
	if not _assistant_available():
		return
	if ask_mode != "assistant" or ask_state == "" or ask_state == "answer" or ask_state == "error":
		ask_text = ""
		ask_state = "edit"
	ask_mode = "assistant"
	# Con el botón de abajo, a escuchar directamente (y la caja sigue ahí para escribir).
	if listen and tutor_voice.available() and ask_state == "edit":
		_toggle_listen()
		return
	_build_ask_window()


## Lo que el asistente necesita saber de la app ahora mismo (y, si toca mover, las jugadas legales).
func _assistant_state() -> Dictionary:
	var screen := mode
	if progress != null and is_instance_valid(progress):
		screen = "pagina:" + progress_kind
	elif sheet_kind != "":
		screen = "opciones"
	var st := {
		"pantalla": screen, "idioma": Loc.language, "piezas": str(SET_NAMES[maxi(0, SETS.find(piece_set))]),
		"material": str(STYLE_NAMES[maxi(0, STYLES.find(board_style))]), "tema": "oscuro" if dark else "claro",
		"inclinacion": roundi(view.board.cam_pitch), "sonido": sound_on, "tutor": Premium.coach_on,
		"perfil": _assistant_profile(),
	}
	if mode == "game" and not game.is_empty():
		var g := {"titulo": str(game.get("title", "")), "online": bool(game.get("online", false)), "reloj": game_clocked, "color": "blancas" if game_color == 0 else "negras", "estado": game_state}
		st["partida"] = g
		if game_state == "play" and game_back == 0 and not lesson_open:
			var pos := view.board.chess
			var legal: Array = []
			for m in pos.legal_moves():
				legal.append("%s=%s" % [SanEs.san(pos, m), Chess.uci(m)])
			st["legal"] = legal
	return st


## Lo que el asistente sabe del jugador para recomendar con datos (sin nada personal: niveles, reto y racha).
func _assistant_profile() -> Dictionary:
	var p := {"stockfish_en_el_movil": local_engine.available(), "premium": Premium.active(), "tutor_partidas_gratis_quedan": Premium.trial_left()}
	if _has_player():
		var r := float(player["rating"]["r"])
		p["tactica"] = {"nivel": Assessment.level_of(r), "de": Assessment.LEVEL_FLOORS.size() - 1, "puntos": roundi(r), "escala": "problemas de Lichess (no es Elo)", "test_hecho": bool(player.get("done", false))}
		var s := _prog()
		var day := _prog_day()
		Progress.ensure_today(s, day, _prog_ctx())
		var goals: Array = Progress.goals(s, day)
		var done := goals.filter(func(g: Dictionary) -> bool: return bool(g["hecho"])).size()
		p["reto_de_hoy"] = {"hechos": done, "de": goals.size(), "cumplido": bool((s["reto"] as Dictionary)["completo"]), "pasos": goals.map(func(g: Dictionary) -> String: return "%s %d de %d%s" % [str(g["tipo"]), int(g["actual"]), int(g["meta"]), " (hecho)" if bool(g["hecho"]) else ""])}
		p["racha_dias"] = Progress.streak_now(s, day)
		p["fallos_por_repasar"] = _pending_fails().size()
	else:
		p["tactica"] = "sin medir: no ha hecho el test de nivel"
	var gr := GameLog.game_rating(_log())
	p["juego"] = {"elo": roundi(float(gr["r"])), "partidas_que_cuentan": int(gr["n"]), "provisional": bool(gr["provisional"])} if int(gr["n"]) > 0 else "sin partidas contra la app todavía"
	return p


func _send_to_assistant() -> void:
	var q := ask_text.strip_edges()
	if q.length() < 2 or not _assistant_available():
		return
	tutor_voice.cancel()
	ask_text = q
	ask_state = "wait"
	ask_answer = {}
	_ask_gen += 1
	coach.assist_remote(q, _assistant_state(), Loc.language, _ask_gen)
	_build_ask_window()


func _on_assistant_reply(gen: int, data: Dictionary) -> void:
	if gen != _ask_gen or ask_mode != "assistant" or ask_state != "wait":
		return
	if data.has("_error"):
		ask_state = "error"
		ask_error = int(data["_error"])
		_build_ask_window()
		return
	var notes: Array = []
	var say := str(data.get("say", ""))
	for a: Variant in data.get("actions", []):
		if a is Dictionary:
			var note: String = await _run_assistant_action(str(a.get("name", "")), a.get("input", {}) if a.get("input") is Dictionary else {})
			if note != "":
				notes.append(note)
		if ask_mode != "assistant":
			return
	if gen != _ask_gen:
		return
	ask_state = "answer"
	ask_answer = {"answer": "\n\n".join(([say] if say != "" else []) + notes)}
	# Hecho sin nada más que contar: la ventana se cierra y la frase sale en un aviso breve. Solo si la frase es
	# corta: una respuesta larga en el aviso se salía de la pantalla por los dos lados (Pablo, 22 nov); esa se queda
	# en la ventana semitransparente, como las demás respuestas.
	if notes.is_empty() and not (data.get("actions", []) as Array).is_empty() and fits_toast(say):
		ask_state = ""
		_confirm_on_close = Callable()
		_close_confirm()
		if say != "":
			_prog_toast(say, "", false)
			_speak_tutor(say)
		return
	_build_ask_window()
	_speak_tutor(str(ask_answer["answer"]))


## Ejecuta una acción del asistente. Devuelve un texto para el jugador si hay algo que contar (un resultado o por
## qué no se ha podido); "" si se hizo sin más.
func _run_assistant_action(action: String, a: Dictionary) -> String:
	match action:
		"empezar_partida":
			if kids:
				return Loc.t("En el modo Kids las partidas se eligen desde el curso.")
			var g := maxi(0, ["muy fácil", "fácil", "medio", "difícil", "muy difícil", "experto"].find(str(a.get("nivel", "medio"))))
			if g == Bot.APP_GROUPS and _level_groups().has(g) and not Premium.active():
				_open_premium_offer("experto")
				return Loc.t("El rival «Experto» (Stockfish) es de Premium.")
			if g == Bot.APP_GROUPS and not _level_groups().has(g):
				return Loc.t("El nivel «Experto» es Stockfish y necesita la app instalada desde el APK completo, en una partida normal (no en War Chess). Prueba con «Muy difícil».")
			var levels := Bot.group_levels(g)
			var lv := int(levels[clampi(int(a.get("subnivel", 1)) - 1, 0, levels.size() - 1)]) if a.has("subnivel") else int(game_sublevels.get(str(g), levels[0]))
			if a.has("color"):
				game_pick_color = maxi(0, ["blancas", "negras", "azar"].find(str(a["color"])))
			if a.has("ritmo"):
				for i in TIME_CONTROLS.size():
					if str(TIME_CONTROLS[i][0]).to_lower() == str(a["ritmo"]):
						game_tc_pick = i
			if a.has("war_chess"):
				game_war = bool(a["war_chess"])
			_close_confirm()
			_start_level(lv)
		"mover":
			if mode != "game" or game_state != "play" or game_back > 0 or lesson_open:
				return Loc.t("Ahora no se puede mover: espera a que te toque en la partida.")
			var uci := str(a.get("uci", ""))
			if view.board.chess.find_uci(uci) < 0:
				return Loc.t("Esa jugada no es legal ahora.")
			_confirm_on_close = Callable()
			_close_confirm()
			view.show_move(uci)
			_game_move(uci)
		"cambiar_piezas":
			_set_pieces_index(maxi(0, ["figuras", "fichas", "simple"].find(str(a.get("piezas", "figuras")))))
		"cambiar_material":
			_set_style_index(maxi(0, ["madera", "mármol", "metal", "ilustrado"].find(str(a.get("material", "madera")))))
		"inclinar_tablero":
			if view.board.is_simple():
				return Loc.t("Con las piezas «Simple» el tablero se ve siempre desde arriba.")
			var deg := clampf(float(a.get("grados", Board3D.DEFAULT_PITCH)), Board3D.PITCH_MIN, Board3D.PITCH_MAX)
			top_view = deg > 84.0
			view.board.animate_view(deg, view.board.cam_yaw)
			_save_settings()
			if float(a.get("grados", deg)) < Board3D.PITCH_MIN:
				return Loc.f("Lo más inclinado que va el tablero son %d grados: lo he dejado así.", int(Board3D.PITCH_MIN))
		"cambiar_tema":
			_set_theme_index(1 if str(a.get("tema", "")) == "oscuro" else 0)
		"animaciones":
			_set_anim(maxi(0, ["completas", "rápidas", "mínimas", "sin"].find(str(a.get("modo", "completas")))))
		"ajuste":
			var on := bool(a.get("activo", true))
			match str(a.get("nombre", "")):
				"sonido": _set_sound(on)
				"contorno": _set_outline(on)
				"seguir_movil": _set_tilt(on)
				"fijar_giro": _set_lock(on)
				"pista_gestos": _set_gesture_hint(on)
				"pulsar_reloj": _set_press_clock(on)
				"tutor":
					if on and _tutor_blocked_reason() != "":
						return Loc.t(_tutor_blocked_reason())
					_set_coach_on(on)
					_refresh()
		"cambiar_idioma":
			_set_language(str(a.get("idioma", Loc.language)))
		"abrir":
			_confirm_on_close = Callable()
			_close_confirm()
			match str(a.get("pantalla", "")):
				"inicio": _open_home()
				"opciones": _open_options()
				"jugar": _open_game_setup()
				"online": _open_online_home()
				"mis_partidas": _open_my_games_from("home")
				"entrenar": _open_train_hub()
				"aprender": _open_course()
				"mi_nivel":
					if _has_player():
						_open_progress("progress")
					else:
						_open_experience()
				"finales_campeones": _open_cine()
				"como_se_usa": _open_welcome()
				"licencias": _open_licences()
				"reto_del_dia":
					if not _has_player():
						_open_experience()
						return Loc.t("Primero, el test de nivel: así el reto del día se ajusta a ti.")
					_open_day()
				"test_nivel":
					if _has_player() and not bool(player.get("done", false)):
						_home_test()
					else:
						_open_experience()
				"repasar_fallos": _start_review_session()
				"mi_icono": _open_avatar()
				"idioma": _open_language_dialog()
		"entrenar":
			if kids:
				return Loc.t("En el modo Kids los problemas están en el curso.")
			_confirm_on_close = Callable()
			_close_confirm()
			if not _has_player():
				_open_experience()
				return Loc.t("Primero, el test de nivel: así los problemas se ajustan a ti.")
			var tema := str(a.get("tema", "mi_nivel"))
			if Assessment.FAMILIES.has(tema):
				_train_family(tema)
			else:
				train_family = ""
				train_level = -1
				_start_training()
		"ver_partidas_online":
			var lobby: Dictionary = await online.lobby()
			if not bool(lobby.get("ok", false)):
				return Loc.t("No he podido mirar las partidas online (sin conexión).")
			var spaces: Dictionary = lobby.get("spaces", {})
			if spaces.is_empty():
				return Loc.t("Ahora mismo no hay nadie esperando rival online. Si entras en «Partida online» y eliges un ritmo, esperas tú y te avisa cuando llegue alguien.")
			var parts: Array = []
			for r: String in spaces.keys():
				parts.append(Loc.f("%s: %d esperando", [Online.rhythm_label(r), (spaces[r] as Array).size()]))
			return Loc.t("Esperando rival ahora:") + " " + ", ".join(parts) + "."
		"accion_partida":
			if mode != "game" or game_state != "play":
				return Loc.t("Eso solo se puede en una partida, cuando te toca.")
			_confirm_on_close = Callable()
			_close_confirm()
			match str(a.get("accion", "")):
				"pista": _game_hint()
				"deshacer": _game_undo()
				"explicamelo":
					if coach_lesson.is_empty():
						return Loc.t("Todavía no hay ninguna jugada tuya que explicar.")
					_open_lesson()
		"preguntar_tutor":
			if not _tutor_can_ask():
				return Loc.t("El tutor solo contesta en una partida contra la app, con el tutor encendido.")
			ask_mode = "tutor"
			ask_text = str(a.get("pregunta", ""))
			_send_question()
	return ""


## Lo que el alumno tiene en pantalla si no es la partida en directo: un paso de la lección (o de la línea de una
## respuesta) o una jugada anterior de la partida. El tutor contesta sobre eso (Pablo preguntó «¿y si le como el
## peón?» mirando un ejemplo y le contestó sobre la partida). Las etiquetas son para Claude: van en español.
func _ask_shown() -> Dictionary:
	if lesson_open:
		var steps := _lesson_steps()
		if steps.is_empty():
			return {}
		var upto := clampi(lesson_step, 0, steps.size() - 1)
		var moves: Array = []
		for i in upto + 1:
			moves.append(str((steps[i] as Dictionary)["uci"]))
		var what: String = {"played": "la lección: lo que jugó el alumno y cómo sigue según Stockfish", "best": "la lección: la mejor jugada, lo que habría pasado si la hubiera jugado", "answer": "la línea que enseñaste en tu respuesta anterior"}.get(lesson_line, "un ejemplo")
		return {"start": str((steps[0] as Dictionary)["fen"]), "moves": moves, "label": "%s, jugada %d de %d" % [what, upto + 1, steps.size()]}
	if game_back > 0 and game_history.size() > game_back:
		var idx := game_history.size() - 1 - game_back
		return {"start": str(game_history[idx]), "moves": [], "label": "repasando la partida hacia atrás: la posición tras la jugada %d de la partida, no la de ahora" % idx}
	return {}


## Cómo se valoró la última jugada del alumno (la chapa que ve), para que el tutor no la contradiga sin explicarlo.
func _ask_judged() -> Dictionary:
	if coach_lesson.is_empty():
		return {}
	return {"uci": str(coach_lesson["uci"]), "verdict": str(coach_lesson["verdict"]), "win_best": int(coach_lesson["win_best"]), "win_played": int(coach_lesson["win_played"])}


func _on_tutor_answer(run: int, gen: int, data: Dictionary) -> void:
	if run != run_id or gen != _ask_gen or ask_state != "wait":
		return
	if int(data.get("_error", 0)) == 402:
		# Sin cupo: no es un error, es la oferta de Premium (o de una recarga).
		ask_state = ""
		_close_confirm()
		_open_premium_offer(str(data.get("_motivo", "premium")))
		return
	if data.has("_error"):
		ask_state = "error"
		ask_error = int(data["_error"])
	else:
		ask_state = "answer"
		ask_answer = data
		_speak_tutor(str(data.get("answer", "")))
		ask_history.append({"q": ask_text, "a": str(data.get("answer", ""))})
		if ask_history.size() > 3:
			ask_history = ask_history.slice(-3)
	# La respuesta sale aunque se hubiera cerrado la ventana mientras pensaba. Con la ventana abierta, siempre: también
	# durante la lección (antes se quedaba en «El tutor está preparando tu respuesta»; lo vio Pablo, 22 nov).
	if (_ask_window_up and is_instance_valid(confirm_node)) or (mode == "game" and not lesson_open):
		_build_ask_window()


## Una frase cabe en el aviso breve (una línea, sin saltos): si no, va en la ventana.
static func fits_toast(text: String) -> bool:
	return text.length() <= TOAST_MAX and not text.contains("\n")


# ---------------------------------------------------------------- la voz del tutor

## Lee en voz alta lo que dice el tutor (si la voz está puesta y no es Kids). Corta lo que estuviera diciendo.
func _speak_tutor(text: String) -> void:
	if tutor_speech == null or kids or not tutor_speech_on:
		return
	_speech_text = text
	tutor_speech.say(text, Loc.language)


func _stop_tutor_speech() -> void:
	if tutor_speech != null:
		tutor_speech.stop()


## «Escuchar» / «Parar» debajo de un texto del tutor (null con la voz quitada).
func _speech_button(text: String) -> Button:
	if kids or not tutor_speech_on or text.strip_edges() == "":
		return null
	var tint := _tint("sky")
	var on := tutor_speech.speaking and _speech_text == text
	var b := _button("sound", "Parar la voz" if on else "Escuchar", _toggle_speech.bind(text), tint[0], tint[1], {"font_size": F_SUB, "height": 88.0, "icon": 44.0, "radius": 44})
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.set_meta("speech", text)
	return b


func _toggle_speech(text: String) -> void:
	if tutor_speech.speaking and _speech_text == text:
		_stop_tutor_speech()
	else:
		_speak_tutor(text)


## Cambia el rótulo de los botones «Escuchar» que haya a la vista.
func _on_speech_changed(_on: bool) -> void:
	if confirm_node == null or not is_instance_valid(confirm_node):
		return
	var stack: Array = [confirm_node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Button and n.has_meta("speech"):
			var on := tutor_speech.speaking and _speech_text == str(n.get_meta("speech"))
			_set_button_text(n as Button, "Parar la voz" if on else "Escuchar")
		stack.append_array(n.get_children())


## El texto de un botón hecho con _button (va en una etiqueta dentro).
func _set_button_text(b: Button, text: String) -> void:
	var stack: Array = [b]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Label:
			(n as Label).text = Loc.t(text)
			return
		stack.append_array(n.get_children())


func _set_tutor_speech(on: bool) -> void:
	tutor_speech_on = on
	tutor_speech.enabled = on
	if not on:
		_stop_tutor_speech()
	_save_settings()
	_sync_sheet()


func _ask_closed() -> void:
	_ask_window_up = false
	tutor_voice.cancel()
	_stop_tutor_speech()
	if ask_state == "edit" or ask_state == "listen":
		ask_state = ""
	view.board.set_focus([])
	ask_edit = null


func _toggle_listen() -> void:
	if ask_state == "listen":
		tutor_voice.stop()
		return
	ask_state = "listen"
	_build_ask_window()
	tutor_voice.listen(Loc.language)


## Grabado: ahora lo transcribe Whisper en el servidor (un segundo o dos).
func _on_voice_transcribing() -> void:
	if ask_state != "listen":
		return
	var col := _ask_column()
	if col != null:
		for c in col.get_children():
			if c is Label and (c as Label).text == Loc.t("Te escucho… habla con calma."):
				(c as Label).text = Loc.t("Un momento, que lo escribo…")


func _on_voice_partial(t: String) -> void:
	if ask_state != "listen":
		return
	ask_text = t
	if ask_edit != null and is_instance_valid(ask_edit):
		ask_edit.text = t


func _on_voice_heard(t: String) -> void:
	if ask_state != "listen":
		return
	ask_text = t if t != "" else ask_text
	ask_state = "edit"
	# Dicho y hecho: si se ha entendido algo, se pregunta directamente.
	if ask_text.strip_edges().length() >= 2:
		_send_question()
	else:
		_build_ask_window()


func _on_voice_failed(code: int) -> void:
	if ask_state != "listen":
		return
	ask_state = "edit"
	_build_ask_window()
	var why := "No te he oído bien. Prueba otra vez, más cerca del micrófono." if TutorVoice.NO_MATCH.has(code) else "No se ha podido usar el micrófono."
	if code == TutorVoice.PERMISSION_DENIED:
		why = "Sin permiso para el micrófono: puedes escribir la pregunta o dar el permiso en los ajustes de Android."
	var col := _ask_column()
	if col != null:
		# En el APK de pruebas, con el código de Android (para saber qué pasa en cada móvil).
		var note := _para(Loc.t(why) + ((" (%d)" % code) if Premium.test_allowed() else ""), F_SUB, _c("bad"), font_medium)
		col.add_child(note)
		col.move_child(note, mini(3, col.get_child_count() - 1))


func _ask_column() -> VBoxContainer:
	if ask_edit != null and is_instance_valid(ask_edit):
		return ask_edit.get_parent() as VBoxContainer
	return null


## La línea de la respuesta, en el tablero (como la lección): el tablero vuelve a la partida al terminar.
func _open_answer_lesson() -> void:
	if _lesson_steps("answer").is_empty() or mode != "game" or game_state != "play":
		return
	_confirm_on_close = Callable()
	_close_confirm()
	view.board.set_focus([])
	lesson_open = true
	lesson_line = "answer"
	game_back = 0
	view.interactive = false
	_lesson_show(0)


## Texto de un paso: el del profesor si ha llegado; si no, lo que la app sabe decir de esa jugada.
func _tutor_text(step: Dictionary) -> String:
	if str(step.get("text", "")) != "":
		return str(step["text"])
	var pos := Chess.from_fen(str(step["fen"]))
	var m := pos.find_uci(str(step["uci"]))
	if m < 0:
		return ""
	var tag := MoveWhy.short_tag(pos, m)
	return SanEs.san(pos, m) + ((": " + tag) if tag != "" else "") + "."


## La tarjeta durante la lección: qué línea, qué jugada (y de quién) y lo que dice el profesor.
func _build_lesson_card() -> void:
	var steps := _lesson_steps()
	if steps.is_empty():
		return
	var step: Dictionary = steps[clampi(lesson_step, 0, steps.size() - 1)]
	var pos := Chess.from_fen(str(step["fen"]))
	var m := pos.find_uci(str(step["uci"]))
	var mine := pos.turn == game_color
	var bad := lesson_line != "answer" and [GameDetail.INACCURACY, GameDetail.MISTAKE, GameDetail.BLUNDER].has(str(coach_lesson.get("verdict", "")))
	var head := "Lo que jugaste" if lesson_line == "played" else "Lo que era mejor"
	if lesson_line == "played" and not bad:
		head = "Tu jugada"
	if lesson_line == "answer":
		head = "Te lo enseño en el tablero"
	title = _para(head, F_TITLE2, _c("good") if lesson_line == "best" or not bad else _c("bad"), font_display)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head_row := HBoxContainer.new()
	head_row.add_theme_constant_override("separation", 14)
	head_row.add_child(title)
	if _tutor_can_ask():
		# También se pregunta sobre el ejemplo que está en el tablero (el tutor sabe qué paso se ve).
		var tint := _tint("lilac")
		var ask_b := _round_button("ask", _open_ask, 80.0, tint[1], Color.WHITE, false)
		ask_b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head_row.add_child(ask_b)
	card_body.add_child(head_row)
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 12)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var san := SanEs.san(pos, m) if m >= 0 else str(step["uci"])
	var num := "%d%s %s" % [pos.full, "." if pos.turn == 0 else "…", san]
	var tint := _tint("mint" if mine and (lesson_line == "best" or not bad) else ("rose" if lesson_line == "played" and bad else "sky"))
	chips.add_child(_chip(num, tint[0], tint[1]))
	chips.add_child(_chip("Tú" if mine else "Rival", _c("field"), _c("quiet")))
	chips.add_child(_chip(Loc.f("Jugada %d de %d", [lesson_step + 1, steps.size()]), _c("field"), _c("quiet")))
	card_body.add_child(chips)
	card_body.add_child(_para(_tutor_text(step), F_BODY, _c("ink"), font_medium))
	if lesson_line == "answer":
		card_body.add_child(_para(str(ask_answer.get("answer", "")), F_SUB, _c("accent_text"), font_semibold))
	elif bool(coach_lesson.get("asked", false)) and not bool(coach_lesson.get("ready", false)):
		card_body.add_child(_para("El profesor está preparando la explicación…", F_SUB, _c("accent_text"), font_medium))
	elif not _lesson_has_next() and str(coach_lesson.get("advice", "")) != "":
		card_body.add_child(_para(str(coach_lesson["advice"]), F_SUB, _c("accent_text"), font_semibold))


func _build_lesson_actions() -> void:
	var key := "lesson:%s:%d:%s" % [lesson_line, lesson_step, str(_lesson_has_next())]
	if key == _actions_mode:
		return
	_actions_mode = key
	for old in actions.get_children():
		(old as CanvasItem).visible = false
		old.queue_free()
	hint_button = null
	step_button = null
	var go := {"font_size": F_BODY, "height": BAR_HEIGHT, "icon": 56.0, "radius": 60, "glow": _c("glow"), "trailing": true}
	var close := _tool_button("close", "Cerrar", _close_lesson, "lilac")
	var prev := _tool_button("back", "Anterior", _lesson_prev, "peach")
	prev.disabled = lesson_step == 0 and lesson_line != "best"
	prev.modulate.a = 0.42 if prev.disabled else 1.0
	var label := "Siguiente"
	if lesson_step >= _lesson_steps().size() - 1:
		label = "Ver la mejor" if lesson_line == "played" and not _lesson_steps("best").is_empty() else "Terminar"
	# «Ver la mejor», en verde: pasa a la jugada buena (Pablo, 22 nov). Lo demás, con el color de siempre.
	var to_best := label == "Ver la mejor"
	var next_bg := _c("good") if to_best else _c("accent")
	var next_ink := (Color("10241a") if dark else Color.WHITE) if to_best else _c("accent_ink")
	if to_best:
		go["glow"] = Color(next_bg.r, next_bg.g, next_bg.b, 0.35)
	var next := _button("next" if _lesson_has_next() else "check", label, _lesson_next, next_bg, next_ink, go)
	left_button = close
	right_button = next
	for b: Button in [close, prev, next]:
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(b)
	next.size_flags_stretch_ratio = 2.2


## Si la leyenda de las chapas se ve ahora: partida con profesor, en juego, y con sitio encima del tablero.
func _coach_legend_shown() -> bool:
	if mode != "game" or kids or welcome != null or progress != null or not film.is_empty():
		return false
	if game_state != "play" and game_state != "think":
		return false
	if not Premium.coach_applies(kids, bool(game.get("online", false)), game_clocked, str(game.get("variant", "")), game_serial):
		return false
	if board_slot == null or not is_instance_valid(board_slot) or not board_slot.is_inside_tree():
		return false
	if gesture_tip != null and is_instance_valid(gesture_tip) and gesture_tip.visible:
		return false
	return _coach_legend_top() - _coach_legend_floor() >= COACH_LEGEND_H + 28.0


## Borde de arriba de lo que hay sobre el tablero (las piezas comidas, si se ven) y borde de abajo de la barra.
func _coach_legend_top() -> float:
	if cap_top != null and is_instance_valid(cap_top) and cap_top.visible:
		return cap_top.get_global_rect().position.y
	return board_slot.get_global_rect().position.y


func _coach_legend_floor() -> float:
	return bar_row.get_global_rect().end.y if bar_row != null and is_instance_valid(bar_row) else 0.0


func _sync_coach_legend() -> void:
	var on := _coach_legend_shown()
	if on != _coach_legend_was:
		# La tarjeta lleva la valoración solo cuando no hay leyenda: si la leyenda aparece o desaparece (cambio de
		# tema, giro de pantalla), la tarjeta se rehace.
		_coach_legend_was = on
		if mode == "game" and coach_verdict != "":
			_refresh.call_deferred(false)
	if not on:
		if coach_legend != null and is_instance_valid(coach_legend):
			coach_legend.visible = false
		return
	if coach_legend == null or not is_instance_valid(coach_legend):
		coach_legend = HBoxContainer.new()
		coach_legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
		coach_legend.add_theme_constant_override("separation", 0)
		add_child(coach_legend)
		if gesture_tip != null and is_instance_valid(gesture_tip):
			# Al nivel de la pista de gestos: por debajo de las páginas y ventanas.
			move_child(coach_legend, gesture_tip.get_index())
		_coach_legend_key = ""
	var key := "%s|%s|%s" % [coach_verdict, str(dark), Loc.language]
	if key != _coach_legend_key:
		_coach_legend_key = key
		for c in coach_legend.get_children():
			coach_legend.remove_child(c)
			c.queue_free()
		var in_legend := COACH_LEGEND.has(coach_verdict) or coach_verdict in ["brilliant", "miss", GameDetail.EXCELLENT]
		for v: String in COACH_LEGEND:
			# «Brillante» (solo la da Stockfish) ocupa el sitio de «La mejor» cuando toca; «Excelente», el de «Buena»;
			# «Oportunidad perdida», el de «Error».
			var shown := v
			if v == GameDetail.BEST and coach_verdict == "brilliant":
				shown = "brilliant"
			elif v == GameDetail.GOOD and coach_verdict == GameDetail.EXCELLENT:
				shown = GameDetail.EXCELLENT
			elif v == GameDetail.MISTAKE and coach_verdict == "miss":
				shown = "miss"
			coach_legend.add_child(_coach_legend_item(shown, coach_verdict == shown, in_legend))
	var w := size.x - 24.0
	coach_legend.size = Vector2(w, COACH_LEGEND_H)
	coach_legend.position = Vector2(12.0, _coach_legend_top() - COACH_LEGEND_H - 14.0)
	coach_legend.visible = true


## Una valoración de la leyenda: la chapa (como en el tablero) y, debajo, su nombre. `current`: es la de tu última
## jugada (va resaltada); `dim`: hay otra resaltada, esta se apaga.
func _coach_legend_item(verdict: String, current: bool, dim: bool) -> Control:
	var def: Array = BADGES[_coach_badge_for(verdict)]
	var glyph := str(def[0])
	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	var paper := _c("surface")
	sb.bg_color = Color(paper.r, paper.g, paper.b, 0.92 if current else 0.0)
	sb.set_corner_radius_all(30)
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 6.0
	if current:
		sb.shadow_color = _c("shadow")
		sb.shadow_size = 10
	pill.add_theme_stylebox_override("panel", sb)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 4)
	pill.add_child(column)
	var disc := PanelContainer.new()
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.custom_minimum_size = Vector2(54.0, 54.0)
	disc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var ds := StyleBoxFlat.new()
	ds.bg_color = def[1]
	ds.set_corner_radius_all(27)
	disc.add_theme_stylebox_override("panel", ds)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.add_child(center)
	if glyph.begins_with("@"):
		center.add_child(_icon(glyph.substr(1), 34.0, Color.WHITE))
	else:
		var g := Label.new()
		g.text = glyph
		g.add_theme_font_size_override("font_size", 30)
		g.add_theme_color_override("font_color", Color.WHITE)
		g.add_theme_font_override("font", font_display)
		center.add_child(g)
	column.add_child(disc)
	# En la leyenda no cabe «Oportunidad perdida»: «Oportunidad».
	var name_label := _text(Loc.t("Oportunidad") if verdict == "miss" else _coach_label(verdict), F_CAP, _c("ink") if current else _c("quiet"), font_semibold if current else font_medium)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(name_label)
	if dim and not current:
		pill.modulate = Color(1.0, 1.0, 1.0, 0.45)
	return pill


## Pone (o repone) la chapa de la última jugada valorada, si en esa casilla sigue habiendo una pieza del jugador
## y se está viendo la partida en directo.
func _coach_place_badge() -> void:
	if _coach_badge_sq < 0 or mode != "game" or game_back > 0:
		return
	if Chess.color_of(view.board.chess.b[_coach_badge_sq]) != game_color:
		_coach_badge_sq = -1
		return
	_move_badge(_coach_badge_uci, _coach_badge_kind)


func _reap_coach_threads() -> void:
	for t: Thread in _coach_threads.duplicate():
		if not t.is_alive():
			t.wait_to_finish()
			_coach_threads.erase(t)


func _on_coach_answered(run: int, _ply: int, text: String, from_ai: bool) -> void:
	if run != run_id or mode != "game" or game_state == "over":
		return
	coach_waiting = false
	# Sin IA (sin red o respuesta descartada), `text` es el texto comprobado: en la tarjeta va su versión corta.
	coach_note = text if from_ai else _coach_short
	coach_full = text if from_ai else _coach_verified
	coach_from_ai = from_ai
	_refresh()


func _coach_block() -> PanelContainer:
	var tint := _tint("lilac")
	var paper: Color = tint[0]
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(paper.r, paper.g, paper.b, 0.6)
	sb.set_corner_radius_all(36)
	sb.content_margin_left = 26.0
	sb.content_margin_right = 22.0
	sb.content_margin_top = 18.0
	sb.content_margin_bottom = 20.0
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(head)
	var bulb := _icon("bulb", 52.0, tint[1])
	bulb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(bulb)
	# Corto, para que quepan los botones: «Tutor IA», o la partida gratis en curso («Gratis 2/5»).
	var title := _text(Loc.f("Gratis %d/%d", [coach_trial_game, Premium.TRIAL_GAMES]) if coach_trial_game > 0 else Loc.t("Tutor IA"), F_SUB, _c("ink"), font_semibold)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(title)
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if _tutor_can_ask():
		# Preguntar al tutor, en cualquier momento: botón redondo de color, con el bocadillo (o el micrófono).
		var ask_b := _round_button("ask", _open_ask, 80.0, tint[1], Color.WHITE, false)
		ask_b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(ask_b)
	if coach_waiting:
		column.add_child(_para("El profesor está mirando tu jugada…", F_BODY, _c("quiet"), font_medium))
		return panel
	if coach_hint != "":
		var hint := _para(coach_hint, F_BODY, _c("ink"), font_semibold)
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(hint)
		return panel
	if coach_note == "" and coach_lesson.is_empty():
		column.add_child(_para("Toca el bocadillo y pregúntame lo que quieras: por qué una jugada es buena o mala, qué planea el rival…", F_BODY, _c("quiet"), font_medium))
		return panel
	# Un botón con color, bien visible; además, se puede tocar cualquier punto del bloque. Con Stockfish hay
	# lección sobre el tablero («Explícamelo», en cualquier jugada, también en las buenas); sin él, el texto entero.
	var has_lesson := not coach_lesson.is_empty()
	var open_it: Callable = _open_lesson if has_lesson else _open_coach_full
	var more := _button("play" if has_lesson else "eye", "Explícamelo" if has_lesson else "Ver completa", open_it, _c("accent"), _c("accent_ink"), {"font_size": F_FOOT, "height": 72.0, "icon": 40.0, "radius": 36})
	if has_lesson and game_state != "play":
		# La lección se abre en tu turno: mientras piensa el rival, el botón espera.
		more.disabled = true
		more.modulate.a = 0.5
	more.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(more)
	# En la tarjeta, dos líneas como mucho; lo demás, en la ventana.
	var body := _para(coach_note, F_BODY, _c("quiet"), font_medium)
	body.max_lines_visible = 2
	body.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if coach_retry_line != "":
		var cheer := _para(coach_retry_line, F_BODY, _c("ink"), font_semibold)
		cheer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(cheer)
	column.add_child(body)
	if _retry_ready():
		# Aprender de la jugada mala: se deshace (con la respuesta del rival) y se vuelve a intentar, con pista.
		var again := _button("retry", "Prueba otra vez", _coach_retry, _c("field"), _c("ink"), {"font_size": F_FOOT, "height": 72.0, "icon": 40.0, "radius": 36})
		again.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		column.add_child(again)
	var tap := Button.new()
	tap.flat = true
	tap.focus_mode = Control.FOCUS_NONE
	for st: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		tap.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	tap.pressed.connect(open_it)
	tap.disabled = more.disabled
	panel.add_child(tap)
	# Debajo del texto: el bloque entero se toca para verlo; el botón de preguntar va encima y es suyo.
	panel.move_child(tap, 0)
	return panel


## La explicación entera del profesor, en una ventana encima de la partida.
func _open_coach_full() -> void:
	var text := coach_full if coach_full != "" else coach_note
	if text == "":
		return
	var glyph := str((BADGES.get(_coach_badge_for(coach_verdict), ["", Color.WHITE]) as Array)[0])
	var mark := "" if glyph == "" or glyph.begins_with("@") else glyph + " "
	var head := mark + (_coach_label(coach_verdict) if coach_verdict != "" else Loc.t("Profesor"))
	var column := _glass_popup(head, true)
	_confirm_on_close = _stop_tutor_speech
	_speak_tutor(text)
	column.add_child(_para("Profesor IA" if coach_from_ai else "Profesor", F_SUB, _c("accent_text"), font_semibold))
	column.add_child(_para(text, F_BODY, _c("ink"), font_medium))
	var listen := _speech_button(text)
	if listen != null:
		column.add_child(listen)
	column.add_child(_spacer(6.0))
	column.add_child(_button("check", "Entendido", _close_confirm, _c("field"), _c("ink"), {"font_size": F_BODY, "height": 116.0, "icon": 56.0, "radius": 58}))
	var hint := _para("Arrastra la ventana para moverla", F_CAP, _c("quiet"), font_medium)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)


## Ventana semitransparente y arrastrable (la del profesor y la de las preguntas), con su asa arriba.
func _glass_popup(head: String, reading: bool = false) -> VBoxContainer:
	# Más transparente que las demás ventanas (petición de Pablo): se ve bien el tablero debajo. Con texto largo
	# (`reading`), casi opaca.
	var column := _popup(head, "")
	var window := column.get_parent().get_parent() as PanelContainer
	if window != null:
		var glass := window.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		glass.bg_color.a = READING_WINDOW_ALPHA if reading else COACH_WINDOW_ALPHA
		glass.shadow_size = 18
		window.add_theme_stylebox_override("panel", glass)
		# Arrastrable: un asa arriba lo indica; al soltarla, se queda donde esté (también la próxima vez).
		_coach_window_drag = false
		window.gui_input.connect(_coach_window_input.bind(window))
		window.minimum_size_changed.connect(_coach_window_restore.bind(window))
		_coach_window_restore.call_deferred(window)
	var grip := Panel.new()
	grip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grip.custom_minimum_size = Vector2(120.0, 10.0)
	grip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var gs := StyleBoxFlat.new()
	gs.bg_color = _c("quiet")
	gs.bg_color.a = 0.55
	gs.set_corner_radius_all(5)
	grip.add_theme_stylebox_override("panel", gs)
	column.add_child(grip)
	column.move_child(grip, 0)
	return column


## Arrastrar la ventana de la explicación con el dedo (o el ratón).
func _coach_window_input(e: InputEvent, window: PanelContainer) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_coach_window_drag = (e as InputEventMouseButton).pressed
	elif e is InputEventMouseMotion and _coach_window_drag and is_instance_valid(window):
		_coach_window_pos = _coach_window_clamp(window.position + (e as InputEventMouseMotion).relative, window.size)
		window.position = _coach_window_pos


## Dentro de la pantalla: como mucho, la mitad de la ventana puede salirse por los lados o por abajo.
func _coach_window_clamp(pos: Vector2, window_size: Vector2) -> Vector2:
	return Vector2(clampf(pos.x, -window_size.x * 0.5, size.x - window_size.x * 0.5), clampf(pos.y, 20.0, size.y - window_size.y * 0.5))


## Si la ventana ya se movió antes, se abre donde se dejó.
func _coach_window_restore(window: PanelContainer) -> void:
	if _coach_window_pos == Vector2.INF or not is_instance_valid(window):
		return
	window.position = _coach_window_clamp(_coach_window_pos, window.size)


## Botón flotante del asistente: abajo a la derecha, encima de la barra de botones, en todas las pantallas.
## Va en una capa propia, por encima de todas las páginas: en el móvil de Pablo la página de inicio se dibujaba encima
## y lo tapaba (22 nov). Se comprueba cuatro veces por segundo si debe verse (páginas y ventanas cambian sin _refresh).
var _assistant_layer: CanvasLayer


func _sync_assistant_button() -> void:
	if assistant_button == null or not is_instance_valid(assistant_button):
		var tint := _tint("lilac")
		_assistant_layer = CanvasLayer.new()
		_assistant_layer.layer = 5
		add_child(_assistant_layer)
		# Destellos, no micrófono: el del tutor ya lleva su bocadillo y no deben confundirse (Pablo, 22 nov). Al tocarlo
		# escucha directamente.
		assistant_button = _round_button("spark", _on_assistant_fab, 116.0, tint[1], Color.WHITE)
		assistant_button.tooltip_text = Loc.t("Asistente")
		# Se puede arrastrar a donde se quiera (Pablo, 22 nov); el sitio se guarda.
		assistant_button.gui_input.connect(_on_assistant_fab_input)
		_assistant_layer.add_child(assistant_button)
		var tick := Timer.new()
		tick.wait_time = 0.25
		tick.autostart = true
		tick.timeout.connect(_sync_assistant_button)
		add_child(tick)
	# Fuera mientras hay una ventana abierta (también la suya), en Kids y en la bienvenida.
	assistant_button.visible = _assistant_available() and welcome == null and (confirm_node == null or not is_instance_valid(confirm_node))
	if not assistant_button.visible:
		return
	if _fab_drag_from.x >= 0.0:
		return
	assistant_button.position = _assistant_fab_position()


## Sitio del botón del asistente: el que eligió el jugador (fracción de la pantalla) o, si no, abajo a la derecha,
## encima de la barra. Siempre dentro de la pantalla (con las barras del sistema).
func _assistant_fab_position() -> Vector2:
	var vp := get_viewport_rect().size
	var ins := _insets()
	var side := 116.0
	var p := Vector2(vp.x - side - 28.0, vp.y - ins.y - BAR_HEIGHT - side - 64.0)
	if assistant_spot.x >= 0.0:
		p = Vector2(assistant_spot.x * vp.x, assistant_spot.y * vp.y)
	return Vector2(clampf(p.x, 12.0, vp.x - side - 12.0), clampf(p.y, ins.x + 12.0, vp.y - ins.y - side - 12.0))


## Arrastrar el botón: pasado un umbral es un arrastre y no abre el asistente.
var assistant_spot := Vector2(-1.0, -1.0)
var _fab_drag_from := Vector2(-1.0, -1.0)
var _fab_grab := Vector2.ZERO
var _fab_dragged := false


func _on_assistant_fab_input(event: InputEvent) -> void:
	var pos := Vector2.ZERO
	var pressed := false
	var released := false
	var moved := false
	if event is InputEventScreenTouch:
		pos = (event as InputEventScreenTouch).position
		pressed = (event as InputEventScreenTouch).pressed
		released = not pressed
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		pos = (event as InputEventMouseButton).position
		pressed = (event as InputEventMouseButton).pressed
		released = not pressed
	elif event is InputEventScreenDrag:
		pos = (event as InputEventScreenDrag).position
		moved = true
	elif event is InputEventMouseMotion and ((event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		pos = (event as InputEventMouseMotion).position
		moved = true
	else:
		return
	# `pos` es local al botón: se pasa a la pantalla.
	var screen := assistant_button.position + pos
	if pressed:
		_fab_drag_from = screen
		_fab_grab = pos
		_fab_dragged = false
	elif moved and _fab_drag_from.x >= 0.0:
		if not _fab_dragged and screen.distance_to(_fab_drag_from) > 24.0:
			_fab_dragged = true
		if _fab_dragged:
			assistant_button.position = screen - _fab_grab
			var vp := get_viewport_rect().size
			assistant_spot = Vector2(assistant_button.position.x / vp.x, assistant_button.position.y / vp.y)
			assistant_button.position = _assistant_fab_position()
	elif released:
		_fab_drag_from = Vector2(-1.0, -1.0)
		if _fab_dragged:
			_save_settings()


func _on_assistant_fab() -> void:
	if _fab_dragged:
		_fab_dragged = false
		return
	_open_assistant(true)


## El interruptor «Tutor IA» de la barra: una pastilla con el nombre y el interruptor; se toca entera.
func _tutor_toggle_button() -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.custom_minimum_size = Vector2(0.0, 100.0)
	var tint := _tint("lilac")
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = tint[0]
		sb.set_corner_radius_all(50)
		b.add_theme_stylebox_override(state, sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pad := _pad(24, 0, 16, 0)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	pad.add_child(row)
	b.add_child(pad)
	var bulb := _icon("bulb", 44.0, tint[1])
	bulb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bulb)
	var label := _text("Tutor IA", F_SUB, _c("ink"), font_semibold)
	label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	_tutor_switch = Switch.new()
	_tutor_switch.on_color = _c("accent")
	_tutor_switch.off_color = _c("track")
	_tutor_switch.knob_color = Color.WHITE
	_tutor_switch.custom_minimum_size = Vector2(96.0, 58.0)
	_tutor_switch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_tutor_switch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		_tutor_switch.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	row.add_child(_tutor_switch)
	b.pressed.connect(_on_tutor_toggle)
	b.visible = false
	# El ancho, el de su contenido.
	pad.minimum_size_changed.connect(func() -> void: b.custom_minimum_size.x = pad.get_combined_minimum_size().x)
	return b


## En todas las partidas contra la app (en Kids no: allí no hay profesor).
func _tutor_toggle_shown() -> bool:
	return mode == "game" and not kids and not game.is_empty()


## Por qué el tutor no puede ir en esta partida ("" si puede).
func _tutor_blocked_reason() -> String:
	if bool(game.get("online", false)):
		return "En las partidas online el tutor no ayuda: sería jugar con ventaja."
	if game_clocked:
		return "Con reloj no hay tutor, como en una partida oficial. Juega una partida sin reloj para tenerlo."
	if str(game.get("variant", "")) != "":
		return "El tutor solo va en las partidas de ajedrez normal, no en las variantes."
	return ""


func _sync_tutor_toggle() -> void:
	if tutor_toggle == null or not is_instance_valid(tutor_toggle):
		return
	tutor_toggle.visible = _tutor_toggle_shown()
	if not tutor_toggle.visible:
		return
	var blocked := _tutor_blocked_reason() != ""
	_tutor_switch.on = Premium.coach_on and not blocked
	_tutor_switch.queue_redraw()
	tutor_toggle.modulate.a = 0.55 if blocked else 1.0


func _on_tutor_toggle() -> void:
	var why := _tutor_blocked_reason()
	if why != "":
		var column := _popup("Tutor IA", why)
		column.add_child(_button("check", "Entendido", _close_confirm, _c("field"), _c("ink"), {"font_size": F_BODY, "height": 116.0, "icon": 56.0, "radius": 58}))
		return
	_set_coach_on(not Premium.coach_on)
	if Premium.coach_on and mode == "game" and game_state == "play" and coach_note == "":
		coach_note = Loc.t("Tutor encendido: te comento tu próxima jugada. También puedes preguntarme lo que quieras.")
		coach_full = coach_note
	_refresh()


## El servidor manda el estado de la cuenta (Premium y cupo).
func _on_quota(st: Dictionary) -> void:
	Premium.set_status(st)
	_sync_sheet()


func _on_pagos_changed() -> void:
	_sync_sheet()
	if _premium_offer_node != null and is_instance_valid(_premium_offer_node) and confirm_node == _premium_offer_node:
		_open_premium_offer(_premium_offer_reason)


func _on_pagos_note(text: String) -> void:
	var column := _popup("A Chess Way Premium", text)
	column.add_child(_button("check", "Entendido", _close_confirm, _c("field"), _c("ink"), {"font_size": F_BODY, "height": 116.0, "icon": 56.0, "radius": 58}))


## Ventana de Premium: qué trae, precio (el de Google Play) y comprar, recargar o restaurar. `reason`: «premium»
## (no tiene explicaciones), «cupo» (ha gastado las del mes), «experto» (el rival Stockfish) u «opciones».
var _premium_offer_node: Control
var _premium_offer_reason := ""


func _open_premium_offer(reason: String = "opciones") -> void:
	_premium_offer_reason = reason
	var head: String = {
		"premium": "Las explicaciones y las preguntas al tutor son de Premium.",
		"cupo": "Has usado las explicaciones de este mes.",
		"experto": "El rival «Experto» (Stockfish) es de Premium.",
		"campeonato": "Desde la tercera ronda, el Campeonato (y el torneo del gran hotel, con Stockfish) es de Premium.",
	}.get(reason, "")
	var column := _popup("A Chess Way Premium", head)
	var opts := {"font_size": F_BODY, "height": 116.0, "icon": 56.0, "radius": 58}
	# APK de pruebas: el interruptor aquí mismo, para probarlo todo sin comprar (Pablo, 23 nov).
	if Premium.test_allowed():
		column.add_child(_switch_row("party", "butter", "Premium de prueba", "Solo en el APK de pruebas: activa la versión premium sin comprarla.", Premium.test_on, func(on: bool) -> void:
			_set_premium_test(on)
			_open_premium_offer(reason)))
	var st := Premium.server
	if Premium.active():
		column.add_child(_para(Loc.f("Premium activo: te quedan %d explicaciones este mes.", int(st.get("quedan", 0))) + (" " + Loc.f("Y %d de recargas.", int(st.get("extra", 0))) if int(st.get("extra", 0)) > 0 else ""), F_BODY, _c("ink"), font_semibold))
	else:
		for line: String in ["%d explicaciones o preguntas al tutor cada mes", "Rival «Experto»: Stockfish, de muy fuerte a imbatible", "Las chapas de cada jugada y el asistente, gratis para todos"]:
			column.add_child(_para("• " + (Loc.f(line, _premium_monthly()) if line.contains("%d") else Loc.t(line)), F_BODY, _c("ink"), font_regular))
		var price := str(pagos.prices.get(Pagos.SUB, ""))
		var label := Loc.f("Hazte Premium · %s/mes", price) if price != "" else Loc.t("Hazte Premium")
		column.add_child(_button("party", label, _buy.bind(Pagos.SUB), _c("accent"), _c("accent_ink"), opts))
		column.add_child(_para(Loc.t("Se renueva cada mes. Puedes cancelarla cuando quieras en Google Play."), F_FOOT, _c("quiet"), font_regular))
	if Premium.active() or reason == "cupo" or int(st.get("extra", 0)) > 0:
		var pack := str(pagos.prices.get(Pagos.PACK, ""))
		var tint := _tint("sky")
		column.add_child(_button("bulb", Loc.f("100 explicaciones más · %s", pack) if pack != "" else Loc.t("100 explicaciones más"), _buy.bind(Pagos.PACK), tint[0], tint[1], opts))
	column.add_child(_button("retry", "Restaurar compras", _restore_purchases, _c("field"), _c("ink"), opts))
	if not pagos.available():
		column.add_child(_para(Loc.t("Las compras solo funcionan en la app instalada desde Google Play."), F_FOOT, _c("quiet"), font_regular))
	_premium_offer_node = confirm_node


func _premium_monthly() -> int:
	return int(Premium.server.get("mes", 300))


func _buy(id: String) -> void:
	_close_confirm()
	pagos.buy(id)


func _restore_purchases() -> void:
	_close_confirm()
	pagos.restore()
	if CoachAI.tutor_url(coach.cfg) != "":
		coach.premium_call("/premium/estado", {})


## Opciones → Premium. Las pruebas (activar premium sin comprar y pegar una clave de la API) solo salen en las
## compilaciones de depuración.
func _premium_rows(box: VBoxContainer) -> void:
	# En la versión de publicación, mientras no haya compra real, la sección no sale: anunciaría algo que no se
	# puede comprar.
	box.add_child(_caption("Premium"))
	if Premium.test_allowed():
		box.add_child(_switch_row("party", "butter", "Premium de prueba", "Solo en el APK de pruebas: activa la versión premium sin comprarla.", Premium.test_on, _set_premium_test))
		# La cuenta, para darla de alta como probador en el servidor (explicaciones sin cupo).
		box.add_child(_para(Loc.f("Tu cuenta (para pruebas): %s", Premium.account_id()), F_FOOT, _c("quiet"), font_regular))
		var tc := _tint("sky")
		box.add_child(_button("check", "Copiar el texto", func() -> void:
			DisplayServer.clipboard_set(Premium.account_id())
			_prog_toast(Premium.account_id(), "", false), tc[0], tc[1], {"font_size": F_SUB, "height": 96.0, "icon": 44.0}))
	var st := Premium.server
	var state := Loc.f("Premium activo: te quedan %d explicaciones este mes.", int(st.get("quedan", 0))) if Premium.active() \
		else Loc.f("Te quedan %d de %d partidas gratis con explicaciones.", [Premium.trial_left(), Premium.TRIAL_GAMES])
	if int(st.get("extra", 0)) > 0:
		state += " " + Loc.f("Y %d de recargas.", int(st.get("extra", 0)))
	box.add_child(_para(state, F_SUB, _c("ink"), font_semibold))
	var tint := _tint("butter")
	box.add_child(_button("party", "Ver Premium" if not Premium.active() else "Premium y recargas", _open_premium_offer.bind("opciones"), tint[0], tint[1], {"font_size": F_SUB, "height": 104.0, "icon": 50.0}))
	var sub := "Te marca cada jugada y te explica tus errores mientras juegas contra el rival (partidas sin reloj)."
	box.add_child(_switch_row("bulb", "lilac", "Profesor IA en las partidas", sub, Premium.coach_on, _set_coach_on))
	box.add_child(_switch_row("sound", "sky", "Voz del tutor", "Lee en voz alta sus respuestas, sus explicaciones y la lección en el tablero.", tutor_speech_on, _set_tutor_speech))
	if Premium.test_allowed() and CoachAI.endpoint_mode(coach.cfg, "", true) != "server":
		box.add_child(_coach_key_block())


func _coach_key_block() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_coach_key_edit = LineEdit.new()
	_show_caret(_coach_key_edit)
	_coach_key_edit.placeholder_text = "Clave de la API de Claude (sk-ant-…)"
	_coach_key_edit.secret = true
	_coach_key_edit.text = Premium.test_key
	_coach_key_edit.add_theme_font_size_override("font_size", F_SUB)
	_coach_key_edit.add_theme_font_override("font", font_medium)
	_coach_key_edit.custom_minimum_size = Vector2(0.0, 104.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = _c("surface")
	sb.set_corner_radius_all(36)
	sb.border_color = _c("track")
	sb.set_border_width_all(3)
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	_coach_key_edit.add_theme_stylebox_override("normal", sb)
	_coach_key_edit.add_theme_stylebox_override("focus", sb)
	_coach_key_edit.add_theme_color_override("font_color", _c("ink"))
	_coach_key_edit.text_submitted.connect(func(_t: String) -> void: _save_coach_key())
	box.add_child(_coach_key_edit)
	var state := "Clave guardada en este móvil." if Premium.test_key != "" else "Sin clave, el profesor usa los textos comprobados de la app, sin IA."
	box.add_child(_para(state + " " + Loc.t("Solo para pruebas: no se sube a ningún sitio salvo a la API de Claude."), F_FOOT, _c("quiet"), font_regular))
	var tint := _tint("sky")
	box.add_child(_button("check", "Guardar la clave", _save_coach_key, tint[0], tint[1], {"font_size": F_SUB, "height": 104.0, "icon": 50.0}))
	return box


func _set_premium_test(on: bool) -> void:
	Premium.test_on = on
	Premium.save_state()
	_sync_sheet()


func _set_coach_on(on: bool) -> void:
	Premium.coach_on = on
	Premium.save_state()
	if not on:
		_clear_coach()
		if mode == "game":
			_refresh()
	_sync_sheet()


func _save_coach_key() -> void:
	if _coach_key_edit == null or not is_instance_valid(_coach_key_edit):
		return
	Premium.test_key = _coach_key_edit.text.strip_edges()
	Premium.save_state()
	_sync_sheet()


func _stop_game_thread() -> void:
	if _game_thread != null:
		if _game_thread.is_started():
			_game_thread.wait_to_finish()
		_game_thread = null
	if _review_thread != null:
		if _review_thread.is_started():
			_review_thread.wait_to_finish()
		_review_thread = null


## ¿Se ha acabado la partida tras la jugada m (hecha desde before)? Si es así, la cierra y devuelve true.
## Con m == −1: el que mueve no tiene jugadas.
func _game_check_end(before: Chess, m: int) -> bool:
	var pos := view.board.chess
	var variant := str(game.get("variant", ""))
	var winner := -2
	var why := ""
	if variant == "peones":
		if m >= 0:
			winner = Bot.peones_result(pos, m)
			if winner >= 0:
				why = "corona" if Chess.move_promo(m) != 0 else "piezas"
		if winner < 0 and pos.pseudo_moves().is_empty():
			winner = 1 - pos.turn
			why = "bloqueo"
		if winner < 0:
			return false
	else:
		if pos is WarChess:
			_war_sync_seen()
		if pos is WarChess and (pos as WarChess).repetition_locked() and not pos.in_check():
			# War Chess: solo le quedan jugadas que repetirían la posición por tercera vez: pierde (como en Arimaa).
			winner = 1 - pos.turn
			why = "repite"
		elif pos.legal_moves().is_empty():
			winner = 1 - pos.turn if pos.in_check() else -1
			why = "mate" if pos.in_check() else "ahogado"
		elif pos.half >= 100:
			winner = -1
			why = "50"
		elif _game_repeated(3):
			winner = -1
			why = "repeticion"
		elif _game_bare():
			winner = -1
			why = "material"
		else:
			return false
	game_state = "over"
	view.interactive = false
	if bool(game.get("online", false)):
		online.finish()
	game_won = 0 if winner < 0 else (1 if winner == game_color else -1)
	_wait_bot_farewell()
	var texts := {
		"mate": ["¡Jaque mate! Has ganado.", "Jaque mate: gana el rival."],
		"corona": ["¡Has coronado! Has ganado.", "El rival ha coronado: gana él."],
		"piezas": ["¡Has capturado todas sus piezas!", "El rival ha capturado todas tus piezas."],
		"bloqueo": ["El rival se ha quedado sin jugadas: ¡has ganado!", "Te has quedado sin jugadas: gana el rival."],
		"repite": ["Al rival solo le quedaban jugadas que repetían la posición por tercera vez: ¡has ganado!", "Solo te quedaban jugadas que repetían la posición por tercera vez: gana el rival."],
	}
	var draws := {"ahogado": "Ahogado: el rey no está en jaque y no puede mover. Tablas.", "50": "Cincuenta jugadas sin capturas ni movimientos de peón: tablas.", "repeticion": "La misma posición tres veces: tablas.", "material": "No queda material para dar mate: tablas."}
	if game_won != 0:
		_sfx("leccion" if game_won > 0 else "error")
	if game_won == 0:
		game_result = str(draws.get(why, "Tablas."))
		_say([_kid_line("gameDraw")])
	else:
		game_result = str((texts[why] as Array)[0 if game_won > 0 else 1])
		if variant == "peones":
			_say(([BRAVO] if game_won > 0 else []) + [_kid_line("pawnsWin" if game_won > 0 else "pawnsLose")])
		else:
			_say(([BRAVO] if game_won > 0 else []) + [_kid_line("gameWin" if game_won > 0 else "gameLose")])
	if game_won > 0 and str(game.get("unit", "")) != "":
		course_done["partida-" + str(game["unit"])] = 1
		_save_course_progress()
	_refresh()
	return true


func _game_repeated(times: int) -> bool:
	var counts := {}
	for f: Variant in game_history:
		# Colocación, turno, enroques y al paso; en War Chess, también los blindajes (séptimo campo).
		var parts := str(f).split(" ")
		var key := " ".join(parts.slice(0, 4)) + (" " + parts[6] if parts.size() > 6 else "")
		counts[key] = int(counts.get(key, 0)) + 1
		if int(counts[key]) >= times:
			return true
	return false


## Solo reyes, o rey y una pieza menor contra rey: nadie puede dar mate.
func _game_bare() -> bool:
	var minors := 0
	for p in view.board.chess.b:
		if p == 0:
			continue
		var t := Chess.type_of(p)
		if t == Chess.PAWN or t == Chess.ROOK or t == Chess.QUEEN:
			return false
		if t == Chess.KNIGHT or t == Chess.BISHOP:
			minors += 1
	return minors <= 1


## Deshacer: vuelve a la última vez que le tocaba al jugador (su jugada y la respuesta del rival).
func _game_undo() -> void:
	if game_state == "think" or game_history.size() < 2:
		return
	_coach_prev_win = -1
	run_id += 1
	var keep := game_history.size() - 1
	while keep > 0:
		var turn_char := str(game_history[keep - 1]).split(" ")[1]
		keep -= 1
		if (turn_char == "w") == (game_color == 0):
			break
	if keep < 0:
		return
	game_history = game_history.slice(0, keep + 1)
	game_moves = game_moves.slice(0, keep)
	view.set_fen(str(game_history[keep]))
	view.board.set_arrows([])
	game_state = "play"
	game_note = Loc.t("Jugada deshecha.") + _mark_helped()
	_clear_coach()
	view.interactive = view.board.chess.turn == game_color
	if not view.interactive:
		_game_bot_turn()
		return
	_refresh()


## La partida pasa a tener ayudas: no contará para el nivel de juego. La primera vez se avisa (texto para la nota).
func _mark_helped() -> String:
	if game_helped or kids:
		return ""
	game_helped = true
	return " " + Loc.t("Con ayudas, esta partida no cuenta para tu nivel.")


## Tras valorar una jugada: si es mala, se ofrece «Prueba otra vez»; si era un nuevo intento, el tutor lo celebra.
func _coach_retry_after(fen: String, verdict: String, best: String) -> void:
	var bad := [GameDetail.INACCURACY, GameDetail.MISTAKE, GameDetail.BLUNDER, "miss"].has(verdict)
	if not _retry_target.is_empty() and _same_position(str(_retry_target["fen"]), fen):
		if verdict == "best" or verdict == "brilliant":
			coach_retry_line = Loc.t("¡Ahora sí! Era la mejor jugada.")
		elif not bad:
			coach_retry_line = Loc.t("¡Mucho mejor! Buena jugada.")
		else:
			coach_retry_line = Loc.t("Todavía no: puedes volver a probar.")
	_retry_target = {}
	if bad and best != "" and fen != "":
		_retry = {"fen": fen, "best": best}
	# Se acabaron las partidas gratis con explicaciones: se dice una vez, con la primera chapa.
	_coach_trial_over()


## Misma posición (piezas, turno, enroques y al paso; sin los contadores de jugadas).
func _same_position(a: String, b: String) -> bool:
	return Array(a.split(" ")).slice(0, 4) == Array(b.split(" ")).slice(0, 4)


## Se puede repetir la jugada mala: partida en curso sin reloj (en las demás no hay deshacer) y ya en tu turno.
func _retry_ready() -> bool:
	return not _retry.is_empty() and mode == "game" and game_state == "play" and not game_clocked and not kids \
		and not bool(game.get("online", false)) and game_history.size() >= 2 and view.board.chess.turn == game_color


## «Prueba otra vez»: deshace tu jugada (y la respuesta del rival) y el tutor da una pista sin decir la jugada: la
## pieza que conviene mover parpadea en rosa.
func _coach_retry() -> void:
	if not _retry_ready():
		return
	var r := _retry.duplicate()
	_game_undo()
	if not _same_position(view.board.chess.fen(), str(r["fen"])):
		return
	_retry_target = r
	var pos := view.board.chess
	var bm := pos.find_uci(str(r["best"]))
	if bm >= 0:
		var from := Chess.move_from(bm)
		coach_hint = Loc.f("Busca algo mejor. Pista: fíjate en tu %s de %s.", [Loc.t(_piece_noun(pos.b[from])), Chess.sq_name(from)])
		view.board.set_focus([from])
	else:
		coach_hint = Loc.t("Busca algo mejor.")
	_refresh()


const HINT_MS := 600
var _hint_busy := false


## Pista: con Stockfish del móvil, su mejor jugada; si no, la mejor jugada que encuentra el rival «Medio» (sin sus errores a propósito), con una flecha.
func _game_hint() -> void:
	if game_state != "play" or _hint_busy:
		return
	var m := -1
	if str(game.get("variant", "")) == "" and local_engine.available():
		# Con Stockfish del móvil: la mejor de verdad (medio segundo).
		_hint_busy = true
		var my_run := run_id
		var fen := view.board.chess.fen()
		var a: Dictionary = await local_engine.analyze(fen, HINT_MS)
		_hint_busy = false
		if my_run != run_id or game_state != "play" or view.board.chess.fen() != fen:
			return
		m = view.board.chess.find_uci(str(a.get("move", "")))
	if m < 0:
		var helper := Bot.new(2, str(game.get("variant", "")))
		helper.exact = true
		m = helper.choose(view.board.chess.copy())
	if m < 0:
		return
	if WarChess.is_armor_move(m):
		# Blindarse no tiene flecha: se señala la pieza con la chapa del escudo.
		view.board.set_arrows([])
		view.board.set_badge(Chess.move_from(m), "", Color("e0453f"), UiIcons.texture("shield"))
		game_note = Loc.f("Pista: blinda tu %s de %s.", [Loc.t(_piece_noun(view.board.chess.b[Chess.move_from(m)])), Chess.sq_name(Chess.move_from(m))]) + _mark_helped()
		_refresh()
		return
	view.board.set_arrows([{"from": Chess.move_from(m), "to": Chess.move_to(m), "tone": "info"}])
	game_note = _kid_line("gameHint") if kids else Loc.f("Pista: %s.", SanEs.san(view.board.chess, m)) + _mark_helped()
	_say([_kid_line("gameHint")])
	_refresh()


## Tu pulsador del reloj.
func _on_clock_pressed() -> void:
	if game_state != "press":
		return
	Input.vibrate_handheld(25)
	_press_game_clock()


## Has tocado tu pulsador antes de mover.
func _on_clock_early() -> void:
	if game_state == "play" and game_note == "":
		game_note = "Primero haz tu jugada; después pulsa el reloj."
		_refresh()


## ¿Hay una partida en marcha (que se perdería al salir)?
func _game_live() -> bool:
	return mode == "game" and game_state in ["play", "think", "press"]


func _ask_resign() -> void:
	if not _game_live():
		_game_resign()
		return
	_confirm("¿Te rindes?", "La partida termina y la gana el rival.", "flag", "Rendirme", _game_resign)


func _ask_leave(then: Callable = _leave_game) -> void:
	if not _game_live():
		then.call()
		return
	var online_game := bool(game.get("online", false))
	var go := then
	if str(game.get("campeonato", "")) != "":
		_confirm("¿Abandonar la partida?", "La gana el rival y quedas fuera del torneo.", "close", "Abandonar", func() -> void:
			game_won = -1
			game_result = "Has abandonado la partida."
			game_state = "over"
			_record_game()
			_campeonato_record_once()
			CampeonatoUI.ambient_stop()
			then.call())
		return
	if online_game:
		go = func() -> void:
			# Se guarda como perdida por abandono (si ya se había jugado algo).
			game_won = -1
			game_result = "Has abandonado la partida."
			_record_game()
			then.call()
	_confirm("¿Salir de la partida?", "Abandonas la partida y la gana el rival." if online_game else "La partida se termina y no se guarda.", "close", "Salir", go)


## Ventana de confirmación semitransparente sobre el tablero: el aviso, «Cancelar» y la acción. Tocar fuera la
## cierra (como «Cancelar»).
func _confirm(head: String, text: String, ok_icon: String, ok_label: String, on_ok: Callable) -> void:
	var column := _popup(head, text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	column.add_child(row)
	var opts := {"font_size": F_BODY, "height": 116.0, "icon": 56.0, "radius": 58}
	var cancel := _button("back", "Cancelar", _close_confirm, _c("field"), _c("ink"), opts)
	var tint := _tint("rose")
	var ok := _button(ok_icon, ok_label, func() -> void:
		_close_confirm()
		on_ok.call(), tint[0], tint[1], opts)
	for b: Button in [cancel, ok]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)


## Ventana semitransparente sobre el tablero (se cierra tocando fuera): título, texto y una columna para lo demás.
func _popup(head: String, text: String, opaque: bool = false) -> VBoxContainer:
	_close_confirm()
	confirm_node = Control.new()
	confirm_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	confirm_node.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(confirm_node)
	var scrim := ColorRect.new()
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0.03, 0.05, 0.14, 0.32 if dark else 0.2)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			_close_confirm())
	confirm_node.add_child(scrim)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	var paper := _c("surface")
	# Casi opaca para lo que hay que leer con detalle (el reloj de la hora del aviso).
	sb.bg_color = Color(paper.r, paper.g, paper.b, 0.97 if opaque else 0.86)
	sb.set_corner_radius_all(60)
	sb.shadow_color = _c("shadow")
	sb.shadow_size = 30
	sb.shadow_offset = Vector2(0.0, 12.0)
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	confirm_node.add_child(panel)
	var pad := _pad(50, 44, 50, 40)
	panel.add_child(pad)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	pad.add_child(column)
	column.add_child(_para(head, F_TITLE, _c("ink"), font_display))
	if text != "":
		column.add_child(_para(text, F_BODY, _c("quiet"), font_regular))
	var place := func() -> void:
		if not is_instance_valid(panel) or board_slot == null or not is_instance_valid(board_slot):
			return
		var w := minf(size.x - 120.0, 860.0)
		panel.size = Vector2(w, 0.0)
		panel.reset_size()
		panel.size.x = w
		var h := panel.get_combined_minimum_size().y
		var rect := board_slot.get_global_rect()
		panel.position = Vector2((size.x - w) * 0.5, clampf(rect.get_center().y - h * 0.5, 40.0, size.y - h - 40.0))
		panel.pivot_offset = panel.size * 0.5
	panel.minimum_size_changed.connect(place)
	place.call_deferred()
	panel.scale = Vector2(0.9, 0.9)
	confirm_node.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(panel, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(confirm_node, "modulate:a", 1.0, 0.15)
	return column


## Lo que hay que hacer al cerrarse la ventana abierta (con su botón o tocando fuera), una vez.
var _confirm_on_close := Callable()


func _close_confirm() -> void:
	if confirm_node != null and is_instance_valid(confirm_node):
		confirm_node.queue_free()
	confirm_node = null
	if _confirm_on_close.is_valid():
		var then := _confirm_on_close
		_confirm_on_close = Callable()
		then.call()


func _game_resign() -> void:
	if game_state == "over":
		return
	if bool(game.get("online", false)):
		online.leave()
	_stop_game_thread()
	run_id += 1
	game_state = "over"
	game_won = -1
	game_result = "Te has rendido."
	_wait_bot_farewell()
	view.interactive = false
	_refresh()


func _game_again() -> void:
	if bool(game.get("online", false)):
		online.leave()
		online_status = ""
		_online_search()
		return
	_start_game(game, game_color)


func _leave_game() -> void:
	CampeonatoUI.ambient_stop()
	if bool(game.get("online", false)):
		online.leave()
	_stop_game_thread()
	run_id += 1
	view.interactive = false
	view.board.set_arrows([])
	var unit := str(game.get("unit", ""))
	game_state = ""
	view.set_orientation(0)
	if lesson.is_empty():
		mode = "free"
		_idle()
	else:
		mode = "learn"
		_show_lesson_step()
	if unit != "":
		_open_course()
	else:
		_open_home()


## Tras la partida de una unidad: la primera lección de la siguiente (o el mapa del curso).
func _game_next_lesson() -> void:
	var unit := str(game.get("unit", ""))
	_stop_game_thread()
	game_state = ""
	var found := false
	view.set_orientation(0)
	for u: Dictionary in course:
		if found:
			_start_lesson(str((u["lessons"] as Array)[0]["id"]))
			return
		found = str(u["id"]) == unit
	# Fin del curso: sin nivel todavía, el test (salvo en el nivel Kids).
	if not kids and not _has_player():
		game_state = ""
		_after_course()
	else:
		_leave_game()


func _build_game_card() -> void:
	if lesson_open:
		_build_lesson_card()
		return
	if game_state == "review":
		_build_review_card()
		return
	if game_state == "detail":
		_build_detail_card()
		return
	var head := ""
	var tone := _c("ink")
	match game_state:
		"play":
			head = "¡Te toca!" if kids else "Te toca"
		"press":
			head = "Pulsa el reloj"
		"think":
			head = "Piensa el rival…"
		"over":
			head = "¡Has ganado!" if game_won > 0 else ("Tablas" if game_won == 0 else ("Ha ganado el rival" if kids else "Has perdido"))
			tone = _c("good") if game_won > 0 else (_c("ink") if game_won == 0 else _c("bad"))
	title = _para(head, F_TITLE, tone, font_display)
	if game_clocked and game_state != "over":
		# Con reloj, el reloj ocupa la tarjeta (el nombre del rival va en el reloj) y, en las online, a su lado, la
		# insignia del rival, sus gestos y sus opciones. Nada más, para que no haya scroll y el reloj se vea grande.
		if game_back > 0:
			var t0 := _tint("peach")
			var back_chips := HFlowContainer.new()
			back_chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
			back_chips.add_child(_chip(Loc.f("Jugada %d de %d · toca el tablero para volver", [game_history.size() - 1 - game_back, game_history.size() - 1]), t0[0], t0[1], "back"))
			card_body.add_child(back_chips)
		_clock_labels = []
		chess_clock = ChessClock.new()
		chess_clock.digits_font = _digits_font if _digits_font != null else font_display
		chess_clock.label_font = font_semibold
		chess_clock.dark = dark
		chess_clock.accent = _c("accent")
		chess_clock.custom_minimum_size = Vector2(0.0, 360.0)
		chess_clock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chess_clock.pressed_mine.connect(_on_clock_pressed)
		chess_clock.pressed_early.connect(_on_clock_early)
		var is_online := bool(game.get("online", false))
		var who := str(online_rival.get("nombre", "")) if is_online else (str(game["rival_nombre"]).split(" ")[0] if game.has("rival_nombre") else Bot.level_name(int(game.get("level", 0))))
		chess_clock.labels = ["TÚ", who.to_upper().left(14) if who != "" else "RIVAL"]
		card_body.add_child(chess_clock)
		if is_online:
			# Debajo del reloj y grandes (Pablo, 16 nov): la insignia del rival, los gestos, «¡Tu tiempo!» y «…».
			card_body.add_child(_rival_tools())
		_show_clocks()
		return
	if game_clocked and game_state != "over":
		# Con reloj, el reloj ya dice a quién le toca: sin título.
		pass
	elif kids and voice_on and _has_voice(_voice_last):
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 16)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(title)
		top.add_child(_round_button("sound", _say_again, 96.0, _c("field"), _c("ink"), false))
		card_body.add_child(top)
	else:
		card_body.add_child(title)
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 12)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chips.add_child(_chip(str(game.get("title", "Partida")), _c("field"), _c("ink")))
	if game_clocked:
		var clock: Array = game.get("clock", [0, 0])
		chips.add_child(_chip("%d+%d" % [int(clock[0]), int(clock[1])], _c("field"), _c("quiet"), "clock"))
	chips.add_child(_chip("Blancas" if game_color == 0 else "Negras", _c("field"), _c("quiet"), "sun" if game_color == 0 else "moon"))
	if view.board.chess is WarChess:
		var war := view.board.chess as WarChess
		var tr := _tint("rose")
		chips.add_child(_chip(Loc.f("Blindajes: tú %d · rival %d", [war.armors_left(game_color), war.armors_left(1 - game_color)]), tr[0], tr[1], "shield"))
		if war.turn == game_color and war.armor_rested() and game_state == "play":
			# Acabas de blindar: este turno no puedes volver a hacerlo.
			chips.add_child(_chip("Blindar: el turno que viene", _c("field"), _c("quiet"), "clock"))
	var where := ""
	if game_back > 0 and game_state != "over":
		where = Loc.f("Viendo la jugada %d de %d · toca el tablero para volver", [game_history.size() - 1 - game_back, game_history.size() - 1])
	if game_clocked and where != "":
		# Con reloj no cabe una línea más: el aviso va en lugar de las etiquetas.
		chips = HFlowContainer.new()
		chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var t := _tint("peach")
		chips.add_child(_chip(Loc.f("Jugada %d de %d · toca el tablero para volver", [game_history.size() - 1 - game_back, game_history.size() - 1]), t[0], t[1], "back"))
	card_body.add_child(chips)
	if bool(game.get("online", false)):
		card_body.add_child(_rival_row())
		card_body.add_child(_gesture_row())
	if where != "" and not game_clocked:
		card_body.add_child(_para(where, F_SUB, _c("accent_text"), font_semibold))
	_clock_labels = []
	chess_clock = null
	if game_clocked:
		chess_clock = ChessClock.new()
		chess_clock.digits_font = _digits_font if _digits_font != null else font_display
		chess_clock.label_font = font_semibold
		chess_clock.dark = dark
		chess_clock.accent = _c("accent")
		chess_clock.custom_minimum_size = Vector2(0.0, 260.0 if game_state == "over" else 360.0)
		chess_clock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chess_clock.pressed_mine.connect(_on_clock_pressed)
		chess_clock.pressed_early.connect(_on_clock_early)
		card_body.add_child(chess_clock)
		_show_clocks()
		if game_state != "over":
			# Con el reloj, la tarjeta no crece: lo demás lo dicen el tablero y el reloj.
			return
	if game_state == "over":
		card_body.add_child(_para(game_result, F_BODY, _c("ink"), font_medium))
		return
	if game_history.size() <= 2 and str(game.get("text", "")) != "":
		card_body.add_child(_para(str(game.get("kids", "")) if kids and str(game.get("kids", "")) != "" else str(game["text"]), F_BODY, _c("ink"), font_regular))
	if game_note != "":
		card_body.add_child(_para(game_note, F_BODY, _c("quiet"), font_medium))
	# La valoración va en la leyenda de encima del tablero; aquí solo si la leyenda no cabe (o es «única jugada»,
	# que no está en la leyenda).
	if coach_verdict != "" and (not (COACH_LEGEND.has(coach_verdict) or coach_verdict == "brilliant" or coach_verdict == "miss") or not _coach_legend_shown()):
		var glyph := str((BADGES.get(_coach_badge_for(coach_verdict), ["", Color.WHITE]) as Array)[0])
		var mark := "" if glyph.begins_with("@") else glyph + " "
		card_body.add_child(_para(mark + _coach_label(coach_verdict), F_BODY, _c("ink"), font_semibold))
	if coach_note != "" or coach_waiting or not coach_lesson.is_empty() or _tutor_can_ask():
		card_body.add_child(_coach_block())
	if coach_debug != "" and Premium.test_on:
		card_body.add_child(_para(coach_debug, F_FOOT, _c("quiet"), font_regular))


func _build_game_actions() -> void:
	if lesson_open:
		_build_lesson_actions()
		return
	if game_state == "review":
		_build_review_actions()
		return
	if game_state == "detail":
		_build_detail_actions()
		return
	var is_online := bool(game.get("online", false))
	var key := "game:%s:%s:%s:%s:%d:%d:%d" % [game_state if game_state != "think" else "play", str(game.get("unit", "")), str(game_clocked), str(is_online), game_back, _online_pending.size(), game_history.size()]
	if game_state == "press":
		key += ":" + str(_press_warned)
	if key == _actions_mode:
		for b in [left_button, hint_button]:
			if b != null and is_instance_valid(b):
				b.disabled = game_state != "play"
				b.modulate.a = 1.0 if game_state == "play" else 0.42
		return
	_actions_mode = key
	for old in actions.get_children():
		(old as CanvasItem).visible = false
		old.queue_free()
	hint_button = null
	step_button = null
	var wide := {"font_size": F_BODY, "height": BAR_HEIGHT, "icon": 56.0, "radius": 60}
	var go := wide.duplicate()
	go["glow"] = _c("glow")
	go["trailing"] = true
	var row: Array[Button] = []
	if game_state == "over" and bool(game.get("saved", false)):
		# Una partida guardada: su análisis (resumen o jugada a jugada) y volver a la lista.
		left_button = _tool_button("chart", "Análisis", _open_review, "lilac")
		var det0 := _tool_button("line", "Jugada a jugada", _open_detail_from_over, "sky")
		right_button = _button("trend", "Mis partidas", _back_to_my_games, _c("accent"), _c("accent_ink"), go)
		row = [left_button, det0, right_button]
	elif game_state == "over" and str(game.get("campeonato", "")) != "":
		_record_game()
		_campeonato_record_once()
		var go_on := _button("next", "Seguir el torneo", _campeonato_after_game, _c("accent"), _c("accent_ink"), go)
		row = []
		if game_moves.size() >= 2:
			row.append(_tool_button("chart", "Análisis", _open_review, "lilac"))
			row.append(_tool_button("line", "Jugada a jugada", _open_detail_from_over, "sky"))
		row.append(go_on)
		left_button = row[0]
		right_button = go_on
	elif game_state == "over":
		_record_game()
		var next: Button
		if str(game.get("unit", "")) != "":
			next = _button("next", "Seguir", _game_next_lesson, _c("accent"), _c("accent_ink"), go)
		else:
			next = _button("next", "Salir", _leave_game, _c("accent"), _c("accent_ink"), go)
		row = [_tool_button("retry", "Otra", _game_again, "peach")]
		if str(game.get("variant", "")) == "" and game_moves.size() >= 2:
			# Resumen de la partida y, aparte y bien a la vista, el análisis jugada a jugada.
			row.append(_tool_button("chart", "Análisis", _open_review, "lilac"))
			if not kids:
				row.append(_tool_button("line", "Jugada a jugada", _open_detail_from_over, "sky"))
		row.append(next)
		left_button = row[0]
		right_button = next
	else:
		hint_button = _tool_button("bulb", "Pista", _game_hint, "butter")
		right_button = _tool_button("flag", "Rendirse", _ask_resign, "rose")
		var out := _tool_button("close", "Salir", _ask_leave, "lilac")
		# Mirar jugadas anteriores sin parar la partida; al mover el rival (o tocar el tablero) se vuelve al directo.
		var back0 := _tool_button("back", "Atrás", _game_browse.bind(1), "peach")
		var fwd0 := _tool_button("next", "Adelante", _game_browse.bind(-1), "mint")
		back0.disabled = game_history.size() <= 1 or game_back >= game_history.size() - 1
		back0.modulate.a = 0.42 if back0.disabled else 1.0
		fwd0.disabled = game_back == 0
		fwd0.modulate.a = 0.42 if game_back == 0 else 1.0
		left_button = _tool_button("retry", "Deshacer", _game_undo, "sky")
		row = [out, back0, fwd0, left_button, hint_button, right_button]
		if game_clocked or is_online:
			# Con reloj o contra una persona, como en una partida oficial: ni deshacer ni pistas.
			left_button = null
			hint_button = null
			row = [out, back0, fwd0, right_button]
			if is_online:
				# Mirar jugadas anteriores y volver al directo.
				var back := _tool_button("back", "Atrás", _game_browse.bind(1), "peach")
				var fwd := _tool_button("next", "Adelante", _game_browse.bind(-1), "mint")
				var live := _tool_button("play", "Directo" if _online_pending.is_empty() else "¡Directo!", _game_browse.bind(-99), "sky")
				fwd.disabled = game_back == 0
				fwd.modulate.a = 0.42 if game_back == 0 else 1.0
				live.disabled = game_back == 0
				live.modulate.a = 0.42 if game_back == 0 else 1.0
				row = [out, back, fwd, live, right_button]
				back.disabled = game_history.size() <= 1 or game_back >= game_history.size() - 1
				back.modulate.a = 0.42 if back.disabled else 1.0
		for b in [left_button, hint_button]:
			if b != null:
				b.disabled = game_state != "play" or game_back > 0
				b.modulate.a = 1.0 if not b.disabled else 0.42
	for b: Button in row:
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(b)




# ---------------------------------------------------------------- reto del día, racha y reto semanal
# La lógica está en core/progress.gd y sus valores en core/progress_config.gd; aquí solo se avisa de lo que
# ocurre (un problema, una lección, una partida), se enseñan los avisos y se dibuja la página «Tu día».
# Nada de esto se usa en el nivel Kids.

## [segundos Unix, minutos de diferencia con UTC]: el día cambia a medianoche del jugador.
func _prog_now() -> Array:
	return [int(Time.get_unix_time_from_system()), int(Time.get_time_zone_from_system().get("bias", 0))]


func _prog_day() -> int:
	var n := _prog_now()
	return Progress.day_number(int(n[0]), int(n[1]))


func _prog() -> Dictionary:
	if prog.is_empty():
		prog = Progress.load_state() if use_settings else Progress.new_state()
	return prog


func _prog_save() -> void:
	if use_settings:
		Progress.save_state(_prog())


## Lo que el núcleo necesita saber de hoy: si hay fallos que repasar, si quedan lecciones, qué categorías flojas
## tiene el jugador y cuántos problemas hay de cada una.
func _prog_ctx() -> Dictionary:
	var tries: Array = player.get("tries", [])
	var solved := {}
	for t: Dictionary in tries:
		if bool(t["correct"]):
			solved[str(t["id"])] = true
	var due := 0
	for t: Dictionary in tries:
		var id := str(t["id"])
		if not bool(t["correct"]) and not solved.has(id) and not reviewed.has(id) and _index_of.has(id):
			due += 1
	var lessons_left := false
	for l: Dictionary in _course_lessons():
		if not course_done.has(str(l["id"])):
			lessons_left = true
			break
	var families := {}
	for p: Dictionary in pool:
		var f := str(p.get("family", "otros"))
		families[f] = int(families.get(f, 0)) + 1
	var focus: Array = []
	if _has_player():
		var plan := Assessment.plan(player["rating"], Assessment.profile(tries))
		for item: Dictionary in plan["focus"]:
			if str(item["kind"]) == "family":
				focus.append(str(item["family"]))
	return {"can_review": due >= 2, "lessons_left": lessons_left, "kids": kids, "focus": focus, "families": families}


## Primer intento de un problema nuevo (el que mueve el nivel): cuenta para «Resuelve 3 problemas».
func _prog_problem(correct: bool) -> void:
	if kids:
		return
	var n := _prog_now()
	var avisos := Progress.record_problem(_prog(), {"correct": correct}, int(n[0]), int(n[1]), _prog_ctx())
	# Si ya sale el aviso de puntos ganados, el de objetivos espera a que termine.
	var after_points := mode == "train" and correct and float(_rating_shown[1]) > float(_rating_shown[0]) + 0.5
	_prog_done(avisos, 3.2 if after_points else 0.6)


## Un problema del entrenamiento que termina, nuevo o repetido (resuelto, o con la solución a la vista): cuenta para
## el reto de la semana (cada problema de su categoría, una vez) y para el repaso de hoy. Antes, un problema ya
## intentado (los repasos y los repetidos) no contaba para nada, porque solo se anotaba el primer intento.
func _prog_finish(solved: bool, review: bool) -> void:
	if kids or mode != "train" or not _has_player() or index < 0 or index >= pool.size():
		return
	var item: Dictionary = pool[index]
	var n := _prog_now()
	var avisos := Progress.record_finish(_prog(), {"id": str(item["id"]), "family": str(item.get("family", "otros")), "solved": solved, "review": review}, int(n[0]), int(n[1]), _prog_ctx())
	# Si además sale el aviso de puntos ganados, _prog_problem ya pidió esperar más (se queda el retraso mayor).
	_prog_done(avisos, 0.6)


func _prog_lesson() -> void:
	if kids:
		return
	var n := _prog_now()
	_prog_done(Progress.record_lesson(_prog(), int(n[0]), int(n[1]), _prog_ctx()), 1.2)


## Partida terminada y anotada en el historial (no cuentan las del curso, las variantes ni Kids).
func _prog_game() -> void:
	if kids:
		return
	var moves := game_moves.size()
	var own := (moves + 1) / 2 if game_color == 0 else moves / 2
	var n := _prog_now()
	_prog_done(Progress.record_game(_prog(), {"own_moves": own, "result": game_won}, int(n[0]), int(n[1]), _prog_ctx()), 1.4)


var _prog_pending: Array = []
var _prog_pending_delay := -1.0


func _prog_done(avisos: Array, delay: float) -> void:
	_prog_save()
	_aviso_refresh()
	# Al resolver un problema nuevo llegan dos anotaciones seguidas (el primer intento y el final): se juntan sus
	# avisos y sale solo el más importante.
	_prog_pending.append_array(avisos)
	if _prog_pending_delay < 0.0:
		_prog_flush.call_deferred()
	_prog_pending_delay = maxf(_prog_pending_delay, delay)


func _prog_flush() -> void:
	var avisos := _prog_pending
	var delay := _prog_pending_delay
	_prog_pending = []
	_prog_pending_delay = -1.0
	_prog_notify(avisos, delay)


const PROG_GOAL_DONE := {"problemas": "Problemas de hoy hechos", "repaso": "Repaso de hoy hecho", "leccion": "Lección de hoy hecha", "partida": "Partida de hoy jugada"}


## Enseña el aviso más importante de los que ha habido (uno solo, para no saturar).
func _prog_notify(avisos: Array, delay: float) -> void:
	var order := {"racha": 1, "objetivo": 2, "reto_dia": 3, "reto_semana": 4, "insignia": 5}
	var best := {}
	for a: Dictionary in avisos:
		if str(a["tipo"]) == "racha" and int(a["dias"]) < 2:
			continue
		if best.is_empty() or int(order[str(a["tipo"])]) > int(order[str(best["tipo"])]):
			best = a
	if best.is_empty():
		return
	var title := ""
	var sub := ""
	var party := true
	match str(best["tipo"]):
		"insignia":
			title = "¡Nueva insignia!"
			sub = str(Progress.badge_info(str(best["id"]))["nombre"])
		"reto_semana":
			title = "¡Reto de la semana cumplido!"
			sub = Loc.t(str(Assessment.FAMILY_NAME.get(str(best["familia"]), "")))
		"reto_dia":
			title = "¡Reto del día cumplido!"
			var streak := Progress.streak_now(_prog(), _prog_day())
			sub = Loc.f("Racha de %d días", streak) if streak >= 2 else Loc.t("Hasta mañana")
		"objetivo":
			title = "¡Objetivo cumplido!"
			sub = str(PROG_GOAL_DONE.get(str(best["meta"]), ""))
			party = false
		"racha":
			title = Loc.f("¡Racha de %d días!", int(best["dias"]))
			sub = "Sigue mañana"
			party = false
	if title == "":
		return
	if delay <= 0.0:
		_prog_toast(title, sub, party)
	else:
		get_tree().create_timer(delay).timeout.connect(_prog_toast.bind(title, sub, party))


var _prog_toast_node: Control


func _prog_toast(title: String, sub: String, party: bool, wait_left: int = 150) -> void:
	# Con la enhorabuena de subir de nivel o la ventana «¡Resuelto!» abiertas (o a punto de salir), se espera a que
	# se cierren (como mucho un minuto): un aviso de premio encima de otro tapa los dos.
	var celebrating := _celebration != null and is_instance_valid(_celebration) and _celebration.mouse_filter == Control.MOUSE_FILTER_STOP
	var solved_popup := result_popup and phase == Phase.SOLVED and mode != "learn" and mode != "game"
	if (celebrating or solved_popup) and wait_left > 0:
		get_tree().create_timer(0.4).timeout.connect(_prog_toast.bind(title, sub, party, wait_left - 1))
		return
	if _prog_toast_node != null and is_instance_valid(_prog_toast_node):
		_prog_toast_node.queue_free()
	var toast := Control.new()
	toast.set_anchors_preset(Control.PRESET_FULL_RECT)
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast)
	_prog_toast_node = toast
	var tint := _tint("butter")
	var pill := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = tint[0]
	sb.set_corner_radius_all(60)
	sb.shadow_color = _c("shadow")
	sb.shadow_size = 24
	sb.shadow_offset = Vector2(0.0, 10.0)
	sb.content_margin_left = 44
	sb.content_margin_right = 44
	sb.content_margin_top = 22
	sb.content_margin_bottom = 22
	pill.add_theme_stylebox_override("panel", sb)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(row)
	row.add_child(_icon("flag", 64.0, tint[1]))
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 0)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(_line(title, F_HEAD, _c("ink"), font_display))
	if sub != "":
		words.add_child(_line(sub, F_SUB, tint[1], font_semibold))
	# Nunca más ancho que la pantalla: un texto largo baja de línea (antes se salía por los dos lados).
	var room := maxf(300.0, size.x * 0.9 - 44.0 * 2.0 - 64.0 - 20.0)
	for lab: Node in words.get_children():
		var l := lab as Label
		if l == null:
			continue
		var wide := l.get_theme_font("font").get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x
		if wide > room:
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size.x = room
	row.add_child(words)
	toast.add_child(pill)
	_prog_toast_place.call_deferred()
	if party:
		var bits := Confetti.new()
		bits.set_anchors_preset(Control.PRESET_FULL_RECT)
		bits.mouse_filter = Control.MOUSE_FILTER_IGNORE
		toast.add_child(bits)
		bits.burst(Vector2(size.x * 0.5, 340.0), 40, _confetti_colors(), 1400.0)
	pill.pivot_offset = Vector2(240.0, 60.0)
	pill.scale = Vector2(0.6, 0.6)
	pill.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(pill, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(pill, "modulate:a", 1.0, 0.2)
	tw.chain().tween_interval(2.4)
	tw.chain().tween_property(pill, "modulate:a", 0.0, 0.4)
	tw.chain().tween_callback(toast.queue_free)


## Coloca el aviso de premio (el último: si ha llegado otro antes de colocarlo, el anterior ya no está).
func _prog_toast_place() -> void:
	if _prog_toast_node == null or not is_instance_valid(_prog_toast_node) or _prog_toast_node.is_queued_for_deletion():
		return
	var pill := _prog_toast_node.get_child(0) as Control
	pill.reset_size()
	var top := board_slot.get_global_rect().position.y + 20.0 if board_slot != null and progress == null else 260.0
	pill.position = Vector2((size.x - pill.get_combined_minimum_size().x) * 0.5, top)


## Frase de la tarjeta del inicio: objetivos de hoy cumplidos y racha.
func _prog_home_text() -> String:
	var s := _prog()
	var day := _prog_day()
	Progress.ensure_today(s, day, _prog_ctx())
	var goals := Progress.goals(s, day)
	var done := 0
	for g: Dictionary in goals:
		if bool(g["hecho"]):
			done += 1
	var streak := Progress.streak_now(s, day)
	var text := Loc.f("Hoy %d de %d", [done, goals.size()]) if not goals.is_empty() else Loc.t("Tu objetivo de hoy")
	if bool((s["reto"] as Dictionary)["completo"]):
		text = Loc.t("¡Cumplido hoy!")
	if streak >= 2:
		text += Loc.f(" · racha de %d días", streak)
	return text


const PROG_GOAL_ICON := {"problemas": ["target", "peach"], "repaso": ["retry", "lilac"], "leccion": ["book", "butter"], "partida": ["piece_knight", "sky"]}


func _prog_goal_text(g: Dictionary) -> String:
	var n := int(g["meta"])
	match str(g["tipo"]):
		"problemas":
			return Loc.f("Resuelve %d problemas", n) if n != 1 else Loc.t("Resuelve un problema")
		"repaso":
			return Loc.t("Repasa un fallo antiguo") if n == 1 else Loc.f("Repasa %d fallos antiguos", n)
		"leccion":
			return Loc.t("Haz una lección") if n == 1 else Loc.f("Haz %d lecciones", n)
		"partida":
			return Loc.t("Juega una partida") if n == 1 else Loc.f("Juega %d partidas", n)
	return ""


## Una fila de «Tu día» con su botón «Ir» a la derecha, centrado en alto.
func _with_go(row: Control, go: Callable) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 16)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(row)
	var b := _button("next", "Ir", go, _c("accent_soft"), _c("accent_text"), {"font_size": F_SUB, "height": 88.0, "icon": 40.0, "pad_x": 26.0, "trailing": true, "radius": 44})
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(b)
	return line


## «Ir» de un reto de hoy: directo a lo que falta.
func _prog_goal_go(kind: String) -> void:
	match kind:
		"problemas":
			_train_family("")
		"repaso":
			_go_review()
		"leccion":
			for l: Dictionary in _course_lessons():
				if not course_done.has(str(l["id"])):
					_start_lesson(str(l["id"]))
					return
			_open_course()
		"partida":
			_open_game_setup(true)


## Directo a repasar: el fallo más antiguo que aún no se ha resuelto ni repasado (sin esperar a que toque en el
## entrenamiento). Si no queda ninguno, el entrenamiento de siempre.
func _go_review() -> void:
	var ids := _pending_fails()
	if ids.is_empty():
		_train_family("")
		return
	train_family = ""
	train_level = -1
	mode = "train"
	review_session = false
	_close_progress()
	_since_review = 0
	_start(int(_index_of[str(ids[0])]), true)


## Fallos pendientes de repaso (ids), del más antiguo al más reciente: problemas fallados que nunca se han resuelto
## ni repasado.
func _pending_fails() -> Array:
	if not _has_player():
		return []
	var tries: Array = player["tries"]
	var solved := {}
	for t: Dictionary in tries:
		if bool(t["correct"]):
			solved[str(t["id"])] = true
	var out: Array = []
	var taken := {}
	for t: Dictionary in tries:
		var id := str(t["id"])
		if bool(t["correct"]) or solved.has(id) or reviewed.has(id) or taken.has(id) or not _index_of.has(id):
			continue
		taken[id] = true
		out.append(id)
	return out


## «Repasar mis fallos»: todos los pendientes seguidos, del más antiguo al más reciente, con todas las ayudas y la
## explicación completa (como cualquier repaso: no mueve el nivel).
func _start_review_session() -> void:
	var ids := _pending_fails()
	if ids.is_empty():
		_popup(Loc.t("No te quedan fallos"), Loc.t("Los problemas que falles aparecerán aquí para repasarlos."))
		return
	mode = "train"
	train_family = ""
	train_level = -1
	practice_queue.clear()
	review_session = true
	_review_session_seen = {}
	_review_session_total = ids.size()
	_close_progress()
	_review_session_next(ids)


func _review_session_next(ids: Array) -> void:
	for id: String in ids:
		if not _review_session_seen.has(id):
			_review_session_seen[id] = true
			_since_review = 0
			_start(int(_index_of[id]), true)
			return
	_review_session_end()


## Fin de la sesión: cuántos quedan (los saltados sin resolver) y a dónde seguir.
func _review_session_end() -> void:
	review_session = false
	var left := _pending_fails().size()
	var text := Loc.t("Has repasado todos tus fallos. Los que falles a partir de ahora aparecerán aquí.") if left == 0 else Loc.f("Has pasado por todos. Te quedan %d sin resolver: saldrán la próxima vez.", left)
	var column := _popup(Loc.t("Fallos repasados"), text)
	var opts := {"font_size": F_SUB, "height": 104.0, "icon": 48.0}
	var tint := _tint("mint")
	var more := _button("play", "Seguir entrenando", func() -> void:
		_close_confirm()
		_train_family(""), tint[0], tint[1], opts)
	more.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(more)
	var back := _button("back", "Volver a Entrenar", func() -> void:
		_close_confirm()
		_open_train_hub(), _c("field"), _c("ink"), opts)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(back)


## «Tu día»: racha, objetivos de hoy, reto de la semana, lo hecho hoy e insignias.
func _open_day() -> void:
	var s := _prog()
	var day := _prog_day()
	Progress.ensure_today(s, day, _prog_ctx())
	_prog_save()
	var page := _page("day")
	var body: VBoxContainer = page["body"]
	var footer: VBoxContainer = page["footer"]
	body.add_child(_spacer(4.0))
	body.add_child(_centered(_para("TU DÍA", F_CAP, _c("quiet"), font_semibold)))
	var streak := Progress.streak_now(s, day)
	if streak > 0:
		var number := _centered(_para("%d" % streak, F_LARGE + 44, _c("ink"), font_display))
		number.add_theme_constant_override("line_spacing", -8)
		body.add_child(number)
		body.add_child(_centered(_para("día de racha" if streak == 1 else "días de racha", F_HEAD, _c("quiet"), font_medium)))
	else:
		body.add_child(_spacer(10.0))
		body.add_child(_centered(_para("Juega hoy para empezar una racha", F_HEAD, _c("ink"), font_display)))
	var best := int((s["racha"] as Dictionary)["mejor"])
	var small := PackedStringArray()
	if best > streak:
		small.append(Loc.t("Tu mejor racha: 1 día.") if best == 1 else Loc.f("Tu mejor racha: %d días.", best))
	if ProgressConfig.GRACE_PER_WEEK > 0:
		small.append(Loc.t("Si un día no puedes jugar no pasa nada: una vez por semana se te perdona."))
	if not small.is_empty():
		body.add_child(_spacer(8.0))
		body.add_child(_centered(_para(" ".join(small), F_FOOT, _c("quiet"), font_regular)))

	# Objetivos de hoy.
	body.add_child(_spacer(36.0))
	var complete := bool((s["reto"] as Dictionary)["completo"])
	body.add_child(_text("RETO DE HOY · ¡CUMPLIDO!" if complete else "RETO DE HOY", F_CAP, _c("quiet"), font_semibold))
	body.add_child(_spacer(12.0))
	var made := _panel()
	body.add_child(made[0])
	for g: Dictionary in Progress.goals(s, day):
		var def: Array = PROG_GOAL_ICON[str(g["tipo"])]
		var done := bool(g["hecho"])
		var progress_text := "¡Hecho!" if done else (Loc.f("%d de %d", [int(g["actual"]), int(g["meta"])]) if int(g["meta"]) > 1 else "Todavía no")
		var row := _profile_row("check" if done else str(def[0]), "mint" if done else str(def[1]), _prog_goal_text(g), progress_text)
		# Lo que falta, a un toque: «Ir» lleva directo a ese reto.
		(made[1] as VBoxContainer).add_child(row if done else _with_go(row, _prog_goal_go.bind(str(g["tipo"]))))

	# Reto de la semana.
	var w: Dictionary = s["semana"]
	if str(w["familia"]) != "":
		body.add_child(_spacer(36.0))
		body.add_child(_text("RETO DE LA SEMANA", F_CAP, _c("quiet"), font_semibold))
		body.add_child(_spacer(12.0))
		var wmade := _panel()
		body.add_child(wmade[0])
		var fam := str(Assessment.FAMILY_NAME.get(str(w["familia"]), str(w["familia"])))
		var wtext := Loc.t("¡Cumplido!") if bool(w["completo"]) else Loc.f("%d de %d problemas resueltos", [mini(int(w["hecho"]), int(w["meta"])), int(w["meta"])])
		var wrow := _profile_row("check" if bool(w["completo"]) else "flag", "mint" if bool(w["completo"]) else "rose", fam, wtext)
		(wmade[1] as VBoxContainer).add_child(wrow if bool(w["completo"]) else _with_go(wrow, _train_family.bind(str(w["familia"]))))

	# Aviso diario (solo si hay plugin de notificaciones).
	if not kids and (_aviso_available() or not use_settings):
		body.add_child(_spacer(36.0))
		body.add_child(_text("AVISO DIARIO", F_CAP, _c("quiet"), font_semibold))
		body.add_child(_spacer(12.0))
		var amade := _panel()
		body.add_child(amade[0])
		var aviso_on := bool((s["aviso"] as Dictionary)["activo"])
		(amade[1] as VBoxContainer).add_child(_switch_row("clock", "peach", "Avisarme cada día", Loc.f("A las %s, solo si aún no has cumplido tu reto.", _aviso_hour_text()), aviso_on, _aviso_set))
		# La hora, con el reloj de WakeAgenda (21:00 si no se elige otra).
		if aviso_on:
			(amade[1] as VBoxContainer).add_child(_option_button("clock", "peach", "Hora del aviso", Loc.f("%s · toca para cambiar", _aviso_hour_text()), _aviso_pick_time))
			var next := _aviso_next_text()
			if next != "":
				body.add_child(_spacer(10.0))
				body.add_child(_para(next, F_FOOT, _c("quiet"), font_regular))

	# Lo hecho hoy.
	var lines := Progress.summary_lines(s, day)
	if not lines.is_empty():
		body.add_child(_spacer(36.0))
		body.add_child(_text("HOY HAS HECHO", F_CAP, _c("quiet"), font_semibold))
		body.add_child(_spacer(10.0))
		for line: String in lines:
			body.add_child(_para(line, F_BODY, _c("ink"), font_medium))

	# Insignias.
	var badges: Array = s["insignias"]
	if not badges.is_empty():
		body.add_child(_spacer(36.0))
		body.add_child(_text("INSIGNIAS", F_CAP, _c("quiet"), font_semibold))
		body.add_child(_spacer(12.0))
		var bmade := _panel()
		body.add_child(bmade[0])
		for i in range(badges.size() - 1, -1, -1):
			var info := Progress.badge_info(str(badges[i]))
			(bmade[1] as VBoxContainer).add_child(_profile_row("party", "butter", str(info["nombre"]), str(info["texto"])))
	body.add_child(_spacer(20.0))

	var go := {"font_size": F_HEAD, "height": 148.0, "icon": 60.0, "trailing": true, "glow": _c("glow")}
	var train := _button("next", "Entrenar", _home_train, _c("accent"), _c("accent_ink"), go)
	train.mouse_filter = Control.MOUSE_FILTER_STOP
	footer.add_child(train)
	footer.add_child(_spacer(8.0))
	footer.add_child(_button("home", "Inicio", _open_home, _c("field"), _c("ink"), {"font_size": F_SUB, "height": 92.0, "icon": 44.0, "font": font_medium}))


# ---------------------------------------------------------------- aviso diario
# Qué decir y cuándo lo decide core/reminder.gd; aquí solo se habla con el plugin de notificaciones locales de
# Android (Notification Scheduler, MIT), que se añade al compilar el APK con avisos. Sin el plugin (el
# ordenador, la web o un APK normal) nada de esto hace nada y la fila de «Tu día» no sale.

const AVISO_PLUGIN := "res://addons/NotificationSchedulerPlugin/"
const AVISO_ID := 4201
const AVISO_CHANNEL := "chessome_diario"

## El reloj abierto para elegir la hora del aviso (para las pruebas).
var _aviso_picker: ClockPicker
var _aviso_node: Node
var _aviso_ready := false


func _aviso_available() -> bool:
	return OS.has_feature("android") and Engine.has_singleton("NotificationSchedulerPlugin") and ResourceLoader.exists(AVISO_PLUGIN + "NotificationScheduler.gd")


## Conecta con el plugin una vez (si está y no es Kids).
func _aviso_setup() -> void:
	if _aviso_node != null or kids or not _aviso_available():
		return
	var script: GDScript = load(AVISO_PLUGIN + "NotificationScheduler.gd")
	_aviso_node = script.new()
	add_child(_aviso_node)
	_aviso_node.initialization_completed.connect(_aviso_on_ready)
	_aviso_node.post_notifications_permission_granted.connect(_aviso_on_permission.bind(true))
	_aviso_node.post_notifications_permission_denied.connect(_aviso_on_permission.bind(false))
	_aviso_node.initialize()


func _aviso_on_ready() -> void:
	var channel = (load(AVISO_PLUGIN + "model/NotificationChannel.gd") as GDScript).new()
	channel.set_id(AVISO_CHANNEL).set_name(Loc.t("Aviso diario")).set_description(Loc.t("Un recordatorio al día para entrenar")).set_importance(3)
	_aviso_node.create_notification_channel(channel)
	_aviso_ready = true
	_aviso_refresh()


func _aviso_on_permission(_permission: String, granted: bool) -> void:
	if granted and bool((_prog()["aviso"] as Dictionary)["activo"]):
		_aviso_refresh()
		_aviso_preview()
	if not granted:
		(_prog()["aviso"] as Dictionary)["activo"] = false
		_prog_save()
		_aviso_refresh()
		if progress != null and is_instance_valid(progress) and progress_kind == "day":
			_open_day()


## Activado o no, y a qué hora: la que eligió el jugador con el reloj o, si no eligió ninguna, ReminderConfig.HOUR
## (las horas que se guardaron con el selector de antes, de cuatro horas fijas, ya no cuentan: no llevan «elegida»).
func _aviso_settings() -> Dictionary:
	var a: Dictionary = _prog()["aviso"]
	var chosen := bool(a.get("elegida", false))
	return {"enabled": bool(a["activo"]), "hour": int(a["hora"]) if chosen else ReminderConfig.HOUR, "minute": int(a["min"]) if chosen else 0}


## El reloj para elegir la hora del aviso (ui/clock_picker.gd), en una ventana con «Cancelar» y «Aceptar».
func _aviso_pick_time() -> void:
	var settings := _aviso_settings()
	var column := _popup(Loc.t("Hora del aviso"), "", true)
	var picker := ClockPicker.new()
	picker.primary = _c("accent")
	picker.on_primary = _c("ink")
	picker.face_color = _c("field")
	picker.ink = _c("ink")
	picker.quiet = _c("quiet")
	picker.font_bold = font_display
	picker.font_medium = font_medium
	picker.hint_font = F_BODY
	picker.diameter = clampf(minf(size.x - 120.0, 860.0) - 140.0, 480.0, 700.0)
	picker.set_time(int(settings["hour"]), int(settings["minute"]))
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(picker)
	_aviso_picker = picker
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	column.add_child(row)
	var opts := {"font_size": F_BODY, "height": 116.0, "icon": 56.0, "radius": 58}
	var cancel := _button("back", "Cancelar", _close_confirm, _c("field"), _c("ink"), opts)
	var ok := _button("check", "Aceptar", func() -> void:
		_aviso_set_time(picker.hour, picker.minute)
		_close_confirm()
		_open_day(), _c("accent"), _c("ink"), opts)
	for b: Button in [cancel, ok]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)


## Guarda la hora elegida y vuelve a programar el aviso.
func _aviso_set_time(hour: int, minute: int) -> void:
	var a: Dictionary = _prog()["aviso"]
	a["hora"] = clampi(hour, 0, 23)
	a["min"] = clampi(minute, 0, 59)
	a["elegida"] = true
	_prog_save()
	_aviso_refresh()


## «Próximo aviso: hoy a las 21:00» (o mañana, o dentro de unos días), con el mismo cálculo que lo programa; vacío si
## no hay ninguno (p. ej. reto cumplido y aviso apagado).
func _aviso_next_text() -> String:
	var n := _prog_now()
	var plan := Reminder.plan(_prog(), _aviso_settings(), int(n[0]), int(n[1]))
	if plan.is_empty():
		return ""
	var days := Progress.day_number(int(plan["at"]), int(n[1])) - Progress.day_number(int(n[0]), int(n[1]))
	var hour := _aviso_hour_text()
	if days <= 0:
		return Loc.f("Próximo aviso: hoy a las %s.", hour)
	if days == 1:
		return Loc.f("Próximo aviso: mañana a las %s.", hour)
	return Loc.f("Próximo aviso: dentro de %d días, a las %s.", [days, hour])


## El complemento propio que pinta el aviso diario con el diseño de A Chess Way (o null si este APK no lo trae). El
## código Java va en el mismo APK que este script: si está el complemento, tiene scheduleReminder (y has_method no
## sirve con los métodos Java de un singleton).
func _aviso_own() -> Object:
	return Engine.get_singleton("EsperaOnline") if Engine.has_singleton("EsperaOnline") else null


## Vuelve a programar el próximo aviso (se cancela el anterior): tras cada cosa que hace el jugador y al salir de la app.
func _aviso_refresh() -> void:
	if kids or _aviso_node == null or not _aviso_ready:
		return
	_aviso_node.cancel(AVISO_ID)
	var own := _aviso_own()
	if own != null:
		own.call("cancelReminder")
	var settings := _aviso_settings()
	if not bool(settings["enabled"]):
		return
	var n := _prog_now()
	var plan := Reminder.plan(_prog(), settings, int(n[0]), int(n[1]))
	if plan.is_empty():
		return
	# Con el diseño de A Chess Way (degradado gris, logo grande y «Entrenar»; android_espera/AvisoReceiver.java). Si
	# el APK no lo trae, el aviso estándar del complemento de notificaciones.
	if own != null:
		own.call("scheduleReminder", {"at": int(plan["at"]), "title": str(plan["title"]), "text": str(plan["body"]), "pill": Loc.t("Entrenar"), "channel": Loc.t("Aviso diario")})
		return
	var data = (load(AVISO_PLUGIN + "model/NotificationData.gd") as GDScript).new()
	data.set_id(AVISO_ID).set_channel_id(AVISO_CHANNEL).set_title(str(plan["title"])).set_content(str(plan["body"]))
	data.set_delay(maxi(1, int(plan["at"]) - int(n[0])))
	_aviso_node.schedule(data)


func _aviso_set(on: bool) -> void:
	(_prog()["aviso"] as Dictionary)["activo"] = on
	_prog_save()
	var ask: bool = on and _aviso_node != null and not bool(_aviso_node.has_post_notifications_permission())
	if ask:
		_aviso_node.request_post_notifications_permission()
	_aviso_refresh()
	# La muestra, después de reprogramar (reprogramar quita el aviso anterior).
	if on and not ask:
		_aviso_preview()
	_open_day()


## Al activar el aviso (con permiso), uno de muestra en ese momento: así se ve cómo es y que funciona.
func _aviso_preview() -> void:
	var own := _aviso_own()
	if own == null or kids:
		return
	var status := str(own.call("showReminderNow", {"title": Loc.t("Tu reto de hoy"), "text": Loc.f("Así te avisaremos a las %s si aún no has cumplido tu reto.", _aviso_hour_text()), "pill": Loc.t("Entrenar"), "channel": Loc.t("Aviso diario")}))
	# Si Android no deja enseñarlo, se dice por qué (si no, el jugador solo vería que no llega nada).
	if status == "off":
		_prog_toast(Loc.t("No llegan los avisos"), Loc.t("Los avisos de la app están desactivados en los ajustes de Android."), false)
	elif status == "channel":
		_prog_toast(Loc.t("No llegan los avisos"), Loc.t("El aviso diario está desactivado en los ajustes de Android."), false)
	elif status != "ok":
		_prog_toast(Loc.t("No llegan los avisos"), status, false)


## La hora del aviso como se escribe en cada idioma: «21:00» y, en inglés, «9 PM» o «9:30 PM».
func _aviso_hour_text() -> String:
	var settings := _aviso_settings()
	var h := int(settings["hour"])
	var m := int(settings["minute"])
	if Loc.language == "en":
		var h12 := 12 if h % 12 == 0 else h % 12
		var ampm := "PM" if h >= 12 else "AM"
		return ("%d %s" % [h12, ampm]) if m == 0 else ("%d:%02d %s" % [h12, m, ampm])
	return "%d:%02d" % [h, m]


# ---------------------------------------------------------------- insignia del nivel

## Rango de cada nivel: pieza, nombre y color (niveles 0–1 peón … 10 rey).
const RANKS := [["piece_pawn", "Peón", "mint"], ["piece_knight", "Caballo", "sky"], ["piece_bishop", "Alfil", "butter"], ["piece_rook", "Torre", "peach"], ["piece_queen", "Dama", "rose"], ["piece_king", "Rey", "lilac"]]


func _rank(level: int) -> Array:
	return RANKS[clampi(level / 2, 0, RANKS.size() - 1)]


## Lo que llevas del nivel actual hacia el siguiente (0–1; 1 en el último nivel).
func _level_progress(rating: float) -> float:
	var lv := Assessment.level_of(rating)
	if lv + 1 >= Assessment.LEVEL_FLOORS.size():
		return 1.0
	var lo := float(Assessment.LEVEL_FLOORS[lv])
	var hi := float(Assessment.LEVEL_FLOORS[lv + 1])
	return clampf((rating - lo) / maxf(hi - lo, 1.0), 0.0, 1.0)


## Elo de juego para la insignia del avatar («1566»), o "" si aún no hay partidas que cuenten (o en Kids): entonces
## la insignia lleva el nivel de táctica (0–10). Decisión de Pablo (22 nov): el número a la vista, el Elo.
func _badge_elo() -> String:
	if kids:
		return ""
	var gr := GameLog.game_rating(_log())
	return str(roundi(float(gr["r"]))) if int(gr["n"]) > 0 else ""


func _level_badge(rating: float, side: float, elo_label: String = "") -> Control:
	var lv := Assessment.level_of(rating)
	var rank := _rank(lv)
	var tint := _tint(str(rank[2]))
	var badge := LevelBadge.new()
	badge.custom_minimum_size = Vector2(side, side)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.fill = tint[0]
	badge.ring = tint[1]
	badge.track = Color(tint[1].r, tint[1].g, tint[1].b, 0.18)
	badge.bubble = tint[1]
	badge.bubble_ink = Color.WHITE
	badge.progress = _level_progress(rating)
	badge.level = lv
	badge.label = elo_label
	badge.font = font_display
	var photo := _avatar_photo() if avatar == "foto" else null
	if photo != null:
		# La foto (ya recortada en círculo) llena la insignia por dentro del anillo.
		var pic := TextureRect.new()
		pic.texture = photo
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pic.set_anchors_preset(Control.PRESET_FULL_RECT)
		var inset := side * 0.11
		pic.offset_left = inset
		pic.offset_top = inset
		pic.offset_right = -inset
		pic.offset_bottom = -inset
		pic.show_behind_parent = true
		badge.fill = Color(tint[0].r, tint[0].g, tint[0].b, 0.0)
		badge.add_child(pic)
		return badge
	var glyph := avatar if avatar.begins_with("piece_") and UiIcons.has(avatar) else str(rank[0])
	var icon := _icon(glyph, side * 0.5, tint[1])
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = side * 0.25
	icon.offset_top = side * 0.22
	icon.offset_right = -side * 0.25
	icon.offset_bottom = -side * 0.28
	badge.add_child(icon)
	return badge


func _avatar_photo() -> Texture2D:
	if _avatar_tex == null and FileAccess.file_exists(AVATAR_PATH):
		var img := Image.new()
		if img.load_png_from_buffer(FileAccess.get_file_as_bytes(AVATAR_PATH)) == OK:
			img.generate_mipmaps()
			_avatar_tex = ImageTexture.create_from_image(img)
	return _avatar_tex


## Hoja «Tu icono»: elegir una pieza, la del rango (automática) o una foto del dispositivo.
func _open_avatar() -> void:
	options_open = true
	sheet_kind = "avatar"
	_build_avatar_sheet()


func _build_avatar_sheet() -> void:
	var box := _sheet("Tu icono")
	if box == null:
		return
	box.add_child(_para("Es el dibujo de tu insignia. El anillo y el número siguen marcando tu nivel.", F_SUB, _c("quiet"), font_regular))
	var pieces := ["", "piece_pawn", "piece_knight", "piece_bishop", "piece_rook", "piece_queen", "piece_king"]
	var labels := ["Mi rango", "Peón", "Caballo", "Alfil", "Torre", "Dama", "Rey"]
	var row: HBoxContainer = null
	for i in pieces.size():
		if i % 4 == 0:
			row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 12)
			box.add_child(row)
		var on: bool = avatar == str(pieces[i])
		var colors := _choice_colors(on)
		var glyph: String = pieces[i]
		if glyph == "":
			glyph = str(_rank(Assessment.level_of(float(player["rating"]["r"])) if _has_player() else 0)[0])
		var b := _button(glyph, str(labels[i]), _set_avatar.bind(pieces[i]), colors[0], colors[1], {"vertical": true, "font_size": F_FOOT, "height": 178.0, "icon": 84.0, "radius": 40, "pad_x": 6.0, "border": colors[2], "font": font_semibold if on else font_medium})
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	if not kids:
		# En el nivel Kids no se ofrece cargar fotos.
		var photo_tint := _tint("sky")
		box.add_child(_button("open", "Cargar una foto", _pick_avatar_photo, photo_tint[0], photo_tint[1], {"font_size": F_SUB, "height": 112.0, "icon": 52.0}))
		box.add_child(_para("La foto se guarda solo en este dispositivo.", F_FOOT, _c("quiet"), font_regular))
	if _has_player() and not kids and progress_kind != "progress":
		var mine_tint := _tint("lilac")
		box.add_child(_button("cap", "Mi nivel y mi plan", _open_progress.bind("progress"), mine_tint[0], mine_tint[1], {"font_size": F_SUB, "height": 112.0, "icon": 52.0}))


func _set_avatar(value: String) -> void:
	avatar = value
	_save_settings()
	_avatar_changed()


## Rehace las insignias que hay a la vista con el icono nuevo.
func _avatar_changed() -> void:
	if level_slot != null and is_instance_valid(level_slot):
		level_slot.set_meta("key", "")
	_sync_level_badge()
	_close_options()
	if progress_kind == "home":
		_open_home()
	elif progress_kind == "progress":
		_open_progress("progress")


func _pick_avatar_photo() -> void:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		_close_options()
		_note("Este dispositivo no deja elegir una foto")
		return
	DisplayServer.file_dialog_show("Elige una foto", "", "", false, DisplayServer.FILE_DIALOG_MODE_OPEN_FILE, PackedStringArray(["*.png,*.jpg,*.jpeg,*.webp;Imágenes"]), _on_avatar_photo)


func _on_avatar_photo(ok: bool, paths: PackedStringArray, _filter: int) -> void:
	if not ok or paths.is_empty():
		return
	var bytes := FileAccess.get_file_as_bytes(paths[0])
	var img := Image.new()
	var loaded := false
	for loader: String in ["load_jpg_from_buffer", "load_png_from_buffer", "load_webp_from_buffer"]:
		if not bytes.is_empty() and img.call(loader, bytes) == OK:
			loaded = true
			break
	if not loaded:
		_close_options()
		_note("No se ha podido abrir esa foto")
		return
	# Cuadrada por el centro, a 256 px y recortada en círculo: así encaja en la insignia.
	var side := mini(img.get_width(), img.get_height())
	img = img.get_region(Rect2i((img.get_width() - side) / 2, (img.get_height() - side) / 2, side, side))
	img.resize(256, 256, Image.INTERPOLATE_LANCZOS)
	img.convert(Image.FORMAT_RGBA8)
	for y in 256:
		for x in 256:
			var d := Vector2(float(x) - 127.5, float(y) - 127.5).length()
			var px := img.get_pixel(x, y)
			px.a = clampf(127.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, px)
	img.save_png(AVATAR_PATH)
	_avatar_tex = null
	_set_avatar("foto")


## Botón de la barra con la insignia: lleva a «Mi nivel y mi plan».
func _sync_level_badge() -> void:
	if level_slot == null or not is_instance_valid(level_slot):
		return
	var show := _has_player() and mode != "test"
	level_slot.visible = show
	if not show:
		return
	var r := float(player["rating"]["r"])
	var key := "%d:%d:%s:%s:%s" % [Assessment.level_of(r), int(_level_progress(r) * 40.0), str(dark), avatar, _badge_elo()]
	if str(level_slot.get_meta("key", "")) == key:
		return
	level_slot.set_meta("key", key)
	for child in level_slot.get_children():
		child.queue_free()
	var badge := _level_badge(r, 112.0, _badge_elo())
	badge.set_anchors_preset(Control.PRESET_FULL_RECT)
	level_slot.add_child(badge)


# ---------------------------------------------------------------- enhorabuenas

const CHEERS := ["¡Sigue así!", "¡Vas mejorando!", "¡Muy bien pensado!", "¡Así se juega!", "¡Otro más!", "¡Qué buena vista!"]
const STREAK_CHEERS := ["¡Estás en racha!", "¡Imparable!", "¡Qué racha!"]
const LEVEL_CHEERS := ["Cada problema te hace más fuerte. ¡A por el siguiente nivel!", "Tu esfuerzo se nota. ¡Sigue jugando!", "Ya ves más que antes. ¡Vamos a por más!"]


## Sube la puntuación: un aviso con los puntos ganados y un poco de confeti; si además sube el nivel, una
## enhorabuena a pantalla completa con un botón para seguir.
func _celebrate(before: float, now: float) -> void:
	var lv0 := Assessment.level_of(before)
	var lv1 := Assessment.level_of(now)
	var gained := int(round(now - before))
	if lv1 > lv0:
		_level_up(lv1, before, now)
		return
	if _celebration != null and is_instance_valid(_celebration):
		_celebration.queue_free()
	var toast := Control.new()
	toast.set_anchors_preset(Control.PRESET_FULL_RECT)
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast)
	_celebration = toast
	var pill := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	var tint := _tint("mint")
	sb.bg_color = tint[0]
	sb.set_corner_radius_all(60)
	sb.shadow_color = _c("shadow")
	sb.shadow_size = 24
	sb.shadow_offset = Vector2(0.0, 10.0)
	sb.content_margin_left = 44
	sb.content_margin_right = 44
	sb.content_margin_top = 22
	sb.content_margin_bottom = 22
	pill.add_theme_stylebox_override("panel", sb)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(row)
	var star := TextureRect.new()
	star.texture = UiIcons.kids_texture("spark")
	star.custom_minimum_size = Vector2(76.0, 76.0)
	star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	star.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(star)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 0)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cheer := str(STREAK_CHEERS[_rng.randi() % STREAK_CHEERS.size()]) if _streak >= 3 else str(CHEERS[_rng.randi() % CHEERS.size()])
	words.add_child(_line(cheer, F_HEAD + 4, _c("ink"), font_display))
	var sub := Loc.f("+%d puntos · ahora %d", [gained, int(round(now))])
	if _streak >= 3:
		sub += Loc.f(" · %d seguidos", _streak)
	words.add_child(_line(sub, F_SUB, tint[1], font_semibold))
	row.add_child(words)
	toast.add_child(pill)
	var place := func() -> void:
		if not is_instance_valid(pill):
			return
		pill.reset_size()
		var w := pill.get_combined_minimum_size().x
		var top := board_slot.get_global_rect().position.y + 20.0 if board_slot != null else 300.0
		pill.position = Vector2((size.x - w) * 0.5, top)
	place.call_deferred()
	var bits := Confetti.new()
	bits.set_anchors_preset(Control.PRESET_FULL_RECT)
	bits.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.add_child(bits)
	var origin := Vector2(size.x * 0.5, (board_slot.get_global_rect().position.y if board_slot != null else 300.0) + 80.0)
	bits.burst(origin, 46, _confetti_colors(), 1500.0)
	pill.pivot_offset = Vector2(240.0, 60.0)
	pill.scale = Vector2(0.6, 0.6)
	pill.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(pill, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(pill, "modulate:a", 1.0, 0.2)
	tw.chain().tween_interval(2.2)
	tw.chain().tween_property(pill, "modulate:a", 0.0, 0.4)
	tw.chain().tween_callback(toast.queue_free)


## Enhorabuena por subir de nivel: pantalla con trofeo, confeti, el nivel nuevo y ánimo para seguir.
func _level_up(level_now: int, before: float, now: float) -> void:
	if _celebration != null and is_instance_valid(_celebration):
		_celebration.queue_free()
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(layer)
	_celebration = layer
	var scrim := ColorRect.new()
	scrim.color = Color(_c("bg").r, _c("bg").g, _c("bg").b, 0.82)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(scrim)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 18)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(column)
	var trophy := TextureRect.new()
	trophy.texture = UiIcons.kids_texture("trophy")
	trophy.custom_minimum_size = Vector2(300.0, 300.0)
	trophy.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	trophy.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	trophy.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	trophy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trophy.pivot_offset = Vector2(150.0, 150.0)
	column.add_child(trophy)
	column.add_child(_centered(_para("¡Enhorabuena!", F_LARGE, _c("ink"), font_display)))
	column.add_child(_centered(_para((Loc.t("Has subido al nivel %d") if kids else Loc.t("Nivel %d de táctica")) % level_now, F_TITLE + 6, _tint("lilac")[1], font_display)))
	var badge := _level_badge(now, 170.0)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(badge)
	column.add_child(_centered(_para(Loc.f("Rango: %s", str(_rank(level_now)[1])), F_SUB, _c("quiet"), font_semibold)))
	column.add_child(_centered(_para(Loc.f("%d → %d puntos", [int(round(before)), int(round(now))]), F_SUB, _c("quiet"), font_medium)))
	column.add_child(_spacer(10.0))
	var pad := _pad(80, 0, 80, 0)
	pad.add_child(_centered(_para(str(LEVEL_CHEERS[_rng.randi() % LEVEL_CHEERS.size()]), F_HEAD, _c("ink"), font_medium)))
	column.add_child(pad)
	column.add_child(_spacer(26.0))
	var go_pad := _pad(90, 0, 90, 0)
	var go := _button("next", "¡Seguir jugando!", _close_celebration, _c("accent"), _c("accent_ink"), {"font_size": F_HEAD, "height": 148.0, "icon": 60.0, "trailing": true, "glow": _c("glow")})
	go.mouse_filter = Control.MOUSE_FILTER_STOP
	go_pad.add_child(go)
	column.add_child(go_pad)
	var bits := Confetti.new()
	bits.set_anchors_preset(Control.PRESET_FULL_RECT)
	bits.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bits.duration = 3.6
	layer.add_child(bits)
	bits.burst(Vector2(size.x * 0.25, size.y * 0.42), 70, _confetti_colors(), 2100.0)
	bits.burst(Vector2(size.x * 0.75, size.y * 0.42), 70, _confetti_colors(), 2100.0)
	_sfx("leccion")
	layer.modulate.a = 0.0
	trophy.scale = Vector2(0.3, 0.3)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(layer, "modulate:a", 1.0, 0.25)
	tw.tween_property(trophy, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _close_celebration() -> void:
	if _celebration != null and is_instance_valid(_celebration):
		var layer := _celebration
		_celebration = null
		var tw := create_tween()
		tw.tween_property(layer, "modulate:a", 0.0, 0.2)
		tw.tween_callback(layer.queue_free)


func _confetti_colors() -> Array:
	var out: Array = []
	for t: String in ["peach", "mint", "sky", "butter", "rose", "lilac"]:
		out.append(_tint(t)[1])
	out.append(_c("accent"))
	return out


# ---------------------------------------------------------------- análisis educativo de la partida

## Abre el análisis: se calcula en otro hilo la primera vez (puede tardar unos segundos en el móvil).
func _open_review() -> void:
	detail_from_over = false
	if review_done:
		if review.is_empty():
			_show_review_page()
		else:
			_review_show(maxi(review_at, 0))
		return
	var page := _page("review")
	var body: VBoxContainer = page["body"]
	body.add_child(_spacer(8.0, true))
	_wait_anim = _wait_animation(false)
	body.add_child(_wait_anim)
	body.add_child(_spacer(56.0))
	body.add_child(_centered(_para("Analizando la partida…", F_TITLE, _c("ink"), font_display)))
	body.add_child(_spacer(8.0, true))
	_stop_game_thread()
	_review_thread = Thread.new()
	var my_run := run_id
	_review_thread.start(_review_work.bind(game_history.duplicate(), game_moves.duplicate(), game_color, my_run))


func _review_work(fens: Array, moves: Array, color: int, my_run: int) -> void:
	var found := GameReview.analyze(fens, moves, color)
	_review_ready.call_deferred(found, my_run)


func _review_ready(found: Array, my_run: int) -> void:
	if _review_thread != null:
		_review_thread.wait_to_finish()
		_review_thread = null
	if my_run != run_id or mode != "game":
		return
	review = found
	review_done = true
	_save_game_summary()
	if progress_kind == "review":
		# Directo al tablero, con el primer momento; la lista queda a un toque («Lista»).
		if review.is_empty():
			_show_review_page()
		else:
			_review_show(0)


## Lista de los momentos, cada uno con «Ver» y, si lo hay, con qué practicar.
func _show_review_page() -> void:
	var page := _page("review")
	var body: VBoxContainer = page["body"]
	var footer: VBoxContainer = page["footer"]
	var tile := _icon_tile("why", "lilac", 156.0, 98.0)
	tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(tile)
	body.add_child(_spacer(20.0))
	body.add_child(_centered(_para("Análisis de la partida", F_TITLE + 8, _c("ink"), font_display)))
	body.add_child(_centered(_para(game_result, F_SUB, _c("quiet"), font_medium)))
	body.add_child(_spacer(26.0))
	if review.is_empty():
		var none := _kid_line("reviewNone") if kids else "No has dejado piezas a tiro, no se te ha escapado ningún mate en una y no has permitido ninguno. En la apertura, tampoco has repetido piezas ni has movido el rey sin enrocar."
		body.add_child(_para(none, F_BODY, _c("ink"), font_regular))
		_say([_kid_line("reviewNone")])
	else:
		var intro := _kid_line("reviewIntro") if kids else (Loc.t("1 momento para aprender. Toca «Ver» para ir a esa posición.") if review.size() == 1 else Loc.f("%d momentos para aprender. Toca «Ver» para ir a esa posición.", review.size()))
		body.add_child(_para(intro, F_BODY, _c("ink"), font_regular))
		_say([_kid_line("reviewIntro")])
		body.add_child(_spacer(20.0))
		var tints := {"allowed_mate": "rose", "missed_mate": "peach", "hang": "butter", "missed_capture": "mint", "king": "sky", "repeat": "lilac"}
		for i in review.size():
			var mo: Dictionary = review[i]
			var kind := str(mo["kind"])
			var panel_rows := _panel()
			var rows: VBoxContainer = panel_rows[1]
			var move_no := int(mo["ply"]) / 2 + 1
			rows.add_child(_icon_row("target" if kind in ["hang", "missed_capture"] else ("flag" if kind.ends_with("mate") else "piece_king"), str(tints.get(kind, "sky")), GameReview.title_of(kind), Loc.f("Jugada %d", move_no), 96.0))
			rows.add_child(_para(_kid_line(GameReview.kids_key(kind)) if kids else str(mo["text"]), F_BODY, _c("ink"), font_regular))
			var buttons := HBoxContainer.new()
			buttons.add_theme_constant_override("separation", 14)
			var see := _button("eye", "Ver", _review_show.bind(i), _c("accent"), _c("accent_ink"), {"font_size": F_SUB, "height": 104.0, "icon": 48.0})
			see.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			see.mouse_filter = Control.MOUSE_FILTER_STOP
			buttons.add_child(see)
			if str(mo["lesson"]) != "":
				var learn := _button("book", "Lección", _review_lesson.bind(str(mo["lesson"])), _c("field"), _c("ink"), {"font_size": F_SUB, "height": 104.0, "icon": 48.0})
				learn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				learn.mouse_filter = Control.MOUSE_FILTER_STOP
				buttons.add_child(learn)
			if not kids and not (mo["themes"] as Array).is_empty() and not _practice_for(mo["themes"]).is_empty():
				var drill := _button("target", "Problemas", _review_practice.bind(mo["themes"]), _c("field"), _c("ink"), {"font_size": F_SUB, "height": 104.0, "icon": 48.0})
				drill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				drill.mouse_filter = Control.MOUSE_FILTER_STOP
				buttons.add_child(drill)
			rows.add_child(buttons)
			body.add_child(panel_rows[0])
			body.add_child(_spacer(20.0))
	if not kids and game_moves.size() >= 2:
		body.add_child(_spacer(10.0))
		if detail_done and not detail.is_empty():
			var c := GameDetail.counts(detail)
			var parts: Array = []
			for v: String in ["best", "excellent", "good", "only", "inaccuracy", "mistake", "blunder"]:
				if int(c.get(v, 0)) > 0:
					parts.append("%s: %d" % [str(GameDetail.LABELS[v]), int(c[v])])
			body.add_child(_para(Loc.t("Tus jugadas") + " · " + " · ".join(parts), F_SUB, _c("quiet"), font_medium))
			body.add_child(_spacer(10.0))
		body.add_child(_option_button("line", "lilac", "Ver el detalle", "Jugada a jugada: qué hiciste bien, qué no y cuál era la mejor.", _open_detail, true))
	body.add_child(_spacer(10.0, true))
	if not kids:
		footer.add_child(_para("Solo se señala lo que se puede comprobar con seguridad: piezas que quedan a tiro, capturas gratis y mates en una jugada. Otras ideas de la partida (planes, estructura) no se analizan todavía.", F_FOOT + 2, _c("quiet"), font_regular))
		footer.add_child(_spacer(10.0))
	footer.add_child(_button("back", "Volver a la partida", _close_progress, _c("field"), _c("ink"), {"font_size": F_SUB, "height": 96.0, "icon": 44.0, "font": font_medium}))
	if use_settings:
		footer.add_child(_button("home", "Inicio", _go_home, _c("field"), _c("ink"), {"font_size": F_SUB, "height": 92.0, "icon": 44.0, "font": font_medium}))


## Lleva el tablero a la posición del momento i, con la jugada hecha (roja) y la otra (verde).
## «Siguiente» en el repaso: antes de enseñar el momento siguiente, se ven en el tablero las jugadas de la partida
## que hubo entre uno y otro, con su movimiento (más deprisa si son muchas).
func _review_advance() -> void:
	var i := review_at + 1
	if i < 0 or i >= review.size():
		return
	var from_ply := int((review[review_at] as Dictionary).get("ply", -1)) if review_at >= 0 else -1
	var to_ply := int((review[i] as Dictionary).get("ply", -1))
	if from_ply < 0 or to_ply <= from_ply or to_ply > game_moves.size() or from_ply >= game_history.size():
		_review_show(i)
		return
	run_id += 1
	var my_run := run_id
	view.interactive = false
	view.board.deselect()
	view.board.set_arrows([])
	view.set_fen(str(game_history[from_ply]))
	view.set_orientation(game_color)
	var pause := clampf(4.0 / float(to_ply - from_ply), 0.16, 0.5)
	for ply in range(from_ply, to_ply):
		view.show_move(str(game_moves[ply]))
		await _wait(pause)
		if my_run != run_id or game_state != "review":
			return
	_review_show(i)


func _review_show(i: int) -> void:
	if i < 0 or i >= review.size():
		return
	_close_progress()
	run_id += 1
	review_at = i
	game_state = "review"
	var mo: Dictionary = review[i]
	view.interactive = false
	view.set_fen(str(mo["fen"]))
	view.set_orientation(game_color)
	view.board.set_arrows(mo.get("arrows", []))
	# Valoración de la jugada, en su casilla de destino: «??» si permitió mate o dejó una pieza, «?» si dejó pasar
	# un mate, «?!» en lo demás.
	var at_ply := int(mo.get("ply", -1))
	if at_ply >= 0 and at_ply < game_moves.size():
		var how := str(mo.get("kind", ""))
		_move_badge(str(game_moves[at_ply]), "blunder" if how == "allowed_mate" or how == "hang" else ("wrong" if how == "missed_mate" else "dubious"))
	if int(mo.get("square", -1)) >= 0:
		view.board.select(int(mo["square"]))
	_say([_kid_line(GameReview.kids_key(str(mo["kind"])))])
	_refresh()


func _build_review_card() -> void:
	var mo: Dictionary = review[review_at] if review_at >= 0 and review_at < review.size() else {}
	title = _para(GameReview.title_of(str(mo.get("kind", ""))), F_TITLE, _c("ink"), font_display)
	card_body.add_child(title)
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 12)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chips.add_child(_chip(Loc.f("Jugada %d", (int(mo.get("ply", 0)) / 2 + 1)), _c("field"), _c("ink")))
	chips.add_child(_chip(Loc.f("%d de %d", [review_at + 1, review.size()]), _c("field"), _c("quiet")))
	card_body.add_child(chips)
	card_body.add_child(_para(_kid_line(GameReview.kids_key(str(mo.get("kind", "")))) if kids else str(mo.get("text", "")), F_BODY, _c("ink"), font_regular))
	if not kids:
		var legend := "Flecha roja: tu jugada."
		if str(mo.get("better", "")) != "":
			legend += " Verde: la otra."
		if str(mo.get("kind", "")) == "hang":
			legend += " Violeta: quién podía capturar."
		elif str(mo.get("kind", "")) == "allowed_mate":
			legend += " Violeta: el mate del rival."
		card_body.add_child(_para(legend, F_FOOT + 2, _c("quiet"), font_regular))


func _build_review_actions() -> void:
	var key := "review:%d" % review_at
	if key == _actions_mode:
		return
	_actions_mode = key
	for old in actions.get_children():
		(old as CanvasItem).visible = false
		old.queue_free()
	hint_button = null
	step_button = null
	left_button = _tool_button("back", "Anterior", _review_show.bind(review_at - 1), "sky")
	# «Volver», a la pantalla desde la que se abrió el análisis (el final de la partida; si es una guardada, con
	# «Mis partidas» a mano). Pablo, 17-11: antes solo se podía salir al inicio o a la lista.
	var leave := _tool_button("close", "Volver", _review_leave, "peach")
	var list := _tool_button("why", "Lista", _review_back, "lilac")
	right_button = _tool_button("next", "Siguiente", _review_advance, "mint")
	left_button.disabled = review_at <= 0
	left_button.modulate.a = 1.0 if review_at > 0 else 0.42
	right_button.disabled = review_at >= review.size() - 1
	right_button.modulate.a = 1.0 if review_at < review.size() - 1 else 0.42
	var bar: Array[Button] = [left_button, leave, list]
	if not kids:
		# El análisis jugada a jugada, a la vista también aquí (Pablo, 17-11: al abrir una partida de «Mis partidas»
		# se entra directo en este resumen y el jugada a jugada quedaba escondido tras «Volver» o «Lista»).
		bar.append(_tool_button("line", "Jugada a jugada", _review_to_detail, "sky"))
	bar.append(right_button)
	for b: Button in bar:
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(b)


## Del resumen del análisis al jugada a jugada; su «Volver» lleva al final de la partida.
func _review_to_detail() -> void:
	_review_leave()
	_open_detail_from_over()


## Del análisis en el tablero al final de la partida, como estaba antes de abrirlo.
func _review_leave() -> void:
	run_id += 1
	view.board.set_arrows([])
	view.board.set_badge(-1, "")
	view.board.select(-1)
	view.set_fen(str(game_history[game_history.size() - 1]))
	game_state = "over"
	review_at = -1
	_close_progress()
	_actions_mode = ""
	_refresh()


## Del tablero a la lista de momentos; la partida se queda como acabó.
func _review_back() -> void:
	view.board.set_arrows([])
	view.set_fen(str(game_history[game_history.size() - 1]))
	game_state = "over"
	review_at = -1
	_refresh()
	_show_review_page()


## «Ver el detalle»: calcula (una vez, en otro hilo) la valoración de cada jugada propia y la enseña en el tablero.
func _open_detail() -> void:
	if detail_done:
		if not detail.is_empty():
			_detail_show(0)
		return
	var page := _page("review")
	var body: VBoxContainer = page["body"]
	body.add_child(_spacer(8.0, true))
	# El caballo y, debajo, una barra con lo que va.
	_wait_anim = _wait_animation(true)
	_wait_anim.progress = 0.0
	body.add_child(_wait_anim)
	body.add_child(_spacer(56.0))
	body.add_child(_centered(_para("Analizando jugada a jugada…", F_TITLE, _c("ink"), font_display)))
	_detail_progress = _centered(_para("", F_BODY, _c("quiet"), font_medium))
	body.add_child(_detail_progress)
	body.add_child(_spacer(8.0, true))
	_stop_game_thread()
	var my_run := run_id
	if str(game.get("variant", "")) == "" and local_engine.available():
		_detail_with_sf(game_history.duplicate(), game_moves.duplicate(), game_color, my_run)
		return
	_review_thread = Thread.new()
	_review_thread.start(_detail_work.bind(game_history.duplicate(), game_moves.duplicate(), game_color, my_run))


## Análisis jugada a jugada con Stockfish del móvil: cada posición de la partida se analiza una vez (la de después
## de tu jugada es la de antes de la del rival). Los textos salen igual que con el motor de la app (GameDetail).
func _detail_with_sf(fens: Array, moves: Array, color: int, my_run: int) -> void:
	var mine: Array = []
	for i in moves.size():
		if i < fens.size() and Chess.from_fen(str(fens[i])).turn == color:
			mine.append(i)
	var seen := {}
	var found: Array = []
	var done := 0
	for i: int in mine:
		var pos := Chess.from_fen(str(fens[i]))
		var m := pos.find_uci(str(moves[i]))
		done += 1
		_detail_tick(done, mine.size())
		if m < 0:
			continue
		var after_fen := str(fens[i + 1]) if i + 1 < fens.size() else pos.after(m).fen()
		var pair: Array = []
		for f: String in [pos.fen(), after_fen]:
			if not seen.has(f):
				seen[f] = await local_engine.analyze(f, DETAIL_MS) if not Chess.from_fen(f).legal_moves().is_empty() else {}
				if my_run != run_id or mode != "game":
					return
			pair.append(seen[f])
		var pre := GameDetail.pre_from_engine(pos, m, pair[0], pair[1], coach.player_elo)
		found.append(GameDetail.entry(null, pos, m, color, i, 0.6, pre))
	_detail_ready(found, my_run)


## Tiempo de Stockfish por posición en el análisis (unos 40 posiciones en una partida de 40 jugadas: ~20 s).
const DETAIL_MS := 500


func _detail_work(fens: Array, moves: Array, color: int, my_run: int) -> void:
	var found := GameDetail.analyze(fens, moves, color, 0.6, func(done: int, total: int) -> void: _detail_tick.call_deferred(done, total))
	_detail_ready.call_deferred(found, my_run)


func _detail_tick(done: int, total: int) -> void:
	if _detail_progress != null and is_instance_valid(_detail_progress):
		_detail_progress.text = Loc.f("Jugada %d de %d", [done, total])
	if _wait_anim != null and is_instance_valid(_wait_anim):
		_wait_anim.progress = float(done) / float(maxi(total, 1))


## La animación de espera: el caballo del logo (un vídeo por espera, en ciclo); quieta con las animaciones apagadas.
func _wait_animation(with_bar: bool) -> KnightWait:
	var k := KnightWait.new()
	k.mark = _c("accent")
	k.track = _c("track")
	k.still = view != null and view.board.anim_mode == Board3D.Anim.NONE
	k.set_side(minf(760.0, size.x * 0.7) if size.x > 0.0 else 740.0, with_bar)
	# Uno por espera, en ciclo: esta vez este, la próxima el siguiente.
	k.clip = wait_clip
	wait_clip = KnightWait.next_clip(wait_clip)
	_save_settings()
	return k


func _detail_ready(found: Array, my_run: int) -> void:
	if _review_thread != null:
		_review_thread.wait_to_finish()
		_review_thread = null
	if my_run != run_id or mode != "game":
		return
	detail = found
	detail_done = true
	if detail.is_empty():
		_show_review_page()
	else:
		_detail_show(0)


const DETAIL_TONES := {"only": "info", "best": "good", "excellent": "good", "good": "good", "inaccuracy": "mid", "mistake": "bad", "blunder": "bad"}


## Una jugada del análisis, con movimiento: si venimos de la anterior, primero se juega la respuesta del rival;
## después, tu jugada, y al caer la pieza aparecen su chapa (buena, la mejor, imprecisión…) y las flechas.
func _detail_show(i: int) -> void:
	if i < 0 or i >= detail.size():
		return
	_close_progress()
	run_id += 1
	var my_run := run_id
	var prev := detail_at
	detail_at = i
	game_state = "detail"
	detail_line = []
	detail_line_san = []
	detail_line_ply = -1
	var e: Dictionary = detail[i]
	view.interactive = false
	view.set_orientation(game_color)
	view.board.set_arrows([])
	view.board.set_badge(-1, "")
	var ply := int(e.get("ply", -1))
	var replies: Array = []
	if prev >= 0 and prev == i - 1 and ply > 0:
		var pply := int((detail[prev] as Dictionary).get("ply", -1))
		# ¿Está el tablero justo después de tu jugada anterior? Entonces se siguen jugando las de en medio.
		if pply >= 0 and pply + 1 < game_history.size() and view.board.chess.fen() == str(game_history[pply + 1]):
			for k in range(pply + 1, ply):
				replies.append(str(game_moves[k]))
	if replies.is_empty():
		view.set_fen(str(e["fen"]))
	_refresh()
	var still := func() -> bool:
		return my_run == run_id and game_state == "detail" and detail_at == i
	for u: String in replies:
		await _wait(0.3)
		if not still.call():
			return
		view.show_move(u)
		await _wait(0.45)
		if not still.call():
			return
	await _wait(0.35)
	if not still.call():
		return
	view.show_move(str(e["uci"]))
	await _wait(0.5)
	if not still.call():
		return
	view.board.set_arrows(e.get("arrows", []))
	_move_badge(str(e["uci"]), str(e.get("badge", "")))


func _build_detail_card() -> void:
	var e: Dictionary = detail[detail_at] if detail_at >= 0 and detail_at < detail.size() else {}
	var tone := str(DETAIL_TONES.get(str(e.get("verdict", "")), "info"))
	var color := _c("good") if tone == "good" else (_c("bad") if tone == "bad" else (_c("accent_text") if tone == "mid" else (Color("a593ff") if dark else Color("5b3fd0"))))
	title = _para("%s · %s" % [str(e.get("san", "")), str(e.get("label", ""))], F_TITLE2, color, font_display)
	card_body.add_child(title)
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 12)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chips.add_child(_chip(Loc.f("Jugada %d", int(e.get("n", 0))), _c("field"), _c("ink")))
	chips.add_child(_chip(Loc.f("%d de %d", [detail_at + 1, detail.size()]), _c("field"), _c("quiet")))
	card_body.add_child(chips)
	if not detail_line.is_empty():
		_add_detail_line(e)
		return
	for t: Variant in e.get("paras", []):
		var text := str(t)
		card_body.add_child(_para(text, F_BODY, _c("ink"), font_regular))
		if (text.begins_with("La mejor era") or text.begins_with("También estaba")) and e.has("best_uci"):
			# Debajo, un botón: la mejor jugada en el tablero y cómo seguiría la partida.
			var tint := _tint("mint")
			var see := _card_button("Ver la mejor y cómo seguiría", _detail_line_open, tint[0], tint[1], F_SUB, "play")
			see.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			card_body.add_child(see)
	var bad := str(e.get("verdict", "")) in ["inaccuracy", "mistake", "blunder"]
	if bad:
		card_body.add_child(_para("Flecha roja: tu jugada. Violeta: la respuesta del rival. Verde: la mejor.", F_FOOT + 2, _c("quiet"), font_regular))


## «La mejor era…»: la mejor jugada y cómo seguiría la partida (el motor de la app, sin errores adrede, unas
## pocas jugadas), para verla paso a paso en el tablero.
var detail_line: Array = []
var detail_line_san: Array = []
var detail_line_fen := ""
var detail_line_ply := -1


func _detail_line_open() -> void:
	if detail_at < 0 or detail_at >= detail.size():
		return
	var e: Dictionary = detail[detail_at]
	var pos := Chess.from_fen(str(e.get("fen", "")))
	var m := pos.find_uci(str(e.get("best_uci", "")))
	if m < 0:
		return
	run_id += 1
	detail_line = [Chess.uci(m)]
	detail_line_san = [SanEs.san(pos, m)]
	detail_line_fen = pos.fen()
	var p := pos.after(m)
	var bot := Bot.new(4)
	bot.exact = true
	bot.time_cap = 0.2
	for k in 5:
		if p.legal_moves().is_empty():
			break
		var r := bot.choose(p)
		if r < 0:
			break
		detail_line.append(Chess.uci(r))
		detail_line_san.append(SanEs.san(p, r))
		p.apply(r)
	view.board.set_arrows([])
	view.board.set_badge(-1, "")
	_actions_mode = ""
	_detail_line_step(0)


func _detail_line_step(ply: int) -> void:
	if detail_line.is_empty():
		return
	detail_line_ply = clampi(ply, -1, detail_line.size() - 1)
	var pos := Chess.from_fen(detail_line_fen)
	for k in maxi(detail_line_ply, 0):
		pos.apply(pos.find_uci(str(detail_line[k])))
	view.set_fen(pos.fen())
	if detail_line_ply >= 0:
		view.show_move(str(detail_line[detail_line_ply]))
	_keep_scroll = true
	_refresh()


func _detail_line_close() -> void:
	detail_line = []
	detail_line_san = []
	detail_line_ply = -1
	_actions_mode = ""
	var i := detail_at
	detail_at = -1
	_detail_show(i)


## La variante en la tarjeta: las jugadas (la que se ve, resaltada) y sus botones.
func _add_detail_line(e: Dictionary) -> void:
	var pos := Chess.from_fen(detail_line_fen)
	var n := pos.full
	var parts: Array = []
	for k in detail_line_san.size():
		var side := pos.turn if k % 2 == 0 else 1 - pos.turn
		var num := ""
		if side == 0:
			num = "%d. " % (n + (k + (1 if pos.turn == 1 else 0)) / 2)
		elif k == 0:
			num = "%d… " % n
		var san := str(detail_line_san[k])
		parts.append(num + ("[%s]" % san if k == detail_line_ply else san))
	card_body.add_child(_para(Loc.f("La mejor era %s. Así podía seguir la partida:", str(detail_line_san[0])), F_SUB, _c("good"), font_semibold))
	card_body.add_child(_para(" ".join(parts), F_BODY, _c("ink"), font_medium))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	for def: Array in [["first", -1], ["prev", detail_line_ply - 1], ["play", detail_line_ply + 1]]:
		var b := _round_button("play" if str(def[0]) == "prev" else str(def[0]), _detail_line_step.bind(int(def[1])), 96.0, _c("field"), _c("ink"), false)
		if str(def[0]) == "prev":
			for child in b.get_child(0).get_children():
				if child is TextureRect:
					(child as TextureRect).flip_h = true
		row.add_child(b)
	var mark := _text("inicio" if detail_line_ply < 0 else Loc.f("%d de %d", [detail_line_ply + 1, detail_line.size()]), F_FOOT, _c("quiet"), font_medium)
	mark.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(mark)
	row.add_child(_button("back", "Volver", _detail_line_close, _c("accent_soft"), _c("accent_text"), {"font_size": F_SUB, "height": 96.0, "icon": 44.0}))
	card_body.add_child(row)
	card_body.add_child(_para("Jugadas del motor de la app: una idea de cómo seguiría, no la única.", F_FOOT, _c("quiet"), font_regular))


## Siguiente jugada con imprecisión o error (−1 si no hay más).
func _next_detail_fault() -> int:
	for i in range(detail_at + 1, detail.size()):
		if str((detail[i] as Dictionary).get("verdict", "")) in ["inaccuracy", "mistake", "blunder"]:
			return i
	return -1


func _build_detail_actions() -> void:
	var key := "detail:%d" % detail_at
	if key == _actions_mode:
		return
	_actions_mode = key
	for old in actions.get_children():
		(old as CanvasItem).visible = false
		old.queue_free()
	hint_button = null
	step_button = null
	left_button = _tool_button("back", "Anterior", _detail_show.bind(detail_at - 1), "sky")
	var summary := _tool_button("close" if detail_from_over else "why", "Volver" if detail_from_over else "Resumen", _detail_back, "lilac")
	right_button = _tool_button("next", "Siguiente", _detail_show.bind(detail_at + 1), "mint")
	var fault := _next_detail_fault()
	var jump := _tool_button("wrong", "Sig. fallo", _detail_show.bind(fault), "rose")
	left_button.disabled = detail_at <= 0
	left_button.modulate.a = 1.0 if detail_at > 0 else 0.42
	right_button.disabled = detail_at >= detail.size() - 1
	right_button.modulate.a = 1.0 if detail_at < detail.size() - 1 else 0.42
	jump.disabled = fault < 0
	jump.modulate.a = 1.0 if fault >= 0 else 0.42
	for b: Button in [left_button, summary, jump, right_button]:
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(b)


## Del detalle al resumen; la partida se queda como acabó.
## «Jugada a jugada» desde el final de la partida (sin pasar por el resumen): al volver, se vuelve al final.
var detail_from_over := false


func _open_detail_from_over() -> void:
	detail_from_over = true
	_open_detail()


func _detail_back() -> void:
	if detail_from_over:
		detail_from_over = false
		run_id += 1
		view.board.set_arrows([])
		view.board.set_badge(-1, "")
		view.set_fen(str(game_history[game_history.size() - 1]))
		game_state = "over"
		detail_at = -1
		_close_progress()
		_actions_mode = ""
		_refresh()
		return
	run_id += 1
	view.board.set_arrows([])
	view.board.set_badge(-1, "")
	view.set_fen(str(game_history[game_history.size() - 1]))
	game_state = "over"
	detail_at = -1
	_refresh()
	_show_review_page()


func _review_lesson(id: String) -> void:
	_stop_game_thread()
	game_state = ""
	view.set_orientation(0)
	view.board.set_arrows([])
	_start_lesson(id)


## Problemas de esos temas cerca del nivel del jugador (hasta 5): índices en `puzzles`. Primero los que no ha visto,
## después los que falló y aún no ha resuelto y, solo si no queda otra, los ya resueltos. Antes salían siempre los
## mismos cinco (los más cercanos a su nivel): tras cada partida con un mate fallado se repetían los mismos mates del
## pasillo (un usuario, 17-11). Un poco de azar en la distancia para que no salgan siempre en el mismo orden.
func _practice_for(themes: Array) -> Array:
	var target := float(player["rating"]["r"]) - 150.0 if _has_player() else 800.0
	var last := {}
	if _has_player():
		for t: Dictionary in player["tries"]:
			last[str(t["id"])] = bool(t["correct"]) or bool(last.get(str(t["id"]), false))
	var found: Array = []
	for i in puzzles.size():
		if themes.has(str(puzzles[i].get("theme", ""))):
			var id := str(puzzles[i].get("id", ""))
			var tier := 0 if not last.has(id) else (2 if bool(last[id]) else 1)
			found.append([tier, absf(float(puzzles[i].get("rating", 0)) - target) + _rng.randf() * 80.0, i])
	found.sort_custom(func(a: Array, b: Array) -> bool: return [a[0], a[1]] < [b[0], b[1]])
	return found.slice(0, 5).map(func(x: Array) -> int: return int(x[2]))


func _review_practice(themes: Array) -> void:
	_stop_game_thread()
	game_state = ""
	view.set_orientation(0)
	view.board.set_arrows([])
	practice_queue = _practice_for(themes)
	_close_progress()
	if _has_player():
		_start_training()
	elif not practice_queue.is_empty():
		mode = "free"
		_start(int(practice_queue.pop_front()))


## Guarda un resumen de cada partida analizada (para el progreso y para elegir lecciones más adelante).
func _save_game_summary() -> void:
	if not use_settings:
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(GAMES_PATH)) if FileAccess.file_exists(GAMES_PATH) else null
	var games: Array = data.get("games", []) if typeof(data) == TYPE_DICTIONARY else []
	games.append({"date": Time.get_datetime_string_from_system(), "level": int(game.get("level", 0)), "won": game_won, "moves": game_moves.size(), "kinds": review.map(func(x: Dictionary) -> String: return str(x["kind"]))})
	var file := FileAccess.open(GAMES_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"version": 1, "games": games.slice(-200)}))
		file.close()


# ---------------------------------------------------------------- nivel Kids: textos sencillos y voz

## Texto de la lección para quien juega: el del nivel Kids si lo hay.
func _lesson_text(field: String) -> Variant:
	if kids:
		var k: Dictionary = lesson.get("kids", {})
		if k.has(field):
			return k[field]
	return lesson.get(field, "")


func _lesson_title(l: Dictionary) -> String:
	return str((l.get("kids", {}) as Dictionary).get("title", l["title"])) if kids else str(l["title"])


func _lesson_line(l: Dictionary) -> String:
	return str((l.get("kids", {}) as Dictionary).get("takeaway", l["takeaway"])) if kids else str(l["takeaway"])


func _ex_text(e: Dictionary) -> String:
	if e.has("parts"):
		return Cine.info_text(e)
	return str(e.get("kids", e.get("text", ""))) if kids else str(e.get("text", ""))


func _kid_line(key: String) -> String:
	return str(kids_lines.get(key, ""))



## Efecto de la interfaz: "acierto" (cada jugada buena), "error" (jugada mala) y "leccion" (lección o problema
## terminados, partida ganada). Con el sonido quitado, nada.
func _sfx(kind: String) -> void:
	if not sound_on or sfx_player == null:
		return
	if not _sfx_cache.has(kind):
		var path := "res://sounds/ui/%s.ogg" % kind
		_sfx_cache[kind] = load(path) if ResourceLoader.exists(path) else null
	var stream: AudioStream = _sfx_cache[kind]
	if stream == null:
		return
	sfx_player.stream = stream
	sfx_player.play()


## Música de fondo del nivel Kids: suena en bucle mientras se esté en Kids, con la música y el sonido puestos.
func _sync_music() -> void:
	if music_player == null:
		return
	var want := kids and music_on and sound_on and use_settings
	if want and not music_player.playing:
		if music_player.stream == null and ResourceLoader.exists("res://sounds/ui/musica_kids.ogg"):
			var stream := load("res://sounds/ui/musica_kids.ogg") as AudioStreamOggVorbis
			if stream != null:
				stream = stream.duplicate()
				stream.loop = true
				music_player.stream = stream
		if music_player.stream != null:
			music_player.volume_db = MUSIC_DB
			music_player.play()
	elif not want and music_player.playing:
		music_player.stop()


func _set_music(on: bool) -> void:
	music_on = on
	_save_settings()
	_sync_music()
	_sync_sheet()


## Dice las frases en voz alta, una detrás de otra (solo en el nivel Kids y con la voz puesta). Corta lo que
## estuviera sonando. Una frase sin audio se salta: la voz no es imprescindible para seguir.
func _say(lines: Array) -> void:
	_voice_last = lines.duplicate()
	if not kids or not voice_on or voice_player == null:
		return
	_voice_queue = []
	for t: Variant in lines:
		if str(t) == BRAVO:
			# El «¡Muy bien!» grabado por una persona es en español: en otros idiomas no se dice.
			if language == "es" and ResourceLoader.exists(BRAVO_PATH):
				_voice_queue.append(BRAVO_PATH)
			continue
		var path := _voice_path(str(t))
		if path != "":
			_voice_queue.append(path)
	voice_player.stop()
	_voice_next()


func _voice_next() -> void:
	if voice_player == null:
		return
	if _voice_queue.is_empty():
		# Sin voz, la música vuelve a su volumen.
		if music_player != null:
			create_tween().tween_property(music_player, "volume_db", MUSIC_DB, 0.4)
		return
	if music_player != null and music_player.playing:
		create_tween().tween_property(music_player, "volume_db", MUSIC_DUCK_DB, 0.15)
	var stream := load(str(_voice_queue.pop_front())) as AudioStream
	if stream == null:
		_voice_next()
		return
	voice_player.stream = stream
	voice_player.play()


func _say_again() -> void:
	_say(_voice_last)


func _stop_voice() -> void:
	_voice_queue = []
	if voice_player != null:
		voice_player.stop()


## Hay audio para alguna de estas frases (para enseñar el botón de repetir).
func _has_voice(lines: Array) -> bool:
	for t: Variant in lines:
		if str(t) == BRAVO:
			if language == "es":
				return true
			continue
		if _voice_path(str(t)) != "":
			return true
	return false


## Audio de una frase del nivel Kids en el idioma de la app ("" si no hay). En español, data/voz.json y res://voz/;
## en los demás, data/voz_<idioma>.json y res://voz_<idioma>/ (frase en español → audio de su traducción). Sin el
## audio del idioma no suena nada: mejor callar que leer en español un texto que se ve en otro idioma.
func _voice_path(text: String) -> String:
	if language == "es":
		var id := str(voice_index.get(text, ""))
		var path := "res://voz/%s.ogg" % id
		return path if id != "" and ResourceLoader.exists(path) else ""
	if _voice_lang != language:
		_voice_lang = language
		var file := "res://data/voz_%s.json" % language
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(file)) if FileAccess.file_exists(file) else null
		_voice_lang_index = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	var lid := str(_voice_lang_index.get(text, ""))
	var lpath := "res://voz_%s/%s.ogg" % [language, lid]
	return lpath if lid != "" and ResourceLoader.exists(lpath) else ""


## «Modo Kids» desde la bienvenida: directo al curso, sin pregunta de experiencia ni test.
func _start_kids() -> void:
	kids = true
	welcome_seen = true
	_save_settings()
	if welcome != null and is_instance_valid(welcome):
		welcome.visible = false
		welcome.queue_free()
	welcome = null
	_place_tip()
	if course_done.is_empty():
		_start_from_zero()
	else:
		_open_course()


func _set_kids(on: bool) -> void:
	if on == kids:
		return
	if on:
		kids = true
		_sync_piece_set()
		_actions_mode = ""
		_sync_bar_icons()
		_save_settings()
		_close_options()
		_open_home()
		return
	# Salir del nivel Kids es cosa de mayores.
	_close_options()
	_open_gate(_leave_kids)


func _leave_kids() -> void:
	kids = false
	_sync_piece_set()
	_actions_mode = ""
	_sync_bar_icons()
	_stop_voice()
	_save_settings()
	if mode == "learn" and not lesson.is_empty():
		_show_lesson_step()
	else:
		_open_home()


func _set_voice(on: bool) -> void:
	voice_on = on
	if not on:
		_stop_voice()
	_save_settings()
	_sync_sheet()


## Puerta para adultos: una multiplicación que un niño de 8 años no suele saber, con tres respuestas.
func _open_gate(then: Callable) -> void:
	var a := _rng.randi_range(6, 9)
	var b := _rng.randi_range(6, 9)
	_gate_answer = a * b
	_gate_then = then
	var page := _page("gate")
	var body: VBoxContainer = page["body"]
	var footer: VBoxContainer = page["footer"]
	body.add_child(_spacer(8.0, true))
	var tile := _icon_tile("pin_on", "lilac", 156.0, 98.0)
	tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(tile)
	body.add_child(_spacer(24.0))
	body.add_child(_centered(_para("Para mayores", F_TITLE + 12, _c("ink"), font_display)))
	body.add_child(_spacer(4.0))
	body.add_child(_centered(_para(Loc.f("Para salir del modo Kids, responde: ¿cuánto es %d × %d?", [a, b]), F_HEAD, _c("quiet"), font_medium)))
	body.add_child(_spacer(40.0))
	var answers := [_gate_answer, _gate_answer + _rng.randi_range(1, 4), _gate_answer - _rng.randi_range(1, 4)]
	answers.shuffle()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	for v: Variant in answers:
		var b2 := _button("", str(v), _on_gate.bind(int(v)), _c("surface"), _c("ink"), {"font_size": F_TITLE, "height": 148.0, "font": font_display, "glow": _c("shadow")})
		b2.mouse_filter = Control.MOUSE_FILTER_STOP
		b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b2)
	body.add_child(row)
	body.add_child(_spacer(8.0, true))
	footer.add_child(_button("party", "Seguir en modo Kids", _close_gate, _tint("peach")[0], _c("ink"), {"font_size": F_SUB, "height": 96.0, "icon": 44.0, "font": font_medium}))
	_say([_kid_line("gate")])


func _on_gate(v: int) -> void:
	var ok := v == _gate_answer and _gate_answer >= 0
	_gate_answer = -1
	_close_progress()
	if ok and _gate_then.is_valid():
		_gate_then.call()
	elif mode != "learn":
		_open_home()


func _close_gate() -> void:
	_gate_answer = -1
	_close_progress()
	if mode != "learn":
		_open_home()


# ---------------------------------------------------------------- páginas: experiencia, resultado y progreso

## Página a pantalla completa con fondo pastel: arriba una zona que se desplaza y abajo un pie fijo.
## Devuelve {"body": VBoxContainer, "footer": VBoxContainer}.
func _page(kind: String) -> Dictionary:
	_close_progress()
	if sheet_kind != "":
		_close_options()
	progress_kind = kind
	progress = Control.new()
	progress.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(progress)
	var back := PastelBackdrop.new()
	back.top = _c("wash_top")
	back.mid = _c("wash_mid")
	back.bottom = _c("wash_bottom")
	var glow := 0.5 if not dark else 0.22
	var rose: Color = _tint("rose")[0]
	var sky: Color = _tint("sky")[0]
	var butter: Color = _tint("butter")[0]
	back.blobs = [
		[Vector2(0.95, 0.08), 0.62, Color(sky.r, sky.g, sky.b, glow)],
		[Vector2(0.0, 0.4), 0.5, Color(rose.r, rose.g, rose.b, glow * 0.8)],
		[Vector2(0.92, 0.8), 0.56, Color(butter.r, butter.g, butter.b, glow * 0.9)],
	]
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_STOP
	progress.add_child(back)
	if kids:
		progress.add_child(_kids_wall())
	var inset := _insets()
	var pad := _pad(48, int(maxf(inset.x, 60.0)) + 20, 48, int(inset.y) + 40)
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	progress.add_child(pad)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	pad.add_child(column)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	progress_scroll = scroll
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 0)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	column.add_child(_spacer(20.0))
	var footer := VBoxContainer.new()
	footer.add_theme_constant_override("separation", 14)
	column.add_child(footer)
	_place_tip()
	return {"body": body, "footer": footer}


func _close_progress() -> void:
	if progress != null and is_instance_valid(progress):
		progress.visible = false
		progress.queue_free()
	progress = null
	progress_kind = ""
	_place_tip()


## Salir de la página abierta (botón «atrás»): del resultado se pasa a entrenar; de la pregunta de
## experiencia no se sale sin contestar (o sin saltar el test).
func _leave_progress() -> void:
	if progress_kind == "result":
		_start_training()
	elif progress_kind == "gate":
		_close_gate()
	elif progress_kind == "game_setup":
		_close_game_setup()
	elif progress_kind == "review":
		_close_progress()
	elif progress_kind == "day":
		_open_home()
	elif progress_kind == "cine":
		_open_train_hub()
	elif progress_kind == "campeonato":
		_open_home()
	elif progress_kind == "campeonato_sala":
		_open_campeonato()
	elif progress_kind == "progress" or (progress_kind == "course" and mode == "learn" and not lesson.is_empty()):
		_close_progress()
	elif progress_kind in ["course", "experience"] and use_settings:
		_open_home()


func _start_training() -> void:
	mode = "train"
	review_session = false
	_close_progress()
	_next_training()


func _centered(label: Label) -> Label:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


## Pregunta de experiencia: el punto de partida del test. Cuatro opciones con su dibujo.
func _open_experience() -> void:
	var page := _page("experience")
	var body: VBoxContainer = page["body"]
	var footer: VBoxContainer = page["footer"]
	body.add_child(_spacer(8.0, true))
	var tile := _icon_tile("cap", "lilac", 156.0, 98.0)
	tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(tile)
	body.add_child(_spacer(24.0))
	body.add_child(_centered(_para("¿Cuánto has jugado?", F_TITLE + 12, _c("ink"), font_display)))
	body.add_child(_spacer(4.0))
	body.add_child(_centered(_para("Así el test empieza cerca de tu nivel.", F_HEAD, _c("quiet"), font_medium)))
	body.add_child(_spacer(40.0))
	var options := [
		["never", "book", "butter", "Nunca he jugado", "Empieza por las lecciones: cómo se mueve cada pieza."],
		["rules", "piece_pawn", "mint", "Sé mover las piezas", "Conozco las reglas y poco más."],
		["casual", "piece_knight", "sky", "Juego de vez en cuando", "Alguna partida con amigos o en el móvil."],
		["regular", "piece_queen", "rose", "Juego a menudo", "En un club o por internet."],
	]
	for def: Array in options:
		var pick := _start_test.bind(str(def[0]))
		if str(def[0]) == "never" and not course.is_empty():
			pick = _start_from_zero
		body.add_child(_option_button(str(def[1]), str(def[2]), str(def[3]), str(def[4]), pick))
		body.add_child(_spacer(20.0))
	body.add_child(_spacer(8.0, true))
	footer.add_child(_centered(_para("El test tiene entre 8 y 12 problemas, con un solo intento y sin ayudas. Al terminar verás tu nivel, en qué fallas y un plan.", F_FOOT + 2, _c("quiet"), font_regular)))
	footer.add_child(_spacer(14.0))
	if _has_player():
		# Se llega aquí desde «Repetir el test»: se puede dejar todo como estaba.
		footer.add_child(_button("close", "Cancelar", _open_home if use_settings else _close_progress, _c("field"), _c("ink"), {"font_size": F_SUB, "height": 96.0, "icon": 40.0, "font": font_medium}))
	else:
		footer.add_child(_button("skip", "Saltar el test", _skip_test, _tint("butter")[0], _c("ink"), {"font_size": F_SUB, "height": 96.0, "icon": 44.0, "font": font_medium}))
		if use_settings and welcome_seen:
			footer.add_child(_button("home", "Inicio", _open_home, _c("field"), _c("ink"), {"font_size": F_SUB, "height": 92.0, "icon": 44.0, "font": font_medium}))


## Opción grande: tesela con dibujo, titular, una línea de texto y una flecha.
## big: letra y tesela más grandes (el inicio, que tiene sitio de sobra).
func _option_button(icon_name: String, tint_name: String, heading: String, text: String, on_press: Callable, big: bool = false) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.pressed.connect(on_press)
	_style_button(b, _c("surface"), _c("ink"), 48, F_BODY, font_semibold, _c("shadow"))
	var pad := _pad(26, 30, 30, 30) if big else _pad(26, 24, 30, 24)
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.add_child(pad)
	var row := _icon_row(icon_name, tint_name, heading, text, 148.0, F_HEAD + 6, F_BODY + 2) if big else _icon_row(icon_name, tint_name, heading, text, 120.0)
	pad.add_child(row)
	row.add_child(_icon("next", 56.0 if big else 46.0, _c("quiet")))
	var fit := func() -> void:
		if is_instance_valid(b) and is_instance_valid(pad):
			b.custom_minimum_size = Vector2(0.0, pad.get_combined_minimum_size().y)
	pad.minimum_size_changed.connect(fit)
	fit.call()
	b.set_meta("label", heading)
	return b


## Tarjeta blanca de una página, con sus filas dentro.
func _panel() -> Array:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = _c("surface")
	sb.set_corner_radius_all(48)
	sb.content_margin_left = 30.0
	sb.content_margin_right = 30.0
	sb.content_margin_top = 30.0
	sb.content_margin_bottom = 30.0
	sb.shadow_color = _c("shadow")
	sb.shadow_size = 24
	sb.shadow_offset = Vector2(0.0, 10.0)
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 30)
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(rows)
	return [panel, rows]


## Calificación de una dimensión del perfil, como etiqueta. "" = sin etiqueta.
func _status_chip(state: String) -> Control:
	var chip: PanelContainer = null
	match state:
		"weak":
			var rose := _tint("rose")
			chip = _chip("A reforzar", rose[0], rose[1], "target")
		"strong":
			var mint := _tint("mint")
			chip = _chip("Fuerte", mint[0], mint[1], "spark")
		"ok":
			chip = _chip("En tu nivel", _c("field"), _c("ink"), "check")
		"few":
			chip = _chip("Pocos datos", _c("field"), _c("quiet"), "info")
	return chip


## Fila del perfil o del plan: tesela con icono, titular, detalle y, si la hay, su calificación.
func _profile_row(icon_name: String, tint_name: String, heading: String, text: String, state: String = "") -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_icon_row(icon_name, tint_name, heading, text, 92.0))
	var chip := _status_chip(state)
	if chip != null:
		var line := HBoxContainer.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(_spacer_w(116.0))
		chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		line.add_child(chip)
		box.add_child(line)
	return box


func _spacer_w(width: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(width, 0.0)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## «18 s» o «1 min 5 s».
func _duration(ms: float) -> String:
	var seconds := int(round(ms / 1000.0))
	if seconds < 60:
		return "%d s" % maxi(seconds, 1)
	return Loc.f("%d min %d s", [seconds / 60, seconds % 60]) if seconds % 60 != 0 else Loc.f("%d min", (seconds / 60))


## Resultado del test ("result") o progreso ("progress"): el nivel, el perfil por dimensiones y el plan.
func _open_progress(kind: String = "progress") -> void:
	if not _has_player():
		return
	var page := _page(kind)
	var body: VBoxContainer = page["body"]
	var footer: VBoxContainer = page["footer"]
	var rating: Dictionary = player["rating"]
	var tries: Array = player["tries"]
	var pr := Assessment.profile(tries)
	var todo := Assessment.plan(rating, pr)
	var r := float(rating["r"])
	var band := Assessment.level_band(r)
	var limits := Assessment.measurable_range(pool)

	# Arriba a la izquierda, el icono del jugador: al tocarlo, cambiar el icono o la foto. Va en un hueco de alto cero
	# para no empujar el resto (y se desplaza con la página).
	if kind == "progress" and not kids:
		var corner := Control.new()
		corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_child(corner)
		var pick := Button.new()
		pick.flat = true
		pick.focus_mode = Control.FOCUS_NONE
		for state: String in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			pick.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		pick.size = Vector2(150.0, 150.0)
		pick.position = Vector2(0.0, 0.0)
		pick.mouse_filter = Control.MOUSE_FILTER_STOP
		pick.pressed.connect(_open_avatar)
		pick.set_meta("label", "Tu icono")
		var mark := _level_badge(r, 150.0)
		mark.set_anchors_preset(Control.PRESET_FULL_RECT)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pick.add_child(mark)
		corner.add_child(pick)
	# El nivel.
	body.add_child(_spacer(4.0))
	body.add_child(_centered(_para("TU NIVEL" if kind != "result" else "RESULTADO DEL TEST", F_CAP, _c("quiet"), font_semibold)))
	var level := Assessment.level_of(r)
	var level_text := Loc.f("Nivel %d", level)
	var limit_note := ""
	if r < float(limits["min"]):
		limit_note = "Casi no hay problemas más fáciles que los de este nivel: tu puntuación exacta aún no es fiable."
	elif r > float(limits["max"]):
		limit_note = "Casi no hay problemas más difíciles que los de este nivel: tu puntuación exacta aún no es fiable."
	var number := _centered(_para(level_text, F_LARGE + 44, _c("ink"), font_display))
	number.add_theme_constant_override("line_spacing", -8)
	body.add_child(number)
	# De cuántos niveles, y a qué tramo de la escala de problemas de Lichess corresponde.
	body.add_child(_centered(_para(Loc.f("de %d · problemas de Lichess de %s", [Assessment.LEVEL_FLOORS.size() - 1, Assessment.level_span(level)]), F_SUB, _c("quiet"), font_medium)))
	body.add_child(_spacer(6.0))
	var band_row := CenterContainer.new()
	band_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lilac := _tint("lilac")
	band_row.add_child(_chip(str(band["name"]), lilac[0], lilac[1]))
	body.add_child(band_row)
	body.add_child(_spacer(18.0))
	body.add_child(_centered(_para(str(band["blurb"]), F_BODY, _c("ink"), font_regular)))
	body.add_child(_spacer(10.0))
	var margin := int(round(2.0 * float(rating["rd"]) / 10.0)) * 10
	var small := Loc.f("Puntuación %d (margen ±%d). Se afina con cada problema. Es la escala de los problemas de Lichess. No es Elo: no hay una equivalencia fiable entre las dos.", [int(round(r)), margin])
	if limit_note != "":
		small = limit_note + " " + small
	if test_skipped:
		small = Loc.t("Has saltado el test: empiezas desde el principio y el nivel se ajusta al jugar.") + " " + small
	body.add_child(_centered(_para(small, F_FOOT, _c("quiet"), font_regular)))

	# El perfil.
	body.add_child(_spacer(40.0))
	var n := tries.size()
	body.add_child(_text((Loc.f("PERFIL · %d PROBLEMAS", n)) if n != 1 else "PERFIL · 1 PROBLEMA", F_CAP, _c("quiet"), font_semibold))
	body.add_child(_spacer(8.0))
	if n < 20:
		body.add_child(_para("Primeras observaciones: con tan pocos problemas son indicios, no un veredicto. Se afinan al entrenar.", F_FOOT + 2, _c("quiet"), font_regular))
		body.add_child(_spacer(14.0))
	var made := _panel()
	var rows: VBoxContainer = made[1]
	body.add_child(made[0])
	# Las familias con datos para calificarlas van cada una en su fila; las demás, juntas al final.
	var few := PackedStringArray()
	for f: Dictionary in pr["families"]:
		var family_name := str(Assessment.FAMILY_NAME.get(f["family"], f["family"]))
		var family_state := Assessment.status(f)
		if family_state == "few":
			few.append(Loc.f("%s, %d de %d", [family_name.to_lower(), int(f["correct"]), int(f["n"])]))
		else:
			rows.add_child(_profile_row("whatif", "sky", family_name, Loc.f("%d de %d acertados", [int(f["correct"]), int(f["n"])]), family_state))
	var mate: Dictionary = pr["mate"]
	if int(mate["n"]) > 0:
		rows.add_child(_profile_row("target", "rose", "Visión de mate", Loc.f("%d de %d problemas que acaban en mate", [int(mate["correct"]), int(mate["n"])]), Assessment.status(mate)))
	var long: Dictionary = pr["long"]
	if int(long["n"]) > 0:
		var calc := Loc.f("%d de %d problemas de tres jugadas o más.", [int(long["correct"]), int(long["n"])])
		if int(pr["failLater"]) > 0:
			calc += Loc.f(" En %d acertaste la primera jugada y fallaste después.", int(pr["failLater"]))
		rows.add_child(_profile_row("line", "lilac", "Cálculo", calc, Assessment.status(long)))
	var fails := int(pr["fails"])
	if fails > 0:
		var parts := PackedStringArray()
		for error_kind: String in Assessment.ERROR_KINDS:
			var count := int(pr["errors"][error_kind])
			if count > 0:
				parts.append("%s ×%d" % [_error_name(error_kind), count])
		var detail := " · ".join(parts) + "."
		if int(pr["replyBlind"]) > 0:
			detail += Loc.f(" %d de %d se castigaban con la respuesta inmediata del rival.", [int(pr["replyBlind"]), fails])
		rows.add_child(_profile_row("wrong", "peach", Loc.f("Tus jugadas equivocadas: %d", fails), detail))
	var time: Dictionary = pr["time"]
	if int(time["n"]) > 0:
		var pace := Loc.f("Sueles tardar %s en mover.", _duration(float(time["median"])))
		if int(time["rushed"]) > 0:
			pace += Loc.f(" %d fallos llegaron en menos de la mitad de lo que tardas cuando aciertas.", int(time["rushed"]))
		rows.add_child(_profile_row("clock", "butter", "Ritmo", pace))
	if not few.is_empty():
		rows.add_child(_profile_row("chart", "sky", "Con pocos datos todavía", _sentence("; ".join(few) + ".")))
	rows.add_child(_profile_row("info", "mint", "Sin medir todavía", "Desarrollo, seguridad del rey y estrategia. Los problemas tácticos no las miden: hacen falta posiciones de otro tipo."))

	# Los niveles: dónde está y cuántos problemas de cada uno ha resuelto.
	body.add_child(_spacer(40.0))
	body.add_child(_text("NIVELES", F_CAP, _c("quiet"), font_semibold))
	body.add_child(_spacer(12.0))
	var levels_made := _panel()
	body.add_child(levels_made[0])
	var solved := {}
	for t: Dictionary in tries:
		if bool(t["correct"]):
			solved[str(t["id"])] = true
	var per_level := {}
	var done_level := {}
	for item: Dictionary in pool:
		var lv := Assessment.level_of(float(item["rating"]))
		per_level[lv] = int(per_level.get(lv, 0)) + 1
		if solved.has(str(item["id"])):
			done_level[lv] = int(done_level.get(lv, 0)) + 1
	var tints := ["peach", "mint", "lilac", "sky", "butter", "rose"]
	for lv in Assessment.LEVEL_FLOORS.size():
		if not per_level.has(lv):
			continue
		var line := Loc.f("%d de %d problemas resueltos · puntuación %s", [int(done_level.get(lv, 0)), int(per_level[lv]), Assessment.level_span(lv)])
		var state := ""
		if lv == level:
			state = "here"
		var row := _profile_row("flag" if lv == level else "check", str(tints[lv % tints.size()]), Loc.f("Nivel %d", lv), line)
		if state == "here":
			var here := _chip("Estás aquí", _tint("lilac")[0], _tint("lilac")[1], "pin_on")
			here.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			var line_box := HBoxContainer.new()
			line_box.add_child(_spacer_w(116.0))
			line_box.add_child(here)
			row.add_child(line_box)
		(levels_made[1] as VBoxContainer).add_child(row)

	# El plan.
	body.add_child(_spacer(40.0))
	body.add_child(_text("TU PLAN", F_CAP, _c("quiet"), font_semibold))
	body.add_child(_spacer(12.0))
	var plan_made := _panel()
	var plan_rows: VBoxContainer = plan_made[1]
	body.add_child(plan_made[0])
	var target := float(todo["target"])
	var lowest := float(pool[0]["rating"]) if not pool.is_empty() else 0.0
	if target < lowest:
		plan_rows.add_child(_profile_row("target", "peach", "Los problemas más fáciles que hay", Loc.f("La muestra empieza en %d: al principio fallarás más de lo que conviene.", int(lowest))))
	else:
		plan_rows.add_child(_profile_row("target", "peach", Loc.f("Problemas de dificultad %d", int(round(target))), "Algo por debajo de tu nivel, para acertar unos tres de cada cuatro."))
	var focus: Array = todo["focus"]
	if focus.is_empty():
		plan_rows.add_child(_profile_row("whatif", "sky", "Problemas variados", "Todavía no hay un punto flojo claro."))
	for item: Dictionary in focus:
		var what := "mate"
		if str(item["kind"]) == "long":
			what = "tres jugadas o más"
		elif str(item["kind"]) == "family":
			what = str(Assessment.FAMILY_NAME.get(item["family"], "")).to_lower()
		plan_rows.add_child(_profile_row("flag", "rose", Loc.f("Más problemas de %s", what), "Es donde rindes por debajo de tu nivel: saldrán más a menudo."))
	for habit: String in todo["habits"]:
		match habit:
			"reply":
				plan_rows.add_child(_profile_row("eye", "lilac", "Mira la respuesta del rival", "Antes de soltar la pieza, busca sus jaques, capturas y amenazas."))
			"rushed":
				plan_rows.add_child(_profile_row("clock", "butter", "Sin prisa", "Tus fallos llegan muy rápido. Dedica a cada jugada el tiempo que usas cuando aciertas."))
			"followThrough":
				plan_rows.add_child(_profile_row("line", "mint", "Calcula hasta el final", "Aciertas la primera jugada y fallas después: repasa la variante entera antes de mover."))
	body.add_child(_spacer(20.0))

	var go := {"font_size": F_HEAD, "height": 148.0, "icon": 60.0, "trailing": true, "glow": _c("glow")}
	if kind == "result":
		var start := _button("next", "Empezar a entrenar", _start_training, _c("accent"), _c("accent_ink"), go)
		start.mouse_filter = Control.MOUSE_FILTER_STOP
		footer.add_child(start)
	else:
		var keep := _button("next", "Seguir entrenando", _close_progress, _c("accent"), _c("accent_ink"), go)
		keep.mouse_filter = Control.MOUSE_FILTER_STOP
		footer.add_child(keep)
		footer.add_child(_spacer(8.0))
		footer.add_child(_button("retry", "Repetir el test de nivel", _open_experience, _tint("sky")[0], _c("ink"), {"font_size": F_SUB, "height": 92.0, "icon": 44.0, "font": font_medium}))
	if use_settings:
		footer.add_child(_button("home", "Inicio", _open_home, _c("field"), _c("ink"), {"font_size": F_SUB, "height": 92.0, "icon": 44.0, "font": font_medium}))


## La frase, con su primera letra en mayúscula.
func _sentence(text: String) -> String:
	return text.substr(0, 1).to_upper() + text.substr(1) if text != "" else ""


## Clase de una jugada equivocada, como nombre corto para la lista del perfil.
func _error_name(kind: String) -> String:
	match kind:
		"mate":
			return "mate en contra"
		"hangMoved":
			return "pieza movida a una casilla atacada"
		"hangOther":
			return "otra pieza sin defensa"
		"material":
			return "pérdida de material en pocas jugadas"
		"worse":
			return "posición perdida"
		"missed":
			return "ocasión desaprovechada"
		"slower":
			return "ganaba, pero no era la más precisa"
	return kind
