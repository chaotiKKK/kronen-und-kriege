extends Control
## Zeichnet Beschriftungen, Auswahlbedienung und Legende über dem
## zwischengespeicherten Kartenunterbau aus MapBase.gd. Der Unterbau wird nur
## bei Daten-/Modus-/Auswahlwechsel neu gezeichnet und beim Pan/Zoom verschoben.

signal province_selected(province_id: String)
signal map_mode_changed(mode: String)
signal province_activated(province_id: String)
signal army_selected(house_index: int, province_id: String)
signal construction_selected(province_id: String, project_id: int)
signal atlas_location_selected(record: Dictionary)

const MapModesScript = preload("res://scripts/MapModes.gd")
const MAP_MODES := MapModesScript.IDS
const MODE_TITLES := MapModesScript.TITLES
const MODE_HINTS := MapModesScript.HINTS
const MotionScript := preload("res://scripts/AtlasMotion.gd")
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
var title_level := "kingdom"
var legend_visible := false
var crests: Array = []
var _edge_neighbor: Dictionary = {}
var _game_id: int = -1
var _edge_catalog_hash := ""
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
var economic_markers_drawn: Array = []
var irrigation_markers_drawn: Array = []
var army_markers_drawn: Array = []
var construction_markers_drawn: Array = []
var _production_snapshot: Dictionary = {}
var _supply_snapshot: Dictionary = {}
var _road_snapshot: Array = []
var _simulation_reports_set := false
var _terrain_tex: Dictionary = {}
var _building_tex: Dictionary = {}
var _unit_tex: Dictionary = {}
var _base
var _motion: Node2D
var map_motion_enabled := true
var atlas_data
var atlas_layer
var atlas_obstacles: Array = []
var atlas_location: String = ""
var _rivers_cache: Array = []
var _base_zoom_bucket := -1
var _last_canvas_size := Vector2.ZERO

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
	_motion = MotionScript.new()
	_motion.host = self
	add_child(_motion)
	_motion.set_enabled(map_motion_enabled)
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
		_simulation_reports_set=false
		if _motion != null:
			_motion.set_deliveries([])
			_motion.set_march_preview({})
		_game_id = game.get_instance_id()
		var catalog: String = game.data.catalog_hash() if game.data.has_method("catalog_hash") else ""
		# Region geometry is immutable and catalog-bound. A network snapshot
		# changes owners/economy, while every edge remains identical.
		if catalog.is_empty() or catalog != _edge_catalog_hash:
			_rebuild_edge_cache()
			_edge_catalog_hash = catalog
	if _base != null:
		_base.queue_redraw()
	queue_redraw()

func set_simulation_reports(production: Dictionary, supply: Dictionary, food: Array = [], march: Dictionary = {}) -> void:
	# Game reports are calculated by Main once per accepted simulation refresh.
	_production_snapshot=production.duplicate(true)
	_supply_snapshot=supply.duplicate(true)
	_road_snapshot=game.road_segments() if game!=null else []
	_simulation_reports_set=true
	if _motion != null:
		_motion.set_deliveries(production.get("flows", []),supply.get("frontier_deliveries", []),food)
		_motion.set_march_preview(march)
	queue_redraw()

func march_route_overlay() -> Dictionary:
	return _motion.march_overlay.duplicate() if _motion != null and map_mode == "war" else {}

func set_mode(mode: String) -> void:
	var clean := MapModesScript.canonical(mode)
	if mode == "duchy": set_title_level("duchy")
	if mode == "kingdom": set_title_level("kingdom")
	if clean == map_mode:
		queue_redraw()
		return
	map_mode = clean
	if _motion != null:
		_motion.play_transition()
	if _base != null:
		_base.queue_redraw()
	queue_redraw()
	map_mode_changed.emit(map_mode)

func set_title_level(level: String) -> void:
	if not level in ["duchy", "kingdom", "empire"] or title_level == level:
		return
	title_level = level
	if _base != null:
		_base.queue_redraw()
	queue_redraw()
	if atlas_layer != null:
		atlas_layer.refresh()
	if map_mode == "titles":
		map_mode_changed.emit(map_mode)

func set_map_motion_enabled(enabled: bool) -> void:
	map_motion_enabled = enabled
	if _motion != null:
		_motion.set_enabled(enabled)

func mode_title() -> String:
	return str(MODE_TITLES.get(map_mode, "Politik"))

func select(id: String) -> void:
	var changed := selected != id
	selected = id
	if changed and _motion != null:
		_motion.play_selection()
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
	if _last_canvas_size.x > 0.0 and _last_canvas_size.y > 0.0 and not size.is_equal_approx(_last_canvas_size):
		var old_fit := minf(_last_canvas_size.x / MAP_SIZE.x, _last_canvas_size.y / MAP_SIZE.y)
		var new_fit := minf(size.x / MAP_SIZE.x, size.y / MAP_SIZE.y)
		if old_fit > 0.0 and new_fit > 0.0:
			# pan / Maßstab bestimmt den geografischen Mittelpunkt, nicht pan allein.
			pan *= new_fit / old_fit
			_clamp_pan()
	_last_canvas_size = size
	var fit := _fit()
	_base.position = fit[1]
	_base.scale = Vector2(float(fit[0]), float(fit[0]))
	if _motion != null and not _motion.paths.is_empty():
		_motion.queue_redraw()
	var bucket := int(zoom)
	if bucket != _base_zoom_bucket:
		_base_zoom_bucket = bucket
		_base.queue_redraw()
	if atlas_layer != null:
		atlas_layer.size = size

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
	_sync_base_transform()
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
	_last_canvas_size = size
	zoom = 1.0
	pan = Vector2.ZERO
	_sync_base_transform()
	queue_redraw()

