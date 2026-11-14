shader_type spatial;
// Las 64 casillas de los acabados realistas (madera, mármol, metal): dos materiales con textura fotográfica.
// Cada casilla es un trozo distinto del material (otro sitio de la tabla o de la losa), con una junta fina
// entre casillas. Los resaltados y las marcas llegan en la misma textura de estado de 8×8 que en el estilo ilustrado.

uniform sampler2D light_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dark_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D light_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D dark_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec3 light_tint : source_color = vec3(1.0);
uniform vec3 dark_tint : source_color = vec3(1.0);
// Parte de la textura que ocupa una casilla.
uniform float light_grain = 0.2;
uniform float dark_grain = 0.16;
// 1 = la textura se gira un cuarto de vuelta (para igualar el sentido de la veta, o para cruzar el cepillado).
uniform float light_turn = 0.0;
uniform float dark_turn = 0.0;
uniform float rough : hint_range(0.0, 1.0) = 0.3;
uniform float coat : hint_range(0.0, 1.0) = 0.4;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float normal_depth = 0.6;
// Cuánto se oscurece la junta entre casillas (0 = no se ve).
uniform float joint_dark : hint_range(0.0, 1.0) = 0.5;
uniform vec4 c_last : source_color = vec4(1.0, 0.62, 0.12, 1.0);
uniform vec4 c_select : source_color = vec4(0.96, 0.8, 0.2, 1.0);
uniform vec4 c_check : source_color = vec4(0.86, 0.16, 0.14, 1.0);
uniform vec4 c_hint_dark : source_color = vec4(0.16, 0.09, 0.05, 1.0);
uniform vec4 c_hint_light : source_color = vec4(0.98, 0.93, 0.8, 1.0);
// R: 1 = origen de la última jugada, 2 = destino, 3 = seleccionada, 4 = rey en jaque.
// G: 1 = destino libre (punto), 2 = destino con captura (anillo).  B: 255 = casilla ocupada.
uniform sampler2D state : filter_nearest, repeat_disable;

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 q = vec2(lp.x + 4.0, 4.0 - lp.z);
	vec2 cell = clamp(floor(q), vec2(0.0), vec2(7.0));
	vec2 f = q - cell;
	bool dark = mod(cell.x + cell.y, 2.0) < 0.5;
	vec2 offset = vec2(hash(cell), hash(cell + vec2(17.3, 3.1)));
	float flip = hash(cell + vec2(5.1, 9.2)) < 0.5 ? -1.0 : 1.0;
	// Las derivadas se toman de la coordenada continua: así el nivel de detalle no salta en las juntas.
	vec2 dx = dFdx(q);
	vec2 dy = dFdy(q);
	vec3 col;
	vec3 nm;
	vec2 base = vec2(f.x * flip, f.y);
	if (dark) {
		bool turn = dark_turn > 0.5;
		vec2 uv = (turn ? base.yx : base) * dark_grain + offset;
		vec2 gx = (turn ? dx.yx : dx) * dark_grain;
		vec2 gy = (turn ? dy.yx : dy) * dark_grain;
		col = textureGrad(dark_tex, uv, gx, gy).rgb * dark_tint;
		nm = textureGrad(dark_normal, uv, gx, gy).rgb;
	} else {
		bool turn = light_turn > 0.5;
		vec2 uv = (turn ? base.yx : base) * light_grain + offset;
		vec2 gx = (turn ? dx.yx : dx) * light_grain;
		vec2 gy = (turn ? dy.yx : dy) * light_grain;
		col = textureGrad(light_tex, uv, gx, gy).rgb * light_tint;
		nm = textureGrad(light_normal, uv, gx, gy).rgb;
	}
	// Cada trozo tiene su tono.
	col *= 0.96 + 0.08 * hash(cell + vec2(9.7, 1.3));
	// Junta entre casillas.
	float edge = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
	float joint = 1.0 - smoothstep(0.004, 0.016, edge);
	col *= mix(1.0, 1.0 - joint_dark, joint);
	// El borde del tablero se oscurece un poco hacia el marco.
	float rim = min(min(q.x, 8.0 - q.x), min(q.y, 8.0 - q.y));
	col *= mix(0.72, 1.0, smoothstep(0.0, 0.08, rim));

	vec4 st = texelFetch(state, ivec2(cell), 0);
	int hi = int(st.r * 255.0 + 0.5);
	int mark = int(st.g * 255.0 + 0.5);
	float d = length(f - vec2(0.5));
	float aa = fwidth(d) * 1.2 + 0.002;
	if (hi == 1) {
		col = mix(col, c_last.rgb, 0.42);
	} else if (hi == 2) {
		col = mix(col, c_last.rgb, 0.6);
	} else if (hi == 3) {
		col = mix(col, c_select.rgb, 0.5);
	} else if (hi == 4) {
		col = mix(col, c_check.rgb, (1.0 - smoothstep(0.08, 0.68, d)) * 0.92);
	}
	// Sombra de contacto bajo cada pieza.
	if (st.b > 0.5) {
		col *= 1.0 - 0.34 * (1.0 - smoothstep(0.2, 0.52, d));
	}
	vec3 hint = dark ? c_hint_light.rgb : c_hint_dark.rgb;
	float hint_alpha = dark ? 0.6 : 0.42;
	if (mark == 1) {
		col = mix(col, hint, (1.0 - smoothstep(0.15 - aa, 0.15 + aa, d)) * hint_alpha);
	} else if (mark == 2) {
		float ring = smoothstep(0.38 - aa, 0.38 + aa, d) * (1.0 - smoothstep(0.47 - aa, 0.47 + aa, d));
		col = mix(col, hint, ring * (hint_alpha + 0.1));
	}
	ALBEDO = col;
	// Los resaltados y las marcas son pintura sobre el material: ahí no brilla como metal.
	float paint = (hi > 0 || mark > 0) ? 0.5 : 1.0;
	METALLIC = metallic * paint;
	ROUGHNESS = rough + joint * 0.25;
	SPECULAR = 0.5;
	CLEARCOAT = coat * (1.0 - joint);
	CLEARCOAT_ROUGHNESS = 0.1;
	NORMAL_MAP = nm;
	NORMAL_MAP_DEPTH = normal_depth;
}
