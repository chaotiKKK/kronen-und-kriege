extends Control
## Statischer Kartenunterbau: Textur, Gelände, Provinzflächen und Grenzen.
## Die Ebene wird nur bei Daten-/Modus-/Auswahlwechsel neu gezeichnet; Pan und
## Zoom verschieben sie als Ganzes. Dadurch bleiben die teuren Grenzlinien
## zwischengespeichert und müssen beim Ziehen nicht jede Frame neu entstehen.

const MAP_SIZE := Vector2(1200, 760)
const EUROPE := preload("res://assets/map/atlas_terrain.webp")
const RELIEF := preload("res://assets/map/generated/relief_shaded.png")
const RELIEF_SHADER := preload("res://shaders/map_relief.gdshader")

var host
var _relief_overlay: TextureRect
var _relief_material: ShaderMaterial

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = true
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_relief_material = ShaderMaterial.new()
	_relief_material.shader = RELIEF_SHADER
	_relief_overlay = TextureRect.new()
	_relief_overlay.texture = RELIEF
	_relief_overlay.position = Vector2.ZERO
	_relief_overlay.size = MAP_SIZE
	_relief_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_relief_overlay.stretch_mode = TextureRect.STRETCH_SCALE
	_relief_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_relief_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_relief_overlay.material = _relief_material
	# Der neue Untergrund enthält bereits geografisch passende Schummerung.
	# Das frühere prozedurale Relief bleibt als Projektasset erhalten.
	_relief_overlay.visible = false
	add_child(_relief_overlay)

func _draw() -> void:
	if host == null:
		return
	draw_texture_rect(EUROPE, Rect2(Vector2.ZERO, MAP_SIZE), false)

	if host.game == null:
		return

	# Provinzflächen: je nach Modus politisch, Gelände, Titel, Entwicklung oder Krieg.
	for p in host.game.provinces:
		var base: Color = host._fill_color(p)
		for part in host._province_parts(p):
			draw_colored_polygon(part, base)
	_sync_relief_strength()
	_draw_geography(host.map_mode == "terrain")

	var border_batches: Dictionary = {
		"province": [], "duchy": [], "kingdom": [], "owner": [], "empire": [], "coast": [],
	}
	for p in host.game.provinces:
		var parts: Array = host._province_parts(p)
		for pi in parts.size():
			var pts: PackedVector2Array = parts[pi]
			for i in pts.size():
				var a: Vector2 = pts[i]
				var b: Vector2 = pts[(i + 1) % pts.size()]
				var nid: String = str(host._edge_neighbor.get("%s|%d|%d" % [p["id"], pi, i], ""))
				var q: Dictionary = host.game.province(nid) if nid != "" else {}
				var key := "province"
				if q.is_empty():
					key = "coast"
				elif str(p["empire"]) != str(q["empire"]):
					key = "empire"
				elif int(p["owner"]) != int(q["owner"]):
					key = "owner"
				elif str(p["kingdom"]) != str(q["kingdom"]):
					key = "kingdom"
				elif str(p["duchy"]) != str(q["duchy"]):
					key = "duchy"
				var seg: Array = border_batches[key]
				seg.append(a)
				seg.append(b)
	var screen_scale: float = maxf(0.1, float(host._fit()[0]))
	var border_style := {
		"province": [Color(0.16, 0.18, 0.13, 0.20), 0.55],
		"duchy": [Color(0.32, 0.30, 0.20, 0.38), 0.8],
		"kingdom": [Color(0.50, 0.40, 0.23, 0.68), 1.1],
		"owner": [Color(0.95, 0.82, 0.49, 0.85), 1.6],
		"empire": [Color(0.31, 0.25, 0.16, 0.78), 2.0],
		"coast": [Color(0.14, 0.23, 0.23, 0.48), 0.65],
	}
	for key in ["province", "duchy", "kingdom", "owner", "empire", "coast"]:
		var points := PackedVector2Array(border_batches[key])
		if points.size() >= 2:
			var style: Array = border_style[key]
			draw_multiline(points, style[0], float(style[1]) / screen_scale, true)

	if host.selected != "":
		var sel: Dictionary = host.game.province(host.selected)
		if not sel.is_empty():
			for part in host._province_parts(sel):
				draw_colored_polygon(part, Color(1.0, 0.92, 0.62, 0.18))
				var outline: PackedVector2Array = part.duplicate()
				outline.append(part[0])
				draw_polyline(outline, Color(1.0, 0.90, 0.55), 2.0 / screen_scale, true)
	_draw_edge_vignette()