func center_on(map_point: Vector2) -> void:
	_last_canvas_size = size
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
	zoom = 4.5 if kind in ["country", "region"] else (12.0 if kind == "district" else (48.0 if kind in ["municipality", "local_admin"] else 24.0))
	center_on(point)
	var province_id := _region_for_record(record)
	if game != null and not game.province(province_id).is_empty():
		select(province_id)
		province_selected.emit(province_id)
	else:
		select("")
		province_selected.emit("")
	atlas_location_selected.emit(record)

func _region_for_record(record: Dictionary) -> String:
	if game != null and game.data.has_method("region_at"):
		var region: Dictionary = game.data.region_at(record.get("point", Vector2(-100, -100)))
		return str(region.get("id", ""))
	return str(record.get("province_id", ""))

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
	if game.data.has_method("region_at"):
		return str(game.data.region_at(map_point).get("id", ""))
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
	# Armeeplaketten sind selbst bedienbare Ziele, auch wenn ihr Schild neben
	# der eigentlichen Provinzfläche liegt. Auswahl erteilt niemals Befehle.
	if map_mode == "war":
		var markers := army_markers()
		markers.reverse()
		for marker in markers:
			if (marker.rect as Rect2).has_point(pos):
				select(str(marker.province))
				atlas_location = ""
				province_selected.emit(selected)
				army_selected.emit(int(marker.house),selected)
				queue_redraw()
				return
	for marker in construction_markers():
		if (marker.hit_rect as Rect2).has_point(pos):
			select(str(marker.province))
			atlas_location=""
			province_selected.emit(selected)
			construction_selected.emit(selected,int(marker.id))
			queue_redraw()
			return
	atlas_location = ""
	var record: Dictionary = {}
	var anchor_target := false
	if atlas_layer != null and zoom >= 2.5:
		var fit := _fit()
		var point: Vector2 = (pos - fit[1]) / float(fit[0])
		# Ein verschobenes Namensschild gehört weiterhin zu seinem tatsächlichen Ort.
		for label in atlas_layer.audit_labels:
			if (label.get("rect", Rect2()) as Rect2).has_point(pos):
				record = atlas_data.lookup(str(label.get("id", "")))
				anchor_target = not record.is_empty()
				break
		if record.is_empty():
			record = atlas_data.nearest_city(point, 12.0 / float(fit[0]))
			anchor_target = not record.is_empty()
		if record.is_empty():
			record = atlas_data.feature_at(point, zoom)
		atlas_layer.selected_id = str(record.get("id", ""))
		atlas_location = str(record.get("name", ""))
	var id: String = _province_at(pos)
	if anchor_target:
		var mapped_id := _region_for_record(record)
		id = mapped_id if not game.province(mapped_id).is_empty() else ""
	if id == "":
		if selected != "":
			select("")
			province_selected.emit("")
			queue_redraw()
		if not record.is_empty():
			atlas_location_selected.emit(record)
		return
	select(id)
	hovered = id
	_hover_pos = pos
	province_selected.emit(selected)
	if not record.is_empty():
		atlas_location_selected.emit(record)
	queue_redraw()

func _draw() -> void:
	_sync_base_transform()
	var fit := _fit()
	var s: float = fit[0]
	var off: Vector2 = fit[1]
	fleet_markers_drawn.clear()
	army_markers_drawn.clear()
	construction_markers_drawn.clear()
	capital_markers_drawn.clear()
	kingdom_banners_drawn.clear()
	empire_banners_drawn.clear()
	if game == null:
		draw_rect(Rect2(off, MAP_SIZE * s), Color(0.72, 0.58, 0.34, 0.5), false, 3.0)
		return
	_draw_hover_highlight(s, off)
	_draw_infrastructure(s, off)
	_draw_frontier_supply(s, off)
	_draw_labels(s, off)

func _draw_sea_names(s: float, off: Vector2, occupied: Array) -> void:
	if zoom >= 3.0:
		return
	var font := ThemeDB.fallback_font
	var font_size := int(round(13.0 * preload("res://scripts/ModernInterface.gd").text_scale))
	for sea in seas():
		var position: Vector2 = off + sea.pos * s
		if not Rect2(Vector2.ZERO, size).has_point(position):
			continue

		var width := font.get_string_size(sea.name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var bounds := Rect2(position - Vector2(0, font_size), Vector2(width, font_size + 3))
		if occupied.any(func(obstacle: Rect2) -> bool: return obstacle.grow(3).intersects(bounds)):
			continue
		draw_string_outline(font, position, sea.name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3, Color(0.08, 0.16, 0.18, 0.85))
		draw_string(font, position, sea.name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.85, 0.91, 0.88, 0.85))
		occupied.append(bounds)

func infrastructure_segments() -> Array:
	var segments: Array = []
	if game == null:
		return segments
	var transport := {}
	if map_mode in ["economy","war"]:
		var supply: Dictionary=_supply_snapshot if _simulation_reports_set else game.supply_report()
		for edge in supply.get("roads",[]):
			transport[_road_key(str(edge.from),str(edge.to))] = edge
	for road in (_road_snapshot if _simulation_reports_set else game.road_segments()):
		var a: Dictionary = game.province(str(road.from))
		var b: Dictionary = game.province(str(road.to))
		if a.is_empty() or b.is_empty():
			continue
		var edge: Dictionary = transport.get(_road_key(str(road.from),str(road.to)),{})
		segments.append({"from":str(road.from),"to":str(road.to),"a": _label_point(a), "b": _label_point(b), "state": road.state, "months": road.months,"transport_active":bool(edge.get("active",false)),"transport_reason":str(edge.get("reason","")),"own_route":int(a.owner)==game.player or int(b.owner)==game.player})
	return segments

