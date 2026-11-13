shader_type sky;
// Entorno de estudio dibujado por código: no se ve (el fondo de la escena es un color liso), pero da la luz
// ambiente y los reflejos del acabado realista. Paredes claras, suelo cálido, techo oscuro y tres cajas de luz:
// la principal arriba y hacia el jugador, una ancha y alta hacia el fondo (el brillo suave del barniz) y dos
// tiras bajas detrás (el filo luminoso de las piezas).

uniform float intensity = 1.0;
uniform vec3 wall_color : source_color = vec3(0.62, 0.65, 0.7);
uniform vec3 floor_color : source_color = vec3(0.3, 0.25, 0.2);
uniform vec3 ceiling_color : source_color = vec3(0.1, 0.11, 0.14);
uniform vec3 key_color : source_color = vec3(1.0, 0.96, 0.9);
uniform float key_power = 9.0;
uniform float top_power = 3.2;
uniform float rim_power = 4.5;

// Caja de luz rectangular centrada en la dirección «c», con los bordes difuminados.
float softbox(vec3 d, vec3 c, vec3 side, vec2 half_size, float soft) {
	float t = dot(d, c);
	if (t <= 0.02) {
		return 0.0;
	}
	vec3 p = d / t - c;
	vec3 up = normalize(cross(c, side));
	vec2 q = abs(vec2(dot(p, side), dot(p, up)));
	vec2 a = vec2(1.0) - smoothstep(half_size - vec2(soft), half_size + vec2(soft), q);
	return a.x * a.y;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	vec3 col = mix(floor_color, wall_color, smoothstep(-0.3, 0.04, d.y));
	col = mix(col, ceiling_color, smoothstep(0.22, 0.85, d.y));
	// Franja clara en el horizonte: es lo que se refleja en el canto de las piezas.
	col += wall_color * 0.55 * (1.0 - smoothstep(0.0, 0.3, abs(d.y - 0.06)));
	// Luz principal: arriba, a la izquierda y del lado del jugador (+Z).
	vec3 key = normalize(vec3(-0.52, 0.72, 0.46));
	col += key_color * key_power * softbox(d, key, normalize(vec3(0.66, 0.0, 0.75)), vec2(0.34, 0.26), 0.1);
	// Caja ancha y alta hacia el fondo: su reflejo en el tablero es el brillo del barniz.
	vec3 top = normalize(vec3(-0.16, 0.86, -0.48));
	col += vec3(0.93, 0.96, 1.0) * top_power * softbox(d, top, vec3(1.0, 0.0, 0.0), vec2(0.5, 0.3), 0.22);
	// Dos tiras bajas detrás, a los lados.
	col += vec3(0.9, 0.95, 1.0) * rim_power * softbox(d, normalize(vec3(-0.82, 0.3, -0.5)), normalize(vec3(0.52, 0.0, -0.85)), vec2(0.12, 0.42), 0.08);
	col += vec3(1.0, 0.95, 0.88) * rim_power * 0.8 * softbox(d, normalize(vec3(0.84, 0.26, -0.48)), normalize(vec3(0.5, 0.0, 0.87)), vec2(0.12, 0.4), 0.08);
	COLOR = col * intensity;
}
