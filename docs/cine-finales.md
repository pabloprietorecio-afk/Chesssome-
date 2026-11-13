# Cine de finales: vídeo real con pausa automática

Idea de Pablo: ver finales reales en vídeo y que el vídeo **se pare solo justo antes de la jugada** para preguntar al jugador «¿Qué jugarías?». Después, el vídeo sigue y se ve lo que pasó de verdad.

**Estado (13 nov 2026).** Prototipo en la web 2D, en la rama `cine-video`, publicado en la web de pruebas (apartado 12). El reproductor de YouTube carga en el móvil de Pablo. Un clip preparado (Ding–Gukesh, Mundial 2024) con tres preguntas comprobadas con Stockfish y con las marcas de tiempo puestas por Pablo viendo el vídeo; falta que confirme en el móvil que la pausa automática cae justo antes de la jugada. Las películas generadas (sin vídeo) quedan aparcadas: ver el apartado 13.

## 1. Cómo es la experiencia

1. **Ver el vídeo.** El jugador pulsa ▶ en el reproductor. El vídeo corre hasta la marca y se para solo.
2. **Pregunta.** Debajo del vídeo aparece la pregunta y nuestro tablero con la posición. Puede haber varias preguntas encadenadas en la misma pausa; el tablero juega las jugadas intermedias de la partida.
3. **Respuesta.** Tras cada jugada, la app dice si mantiene el resultado, si lo estropea y con qué línea del motor.
4. **Así ocurrió.** El vídeo sigue desde la pausa y se ve la jugada real y lo que vino después.

Y dos atajos:

- **Ir directo a la pregunta:** sin vídeo previo. Sirve sin conexión, evita que el título del vídeo destripe nada y es el único modo mientras un clip no tenga marcas.
- **Seguir viendo sin responder:** siempre disponible (lo exige YouTube; ver apartado 2).

## 2. Qué permite y qué exige YouTube (hechos verificados)

