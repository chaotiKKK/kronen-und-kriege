extends Control
## Live-Vorschau und Exportfläche des Wappen-Generators.

var design: Dictionary = {}
var _symbols: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 12:
		var t = load("res://assets/banners/symbols/symbol_%02d.png" % i)
		if t != null:
			_symbols.append(t)
		else:
			_symbols.append(null)

func set_design(d: Dictionary) -> void:
	design = d.duplicate(true)
	queue_redraw()

func _col(key: String, fallback: String) -> Color:
	var v = design.get(key, fallback)
	if v is Color:
		return v
	if v is String:
		return Color(v)
	return Color(fallback)

func _shape_points(shape: int, r: Rect2) -> PackedVector2Array:
	var n: Array = []
	match shape:
		0: n = [[.10, .055], [.90, .055], [.885, .54], [.73, .77], [.50, .945], [.27, .77], [.115, .54]]
		1: n = [[.10, .06], [.30, .035], [.70, .035], [.90, .06], [.90, .48], [.76, .72], [.50, .93], [.24, .72], [.10, .48]]
		2: n = [[.09, .06], [.91, .06], [.93, .42], [.82, .68], [.50, .95], [.18, .68], [.07, .42]]
		3: n = [[.05, .15], [.95, .15], [.95, .70], [.05, .70]]
		4: n = [[.05, .15], [.95, .15], [.78, .425], [.95, .70], [.05, .70]]
		_: n = [[.29, .055], [.71, .055], [.71, .80], [.50, .945], [.29, .80]]
	var out := PackedVector2Array()
	for p in n:
		out.append(r.position + Vector2(float(p[0]), float(p[1])) * r.size)
	return out

func _close(poly: PackedVector2Array) -> PackedVector2Array:
	var out := poly.duplicate()
	if out.size() > 0:
		out.append(out[0])
	return out

func _fill_shape(shape: PackedVector2Array, poly: Array, color: Color) -> void:
	var pieces: Array = Geometry2D.intersect_polygons(shape, PackedVector2Array(poly))
	for piece in pieces:
		if piece.size() >= 3:
			draw_colored_polygon(piece, color)

