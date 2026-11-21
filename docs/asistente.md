# Asistente (21 nov 2026)

Petición de Pablo: «Ya que tenemos IA, que el usuario pueda pedir cosas como “empieza una partida en nivel
intermedio”, “pon las fichas 3D de mármol e inclina el tablero 35 grados”, “busca qué partidas online hay activas”,
“mueve peón de rey dos pasos”… Cualquier cosa. Si no se puede hacer, le sugerirá qué opciones tiene y cómo hacerlo».

- **En la app**: botón flotante morado (destellos, o micrófono si el móvil puede escuchar) abajo a la derecha, en
  todas las pantallas menos Kids. Abre la misma ventana que las preguntas al tutor (texto, «Hablar», ideas). Si todo
  se hace sin más, la ventana se cierra sola y sale un aviso breve con lo que ha hecho; si hay algo que contar (las
  partidas online, o por qué no se ha podido), se queda abierta con la respuesta.
- **En el servidor** (`worker/src/assistant.js`, ruta `/asistente`, 20 por minuto por IP): Claude Haiku 5.5 con una
  lista fija de acciones (herramientas): empezar_partida, mover, cambiar_piezas, cambiar_material,
  inclinar_tablero, cambiar_tema, animaciones, ajuste, cambiar_idioma, abrir (pantallas), ver_partidas_online,
  accion_partida (pista, deshacer, explícamelo) y preguntar_tutor. Recibe el estado de la app (pantalla, ajustes,
  partida y, si toca mover, las jugadas legales «SAN=UCI»). El servidor valida nombres y valores (una jugada, solo si
  está en las legales) y la app vuelve a comprobarlo todo al ejecutarlo.
- No hace nada peligroso ni irreversible (rendirse, borrar el progreso): lo explica.
- «Partidas online activas»: lo que la app puede saber es quién espera rival, por ritmo (no las partidas en juego
  entre otros).
- Inclinación: 90 = desde arriba, 64 = normal, 36 = lo más tumbado; por debajo de 36 lo dice.
- Coste estimado: una llamada a Haiku por petición (~2.000 tokens de entrada por la lista de acciones): ~0,03
  céntimos.
- Pruebas: `worker/test.mjs` y `godot/tests/test_tutor.gd` (servidor simulado); el despliegue prueba una orden real.
