extends Control
## Zeichnet Beschriftungen, Auswahlbedienung und Legende über dem
## zwischengespeicherten Kartenunterbau aus MapBase.gd. Der Unterbau wird nur
## bei Daten-/Modus-/Auswahlwechsel neu gezeichnet und beim Pan/Zoom verschoben.

signal province_selected(province_id: String)
signal map_mode_changed(mode: String)
signal province_activated(province_id: String)
signal atlas_location_selected(record: Dictionary)

const MAP_MODES := ["political", "terrain", "duchy", "kingdom", "development", "war"]
const MODE_TITLES := {
	"political": "Politik",
	"terrain": "Gelände",
	"duchy": "Titel",
	"kingdom": "Reiche",
	"development": "Entwicklung",
	"war": "Krieg",
}
const MODE_HINTS := {
	"political": "Reichs- und Grafschaftsgrenzen",
	"terrain": "Gelände, Flüsse und Versorgung",
	"duchy": "Herzogtümer und ihre Grenzen",
	"kingdom": "Königreiche und Reichsgrenzen",
	"development": "Entwicklung der Grafschaften",
	"war": "Belagerungen, Flotten und Kriegsstand",
}
const TERRAIN_ORDER := ["plains", "farmland", "forest", "hills", "mountains", "marsh", "coast", "steppe", "heath"]
const TITLE_COLORS := [
	Color(0.62, 0.27, 0.20), Color(0.24, 0.40, 0.58), Color(0.25, 0.48, 0.31),
	Color(0.68, 0.53, 0.22), Color(0.35, 0.28, 0.52), Color(0.22, 0.50, 0.50),
	Color(0.55, 0.34, 0.25), Color(0.40, 0.47, 0.25), Color(0.56, 0.24, 0.40),
]
const SEAS := [
	{"name": "ATLANTIK", "geo": Vector2(-9.5, 45.0)},
	{"name": "NORDSEE", "geo": Vector2(3.5, 56.5)},
	{"name": "OSTSEE", "geo": Vector2(19.0, 58.0)},
	{"name": "MITTELMEER", "geo": Vector2(10.0, 35.0)},
	{"name": "SCHWARZES MEER", "geo": Vector2(34.0, 43.0)},
]

const MAP_SIZE := Vector2(1200, 760)
const MapBaseScript = preload("res://scripts/MapBase.gd")
const AtlasDataScript = preload("res://scripts/AtlasData.gd")
const AtlasLayerScript = preload("res://scripts/AtlasLayer.gd")
const MARKER_CASTLE := preload("res://assets/map/generated/marker_castle.png")
const MARKER_BANNER := preload("res://assets/map/generated/marker_banner.png")
const INK := Color(0.12, 0.09, 0.05)
const CREAM := Color(1.0, 0.96, 0.86)
const GOLD := Color(0.86, 0.68, 0.32)
const LABEL_BG := Color(0.08, 0.06, 0.03, 0.48)

var game = null
var selected: String = ""
var hovered: String = ""
var map_mode: String = "political"
var legend_visible := false
var crests: Array = []
var _edge_neighbor: Dictionary = {}
var _game_id: int = -1
var zoom: float = 1.0
var pan := Vector2.ZERO
var _dragging := false
var _hover_pos := Vector2.ZERO
var labels_drawn: int = 0
## Audit der tatsächlich gezeichneten 3D-Marker. Wird in jedem Draw neu gefüllt
## und dient dem Fenstertest als Nachweis des realen Draw-Pfads.
var capital_markers_drawn: Array = []
var kingdom_banners_drawn: Array = []
var empire_banners_drawn: Array = []
## Audit der tatsächlich gezeichneten Flottenmarker. Wird in jedem Draw neu
## gefüllt und dient dem Fenstertest als Nachweis des realen Draw-Pfads.
var fleet_markers_drawn: Array = []
var _terrain_tex: Dictionary = {}
var _building_tex: Dictionary = {}
var _unit_tex: Dictionary = {}
var _base
var atlas_data
var atlas_layer
var atlas_obstacles: Array = []
var atlas_location: String = ""
var _rivers_cache: Array = []
var _base_zoom_bucket := -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	atlas_data = AtlasDataScript.new()
	if atlas_data.load_data():
		atlas_layer = AtlasLayerScript.new()
		atlas_layer.configure(self)
		add_child(atlas_layer)
	_base = MapBaseScript.new()
	_base.host = self
	_base.size = MAP_SIZE
	add_child(_base)
	move_child(_base, 0)
	resized.connect(_sync_base_transform)
	mouse_exited.connect(_on_mouse_exited)
	_sync_base_transform()
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for i in 9:
		var t = load("res://assets/crests/crest_%d.png" % i)
		if t != null:
			crests.append(t)
	for key in TERRAIN_ORDER:
		var tex = load("res://assets/ui/tokens/terrain_%s.png" % key)
		if tex != null:
			_terrain_tex[str(key)] = tex
	for key in ["market", "barracks", "walls"]:
		var btex = load("res://assets/ui/tokens/building_%s.png" % key)
		if btex != null:
			_building_tex[str(key)] = btex
	for key in ["levy", "archer", "knight", "siege", "fleet"]:
		var utex = load("res://assets/ui/tokens/unit_%s.png" % key)
		if utex != null:
			_unit_tex[str(key)] = utex

