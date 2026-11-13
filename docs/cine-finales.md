# Cine de finales (pendiente; después de las piezas 3D)

Idea de Pablo: ver dentro de la app los mejores finales como si fueran películas antiguas, en blanco y negro.

## Por qué no vídeos ya grabados

- **Vídeos de YouTube**: se pueden incrustar con el reproductor oficial, pero sus normas prohíben modificarlo o taparlo con capas, así que no se pueden mostrar en blanco y negro ni con efecto de película antigua. Solo valdrían tal cual (en color) o con un enlace «Ver en YouTube».
- **Descargar vídeos de terceros y alojarlos** en la app: infringe sus derechos salvo licencia expresa.
- **Grabaciones de archivo antiguas** (películas reales de partidas): habría que comprobar el dominio público de cada una. No verificado.

## Propuesta: películas generadas por la propia app

Cada «película» no es un archivo de vídeo, sino una partida o posición reproducida en el tablero de la app (2D o la colección 3D elegida) con un filtro de cine antiguo:

- **Filtro**: blanco y negro (o sepia suave), grano, rayas, viñeteado, parpadeo leve del proyector y un poco de vaivén de la imagen. En Godot, un shader de pantalla completa; en el modo minimalista y con «reducir movimiento», sin parpadeo ni vaivén.
- **Rótulos de cine mudo** entre jugadas con la idea clave («Las blancas construyen un puente…»), escritos por nosotros y comprobados con el motor como el resto de explicaciones.
- **Pausas para pensar**: la película se detiene en el momento clave y pregunta «¿Qué jugarías?»; al acertar o fallar se explica, como en los problemas.
- **Duración**: 30–90 segundos; se puede pasar jugada a jugada, rebobinar y saltar.
- **Peso**: una película son unas jugadas y unos rótulos (pocos KB), no megas de vídeo; funciona sin conexión y se traduce fácilmente.

## Contenido y derechos

| Tipo | Ejemplos | Derechos |
| --- | --- | --- |
| Finales teóricos (técnicas) | Lucena, Philidor, oposición, regla del cuadrado | Son técnicas, no obras: se pueden explicar libremente. Las líneas se generan y verifican con Stockfish y tablas de finales. |
| Finales de partidas históricas | Partidas de campeonatos del mundo antiguas | En EE. UU. la opinión mayoritaria es que las jugadas de una partida no tienen copyright, pero no está zanjado por tribunales y en la UE no lo he verificado; las anotaciones y las colecciones sí pueden tenerlo, y en la UE existe además el derecho sobre bases de datos. Tomar las partidas de fuentes con licencia libre y escribir comentarios propios. Consultar con un abogado antes de publicar. |
| Estudios compuestos | Saavedra (1895), Réti (1921) | Los estudios pueden protegerse como obras. Los antiguos probablemente estén ya en dominio público por la fecha de muerte del autor, pero hay que comprobarlo caso a caso. No verificado. |

## Orden

1. Piezas y tablero 3D (siguiente fase, con el modelo Fable).
2. Cine de finales reutilizando ese tablero y sus piezas, más el shader de cine antiguo.
