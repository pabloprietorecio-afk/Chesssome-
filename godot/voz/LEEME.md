# Voz del nivel Kids

Un audio por frase (`<id>.ogg`, mono, 24 kHz). El id es un resumen del texto; el índice texto → id está en
`data/voz.json`. Los genera la CI con Kokoro-82M (pesos Apache-2.0, https://huggingface.co/hexgrad/Kokoro-82M),
voz `ef_dora`: ver `docs/kids.md` y `.github/workflows/voz.yml`. No editar a mano.
