shader_type spatial;
// Piezas de madera torneada y barnizada (acabado realista): la textura de la madera se proyecta por los tres
// ejes de la pieza, con la veta en vertical; la oclusión viene horneada en el color de vértice y los brillos
// los pone el entorno de estudio.

uniform sampler2D wood : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 tint : source_color = vec3(1.0);
// Repeticiones de la textura por casilla de altura.
uniform float grain_scale = 0.3;
uniform float rough : hint_range(0.0, 1.0) = 0.34;
uniform float spec : hint_range(0.0, 1.0) = 0.5;
uniform float coat : hint_range(0.0, 1.0) = 0.35;
uniform float ao_amount : hint_range(0.0, 1.0) = 1.0;
uniform vec4 rim_color : source_color = vec4(0.75, 0.82, 1.0, 1.0);
uniform float rim_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 glow_color : source_color = vec4(1.0, 0.48, 0.1, 1.0);
// Por pieza: resplandor de selección (0–1).
instance uniform float glow = 0.0;

varying vec3 model_pos;
varying vec3 model_normal;

void vertex() {
	model_pos = VERTEX;
	model_normal = NORMAL;
}

void fragment() {
	vec3 w = pow(abs(normalize(model_normal)), vec3(4.0));
	w /= (w.x + w.y + w.z);
	vec3 p = model_pos * grain_scale;
	// La veta de la textura corre a lo largo de U: U es la altura de la pieza.
	vec3 along_x = texture(wood, vec2(p.y, p.z + 0.21)).rgb;
	vec3 along_z = texture(wood, vec2(p.y + 0.43, p.x + 0.37)).rgb;
	vec3 along_y = texture(wood, vec2(p.x + 0.13, p.z + 0.61)).rgb;
	vec3 col = (along_x * w.x + along_y * w.y + along_z * w.z) * tint;
	float ao = mix(1.0, COLOR.r, ao_amount);
	col *= mix(0.5, 1.0, ao);
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	col = mix(col, rim_color.rgb, fres * rim_amount);
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = spec;
	CLEARCOAT = coat;
	CLEARCOAT_ROUGHNESS = 0.12;
	AO = ao;
	AO_LIGHT_AFFECT = 0.4;
	EMISSION = glow_color.rgb * glow * (0.12 + fres * 0.75);
}
