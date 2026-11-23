shader_type canvas_item;
// «Foto viva» del Campeonato (ui/campeonato_ui.gd): cada punto de la foto se desplaza según su profundidad
// (depth_tex: blanco = cerca; tools/campeonato/profundidad.py), como si la cámara se moviera un poco. Lo que está a
// la profundidad `focus` no se mueve; lo de delante y lo de detrás, en sentidos contrarios.

uniform sampler2D depth_tex : filter_linear, repeat_disable;
uniform vec2 shift = vec2(0.0);
uniform float focus = 0.5;

void fragment() {
	vec2 uv = UV;
	// Unas pocas pasadas: el punto que se ve donde estaba otro, sin dejar huecos en los bordes de las figuras.
	for (int i = 0; i < 3; i++) {
		float d = texture(depth_tex, uv).r;
		uv = UV - shift * (d - focus);
	}
	COLOR = texture(TEXTURE, clamp(uv, vec2(0.002), vec2(0.998)));
}