func _road_key(a: String, b: String) -> String:
	return a+"|"+b if a<b else b+"|"+a

func _draw_infrastructure(s: float, off: Vector2) -> void:
	if map_mode not in ["political", "economy", "war"]:
		return
	for segment in infrastructure_segments():
		var a: Vector2 = off + segment.a * s
		var b: Vector2 = off + segment.b * s
		var width: float = clampf(2.0 * s, 2.5, 6.0)
		if segment.state == "complete":
			var road_color := Color("d5b97a") if map_mode == "economy" else Color("b0a490")
			if map_mode in ["economy","war"] and bool(segment.own_route):
				road_color = Color("77c9a4") if bool(segment.transport_active) else Color("d58b72")
			draw_line(a, b, Color(0.12, 0.08, 0.035, 0.92), width + 3.0, true)
			draw_line(a, b, road_color, width, true)
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

func frontier_supply_paths() -> Array:
	if game == null or map_mode != "war":
		return []
	var report: Dictionary = _supply_snapshot if _simulation_reports_set else game.supply_report()
	var paths := {}
	for delivery in report.get("frontier_deliveries",[]):
		var path: Array = delivery.get("path",[])
		if path.size() < 2:
			continue
		paths[JSON.stringify(path)] = path
	return paths.values()

func _draw_frontier_supply(s: float, off: Vector2) -> void:
	for path in frontier_supply_paths():
		var points := PackedVector2Array()
		for id in path:
			var region: Dictionary = game.province(str(id))
			if region.is_empty():
				break
			points.append(off + _label_point(region) * s)
		if points.size() != path.size():
			continue
		draw_polyline(points, Color(0.035,0.11,0.1,0.95), 7.0, true)
		draw_polyline(points, Color("8de6ce"), 3.0, true)
		draw_circle(points[0], 4.5, Color("8de6ce"), true, -1.0, true)

func _draw_labels(s: float, off: Vector2) -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var font := ThemeDB.fallback_font
	var map_rect := Rect2(off, MAP_SIZE * s)
	var inner := map_rect.intersection(Rect2(Vector2.ZERO, size)).grow(-3)
	atlas_obstacles.clear()
	economic_markers_drawn.clear()
	irrigation_markers_drawn.clear()
	# Die Minimap ist ein Geschwister-Control; ihr Raum gehört nicht den Labels.
	if get_parent() != null:
		for sibling in get_parent().get_children():
			if sibling is Control and sibling.get_script() == preload("res://scripts/WorldMiniMap.gd") and sibling.visible:
				atlas_obstacles.append(Rect2(sibling.global_position - global_position, sibling.size))
	if inner.size.x < 80 or inner.size.y < 40:
		return
	var occupied: Array = []
	atlas_obstacles.append_array(_military_obstacles())
	_draw_undertaking_marker(inner)
	occupied.append_array(atlas_obstacles)
	var font_scale: float = preload("res://scripts/ModernInterface.gd").text_scale
	var fs_title := int(round(19 * font_scale))
	var fs_owner := int(round(13 * font_scale))
	var fs_label := int(round(13 * font_scale))
	# In der Nahansicht übernehmen echte Orte und Verwaltungsgrenzen den Platz.
	if atlas_layer != null and zoom >= 2.5:
		labels_drawn = 0
		if map_mode == "war":
			_draw_war_markers(s, off, font)
		elif map_mode == "economy":
			_draw_irrigation_models(inner)
			_draw_market_models(s, off, inner)
			_draw_economic_markers(font)
		_draw_construction_markers(font)
		_draw_construction_cues()
		_draw_hover_tooltip(font)
		if legend_visible:
			_draw_legend(map_rect, font)
		return

	# Die Blender-Marker sitzen an den Halte- und Königreichssitzen. Sie werden
	# vor den Titeln eingeplant, damit die Beschriftung nicht auf ihnen landet.
	if map_mode in ["political", "titles"]:
		_draw_3d_markers(s, off, occupied, inner)
	elif map_mode == "economy":
		_draw_irrigation_models(inner)
		_draw_market_models(s, off, inner)
		occupied.append_array(atlas_obstacles)
		_draw_economic_markers(font)
		for marker in economic_markers_drawn: occupied.append(marker.rect)
	_draw_construction_markers(font)
	for marker in construction_markers_drawn: occupied.append(marker.hit_rect)

	# Neun Königreichstitel; sie bekommen zuerst Platz.
	var groups: Array = []
	var seen := {}
	for p in game.provinces:
		var field := title_level if map_mode == "titles" else ("empire" if map_mode == "terrain" else "owner")
		var kid := str(p[field])
		if seen.has(kid):
			continue
		seen[kid] = true
		var sum := Vector2.ZERO
		var count := 0
		var income := 0
		var levy := 0
		for q in game.provinces:
			if str(q[field]) != kid:
				continue
			sum += _label_point(q) * s + off
			count += 1
			income += int(game.region_income(q))
			levy += int(q.get("levy",0))
		groups.append({"id": kid, "pos": sum / maxf(1.0, float(count)), "p": p, "field":field, "count":count,"income":income,"levy":levy})
	for g in groups:
		var p: Dictionary = g["p"]
		var title: String = str(p.get(str(g.field) + "_name", "")) if str(g.field) != "owner" else str(game.houses[int(p.owner)].name)
		var house_name: String = "Angestammter Titel" if map_mode in ["terrain", "titles"] else "%d Spielregionen" % int(g.count)
		if map_mode == "economy": house_name = "%d Gold/Jahr" % int(g.income)
		if map_mode == "war": house_name = "%d Mann Aufgebot" % int(g.levy)
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
		var hcol: Color = game.houses[int(p["owner"])].get("color", GOLD) if map_mode == "political" else MapModesScript.ACCENTS[map_mode]
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
		if map_mode == "economy":
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
	_draw_sea_names(s, off, occupied)
	atlas_obstacles.append_array(occupied)

	if map_mode == "war":
		_draw_war_markers(s, off, font)

	if legend_visible:
		_draw_legend(map_rect, font)
	draw_rect(map_rect, Color(0.72, 0.58, 0.34, 0.5), false, 3.0)
	_draw_construction_cues()
	_draw_hover_tooltip(font)

