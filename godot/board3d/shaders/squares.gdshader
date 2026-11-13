shader_type spatial;
// Las 64 casillas en un solo plano. Los resaltados (última jugada, selección, jaque) y las marcas de
// destino llegan en una textura de 8×8: así todo va en una sola llamada de dibujo y siempre alineado.

uniform vec4 light_sq : source_color = vec4(0.91, 0.94, 0.98, 1.0);
uniform vec4 dark_sq : source_color = vec4(0.56, 0.65, 0.79, 1.0);
uniform vec4 c_last : source_color = vec4(1.0, 0.6, 0.18, 1.0);
uniform vec4 c_select : source_color = vec4(0.49, 0.36, 0.98, 1.0);
uniform vec4 c_check : source_color = vec4(0.9, 0.28, 0.3, 1.0);
uniform vec4 c_hint : source_color = vec4(0.1, 0.14, 0.25, 1.0);
// R: 1 = origen de la última jugada, 2 = destino, 3 = seleccionada, 4 = rey en jaque.
// G: 1 = destino libre (punto), 2 = destino con captura (anillo).
uniform sampler2D state : filter_nearest, repeat_disable;
uniform float rough = 0.62;

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	vec2 q = vec2(lp.x + 4.0, 4.0 - lp.z);
	vec2 cell = clamp(floor(q), vec2(0.0), vec2(7.0));
	vec2 f = q - cell;
	bool dark = mod(cell.x + cell.y, 2.0) < 0.5;
	vec3 col = dark ? dark_sq.rgb : light_sq.rgb;
	// Bisel muy suave en el borde de cada casilla: da relieve sin estorbar.
	float edge = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
	col *= mix(0.9, 1.0, smoothstep(0.0, 0.045, edge));

	vec4 st = texelFetch(state, ivec2(cell), 0);
	int hi = int(st.r * 255.0 + 0.5);
	int mark = int(st.g * 255.0 + 0.5);
	float d = length(f - vec2(0.5));
	float aa = fwidth(d) * 1.2 + 0.002;
	if (hi == 1) {
		col = mix(col, c_last.rgb, 0.4);
	} else if (hi == 2) {
		col = mix(col, c_last.rgb, 0.58);
	} else if (hi == 3) {
		col = mix(col, c_select.rgb, 0.5);
	} else if (hi == 4) {
		col = mix(col, c_check.rgb, (1.0 - smoothstep(0.08, 0.66, d)) * 0.9);
	}
	if (mark == 1) {
		col = mix(col, c_hint.rgb, (1.0 - smoothstep(0.15 - aa, 0.15 + aa, d)) * 0.42);
	} else if (mark == 2) {
		float ring = smoothstep(0.38 - aa, 0.38 + aa, d) * (1.0 - smoothstep(0.47 - aa, 0.47 + aa, d));
		col = mix(col, c_hint.rgb, ring * 0.5);
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.3;
}
