extends Control
## Banner- & Fahnen- & Wappen-Generator. Das Fenster folgt der Vorlage:
## links Vorlagen/Designs/Epochen, Mitte Live-Vorschau, rechts Farben, Symbole,
## Text und Rahmen, unten Werkzeuge und Export.

signal applied(design: Dictionary)
signal closed

const PreviewScript = preload("res://scripts/BannerPreview.gd")
const TEMPLATE_NAMES := ["Klassisch", "Rund", "Iberisch", "Fahne", "Stander", "Banner"]
const PRESET_NAMES := ["König", "Nordmeer", "Oriental", "Hain", "Adler", "Krieg"]
const ERA_NAMES := ["Bronze", "Antike", "Mittelalter", "Nordisch"]
const PALETTE := [
	"#7d2f2f", "#263b60", "#2f5a3b", "#c49a3a", "#28706b", "#5a3b70",
	"#ece3cd", "#34363a", "#a94438", "#6d8fb3", "#7a5233", "#f1eee3",
]
const LAYERS := ["Feld", "Teilung", "Symbol", "Rahmen", "Text"]
const LAYER_KEYS := ["primary", "secondary", "symbol_color", "accent", "text_color"]

var design: Dictionary = {}
var preview
var status_label: Label
var text_edit: LineEdit
var text_size: HSlider
var curve_check: CheckBox
var division_option: OptionButton
var layer_buttons: Dictionary = {}
var shape_buttons: Array = []
var preset_buttons: Array = []
var pattern_buttons: Array = []
var symbol_buttons: Array = []
var border_buttons: Array = []
var check_division: CheckBox
var check_symbol: CheckBox
var check_text: CheckBox
var history_box: HBoxContainer
var color_target: String = "primary"
var _built := false
var _house_name := ""
var _card: PanelContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()