func _military_obstacles() -> Array:
	var occupied: Array=[]
	if game==null or map_mode!="war": return occupied
	var fit:=_fit()
	var s: float=fit[0]
	var off: Vector2=fit[1]
	for army in army_markers(): occupied.append(army.rect)
	for marker in siege_markers():
		var pos: Vector2=marker.anchor*s+off
		occupied.append(Rect2(pos-Vector2(16,16),Vector2(60,34)))
	for house in game.houses:
		for fleet in house.get("fleets",[]):
			var station: Dictionary=game.province(str(fleet.get("station","")))
			if station.is_empty(): continue
			var pos: Vector2=_label_point(station)*s+off+Vector2(0,22)
			if int(station.get("siege",0))>0: pos+=Vector2(20,0)
			var text_size:=ThemeDB.fallback_font.get_string_size(str(int(fleet.get("ships",0))),HORIZONTAL_ALIGNMENT_LEFT,-1,9)
			occupied.append(Rect2(pos-Vector2(17,17),Vector2(34,34)).merge(Rect2(pos+Vector2(16,-5),text_size+Vector2(1,3))))
	return occupied

func _construction_obstacles() -> Array:
	var occupied: Array=_military_obstacles()
	if get_parent()!=null:
		for sibling in get_parent().get_children():
			if sibling is Control and sibling.get_script()==preload("res://scripts/WorldMiniMap.gd") and sibling.visible:
				occupied.append(Rect2(sibling.global_position-global_position,sibling.size))
	if map_mode=="economy":
		for marker in focus_markers(): occupied.append(marker.rect)
	if atlas_layer!=null and zoom>=2.5: return occupied
	var fit:=_fit()
	var s: float=fit[0]
	var off: Vector2=fit[1]
	var inner:=Rect2(off,MAP_SIZE*s).intersection(Rect2(Vector2.ZERO,size)).grow(-3)
	var ms:=marker_scale_for(s)
	for spec in marker_specs():
		var pos: Vector2=spec.pos*s+off
		var castle_size:=Vector2(27,27)*ms
		var banner_size:=Vector2(22,32)*ms
		occupied.append(_clamp_marker_rect(Rect2(pos+Vector2(-castle_size.x*0.5,18*ms-castle_size.y),castle_size),inner).grow(2))
		occupied.append(_clamp_marker_rect(Rect2(pos+Vector2(11*ms,18*ms-banner_size.y),banner_size),inner).grow(2))
		# Existing crest and completed-building tokens sit above/below the same seat.
		var crest_size:=Vector2(19,23) if s<0.9 else Vector2(23,28)
		var crest:=_clamp_marker_rect(Rect2(pos+Vector2(-crest_size.x*0.5,-crest_size.y-3),crest_size),inner)
		occupied.append(crest.grow(2))
		occupied.append(Rect2(crest.position+Vector2(0,crest_size.y+2),Vector2(42,13)).grow(2))
	return occupied

func construction_markers() -> Array:
	var markers: Array=[]
	if game==null or not _simulation_reports_set or size.x<100 or size.y<60: return markers
	var fit:=_fit()
	var scale: float=preload("res://scripts/ModernInterface.gd").text_scale
	var font:=ThemeDB.fallback_font
	var viewport:=Rect2(Vector2(3,3),size-Vector2(6,6))
	var occupied:=_construction_obstacles()
	var sites: Array=_production_snapshot.get("sites",[]).duplicate()
	sites.sort_custom(func(a,b):
		if (str(a.province)==selected)!=(str(b.province)==selected): return str(a.province)==selected
		return int(a.id)<int(b.id))
	for site in sites:
		if int(site.owner)!=game.player: continue
		var province_id:=str(site.province)
		var province: Dictionary=game.province(province_id)
		if province.is_empty() or int(province.owner)!=game.player: continue
		var point: Vector2=_label_point(province)
		if str(site.kind)=="road":
			var a: Dictionary=game.province(str(site.from))
			var b: Dictionary=game.province(str(site.to))
			if a.is_empty() or b.is_empty(): continue
			if selected in [str(site.from),str(site.to)]:
				province_id=selected; point=_label_point(game.province(selected))
			else: point=(_label_point(a)+_label_point(b))*0.5
		var anchor: Vector2=point*float(fit[0])+Vector2(fit[1])
		if not viewport.has_point(anchor): continue
		var progress:=clampf(float(site.progress),0,1)
		var label:=("Straße" if str(site.kind)=="road" else "Bau")+" %d %%" % int(progress*100)
		if bool(site.blocked): label="Bau pausiert"
		var font_size:=int(round(11*scale))
		var measured:=font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size)
		var box_size:=Vector2(maxf(44,measured.x+16),maxf(44,measured.y+18))
		var chosen:=Rect2()
		var offsets: Array=[Vector2(18,-box_size.y*0.5),Vector2(-box_size.x-18,-box_size.y*0.5),Vector2(-box_size.x*0.5,-box_size.y-20),Vector2(-box_size.x*0.5,24),Vector2(36,-box_size.y-28),Vector2(-box_size.x-36,-box_size.y-28),Vector2(36,34),Vector2(-box_size.x-36,34)]
		for step in [1,2]:
			for offset in offsets:
				var candidate:=Rect2(anchor+Vector2(offset)*step,box_size)
				candidate.position.x=clampf(candidate.position.x,viewport.position.x,maxf(viewport.position.x,viewport.end.x-box_size.x))
				candidate.position.y=clampf(candidate.position.y,viewport.position.y,maxf(viewport.position.y,viewport.end.y-box_size.y))
				if not viewport.encloses(candidate): continue
				if occupied.any(func(rect):return (rect as Rect2).grow(2).intersects(candidate)): continue
				chosen=candidate; break
			if chosen.has_area(): break
		if not chosen.has_area(): continue
		occupied.append(chosen)
		var marker: Dictionary={"id":int(site.id),"province":province_id,"kind":str(site.kind),"name":str(site.name),"anchor":anchor,"rect":chosen,"hit_rect":chosen,"progress":progress,"blocked":bool(site.blocked),"label":label,"font_size":font_size}
		marker["cue"]=_construction_cue(marker)
		markers.append(marker)
	return markers

