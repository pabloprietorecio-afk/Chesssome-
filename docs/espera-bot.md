# Espera online con Robi, el bot

Petición de Pablo (21 nov 2026): al principio habrá pocos jugadores; que nadie se aburra esperando rival.
Decisión: **siempre se dice que es un bot**, pero se porta como un rival amable.

## Qué pasa
- Al buscar rival, pasado un tiempo sin partida se ofrece «Jugar contra Robi, un bot de la app», con la nota
  «Es un bot, no una persona». Se puede seguir esperando: la oferta no corta la búsqueda.
- El tiempo: `Online.bot_offer_s` → 15 s si no espera nadie en ningún otro espacio y 15 s más por cada jugador que
  espera en otro, hasta 2 minutos. Así, cuantos más jugadores, más se espera antes de ofrecer el bot.
- Si se acepta, se deja de buscar (no queda nadie esperando en el servidor) y empieza una partida normal contra el
  rival de la app: mismo ritmo y modalidad que el espacio, el nivel con el Elo más cercano al rating del jugador
  (`Bot.closest_level`), color al azar. Cuenta como partida contra el rival de la app, no como online.
- Trato (core/wait_bot.gd), con los gestos del chat online y siempre firmados «Robi (bot)»:
  saluda al empezar; a veces felicita una captura de pieza que no es un error («Bien»; «¡Genial!» si es la dama),
  como mucho una vez cada 4 jugadas; piensa entre 1,2 y 4 s (rápido en la apertura y con poco reloj);
  se despide con «Buena partida» (antes «¡Bravo!» si ganas).

## Pendiente
- Seguir buscando rival en segundo plano mientras se juega contra Robi y avisar si entra alguien. Hace falta probarlo
  contra Firebase (el que espera confirma `listo`), por eso no está.
- Que Robi conteste a los gestos del jugador (hoy la fila de gestos solo sale en partidas online).
- Textos nuevos sin traducir.

## Pruebas
`godot/tests/test_espera_bot.gd`, en la CI.