func relief_texture() -> Texture2D:
	return RELIEF

func terrain_texture() -> Texture2D:
	return EUROPE

func relief_overlay() -> TextureRect:
	return _relief_overlay

func _sync_relief_strength() -> void:
	if _relief_material == null or host == null:
		return
	var strength := 0.48 if host.map_mode in ["political", "duchy", "kingdom", "war"] else 0.64
	_relief_material.set_shader_parameter("strength", strength)

func _draw_geography(detailed: bool) -> void:
	var screen_scale: float = maxf(0.1, float(host._fit()[0]))
	for river in host.rivers():
		var line := PackedVector2Array()
		for point in river["points"]:
			line.append(point)
		if line.size() > 1:
			draw_polyline(line, Color(0.20, 0.40, 0.44, 0.68), 1.0 / screen_scale, true)
	if not detailed:
		return
	for p in host.game.provinces:
		var pos: Vector2 = host._label_point(p) + Vector2(0, -10)
		var kind: String = str(p.get("terrain", "plains"))
		var token: Texture2D = host._terrain_tex.get(kind)
		if token != null:
			draw_texture_rect(token, Rect2(pos - Vector2(11, 11), Vector2(22, 22)), false, Color(1, 1, 1, 0.94))
		else:
			_draw_terrain_icon(kind, pos, Color(0.09, 0.07, 0.04, 0.52))

func _draw_edge_vignette() -> void:
	# Papierkante: mehrere sehr transparente Rahmen erzeugen eine weiche
	# Abdunklung, ohne eine zusätzliche Textur zu benötigen.
	for i in 10:
		var inset := float(i)
		var alpha := 0.020 * float(10 - i) / 10.0
		var col := Color(0.025, 0.018, 0.010, alpha)
		draw_rect(Rect2(inset, inset, MAP_SIZE.x - inset * 2.0, 1.0), col, true)
		draw_rect(Rect2(inset, MAP_SIZE.y - inset - 1.0, MAP_SIZE.x - inset * 2.0, 1.0), col, true)
		draw_rect(Rect2(inset, inset, 1.0, MAP_SIZE.y - inset * 2.0), col, true)
		draw_rect(Rect2(MAP_SIZE.x - inset - 1.0, inset, 1.0, MAP_SIZE.y - inset * 2.0), col, true)

func _draw_terrain_icon(kind: String, pos: Vector2, col: Color) -> void:
	match kind:
		"mountains":
			draw_colored_polygon(PackedVector2Array([pos + Vector2(-8, 4), pos + Vector2(-2, -6), pos + Vector2(4, 4)]), col)
			draw_colored_polygon(PackedVector2Array([pos + Vector2(-1, 4), pos + Vector2(5, -3), pos + Vector2(10, 4)]), col)
		"forest":
			for dx in [-6.0, 0.0, 6.0]:
				draw_colored_polygon(PackedVector2Array([pos + Vector2(dx, 4), pos + Vector2(dx - 4, -2), pos + Vector2(dx + 4, -2)]), col)
				draw_line(pos + Vector2(dx, 4), pos + Vector2(dx, 7), col, 1.2)
		"hills":
			draw_arc(pos + Vector2(-4, 3), 5.0, PI, TAU, 8, col, 1.4)
			draw_arc(pos + Vector2(4, 3), 4.0, PI, TAU, 8, col, 1.4)
		"marsh":
			for dx in [-5.0, 0.0, 5.0]:
				draw_line(pos + Vector2(dx, 5), pos + Vector2(dx, -4), col, 1.2)
				draw_line(pos + Vector2(dx, -4), pos + Vector2(dx + 2, -1), col, 1.0)
		"coast":
			for dy in [-3.0, 3.0]:
				draw_arc(pos + Vector2(0, dy), 6.0, 0.15, PI - 0.15, 8, col, 1.2)
		"farmland":
			for dy in [-4.0, 0.0, 4.0]:
				draw_line(pos + Vector2(-7, dy), pos + Vector2(7, dy), col, 1.1)
		"steppe":
			for dx in [-5.0, 0.0, 5.0]:
				draw_line(pos + Vector2(dx, 4), pos + Vector2(dx + 3, -4), col, 1.1)
		"heath":
			for dx in [-5.0, 0.0, 5.0]:
				draw_circle(pos + Vector2(dx, 1), 1.2, col)
		_:
			draw_circle(pos, 1.5, col)
