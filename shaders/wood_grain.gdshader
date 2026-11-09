shader_type canvas_item;
render_mode unshaded;

uniform vec2 panel_size = vec2(1.0);
uniform float corner_radius = 7.0;
varying vec2 local_position;

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	float radius = min(corner_radius, min(panel_size.x, panel_size.y) * 0.5);
	vec2 p = abs(local_position - panel_size * 0.5) - (panel_size * 0.5 - vec2(radius));
	float distance_to_edge = length(max(p, vec2(0.0))) + min(max(p.x, p.y), 0.0) - radius;
	COLOR = texture(TEXTURE, UV) * COLOR;
	COLOR.a *= 1.0 - smoothstep(-2.0, -1.0, distance_to_edge);
}