func set_game(g) -> void:
	game = g
	hovered = ""
	if game != null and game.get_instance_id() != _game_id:
		_game_id = game.get_instance_id()
		_rebuild_edge_cache()
	if _base != null:
		_base.queue_redraw()
	queue_redraw()

func set_mode(mode: String) -> void:
	var clean: String = mode if MAP_MODES.has(mode) else "political"
	if clean == map_mode:
		queue_redraw()
		return
	map_mode = clean
	if _base != null:
		_base.queue_redraw()
	queue_redraw()
	map_mode_changed.emit(map_mode)

func mode_title() -> String:
	return str(MODE_TITLES.get(map_mode, "Politik"))

func select(id: String) -> void:
	selected = id
	if _base != null:
		_base.queue_redraw()
	queue_redraw()

func hover_at(pos: Vector2) -> void:
	_hover_pos = pos
	var id: String = _province_at(pos)
	if id == hovered:
		return
	hovered = id
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hovered != "" else Control.CURSOR_ARROW
	queue_redraw()

func set_crest_texture(index: int, tex: Texture2D) -> void:
	while crests.size() <= index:
		crests.append(null)
	crests[index] = tex
	queue_redraw()

func _fit() -> Array:
	var fit_s: float = min(size.x / MAP_SIZE.x, size.y / MAP_SIZE.y)
	if fit_s <= 0.0:
		fit_s = 1.0
	var s: float = fit_s * zoom
	var off: Vector2 = (size - MAP_SIZE * s) * 0.5 + pan
	return [s, off]

func _sync_base_transform() -> void:
	if _base == null:
		return
	var fit := _fit()
	_base.position = fit[1]
	_base.scale = Vector2(float(fit[0]), float(fit[0]))
	var bucket := int(zoom)
	if bucket != _base_zoom_bucket:
		_base_zoom_bucket = bucket
		_base.queue_redraw()
	if atlas_layer != null:
		atlas_layer.size = size
		atlas_layer.refresh()

func rivers() -> Array:
	if _rivers_cache.is_empty() and atlas_data != null:
		for river in atlas_data.rivers:
			for ref in river.get("paths", []):
				var points: PackedVector2Array = atlas_data.path(ref)
				if points.size() > 1:
					_rivers_cache.append({"name": str(river.get("name", "")), "points": points})
	return _rivers_cache

func seas() -> Array:
	var result: Array = []
	if atlas_data == null:
		return result
	for sea in SEAS:
		result.append({"name": sea.name, "pos": atlas_data.project(sea.geo.x, sea.geo.y)})
	return result

func _clamp_pan() -> void:
	var fit_s: float = min(size.x / MAP_SIZE.x, size.y / MAP_SIZE.y)
	if fit_s <= 0.0:
		return
	var s: float = fit_s * zoom
	var scaled: Vector2 = MAP_SIZE * s
	var base: Vector2 = (size - scaled) * 0.5
	var off: Vector2 = base + pan
	if scaled.x <= size.x:
		off.x = base.x
	else:
		off.x = clampf(off.x, size.x - scaled.x, 0.0)
	if scaled.y <= size.y:
		off.y = base.y
	else:
		off.y = clampf(off.y, size.y - scaled.y, 0.0)
	pan = off - base

func zoom_by(factor: float, pivot = null) -> void:
	var p: Vector2 = size * 0.5 if pivot == null else pivot
	var old: Array = _fit()
	var before: Vector2 = (p - (old[1] as Vector2)) / float(old[0])
	zoom = clampf(zoom * factor, 1.0, 64.0)
	var fit_s: float = min(size.x / MAP_SIZE.x, size.y / MAP_SIZE.y)
	var s: float = fit_s * zoom
	var base: Vector2 = (size - MAP_SIZE * s) * 0.5
	pan = p - before * s - base
	_clamp_pan()
	_sync_base_transform()
	queue_redraw()

func reset_view() -> void:
	zoom = 1.0
	pan = Vector2.ZERO
	_sync_base_transform()
	queue_redraw()

func center_on(map_point: Vector2) -> void:
	var fit_s: float = min(size.x / MAP_SIZE.x, size.y / MAP_SIZE.y)
	if fit_s <= 0.0:
		return
	var s: float = fit_s * zoom
	var base: Vector2 = (size - MAP_SIZE * s) * 0.5
	pan = size * 0.5 - map_point * s - base
	_clamp_pan()
	_sync_base_transform()
	queue_redraw()

func focus_atlas_location(record: Dictionary) -> void:
	if record.is_empty() or atlas_layer == null:
		return
	var point: Vector2 = record.get("point", record.get("center", Vector2.ZERO))
	atlas_location = str(record.get("name", ""))
	atlas_layer.selected_id = str(record.get("id", ""))
	var kind := str(record.get("kind", "city"))
	zoom = 4.5 if kind in ["country", "region"] else (12.0 if kind == "district" else (48.0 if kind == "municipality" else 24.0))
	center_on(point)
	var province_id := str(record.get("province_id", ""))
	if game != null and not game.province(province_id).is_empty():
		select(province_id)
		province_selected.emit(province_id)
	atlas_location_selected.emit(record)

func _centroid(poly: PackedVector2Array) -> Vector2:
	var sum := Vector2.ZERO
	for p in poly:
		sum += p
	return sum / maxf(1.0, float(poly.size()))

func _poly_has_point(poly: PackedVector2Array, pt: Vector2) -> bool:
	for p in poly:
		if p.distance_squared_to(pt) < 1.8:
			return true
	return false

