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
var _last_content_state: Array = []
var _colors: Array = []
var _content: Control

class MapContent extends Control:
	var overview
	func _draw() -> void:
		if is_instance_valid(overview):
			overview._draw_map_content(self)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "Übersicht · Klicken, um die Weltkarte dorthin zu ziehen."
	clip_contents = true
	# Geometry has its own retained CanvasItem. Camera motion redraws only
	# this control's small viewport outline, not every province polygon.
	_content = MapContent.new()
	_content.name = "MapContent"
	_content.overview = self
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.focus_mode = Control.FOCUS_NONE
	_content.show_behind_parent = true
	add_child(_content)
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(_delta: float) -> void:
	if not is_instance_valid(host):
		if not _last_content_state.is_empty():
			_last_content_state.clear()
			_colors.clear()
			_last_state = "__no_host__"
			_content.queue_redraw()
			queue_redraw()
		return
	var game_key: int = host.game.get_instance_id() if host.game != null else 0
	var colors: Array = []
	# Compare the actual rendered colors, so research, focus, claims, house
	# colors and title tiers cannot silently leave a stale overview behind.
	if host.game != null:
		for province in host.game.provinces:
			var color: Color = host._fill_color(province)
			color.a = 0.62
			colors.append(color)
	var content_state: Array = [host.get_instance_id(), game_key, size, host.selected, colors]
	if content_state != _last_content_state:
		_last_content_state = content_state
		_colors = colors
		_content.queue_redraw()
	var key := "%s|%s|%s|%s" % [hash(content_state), host._fit(), host.size, host.zoom]
	if key == _last_state:
		return
	_last_state = key
	queue_redraw()

func _map_rect() -> Rect2:
	var outer := Rect2(Vector2(2, 2), size - Vector2(4, 4))
	var inner := Rect2(outer.position + Vector2(5, 18), outer.size - Vector2(10, 23))
	var s: float = min(inner.size.x / MAP_SIZE.x, inner.size.y / MAP_SIZE.y)
	return Rect2(inner.position + (inner.size - MAP_SIZE * s) * 0.5, MAP_SIZE * s)

func _draw_map_content(canvas: CanvasItem) -> void:
	var outer := Rect2(Vector2(2, 2), size - Vector2(4, 4))
	canvas.draw_rect(outer, INK, true)
	canvas.draw_rect(outer, Color(0.66, 0.49, 0.24, 0.96), false, 1.0)
	var font := ThemeDB.fallback_font
	canvas.draw_string(font, Vector2(8, 14), "ÜBERSICHT", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.96, 0.82, 0.50))
	if is_instance_valid(host) and host.game == null:
		canvas.draw_string(font, Vector2(8, 30), "Keine Karte", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.76, 0.70, 0.58))
		return
	if not is_instance_valid(host):
		return
	var mr := _map_rect()
	var s: float = mr.size.x / MAP_SIZE.x
	canvas.draw_rect(mr, Color(0.10, 0.16, 0.18, 1.0), true)
	canvas.draw_texture_rect(RELIEF, mr, false, Color(0.68, 0.68, 0.62, 0.88))
	for index in host.game.provinces.size():
		var p: Dictionary = host.game.provinces[index]
		var c: Color = _colors[index] if index < _colors.size() else host._fill_color(p)
		c.a = 0.62
		for part in host._province_parts(p):
			var pts := PackedVector2Array()
			for point in part:
				pts.append(mr.position + point * s)
			canvas.draw_colored_polygon(pts, c)
	if host.selected != "":
		var sel: Dictionary = host.game.province(host.selected)
		if not sel.is_empty():
			for part in host._province_parts(sel):
				var pts := PackedVector2Array()
				for point in part:
					pts.append(mr.position + point * s)
				var outline: PackedVector2Array = pts.duplicate()
				outline.append(pts[0])
				canvas.draw_polyline(outline, Color(1.0, 0.90, 0.54), 1.4, true)

func _draw() -> void:
	if not is_instance_valid(host) or host.game == null:
		return
	var mr := _map_rect()
	var s: float = mr.size.x / MAP_SIZE.x
	var font := ThemeDB.fallback_font
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
	if not is_instance_valid(host) or host.game == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mr := _map_rect()
		if mr.size.x <= 0.0 or mr.size.y <= 0.0:
			return
		var local: Vector2 = (event.position - mr.position) / mr.size
		if local.x >= 0.0 and local.x <= 1.0 and local.y >= 0.0 and local.y <= 1.0:
			host.center_on(local * MAP_SIZE)
			accept_event()
