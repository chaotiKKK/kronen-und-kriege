extends Control
## Vektor-Fallback für fehlende Ereignisbilder. Zeichnet eine stilisierte
## Burgenlandschaft ohne Textur, damit das Panel nie leer bleibt.

const SKY_TOP := Color(0.20, 0.18, 0.24)
const SKY_BOTTOM := Color(0.56, 0.39, 0.27)
const HILL_FAR := Color(0.27, 0.28, 0.28)
const HILL_NEAR := Color(0.19, 0.23, 0.20)
const STONE := Color(0.35, 0.32, 0.28)
const STONE_LIGHT := Color(0.53, 0.48, 0.39)
const WINDOW := Color(0.94, 0.68, 0.30)
const FLAG := Color(0.60, 0.16, 0.13)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w <= 1.0 or h <= 1.0:
		return
	# Himmel als horizontale Farbbänder
	for i in 8:
		var t: float = float(i) / 7.0
		draw_rect(Rect2(0.0, h * t, w, h / 7.0 + 1.0),
			SKY_TOP.lerp(SKY_BOTTOM, t), true)
	# Tief stehende Sonne
	draw_circle(Vector2(w * 0.78, h * 0.30), h * 0.105, Color(0.86, 0.66, 0.33))
	draw_circle(Vector2(w * 0.78, h * 0.30), h * 0.16, Color(0.86, 0.66, 0.33, 0.12))
	# Ferne und nahe Hügel
	draw_colored_polygon(PackedVector2Array([
		Vector2(0.0, h * 0.58), Vector2(w * 0.18, h * 0.43),
		Vector2(w * 0.38, h * 0.54), Vector2(w * 0.57, h * 0.40),
		Vector2(w * 0.78, h * 0.55), Vector2(w, h * 0.45),
		Vector2(w, h), Vector2(0.0, h),
	]), HILL_FAR)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0.0, h * 0.72), Vector2(w * 0.24, h * 0.56),
		Vector2(w * 0.50, h * 0.68), Vector2(w * 0.74, h * 0.54),
		Vector2(w, h * 0.66), Vector2(w, h), Vector2(0.0, h),
	]), HILL_NEAR)
	# Burg auf dem mittleren Hügel
	var base_y: float = h * 0.61
	var left: float = w * 0.39
	var right: float = w * 0.61
	draw_rect(Rect2(left, base_y - h * 0.14, right - left, h * 0.20), STONE, true)
	draw_rect(Rect2(left - w * 0.035, base_y - h * 0.26, w * 0.06, h * 0.32), STONE_LIGHT, true)
	draw_rect(Rect2(right - w * 0.025, base_y - h * 0.24, w * 0.06, h * 0.30), STONE_LIGHT, true)
	draw_rect(Rect2(w * 0.47, base_y + h * 0.015, w * 0.06, h * 0.07), Color(0.08, 0.07, 0.07), true)
	# Zinnen
	for i in 4:
		var x: float = left + (right - left) * float(i) / 4.0
		draw_rect(Rect2(x, base_y - h * 0.17, (right - left) / 8.0, h * 0.035), STONE, true)
	# Fenster und Fahne
	draw_rect(Rect2(w * 0.455, base_y - h * 0.09, w * 0.012, h * 0.035), WINDOW, true)
	draw_rect(Rect2(w * 0.535, base_y - h * 0.085, w * 0.012, h * 0.032), WINDOW, true)
	draw_line(Vector2(w * 0.485, base_y - h * 0.26), Vector2(w * 0.485, base_y - h * 0.40),
		Color(0.10, 0.08, 0.07), 2.0, true)
	draw_colored_polygon(PackedVector2Array([
		Vector2(w * 0.487, base_y - h * 0.40),
		Vector2(w * 0.545, base_y - h * 0.37),
		Vector2(w * 0.487, base_y - h * 0.34),
	]), FLAG)
	# Rahmen
	draw_rect(Rect2(1.0, 1.0, w - 2.0, h - 2.0), Color(0.72, 0.55, 0.28), false, 2.0)