func _province_parts(p: Dictionary) -> Array:
	var out: Array = []
	var raw = p.get("parts", [])
	if raw is Array:
		for part in raw:
			if part is PackedVector2Array and part.size() >= 3:
				out.append(part)
	if out.is_empty():
		var pts: PackedVector2Array = p.get("points", PackedVector2Array())
		if pts.size() >= 3:
			out.append(pts)
	return out

func _label_point(p: Dictionary) -> Vector2:
	var pos = p.get("label_pos", null)
	if pos is Vector2:
		return pos
	return _centroid(p["points"])

func _rebuild_edge_cache() -> void:
	_edge_neighbor = {}
	if game == null:
		return
	for p in game.provinces:
		var parts: Array = _province_parts(p)
		var ns: Array = game.neighbours(str(p["id"]))
		for pi in parts.size():
			var pts: PackedVector2Array = parts[pi]
			for i in pts.size():
				var a: Vector2 = pts[i]
				var b: Vector2 = pts[(i + 1) % pts.size()]
				var found := ""
				for nid in ns:
					var q: Dictionary = game.province(str(nid))
					if q.is_empty():
						continue
					for qp in _province_parts(q):
						if _poly_has_point(qp, a) and _poly_has_point(qp, b):
							found = str(nid)
							break
					if found != "":
						break
				_edge_neighbor["%s|%d|%d" % [p["id"], pi, i]] = found

func _province_at(pos: Vector2) -> String:
	if game == null:
		return ""
	var fit := _fit()
	var s: float = fit[0]
	var off: Vector2 = fit[1]
	var map_point: Vector2 = (pos - off) / s
	# Kleine Inseln zuerst prüfen, damit sie nicht von großen Nachbarflächen
	# überdeckt werden; bei sich überlappenden Teilen gewinnt die kleinste Fläche.
	var candidates: Array = []
	for p in game.provinces:
		for part in _province_parts(p):
			if Geometry2D.is_point_in_polygon(map_point, part):
				var area := 0.0
				for i in part.size():
					var a: Vector2 = part[i]
					var b: Vector2 = part[(i + 1) % part.size()]
					area += a.x * b.y - b.x * a.y
				candidates.append([absf(area), str(p["id"])])
	if not candidates.is_empty():
		candidates.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
		return str(candidates[0][1])
	return ""

func _pick_at(pos: Vector2) -> void:
	if game == null:
		return
	atlas_location = ""
	if atlas_layer != null and zoom >= 2.5:
		var fit := _fit()
		var point: Vector2 = (pos - fit[1]) / float(fit[0])
		var record: Dictionary = atlas_data.nearest_city(point, 12.0 / float(fit[0]))
		if record.is_empty():
			record = atlas_data.feature_at(point, zoom)
		atlas_layer.selected_id = str(record.get("id", ""))
		atlas_location = str(record.get("name", ""))
		if not record.is_empty():
			atlas_location_selected.emit(record)
	var id: String = _province_at(pos)
	if id == "":
		if selected != "":
			selected = ""
			province_selected.emit("")
			queue_redraw()
		return
	selected = id
	hovered = id
	_hover_pos = pos
	province_selected.emit(selected)
	queue_redraw()

func _draw() -> void:
	var fit := _fit()
	var s: float = fit[0]
	var off: Vector2 = fit[1]
	fleet_markers_drawn.clear()
	capital_markers_drawn.clear()
	kingdom_banners_drawn.clear()
	empire_banners_drawn.clear()
	_sync_base_transform()
	if game == null:
		draw_rect(Rect2(off, MAP_SIZE * s), Color(0.72, 0.58, 0.34, 0.5), false, 3.0)
		return
	_draw_hover_highlight(s, off)
	_draw_infrastructure(s, off)
	_draw_sea_names(s, off)
	_draw_labels(s, off)

func _draw_sea_names(s: float, off: Vector2) -> void:
	if zoom >= 3.0:
		return
	var font := ThemeDB.fallback_font
	var font_size := int(round(13.0 * preload("res://scripts/ModernInterface.gd").text_scale))
	for sea in seas():
		var position: Vector2 = off + sea.pos * s
		if not Rect2(Vector2.ZERO, size).has_point(position):
			continue
		draw_string_outline(font, position, sea.name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3, Color(0.08, 0.16, 0.18, 0.85))
		draw_string(font, position, sea.name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.85, 0.91, 0.88, 0.85))

func infrastructure_segments() -> Array:
	var segments: Array = []
	if game == null:
		return segments
	for road in game.road_segments():
		var a: Dictionary = game.province(str(road.from))
		var b: Dictionary = game.province(str(road.to))
		if a.is_empty() or b.is_empty():
			continue
		segments.append({"a": _label_point(a), "b": _label_point(b), "state": road.state, "months": road.months})
	return segments

func _draw_infrastructure(s: float, off: Vector2) -> void:
	for segment in infrastructure_segments():
		var a: Vector2 = off + segment.a * s
		var b: Vector2 = off + segment.b * s
		var width: float = clampf(2.0 * s, 2.5, 6.0)
		if segment.state == "complete":
			draw_line(a, b, Color(0.12, 0.08, 0.035, 0.92), width + 3.0, true)
			draw_line(a, b, Color(0.95, 0.81, 0.48), width, true)
			draw_line(a, b, Color(1.0, 0.94, 0.74), 1.0, true)
		else:
			var length: float = a.distance_to(b)
			if length < 1.0:
				continue
			var direction: Vector2 = (b - a) / length
			for distance in range(0, int(length), 14):
				var start: Vector2 = a + direction * float(distance)
				var end: Vector2 = a + direction * minf(float(distance + 8), length)
				draw_line(start, end, Color(0.98, 0.72, 0.25), width, true)
		for endpoint in [a, b]:
			draw_circle(endpoint, width + 1.5, Color(0.12, 0.08, 0.035))
			draw_circle(endpoint, width - 0.5, Color(0.98, 0.85, 0.52))

