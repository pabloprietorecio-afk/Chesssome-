# Las otras jugadas del rival («¿por qué entrega la dama?»)

En el «paso a paso» de un problema y en «¿Por qué ha jugado eso el rival?», la respuesta del rival dentro de la solución
se explicaba con qué hace la jugada y, al final, «De todas sus jugadas, es la que más resiste». Pablo (17 nov 2026): un
jugador inexperto no entiende así por qué el rival entrega la dama. Además, la app no comprobaba esa frase: la
respuesta es la que eligió el motor de Lichess al generar el problema.

Desde el 17 nov, para cada respuesta del rival con pocas jugadas legales (2 a 7; casi siempre, salir de un jaque) se
cuenta **qué pasaba con cada una de las otras**, y solo se dice que la jugada hecha es la que menos pierde cuando lo es.

## De dónde sale cada cosa

| Qué | De dónde |
| --- | --- |
| Valoración y continuación de cada jugada del rival | **Stockfish** (el instalado: hoy Stockfish 16, profundidad 20), sin conexión: `tools/defensas/analizar.py` → `godot/data/defensas.json` (35 KB). El archivo dice motor y profundidad. |
| Mate, pieza que se come, clase de jaque, pieza que «cae haga lo que haga» | **El tablero**, en el móvil: `MoveWhy.alternatives_paras` (`godot/core/move_why.gd`) lo comprueba jugada a jugada antes de decirlo. |
| «Aguantaba más o menos igual», «queda todavía peor», «hay mate en N» | El motor (no se puede comprobar en el tablero). |

Regenerar los datos (unos 7 min): `python3 tools/defensas/analizar.py` (necesita `pip install chess` y un `stockfish`
en el PATH). Con un hilo, el resultado es el mismo cada vez.

## Qué se dice

Las otras jugadas se comparan con la de la solución (`DefenseData.compare`): **peor**, **parecida** (a menos de 1,5
peones, o de un cuarto de la valoración si es muy grande; o el mismo mate) o **mejor**.

- **Peores**, de la más castigada a la menos (hasta 3 párrafos entre todas; el resto, «Las demás jugadas tampoco eran
  mejores»). Para cada una se dice lo primero de esta lista que se cumpla:
  1. «Si Rh8, Dg7# es jaque mate.» (mate en 1, comprobado).
  2. «Si Rg8, llega el mate: Dh7+ Rf8 Dh8#.» (mate en 2 o 3: la línea del motor, comprobada hasta el mate).
  3. «Si Rd8, Txf8+ y hay mate en 4.» (hasta mate en 5; más lejos no se dice: no enseña nada).
  4. «Si De8, Txe8+ se come la dama rival de e8.» (captura que gana: vale más que la que come, o no se la recuperan).
  5. «Si Rh7, Cxf5+ es jaque descubierto y además ataca la dama rival de g7, que cae sin remedio.» El jaque puede
     ser «jaque», «jaque descubierto» o «jaque doble». «Cae sin remedio» se comprueba probando **todas** las
     respuestas: tras cualquiera, se la pueden comer con una pieza que vale menos, o gratis, o hay mate
     (`_falls`). Si la pieza ya estaba atacada antes: «…es jaque y después cae la torre rival de h7». Sin jaque:
     «Si X, Y ataca Z, que cae sin remedio» / «Si X, tras Y cae Z».
  6. «Si Rc3, Cxd3 y queda todavía peor.» (nada tan claro en el tablero: lo dice el motor).
- **Parecidas**: «Rh8 aguantaba más o menos igual: seguiría Cxf5+.» Las que tienen la misma continuación van juntas
  («Rd2 y Rf2 aguantaban…»). Si lo que seguiría es **la jugada siguiente de la solución, no se dice** (ya se verá en el
  paso siguiente y, mientras se resuelve, sería dar la respuesta). Con mate: «Con Rb1 el mate llegaba igual».
