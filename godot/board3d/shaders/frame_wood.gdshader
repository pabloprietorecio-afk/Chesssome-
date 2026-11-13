shader_type spatial;
// Marco del tablero del acabado realista: madera oscura con la veta a lo largo de cada lado y las esquinas
// a inglete. La malla del marco no tiene coordenadas de textura: se usan las del propio modelo.

uniform sampler2D wood : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 tint : source_color = vec3(0.7);
uniform float grain = 0.22;
uniform float rough : hint_range(0.0, 1.0) = 0.3;
uniform float coat : hint_range(0.0, 1.0) = 0.4;

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	// La veta de la textura corre a lo largo de V.
	vec3 a = texture(wood, vec2(lp.x + lp.y, lp.z) * grain).rgb;
	vec3 b = texture(wood, vec2(lp.z + lp.y, lp.x) * grain + vec2(0.37, 0.11)).rgb;
	float along_z = step(abs(lp.z), abs(lp.x));
	vec3 col = mix(b, a, along_z) * tint * COLOR.rgb;
	// Inglete: una línea fina en la diagonal de cada esquina.
	float mitre = abs(abs(lp.x) - abs(lp.z));
	col *= mix(0.55, 1.0, smoothstep(0.004, 0.018, mitre));
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.5;
	CLEARCOAT = coat;
	CLEARCOAT_ROUGHNESS = 0.1;
}
