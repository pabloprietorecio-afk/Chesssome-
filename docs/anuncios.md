# Anuncios y paquete para Play (AAB)

## Reglas de producto (Pablo, 16 nov)
- **Nunca en Kids**, ni en el cine (YouTube), ni en el reloj, ni en mitad de una partida, problema o lección.
- Solo **entre actividades**: se intenta al abrir el inicio. El primero tras 10 min de uso real; luego uno cada 8 min como mínimo; 6 por sesión como máximo (`godot/data/ads.json`).
- Formato: solo **intersticial**. Sin banners ni vídeos recompensados.
- Todas las peticiones salen con **tratamiento dirigido a niños y contenido G** (`core/ads_admob.gdtxt`): la app es de público mixto y no tiene pantalla de edad. Consecuencia: sin anuncios personalizados y menos ingresos. Si se quisiera personalizar para adultos, hace falta una pantalla de edad neutra (Play lo exige en apps de público mixto).

## Cómo está montado
- `core/ads.gd`: reglas (cuándo toca) y arranque. Sin plugin no hace nada (tests, escritorio, web).
- `core/ads_admob.gdtxt`: puente con el plugin. **Se llama `.gdtxt` a propósito**: usa las clases del plugin y no compilaría sin él. La CI lo copia a `core/ads_admob.gd` tras instalar el plugin.
- Plugin: [poingstudios/godot-admob-plugin](https://github.com/poingstudios/godot-admob-plugin) v5.1.0 (MIT), fijado por commit; las librerías de Android (`android-template-v4.7.2.zip`), por suma SHA-256. Usa el SDK «Next-Gen» de Google Mobile Ads 1.4.0.
- Consentimiento (UMP): se pide el formulario solo si Google lo marca como necesario (UE/Reino Unido). Sin consentimiento resuelto, no se piden anuncios.

## Para publicar
1. **IDs de AdMob**: `godot/data/ads.json` lleva los IDs de PRUEBA de Google. Poner el ID de la app (`ca-app-pub-…~…`) y el del bloque intersticial (`ca-app-pub-…/…`). La CI avisa mientras sean los de prueba.
2. Secretos del repositorio (Settings → Secrets and variables → Actions): `UPLOAD_KEYSTORE_B64`, `UPLOAD_KEYSTORE_PASSWORD`, `UPLOAD_KEY_ALIAS` (clave de subida; **nunca** en el repositorio).
3. La CI deja el AAB en el artefacto `AChessWay-play-aab` de la ejecución (30 días, hace falta iniciar sesión en GitHub).
4. En Play Console: Play App Signing (la clave de subida se puede restablecer si se pierde), público objetivo, declaración de anuncios, **ID de publicidad** (el plugin añade el permiso `AD_ID`; con tráfico siempre infantil el SDK no lo usa — decidir la declaración con la política vigente), seguridad de los datos, política de privacidad.

## Sin verificar
- El plugin **no se ha probado en un móvil** ni en esta CI hasta el primer APK con él.
- Si Play acepta «público mixto» sin pantalla de edad con todo el tráfico como infantil: revisar la política de Familias vigente al rellenar el formulario.
