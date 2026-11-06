extends Control
## Zeichnet den Stammbaum: Herrscher, Gemahl/in, Ehe-Linie und Kinder mit
## Porträts und Nummern der Erbfolge. Reine Darstellung, keine Spiellogik.

const INK := Color(0.16, 0.11, 0.07)
const INK_SOFT := Color(0.34, 0.25, 0.15)
const GOLD := Color(0.55, 0.40, 0.18)
const CREAM := Color(0.98, 0.94, 0.84)
const PAPER := Color(0.92, 0.84, 0.66)

var game = null
var idx: int = -1
var portraits: Array = []
var icons: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(720, 470)
	for i in 12:
		var t = load("res://assets/portraits/portrait_%d.png" % i)
		if t != null:
			portraits.append(t)
	for n in ["heart", "ring"]:
		var t2 = load("res://assets/icons/icon_%s.png" % n)
		if t2 != null:
			icons[n] = t2

func set_house(g, index: int) -> void:
	game = g
	idx = index
	queue_redraw()

func _draw() -> void:
	if game == null or idx < 0 or idx >= game.houses.size():
		return
	var h: Dictionary = game.houses[idx]
	var font := ThemeDB.fallback_font
	var W: float = size.x
	var ruler_w := 104.0
	var ruler_h := 142.0
	var ruler_pos := Vector2(W * 0.30 - ruler_w / 2.0, 10)
	var spouse: Dictionary = h["spouse"]
	var spouse_w := 96.0
	var spouse_h := 132.0
	var spouse_pos := Vector2(W * 0.70 - spouse_w / 2.0, 15)
	var ry: float = ruler_pos.y + ruler_h * 0.46

	if not spouse.is_empty():
		draw_line(Vector2(ruler_pos.x + ruler_w, ry), Vector2(spouse_pos.x, ry), GOLD, 2.0)
		draw_line(Vector2(ruler_pos.x + ruler_w, ry + 4), Vector2(spouse_pos.x, ry + 4), GOLD, 1.0)
		var mid := Vector2((ruler_pos.x + ruler_w + spouse_pos.x) / 2.0, ry - 2)
		if icons.has("heart"):
			draw_texture_rect(icons["heart"], Rect2(mid - Vector2(14, 13), Vector2(28, 26)), false)
		else:
			draw_circle(mid - Vector2(5, 0), 6, GOLD, false, 2.0)
			draw_circle(mid + Vector2(5, 0), 6, GOLD, false, 2.0)

	var kids: Array = game.succession_order(idx)
	var y := 255.0
	var mid_x: float = W / 2.0
	draw_line(Vector2(mid_x, ry + 10), Vector2(mid_x, 215), GOLD, 2.0)
	if kids.is_empty():
		draw_string(font, Vector2(W / 2.0 - 160, 252), "Noch keine Nachkommen", HORIZONTAL_ALIGNMENT_CENTER, 320, 15, INK_SOFT)
	else:
		var n: int = mini(kids.size(), 8)
		var nw := 92.0
		var gap := 8.0
		var total: float = n * nw + (n - 1) * gap
		var start: float = (W - total) / 2.0
		var first_cx: float = start + nw / 2.0
		var last_cx: float = start + (n - 1) * (nw + gap) + nw / 2.0
		draw_line(Vector2(first_cx, 215), Vector2(last_cx, 215), GOLD, 2.0)
		for i in n:
			var x: float = start + i * (nw + gap)
			var cx: float = x + nw / 2.0
			draw_line(Vector2(cx, 215), Vector2(cx, y - 6), GOLD, 2.0)
		for i in n:
			var x2: float = start + i * (nw + gap)
			var child: Dictionary = kids[i]
			_person_node(font, Vector2(x2, y), child, "Erbe" if i == 0 else "Kind", i == 0, nw, 128.0)
			draw_circle(Vector2(x2 + 13, y + 13), 11, Color(0.55, 0.38, 0.14))
			draw_circle(Vector2(x2 + 13, y + 13), 11, Color(0.96, 0.82, 0.46), false, 1.5)
			draw_string(font, Vector2(x2 + 3, y + 17), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, 20, 11, CREAM)
		if kids.size() > n:
			draw_string(font, Vector2(W / 2.0 - 120, y + 150), "+%d weitere" % (kids.size() - n), HORIZONTAL_ALIGNMENT_CENTER, 240, 12, INK_SOFT)

	_person_node(font, ruler_pos, h["ruler"], "Herrscher", true, ruler_w, ruler_h)
	if not spouse.is_empty():
		_person_node(font, spouse_pos, spouse, "Gemahl/in", false, spouse_w, spouse_h)
	else:
		_unmarried(font, spouse_pos, spouse_w, spouse_h)

func _person_node(font, pos: Vector2, p: Dictionary, role: String, highlight: bool, w: float, h: float) -> void:
	var rect := Rect2(pos, Vector2(w, h))
	draw_rect(rect.grow(3), Color(0.15, 0.10, 0.06), true)
	draw_rect(rect, PAPER, true)
	draw_rect(rect, Color(0.62, 0.46, 0.22), false, 2.0)
	if highlight:
		draw_rect(rect.grow(4), Color(0.96, 0.80, 0.36), false, 2.0)
	var pi: int = int(p.get("portrait", 0))
	if pi >= 0 and pi < portraits.size():
		draw_texture_rect(portraits[pi], Rect2(pos + Vector2(4, 4), Vector2(w - 8, h - 40)), false)
	draw_string(font, pos + Vector2(0, h - 20), str(p.get("name", "?")), HORIZONTAL_ALIGNMENT_CENTER, w, 12, INK)
	var sub: String = role
	if p.has("age"):
		sub = "%d · %s" % [int(p["age"]), role]
	draw_string(font, pos + Vector2(0, h - 6), sub, HORIZONTAL_ALIGNMENT_CENTER, w, 10, INK_SOFT)

func _unmarried(font, pos: Vector2, w: float, h: float) -> void:
	var rect := Rect2(pos, Vector2(w, h))
	draw_rect(rect.grow(3), Color(0.15, 0.10, 0.06), true)
	draw_rect(rect, PAPER, true)
	draw_rect(rect, Color(0.62, 0.46, 0.22), false, 2.0)
	var cx: float = pos.x + w / 2.0
	draw_circle(Vector2(cx, pos.y + 38), 18, Color(0.74, 0.68, 0.57))
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 30, pos.y + 96), Vector2(cx - 20, pos.y + 68),
		Vector2(cx + 20, pos.y + 68), Vector2(cx + 30, pos.y + 96),
	]), Color(0.74, 0.68, 0.57))
	draw_string(font, pos + Vector2(0, h - 20), "unvermählt", HORIZONTAL_ALIGNMENT_CENTER, w, 11, INK_SOFT)
	draw_string(font, pos + Vector2(0, h - 6), "keine Ehe", HORIZONTAL_ALIGNMENT_CENTER, w, 9, INK_SOFT)