func _rect(x0: float, y0: float, x1: float, y1: float, r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([
		r.position + Vector2(x0, y0) * r.size,
		r.position + Vector2(x1, y0) * r.size,
		r.position + Vector2(x1, y1) * r.size,
		r.position + Vector2(x0, y1) * r.size,
	])

func _draw_pattern(shape: PackedVector2Array, r: Rect2, pattern: int, col: Color) -> void:
	if pattern <= 0:
		return
	var c := Color(col.r, col.g, col.b, 0.16)
	if pattern == 1:
		for i in 14:
			var x := -0.3 + float(i) * 0.12
			var strip := PackedVector2Array([
				r.position + Vector2(x, 0.0) * r.size,
				r.position + Vector2(x + 0.018, 0.0) * r.size,
				r.position + Vector2(x + 0.33, 1.0) * r.size,
				r.position + Vector2(x + 0.312, 1.0) * r.size,
			])
			_fill_shape(shape, strip, c)
	elif pattern == 2:
		for i in 9:
			var x := float(i) / 9.0
			var strip := _rect(x, 0.0, minf(1.0, x + 0.035), 1.0, r)
			_fill_shape(shape, strip, Color(col.r, col.g, col.b, 0.09 if i % 2 == 0 else 0.035))
	elif pattern == 3:
		for yy in 8:
			for xx in 8:
				var p := r.position + Vector2((float(xx) + (0.5 if yy % 2 == 0 else 0.0)) / 8.0,
					(float(yy) + 0.35) / 8.0) * r.size
				var s := maxf(1.5, r.size.x * 0.012)
				draw_circle(p, s, c)
				draw_circle(p + Vector2(s * 1.8, 0), s * 0.65, c)

func _draw_symbol(r: Rect2) -> void:
	var idx := int(design.get("symbol", 0))
	if idx <= 0 or idx > _symbols.size():
		return
	var tex = _symbols[idx - 1]
	if tex == null:
		return
	var scale := clampf(float(design.get("symbol_scale", 1.0)), 0.45, 1.65)
	var off = design.get("symbol_offset", [0.0, 0.0])
	var offset := Vector2(float(off[0]), float(off[1])) if off is Array and off.size() >= 2 else Vector2.ZERO
	var side: float = r.size.x * 0.40 * scale
	var center: Vector2 = r.position + Vector2(0.5, 0.46) * r.size + offset * r.size
	var box := Rect2(center - Vector2(side, side) * 0.5, Vector2(side, side))
	var col := _col("symbol_color", "#f4e5bd")
	draw_texture_rect(tex, Rect2(box.position + Vector2(3, 4), box.size), false, Color(0, 0, 0, 0.34))
	draw_texture_rect(tex, box, false, col)

func _draw_text(r: Rect2) -> void:
	var text := str(design.get("text", "")).strip_edges()
	if text == "" or not bool(design.get("show_text", true)):
		return
	var font := ThemeDB.fallback_font
	var fs: int = maxi(9, int(float(design.get("text_size", 26)) * r.size.x / 512.0))
	var col := _col("text_color", "#f6e5b4")
	var y: float = r.position.y + r.size.y * 0.855
	if not bool(design.get("text_curved", false)):
		var tw: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pos := Vector2(r.position.x + (r.size.x - tw) * 0.5, y)
		draw_string(font, pos + Vector2(1, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.55))
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		return
	var widths: Array = []
	var total := 0.0
	for i in text.length():
		var cw: float = font.get_string_size(text.substr(i, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		widths.append(cw)
		total += cw
	var radius := r.size.x * 0.33
	var span := clampf(total / radius, 0.35, 1.6)
	var angle := -PI * 0.5 - span * 0.5
	var center := Vector2(r.position.x + r.size.x * 0.5, y + radius * 0.58)
	for i in text.length():
		var cw: float = float(widths[i])
		var step := cw / radius
		var mid := angle + step * 0.5
		var p := center + Vector2(cos(mid), sin(mid)) * radius
		draw_set_transform(p, mid + PI * 0.5, Vector2.ONE)
		draw_char(font, Vector2(-cw * 0.5, 0), text.substr(i, 1), fs, col)
		angle += step
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw() -> void:
	if size.x < 4 or size.y < 4:
		return
	var s: float = minf(size.x, size.y)
	var r := Rect2((size - Vector2(s, s)) * 0.5, Vector2(s, s))
	var shape := _shape_points(int(design.get("shape", 0)), r)
	if shape.size() < 3:
		return
	var primary := _col("primary", "#8f3b32")
	var secondary := _col("secondary", "#e6dcc4")
	var accent := _col("accent", "#d4a94f")
	# Schatten
	var shadow := shape.duplicate()
	for i in shadow.size():
		shadow[i] += Vector2(0.018, 0.025) * s
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.30))
	draw_colored_polygon(shape, primary)
	if bool(design.get("show_division", true)):
		match int(design.get("division", 0)):
			1:
				_fill_shape(shape, _rect(0.5, 0.0, 1.0, 1.0, r), secondary)
			2:
				_fill_shape(shape, _rect(0.0, 0.5, 1.0, 1.0, r), secondary)
			3:
				_fill_shape(shape, _rect(0.5, 0.0, 1.0, 0.5, r), secondary)
				_fill_shape(shape, _rect(0.0, 0.5, 0.5, 1.0, r), secondary)
			4:
				_fill_shape(shape, PackedVector2Array([
					r.position + Vector2(0, 0.0) * r.size, r.position + Vector2(1, 1) * r.size,
					r.position + Vector2(0, 1) * r.size]), secondary)
			5:
				_fill_shape(shape, PackedVector2Array([
					r.position + Vector2(0.08, 0.36) * r.size, r.position + Vector2(0.50, 0.66) * r.size,
					r.position + Vector2(0.92, 0.36) * r.size, r.position + Vector2(0.92, 0.50) * r.size,
					r.position + Vector2(0.50, 0.80) * r.size, r.position + Vector2(0.08, 0.50) * r.size]), secondary)
			6:
				_fill_shape(shape, _rect(0.42, 0.0, 0.58, 1.0, r), secondary)
				_fill_shape(shape, _rect(0.0, 0.42, 1.0, 0.58, r), secondary)
			7:
				_fill_shape(shape, _rect(0.0, 0.0, 1.0, 1.0, r), secondary)
				_fill_shape(shape, _rect_with_inset(r, 0.12), primary)
	_draw_pattern(shape, r, int(design.get("pattern", 0)), secondary.lightened(0.3))
	if bool(design.get("show_symbol", true)):
		_draw_symbol(r)
	if bool(design.get("show_text", true)):
		_draw_text(r)
	var b := int(design.get("border", 2))
	if b > 0:
		var outer := _close(shape)
		var bw := 2.0 if b == 1 else maxf(3.0, s * 0.009)
		var bc := accent if b >= 2 else Color(0.16, 0.10, 0.06)
		draw_polyline(outer, bc, bw, true)
		if b == 3 or b == 4:
			var inner := _inset_shape(shape, 0.90)
			draw_polyline(_close(inner), bc.darkened(0.25), maxf(1.5, bw * 0.55), true)
		if b == 4:
			for i in range(0, shape.size(), 2):
				draw_circle(shape[i], maxf(1.7, s * 0.006), accent.lightened(0.28))

func _rect_with_inset(r: Rect2, inset: float) -> PackedVector2Array:
	return PackedVector2Array([
		r.position + Vector2(inset, inset) * r.size,
		r.position + Vector2(1 - inset, inset) * r.size,
		r.position + Vector2(1 - inset, 1 - inset) * r.size,
		r.position + Vector2(inset, 1 - inset) * r.size,
	])

func _inset_shape(shape: PackedVector2Array, factor: float) -> PackedVector2Array:
	var c := Vector2.ZERO
	for p in shape:
		c += p
	c /= float(shape.size())
	var out := PackedVector2Array()
	for p in shape:
		out.append(c + (p - c) * factor)
	return out
