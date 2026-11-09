extends Control
## Sichtbare Referenzgrenzen und Ortsnamen im Bildschirmraum, ohne Simulation.
const UiScript = preload("res://scripts/ModernInterface.gd")
const MAP_SIZE := Vector2(1200, 760)
const KIND_NAMES := {"country": "Land", "region": "Region", "district": "Kreis", "municipality": "Gemeinde", "city": "Ort"}
const TEXT := Color("fff7df")
const OUTLINE := Color(0.035, 0.055, 0.045, 0.96)
var host
var selected_id := ""
var audit_labels: Array = []
var audit_features: Array = []
var _last_key := ""

func configure(map_host) -> void:
	host = map_host
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	show_behind_parent = true
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	refresh()

func refresh() -> void:
	if host != null:
		size = host.size
	queue_redraw()

func _process(_delta: float) -> void:
	if host == null:
		return
	var fit: Array = host._fit()
	var key := "%s|%s|%s|%s|%s" % [fit[0], fit[1], host.size, UiScript.text_scale, selected_id]
	if key != _last_key:
		_last_key = key
		refresh()

func _draw() -> void:
	audit_labels.clear()
	audit_features.clear()
	if host == null or host.game == null or host.atlas_data == null:
		return
	var atlas = host.atlas_data
	var fit: Array = host._fit()
	var scale: float = float(fit[0])
	var offset: Vector2 = fit[1]
	if scale <= 0.0:
		return
	var visible := Rect2(-offset / scale, size / scale).intersection(Rect2(Vector2.ZERO, MAP_SIZE))
	if not visible.has_area():
		return
	var features: Array = atlas.visible_features(visible, host.zoom)
	var drawable_features: Array = []
	draw_set_transform(offset, 0.0, Vector2.ONE * scale)
	for feature in features:
		var kind := str(feature.kind)
		if kind == "municipality" and float(feature.bounds.get_area()) * scale * scale < 256.0:
			continue
		var width := 0.85
		var color := Color(0.17, 0.20, 0.15, 0.45)
		if kind == "country":
			width = 1.2
			color = Color(0.14, 0.17, 0.13, 0.55)
		elif kind == "district":
			width = 0.8
			color = Color(0.14, 0.17, 0.13, 0.50)
		elif kind == "municipality":
			width = 0.6
			color = Color(0.20, 0.23, 0.18, 0.25)
		for reference in feature.paths:
			var points: PackedVector2Array = atlas.path(reference)
			if points.size() >= 2:
				draw_polyline(points, color, width / scale, true)
		audit_features.append(str(feature.id))
		drawable_features.append(feature)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_places(atlas, drawable_features, visible, scale, offset)

func _draw_places(atlas, features: Array, visible: Rect2, scale: float, offset: Vector2) -> void:
	var font := ThemeDB.fallback_font
	var viewport := Rect2(Vector2(5, 5), size - Vector2(10, 10))
	var candidates: Array = []
	var selected: Dictionary = atlas.lookup(selected_id) if not selected_id.is_empty() else {}
	if not selected.is_empty() and visible.has_point(selected.point):
		candidates.append({"record": selected, "rank": 2000000000})
	for city in atlas.visible_cities(visible, host.zoom):
		if str(city.id) != selected_id:
			candidates.append({"record": city, "rank": int(city.population) + 1000000})
	for feature in features:
		var kind: String = str(feature.kind)
		if str(feature.id) == selected_id or not visible.has_point(feature.center):
			continue
		var show: bool = (kind == "region" and host.zoom >= 2.5 and host.zoom < 12.0) or (kind == "district" and host.zoom >= 6.0 and host.zoom < 24.0) or (kind == "municipality" and host.zoom >= 24.0)
		if show:
			candidates.append({"record": feature, "rank": 500000 if kind == "region" else 0})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.rank) != int(b.rank):
			return int(a.rank) > int(b.rank)
		return str(a.record.name) < str(b.record.name))
	var occupied: Array = host.atlas_obstacles.duplicate()
	var names: Dictionary = {}
	var text_scale: float = clampf(UiScript.text_scale, 1.0, 2.0)
	var limit := clampi(int(size.x * size.y / (7000.0 * text_scale * text_scale)), 12, 100)
	for candidate in candidates:
		if audit_labels.size() >= limit:
			break
		var record: Dictionary = candidate.record
		var name: String = str(record.get("name", ""))
		if name.is_empty() or names.has(name.to_lower()):
			continue
		var kind: String = str(record.get("kind", "city"))
		var anchor: Vector2 = offset + record.point * scale
		if not viewport.has_point(anchor):
			continue
		var chosen := str(record.get("id", "")) == selected_id
		var base_font := 14 if int(record.get("population", 0)) >= 500000 or kind == "region" else 13
		var font_size := int(round(base_font * text_scale))
		var text_size: Vector2 = font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var box_size := Vector2(text_size.x + 8.0, font.get_height(font_size) + 4.0)
		var options := [Vector2(8, -box_size.y * 0.5), Vector2(8, -box_size.y - 5), Vector2(8, 6), Vector2(-box_size.x - 8, -box_size.y * 0.5), Vector2(-box_size.x * 0.5, -box_size.y - 8), Vector2(-box_size.x * 0.5, 8)]
		var box := Rect2()
		var placed := false
		for option in options:
			box = Rect2(anchor + option, box_size)
			if not viewport.encloses(box):
				continue
			var free := true
			for other in occupied:
				if box.grow(2).intersects(other):
					free = false
					break
			if free:
				placed = true
				break
		if not placed:
			continue
		occupied.append(box)
		names[name.to_lower()] = true
		var text_position := box.position + Vector2(4, font.get_ascent(font_size) + 1)
		var ink := Color("ffe7a0") if chosen else TEXT
		if chosen:
			draw_style_box(_selected_style(), box.grow(2))
		if kind == "city":
			draw_circle(anchor, 3.8 if chosen else 3.0, OUTLINE)
			draw_circle(anchor, 2.2 if chosen else 1.65, ink)
		else:
			draw_circle(anchor, 1.5, Color(ink.r, ink.g, ink.b, 0.65))
		draw_string_outline(font, text_position, name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3, OUTLINE)
		draw_string(font, text_position, name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
		audit_labels.append({"rect": box, "text": name, "font_size": font_size, "kind": kind, "id": str(record.get("id", ""))})

static func _selected_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.035, 0.055, 0.045, 0.90)
	box.border_color = Color("d5bb7e")
	box.set_border_width_all(1)
	box.set_corner_radius_all(3)
	return box
