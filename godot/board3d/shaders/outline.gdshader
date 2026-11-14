shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;
// Contorno de las piezas («casco invertido»): la misma malla, engordada un poco a lo largo de sus normales y
// dibujada solo por sus caras traseras. Asoma por detrás de la pieza como una línea de grosor constante,
// así la silueta se lee sobre cualquier casilla y sobre el fondo.

uniform vec4 outline_color : source_color = vec4(0.16, 0.19, 0.31, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.48, 0.1, 1.0);
// Grosor en unidades del modelo (1 = una casilla).
uniform float width = 0.02;
// Por pieza: selección (0–1). La línea se vuelve del color de acento y engorda.
instance uniform float glow = 0.0;

void vertex() {
	VERTEX += NORMAL * width * (1.0 + glow * 0.8);
}

void fragment() {
	ALBEDO = mix(outline_color.rgb, glow_color.rgb, glow);
}
