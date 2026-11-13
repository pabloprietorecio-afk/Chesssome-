shader_type spatial;
// Fichas planas (colección «Fichas»): el cuerpo es del material de su bando y, en la cara, va el icono de la
// pieza tallado en bajorrelieve con el material del bando contrario, para que contraste.
//
// El icono viene en un atlas de datos (tools/pieces/fichas.mjs), no en una imagen pintada:
//   rojo y verde  hacia dónde mira el relieve en cada punto (su normal, a derecha y arriba)
//   azul          distancia al contorno del icono (0,5 = el contorno; más = dentro)
//   alfa          sombra de los recovecos
// Con eso el relieve responde a la luz de la escena y el borde sale nítido a cualquier tamaño.

uniform sampler2D wood : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D inlay_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D icons : filter_linear_mipmap, repeat_disable;
// 1 = materiales con textura (acabados realistas); 0 = colores lisos (acabado ilustrado).
uniform float use_textures : hint_range(0.0, 1.0) = 1.0;
uniform vec3 tint : source_color = vec3(1.0);
uniform vec3 inlay_tint : source_color = vec3(0.2);
uniform float grain_scale = 0.3;
uniform float rough : hint_range(0.0, 1.0) = 0.34;
uniform float inlay_rough : hint_range(0.0, 1.0) = 0.3;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float inlay_metallic : hint_range(0.0, 1.0) = 0.0;
uniform float spec : hint_range(0.0, 1.0) = 0.5;
uniform float coat : hint_range(0.0, 1.0) = 0.35;
uniform float ao_amount : hint_range(0.0, 1.0) = 1.0;
uniform vec4 rim_color : source_color = vec4(0.75, 0.82, 1.0, 1.0);
uniform float rim_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 glow_color : source_color = vec4(1.0, 0.48, 0.1, 1.0);
uniform vec4 alert_color : source_color = vec4(0.9, 0.22, 0.2, 1.0);
// Medidas de la ficha (tools/pieces/fichas.mjs, TOKEN), en casillas.
uniform float icon_radius = 0.31;
uniform float field_radius = 0.343;
uniform float face_height = 0.152;
uniform float sd_range = 0.05;
// Cuánto se marca el relieve.
uniform float relief : hint_range(0.0, 2.0) = 1.0;
// Por pieza: resplandor de selección (0–1) y casilla del icono en el atlas (columna, fila).
instance uniform float glow = 0.0;
instance uniform vec2 icon_cell = vec2(0.0);
// Por pieza: aviso de jaque (0–1). La ficha tapa casi toda su casilla, así que el aviso va en la propia ficha.
instance uniform float alert = 0.0;

varying vec3 model_pos;
varying vec3 model_normal;
// Ejes del icono (derecha y arriba) en el espacio de la cámara.
varying vec3 icon_right;
varying vec3 icon_up;

void vertex() {
	model_pos = VERTEX;
	model_normal = NORMAL;
	icon_right = normalize((MODELVIEW_MATRIX * vec4(1.0, 0.0, 0.0, 0.0)).xyz);
	icon_up = normalize((MODELVIEW_MATRIX * vec4(0.0, 0.0, -1.0, 0.0)).xyz);
}

void fragment() {
	vec3 nm = normalize(model_normal);
	vec3 w = pow(abs(nm), vec3(4.0));
	w /= (w.x + w.y + w.z);
	vec3 p = model_pos * grain_scale;
	// Textura proyectada por los tres ejes, como en las demás piezas.
	vec3 body_tex = texture(wood, vec2(p.y, p.z + 0.21)).rgb * w.x
		+ texture(wood, vec2(p.x + 0.13, p.z + 0.61)).rgb * w.y
		+ texture(wood, vec2(p.y + 0.43, p.x + 0.37)).rgb * w.z;
	vec3 body = mix(vec3(1.0), body_tex, use_textures) * tint;
	// La incrustación solo se ve en la cara: basta la proyección desde arriba, con la veta cruzada.
	vec3 inlay_sample = texture(inlay_tex, vec2(p.z + 0.37, p.x + 0.53)).rgb;
	vec3 inlay = mix(vec3(1.0), inlay_sample, use_textures) * inlay_tint;

	// Cara de la ficha: el cuadro del icono, visto desde arriba (derecha = +X, arriba = −Z).
	vec2 q = vec2(model_pos.x, -model_pos.z) / icon_radius;
	vec2 cell_uv = clamp(vec2(q.x, -q.y) * 0.5 + 0.5, vec2(0.004), vec2(0.996));
	vec4 ic = texture(icons, (icon_cell + cell_uv) / vec2(3.0, 2.0));
	float on_face = step(0.6, nm.y) * step(face_height - 0.03, model_pos.y)
		* step(max(abs(q.x), abs(q.y)), 0.996) * step(length(model_pos.xz), field_radius);
	float sd = (ic.b - 0.5) * 2.0 * sd_range;
	float aa = clamp(fwidth(sd), 0.0004, 0.01);
	float inside = smoothstep(-aa, aa, sd) * on_face;
	// Un surco fino alrededor del icono separa los dos materiales.
	float groove = smoothstep(-0.02, -0.006, sd) * (1.0 - smoothstep(-aa, aa, sd)) * on_face;
	float cavity = mix(1.0, ic.a, inside);

	vec3 col = mix(body * (1.0 - 0.32 * groove), inlay, inside);
	float ao = mix(1.0, COLOR.r, ao_amount);
	col *= mix(0.5, 1.0, ao) * mix(0.5, 1.0, cavity);

	// Relieve: la normal del icono, en los ejes de la cara.
	vec2 tilt = (ic.rg * 2.0 - 1.0) * relief * inside;
	tilt *= min(1.0, 0.92 / max(length(tilt), 0.0001));
	vec3 base_normal = normalize(NORMAL);
	NORMAL = normalize(icon_right * tilt.x + icon_up * tilt.y + base_normal * sqrt(max(1.0 - dot(tilt, tilt), 0.02)));

	float fres = pow(1.0 - clamp(dot(base_normal, normalize(VIEW)), 0.0, 1.0), 3.0);
	col = mix(col, rim_color.rgb, fres * rim_amount);
	col = mix(col, alert_color.rgb, alert * 0.5 * (1.0 - inside));
	ALBEDO = col;
	METALLIC = mix(metallic, inlay_metallic, inside);
	ROUGHNESS = mix(rough, inlay_rough, inside);
	SPECULAR = spec;
	CLEARCOAT = coat;
	CLEARCOAT_ROUGHNESS = 0.12;
	AO = ao * mix(0.6, 1.0, cavity);
	AO_LIGHT_AFFECT = 0.4;
	EMISSION = glow_color.rgb * glow * fres * 0.7;
}
