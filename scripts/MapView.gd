extends Control
## Zeichnet die hinterlegte Europakarte mit den 49 Provinzflächen. Die echten
## Küstenlinien liegen als vorgenerierte Karte darunter; Grenzen und Beschriftung
## werden aus den Spieldaten gezeichnet.

signal province_selected(province_id: String)

const MAP_SIZE := Vector2(1200, 760)
const EUROPE := preload("res://assets/map/europe_bg.png")
const INK := Color(0.12, 0.09, 0.05)
const CREAM := Color(1.0, 0.96, 0.86)
const GOLD := Color(0.86, 0.68, 0.32)
const LABEL_BG := Color(0.08, 0.06, 0.03, 0.48)

var game = null
var selected: String = ""
var crests: Array = []
var _edge_neighbor: Dictionary = {}
var _game_id: int = -1
var zoom: float = 1.0
var pan := Vector2.ZERO
var _dragging := false
var labels_drawn: int = 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	for i in 9:
		var t = load("res://assets/crests/crest_%d.png" % i)
		if t != null:
			crests.append(t)

func set_game(g) -> void:
	game = g
	if game != null and game.get_instance_id() != _game_id:
		_game_id = game.get_instance_id()
		_rebuild_edge_cache()
	queue_redraw()

func select(id: String) -> void:
	selected = id
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
	zoom = clampf(zoom * factor, 1.0, 4.0)
	var fit_s: float = min(size.x / MAP_SIZE.x, size.y / MAP_SIZE.y)
	var s: float = fit_s * zoom
	var base: Vector2 = (size - MAP_SIZE * s) * 0.5
	pan = p - before * s - base
	_clamp_pan()
	queue_redraw()

func reset_view() -> void:
	zoom = 1.0
	pan = Vector2.ZERO
	queue_redraw()

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

func _pick_at(pos: Vector2) -> void:
	if game == null:
		return
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
		selected = str(candidates[0][1])
		province_selected.emit(selected)
		queue_redraw()

func _draw() -> void:
	var fit := _fit()
	var s: float = fit[0]
	var off: Vector2 = fit[1]
	draw_set_transform(off, 0.0, Vector2(s, s))
	draw_texture_rect(EUROPE, Rect2(Vector2.ZERO, MAP_SIZE), false)
	# Kompass und Schiff als Kartenmöbel
	draw_arc(Vector2(1116, 96), 38, 0, TAU, 32, Color(0.76, 0.65, 0.44, 0.55), 1.5)
	for k in 8:
		var a: float = k * TAU / 8.0
		draw_line(Vector2(1116, 96) + Vector2(cos(a), sin(a)) * 25, Vector2(1116, 96) + Vector2(cos(a), sin(a)) * 52, Color(0.76, 0.65, 0.44, 0.5), 1.0)
	draw_line(Vector2(1116, 44), Vector2(1116, 62), Color(0.88, 0.75, 0.48, 0.8), 2.0)
	var hull := PackedVector2Array([Vector2(74, 700), Vector2(142, 700), Vector2(130, 722), Vector2(86, 722)])
	draw_colored_polygon(hull, Color(0.42, 0.28, 0.14, 0.9))
	draw_line(Vector2(108, 700), Vector2(108, 668), Color(0.55, 0.40, 0.20, 0.9), 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(110, 670), Vector2(140, 692), Vector2(110, 696)]), Color(0.84, 0.76, 0.57, 0.9))

	if game == null:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_rect(Rect2(off, MAP_SIZE * s), Color(0.72, 0.58, 0.34, 0.5), false, 3.0)
		return

	# Provinzflächen: halbtransparent, damit die echte Europakarte darunter sichtbar bleibt.
	for p in game.provinces:
		var base: Color = game.houses[int(p["owner"])]["color"]
		if selected == p["id"]:
			base = base.lightened(0.25)
		base.a = 0.68
		for part in _province_parts(p):
			draw_colored_polygon(part, base)

	# Grenzen: Provinz < Herzogtum < Königreich < Reich < Küste
	for p in game.provinces:
		var parts: Array = _province_parts(p)
		for pi in parts.size():
			var pts: PackedVector2Array = parts[pi]
			for i in pts.size():
				var a: Vector2 = pts[i]
				var b: Vector2 = pts[(i + 1) % pts.size()]
				var nid: String = str(_edge_neighbor.get("%s|%d|%d" % [p["id"], pi, i], ""))
				var q: Dictionary = game.province(nid) if nid != "" else {}
				var col := Color(0.16, 0.11, 0.07, 0.55)
				var width := 1.0
				if q.is_empty():
					col = Color(0.12, 0.09, 0.05, 0.95)
					width = 2.4
				elif str(p["empire"]) != str(q["empire"]):
					col = Color(0.64, 0.18, 0.13, 0.95)
					width = 5.0
				elif int(p["owner"]) != int(q["owner"]):
					col = Color(0.98, 0.84, 0.45, 0.95)
					width = 4.0
				elif str(p["kingdom"]) != str(q["kingdom"]):
					col = Color(0.72, 0.52, 0.22, 0.95)
					width = 3.2
				elif str(p["duchy"]) != str(q["duchy"]):
					col = Color(0.43, 0.30, 0.14, 0.9)
					width = 2.1
				draw_line(a, b, col, width, true)

	# Auswahl
	if selected != "":
		var sel: Dictionary = game.province(selected)
		if not sel.is_empty():
			for part in _province_parts(sel):
				draw_colored_polygon(part, Color(1.0, 0.92, 0.62, 0.18))
				var outline: PackedVector2Array = part.duplicate()
				outline.append(part[0])
				draw_polyline(outline, Color(1.0, 0.90, 0.55), 3.2, true)

	_draw_labels(s, off)

