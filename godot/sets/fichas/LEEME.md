# Colección «Fichas»

Fichas planas con el icono de cada pieza en bajorrelieve. Todo se genera con código propio
(`node tools/pieces/fichas.mjs`): no hay modelos ni dibujos de terceros.

- `token.glb` — la ficha, la misma para todas las piezas.
- `iconos.bin` — atlas de 3 × 2 iconos (peón, caballo, alfil / torre, dama, rey). Es un PNG de **datos**, no una
  imagen pintada: cada punto guarda hacia dónde mira el relieve (rojo y verde), la distancia al contorno (azul)
  y la sombra de los recovecos (alfa). Lleva otra extensión para que Godot no lo trate como textura y lo
  comprima con pérdida; la app lo carga tal cual (`Board3D._load_icons`).

Los iconos son las piezas de la colección «Clásico de autor» vistas de perfil (el rey, de frente, para que se
vea la cruz) y algo ensanchadas, como en los diagramas impresos. El material de la ficha
(`board3d/shaders/piece_token.gdshader`) talla el icono con la luz de la escena: el cuerpo es del material de
su bando y el icono, del material del bando contrario.
