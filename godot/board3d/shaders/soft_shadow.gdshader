shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// Sombra de contacto bajo el tablero: lo asienta sin necesidad de un suelo.

uniform vec4 shadow_color : source_color = vec4(0.12, 0.17, 0.32, 1.0);
uniform float strength = 0.34;
uniform float half_size = 4.35;
uniform float spread = 1.5;

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	vec2 d = max(abs(lp.xz) - vec2(half_size), vec2(0.0));
	float a = 1.0 - smoothstep(0.0, spread, length(d));
	ALBEDO = shadow_color.rgb;
	ALPHA = a * a * strength;
}