func _flat(bg: Color, border := Color(0, 0, 0, 0), width := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	if width > 0:
		sb.border_width_left = width
		sb.border_width_right = width
		sb.border_width_top = width
		sb.border_width_bottom = width
		sb.border_color = border
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	return sb

func _label(text: String, size: int, col := Color(0.86, 0.84, 0.78)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l

func _button(text: String, cb: Callable, min_size := Vector2(0, 33)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", 11)
	b.add_theme_color_override("font_color", Color(0.88, 0.86, 0.80))
	b.add_theme_color_override("font_hover_color", Color(1, 0.94, 0.79))
	b.add_theme_color_override("font_pressed_color", Color(0.76, 0.61, 0.35))
	b.add_theme_stylebox_override("normal", _flat(Color(0.16, 0.16, 0.18), Color(0.33, 0.31, 0.29), 1))
	b.add_theme_stylebox_override("hover", _flat(Color(0.24, 0.21, 0.19), Color(0.64, 0.48, 0.24), 1))
	b.add_theme_stylebox_override("pressed", _flat(Color(0.31, 0.19, 0.17), Color(0.78, 0.55, 0.28), 1))
	b.add_theme_stylebox_override("focus", _flat(Color(0.24, 0.21, 0.19), Color(0.64, 0.48, 0.24), 1))
	b.pressed.connect(cb)
	return b

func _section(title: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	var head := PanelContainer.new()
	head.add_theme_stylebox_override("panel", _flat(Color(0.29, 0.12, 0.12), Color(0.50, 0.21, 0.18), 1))
	var h := _label(title, 11, Color(0.93, 0.84, 0.66))
	head.add_child(h)
	v.add_child(head)
	return v

func _build() -> void:
	if _built:
		return
	_built = true
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.02, 0.025, 0.90)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_card = PanelContainer.new()
	_card.custom_minimum_size = Vector2(1220, 0)
	_card.add_theme_stylebox_override("panel", _flat(Color(0.105, 0.105, 0.115), Color(0.46, 0.35, 0.21), 2))
	center.add_child(_card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	_card.add_child(box)

	# Kopf
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	box.add_child(head)
	var title := _label("BANNER & FAHNEN & WAPPEN", 24, Color(0.92, 0.83, 0.63))
	head.add_child(title)
	head.add_child(_label("GENERATOR", 12, Color(0.65, 0.61, 0.54)))
	head.add_child(_spacer())
	var close := _button("Schließen", _close, Vector2(92, 32))
	head.add_child(close)
	box.add_child(HSeparator.new())

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 7)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(body)
	_build_left(body)
	_build_center(body)
	_build_right(body)
	_build_footer(box)

func _spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c

func _build_left(parent: HBoxContainer) -> void:
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(236, 0)
	left.add_theme_constant_override("separation", 5)
	parent.add_child(left)

	var sec := _section("VORLAGEN")
	left.add_child(sec)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	sec.add_child(grid)
	for i in 6:
		var b := _button(TEMPLATE_NAMES[i], Callable(self, "_set_shape").bind(i), Vector2(110, 58))
		b.icon = load("res://assets/banners/templates/template_%d.png" % i)
		b.add_theme_constant_override("icon_max_width", 38)
		b.tooltip_text = "Vorlage " + TEMPLATE_NAMES[i]
		grid.add_child(b)
		shape_buttons.append(b)

	var secp := _section("VORBEREITETE DESIGNS")
	left.add_child(secp)
	var pg := GridContainer.new()
	pg.columns = 2
	pg.add_theme_constant_override("h_separation", 4)
	pg.add_theme_constant_override("v_separation", 4)
	secp.add_child(pg)
	for i in 6:
		var b := _button(PRESET_NAMES[i], Callable(self, "_apply_preset").bind(i), Vector2(110, 47))
		b.icon = load("res://assets/banners/presets/preset_%d.png" % i)
		b.add_theme_constant_override("icon_max_width", 30)
		pg.add_child(b)
		preset_buttons.append(b)

	var sece := _section("EPOCHEN-STILE")
	left.add_child(sece)
	var eg := GridContainer.new()
	eg.columns = 2
	eg.add_theme_constant_override("h_separation", 4)
	eg.add_theme_constant_override("v_separation", 3)
	sece.add_child(eg)
	for i in 4:
		var b := _button(ERA_NAMES[i], Callable(self, "_apply_era").bind(i), Vector2(110, 28))
		eg.add_child(b)

func _build_center(parent: HBoxContainer) -> void:
	var center := VBoxContainer.new()
	center.custom_minimum_size = Vector2(470, 0)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 5)
	parent.add_child(center)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	center.add_child(tabs)
	for i in 3:
		var names := ["BANNER", "FAHNEN", "WAPPEN"]
		var b := _button(names[i], Callable(self, "_set_tab").bind(i), Vector2(0, 29))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(b)
	var frame := PanelContainer.new()
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.custom_minimum_size = Vector2(430, 464)
	frame.add_theme_stylebox_override("panel", _flat(Color(0.91, 0.88, 0.79), Color(0.54, 0.40, 0.23), 2))
	center.add_child(frame)
	preview = PreviewScript.new()
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_child(preview)
	status_label = _label("Wähle eine Vorlage und gestalte dein Wappen.", 10, Color(0.64, 0.61, 0.55))
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	center.add_child(status_label)

func _build_right(parent: HBoxContainer) -> void:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(298, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(286, 0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 5)
	scroll.add_child(right)

	var sec := _section("FARBEN & TEXTUREN")
	right.add_child(sec)
	var layers := HBoxContainer.new()
	layers.add_theme_constant_override("separation", 2)
	sec.add_child(layers)
	for i in 5:
		var b := _button(LAYERS[i], Callable(self, "_set_color_target").bind(LAYER_KEYS[i]), Vector2(49, 25))
		b.add_theme_font_size_override("font_size", 9)
		layers.add_child(b)
		layer_buttons[LAYER_KEYS[i]] = b
	var pal := GridContainer.new()
	pal.columns = 6
	pal.add_theme_constant_override("h_separation", 4)
	pal.add_theme_constant_override("v_separation", 4)
	sec.add_child(pal)
	for hex in PALETTE:
		var b := Button.new()
		b.custom_minimum_size = Vector2(41, 25)
		b.tooltip_text = hex
		var c := Color(hex)
		b.add_theme_stylebox_override("normal", _flat(c, Color(0.80, 0.72, 0.53), 1))
		b.add_theme_stylebox_override("hover", _flat(c.lightened(0.15), Color(1, 0.89, 0.58), 2))
		b.add_theme_stylebox_override("pressed", _flat(c.darkened(0.12), Color(1, 0.82, 0.38), 2))
		b.pressed.connect(Callable(self, "_pick_color").bind(hex))
		pal.add_child(b)
	var plabel := _label("Textur", 10, Color(0.65, 0.62, 0.56))
	sec.add_child(plabel)
	var pats := HBoxContainer.new()
	pats.add_theme_constant_override("separation", 3)
	sec.add_child(pats)
	var pnames := ["Glatt", "Leinen", "Metall", "Pelz"]
	for i in 4:
		var b := _button(pnames[i], Callable(self, "_set_pattern").bind(i), Vector2(0, 26))
		b.add_theme_font_size_override("font_size", 9)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pats.add_child(b)
		pattern_buttons.append(b)

	var secs := _section("SYMBOLE")
	right.add_child(secs)
	var sg := GridContainer.new()
	sg.columns = 5
	sg.add_theme_constant_override("h_separation", 4)
	sg.add_theme_constant_override("v_separation", 4)
	secs.add_child(sg)
	for i in 13:
		var b := Button.new()
		b.custom_minimum_size = Vector2(49, 38)
		b.tooltip_text = "Kein Symbol" if i == 0 else "Symbol %d" % i
		if i > 0:
			b.icon = load("res://assets/banners/symbols/symbol_%02d.png" % (i - 1))
			b.add_theme_constant_override("icon_max_width", 29)
		else:
			b.text = "—"
		b.add_theme_stylebox_override("normal", _flat(Color(0.16, 0.16, 0.18), Color(0.33, 0.31, 0.29), 1))
		b.add_theme_stylebox_override("hover", _flat(Color(0.26, 0.21, 0.17), Color(0.75, 0.55, 0.27), 1))
		b.add_theme_stylebox_override("pressed", _flat(Color(0.34, 0.19, 0.16), Color(0.95, 0.68, 0.30), 1))
		b.pressed.connect(Callable(self, "_set_symbol").bind(i))
		sg.add_child(b)
		symbol_buttons.append(b)

	var sect := _section("TEXT")
	right.add_child(sect)
	text_edit = LineEdit.new()
	text_edit.placeholder_text = "Wahlspruch ..."
	text_edit.add_theme_stylebox_override("normal", _flat(Color(0.92, 0.89, 0.81), Color(0.43, 0.34, 0.21), 1))
	text_edit.add_theme_color_override("font_color", Color(0.13, 0.10, 0.07))
	text_edit.add_theme_font_size_override("font_size", 12)
	text_edit.text_changed.connect(_text_changed)
	sect.add_child(text_edit)
	var tr := HBoxContainer.new()
	tr.add_theme_constant_override("separation", 5)
	sect.add_child(tr)
	tr.add_child(_label("Größe", 10, Color(0.66, 0.63, 0.57)))
	text_size = HSlider.new()
	text_size.min_value = 12
	text_size.max_value = 58
	text_size.step = 1
	text_size.value = 26
	text_size.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_size.value_changed.connect(_text_size_changed)
	tr.add_child(text_size)
	curve_check = CheckBox.new()
	curve_check.text = "Gebogen"
	curve_check.add_theme_font_size_override("font_size", 10)
	curve_check.add_theme_color_override("font_color", Color(0.82, 0.79, 0.70))
	curve_check.toggled.connect(_curve_toggled)
	sect.add_child(curve_check)

	var secb := _section("GRENZEN & EFFEKTE")
	right.add_child(secb)
	var bg := GridContainer.new()
	bg.columns = 3
	bg.add_theme_constant_override("h_separation", 3)
	bg.add_theme_constant_override("v_separation", 3)
	secb.add_child(bg)
	var bnames := ["Kein", "Dünn", "Gold", "Doppelt", "Punkte"]
	for i in 5:
		var b := _button(bnames[i], Callable(self, "_set_border").bind(i), Vector2(89, 26))
		b.add_theme_font_size_override("font_size", 9)
		bg.add_child(b)
		border_buttons.append(b)

func _build_footer(parent: VBoxContainer) -> void:
	parent.add_child(HSeparator.new())
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 5)
	parent.add_child(foot)
	var tl := _label("WERKZEUGE", 10, Color(0.74, 0.63, 0.43))
	foot.add_child(tl)
	check_division = CheckBox.new()
	check_division.text = "Teilung"
	check_division.button_pressed = true
	check_division.add_theme_font_size_override("font_size", 10)
	check_division.add_theme_color_override("font_color", Color(0.82, 0.80, 0.73))
	check_division.toggled.connect(_toggle_changed)
	foot.add_child(check_division)
	check_symbol = CheckBox.new()
	check_symbol.text = "Symbol"
	check_symbol.button_pressed = true
	check_symbol.add_theme_font_size_override("font_size", 10)
	check_symbol.add_theme_color_override("font_color", Color(0.82, 0.80, 0.73))
	check_symbol.toggled.connect(_toggle_changed)
	foot.add_child(check_symbol)
	check_text = CheckBox.new()
	check_text.text = "Text"
	check_text.button_pressed = true
	check_text.add_theme_font_size_override("font_size", 10)
	check_text.add_theme_color_override("font_color", Color(0.82, 0.80, 0.73))
	check_text.toggled.connect(_toggle_changed)
	foot.add_child(check_text)
	foot.add_child(_label("Symbol", 10, Color(0.62, 0.59, 0.53)))
	for key in ["◀", "▶", "▲", "▼", "−", "+"]:
		var b := _button(key, Callable(self, "_transform_symbol").bind(key), Vector2(27, 27))
		b.add_theme_font_size_override("font_size", 10)
		foot.add_child(b)
	var hist_label := _label("Farben", 10, Color(0.62, 0.59, 0.53))
	foot.add_child(hist_label)
	history_box = HBoxContainer.new()
	history_box.add_theme_constant_override("separation", 2)
	foot.add_child(history_box)
	foot.add_child(_spacer())
	var exp := _button("Export PNG", _export, Vector2(100, 32))
	foot.add_child(exp)
	var apply := _button("Übernehmen", _apply, Vector2(110, 32))
	apply.add_theme_color_override("font_color", Color(1.0, 0.91, 0.71))
	apply.add_theme_stylebox_override("normal", _flat(Color(0.35, 0.18, 0.16), Color(0.87, 0.65, 0.32), 1))
	foot.add_child(apply)

func _default_design(house: Dictionary) -> Dictionary:
	var c: Color = house.get("color", Color(0.55, 0.25, 0.18))
	return {
		"shape": 0, "division": 0, "pattern": 0, "border": 2,
		"primary": "#" + c.to_html(false), "secondary": "#e6dcc4",
		"accent": "#d4a94f", "symbol_color": "#f4e5bd", "text_color": "#f6e5b4",
		"symbol": 3, "symbol_scale": 1.0, "symbol_offset": [0.0, 0.0],
		"text": "", "text_size": 26, "text_curved": false,
		"show_division": true, "show_symbol": true, "show_text": true,
	}

func open(house: Dictionary) -> void:
	visible = true
	_house_name = str(house.get("name", ""))
	var d = house.get("banner", {})
	if d is Dictionary and not (d as Dictionary).is_empty():
		design = (d as Dictionary).duplicate(true)
	else:
		design = _default_design(house)
	status_label.text = "%s · Entwirf das Hauswappen." % _house_name
	_refresh()

func _close() -> void:
	visible = false
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()

func _set_tab(i: int) -> void:
	design["shape"] = [5, 3, 0][i]
	_refresh()

func _set_shape(i: int) -> void:
	design["shape"] = i
	_refresh()

func _set_color_target(key: String) -> void:
	color_target = key
	_refresh()

func _pick_color(hex: String) -> void:
	design[color_target] = hex
	if history_box != null:
		for c in history_box.get_children():
			if str(c.get_meta("hex", "")) == hex:
				return
		if history_box.get_child_count() >= 5:
			var old := history_box.get_child(0)
			history_box.remove_child(old)
			old.queue_free()
		var sw := ColorRect.new()
		sw.custom_minimum_size = Vector2(16, 16)
		sw.color = Color(hex)
		sw.set_meta("hex", hex)
		history_box.add_child(sw)
	_refresh()

func _set_pattern(i: int) -> void:
	design["pattern"] = i
	_refresh()

func _set_symbol(i: int) -> void:
	design["symbol"] = i
	_refresh()

func _set_border(i: int) -> void:
	design["border"] = i
	_refresh()

func _text_changed(value: String) -> void:
	design["text"] = value
	_refresh()

func _text_size_changed(value: float) -> void:
	design["text_size"] = int(value)
	_refresh()

func _curve_toggled(value: bool) -> void:
	design["text_curved"] = value
	_refresh()

func _toggle_changed(_value: bool) -> void:
	design["show_division"] = check_division.button_pressed
	design["show_symbol"] = check_symbol.button_pressed
	design["show_text"] = check_text.button_pressed
	_refresh()

func _transform_symbol(key: String) -> void:
	var off = design.get("symbol_offset", [0.0, 0.0])
	var v := Vector2(float(off[0]), float(off[1])) if off is Array and off.size() >= 2 else Vector2.ZERO
	if key == "◀": v.x -= 0.03
	elif key == "▶": v.x += 0.03
	elif key == "▲": v.y -= 0.03
	elif key == "▼": v.y += 0.03
	elif key == "−": design["symbol_scale"] = clampf(float(design.get("symbol_scale", 1.0)) - 0.1, 0.45, 1.65)
	elif key == "+": design["symbol_scale"] = clampf(float(design.get("symbol_scale", 1.0)) + 0.1, 0.45, 1.65)
	design["symbol_offset"] = [v.x, v.y]
	_refresh()

func _apply_preset(i: int) -> void:
	var base := _default_design({"color": Color(PALETTE[i % 6])})
	var presets := [
		{"shape": 0, "division": 1, "primary": "#8e302e", "secondary": "#e7dcc2", "symbol": 10, "accent": "#d4a94f"},
		{"shape": 2, "division": 2, "primary": "#263b60", "secondary": "#d9e0df", "symbol": 8, "accent": "#c8b06a"},
		{"shape": 1, "division": 3, "primary": "#5a3b70", "secondary": "#e5d7b9", "symbol": 5, "accent": "#e0b556"},
		{"shape": 3, "division": 1, "primary": "#2f5a3b", "secondary": "#e3dcc6", "symbol": 6, "accent": "#d6b665"},
		{"shape": 4, "division": 2, "primary": "#28706b", "secondary": "#e5ddc9", "symbol": 11, "accent": "#d8b55b"},
		{"shape": 5, "division": 4, "primary": "#a94438", "secondary": "#e6d8bb", "symbol": 7, "accent": "#e4bd62"},
	]
	var p: Dictionary = presets[i]
	for k in p.keys():
		base[k] = p[k]
	design = base
	_refresh()

func _apply_era(i: int) -> void:
	var eras := [
		[0, "#7d2f2f", "#d8c59e", "#c49a3a", 1],
		[2, "#263b60", "#e9e0c9", "#c7a24b", 0],
		[1, "#2f5a3b", "#e8dcc2", "#d1ac53", 2],
		[5, "#34363a", "#d7c9a9", "#b88d3d", 3],
	]
	var e: Array = eras[i]
	design["shape"] = e[0]
	design["primary"] = e[1]
	design["secondary"] = e[2]
	design["accent"] = e[3]
	design["pattern"] = e[4]
	_refresh()

func _refresh() -> void:
	if preview == null:
		return
	preview.set_design(design)
	if text_edit != null:
		text_edit.text = str(design.get("text", ""))
	if text_size != null:
		text_size.set_value_no_signal(float(design.get("text_size", 26)))
	if curve_check != null:
		curve_check.set_pressed_no_signal(bool(design.get("text_curved", false)))
	if check_division != null:
		check_division.set_pressed_no_signal(bool(design.get("show_division", true)))
		check_symbol.set_pressed_no_signal(bool(design.get("show_symbol", true)))
		check_text.set_pressed_no_signal(bool(design.get("show_text", true)))
	for key in layer_buttons.keys():
		var b: Button = layer_buttons[key]
		var active: bool = str(key) == color_target
		b.add_theme_stylebox_override("normal", _flat(
			Color(0.31, 0.16, 0.14) if active else Color(0.15, 0.15, 0.17),
			Color(0.86, 0.64, 0.31) if active else Color(0.32, 0.30, 0.27), 1))
	for i in symbol_buttons.size():
		_set_active(symbol_buttons[i], int(design.get("symbol", 0)) == i)
	for i in pattern_buttons.size():
		_set_active(pattern_buttons[i], int(design.get("pattern", 0)) == i)
	for i in border_buttons.size():
		_set_active(border_buttons[i], int(design.get("border", 2)) == i)
	for i in shape_buttons.size():
		_set_active(shape_buttons[i], int(design.get("shape", 0)) == i)
	status_label.text = "%s · %s · %s" % [_house_name, LAYERS[LAYER_KEYS.find(color_target)], "gespeichert" if str(design.get("text", "")) == "" else "Wahlspruch"]

func _set_active(b: Button, active: bool) -> void:
	var bg := Color(0.33, 0.18, 0.15) if active else Color(0.16, 0.16, 0.18)
	var br := Color(0.90, 0.68, 0.34) if active else Color(0.33, 0.31, 0.29)
	b.add_theme_stylebox_override("normal", _flat(bg, br, 1))
	b.add_theme_color_override("font_color", Color(1.0, 0.90, 0.67) if active else Color(0.88, 0.86, 0.80))

func _apply() -> void:
	var d := design.duplicate(true)
	applied.emit(d)
	visible = false

func _export() -> void:
	status_label.text = "Rendere Export ..."
	var img: Image = await render_design(design, Vector2i(512, 640))
	if img == null:
		status_label.text = "Export fehlgeschlagen."
		return
	var path := "user://wappen_export.png"
	var err := img.save_png(path)
	if err != OK:
		status_label.text = "Export konnte nicht geschrieben werden."
		return
	status_label.text = "Export: " + ProjectSettings.globalize_path(path)

func render_design(d: Dictionary, target: Vector2i) -> Image:
	var vp := SubViewport.new()
	vp.size = target
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var p = PreviewScript.new()
	p.size = Vector2(target)
	p.set_design(d)
	vp.add_child(p)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	vp.queue_free()
	return img