func _draw_labels(s: float, off: Vector2) -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var font := ThemeDB.fallback_font
	var map_rect := Rect2(off, MAP_SIZE * s)
	var inner := map_rect.intersection(Rect2(Vector2.ZERO, size)).grow(-3)
	atlas_obstacles.clear()
	# Die Minimap ist ein Geschwister-Control; ihr Raum gehört nicht den Labels.
	if get_parent() != null:
		for sibling in get_parent().get_children():
			if sibling is Control and sibling.get_script() == preload("res://scripts/WorldMiniMap.gd") and sibling.visible:
				atlas_obstacles.append(Rect2(sibling.global_position - global_position, sibling.size))
	if inner.size.x < 80 or inner.size.y < 40:
		return
	var occupied: Array = []
	var font_scale: float = preload("res://scripts/ModernInterface.gd").text_scale
	var fs_title := int(round(19 * font_scale))
	var fs_owner := int(round(13 * font_scale))
	var fs_label := int(round(13 * font_scale))
	# In der Nahansicht übernehmen echte Orte und Verwaltungsgrenzen den Platz.
	if atlas_layer != null and zoom >= 2.5:
		labels_drawn = 0
		if map_mode == "war":
			_draw_war_markers(s, off, font)
		_draw_hover_tooltip(font)
		return

	# Die Blender-Marker sitzen an den Halte- und Königreichssitzen. Sie werden
	# vor den Titeln eingeplant, damit die Beschriftung nicht auf ihnen landet.
	_draw_3d_markers(s, off, occupied, inner)

	# Neun Königreichstitel; sie bekommen zuerst Platz.
	var groups: Array = []
	var seen := {}
	for p in game.provinces:
		var kid := str(p["kingdom"])
		if seen.has(kid):
			continue
		seen[kid] = true
		var sum := Vector2.ZERO
		var count := 0
		for q in game.provinces:
			if str(q["kingdom"]) != kid:
				continue
			sum += _label_point(q) * s + off
			count += 1
		groups.append({"id": kid, "pos": sum / maxf(1.0, float(count)), "p": p})
	for g in groups:
		var p: Dictionary = g["p"]
		var title: String = str(p["kingdom_name"]).replace("Königreich ", "")
		var house_name: String = str(game.houses[int(p["owner"])]["name"])
		var tw: float = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_title).x
		var ow: float = font.get_string_size(house_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_owner).x
		var w: float = maxf(tw, ow) + 18.0
		var h: float = float(fs_title + fs_owner + 9)
		var anchor: Vector2 = g["pos"]
		var candidates := [Vector2(0, -h * 0.5), Vector2(0, -h - 8), Vector2(0, 8),
			Vector2(-w * 0.75, 0), Vector2(w * 0.75, 0),
			Vector2(0, -h - 24), Vector2(0, 24), Vector2(-w, 0), Vector2(w, 0)]
		var box := Rect2()
		var placed := false
		for cand in candidates:
			box = Rect2(anchor + cand - Vector2(w * 0.5, h * 0.5), Vector2(w, h))
			box.position.x = clampf(box.position.x, inner.position.x + 2, inner.end.x - w - 2)
			box.position.y = clampf(box.position.y, inner.position.y + 2, inner.end.y - h - 2)
			var ok := inner.encloses(box)
			if ok:
				for r in occupied:
					if (r as Rect2).grow(2).intersects(box):
						ok = false
						break
			if ok:
				placed = true
				break
		if not placed:
			continue
		occupied.append(box)
		# Titel schweben wie auf einer historischen Karte über dem Gelände:
		# Kontur statt deckender Kästen, dazu eine schmale Hausfarben-Marke.
		var tx := box.position.x + (w - tw) * 0.5
		var ty := box.position.y + float(fs_title) + 2.0
		var hcol: Color = game.houses[int(p["owner"])].get("color", GOLD)
		draw_rect(Rect2(box.position.x + 1, box.position.y + 9, 3, float(fs_title) - 2), Color(hcol.r, hcol.g, hcol.b, 0.92), true)
		draw_string_outline(font, Vector2(tx, ty), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_title, 4, Color(0.025, 0.018, 0.010, 0.9))
		draw_string(font, Vector2(tx, ty), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_title, CREAM)
		var ox := box.position.x + (w - ow) * 0.5
		var oy := ty + float(fs_owner) + 2.0
		draw_string_outline(font, Vector2(ox, oy), house_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_owner, 2, Color(0.025, 0.018, 0.010, 0.92))
		draw_string(font, Vector2(ox, oy), house_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_owner, Color(0.98, 0.87, 0.62))

	# Wappen der neun Hauptstädte, danach die Provinznamen.
	for p in game.provinces:
		if not bool(p.get("capital", false)):
			continue
		var pos: Vector2 = _label_point(p) * s + off
		var size := Vector2(19, 23) if s < 0.9 else Vector2(23, 28)
		var box := Rect2(pos + Vector2(-size.x * 0.5, -size.y - 3), size)
		box.position.x = clampf(box.position.x, inner.position.x, inner.end.x - size.x)
		box.position.y = clampf(box.position.y, inner.position.y, inner.end.y - size.y)
		if not crests.is_empty():
			var oi: int = int(p["owner"])
			var ci: int = posmod(int(game.houses[oi].get("crest", oi)), maxi(1, crests.size()))
			if ci < crests.size() and crests[ci] != null:
				draw_texture_rect(crests[ci], box, false)
			occupied.append(box.grow(2))
			# Gebaute Anlagen als kleine Token unter dem Wappen.
			var levels: Dictionary = p.get("buildings", {})
			var bx: float = box.position.x
			for bkey in ["market", "barracks", "walls"]:
				if int(levels.get(bkey, 0)) <= 0:
					continue
				var btex: Texture2D = _building_tex.get(str(bkey))
				if btex == null:
					continue
				var bpos := Vector2(bx, box.position.y + box.size.y + 2)
				draw_texture_rect(btex, Rect2(bpos, Vector2(13, 13)), false)
				occupied.append(Rect2(bpos, Vector2(13, 13)).grow(1))
				bx += 14.0

	var drawn := 0
	var label_provinces: Array = game.provinces if atlas_layer == null else []
	for p in label_provinces:
		var name := str(p["name"])
		if map_mode == "development":
			name = "%s · %d" % [name, int(p.get("dev", 1))]
		var w: float = font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_label).x
		var h: float = float(fs_label + 3)
		var anchor: Vector2 = _label_point(p) * s + off
		var candidates := [
			Vector2(0, 0), Vector2(0, -h - 3), Vector2(0, h + 3),
			Vector2(-w * 0.55, 0), Vector2(w * 0.55, 0),
			Vector2(-w * 0.55, -h - 3), Vector2(w * 0.55, -h - 3),
			Vector2(-w * 0.55, h + 3), Vector2(w * 0.55, h + 3),
			Vector2(0, -2 * h - 5), Vector2(0, 2 * h + 5),
			Vector2(-w, 0), Vector2(w, 0), Vector2(-w, -h - 3), Vector2(w, -h - 3),
			Vector2(0, -3 * h - 7), Vector2(0, 3 * h + 7),
		]
		var box := Rect2()
		var placed := false
		for cand in candidates:
			box = Rect2(anchor + cand - Vector2(w * 0.5, 0), Vector2(w + 4, h + 2))
			box.position.x = clampf(box.position.x, inner.position.x + 1, inner.end.x - box.size.x - 1)
			box.position.y = clampf(box.position.y, inner.position.y + 1, inner.end.y - box.size.y - 1)
			if not inner.encloses(box):
				continue
			var ok := true
			for r in occupied:
				if (r as Rect2).grow(0.8).intersects(box):
					ok = false
					break
			if ok:
				placed = true
				break
		if not placed:
			continue
		occupied.append(box)
		var txt := Vector2(box.position.x + 2, box.position.y + float(fs_label) + 1)
		draw_string_outline(font, txt, name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_label, 2, Color(0.02, 0.015, 0.01, 0.9))
		draw_string(font, txt, name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_label,
			Color(1.0, 0.86, 0.48) if str(p["id"]) == selected else Color(1.0, 0.97, 0.88))
		if str(p["id"]) == selected:
			draw_line(txt + Vector2(0, 2), txt + Vector2(w, 2), Color(1.0, 0.80, 0.34, 0.95), 1.2, true)
		drawn += 1
	labels_drawn = drawn
	atlas_obstacles.append_array(occupied)

	if map_mode == "war":
		_draw_war_markers(s, off, font)

	if legend_visible:
		_draw_legend(map_rect, font)
	draw_rect(map_rect, Color(0.72, 0.58, 0.34, 0.5), false, 3.0)
	_draw_hover_tooltip(font)