| Regla | Consecuencia en el diseño | Fuente |
| --- | --- | --- |
| La API documenta `pauseVideo`, `playVideo`, `seekTo` y `getCurrentTime`. No hay evento de avance del tiempo | Se puede pausar por código. El tiempo se lee cada 100 ms | [API de iframe](https://developers.google.com/youtube/iframe_api_reference) |
| No se pueden hacer cambios en el reproductor que la documentación no describa | Solo se usan funciones documentadas | [Funcionalidad mínima (RMF)](https://developers.google.com/youtube/terms/required-minimum-functionality) |
| Prohibido poner capas, marcos u otros elementos delante de cualquier parte del reproductor | La pregunta va **debajo** del vídeo. Sin filtro de cine antiguo, sin esquinas recortadas | RMF |
| No se puede condicionar el vídeo a que el usuario haga algo distinto de pulsar play (III.F.3) | **Responder es opcional.** Si el jugador pulsa ▶ durante la pregunta, no se le vuelve a parar | [Políticas para desarrolladores](https://developers.google.com/youtube/terms/developer-policies) |
| No se puede cobrar por ver contenido en un reproductor incrustado (III.F.3) | **El cine con vídeos de YouTube tiene que ser gratis** | Políticas |
| No se pueden vender anuncios en una página con contenido de YouTube salvo que el resto del contenido lo justifique (III.G.1.d) | Sin anuncios propios en la pantalla del cine | Políticas |
| No se puede descargar, guardar ni ofrecer sin conexión (III.E.1), ni reproducir con el reproductor oculto (III.I.9), ni separar audio y vídeo (III.I.7), ni bloquear sus anuncios (III.I.5) | El vídeo siempre a la vista y tal cual. Los anuncios de YouTube pueden aparecer | Políticas |
| El reproductor mide al menos 200 × 200 px | En un móvil de 390 px mide 358 × 201 | RMF |
| La reproducción automática solo puede empezar con el reproductor visible en más de la mitad | Antes de reanudar, la app desplaza la pantalla hasta el vídeo | RMF |
| La página debe identificarse con la cabecera `Referer`; sin ella, error 153. En una app Android, el WebView debe cargar el HTML con una URL base `https://<id de la app>` | En web no se toca el `Referer`. Un archivo abierto en local no puede reproducir. En Godot hará falta un WebView nativo | RMF |
| Las visitas solo cuentan si la reproducción empieza con el botón ▶ del propio reproductor | El vídeo se carga parado y lo arranca el jugador: la visita cuenta para el canal | API de iframe |
| Hay que enlazar los Términos de YouTube y decir en la política de privacidad que se usan sus servicios, con enlace a la de Google (III.A) | Texto y enlaces en la pantalla del clip. La política de privacidad de la app tendrá que incluirlo | Políticas |
| Las apps dirigidas a niños tienen obligaciones adicionales (III.J) | **Nada de YouTube en la sección infantil** | Políticas |

Precedente: herramientas educativas como Edpuzzle hacen exactamente esto con vídeos de YouTube (el vídeo se para en cada pregunta y la pregunta aparece al lado). [Fuente](https://plu.edu/itech/news/using-edpuzzle-for-making-engaging-video-lessons). Diferencia: varias obligan a contestar para seguir; aquí no, por la regla III.F.3.

## 3. Derechos en la UE (no es asesoramiento jurídico)

- Incrustar un vídeo que está libremente accesible con permiso de su titular no es una nueva comunicación al público (TJUE, *BestWater*, C-348/13).
- Si el vídeo se subió **sin** permiso del titular, enlazarlo o incrustarlo sí puede infringir cuando se sabe o se debería saber, y eso se presume en quien actúa con ánimo de lucro (*GS Media*, C-160/15).
- Saltarse una protección contra la incrustación es comunicación al público (*VG Bild-Kunst*, C-392/19).

Fuentes: [Fieldfisher](https://fieldfisher.com/en/insights/case-focus-hyperlinking-and-embedding-of-content), [Hogan Lovells](https://www.hoganlovells.com/en/publications/uploads-framing-hosting-a-demanding-balancing-act), [DLA Piper](https://www.dlapiper.com/insights/publications/2021/03/vg-bild-kunst-the-saga-on-legality-of-linking-continues).

**Regla del proyecto:** solo vídeos del canal oficial del titular (organizador, federación o la productora que lo grabó), nunca copias resubidas, y solo si el canal permite incrustar. El pipeline rechaza cualquier clip con `official: false`.

Sin verificar: qué exige exactamente la normativa española de cookies para incrustar YouTube. Medidas tomadas por prudencia: nada se carga de YouTube hasta que el jugador elige ver el vídeo, y se usa el dominio de privacidad mejorada (`youtube-nocookie.com`). Consultar antes de publicar.

## 4. Cómo funciona la pausa

**Datos de un clip** (`pipeline/video-clips.ts`): el vídeo (id, canal, fecha, si es oficial, duración), las marcas (`start`, `at` de cada parada, `end`), la partida completa en SAN y las preguntas de cada parada, con su texto propio.

**El director** (`src/core/videoCine.ts`) es una máquina de estados pura, sin DOM ni reproductor: recibe lecturas del tiempo y devuelve órdenes (`cue`, `play`, `pause`, `seek`).

| Situación | Qué hace |
| --- | --- |
| El tiempo llega a la marca (0,12 s antes, para compensar la lectura cada 100 ms) | Ordena pausar y pasa a preguntar |
| El reproductor sigue «reproduciendo» justo después de la orden | Espera 0,6 s; reintenta la pausa **una** vez |
| El jugador pulsa ▶ durante la pregunta | No vuelve a parar. Avisa y ofrece «Volver a la pregunta» |
| El jugador arrastra la barra por delante de la marca | No para. Ofrece «Volver a la pregunta» |
| La duración que da el reproductor no es la del vídeo (probable anuncio, o vídeo reeditado) | No actúa hasta que la duración vuelve a coincidir |
| El vídeo da error (retirado, privado, no incrustable, sin `Referer`) | La pregunta sigue funcionando sin vídeo, con enlace «Ver en YouTube» |
| Se llega a `end` | Pausa y muestra el cierre |
| Clip sin marcas | El ▶ del cartel carga el vídeo entero, sin pausa, con «Ir a la pregunta» a mano. También modo directo; al revelar, el vídeo empieza por el principio |

**Reproductor** (`src/ui/youtubePlayer.ts`): crea el iframe en `youtube-nocookie.com` con `enablejsapi=1` y lo controla con la API oficial. El vídeo se carga parado en el segundo exacto y lo arranca el jugador.

**Precisión medida con el reproductor simulado:** con la marca en 8,40 s la pausa cae en 8,35 s. En el test unitario, siempre entre 0,12 s antes y 0,1 s después de la marca.

## 5. De dónde salen las preguntas y las respuestas

`npx tsx pipeline/build-video-cine.ts` (≈40 s por clip):

1. Reproduce la **partida entera** con chess.js. Una jugada ilegal y el clip se rechaza.
2. La posición de cada pregunta sale de esa reproducción, nunca de un FEN escrito a mano.
3. Stockfish 19 evalúa **todas** las jugadas legales (profundidad 24; las dudosas, 34).
4. El resultado que se busca (ganar o tablas) se deduce de la mejor jugada. Si la posición no tiene resultado claro, la pregunta se rechaza.
5. Si la jugada de la partida no mantiene el resultado, la app la presenta como error histórico.
6. Solo se dice «mate forzado» si el motor lo encuentra. Si no, «comprobado con el motor, sin prueba de mate ni tablas de finales».

Que la pausa caiga justo antes de la jugada **no lo puede comprobar ningún programa**: por eso cada clip lleva `marks: 'pending' | 'verified'`.

## 6. El cuello de botella: marcar los segundos

Nadie puede saber en qué segundo se hace una jugada sin ver el vídeo. Claude no puede ver vídeos desde su entorno.

**Editor de marcas** (en la app, dentro de cada clip): se carga el vídeo, se reproduce y se pulsa «= ahora» para el inicio, cada pausa y el fin. Ajustes de ±0,1 y ±1 s y un botón «Probar» que reproduce desde 4 s antes y comprueba dónde se para.

- «Guardar en este dispositivo»: el clip ya se para solo en ese navegador, marcado como «sin verificar».
- «Copiar las marcas»: texto para pegar en el chat o en `pipeline/video-clips.ts`.

Coste estimado: un par de minutos por clip (sin medir).

**Estimación con los relojes (hecha, pendiente de validar con el vídeo).** Las retransmisiones oficiales guardan el reloj de cada jugador tras cada jugada. Con eso se sabe cuánto pensó cada jugada y, si el vídeo no tiene cortes, basta marcar **una** jugada (el ancla) para estimar el segundo de todas las demás (`src/core/clockSync.ts`).

- Tiempo pensado = reloj anterior del mismo bando − reloj actual + incremento (y + 30 min al completar la jugada 40 en el Mundial 2024).
- El error no crece con la distancia al ancla: la suma se telescopa por bando (solo cuentan la primera y la última lectura de cada jugador). Queda ±2 s por redondeo más lo que tarde el jugador en pulsar el reloj.
- Pausa sugerida: 3 s antes de que se pulse el reloj de la jugada, pero al menos 1 s después de la anterior; si están más juntas, a mitad de camino.
- En el editor de marcas: elegir la jugada ancla, pulsar «= ahora» cuando se pulsa su reloj, revisar la lista de segundos estimados (con «Ir» a cada uno) y «Poner las pausas estimadas».
- Limitación: los vídeos con cortes o repeticiones rompen la estimación a partir del corte.

**Ding–Gukesh.** Relojes de la retransmisión oficial en Lichess, leídos del texto indexado por el buscador (la página no se puede descargar por su robots.txt). Gukesh pensó **2 min 12 s** antes de 55…Txf2; el resto fue casi inmediato salvo 58.Re3 (53 s):

| Jugada | Pensado | Segundo estimado con el ancla 55…Txf2 = 217 s |
| --- | --- | --- |
| 55.Tf2 | — | 85 (1:25) |
| 55…Txf2 | 132 s | 217 (3:37), ancla |
| 56.Rxf2 | 2 s | 219 |
| 56…Ad5 | 3 s | 222 |
| 57.Axd5 | 10 s | 232 |
| 57…Rxd5 | 1 s | 233 (3:53) |
| 58.Re3 | 53 s | 286 (4:46) |
| 58…Re5 | 7 s | 293 (4:53) |

Comparación con las marcas de Pablo (pausa 215,47 s, fin 233,07 s): de la pausa al fin hay 17,6 s, y los relojes dan 16 s de 55…Txf2 a 57…Rxd5. Si Gukesh jugó Txf2 1,6 s después de la pausa, el fin marcado coincide con 57…Rxd5, y entonces 58.Re3 y 58…Re5 quedarían **fuera** del clip, hacia 4:46 y 4:53, salvo que el vídeo tenga un corte. Por comprobar viendo el vídeo.

**Idea para escalar (hipótesis):** pedir permiso por escrito a FIDE o a los canales permitiría automatizar la búsqueda del segundo exacto mirando el tablero en el vídeo. Sin permiso, las condiciones de YouTube prohíben descargar el vídeo y acceder por medios automatizados.

## 7. Vídeos

**Criterios:** canal oficial del titular; incrustación permitida (se comprueba con oEmbed); la jugada se ve o se entiende; el título no destripa la jugada; nadie la anuncia antes de la pausa; subida estable (canales institucionales).

| Vídeo | Canal | Momento | Estado |
| --- | --- | --- | --- |
| [Gukesh wins! - The final minutes of the FIDE World Championship 2024](https://www.youtube.com/watch?v=W9JtcW_0Sr8) | FIDE chess | 55.Tf2?? Txf2, 56…Ad5, 58…Re5: final de torre y alfil que pasa a final de peones | **Clip preparado.** oEmbed correcto. Vídeo de 437 s; clip de 3:20 a 3:53 con la pausa en 3:35 (215,47 s), marcas de Pablo |
| [Final Moments of Gukesh Winning World Championship](https://www.youtube.com/watch?v=HlmhDl_KnOY) | ChessBase India | El mismo momento, grabado a pie de tablero | oEmbed correcto. Alternativa al anterior |
| [FIDE World Championship Match - TIEBREAK FOR THE TITLE](https://www.youtube.com/watch?v=WkwVXg9a_i0) | FIDE chess | Nepómniashchi–Ding 2023, desempate 4: 46…Tg6 | oEmbed correcto. Retransmisión larga con comentaristas. No es un final técnico |
| [Instructive Knight vs Rook endgame with a beautiful finish](https://www.youtube.com/watch?v=Y_IV9N5rhhw) | ChessBase India | Final de caballo contra torre entre aficionados | oEmbed correcto. Falta la partida |
| Praggnanandhaa–Ganguly, Tata Steel India Blitz 2018 | ChessBase India | Torre y dos peones contra torre, con 10 s en el reloj | Enlace sin localizar. Ritmo de relámpago: pausas difíciles |
| Tata Steel India Rapid 2021, ronda 2 (jugadores sin verificar) | ChessBase India | Final de torres con promoción menor, comentado por Sagar Shah | Enlace y jugadores sin localizar |

Sin verificar en todos: que se vea bien el tablero y el segundo exacto de cada jugada.

**Archivo histórico con licencia libre** (se puede descargar, editar y poner en blanco y negro; apenas muestra jugadas, sirve de ambiente): Open Beelden, noticiarios Polygoon. Ejemplo: [simultáneas de Tal, Kortchnói y Donner, 1968](https://www.openbeelden.nl/media/621300), CC BY-SA, 352 × 288. El noticiario del Alekhine–Euwe de 1935 existe, con licencia sin verificar.

**Descartados:** vídeos resubidos por terceros; British Pathé, AP y Movietone salvo incrustados tal cual (usar copias exige licencia).

## 8. Plataforma

- **Web (ahora):** iframe con la API oficial. Dentro de un artefacto de Claude no funciona: su marco bloquea los iframes de otros sitios. Hace falta una web normal por https: GitHub Pages del propio repositorio (apartado 12).
- **Android con Godot (después del 3D):** Godot no trae WebView. YouTube exige el WebView del sistema y que la app se identifique con una URL base `https://<id de la app>`. Camino previsto: un plugin Android v2 propio, pequeño, en Kotlin, que coloque un `WebView` nativo en el rectángulo que le indique Godot y hable con GDScript por señales. La vista nativa queda siempre por encima de Godot, que es justo lo que pide YouTube. Exige exportar con Gradle (cambio en la CI). `godot_wry` solo cubre escritorio según su propia documentación; `godot-kirie` cubre Android e iOS pero es experimental. El director y los datos se portan tal cual: solo cambia el adaptador del reproductor.

## 9. Consecuencias para el producto

- **Negocio:** el cine con vídeos de YouTube no puede ir en la parte de pago ni llevar anuncios propios. Sí pueden ser de pago las películas generadas, los clips de archivo con licencia libre alojados por nosotros o los niveles profundos de explicación.
- **Sin conexión:** el vídeo necesita red; la pregunta, no.
- **Infantil:** sin YouTube.
- **Dependencia:** un vídeo puede retirarse o reeditarse. La app sigue funcionando sin él y el catálogo debe poder actualizarse sin publicar una versión nueva (pendiente: hoy va dentro de la app).

## 10. Qué falta validar con YouTube real, por orden

1. Que el control por la API funciona con el dominio `youtube-nocookie.com` (si no, cambiar `YT_EMBED_HOST`).
2. Precisión de la pausa en un móvil Android de gama media.
3. Qué devuelve la API durante un anuncio: la protección por duración es una hipótesis basada en un informe antiguo de Mozilla.
4. Si al reanudar por código tras la pausa el navegador lo permite siempre; si no, la app ya pide pulsar ▶.
5. Marcar el clip Ding–Gukesh y enseñárselo a tres o cuatro personas: ¿responden o siguen viendo?

## 11. Archivos

| Pieza | Dónde |
| --- | --- |
| Modelo, respuestas y director | `src/core/videoCine.ts` |
| Reproductor de YouTube | `src/ui/youtubePlayer.ts` |
| Cartelera, clip y editor de marcas | `src/ui/VideoCinema.tsx` |
| Marcas locales | `src/app/clipMarks.ts` |
| Fuentes de los clips | `pipeline/video-clips.ts` |
| Comprobación y paquete | `pipeline/build-video-cine.ts` → `src/data/videocine.pack.json` (10 KB), informe en `data/dev/videocine-report.json` |
| Análisis compartido | `pipeline/cine-engine.ts` |
| Pruebas | `tests/videoCine.test.ts` (24), `scripts/e2e-videocine.mjs` (Chrome con la API de YouTube simulada) |

```bash
npx tsx pipeline/build-video-cine.ts                          # comprueba los clips y escribe el paquete
npm run build:single && node scripts/e2e-videocine.mjs        # prueba en navegador (reproductor simulado)
```

### Primer clip: Ding Liren – Gukesh, Mundial 2024, partida 14

Partida cotejada jugada a jugada en dos fuentes ([Wikipedia](https://en.wikipedia.org/wiki/World_Chess_Championship_2024) y [ChessBase India](https://hindi.chessbase.in/news/World-Championship-2024-diaries-Game-14-by-GM-Sundararajan-Kidambi)) y reproducida entera (116 medias jugadas).

| Pregunta | Jugada de la partida | Stockfish (prof. 24) |
| --- | --- | --- |
| Tras 55.Tf2 | 55…Txf2 | Única que gana (+6,8). Las otras 23 jugadas no ganan |
| Tras 56.Rxf2 | 56…Ad5 | Única que gana (+6,1). Las otras 11 dan 0,00 |
| Tras 58.Re3 | 58…Re5 | Única que gana (+5,8). Rd6 y Re6 son tablas; el resto pierde |

Antes de 55.Tf2 el motor mantiene las tablas con Ta4, Ag2, Tf1 o Ac6 (entre −0,3 y −0,5 a profundidad 24). Sin prueba de mate: haría falta Syzygy de 5 piezas, inaccesible desde este entorno.

Hechos de los textos: fecha, lugar, marcador 7,5–6,5 y campeón más joven con 18 años, según [FIDE](https://www.fide.com/fide-world-championship-game-14-gukesh-d-claims-title/).

## 12. Web de pruebas

El flujo `.github/workflows/pages.yml` construye el prototipo en cada empuje a `cine-video` (tras pasar los tests) y lo deja en la rama `gh-pages`. **La web solo se hace pública cuando el dueño del repositorio activa Pages:** Settings → Pages → Build and deployment → Source «Deploy from a branch» → rama `gh-pages`, carpeta `/ (root)`. Dirección esperada: `https://pabloprietorecio-afk.github.io/Chesssome-/` (enlace directo al cine: `…/#cine`).

- El cine se abre sin hacer el test de nivel (botón en la bienvenida o `#cine`).
- En el editor de marcas, «Diagnóstico» muestra la versión publicada, el dominio del reproductor y su estado, y permite cambiar a `youtube.com` si `youtube-nocookie.com` diera problemas.
- La CI de esta rama publica las capturas del 3D en `ci-shots-cine-video`, como hace `tablero-v2`, para no pisar `ci-shots`.

**Primera prueba en el móvil (13 nov, Pablo):** la web carga y el reproductor de YouTube aparece desde `youtube-nocookie.com`. El cartel negro sin botón parecía un vídeo que no cargaba: ahora lleva un ▶ que carga el vídeo aunque no haya marcas.

**Prueba en el móvil, por orden:**
1. Abrir el cine y el clip; pulsar «Ir directo a la pregunta», responder y «Ver cómo ocurrió en el vídeo». Comprueba que el vídeo carga y se controla.
2. «Editor de marcas» → «Cargar el vídeo» → ▶. Pulsar «= ahora» en inicio, justo antes de 55…Txf2 y en el final. «Probar» la pausa. «Guardar en este dispositivo».
3. Volver al clip → «Ver el vídeo: se para antes de la jugada». Debe pararse solo.
4. «Copiar las marcas» y pegarlas en el chat para dejarlas en `pipeline/video-clips.ts` con `marks: 'verified'`.

## 13. Películas generadas (aparcadas)

Cuatro películas sin vídeo (oposición, Saavedra 1895, Lucena, Philidor) con filtro de cine antiguo, rótulos y pausas, comprobadas con Stockfish. Siguen en el código y con sus tests, pero fuera de la cartelera. Se ven con el interruptor de desarrollo `localStorage['chessome.dev.generatedFilms'] = '1'`.

- Fuentes: `pipeline/cine-films.ts`; comprobación: `pipeline/build-cine.ts`; núcleo: `src/core/cinema.ts`; pantalla: `src/ui/Cinema.tsx`; prueba: `scripts/e2e-cine.mjs`.
- Reglas: toda jugada del protagonista mantiene el resultado según el motor; las del rival quedan cerca de su mejor defensa; en cada pausa se analizan todas las jugadas; las victorias llevan mate forzado encontrado; las tablas se anuncian como «según el motor».
- Encajan con el vídeo: tras el clip Ding–Gukesh, que acaba con la oposición, se puede ofrecer la película «La oposición».

### Derechos de partidas y estudios (investigado el 13 nov 2026)

- **EE. UU.:** un tribunal federal de Nueva York resolvió en 2016 que las jugadas son hechos y no están protegidas. **Europa:** sin zanjar por falta de jurisprudencia. Fuente: [IPI, Suiza](https://ige.ch/en/blog/blog-article/schach-und-urheberrecht-eine-verlorene-partie).
- **Alemania:** un juez rechazó que una partida sea una base de datos (Federación Búlgara contra ChessBase). [Chess.com](https://www.chess.com/news/view/bulgarian-chess-federation-vs-chessbase-0-1). Tribunal y referencia, sin verificar.
- **Bases de datos (UE):** protegidas frente a la extracción de partes sustanciales. No copiar partidas en bloque de bases comerciales ni anotaciones ajenas.
- **Plazos en España:** autores fallecidos antes del 7-12-1987, vida + 80 años; después, vida + 70. [Legal Today](https://www.legaltoday.com/practica-juridica/derecho-civil/nuevas-tecnologias-civil/la-proteccion-en-espana-de-las-obras-de-autores-europeos-fallecidos-antes-de-1987-2015-07-13/).
- **Saavedra:** publicada por Barbier en 1895; Saavedra murió en 1922. [Tim Krabbé](https://timkr.home.xs4all.nl/chess2/prynd.htm).
- **Sin verificar:** si los estudios compuestos son obra protegida en la UE; la fecha de muerte de Barbier.
- Consultar con un abogado antes de publicar comercialmente partidas históricas o estudios.
