shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
// Disco bajo la base de cada pieza: completa el contorno donde la pieza toca el tablero (ahí el casco
// invertido no asoma) y hace de tapa inferior cuando la pieza se vuelca.

uniform vec4 outline_color : source_color = vec4(0.16, 0.19, 0.31, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.48, 0.1, 1.0);
instance uniform float glow = 0.0;

void fragment() {
	ALBEDO = mix(outline_color.rgb, glow_color.rgb, glow);
}