- **Por qué la jugada hecha**:
  - todas las demás peores → «Así que Rh7: de todas sus jugadas, es la que menos pierde.» / «…al menos se lleva tu
    caballo a cambio. Es lo que menos pierde.» / «…es lo que más retrasa el mate.»;
  - si no, y la jugada come algo que vale menos y se la comen a continuación → «Con Dxh6, al menos se lleva tu
    caballo a cambio de la dama.»;
  - si no, nada (no hay nada cierto que decir).
- **Mejor** (otra aguantaba claramente más): «Re6 aguantaba más: seguiría Txa7.», nada más, y la etiqueta deja de ser
  «Su mejor defensa» para ser «La jugada». Pasa en 2 de los 330 problemas (`orSss` y `OJS82`).

Cada párrafo se ve en el tablero: la posición tras la otra jugada (y su castigo), la otra jugada en violeta y, en rojo,
el jaque y el ataque.

## Mientras se resuelve: sin dar la respuesta

«¿Por qué ha jugado eso el rival?» se puede tocar antes de resolver. Hasta el 17 nov, la explicación del error del
rival acababa con «Pero es un error: permite Cxh6+ y, tras Dxh6, Dxh6»: **la solución entera**, y el problema contaba
como resuelto sin ayuda. Ahora, mientras el problema no está resuelto (`MoveWhy.explain(…, reveal = false)`; en la app,
`_why_reveal()`):

- el error del rival acaba en «Pero es un error. ¿Ves por qué?»;
- la jugada propia no anuncia la siguiente («La idea: tras…, llega…» se guarda para después);
- de las otras jugadas del rival no se dice qué «seguiría», ni que a la pieza que come se la comen después; y si el
  castigo de otra jugada es justo la jugada que hay que encontrar, solo se dice «Si Rc5, queda todavía peor».

Resuelto (o vista la solución), el «paso a paso» lo cuenta todo. `tests/test_por_que.gd`.

## El caso de la queja (problema `dekIo`)

19… f5? 20. Cxh6+ y el rival juega Dxh6. Pablo pensaba que, sin entregar la dama, había jaque doble y mate. Comprobado
con Stockfish (profundidad 28): **no hay mate**. Con Rh8, Cf7+ es jaque doble pero el rey vuelve a g8; Rh8 aguanta
igual que Dxh6 (+6,6 frente a +6,4). Con Rh7, Cxf5+ gana la dama. La app dice ahora:

1. «Tenía tres salidas: Dxh6, Rh8 y Rh7. Eligió Dxh6.»
2. «Si Rh7, Cxf5+ es jaque descubierto y además ataca la dama rival de g7, que cae sin remedio.»
3. «Rh8 aguantaba más o menos igual: seguiría Cxf5+.»
4. «Con Dxh6, al menos se lleva tu caballo a cambio de la dama.»

## Números (330 problemas, 17 nov)

- 374 respuestas del rival: 134 forzadas (una sola jugada), 240 con más de una.
- 158 con 2 a 7 jugadas, todas analizadas (392 jugadas alternativas: 197 peores, 194 parecidas, 1 mejor).
- 82 con más de 7 jugadas: no se guardan (siguen con «por qué no huye su pieza amenazada» o la frase genérica), salvo
  la única en que otra jugada aguantaba claramente más (`OJS82`). En las otras 81, la respuesta de la solución está
  entre las mejores, así que la frase genérica no miente.

## Límites

- Solo los problemas de la app (el análisis va con ellos). Las respuestas con muchas jugadas no tienen «otras jugadas».
- «Parecida» y «peor» dependen del motor y de la profundidad: en posiciones muy perdidas, medio peón no significa nada
  (por eso el margen crece con la valoración).
- La comprobación de «cae sin remedio» mira dos jugadas; si el rival, al responder, se lleva una pieza, no se afirma.

## Arreglo de paso: la torre en inglés

Al probar los idiomas salió un fallo antiguo: en inglés, japonés, indonesio e hindi (que usan las letras inglesas), una
jugada de torre metida en una frase («El rival ha jugado %s») salía como jugada de rey: «Rb1+» → «Kb1+». `Loc.t`
volvía a leer como española una jugada ya escrita en la notación del idioma. Arreglado en `core/i18n/loc.gd` (una
jugada suelta entra tal cual) y vigilado en `tests/test_defensas.gd`.
