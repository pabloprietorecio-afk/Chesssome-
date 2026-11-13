# Estilo 2D (inspirado en WakeAgenda)

Toda la interfaz 2D sigue el estilo de WakeAgenda (`ui/theme/Color.kt`, `ui/theme/Theme.kt`, `ui/components/Components.kt`, `ui/navigation/AppNav.kt`). El prototipo web ya lo aplica (`src/styles.css`, `src/App.tsx`, `src/ui/Board2D.tsx`); la versión Godot lo llevará a un `Theme` de Godot con los mismos valores.

## Tokens

| Token | Valor | Origen en WakeAgenda |
| --- | --- | --- |
| Fondo | `#F1F7FF` → `#E3EDF9` (degradado vertical) | `SkyBg` + `AppBackground` |
| Superficie (tarjetas) | `#FFFFFF` | `surface` |
| Tinte | `#EAF1FB` | `SurfaceTint` |
| Tinta | `#1B2540` | `Ink` |
| Tinta suave | `#5B6782` | `InkSoft` (`#66728C`) oscurecido: el original da 4,48:1 sobre el fondo |
| Contorno | `#D9E3F2` | `Outline` |
| Acento (relleno) | `#FF7A1A`, degradado `#FF9A2E → #FF5E1A` | `AccentPalette.Orange` |
| Acento suave | `#FFEBD9` | `softLight` |
| Acento como texto | `#B84A0C` (5,2:1 sobre blanco) | nuevo |
| Bien / mal / aviso (texto) | `#1F7A44` / `#C0392B` / `#8A5A00` | tonos oscuros de `Green`, `ErrorRed`, `Amber` |
| Bien / mal / aviso (relleno) | `#22A559` / `#E5484D` / `#F2A100` | `Green`, `ErrorRed`, `Amber` |
| Sombra de tarjeta | `0 6px 18px rgba(47, 91, 168, 0.18)` | `ShadowTint` (`#332F5BA8`) |
| Halo de botón | naranja al 40–55 % | `ButtonStyle.glow()` |

## Formas y componentes

- Tarjetas blancas, radio 28, sin borde, sombra azulada (`SoftCard`).
- Botón principal: píldora (radio 30), alto 60 en las acciones grandes y 52 en las normales, degradado naranja horizontal con halo (`BigButton`).
- Botón secundario: píldora con fondo de acento suave.
- Insignias de icono circulares de 44–48 px con fondo suave del color de la acción (`IconBadge`).
- Barra de secciones flotante abajo en el móvil: blanca, radio 32, sombra; icono de 26 px y etiqueta; cada sección con su color, como en `FloatingBar`.
- Tipografía sin serifa (Inter si está disponible), títulos en negrita con interletraje −1,5 %.
- Iconos propios de trazo de 2 px.

## Decisiones distintas de WakeAgenda (y por qué)

- **Texto de los botones naranjas en tinta, no en blanco.** El blanco sobre `#FF7A1A`–`#FF5E1A` da entre 2,6:1 y 3,1:1, por debajo del 4,5:1 que pide WCAG para texto normal; la tinta da entre 5,8:1 y 7,2:1. Alternativa si se prefiere el blanco: degradado más oscuro `#C4520C → #A84408` (≥ 4,6:1).
- **Colores de cada sección oscurecidos** para que el texto cumpla 4,5:1 sobre su fondo suave (comprobado).
- **Tablero «cielo»** (`#E6EEF8` / `#93A9C9`) a juego con el fondo. Última jugada en naranja, selección en violeta, flechas verde / rojo / violeta para que ninguna se confunda con las casillas azules.

## Pendiente para Godot

- Tema oscuro y los acentos alternativos de WakeAgenda (Océano, Bosque, Atardecer, Arena, Medianoche, Dorado).
- Comprobar el contraste de todos los temas en una prueba automática, como hace WakeAgenda con sus widgets.

## Fondos de escena: piezas de ajedrez bajo el tiempo del usuario

Idea de Pablo: como las cabeceras de eventos de WakeAgenda, pero con un paisaje hecho de piezas de ajedrez (torres como torreones, alfiles como agujas, peones como árboles o figuras, caballos como colinas) bajo el cielo de la hora y el tiempo reales.

### Qué se aprovecha de WakeAgenda

| Pieza | Archivo | Cómo se reutiliza |
| --- | --- | --- |
| Cliente y lector de MET Norway (símbolo → código WMO) | `weather/MetNorway.kt` | Port a GDScript con pruebas de oro (JSON de ejemplo → códigos esperados). |
| Salida y puesta del sol | `weather/SunTimes.kt` | Port directo (cálculo astronómico puro). |
| Tipos de cielo y paletas por hora | `ui/components/SkyEffects.kt` (`SkyKind`, `skyKindFor`), `WeatherScene.kt` (`sceneColors`), `SceneryHeader.kt` (`paletteFor`) | Port de los datos y reglas; los colores son de Pablo. |
| Efectos (estrellas, nubes, niebla, lluvia, nieve) | `ui/components/SkyEffects.kt` | Referencia de parámetros; en Godot se dibujan con `_draw()` y partículas. |
| Dibujo del paisaje | `ui/components/SceneryHeader.kt` | No se reutiliza: el paisaje de piezas es nuevo (fase de diseño 3D/arte). |

El código de WakeAgenda es Kotlin/Compose y Chessome es Godot: la lógica se porta, no se copia tal cual.

### Reglas

- **Dónde**: cabeceras y fondos de Hoy, Progreso, Ajustes y bienvenida. Detrás del tablero, como mucho un degradado de cielo suave; nunca piezas ni partículas detrás del tablero ni detrás de texto sin tarjeta.
- **Texto encima de la escena**: claro u oscuro según la escena (el `dark` de `SceneColors`).
- **Sin permiso de ubicación por defecto**: el cielo sigue la hora del dispositivo, sin red. El tiempo real se activa en Ajustes («Usar el tiempo de mi zona»).
- **Ubicación aproximada**: permiso `ACCESS_COARSE_LOCATION` solamente; coordenadas redondeadas a 2 decimales (~1 km) antes de enviarlas (MET admite hasta 4); se guardan solo en el dispositivo. Declararlo en la sección de seguridad de datos de Google Play (pendiente de revisar cómo clasificar el envío a MET Norway).
- **Sección infantil**: sin ubicación ni tiempo real; solo cielo por hora.
- **MET Norway** (condiciones de uso comprobadas en api.met.no/doc/TermsOfService):
  - User-Agent propio que identifique la app y un contacto (los genéricos, como `okhttp` o `Dalvik`, reciben 403).
  - Respetar `Expires` / `If-Modified-Since`; pedir como mucho cada 1–3 horas.
  - Atribución CC BY 4.0 visible: «Datos meteorológicos: MET Norway».
  - Si el tráfico crece mucho, sus condiciones exigen un proxy con caché propio.
- **Rendimiento y accesibilidad**: animaciones desactivables («Fondos animados»), respetar «reducir movimiento», y en modo minimalista solo el degradado.
- WakeAgenda usa también WeatherAPI.com con clave; Chessome no lo necesita y habría que revisar sus condiciones antes de usarlo.
