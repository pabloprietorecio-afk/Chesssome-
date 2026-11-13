shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
// Fondo: degradado vertical (como el fondo de la app) con un halo suave detrás del tablero.

uniform vec4 top_color : source_color = vec4(0.96, 0.98, 1.0, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.86, 0.91, 0.97, 1.0);
uniform vec4 halo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float halo = 0.35;

void fragment() {
	vec3 col = mix(top_color.rgb, bottom_color.rgb, UV.y);
	float r = length((UV - vec2(0.5, 0.46)) * vec2(1.0, 1.15));
	col = mix(col, halo_color.rgb, (1.0 - smoothstep(0.0, 0.55, r)) * halo);
	ALBEDO = col;
}