func _construction_cue(marker: Dictionary) -> Dictionary:
	var rect: Rect2=marker.rect
	var anchor: Vector2=marker.anchor
	if not rect.has_area() or rect.has_point(anchor): return {}
	var direction:=anchor-rect.get_center()
	var fraction:=INF
	if absf(direction.x)>0.0001: fraction=minf(fraction,rect.size.x*0.5/absf(direction.x))
	if absf(direction.y)>0.0001: fraction=minf(fraction,rect.size.y*0.5/absf(direction.y))
	# Stop at the first actual rectangle edge along the anchor ray. Clamping
	# coordinates separately would send diagonal leaders to the wrong corner.
	var endpoint:=rect.get_center()+direction*fraction
	if anchor.distance_to(endpoint)<=1.0: return {}
	var scale: float=clampf(preload("res://scripts/ModernInterface.gd").text_scale,1.0,1.5)
	return {"anchor":anchor,"end":endpoint,"width":2.0*scale,"radius":3.0*scale,"ink":Color("dfb765") if not bool(marker.blocked) else Color("e69b7a")}

func _draw_construction_markers(font: Font) -> void:
	for marker in construction_markers():
		var rect: Rect2=marker.rect
		var ink:=Color("dfb765") if not marker.blocked else Color("e69b7a")
		draw_rect(rect,Color(0.035,0.06,0.07,0.94))
		draw_rect(rect,ink,false,1.5)
		draw_string(font,rect.position+Vector2(8,font.get_ascent(int(marker.font_size))+5),marker.label,HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-16,int(marker.font_size),ink)
		var bar:=Rect2(rect.position+Vector2(7,rect.size.y-10),Vector2(rect.size.x-14,4))
		draw_rect(bar,Color(0.15,0.2,0.2))
		bar.size.x*=float(marker.progress)
		draw_rect(bar,ink)
		construction_markers_drawn.append(marker)
		atlas_obstacles.append(marker.hit_rect)

func _draw_construction_cues() -> void:
	# Use precisely the badges drawn in this frame. The final pass keeps the
	# real anchor visible above map labels without extending any input target.
	var halo:=Color(0.015,0.02,0.025,1.0)
	for marker in construction_markers_drawn:
		var cue: Dictionary=marker.cue
		if cue.is_empty(): continue
		draw_line(cue.anchor,cue.end,halo,float(cue.width)+3.0,true)
		draw_line(cue.anchor,cue.end,cue.ink,float(cue.width),true)
		draw_circle(cue.anchor,float(cue.radius)+2.0,halo,true,-1,true)
		draw_circle(cue.anchor,float(cue.radius),cue.ink,true,-1,true)

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
		if not inner.grow(18.0).has_point(pos):
			continue
		var castle_size := Vector2(34.0, 34.0) * ms
		var castle_rect := _clamp_marker_rect(Rect2(
			pos + Vector2(-castle_size.x * 0.5, 18.0 * ms - castle_size.y),
			castle_size), inner)
		var banner_size := Vector2(22.0, 32.0) * ms
		var banner_rect := _clamp_marker_rect(Rect2(
			pos + Vector2(11.0 * ms, 18.0 * ms - banner_size.y),
			banner_size), inner)
		var shade_pos := Vector2(pos.x, castle_rect.end.y - 2.0 * ms)
		draw_circle(shade_pos, 10.0 * ms, Color(0.035, 0.025, 0.015, 0.32))
		if bool(spec.get("imperial", false)) and map_mode in ["political","titles"]:
			var halo := banner_rect.get_center()
			draw_circle(halo, 15.0 * ms, Color(0.94, 0.70, 0.24, 0.14))
			draw_arc(halo, 15.0 * ms, 0.0, TAU, 28, Color(0.95, 0.75, 0.28, 0.90), 1.7 * ms, true)
		draw_texture_rect(MapModesScript.MINIATURES[map_mode], castle_rect, false, Color(1, 1, 1, 0.98))
		if map_mode in ["political","titles"]:
			draw_texture_rect(MARKER_BANNER, banner_rect, false, Color(1, 1, 1, 0.98))
			occupied.append(banner_rect.grow(1.0))
		occupied.append(castle_rect.grow(1.0))
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
	return MapModesScript.fill(game, p, map_mode, title_level, selected)

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

