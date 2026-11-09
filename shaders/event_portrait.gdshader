shader_type canvas_item;

// Kleines freistehendes Bild mit abgerundeter, weich auslaufender Kontur.
uniform vec2 rect_size = vec2(400.0, 100.0);
varying vec2 shape_uv;

void vertex() {
	shape_uv = VERTEX / max(rect_size, vec2(1.0));
}

void fragment() {
	float aspect = rect_size.x / max(rect_size.y, 1.0);
	vec2 p = (shape_uv - vec2(0.5)) * vec2(aspect, 1.0);
	float radius = 0.22;
	vec2 q = abs(p) - (vec2(aspect * 0.5, 0.5) - vec2(radius));
	float distance_to_edge = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
	COLOR.a *= 1.0 - smoothstep(-0.012, 0.012, distance_to_edge);
}
