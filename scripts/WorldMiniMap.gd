extends Control
## Übersichtsminimap für die Weltkarte. Sie spiegelt Provinzfarben, Auswahl und
## den aktuellen Kartenausschnitt und erlaubt per Klick ein direktes Zentrieren.
## Die Zeichenlogik bleibt unabhängig vom Hauptrenderer; nur Lesedaten werden
## aus MapView übernommen.

const MAP_SIZE := Vector2(1200, 760)
const RELIEF := preload("res://assets/map/europe_relief.png")
const GOLD := Color(0.86, 0.68, 0.32)
const CREAM := Color(1.0, 0.96, 0.86)
const INK := Color(0.04, 0.03, 0.02, 0.94)

var host = null
var _last_state := "__init__"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "Übersicht · Klicken, um die Weltkarte dorthin zu ziehen."
	clip_contents = true

func _process(_delta: float) -> void:
	if host == null:
		return
	var game_key := str(host.game.get_instance_id()) if host.game != null else "0"
	var key := "%s|%.3f|%.1f|%.1f|%s|%s" % [game_key, host.zoom, host.pan.x, host.pan.y, host.selected, host.map_mode]
	if key == _last_state:
		return
	_last_state = key
	queue_redraw()

func _map_rect() -> Rect2:
	var outer := Rect2(Vector2(2, 2), size - Vector2(4, 4))
	var inner := Rect2(outer.position + Vector2(5, 18), outer.size - Vector2(10, 23))
	var s: float = min(inner.size.x / MAP_SIZE.x, inner.size.y / MAP_SIZE.y)
	return Rect2(inner.position + (inner.size - MAP_SIZE * s) * 0.5, MAP_SIZE * s)

func _draw() -> void:
	var outer := Rect2(Vector2(2, 2), size - Vector2(4, 4))
	draw_rect(outer, INK, true)
	draw_rect(outer, Color(0.66, 0.49, 0.24, 0.96), false, 1.0)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(8, 14), "ÜBERSICHT", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.96, 0.82, 0.50))
	if host != null and host.game == null:
		draw_string(font, Vector2(8, 30), "Keine Karte", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.76, 0.70, 0.58))
		return
	if host == null:
		return
	var mr := _map_rect()
	var s: float = mr.size.x / MAP_SIZE.x
	draw_rect(mr, Color(0.10, 0.16, 0.18, 1.0), true)
	draw_texture_rect(RELIEF, mr, false, Color(0.68, 0.68, 0.62, 0.88))
	for p in host.game.provinces:
		var c: Color = host._fill_color(p)
		c.a = 0.62
		for part in host._province_parts(p):
			var pts := PackedVector2Array()
			for point in part:
				pts.append(mr.position + point * s)
			draw_colored_polygon(pts, c)
	if host.selected != "":
		var sel: Dictionary = host.game.province(host.selected)
		if not sel.is_empty():
			for part in host._province_parts(sel):
				var pts := PackedVector2Array()
				for point in part:
					pts.append(mr.position + point * s)
				var outline: PackedVector2Array = pts.duplicate()
				outline.append(pts[0])
				draw_polyline(outline, Color(1.0, 0.90, 0.54), 1.4, true)
	var fit: Array = host._fit()
	if float(fit[0]) > 0.0:
		var off: Vector2 = fit[1]
		var vis := Rect2(-off / float(fit[0]), host.size / float(fit[0]))
		vis = vis.intersection(Rect2(Vector2.ZERO, MAP_SIZE))
		if vis.size.x > 0.0 and vis.size.y > 0.0:
			draw_rect(Rect2(mr.position + vis.position * s, vis.size * s), Color(1.0, 0.91, 0.62, 0.95), false, 1.2)
	draw_rect(mr, Color(0.72, 0.58, 0.34, 0.72), false, 1.0)
	draw_string(font, Vector2(mr.position.x + 4, mr.end.y - 5), "×%.1f" % host.zoom, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.94, 0.84, 0.60))

func _gui_input(event: InputEvent) -> void:
	if host == null or host.game == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mr := _map_rect()
		if mr.size.x <= 0.0 or mr.size.y <= 0.0:
			return
		var local: Vector2 = (event.position - mr.position) / mr.size
		if local.x >= 0.0 and local.x <= 1.0 and local.y >= 0.0 and local.y <= 1.0:
			host.center_on(local * MAP_SIZE)
			accept_event()