func focus_markers() -> Array:
	var markers: Array = []
	if game == null or map_mode != "economy": return markers
	var fit := _fit()
	var scale: float = preload("res://scripts/ModernInterface.gd").text_scale
	var font := ThemeDB.fallback_font
	for p in game.provinces:
		var focus := str(p.get("economic_focus","balanced"))
		if not focus in ["agriculture","trade","workshops"]: continue
		if zoom < 1.6 and int(p.owner) != game.player and str(p.id) != selected: continue
		var anchor: Vector2 = _label_point(p)*float(fit[0])+Vector2(fit[1])
		if not Rect2(Vector2.ZERO,size).has_point(anchor): continue
		var label := str({"agriculture":"Kornkammer","trade":"Handelsort","workshops":"Werkstätten"}[focus])
		var width := font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,int(11*scale)).x+12
		var rect := Rect2(anchor+Vector2(12,14),Vector2(width,20*scale))
		rect.position.x = clampf(rect.position.x,0,maxf(0,size.x-rect.size.x))
		rect.position.y = clampf(rect.position.y,0,maxf(0,size.y-rect.size.y))
		markers.append({"id":str(p.id),"focus":focus,"label":label,"rect":rect,"color":Color("97d4a2") if focus=="agriculture" else Color("edd18c")})
	return markers

func irrigation_markers() -> Array:
	var markers: Array = []
	if game==null or map_mode!="economy": return markers
	var fit:=_fit()
	# Keep an overview focused on the selected works. At regional zoom the
	# other finished sites get the same durable icon.
	var candidates: Array = game.provinces if zoom>=1.68 else [game.province(selected)]
	for p in candidates:
		if p.is_empty() or int(p.logistics_sites.get("irrigation_works",0))!=1: continue
		var emphasized: bool = str(p.id)==selected
		var extent := 42.0 if emphasized else 32.0
		var pivot: Vector2 = _label_point(p)*float(fit[0])+fit[1]
		var rect := Rect2(pivot+Vector2(-extent*.68,-extent-4),Vector2.ONE*extent)
		if not Rect2(Vector2.ZERO,size).encloses(rect): continue
		markers.append({"id":str(p.id),"rect":rect,"emphasized":emphasized})
	markers.sort_custom(func(a,b): return a.emphasized and not b.emphasized)
	return markers.slice(0,16)

func irrigation_flow_active() -> bool:
	if game==null or map_mode!="economy" or selected.is_empty(): return false
	var p: Dictionary = game.province(selected)
	if p.is_empty() or int(p.owner)!=game.player or int(p.logistics_sites.get("irrigation_works",0))!=1: return false
	var report: Dictionary = _production_snapshot if _simulation_reports_set else {}
	return report.get("regions",{}).get(selected,{}).get("blocked_reason","")==""

func _draw_irrigation_models(inner: Rect2) -> void:
	var texture = preload("res://assets/map/irrigation/irrigation_works.png")
	for marker in irrigation_markers():
		var rect: Rect2 = marker.rect
		if not inner.encloses(rect): continue
		if atlas_obstacles.any(func(obstacle: Rect2) -> bool: return obstacle.intersects(rect.grow(2.0))):
			continue
		draw_texture_rect(texture,rect,false)
		irrigation_markers_drawn.append(marker)
		atlas_obstacles.append(rect.grow(2))

func _draw_market_models(scale: float, offset: Vector2, inner: Rect2) -> void:
	var shown := 0
	var candidates: Array = game.provinces.duplicate()
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.id == selected) > int(b.id == selected) if (a.id == selected) != (b.id == selected) else int(a.buildings.market) > int(b.buildings.market))
	for province in candidates:
		if shown >= 12:
			break
		if int(province.buildings.market) <= 0:
			continue
		var point: Vector2 = _label_point(province) * scale + offset
		var extent := 28.0 if zoom < 2.5 else 36.0
		var rect := Rect2(point + Vector2(-extent / 2.0, -extent - 5.0), Vector2.ONE * extent)
		if not inner.encloses(rect):
			continue
		if atlas_obstacles.any(func(obstacle: Rect2) -> bool: return obstacle.intersects(rect.grow(2.0))):
			continue
		draw_texture_rect(MapModesScript.MINIATURES.economy, rect, false)
		atlas_obstacles.append(rect.grow(2.0))
		shown += 1

func undertaking_marker() -> Dictionary:
	if game==null: return {}
	var active: Dictionary=game.house().get("undertaking",{}).get("active",{})
	if active.is_empty() or str(game.ReignUndertakingsScript.CATALOG[active.id].map)!=map_mode: return {}
	var p: Dictionary=game.province(str(active.province))
	if p.is_empty(): return {}
	var fit := _fit()
	var point: Vector2=_label_point(p)*float(fit[0])+fit[1]
	return {"id":str(p.id),"rect":Rect2(point+Vector2(-15,-37),Vector2(30,33)),
		"owned":int(p.owner)==game.player}

func _draw_undertaking_marker(inner: Rect2) -> void:
	var marker := undertaking_marker()
	if marker.is_empty() or not inner.encloses(marker.rect): return
	var rect: Rect2=marker.rect
	var center := rect.get_center()
	var tint := Color("f8dc8d") if marker.owned else Color("c29f92")
	draw_circle(center,14,Color(.035,.075,.085,.9),true,-1,true)
	draw_circle(center,14,tint,false,1.2,true)
	draw_texture_rect(preload("res://assets/map/undertakings/undertaking_marker.png"),rect,false)
	atlas_obstacles.append(rect.grow(2))

