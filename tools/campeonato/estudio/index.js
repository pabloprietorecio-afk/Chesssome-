// Estudio de imágenes del modo Campeonato (temporal): genera una imagen con FLUX.2 [dev] de Workers AI.
// El flujo .github/workflows/campeonato-imagenes.yml lo despliega, lo usa y lo borra. Solo responde con la clave
// (secreto CLAVE) que el propio flujo crea en cada ejecución.
export default {
  async fetch(request, env) {
    if (request.method !== "POST" || request.headers.get("x-clave") !== env.CLAVE) return new Response("no", { status: 403 });
    const p = await request.json();
    if (p.video) {
      // Vídeo (PixVerse v6, a través de Cloudflare): la foto del rival como primer fotograma. Devuelve la URL del MP4.
      try {
        const out = await env.AI.run(p.modelo || "pixverse/v6", {
          prompt: String(p.prompt),
          negative_prompt: p.negative_prompt ? String(p.negative_prompt) : undefined,
          image_input: p.image ? `data:image/jpeg;base64,${p.image}` : undefined,
          duration: Number(p.duration || 5),
          aspect_ratio: String(p.aspect_ratio || "9:16"),
          quality: String(p.quality || "1080p"),
          generate_audio: false,
          seed: p.seed ? Number(p.seed) : undefined,
        });
        return Response.json(out);
      } catch (e) {
        return Response.json({ error: String(e?.message || e) }, { status: 502 });
      }
    }
    const form = new FormData();
    form.append("prompt", String(p.prompt));
    form.append("width", String(p.width || 1024));
    form.append("height", String(p.height || 1024));
    form.append("steps", String(p.steps || 25));
    if (p.seed) form.append("seed", String(p.seed));
    for (const [i, b64] of (p.refs || []).entries()) {
      const bytes = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
      form.append(`input_image_${i}`, new Blob([bytes], { type: "image/jpeg" }), `ref${i}.jpg`);
    }
    const body = new Response(form);
    try {
      const out = await env.AI.run(p.modelo || "@cf/black-forest-labs/flux-2-dev", {
        multipart: { body: body.body, contentType: body.headers.get("content-type") },
      });
      return Response.json({ image: out.image });
    } catch (e) {
      return Response.json({ error: String(e?.message || e) }, { status: 502 });
    }
  },
};