func marker_textures_loaded() -> bool:
	return MARKER_CASTLE != null and MARKER_BANNER != null

func marker_scale_for(s: float) -> float:
	# Marker wachsen mit der Karte, werden bei 4x Zoom aber gedeckelt, damit
	# die Symbole keine Provinzflächen überdecken.
	return clampf(s, 0.95, 1.28)

func marker_specs() -> Array:
	var out: Array = []
	if game == null:
		return out
	var imperial: Dictionary = {}
	for p in game.provinces:
		if not bool(p.get("capital", false)):
			continue
		var empire := str(p["empire"])
		if not imperial.has(empire) or int(p.get("dev", 1)) > int(imperial[empire]["dev"]):
			imperial[empire] = {"id": str(p["id"]), "dev": int(p.get("dev", 1))}
	for p in game.provinces:
		if not bool(p.get("capital", false)):
			continue
		var seat: Dictionary = imperial.get(str(p["empire"]), {})
		out.append({
			"id": str(p["id"]),
			"name": str(p["name"]),
			"pos": _label_point(p),
			"kingdom": str(p["kingdom"]),
			"kingdom_name": str(p["kingdom_name"]),
			"empire": str(p["empire"]),
			"empire_name": str(p["empire_name"]),
			"imperial": str(p["id"]) == str(seat.get("id", "")),
		})
	return out

