# Tipografías

Inter e Inter Display 4.1.1 (The Inter Project Authors), bajo SIL Open Font License 1.1 (`OFL.txt`).

Archivos tomados sin modificar del paquete npm `inter-ui` 4.1.1 (subconjunto latino, carpetas `web-latin` y
`display-latin`); solo se han renombrado quitando el sufijo `-subset`.

## Idiomas (rama `idiomas`)

- Inter e Inter Display se han cambiado por los archivos completos del mismo paquete (`web/` y `display/` de
  `inter-ui` 4.1.1, sin el sufijo `-subset`): traen el cirílico (ruso) y el latín ampliado que faltaban en el
  subconjunto latino. Misma licencia (OFL 1.1).
- `NotoSansJP-Subset.ttf`: subconjunto de Noto Sans JP Medium (paquete npm `@expo-google-fonts/noto-sans-jp`
  0.4.4) con solo los caracteres japoneses que usa la app; lo genera `tools/i18n/fonts.py`. Copyright Adobe /
  The Noto Project Authors, licencia SIL OFL 1.1 (`OFL-NotoSans.txt`). Respaldo solo cuando el idioma es japonés.
- `NotoSansDevanagari-Medium.ttf`: Noto Sans Devanagari Medium, la misma que usa A Tank Story (paquete npm
  `@fontsource/noto-sans-devanagari`, convertida de WOFF a TTF sin cambios). Copyright 2022 The Noto Project
  Authors, licencia SIL OFL 1.1. Respaldo solo en hindi.

Caveat Bold (The Caveat Project Authors), SIL OFL 1.1 (`OFL-Caveat.txt`), del paquete npm `@fontsource/caveat`: solo para la nota manuscrita de la pantalla de inicio «Rejilla».