func _draw_economic_markers(font: Font) -> void:
	var scale: float = preload("res://scripts/ModernInterface.gd").text_scale
	for marker in focus_markers():
		var rect: Rect2 = marker.rect
		draw_rect(rect,Color(.035,.06,.07,.92))
		draw_rect(rect,marker.color,false,1)
		draw_string(font,rect.position+Vector2(6,14*scale),marker.label,HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-12,int(11*scale),marker.color)
		economic_markers_drawn.append(marker)
		atlas_obstacles.append(rect)

func army_markers() -> Array:
	var markers: Array = []
	if game == null or map_mode != "war" or size.x < 100 or size.y < 44:
		return markers
	var fit := _fit()
	var counts := {}
	# Eigene Verbände zuletzt zeichnen: sie bleiben an umkämpften Orten wählbar.
	var order: Array = range(game.houses.size())
	order.erase(game.player)
	order.append(game.player)
	for house_index in order:
		for army in game.houses[house_index].get("armies",[]):
			if int(army.get("strength",0)) <= 0: continue
			var id := str(army.get("province",""))
			var station: Dictionary = game.province(id)
			if station.is_empty(): continue
			var pos: Vector2 = _label_point(station)*float(fit[0])+Vector2(fit[1])
			if not Rect2(Vector2.ZERO,size).has_point(pos): continue
			var row := int(counts.get(id,0))
			counts[id] = row+1
			var origin := pos+Vector2(-48,-52-row*46)
			origin.x = clampf(origin.x,0,size.x-100)
			origin.y = clampf(origin.y,0,size.y-44)
			var rect := _free_army_rect(origin,markers)
			markers.append({"house":house_index,"province":id,"army":int(army.id),"strength":int(army.strength),"morale":int(army.get("morale",0)),"anchor":pos,"rect":rect})
	return markers

func _free_army_rect(origin: Vector2, placed: Array) -> Rect2:
	# Nach dem Begrenzen an den Viewportrand dürfen Marker nicht zusammenfallen.
	# Nächsten freien Rasterplatz suchen; Darstellung und Touch nutzen denselben Ort.
	var best := Rect2(origin,Vector2(100,44))
	var clear := true
	for marker in placed:
		if best.intersects(marker.rect): clear = false; break
	if clear: return best
	var distance := INF
	var columns := maxi(1,int(size.x/104))
	var rows := maxi(1,int(size.y/46))
	for y in range(-rows,rows+1):
		for x in range(-columns,columns+1):
			var offset := Vector2(x*104,y*46)
			if offset.length_squared() >= distance: continue
			var candidate := Rect2(origin+offset,Vector2(100,44))
			if not Rect2(Vector2.ZERO,size).encloses(candidate): continue
			var collision := false
			for marker in placed:
				if candidate.intersects(marker.rect): collision = true; break
			if not collision:
				best = candidate
				distance = offset.length_squared()
	return best

func siege_markers() -> Array:
	var markers: Array=[]
	if game==null or map_mode!="war": return markers
	for p in game.provinces:
		var progress:=clampi(int(p.get("siege",0)),0,100)
		if progress<=0: continue
		var hi:=int(p.get("siege_owner",-1))
		var color: Color=game.houses[hi].get("color",GOLD) if hi>=0 and hi<game.houses.size() else GOLD
		markers.append({"province":str(p.id),"house":hi,"progress":progress,"anchor":_label_point(p),
			"start_angle":-PI/2,"end_angle":-PI/2+TAU*progress/100.0,"color":color})
	return markers

func _draw_war_markers(s: float, off: Vector2, font: Font) -> void:
	_draw_naval_route()
	for marker in siege_markers():
		var pos: Vector2=marker.anchor*s+off
		var color: Color=marker.color
		var siege: int=marker.progress
		var token: Texture2D = MapModesScript.MINIATURES.war
		if token != null:
			draw_texture_rect(token, Rect2(pos - Vector2(14, 14), Vector2(28, 28)), false)
			draw_arc(pos,15.0,0.0,TAU,32,Color(.03,.03,.025,.85),4.0,true)
			draw_arc(pos,15.0,marker.start_angle,marker.end_angle,32,color,2.5,true)
			draw_string(font, pos + Vector2(16, 4), "%d%%" % siege, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1.0, 0.96, 0.86))
		else:
			draw_circle(pos, 12.0, Color(0.55, 0.10, 0.06, 0.92))
			draw_arc(pos,12.0,0.0,TAU,32,Color(.03,.03,.025,.85),4.0,true)
			draw_arc(pos,12.0,marker.start_angle,marker.end_angle,32,color,2.5,true)
			draw_string(font, pos + Vector2(-10, 4), "%d%%" % siege, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1.0, 0.96, 0.86))
	for marker in army_markers():
		var hit: Rect2 = marker.rect
		var panel := Rect2(hit.position+Vector2(0,6),Vector2(hit.size.x,32))
		var own: bool = int(marker.house) == game.player
		var color: Color = game.houses[int(marker.house)].get("color",GOLD)
		if panel.get_center().distance_to(marker.anchor) > 62:
			draw_line(panel.get_center(),marker.anchor,Color(color,0.7),1,true)
		draw_rect(panel,Color(.035,.06,.07,.94))
		draw_rect(panel,CREAM if own else color,false,2 if own else 1)
		draw_string(font,panel.position+Vector2(6,14),"%d Mann" % int(marker.strength),HORIZONTAL_ALIGNMENT_LEFT,88,12,CREAM)
		draw_string(font,panel.position+Vector2(6,27),"Moral %d · %s" % [int(marker.morale),"dein Heer" if own else "fremd"],HORIZONTAL_ALIGNMENT_LEFT,90,9,CREAM)
		army_markers_drawn.append(marker)
		atlas_obstacles.append(panel)
	# Flotten stehen an ihrer tatsächlichen Station: operativer Stützpunkt oder
	# blockierte Küste. Der Ring trägt die Hausfarbe, die Zahl die Schiffszahl.
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