func _clamp_marker_rect(rect: Rect2, inner: Rect2) -> Rect2:
	rect.position.x = clampf(rect.position.x, inner.position.x + 1.0, inner.end.x - rect.size.x - 1.0)
	rect.position.y = clampf(rect.position.y, inner.position.y + 1.0, inner.end.y - rect.size.y - 1.0)
	return rect

func _draw_3d_markers(s: float, off: Vector2, occupied: Array, inner: Rect2) -> void:
	if game == null or not marker_textures_loaded():
		return
	var ms := marker_scale_for(s)
	var specs := marker_specs()
	for spec in specs:
		var pos: Vector2 = (spec["pos"] as Vector2) * s + off
		var castle_size := Vector2(27.0, 27.0) * ms
		var castle_rect := _clamp_marker_rect(Rect2(
			pos + Vector2(-castle_size.x * 0.5, 18.0 * ms - castle_size.y),
			castle_size), inner)
		var banner_size := Vector2(22.0, 32.0) * ms
		var banner_rect := _clamp_marker_rect(Rect2(
			pos + Vector2(11.0 * ms, 18.0 * ms - banner_size.y),
			banner_size), inner)
		var shade_pos := Vector2(pos.x, castle_rect.end.y - 2.0 * ms)
		draw_circle(shade_pos, 10.0 * ms, Color(0.035, 0.025, 0.015, 0.32))
		if bool(spec.get("imperial", false)):
			var halo := banner_rect.get_center()
			draw_circle(halo, 15.0 * ms, Color(0.94, 0.70, 0.24, 0.14))
			draw_arc(halo, 15.0 * ms, 0.0, TAU, 28, Color(0.95, 0.75, 0.28, 0.90), 1.7 * ms, true)
		draw_texture_rect(MARKER_CASTLE, castle_rect, false, Color(1, 1, 1, 0.98))
		draw_texture_rect(MARKER_BANNER, banner_rect, false, Color(1, 1, 1, 0.98))
		occupied.append(castle_rect.grow(1.0))
		occupied.append(banner_rect.grow(1.0))
		capital_markers_drawn.append(str(spec["id"]))
		kingdom_banners_drawn.append(str(spec["id"]))
		if bool(spec.get("imperial", false)):
			empire_banners_drawn.append(str(spec["id"]))

func _draw_hover_highlight(s: float, off: Vector2) -> void:
	if game == null or hovered == "" or _dragging:
		return
	var p: Dictionary = game.province(hovered)
	if p.is_empty():
		return
	for part in _province_parts(p):
		var screen := PackedVector2Array()
		for point in part:
			screen.append(point * s + off)
		draw_colored_polygon(screen, Color(1.0, 0.90, 0.55, 0.12))
		var outline: PackedVector2Array = screen.duplicate()
		outline.append(screen[0])
		draw_polyline(outline, Color(1.0, 0.91, 0.62, 0.95), 2.2, true)

func _draw_hover_tooltip(font: Font) -> void:
	if game == null or hovered == "" or _dragging:
		return
	var p: Dictionary = game.province(hovered)
	if p.is_empty():
		return
	var owner: String = str(game.houses[int(p["owner"])]["name"])
	var w := 286.0
	var h := 92.0
	var pos: Vector2 = _hover_pos + Vector2(18, 18)
	if pos.x + w > size.x - 8:
		pos.x = _hover_pos.x - w - 18
	if pos.y + h > size.y - 8:
		pos.y = _hover_pos.y - h - 18
	pos.x = clampf(pos.x, 8, maxf(8, size.x - w - 8))
	pos.y = clampf(pos.y, 8, maxf(8, size.y - h - 8))
	var box := Rect2(pos, Vector2(w, h))
	draw_rect(Rect2(box.position + Vector2(4, 4), box.size), Color(0, 0, 0, 0.36), true)
	draw_rect(box, Color(0.055, 0.040, 0.024, 0.96), true)
	draw_rect(Rect2(box.position, Vector2(5, h)), Color(0.88, 0.68, 0.30, 0.98), true)
	draw_rect(box, Color(0.70, 0.53, 0.25, 0.92), false, 1.0)
	draw_string(font, pos + Vector2(14, 21), str(p["name"]), HORIZONTAL_ALIGNMENT_LEFT, w - 24, 15, CREAM)
	draw_string(font, pos + Vector2(14, 39), "%s · %s" % [owner, str(p.get("terrain_name", "Ebenen"))], HORIZONTAL_ALIGNMENT_LEFT, w - 24, 10, Color(0.96, 0.84, 0.60))
	draw_string(font, pos + Vector2(14, 56), "%s · %s" % [str(p["kingdom_name"]), str(p["duchy_name"])], HORIZONTAL_ALIGNMENT_LEFT, w - 24, 9, Color(0.82, 0.78, 0.68))
	draw_string(font, pos + Vector2(14, 73), "Entwicklung %d/10 · Aufgebot %d · Gelände %+d%%" % [int(p.get("dev", 1)), int(p.get("levy", 0)), int(p.get("terrain_defense", 0))], HORIZONTAL_ALIGNMENT_LEFT, w - 24, 9, Color(0.98, 0.83, 0.44))
	draw_string(font, pos + Vector2(14, 86), "Klick wählt · Doppelklick öffnet die Provinzseite", HORIZONTAL_ALIGNMENT_LEFT, w - 24, 8, Color(0.68, 0.64, 0.56))