func _draw_labels(s: float, off: Vector2) -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var font := ThemeDB.fallback_font
	var map_rect := Rect2(off, MAP_SIZE * s)
	var inner := map_rect.grow(-3)
	var occupied: Array = []
	var fs_title := 16 if s < 0.9 else 18
	var fs_owner := 10 if s < 0.9 else 11
	var fs_label := 9 if s >= 1.1 else (8 if s >= 0.62 else 7)

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
			box.position.x = clampf(box.position.x, inner.position.x + 2, inner.end.x - w - 2)
			box.position.y = clampf(box.position.y, inner.position.y + 2, inner.end.y - h - 2)
		occupied.append(box)
		draw_rect(box, Color(0.07, 0.05, 0.03, 0.83), true)
		draw_rect(box, Color(0.86, 0.68, 0.32, 0.92), false, 1.2)
		var tx := box.position.x + (w - tw) * 0.5
		var ty := box.position.y + float(fs_title) + 1.0
		draw_string(font, Vector2(tx, ty), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_title, CREAM)
		var ox := box.position.x + (w - ow) * 0.5
		draw_string(font, Vector2(ox, ty + float(fs_owner) + 2.0), house_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_owner, Color(0.96, 0.86, 0.62))

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

	var drawn := 0
	for p in game.provinces:
		var name := str(p["name"])
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
		draw_rect(box, LABEL_BG, true)
		var txt := Vector2(box.position.x + 2, box.position.y + float(fs_label) + 1)
		draw_string(font, txt + Vector2(1, 1), name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_label, Color(0, 0, 0, 0.75))
		draw_string(font, txt, name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_label,
			Color(1.0, 0.86, 0.48) if str(p["id"]) == selected else Color(1.0, 0.97, 0.88))
		drawn += 1
	labels_drawn = drawn

	# Auswahlkarte mit Land, Provinz, Hauptstadtstatus und Besitzer
	if selected != "":
		var p: Dictionary = game.province(selected)
		if not p.is_empty():
			var owner: String = str(game.houses[int(p["owner"])]["name"])
			var cap := "ja" if bool(p.get("capital", false)) else "nein"
			var lines := [
				str(p["name"]),
				str(p["kingdom_name"]),
				str(p["duchy_name"]),
				"Hauptstadt: %s · Besitzer: %s" % [cap, owner],
			]
			var box_w := 250.0
			var box_h := 62.0
			var anchor: Vector2 = _label_point(p) * s + off
			var box := Rect2(anchor + Vector2(-box_w * 0.5, 14), Vector2(box_w, box_h))
			box.position.x = clampf(box.position.x, map_rect.position.x + 4, map_rect.end.x - box_w - 4)
			box.position.y = clampf(box.position.y, map_rect.position.y + 4, map_rect.end.y - box_h - 4)
			draw_rect(box, Color(0.08, 0.06, 0.03, 0.94), true)
			draw_rect(box, GOLD, false, 1.5)
			draw_string(font, box.position + Vector2(8, 19), lines[0], HORIZONTAL_ALIGNMENT_LEFT, box_w - 16, 14, CREAM)
			draw_string(font, box.position + Vector2(8, 33), lines[1], HORIZONTAL_ALIGNMENT_LEFT, box_w - 16, 9, Color(0.96, 0.86, 0.64))
			draw_string(font, box.position + Vector2(8, 45), lines[2], HORIZONTAL_ALIGNMENT_LEFT, box_w - 16, 9, Color(0.84, 0.76, 0.58))
			draw_string(font, box.position + Vector2(8, 57), lines[3], HORIZONTAL_ALIGNMENT_LEFT, box_w - 16, 9, Color(0.98, 0.82, 0.42))

	draw_rect(map_rect, Color(0.72, 0.58, 0.34, 0.5), false, 3.0)

func _gui_input(event: InputEvent) -> void:
	if game == null:
		return
	if event is InputEventMouseButton:
		if event.pressed and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			zoom_by(1.18 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.85, event.position)
			accept_event()
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
			if event.pressed:
				_pick_at(event.position)
				accept_event()
		return
	if event is InputEventMouseMotion and _dragging:
		pan += event.relative
		_clamp_pan()
		queue_redraw()
		accept_event()
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
		queue_redraw()
		accept_event()