func naval_route_overlay() -> Dictionary:
	if game==null or map_mode!="war" or selected.is_empty(): return {}
	var preview: Dictionary = game.naval_transport_preview(selected)
	if str(preview.get("route_id","")).is_empty(): return {}
	var fit := _fit()
	var points := PackedVector2Array()
	for point in preview.route_points: points.append(point*float(fit[0])+fit[1])
	return {"route_id":preview.route_id,"origin":preview.origin,"target":preview.target,
		"map_points":preview.route_points,"points":points,"ready":preview.ok,"reason":preview.reason}

func _draw_naval_route() -> void:
	var overlay := naval_route_overlay()
	if overlay.is_empty(): return
	var points: PackedVector2Array = overlay.points
	var color := Color(GOLD,0.95 if overlay.ready else 0.55)
	for index in range(1,points.size()):
		draw_line(points[index-1],points[index],Color(.05,.045,.025,.85),4.0,true)
		draw_line(points[index-1],points[index],color,2.0,true)
	for point in [points[0],points[points.size()-1]]:
		draw_circle(point,4.0,Color(.05,.045,.025,.9))
		draw_circle(point,2.5,color)
	var end: Vector2 = points[points.size()-1]
	var direction: Vector2 = (end-points[points.size()-2]).normalized()
	var side := Vector2(-direction.y,direction.x)
	draw_line(end,end-direction*9+side*4,color,2.0,true)
	draw_line(end,end-direction*9-side*4,color,2.0,true)

func _legend_rows() -> Array:
	var styles := MapModesScript.border_styles(map_mode)
	var rows: Array = []
	if map_mode == "terrain":
		rows = [["Feste Königreichsgrenze",styles.kingdom[0],styles.kingdom[1]],["Feste Reichsgrenze",styles.empire[0],styles.empire[1]]]
	elif map_mode == "titles":
		rows = [["Angestammte " + {"duchy":"Herzogtümer","kingdom":"Königreiche","empire":"Reiche"}[title_level],styles[title_level][0],styles[title_level][1]]]
	elif map_mode == "war":
		rows = [["Grenze deines Hauses",styles.front[0],styles.front[1]],["Andere Hausgrenze",styles.owner[0],styles.owner[1]]]
	else:
		rows = [["Tatsächliche Hausgrenze",styles.owner[0],styles.owner[1]]]
	return rows

func _draw_legend(map_rect: Rect2, font: Font) -> void:
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
	var ui_scale: float = preload("res://scripts/ModernInterface.gd").text_scale
	var rows := _legend_rows()
	var explanations: Array = {
		"political":["Flächen: aktueller Hausbesitz","Eroberungen verschieben diese Grenzen"],
		"terrain":["Relief, Flüsse und Geländesymbole","Titelgrenzen bleiben bei Eroberung fest"],
		"titles":["Rechtsebene oben umschalten","Titelgebiet und Besitz können abweichen"],
		"economy":["Braun → Gold → Grün: Ertrag","Schilder: örtliche Schwerpunkte","Grün: nutzbare eigene Straße","Rot: Versorgung unterbrochen","Lichtpunkt: gebuchte Baustofflieferung","Wagen: Nahrungsfracht im letzten Monat","Kanalbau: fertiges Bewässerungswerk"],
		"war":["Grün: eigene Spielregionen","Orange: aktuell angreifbare Gebiete","Grau: weitere Gebiete · Ringe: Belagerung","Gold: gewählter Seeweg","Mint: eigener Frontnachschub aus Depot","Gestrichelter Pfeil: geplanter Marsch","Rosafarbener Pfeil: Versorgungslücke"],
	}[map_mode]
	var w := minf(320.0*ui_scale,size.x-24)
	var h := (36.0 + (rows.size()+explanations.size())*20.0)*ui_scale
	var origin := map_rect.position.max(Vector2.ZERO)+Vector2(12,12)
	origin.x = clampf(origin.x,8,maxf(8,size.x-w-8))
	origin.y = clampf(origin.y,8,maxf(8,size.y-h-8))
	var box := Rect2(origin,Vector2(w,h))
	draw_rect(box,Color(.045,.055,.055,.94))
	draw_rect(box,Color(.72,.61,.38,.65),false,1)
	var fs := int(round(12*ui_scale))
	draw_string(font,origin+Vector2(10,20)*ui_scale,"KARTE · "+mode_title(),HORIZONTAL_ALIGNMENT_LEFT,w-20,fs,CREAM)
	var y := 43.0*ui_scale
	for row in rows:
		draw_line(origin+Vector2(10*ui_scale,y-4*ui_scale),origin+Vector2(34*ui_scale,y-4*ui_scale),row[1],float(row[2])*ui_scale,true)
		draw_string(font,origin+Vector2(42*ui_scale,y),str(row[0]),HORIZONTAL_ALIGNMENT_LEFT,w-52*ui_scale,fs,CREAM)
		y += 20*ui_scale
	for line in explanations:
		draw_string(font,origin+Vector2(10*ui_scale,y),str(line),HORIZONTAL_ALIGNMENT_LEFT,w-20*ui_scale,fs,Color("d7cfbc"))
		y += 20*ui_scale

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
	# Ein nachlaufendes Mouse-Exit kann bereits im Szenenabbau eintreffen.
	if not is_inside_tree():
		return
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	queue_redraw()