func _fill_color(p: Dictionary) -> Color:
	var base: Color
	match map_mode:
		"terrain":
			base = p.get("terrain_color", Color(0.47, 0.54, 0.30))
		"duchy":
			base = _title_color(str(p["duchy"]))
		"kingdom":
			base = _title_color(str(p["kingdom"]))
		"development":
			base = _dev_color(int(p.get("dev", 1)))
		_:
			base = game.houses[int(p["owner"])]["color"]
	if selected == str(p["id"]):
		base = base.lightened(0.25)
	base.a = 0.08 if map_mode == "terrain" else (0.38 if map_mode == "development" else 0.26)
	return base

func _title_color(id: String) -> Color:
	if TITLE_COLORS.is_empty():
		return Color(0.40, 0.40, 0.40)
	return TITLE_COLORS[posmod(id.hash(), TITLE_COLORS.size())]

func _dev_color(dev: int) -> Color:
	var t: float = clampf(float(dev - 1) / 9.0, 0.0, 1.0)
	return Color(0.30, 0.24, 0.18).lerp(Color(0.83, 0.70, 0.32), t)

func _terrain_info(key: String) -> Dictionary:
	if game != null:
		return game.data.terrain_info(key)
	return {"name": key, "color": Color(0.47, 0.54, 0.30)}

func _draw_war_markers(s: float, off: Vector2, font: Font) -> void:
	for p in game.provinces:
		var siege: int = int(p.get("siege", 0))
		if siege <= 0:
			continue
		var pos: Vector2 = _label_point(p) * s + off
		var token: Texture2D = _unit_tex.get("siege")
		if token != null:
			draw_texture_rect(token, Rect2(pos - Vector2(14, 14), Vector2(28, 28)), false)
			draw_arc(pos, 15.0, 0.0, TAU, 20, Color(1.0, 0.83, 0.44, 0.72), 1.0, true)
			draw_string(font, pos + Vector2(16, 4), "%d%%" % siege, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1.0, 0.96, 0.86))
		else:
			draw_circle(pos, 12.0, Color(0.55, 0.10, 0.06, 0.92))
			draw_arc(pos, 12.0, 0.0, TAU, 20, Color(1.0, 0.83, 0.44, 0.95), 1.5, true)
			draw_string(font, pos + Vector2(-10, 4), "%d%%" % siege, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1.0, 0.96, 0.86))
	# Flotten stehen im Kriegsmodus an ihrem Heimathafen oder vor der blockierten
	# Küste. Der Ring trägt die Hausfarbe, die Zahl die Schiffszahl.
	for house_index in game.houses.size():
		var house_color: Color = game.houses[house_index].get("color", Color(0.7, 0.5, 0.2))
		for fleet in game.houses[house_index].get("fleets", []):
			var station: Dictionary = game.province(str(fleet.get("station", "")))
			if station.is_empty():
				continue
			var pos: Vector2 = _label_point(station) * s + off + Vector2(0, 22)
			if int(station.get("siege", 0)) > 0:
				pos += Vector2(20, 0)
			var token: Texture2D = _unit_tex.get("fleet")
			var ring_color := Color(house_color.r, house_color.g, house_color.b, 0.95)
			var ships: int = int(fleet.get("ships", 0))
			var token_rect := Rect2(pos - Vector2(14, 14), Vector2(28, 28))
			var label_pos := pos + Vector2(16, 4)
			fleet_markers_drawn.append({
				"house": house_index, "province": str(station["id"]), "ships": ships,
				"label": "%d" % ships, "pos": pos, "ring_color": ring_color,
				"ring_radius": 15.0, "token_rect": token_rect, "label_pos": label_pos,
				"token_path": token.resource_path if token != null else "",
			})
			if token != null:
				draw_texture_rect(token, token_rect, false)
			else:
				draw_circle(pos, 11.0, Color(0.20, 0.36, 0.44, 0.94))
			draw_arc(pos, 15.0, 0.0, TAU, 20, ring_color, 2.0, true)
			draw_string(font, label_pos, "%d" % ships, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1.0, 0.96, 0.86))

func _legend_rows() -> Array:
	match map_mode:
		"duchy":
			return [
				["Grafschaft", Color(0.16, 0.11, 0.07, 0.55), 1.0],
				["Herzogtum", Color(0.43, 0.30, 0.14, 0.9), 2.1],
				["Königreich", Color(0.72, 0.52, 0.22, 0.95), 3.2],
				["Reich", Color(0.64, 0.18, 0.13, 0.95), 5.0],
			]
		"kingdom":
			return [
				["Grafschaft", Color(0.16, 0.11, 0.07, 0.55), 1.0],
				["Königreich", Color(0.72, 0.52, 0.22, 0.95), 3.2],
				["Reich", Color(0.64, 0.18, 0.13, 0.95), 5.0],
			]
		_:
			return [
				["Grafschaft", Color(0.16, 0.11, 0.07, 0.55), 1.0],
				["Besitzerwechsel", Color(0.98, 0.84, 0.45, 0.95), 4.0],
				["Herzogtum", Color(0.43, 0.30, 0.14, 0.9), 2.1],
				["Königreich", Color(0.72, 0.52, 0.22, 0.95), 3.2],
				["Reich", Color(0.64, 0.18, 0.13, 0.95), 5.0],
			]

