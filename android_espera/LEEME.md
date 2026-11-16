# EsperaOnline: esperar rival con la app minimizada

En Android, cuando la app se minimiza, Godot deja de ejecutarse: la partida que espera rival dejaría de enviar su
latido (y caducaría a los 30 s) y nadie avisaría si entra alguien. Este complemento lo resuelve sin servidor:

- Mientras esperas rival en un espacio, un **servicio en primer plano** (aviso fijo «Esperando rival · 5+3», con el
  botón «Dejar de esperar») renueva cada 10 s el latido de `espera/<partida>` y mira cada 3 s si ya hay rival en
  `partidas/<partida>/rival`, con la sesión anónima de la app (la renueva si caduca).
- Si entra alguien con la app minimizada, avisa con «¡Rival encontrado!» y se para. Al tocar el aviso vuelves a la
  app; la partida empieza cuando vuelves (`listo`). Quien entró espera como mucho un minuto; si no vuelves, se va y
  sigue buscando, y tú vuelves a esperar.
- Si la app está a la vista, no hay aviso: la propia app ve entrar al rival.
- «Dejar de esperar» borra la partida en espera; al volver a la app, la búsqueda se da por terminada.
- Como mucho, dos horas esperando.

## Cómo se ven los avisos

- Icono pequeño: el caballo de la app en blanco (`res/drawable-*/ic_stat_achessway.png`, de `tools/ui/icons.mjs`),
  teñido del naranja de la marca (`#F26A1E`). Imagen grande: el icono de la app (`res/drawable-nodpi/
  ic_large_achessway.png`, de `tools/inicio/icono.py`). El CI copia `res/` en la plantilla de Gradle.
- «Esperando rival · 5+3»: fijo y silencioso (Android lo exige para seguir en segundo plano), con el tiempo que llevas
  esperando y los botones «Volver» y «Dejar de esperar».
- «¡Rival encontrado!»: emergente, con sonido y vibración; dice quién («Ana quiere jugar 5+3 contigo…», si puso
  nombre) y desaparece solo al minuto, cuando quien entró deja de esperarte. Botón «Jugar ahora».
- Textos en el idioma de la app (los pasa `core/online.gd`), también los nombres de los canales.

## Archivos

- `EsperaOnline.java`: el complemento de Godot (v2), `Engine.get_singleton("EsperaOnline")`: `start(datos)`,
  `stop()`, `state()`, `clearState()`. Lo usa `godot/core/online.gd`.
- `EsperaService.java`: el servicio (tipo `dataSync`).
- `godot/addons/espera_online/`: complemento del editor que, al exportar con Gradle, añade al manifiesto los permisos
  `FOREGROUND_SERVICE` y `FOREGROUND_SERVICE_DATA_SYNC`, el servicio y el registro del complemento. El permiso de
  avisos (`POST_NOTIFICATIONS`) lo declara el complemento de notificaciones del mismo APK; la app lo pide al empezar
  a esperar (Android 13 o más).

## Compilación

Solo en el **APK con avisos** (CI, trabajo `apk-avisos`): el CI copia estos `.java` en la plantilla de Gradle, junto a
`GodotApp.java`, activa `res://addons/espera_online` y comprueba que el APK lleva las clases y el manifiesto. En el APK
normal (sin Gradle) no existe el complemento: si minimizas, la espera se para hasta que vuelves.

## Antes de Google Play

Google Play pide declarar el uso de servicios en primer plano (tipo `dataSync`) en la ficha de la app, con un vídeo
de cómo se usa. Desde Android 15, los de tipo `dataSync` tienen un límite de 6 horas al día.
