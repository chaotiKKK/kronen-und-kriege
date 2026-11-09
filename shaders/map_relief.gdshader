shader_type canvas_item;
render_mode blend_mul;

// Die gebackene Blender-Schattierung wird als Multiplikator über die
// Provinzflächen gelegt. Dadurch bleiben Hue/Sättigung der Kartenmodi erhalten;
// nur die Helligkeit folgt dem Relief. Meer ist im Asset weiß.
uniform float strength : hint_range(0.0, 0.9) = 0.55;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float shade = clamp(1.0 - strength * (1.0 - tex.r), 0.0, 1.0);
	COLOR = vec4(shade, shade * 0.985, shade * 0.955, 1.0);
}