func _draw_legend(map_rect: Rect2, font: Font) -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var w := 246.0
	var h := 124.0
	if map_mode == "terrain":
		h = 134.0
	elif map_mode == "development":
		h = 78.0
	elif map_mode == "war":
		h = 118.0
	var box := Rect2(map_rect.position + Vector2(12, 92), Vector2(w, h))
	draw_rect(box, Color(0.06, 0.05, 0.03, 0.89), true)
	draw_rect(box, Color(0.72, 0.57, 0.30, 0.92), false, 1.0)
	draw_string(font, box.position + Vector2(8, 15), "KARTE · %s" % mode_title(), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.98, 0.86, 0.58))
	if map_mode == "terrain":
		for i in TERRAIN_ORDER.size():
			var key: String = str(TERRAIN_ORDER[i])
			var info: Dictionary = _terrain_info(key)
			var col: int = i % 3
			var row: int = int(i / 3)
			var origin: Vector2 = box.position + Vector2(8 + col * 79, 23 + row * 22)
			var tex: Texture2D = _terrain_tex.get(key)
			if tex != null:
				draw_texture_rect(tex, Rect2(origin, Vector2(18, 18)), false, Color(1, 1, 1, 0.97))
			else:
				draw_rect(Rect2(origin + Vector2(2, 2), Vector2(14, 14)), info["color"], true)
			draw_string(font, origin + Vector2(22, 14), str(info["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.94, 0.90, 0.80))
		draw_line(box.position + Vector2(8, h - 34), box.position + Vector2(32, h - 34), Color(0.18, 0.45, 0.58, 0.9), 2.0)
		draw_string(font, box.position + Vector2(38, h - 31), "Flüsse · Geländesymbole", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.82, 0.88, 0.86))
		draw_string(font, box.position + Vector2(8, h - 12), "Token = Geländetyp (Blender-Render)", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.76, 0.70, 0.58))
	elif map_mode == "development":
		for i in 5:
			var t: float = float(i) / 4.0
			var c: Color = Color(0.30, 0.24, 0.18).lerp(Color(0.83, 0.70, 0.32), t)
			draw_rect(Rect2(box.position + Vector2(8 + i * 42, 30), Vector2(40, 12)), c, true)
		draw_string(font, box.position + Vector2(8, 57), "niedrig", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.82, 0.78, 0.68))
		draw_string(font, box.position + Vector2(176, 57), "hoch", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.96, 0.86, 0.58))
		draw_string(font, box.position + Vector2(8, 69), "Entwicklungsstufe 1–10", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.82, 0.88, 0.86))
	elif map_mode == "war":
		draw_circle(box.position + Vector2(14, 33), 7.0, Color(0.55, 0.10, 0.06, 0.92))
		draw_arc(box.position + Vector2(14, 33), 7.0, 0.0, TAU, 16, Color(1.0, 0.83, 0.44, 0.95), 1.2, true)
		draw_string(font, box.position + Vector2(28, 37), "Belagerung / Kriegsstand", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.92, 0.88, 0.78))
		draw_line(box.position + Vector2(12, 58), box.position + Vector2(42, 58), Color(0.64, 0.18, 0.13, 0.95), 5.0)
		draw_string(font, box.position + Vector2(52, 62), "Reichsgrenze", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.92, 0.88, 0.78))
		draw_line(box.position + Vector2(12, 79), box.position + Vector2(42, 79), Color(0.98, 0.84, 0.45, 0.95), 4.0)
		draw_string(font, box.position + Vector2(52, 83), "Besitzerwechsel", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.92, 0.88, 0.78))
		draw_circle(box.position + Vector2(14, 100), 7.0, Color(0.20, 0.36, 0.44, 0.94))
		draw_arc(box.position + Vector2(14, 100), 7.0, 0.0, TAU, 16, Color(0.86, 0.68, 0.32, 0.95), 1.5, true)
		draw_string(font, box.position + Vector2(28, 104), "Flotte / Blockade", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.92, 0.88, 0.78))
	else:
		var rows: Array = _legend_rows()
		for i in rows.size():
			var row: Array = rows[i]
			var yy: float = 31.0 + i * 16.0
			draw_line(box.position + Vector2(12, yy), box.position + Vector2(42, yy), row[1], float(row[2]))
			draw_string(font, box.position + Vector2(52, yy + 4), str(row[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.92, 0.88, 0.78))
		draw_string(font, box.position + Vector2(8, h - 8), "Klick wählt · Doppelklick öffnet · Rechtsklick schließt", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.76, 0.70, 0.58))

func _gui_input(event: InputEvent) -> void:
	if game == null:
		return
	if event is InputEventMouseButton:
		if event.pressed and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			zoom_by(1.18 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.85, event.position)
			accept_event()
			return
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_dragging = false
			selected = ""
			hovered = ""
			province_selected.emit("")
			queue_redraw()
			accept_event()
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
			if event.pressed:
				_pick_at(event.position)
				if event.double_click and selected != "":
					province_activated.emit(selected)
				accept_event()
		return
	if event is InputEventMouseMotion:
		if _dragging:
			pan += event.relative
			_clamp_pan()
			_sync_base_transform()
			queue_redraw()
			accept_event()
			return
		hover_at(event.position)
		return
	if event is InputEventScreenTouch:
		_dragging = event.pressed
		if event.pressed:
			_pick_at(event.position)
			accept_event()
		return
	if event is InputEventScreenDrag and _dragging:
		pan += event.relative
		_clamp_pan()
		_sync_base_transform()
		queue_redraw()
		accept_event()

func _on_mouse_exited() -> void:
	if hovered == "":
		return
	hovered = ""
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	queue_redraw()
