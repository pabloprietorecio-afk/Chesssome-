# Compras en Google Play (Premium y recargas)

Qué hay (22 nov):

- **Gratis para todos**: las chapas de cada jugada (Stockfish) y el asistente. Las explicaciones («Explícamelo») y las
  preguntas al tutor, en las 5 primeras partidas con tutor (y un cupo de 40 en el servidor, como red).
- **Premium** (`premium_mensual`, suscripción mensual, 4,99 €): 300 explicaciones o preguntas al mes y el rival
  «Experto» (Stockfish).
- **Recarga** (`explicaciones_100`, producto de compra única consumible, 1,99 €): 100 explicaciones más, que no
  caducan.

Cómo funciona:

1. La app (complemento `PagosGoogle.java`, Play Billing Library 8.3.0) abre la compra de Google Play.
2. La compra pagada va al servidor (`/premium/alta` o `/premium/recarga`), que la **verifica con Google** (Android
   Publisher API) y apunta el cupo en la cuenta anónima del móvil (`worker/src/cuentas.js`, un Durable Object por
   cuenta). La app nunca se da a sí misma por Premium.
3. Después la app reconoce la suscripción o consume la recarga (si no, Google la devuelve a los 3 días).
4. Cada explicación o pregunta gasta una del cupo; si falla, se devuelve. Sin cupo, el servidor contesta 402 y la app
   ofrece Premium o una recarga.

## Lo que tiene que hacer Pablo (una vez)

### 1. Productos en Play Console

Play Console → A Chess Way → **Monetizar** → Productos:

- **Suscripciones** → Crear suscripción: ID `premium_mensual`, nombre «A Chess Way Premium». Añadir un **plan base**
  de renovación automática **mensual**, precio 4,99 € (Play calcula el resto de países), y **activarlo**.
- **Productos de compra única** → Crear producto: ID `explicaciones_100`, nombre «100 explicaciones», precio 1,99 €,
  y **activarlo**.

Los ID tienen que ser exactamente esos.

### 2. Cuenta de servicio para que el servidor verifique las compras

1. En Google Cloud Console (el mismo proyecto que Play Console usa, o uno nuevo): **APIs y servicios → Biblioteca**,
   activar **Google Play Android Developer API**.
2. **IAM → Cuentas de servicio** → Crear cuenta de servicio (p. ej. `pagos-achessway`). Sin roles de Cloud.
3. En esa cuenta → **Claves → Añadir clave → JSON**. Se descarga un archivo `.json`. **No lo pegues en ningún chat.**
4. Play Console → **Usuarios y permisos → Invitar usuario**: el correo de la cuenta de servicio
   (`…@….iam.gserviceaccount.com`), con permiso de la app A Chess Way: **Ver información financiera** y
   **Gestionar pedidos y suscripciones**.
5. GitHub → repositorio → Settings → Secrets and variables → Actions → **New repository secret**: nombre
   `GOOGLE_PLAY_SA`, valor: el contenido completo del `.json`.
6. Volver a desplegar el servidor (Actions → «Servidor del profesor IA» → Run workflow). El paso «Cuenta de servicio
   de Google Play» la sube como secreto de Cloudflare.

Google puede tardar **hasta 24–36 h** en dar acceso a una cuenta de servicio recién invitada: mientras, la
verificación devuelve error y la app dice que lo volverá a intentar (no se cobra dos veces).

### 3. Probar sin pagar

Play Console → **Configuración → Pruebas de licencias**: añadir tu cuenta de Google. Con ella, las compras de la app
instalada desde Play (prueba interna) usan tarjetas de prueba y no cobran. Las suscripciones de prueba se renuevan
cada pocos minutos.

### 4. Cuando todas las versiones de la app manden la cuenta

`worker/wrangler.toml` → `REQUIRE_ACCOUNT = "1"`: el servidor dejará de dar explicaciones a versiones antiguas de la
app sin cupo (hoy las deja pasar para no romperlas).
