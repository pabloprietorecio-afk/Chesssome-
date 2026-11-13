shader_type spatial;
// Material de las piezas: acabado mate tipo porcelana, con la oclusión horneada en el color de vértice
// y un contorno por fresnel que separa la pieza del fondo (oscurece el borde de las claras y aclara el
// de las oscuras), para que la silueta se lea sobre cualquier casilla.

uniform vec4 base_color : source_color = vec4(0.94, 0.9, 0.82, 1.0);
uniform vec4 rim_color : source_color = vec4(0.6, 0.54, 0.45, 1.0);
uniform float rim_amount : hint_range(0.0, 1.0) = 0.4;
uniform float rim_power : hint_range(0.5, 8.0) = 2.4;
uniform float rough : hint_range(0.0, 1.0) = 0.42;
uniform float spec : hint_range(0.0, 1.0) = 0.5;
uniform float ao_amount : hint_range(0.0, 1.0) = 1.0;
uniform vec4 glow_color : source_color = vec4(1.0, 0.48, 0.1, 1.0);
// Por pieza: resplandor de selección (0–1).
instance uniform float glow = 0.0;

void fragment() {
	float ao = mix(1.0, COLOR.r, ao_amount);
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), rim_power);
	vec3 col = base_color.rgb * mix(0.5, 1.0, ao);
	col = mix(col, rim_color.rgb, fres * rim_amount);
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = spec;
	AO = ao;
	AO_LIGHT_AFFECT = 0.3;
	EMISSION = glow_color.rgb * glow * (0.25 + 0.75 * fres);
}
