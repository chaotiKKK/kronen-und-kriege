extends Control
## Baut die Bronzezeit-Oberfläche: Startmenü, Herrscher-/Land-Erstellung, Karte,
## Hofpanel mit Familie und Intrigen, Ereignisse, Spielende.

const DataScript = preload("res://scripts/Data.gd")
const GameScript = preload("res://scripts/Game.gd")
const MapViewScript = preload("res://scripts/MapView.gd")
const FamilyTreeScript = preload("res://scripts/FamilyTree.gd")
const BannerGeneratorScript = preload("res://scripts/BannerGenerator.gd")

const TEX_CARD = preload("res://assets/ui/card.png")
const TEX_BUTTON = preload("res://assets/ui/button.png")
const TEX_TITLE = preload("res://assets/ui/title_bg.png")
const TEX_LOGO = preload("res://assets/ui/logo_title.png")

const INK := Color(0.16, 0.11, 0.07)
const INK_SOFT := Color(0.32, 0.24, 0.15)
const CREAM := Color(0.98, 0.94, 0.84)

var game
var map_view
var date_label: Label
var gold_label: Label
var prestige_label: Label
var crest_rect: TextureRect
var portrait_rect: TextureRect
var title_label: Label
var info_label: Label
var family_label: Label
var hint_label: Label
var log_label: Label
var develop_btn: Button
var recruit_btn: Button
var attack_btn: Button
var court_btn: Button
var marry_btn: Button
var bed_btn: Button
var seduce_btn: Button
var murder_btn: Button
var kidnap_btn: Button
var ransom_btn: Button
var force_btn: Button
var speed_buttons: Array = []
var event_layer: Control
var event_title: Label
var event_text: Label
var event_buttons: VBoxContainer
var over_layer: Control
var start_layer: Control
var newgame_layer: Control
var title_status: Label
var start_box: VBoxContainer
var create_layer: Control
var edit_ruler: LineEdit
var edit_house: LineEdit
var edit_land: LineEdit
var create_sex: OptionButton
var create_home: OptionButton
var points_label: Label
var pick_layer: Control
var pick_title: Label
var pick_box: VBoxContainer
var pick_kind: String = ""
var tree_layer: Control
var tree_view
var tree_title: Label
var tree_list: VBoxContainer
var rule_layer: Control
var rule_title: Label
var rule_body: VBoxContainer
var custom_layer: Control
var custom_name: LineEdit
var custom_house: LineEdit
var custom_gender: OptionButton
var custom_age: SpinBox
var custom_portrait_preview: TextureRect
var custom_crest_preview: TextureRect
var custom_color_swatch: ColorRect
var custom_status: Label
var custom_stat_labels: Dictionary = {}
var custom_portrait_buttons: Array = []
var custom_crest_buttons: Array = []
var custom_portrait_group: ButtonGroup
var custom_crest_group: ButtonGroup
var custom_snapshot: Dictionary = {}
var custom_prev_speed: int = 0
var banner_generator
var banner_prev_speed: int = 0
var ambient_player: AudioStreamPlayer
var click_player: AudioStreamPlayer
var sound_btn: Button
var sound_on := true
var selected: String = ""
var accum: float = 0.0
var stat_values := {"martial": 6, "diplomacy": 6, "stewardship": 6, "intrigue": 6}
var stat_labels := {}
var stat_points: int = 20
var CRESTS: Array = []
var PORTRAITS: Array = []
var ICONS: Dictionary = {}

func _ready() -> void:
	_load_assets()
	_load_audio()
	_build()
	_show_start()

func _load_audio() -> void:
	ambient_player = AudioStreamPlayer.new()
	ambient_player.volume_db = -21.0
	var amb = load("res://assets/audio/ambient.wav")
	if amb != null:
		ambient_player.stream = amb
		if amb is AudioStreamWAV:
			amb.loop_mode = AudioStreamWAV.LOOP_FORWARD
			amb.loop_begin = 0
			amb.loop_end = int(amb.get_length() * float(amb.mix_rate))
		add_child(ambient_player)
		ambient_player.play()
	click_player = AudioStreamPlayer.new()
	click_player.volume_db = -9.0
	var clk = load("res://assets/audio/click.wav")
	if clk != null:
		click_player.stream = clk
		add_child(click_player)

func _play_click() -> void:
	if sound_on and click_player != null:
		click_player.play()

func _toggle_sound() -> void:
	sound_on = not sound_on
	if ambient_player != null:
		ambient_player.stream_paused = not sound_on
	if sound_btn != null:
		sound_btn.text = "Ton an" if sound_on else "Ton aus"

func _load_assets() -> void:
	for i in 9:
		var t = load("res://assets/crests/crest_%d.png" % i)
		if t != null:
			CRESTS.append(t)
	PORTRAITS.clear()
	for i in 48:
		var t2 = load("res://assets/portraits_hd/portrait_%02d.png" % (i + 1))
		if t2 == null:
			t2 = load("res://assets/portraits/portrait_%d.png" % i)
		PORTRAITS.append(t2)
	for n in ["gold", "prestige", "sword", "heart", "ring", "mask", "dagger", "chain", "crown", "scroll"]:
		var t3 = load("res://assets/icons/icon_%s.png" % n)
		if t3 != null:
			ICONS[n] = t3

# --- Stile ---------------------------------------------------------------

func _card_style(cm: int = 18) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = TEX_CARD
	sb.texture_margin_left = 24
	sb.texture_margin_right = 24
	sb.texture_margin_top = 24
	sb.texture_margin_bottom = 24
	sb.content_margin_left = cm
	sb.content_margin_right = cm
	sb.content_margin_top = cm - 4
	sb.content_margin_bottom = cm - 4
	return sb

func _btn_style(bright: float) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = TEX_BUTTON
	sb.texture_margin_left = 14
	sb.texture_margin_right = 14
	sb.texture_margin_top = 12
	sb.texture_margin_bottom = 12
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	sb.modulate_color = Color(bright, bright, bright)
	return sb

func _flat(bg: Color, line := Color(0, 0, 0, 0), width: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	if width > 0:
		sb.border_width_left = width
		sb.border_width_right = width
		sb.border_width_top = width
		sb.border_width_bottom = width
		sb.border_color = line
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

func _field_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.95, 0.88, 0.71)
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.45, 0.32, 0.17)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb

func _label(text: String, px: int, col := INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", col)
	return l

func _button(text: String, cb: Callable, icon_name := "") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 46)
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_pressed_color", Color(0.86, 0.80, 0.68))
	b.add_theme_color_override("font_disabled_color", Color(0.50, 0.44, 0.36))
	b.add_theme_stylebox_override("normal", _btn_style(1.0))
	b.add_theme_stylebox_override("hover", _btn_style(1.18))
	b.add_theme_stylebox_override("pressed", _btn_style(0.82))
	b.add_theme_stylebox_override("disabled", _btn_style(0.55))
	b.add_theme_stylebox_override("focus", _btn_style(1.05))
	if icon_name != "" and ICONS.has(icon_name):
		b.icon = ICONS[icon_name]
		b.add_theme_constant_override("icon_max_width", 22)
	b.pressed.connect(cb)
	b.pressed.connect(_play_click)
	return b

func _title_button(text: String, cb: Callable, icon_name := "") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 54)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", Color(0.97, 0.91, 0.78))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_pressed_color", Color(0.84, 0.77, 0.62))
	b.add_theme_stylebox_override("normal", _flat(Color(0.07, 0.05, 0.03, 0.82), Color(0.56, 0.42, 0.20), 1))
	b.add_theme_stylebox_override("hover", _flat(Color(0.18, 0.12, 0.06, 0.94), Color(0.90, 0.70, 0.34), 2))
	b.add_theme_stylebox_override("pressed", _flat(Color(0.04, 0.03, 0.02, 0.96), Color(0.90, 0.70, 0.34), 2))
	b.add_theme_stylebox_override("focus", _flat(Color(0.10, 0.07, 0.04, 0.90), Color(0.72, 0.56, 0.28), 1))
	if icon_name != "" and ICONS.has(icon_name):
		b.icon = ICONS[icon_name]
		b.add_theme_constant_override("icon_max_width", 24)
	b.pressed.connect(cb)
	b.pressed.connect(_play_click)
	return b

func _map_tool(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(48, 38)
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_stylebox_override("normal", _flat(Color(0.10, 0.07, 0.05, 0.88), Color(0.66, 0.50, 0.25), 1))
	b.add_theme_stylebox_override("hover", _flat(Color(0.20, 0.14, 0.08, 0.95), Color(0.86, 0.68, 0.34), 1))
	b.add_theme_stylebox_override("pressed", _flat(Color(0.06, 0.04, 0.03, 0.95), Color(0.86, 0.68, 0.34), 1))
	b.pressed.connect(cb)
	b.pressed.connect(_play_click)
	return b

func _spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c

# --- Aufbau --------------------------------------------------------------

func _build() -> void:
	var back := ColorRect.new()
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.color = Color(0.07, 0.06, 0.05)
	add_child(back)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	# Kopfzeile
	var top := PanelContainer.new()
	top.custom_minimum_size = Vector2(0, 62)
	top.add_theme_stylebox_override("panel", _flat(Color(0.14, 0.10, 0.07), Color(0.55, 0.40, 0.18), 2))
	root.add_child(top)
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 16)
	top.add_child(top_row)
	date_label = _label("2000 v. Chr.", 20, CREAM)
	top_row.add_child(date_label)
	top_row.add_child(_spacer())
	gold_label = _label("Gold: 0", 19, Color(0.96, 0.80, 0.38))
	top_row.add_child(gold_label)
	prestige_label = _label("Prestige: 0", 19, Color(0.76, 0.86, 0.98))
	top_row.add_child(prestige_label)
	top_row.add_child(_spacer())
	sound_btn = Button.new()
	sound_btn.text = "Ton an"
	sound_btn.custom_minimum_size = Vector2(76, 40)
	sound_btn.add_theme_font_size_override("font_size", 13)
	sound_btn.add_theme_color_override("font_color", CREAM)
	sound_btn.add_theme_stylebox_override("normal", _flat(Color(0.10, 0.07, 0.05, 0.8), Color(0.50, 0.38, 0.18), 1))
	sound_btn.pressed.connect(_toggle_sound)
	top_row.add_child(sound_btn)
	for i in 4:
		var names := ["Pause", "x1", "x2", "x3"]
		var b := Button.new()
		b.text = names[i]
		b.custom_minimum_size = Vector2(66, 40)
		b.add_theme_font_size_override("font_size", 15)
		b.pressed.connect(_set_speed.bind(i))
		speed_buttons.append(b)
		top_row.add_child(b)

	# Inhalt: Karte + Log
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 0)
	root.add_child(row)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(left)

	var map_wrap := Control.new()
	map_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_wrap.custom_minimum_size = Vector2(420, 320)
	left.add_child(map_wrap)
	map_view = MapViewScript.new()
	map_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_view.province_selected.connect(_on_province_selected)
	map_wrap.add_child(map_view)
	var map_tools := HBoxContainer.new()
	map_tools.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	map_tools.offset_left = -162
	map_tools.offset_top = 8
	map_tools.offset_right = -8
	map_tools.offset_bottom = 48
	map_tools.add_theme_constant_override("separation", 6)
	map_wrap.add_child(map_tools)
	map_tools.add_child(_map_tool("−", func(): map_view.zoom_by(0.8)))
	map_tools.add_child(_map_tool("+", func(): map_view.zoom_by(1.25)))
	map_tools.add_child(_map_tool("1:1", func(): map_view.reset_view()))

	var log_panel := PanelContainer.new()
	log_panel.custom_minimum_size = Vector2(0, 92)
	log_panel.add_theme_stylebox_override("panel", _flat(Color(0.10, 0.08, 0.06), Color(0.35, 0.26, 0.13), 1))
	left.add_child(log_panel)
	log_label = _label("", 13, Color(0.88, 0.84, 0.74))
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_panel.add_child(log_label)

	# Hofpanel
	var side := PanelContainer.new()
	side.custom_minimum_size = Vector2(430, 0)
	side.add_theme_stylebox_override("panel", _card_style(12))
	row.add_child(side)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(scroll)
	var side_box := VBoxContainer.new()
	side_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_box.add_theme_constant_override("separation", 7)
	scroll.add_child(side_box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	side_box.add_child(head)
	crest_rect = TextureRect.new()
	crest_rect.custom_minimum_size = Vector2(54, 64)
	crest_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crest_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(crest_rect)
	portrait_rect = TextureRect.new()
	portrait_rect.custom_minimum_size = Vector2(88, 108)
	portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	portrait_rect.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	portrait_rect.tooltip_text = "Porträt antippen: Herrscher und Wappen gestalten"
	portrait_rect.gui_input.connect(_on_identity_gui_input)
	head.add_child(portrait_rect)
	crest_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	crest_rect.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	crest_rect.tooltip_text = "Wappen antippen: Herrscher und Wappen gestalten"
	crest_rect.gui_input.connect(_on_identity_gui_input)
	var head_text := VBoxContainer.new()
	head_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_text.add_theme_constant_override("separation", 2)
	head.add_child(head_text)
	title_label = _label("Dein Hof", 21, INK)
	head_text.add_child(title_label)
	info_label = _label("", 14, INK_SOFT)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head_text.add_child(info_label)
	var profile_hint := _label("Porträt oder Wappen antippen, um Herrscher, Werte und Haus zu gestalten.", 11, Color(0.43, 0.31, 0.18))
	profile_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side_box.add_child(profile_hint)

	family_label = _label("", 13, INK_SOFT)
	family_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side_box.add_child(family_label)
	side_box.add_child(_button("Stammbaum", _show_tree, "crown"))
	hint_label = _label("Tippe auf eine Provinz.", 12, Color(0.38, 0.30, 0.20))
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side_box.add_child(hint_label)

	develop_btn = _button("Ausbauen  (50 Gold)", func(): _do(game.develop(selected)), "gold")
	recruit_btn = _button("Truppen werben  (30 Gold)", func(): _do(game.recruit(selected)), "sword")
	attack_btn = _button("Angreifen  (25 Gold)", func(): _do(game.attack(selected)), "sword")
	side_box.add_child(develop_btn)
	side_box.add_child(recruit_btn)
	side_box.add_child(attack_btn)

	var divider := HSeparator.new()
	side_box.add_child(divider)
	side_box.add_child(_label("Familie & Intrigen", 17, INK))
	marry_btn = _button("Heiraten  (30 Gold)", func(): _open_picker("marry"), "ring")
	bed_btn = _button("Beilager halten", _bed, "heart")
	seduce_btn = _button("Verführen  (20 Gold)", func(): _open_picker("seduce"), "mask")
	murder_btn = _button("Ermorden  (60 Gold)", func(): _open_picker("murder"), "dagger")
	kidnap_btn = _button("Entführen  (45 Gold)", func(): _open_picker("kidnap"), "chain")
	ransom_btn = _button("Lösegeld fordern  (+80 Gold)", func(): _do(game.ransom_captive()), "gold")
	force_btn = _button("Gefangene/n heiraten", func(): _do(game.force_marry_captive()), "ring")
	side_box.add_child(marry_btn)
	side_box.add_child(bed_btn)
	side_box.add_child(seduce_btn)
	side_box.add_child(murder_btn)
	side_box.add_child(kidnap_btn)
	side_box.add_child(ransom_btn)
	side_box.add_child(force_btn)
	court_btn = _button("Hof halten  (40 Gold)", func(): _do(game.court()), "crown")
	side_box.add_child(court_btn)
	side_box.add_child(_button("Herrschaft", _show_rule, "crown"))
	side_box.add_child(_button("Spiel speichern", _save, "scroll"))
	side_box.add_child(_button("Spielstand laden", _load, "scroll"))
	_build_rule_layer()

	# Ereignis-Overlay
	event_layer = Control.new()
	event_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	event_layer.visible = false
	event_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(event_layer)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.66)
	event_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	event_layer.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(720, 0)
	card.add_theme_stylebox_override("panel", _card_style(22))
	center.add_child(card)
	var card_box := VBoxContainer.new()
	card_box.add_theme_constant_override("separation", 14)
	card.add_child(card_box)
	event_title = _label("", 25, INK)
	card_box.add_child(event_title)
	event_text = _label("", 17, INK_SOFT)
	event_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_box.add_child(event_text)
	event_buttons = VBoxContainer.new()
	event_buttons.add_theme_constant_override("separation", 8)
	card_box.add_child(event_buttons)

	# Spielende
	over_layer = Control.new()
	over_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	over_layer.visible = false
	over_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(over_layer)
	var dim2 := ColorRect.new()
	dim2.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim2.color = Color(0.05, 0.02, 0.02, 0.86)
	over_layer.add_child(dim2)
	var center2 := CenterContainer.new()
	center2.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	over_layer.add_child(center2)
	var card2 := PanelContainer.new()
	card2.custom_minimum_size = Vector2(600, 0)
	card2.add_theme_stylebox_override("panel", _card_style(24))
	center2.add_child(card2)
	var box2 := VBoxContainer.new()
	box2.add_theme_constant_override("separation", 14)
	card2.add_child(box2)
	box2.add_child(_label("Das Haus ist erloschen", 27, Color(0.55, 0.18, 0.12)))
	var t := _label("Ohne Erben endet die Dynastie. Beginne ein neues Spiel.", 17, INK_SOFT)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box2.add_child(t)
	box2.add_child(_button("Neu beginnen", func(): get_tree().reload_current_scene(), "crown"))

	# Titelbild
	start_layer = Control.new()
	start_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	start_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(start_layer)
	var art := TextureRect.new()
	art.texture = TEX_TITLE
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	start_layer.add_child(art)
	var dim3 := ColorRect.new()
	dim3.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim3.color = Color(0.02, 0.015, 0.01, 0.10)
	dim3.mouse_filter = Control.MOUSE_FILTER_IGNORE
	start_layer.add_child(dim3)

	var title_panel := VBoxContainer.new()
	title_panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	title_panel.offset_left = -440
	title_panel.offset_right = -44
	title_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	title_panel.add_theme_constant_override("separation", 8)
	start_layer.add_child(title_panel)
	var logo_rect := TextureRect.new()
	logo_rect.texture = TEX_LOGO
	logo_rect.custom_minimum_size = Vector2(0, 342)
	logo_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_panel.add_child(logo_rect)
	var title_menu := VBoxContainer.new()
	title_menu.add_theme_constant_override("separation", 9)
	title_panel.add_child(title_menu)
	title_menu.add_child(_title_button("Neues Spiel", _show_newgame, "crown"))
	title_menu.add_child(_title_button("Spiel laden", _load_from_title, "scroll"))
	title_menu.add_child(_title_button("Beenden", _quit_game, ""))
	title_status = _label("", 12, Color(0.90, 0.75, 0.48))
	title_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_menu.add_child(title_status)

	var version := _label("v1.2 · Bronzezeit · 2000 v. Chr.", 12, Color(0.72, 0.60, 0.42))
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	version.offset_left = 24
	version.offset_top = -32
	version.offset_right = 420
	version.offset_bottom = -10
	start_layer.add_child(version)
	var fullscreen_hint := _label("F11 · Vollbild", 12, Color(0.58, 0.50, 0.38))
	fullscreen_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	fullscreen_hint.offset_left = -180
	fullscreen_hint.offset_top = -32
	fullscreen_hint.offset_right = -24
	fullscreen_hint.offset_bottom = -10
	fullscreen_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	start_layer.add_child(fullscreen_hint)

	# Hausauswahl für ein neues Spiel
	newgame_layer = Control.new()
	newgame_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	newgame_layer.visible = false
	newgame_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(newgame_layer)
	var dim_new := ColorRect.new()
	dim_new.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim_new.color = Color(0.02, 0.015, 0.01, 0.78)
	newgame_layer.add_child(dim_new)
	var center_new := CenterContainer.new()
	center_new.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	newgame_layer.add_child(center_new)
	var card_new := PanelContainer.new()
	card_new.custom_minimum_size = Vector2(880, 0)
	card_new.add_theme_stylebox_override("panel", _card_style(22))
	center_new.add_child(card_new)
	var box_new := VBoxContainer.new()
	box_new.add_theme_constant_override("separation", 8)
	card_new.add_child(box_new)
	var head_new := HBoxContainer.new()
	head_new.add_theme_constant_override("separation", 12)
	box_new.add_child(head_new)
	head_new.add_child(_label("Wähle dein Haus", 30, INK))
	head_new.add_child(_spacer())
	head_new.add_child(_button("Zurück", _hide_newgame, ""))
	var sub_new := _label("2000 v. Chr. · 49 Grafschaften · neun Königreiche · drei Reiche", 14, INK_SOFT)
	sub_new.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box_new.add_child(sub_new)
	box_new.add_child(_button("Eigenes Haus gründen", _show_create, "crown"))
	var scroll3 := ScrollContainer.new()
	scroll3.custom_minimum_size = Vector2(0, 356)
	scroll3.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box_new.add_child(scroll3)
	start_box = VBoxContainer.new()
	start_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_box.add_theme_constant_override("separation", 6)
	scroll3.add_child(start_box)

	# Erstellung
	create_layer = Control.new()
	create_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	create_layer.visible = false
	create_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(create_layer)
	var dim4 := ColorRect.new()
	dim4.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim4.color = Color(0.04, 0.03, 0.02, 0.78)
	create_layer.add_child(dim4)
	var center4 := CenterContainer.new()
	center4.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	create_layer.add_child(center4)
	var card4 := PanelContainer.new()
	card4.custom_minimum_size = Vector2(880, 0)
	card4.add_theme_stylebox_override("panel", _card_style(22))
	center4.add_child(card4)
	var box4 := VBoxContainer.new()
	box4.add_theme_constant_override("separation", 8)
	card4.add_child(box4)
	box4.add_child(_label("Gründe dein Haus", 30, INK))
	box4.add_child(_label("2000 v. Chr. — du bestimmst Namen, Land und Gaben.", 14, INK_SOFT))

	var form := GridContainer.new()
	form.columns = 2
	form.add_theme_constant_override("h_separation", 14)
	form.add_theme_constant_override("v_separation", 6)
	box4.add_child(form)
	form.add_child(_label("Herrscher", 15, INK))
	edit_ruler = _field("Ari", "Name des Herrschers")
	form.add_child(edit_ruler)
	form.add_child(_label("Haus", 15, INK))
	edit_house = _field("Haus Neu", "Name deiner Dynastie")
	form.add_child(edit_house)
	form.add_child(_label("Grafschaft", 15, INK))
	edit_land = _field("", "Name deiner Grafschaft (optional)")
	form.add_child(edit_land)
	form.add_child(_label("Geschlecht", 15, INK))
	create_sex = OptionButton.new()
	create_sex.add_item("Mann")
	create_sex.add_item("Frau")
	create_sex.add_theme_stylebox_override("normal", _field_style())
	create_sex.add_theme_color_override("font_color", INK)
	form.add_child(create_sex)
	form.add_child(_label("Heimat", 15, INK))
	create_home = OptionButton.new()
	var provs: Array = DataScript.provinces()
	var houses: Array = DataScript.houses()
	for i in provs.size():
		var p: Dictionary = provs[i]
		create_home.add_item("%s · %s" % [p["name"], str(p["duchy_name"]).replace("Herzogtum ", "")])
		create_home.set_item_metadata(i, p["id"])
	create_home.add_theme_stylebox_override("normal", _field_style())
	create_home.add_theme_color_override("font_color", INK)
	form.add_child(create_home)

	var stats := VBoxContainer.new()
	stats.add_theme_constant_override("separation", 4)
	box4.add_child(stats)
	stats.add_child(_label("Gaben (20 Punkte frei)", 15, INK))
	for key in ["martial", "diplomacy", "stewardship", "intrigue"]:
		var row2 := HBoxContainer.new()
		row2.add_theme_constant_override("separation", 8)
		var name_label := _label(_stat_name(key), 14, INK)
		name_label.custom_minimum_size = Vector2(150, 0)
		row2.add_child(name_label)
		var minus := _button("−", func(): _adjust(key, -1), "")
		minus.custom_minimum_size = Vector2(42, 38)
		row2.add_child(minus)
		var value_label := _label(str(stat_values[key]), 17, INK)
		value_label.custom_minimum_size = Vector2(34, 0)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row2.add_child(value_label)
		stat_labels[key] = value_label
		var plus := _button("+", func(): _adjust(key, 1), "")
		plus.custom_minimum_size = Vector2(42, 38)
		row2.add_child(plus)
		stats.add_child(row2)
	points_label = _label("Punkte übrig: 20", 14, INK_SOFT)
	stats.add_child(points_label)

	var create_actions := HBoxContainer.new()
	create_actions.add_theme_constant_override("separation", 10)
	create_actions.add_child(_button("Herrschaft beginnen", _create_begin, "crown"))
	create_actions.add_child(_button("Zurück", _hide_create, ""))
	box4.add_child(create_actions)

	# Stammbaum
	tree_layer = Control.new()
	tree_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tree_layer.visible = false
	tree_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(tree_layer)
	var dim6 := ColorRect.new()
	dim6.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim6.color = Color(0, 0, 0, 0.72)
	tree_layer.add_child(dim6)
	var center6 := CenterContainer.new()
	center6.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tree_layer.add_child(center6)
	var card6 := PanelContainer.new()
	card6.custom_minimum_size = Vector2(1140, 0)
	card6.add_theme_stylebox_override("panel", _card_style(20))
	center6.add_child(card6)
	var box6 := VBoxContainer.new()
	box6.add_theme_constant_override("separation", 6)
	card6.add_child(box6)
	var head6 := HBoxContainer.new()
	head6.add_theme_constant_override("separation", 12)
	box6.add_child(head6)
	tree_title = _label("Stammbaum", 23, INK)
	head6.add_child(tree_title)
	head6.add_child(_spacer())
	head6.add_child(_button("Schließen", _hide_tree, ""))
	var content6 := HBoxContainer.new()
	content6.add_theme_constant_override("separation", 10)
	box6.add_child(content6)
	var tree_scroll := ScrollContainer.new()
	tree_scroll.custom_minimum_size = Vector2(730, 470)
	tree_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content6.add_child(tree_scroll)
	tree_view = FamilyTreeScript.new()
	tree_view.custom_minimum_size = Vector2(720, 470)
	tree_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree_scroll.add_child(tree_view)
	var list_scroll := ScrollContainer.new()
	list_scroll.custom_minimum_size = Vector2(330, 470)
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content6.add_child(list_scroll)
	tree_list = VBoxContainer.new()
	tree_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree_list.add_theme_constant_override("separation", 5)
	list_scroll.add_child(tree_list)

	# Zielauswahl für Intrigen
	pick_layer = Control.new()
	pick_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pick_layer.visible = false
	pick_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(pick_layer)
	var dim5 := ColorRect.new()
	dim5.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim5.color = Color(0, 0, 0, 0.7)
	pick_layer.add_child(dim5)
	var center5 := CenterContainer.new()
	center5.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pick_layer.add_child(center5)
	var card5 := PanelContainer.new()
	card5.custom_minimum_size = Vector2(780, 0)
	card5.add_theme_stylebox_override("panel", _card_style(22))
	center5.add_child(card5)
	var box5 := VBoxContainer.new()
	box5.add_theme_constant_override("separation", 8)
	card5.add_child(box5)
	pick_title = _label("", 24, INK)
	box5.add_child(pick_title)
	var pick_scroll := ScrollContainer.new()
	pick_scroll.custom_minimum_size = Vector2(0, 420)
	pick_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box5.add_child(pick_scroll)
	pick_box = VBoxContainer.new()
	pick_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pick_box.add_theme_constant_override("separation", 6)
	pick_scroll.add_child(pick_box)
	box5.add_child(_button("Abbrechen", func(): pick_layer.visible = false, ""))

	_build_customizer()
	_build_banner_generator()

func _build_banner_generator() -> void:
	banner_generator = BannerGeneratorScript.new()
	add_child(banner_generator)
	banner_generator.applied.connect(_on_banner_applied)
	banner_generator.closed.connect(_on_banner_closed)

# --- Herrscher-Werkstatt -------------------------------------------------

func _build_customizer() -> void:
	custom_layer = Control.new()
	custom_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	custom_layer.visible = false
	custom_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(custom_layer)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.02, 0.02, 0.84)
	custom_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	custom_layer.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(960, 0)
	card.add_theme_stylebox_override("panel", _card_style(18))
	center.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	card.add_child(box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	box.add_child(head)
	head.add_child(_label("Herrscher gestalten", 26, INK))
	head.add_child(_spacer())
	head.add_child(_button("Schließen", _custom_cancel, ""))
	var sub := _label("Porträt, Wappen, Hausfarbe und Charakter deines Herrschers.", 13, INK_SOFT)
	box.add_child(sub)

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	box.add_child(content)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(330, 0)
	left.add_theme_constant_override("separation", 4)
	content.add_child(left)

	var preview_row := HBoxContainer.new()
	preview_row.add_theme_constant_override("separation", 10)
	left.add_child(preview_row)
	var portrait_frame := PanelContainer.new()
	portrait_frame.custom_minimum_size = Vector2(116, 142)
	portrait_frame.add_theme_stylebox_override("panel", _flat(Color(0.16, 0.11, 0.07, 0.92), Color(0.76, 0.58, 0.28), 2))
	preview_row.add_child(portrait_frame)
	custom_portrait_preview = TextureRect.new()
	custom_portrait_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	custom_portrait_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_frame.add_child(custom_portrait_preview)
	var badge := VBoxContainer.new()
	badge.add_theme_constant_override("separation", 3)
	preview_row.add_child(badge)
	var crest_frame := PanelContainer.new()
	crest_frame.custom_minimum_size = Vector2(74, 88)
	crest_frame.add_theme_stylebox_override("panel", _flat(Color(0.16, 0.11, 0.07, 0.92), Color(0.76, 0.58, 0.28), 2))
	badge.add_child(crest_frame)
	custom_crest_preview = TextureRect.new()
	custom_crest_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	custom_crest_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crest_frame.add_child(custom_crest_preview)
	badge.add_child(_label("Hausfarbe", 10, INK_SOFT))
	custom_color_swatch = ColorRect.new()
	custom_color_swatch.custom_minimum_size = Vector2(74, 18)
	badge.add_child(custom_color_swatch)

	left.add_child(_label("Porträt wählen", 13, INK))
	var portrait_scroll := ScrollContainer.new()
	portrait_scroll.custom_minimum_size = Vector2(0, 176)
	portrait_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(portrait_scroll)
	var portrait_grid := GridContainer.new()
	portrait_grid.columns = 6
	portrait_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait_grid.add_theme_constant_override("h_separation", 3)
	portrait_grid.add_theme_constant_override("v_separation", 3)
	portrait_scroll.add_child(portrait_grid)
	custom_portrait_group = ButtonGroup.new()
	for i in PORTRAITS.size():
		var pb := Button.new()
		pb.toggle_mode = true
		pb.button_group = custom_portrait_group
		pb.custom_minimum_size = Vector2(48, 54)
		pb.icon = PORTRAITS[i]
		pb.add_theme_constant_override("icon_max_width", 42)
		pb.add_theme_stylebox_override("normal", _flat(Color(0.90, 0.83, 0.68), Color(0.45, 0.32, 0.17), 1))
		pb.add_theme_stylebox_override("hover", _flat(Color(0.98, 0.91, 0.75), Color(0.72, 0.52, 0.23), 2))
		pb.add_theme_stylebox_override("pressed", _flat(Color(0.82, 0.72, 0.52), Color(0.88, 0.68, 0.32), 2))
		pb.tooltip_text = "Porträt %d" % (i + 1)
		pb.pressed.connect(_custom_set_portrait.bind(i))
		portrait_grid.add_child(pb)
		custom_portrait_buttons.append(pb)

	left.add_child(_label("Wappen wählen", 13, INK))
	var crest_grid := GridContainer.new()
	crest_grid.columns = 5
	crest_grid.add_theme_constant_override("h_separation", 3)
	crest_grid.add_theme_constant_override("v_separation", 3)
	left.add_child(crest_grid)
	custom_crest_group = ButtonGroup.new()
	for i in CRESTS.size():
		var cb := Button.new()
		cb.toggle_mode = true
		cb.button_group = custom_crest_group
		cb.custom_minimum_size = Vector2(58, 48)
		cb.icon = CRESTS[i]
		cb.add_theme_constant_override("icon_max_width", 34)
		cb.add_theme_stylebox_override("normal", _flat(Color(0.90, 0.83, 0.68), Color(0.45, 0.32, 0.17), 1))
		cb.add_theme_stylebox_override("hover", _flat(Color(0.98, 0.91, 0.75), Color(0.72, 0.52, 0.23), 2))
		cb.add_theme_stylebox_override("pressed", _flat(Color(0.82, 0.72, 0.52), Color(0.88, 0.68, 0.32), 2))
		cb.tooltip_text = "Wappen %d" % (i + 1)
		cb.pressed.connect(_custom_set_crest.bind(i))
		crest_grid.add_child(cb)
		custom_crest_buttons.append(cb)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 5)
	content.add_child(right)
	var form := GridContainer.new()
	form.columns = 2
	form.add_theme_constant_override("h_separation", 12)
	form.add_theme_constant_override("v_separation", 5)
	right.add_child(form)
	form.add_child(_label("Name", 13, INK))
	custom_name = _field("", "Name des Herrschers")
	custom_name.custom_minimum_size = Vector2(300, 0)
	form.add_child(custom_name)
	form.add_child(_label("Haus", 13, INK))
	custom_house = _field("", "Name des Hauses")
	custom_house.custom_minimum_size = Vector2(300, 0)
	form.add_child(custom_house)
	form.add_child(_label("Geschlecht", 13, INK))
	custom_gender = OptionButton.new()
	custom_gender.add_item("Mann")
	custom_gender.add_item("Frau")
	custom_gender.add_theme_stylebox_override("normal", _field_style())
	custom_gender.add_theme_color_override("font_color", INK)
	form.add_child(custom_gender)
	form.add_child(_label("Alter", 13, INK))
	custom_age = SpinBox.new()
	custom_age.min_value = 16
	custom_age.max_value = 90
	custom_age.get_line_edit().add_theme_stylebox_override("normal", _field_style())
	custom_age.get_line_edit().add_theme_color_override("font_color", INK)
	form.add_child(custom_age)

	right.add_child(_label("Hausfarbe", 13, INK))
	var palette := HBoxContainer.new()
	palette.add_theme_constant_override("separation", 4)
	right.add_child(palette)
	for col in [
		Color(0.68, 0.30, 0.20), Color(0.22, 0.38, 0.62), Color(0.24, 0.50, 0.30),
		Color(0.76, 0.56, 0.20), Color(0.18, 0.50, 0.52), Color(0.46, 0.28, 0.58),
		Color(0.72, 0.60, 0.20), Color(0.34, 0.40, 0.48), Color(0.48, 0.54, 0.28),
		Color(0.58, 0.22, 0.28),
	]:
		var color_btn := Button.new()
		color_btn.custom_minimum_size = Vector2(30, 30)
		color_btn.tooltip_text = "Hausfarbe wählen"
		color_btn.add_theme_stylebox_override("normal", _flat(col, Color(0.20, 0.14, 0.08), 1))
		color_btn.add_theme_stylebox_override("hover", _flat(col.lightened(0.18), Color(0.90, 0.70, 0.34), 2))
		color_btn.add_theme_stylebox_override("pressed", _flat(col.darkened(0.18), Color(1.0, 0.82, 0.42), 2))
		color_btn.pressed.connect(_custom_set_color.bind(col))
		palette.add_child(color_btn)

	right.add_child(_label("Charakterwerte", 15, INK))
	for key in ["martial", "diplomacy", "stewardship", "intrigue"]:
		var stat_row := HBoxContainer.new()
		stat_row.add_theme_constant_override("separation", 7)
		var stat_label := _label(_stat_name(key), 13, INK_SOFT)
		stat_label.custom_minimum_size = Vector2(145, 0)
		stat_row.add_child(stat_label)
		var minus := _button("−", Callable(self, "_custom_adjust").bind(key, -1), "")
		minus.custom_minimum_size = Vector2(36, 32)
		stat_row.add_child(minus)
		var value_label := _label("", 15, INK)
		value_label.custom_minimum_size = Vector2(34, 0)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stat_row.add_child(value_label)
		custom_stat_labels[key] = value_label
		var plus := _button("+", Callable(self, "_custom_adjust").bind(key, 1), "")
		plus.custom_minimum_size = Vector2(36, 32)
		stat_row.add_child(plus)
		right.add_child(stat_row)

	custom_status = _label("Werte 3–20. Übernehmen speichert alle Änderungen im Spielstand.", 11, Color(0.44, 0.34, 0.22))
	custom_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(custom_status)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override("separation", 8)
	box.add_child(footer)
	footer.add_child(_button("Banner-Generator", _open_banner_generator, "crown"))
	footer.add_child(_button("Abbrechen", _custom_cancel, ""))
	footer.add_child(_button("Übernehmen", _custom_apply, "crown"))

	custom_name.text_changed.connect(_custom_name_changed)
	custom_house.text_changed.connect(_custom_house_changed)
	custom_gender.item_selected.connect(_custom_gender_changed)
	custom_age.value_changed.connect(_custom_age_changed)

func _on_identity_gui_input(event: InputEvent) -> void:
	if game == null or game.game_over or custom_layer == null or custom_layer.visible:
		return
	var clicked := false
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		clicked = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		clicked = (event as InputEventScreenTouch).pressed
	if clicked:
		_open_customizer()

func _open_customizer() -> void:
	if game == null or game.game_over:
		return
	custom_snapshot = game.house().duplicate(true)
	custom_prev_speed = int(game.speed)
	game.speed = 0
	var h: Dictionary = game.house()
	var r: Dictionary = h["ruler"]
	custom_name.text = str(r["name"])
	custom_house.text = str(h["name"])
	custom_gender.select(1 if str(r["gender"]) == "f" else 0)
	custom_age.set_value_no_signal(int(r["age"]))
	custom_layer.visible = true
	_refresh_customizer()
	refresh()

func _refresh_customizer() -> void:
	if game == null or custom_portrait_preview == null:
		return
	var h: Dictionary = game.house()
	var r: Dictionary = h["ruler"]
	var pcount: int = custom_portrait_buttons.size()
	var ccount: int = custom_crest_buttons.size()
	var pidx: int = posmod(int(r.get("portrait", 0)), maxi(1, pcount))
	var cidx: int = posmod(int(h.get("crest", game.player)), maxi(1, ccount))
	if not PORTRAITS.is_empty():
		custom_portrait_preview.texture = PORTRAITS[pidx % PORTRAITS.size()]
	var custom_tex := _house_crest_texture(h)
	if custom_tex != null:
		custom_crest_preview.texture = custom_tex
	elif not CRESTS.is_empty():
		custom_crest_preview.texture = CRESTS[cidx % CRESTS.size()]
	custom_color_swatch.color = h.get("color", Color(0.68, 0.30, 0.20))
	for i in pcount:
		custom_portrait_buttons[i].button_pressed = (i == pidx)
	for i in ccount:
		custom_crest_buttons[i].button_pressed = (i == cidx and custom_tex == null)
	for key in custom_stat_labels.keys():
		custom_stat_labels[key].text = str(int(r.get(key, 8)))
	custom_status.text = "%s · %s · %d Jahre · Wappen %d" % [r.get("name", ""), "Frau" if str(r.get("gender", "m")) == "f" else "Mann", int(r.get("age", 25)), cidx + 1]

func _custom_name_changed(value: String) -> void:
	if game == null or value.strip_edges() == "":
		return
	game.house()["ruler"]["name"] = value.strip_edges()
	_refresh_customizer()
	refresh()

func _custom_house_changed(value: String) -> void:
	if game == null or value.strip_edges() == "":
		return
	game.house()["name"] = value.strip_edges()
	refresh()

func _custom_gender_changed(index: int) -> void:
	if game == null:
		return
	game.house()["ruler"]["gender"] = "f" if index == 1 else "m"
	_refresh_customizer()
	refresh()

func _custom_age_changed(value: float) -> void:
	if game == null:
		return
	game.house()["ruler"]["age"] = clampi(int(value), 16, 90)
	_refresh_customizer()
	refresh()

func _custom_adjust(key: String, delta: int) -> void:
	if game == null:
		return
	var r: Dictionary = game.house()["ruler"]
	r[key] = clampi(int(r.get(key, 8)) + delta, 3, 20)
	_refresh_customizer()
	refresh()

func _custom_set_portrait(index: int) -> void:
	if game == null:
		return
	game.house()["ruler"]["portrait"] = index
	_refresh_customizer()
	refresh()

func _custom_set_crest(index: int) -> void:
	if game == null:
		return
	if index < 9:
		game.house().erase("crest_file")
	game.house()["crest"] = index
	_refresh_customizer()
	refresh()

func _custom_set_color(col: Color) -> void:
	if game == null:
		return
	game.house()["color"] = col
	_refresh_customizer()
	refresh()

func _custom_apply() -> void:
	if game == null:
		_close_customizer(false)
		return
	if custom_name.text.strip_edges() == "":
		custom_name.text = "Ari"
		game.house()["ruler"]["name"] = "Ari"
	if custom_house.text.strip_edges() == "":
		custom_house.text = "Haus Neu"
		game.house()["name"] = "Haus Neu"
	game.note("Herrscher, Wappen und Hausfarbe wurden angepasst.")
	_close_customizer(false)

func _custom_cancel() -> void:
	_close_customizer(true)

func _open_banner_generator() -> void:
	if game == null or game.game_over or banner_generator == null:
		return
	if banner_generator.visible:
		return
	banner_prev_speed = int(game.speed)
	game.speed = 0
	banner_generator.open(game.house())

func _on_banner_closed() -> void:
	if game != null and custom_layer != null and not custom_layer.visible:
		game.speed = banner_prev_speed

func _on_banner_applied(design: Dictionary) -> void:
	if game == null:
		return
	var h: Dictionary = game.house()
	h["banner"] = design.duplicate(true)
	h["crest"] = 9
	var img: Image = await banner_generator.render_design(design, Vector2i(256, 320))
	if img != null:
		var path := "user://wappen_custom.png"
		if img.save_png(path) == OK:
			h["crest_file"] = path
			var tex := ImageTexture.create_from_image(img)
			while CRESTS.size() <= 9:
				CRESTS.append(null)
			CRESTS[9] = tex
			if map_view != null:
				map_view.set_crest_texture(9, tex)
	game.note("%s: Ein neues Hauswappen wird angenommen." % h["name"])
	if not custom_layer.visible:
		game.speed = banner_prev_speed
	refresh()
	if custom_layer.visible:
		_refresh_customizer()

func _house_crest_texture(h: Dictionary) -> Texture2D:
	var ci: int = int(h.get("crest", -1))
	var path := str(h.get("crest_file", ""))
	if path == "":
		return null
	_ensure_custom_crest(h)
	if ci >= 0 and ci < CRESTS.size() and CRESTS[ci] != null:
		return CRESTS[ci]
	return null

func _ensure_custom_crest(h: Dictionary) -> void:
	var path := str(h.get("crest_file", ""))
	var ci: int = int(h.get("crest", -1))
	if path == "" or ci < 0:
		return
	if ci < CRESTS.size() and CRESTS[ci] != null:
		return
	if not FileAccess.file_exists(path):
		return
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img == null:
		return
	var tex := ImageTexture.create_from_image(img)
	while CRESTS.size() <= ci:
		CRESTS.append(null)
	CRESTS[ci] = tex
	if map_view != null:
		map_view.set_crest_texture(ci, tex)

func _close_customizer(restore: bool) -> void:
	if custom_layer == null:
		return
	if restore and game != null and not custom_snapshot.is_empty():
		game.houses[game.player] = custom_snapshot.duplicate(true)
	custom_snapshot = {}
	custom_layer.visible = false
	if game != null:
		game.speed = custom_prev_speed
		refresh()

func _field(placeholder: String, fallback: String) -> LineEdit:
	var e := LineEdit.new()
	e.text = placeholder
	e.placeholder_text = fallback
	e.add_theme_stylebox_override("normal", _field_style())
	e.add_theme_stylebox_override("focus", _field_style())
	e.add_theme_color_override("font_color", INK)
	e.add_theme_color_override("caret_color", INK)
	e.add_theme_color_override("font_placeholder_color", Color(0.42, 0.33, 0.22, 0.9))
	e.add_theme_font_size_override("font_size", 15)
	return e

func _stat_name(key: String) -> String:
	match key:
		"martial": return "Kriegskunst"
		"diplomacy": return "Diplomatie"
		"stewardship": return "Verwaltung"
		"intrigue": return "Intrige"
	return key

func _show_newgame() -> void:
	if start_layer == null:
		return
	if newgame_layer != null:
		newgame_layer.visible = true
	if title_status != null:
		title_status.text = ""

func _hide_newgame() -> void:
	if newgame_layer != null:
		newgame_layer.visible = false

func _load_from_title() -> void:
	if not FileAccess.file_exists("user://spielstand.json"):
		if title_status != null:
			title_status.text = "Kein Spielstand gefunden."
		return
	game = GameScript.new(DataScript, 0)
	if _load():
		start_layer.visible = false
		if newgame_layer != null:
			newgame_layer.visible = false
	else:
		if title_status != null:
			title_status.text = "Spielstand konnte nicht geladen werden."

func _quit_game() -> void:
	get_tree().quit()

func _show_start() -> void:
	for c in start_box.get_children():
		c.queue_free()
	var all_houses: Array = DataScript.houses()
	var all_provinces: Array = DataScript.provinces()
	for i in all_houses.size():
		var h: Dictionary = all_houses[i]
		var count := 0
		for p in all_provinces:
			if int(p["owner"]) == i:
				count += 1
		var b := _button("%s  ·  %s  ·  %d Provinzen  ·  %d Gold" % [
			h["name"], h["ruler"]["name"], count, int(h["gold"])
		], Callable(self, "_start").bind(i), "")
		b.custom_minimum_size = Vector2(0, 42)
		if i < CRESTS.size():
			b.icon = CRESTS[i]
			b.add_theme_constant_override("icon_max_width", 26)
		start_box.add_child(b)
	start_layer.visible = true
	if newgame_layer != null:
		newgame_layer.visible = false
	if title_status != null:
		title_status.text = ""

func _show_create() -> void:
	create_layer.visible = true

func _hide_create() -> void:
	create_layer.visible = false

func _adjust(key: String, delta: int) -> void:
	var v: int = int(stat_values[key])
	if delta > 0 and stat_points > 0 and v < 20:
		stat_values[key] = v + 1
		stat_points -= 1
	elif delta < 0 and v > 3:
		stat_values[key] = v - 1
		stat_points += 1
	_update_points()

func _update_points() -> void:
	points_label.text = "Punkte übrig: %d" % stat_points
	for k in stat_labels.keys():
		stat_labels[k].text = str(stat_values[k])

func _create_begin() -> void:
	var ruler: String = edit_ruler.text.strip_edges()
	if ruler == "":
		ruler = "Ari"
	var house_name: String = edit_house.text.strip_edges()
	if house_name == "":
		house_name = "Haus Neu"
	var land: String = edit_land.text.strip_edges()
	var pid: String = str(create_home.get_item_metadata(create_home.selected))
	var cfg := {
		"ruler": ruler, "house": house_name, "land": land,
		"gender": "m" if create_sex.selected == 0 else "f",
		"province": pid, "color": randi_range(0, 8), "crest": randi_range(0, 8),
		"martial": stat_values["martial"], "diplomacy": stat_values["diplomacy"],
		"stewardship": stat_values["stewardship"], "intrigue": stat_values["intrigue"],
	}
	game = GameScript.new(DataScript, 0, cfg)
	selected = ""
	map_view.select("")
	create_layer.visible = false
	start_layer.visible = false
	if newgame_layer != null:
		newgame_layer.visible = false
	pick_layer.visible = false
	tree_layer.visible = false
	rule_layer.visible = false
	if custom_layer != null:
		custom_layer.visible = false
	refresh()

func _start(index: int) -> void:
	game = GameScript.new(DataScript, index)
	selected = ""
	map_view.select("")
	start_layer.visible = false
	if newgame_layer != null:
		newgame_layer.visible = false
	create_layer.visible = false
	pick_layer.visible = false
	tree_layer.visible = false
	rule_layer.visible = false
	if custom_layer != null:
		custom_layer.visible = false
	refresh()

# --- Aktionen ------------------------------------------------------------

func _on_province_selected(id: String) -> void:
	selected = id
	refresh()

func _set_speed(value: int) -> void:
	if game == null:
		return
	game.speed = value
	refresh()

func _do(result: Dictionary) -> void:
	if game == null:
		return
	game.note(str(result["msg"]))
	refresh()

func _bed() -> void:
	if game != null:
		_do(game.bed())

func _open_picker(kind: String) -> void:
	if game == null or game.game_over:
		return
	pick_kind = kind
	pick_title.text = {
		"marry": "Wen heiratest du?",
		"seduce": "Wen verführst du?",
		"murder": "Wen lässt du beseitigen?",
		"kidnap": "Wen lässt du entführen?",
	}.get(kind, "Ziel wählen")
	for c in pick_box.get_children():
		pick_box.remove_child(c)
		c.queue_free()
	for i in game.houses.size():
		if i == game.player:
			continue
		var h: Dictionary = game.houses[i]
		var chance: int = int(round(game.action_chance(kind, i) * 100.0))
		var cost: int = game.action_cost(kind)
		var text := "%s — %s · Haltung %+d · %d%% · %d Gold" % [
			h["name"], h["ruler"]["name"], int(game.opinion[i]), chance, cost
		]
		var b := _button(text, Callable(self, "_pick").bind(kind, i), "")
		if i < CRESTS.size():
			b.icon = CRESTS[i]
			b.add_theme_constant_override("icon_max_width", 24)
		b.disabled = not game.can_action(kind, i)
		pick_box.add_child(b)
	pick_layer.visible = true

func _pick(kind: String, target: int) -> void:
	if game == null:
		return
	game.do_action(kind, target)
	pick_layer.visible = false
	refresh()

func _show_tree() -> void:
	if game == null:
		return
	tree_layer.visible = true
	_refresh_tree()

func _hide_tree() -> void:
	tree_layer.visible = false

func _refresh_tree() -> void:
	if game == null:
		return
	var h: Dictionary = game.house()
	tree_title.text = "Stammbaum — %s" % h["name"]
	tree_view.set_house(game, game.player)
	for c in tree_list.get_children():
		tree_list.remove_child(c)
		c.queue_free()
	tree_list.add_child(_label("Erbfolge", 18, INK))
	var order: Array = game.succession_order(game.player)
	if order.is_empty():
		var empty := _label("Keine Nachkommen. Stirbt der Herrscher, erlischt das Haus.", 12, INK_SOFT)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tree_list.add_child(empty)
	else:
		for i in order.size():
			var child: Dictionary = order[i]
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			if not PORTRAITS.is_empty():
				var mini := TextureRect.new()
				mini.texture = PORTRAITS[int(child.get("portrait", 0)) % PORTRAITS.size()]
				mini.custom_minimum_size = Vector2(38, 48)
				mini.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				mini.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				row.add_child(mini)
			var txt := VBoxContainer.new()
			txt.add_theme_constant_override("separation", 0)
			txt.add_child(_label("%d. %s" % [i + 1, child["name"]], 14, INK))
			txt.add_child(_label("%d Jahre · %s" % [int(child["age"]), "Erbe" if i == 0 else "nachrangig"], 11, INK_SOFT))
			row.add_child(txt)
			tree_list.add_child(row)
	tree_list.add_child(HSeparator.new())
	var spouse: Dictionary = h["spouse"]
	tree_list.add_child(_label("Gemahl/in: %s" % ("unvermählt" if spouse.is_empty() else spouse["name"]), 12, INK_SOFT))
	tree_list.add_child(_label("Herrscher: %s (%d Jahre)" % [h["ruler"]["name"], int(h["ruler"]["age"])], 12, INK_SOFT))
	var succession_law: String = str(game.house()["laws"]["succession"])
	tree_list.add_child(_label("Erbfolgegesetz: %s." % ("Ältester" if succession_law == "eldest" else "Jüngster"), 11, INK_SOFT))

func _save() -> void:
	if game == null:
		return
	var f := FileAccess.open("user://spielstand.json", FileAccess.WRITE)
	if f == null:
		game.note("Speichern fehlgeschlagen.")
		refresh()
		return
	f.store_string(JSON.stringify(game.snapshot()))
	f.close()
	game.note("Spielstand gespeichert.")
	refresh()

func _load() -> bool:
	if game == null:
		return false
	if not FileAccess.file_exists("user://spielstand.json"):
		game.note("Kein Spielstand gefunden.")
		refresh()
		return false
	var f := FileAccess.open("user://spielstand.json", FileAccess.READ)
	if f == null:
		game.note("Laden fehlgeschlagen.")
		refresh()
		return false
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		game.note("Spielstand ist beschädigt.")
		refresh()
		return false
	if not game.restore(parsed):
		refresh()
		return false
	selected = ""
	map_view.select("")
	event_layer.visible = false
	tree_layer.visible = false
	rule_layer.visible = false
	if custom_layer != null:
		custom_layer.visible = false
	start_layer.visible = false
	if newgame_layer != null:
		newgame_layer.visible = false
	game.note("Spielstand geladen.")
	refresh()
	return true

func _choose(index: int) -> void:
	game.apply_event(index)
	event_layer.visible = false
	refresh()

# --- Anzeige -------------------------------------------------------------

func _any_action(kind: String) -> bool:
	for i in game.houses.size():
		if game.can_action(kind, i):
			return true
	return false

func refresh() -> void:
	if game == null:
		return
	var h: Dictionary = game.house()
	_ensure_custom_crest(h)
	map_view.set_game(game)
	date_label.text = game.date_text()
	gold_label.text = "Gold: %d" % int(h["gold"])
	prestige_label.text = "Prestige: %d" % int(h["prestige"])
	for i in speed_buttons.size():
		var b: Button = speed_buttons[i]
		b.modulate = Color(1, 1, 1) if game.speed == i else Color(0.60, 0.60, 0.66)

	var custom_tex := _house_crest_texture(h)
	if custom_tex != null:
		crest_rect.texture = custom_tex
	elif not CRESTS.is_empty():
		crest_rect.texture = CRESTS[posmod(int(h.get("crest", game.player)), CRESTS.size())]
	if not PORTRAITS.is_empty():
		portrait_rect.texture = PORTRAITS[int(h["ruler"]["portrait"]) % PORTRAITS.size()]

	title_label.text = str(h["name"])
	var gender: String = "w" if str(h["ruler"]["gender"]) == "f" else "m"
	var info := "%s\nHerrscher: %s (%s, %d Jahre)\nKrieg %d · Diplomatie %d · Verwaltung %d · Intrige %d\nGrafschaften: %d" % [
		str(h.get("realm", "Hausbesitz")), h["ruler"]["name"], gender, int(h["ruler"]["age"]),
		int(h["ruler"]["martial"]), int(h["ruler"]["diplomacy"]),
		int(h["ruler"]["stewardship"]), int(h["ruler"]["intrigue"]),
		game.owned().size(),
	]
	if selected != "":
		var p: Dictionary = game.province(selected)
		if not p.is_empty():
			var owner_house: Dictionary = game.houses[int(p["owner"])]
			var nb: Array = []
			for n in game.neighbours(selected):
				var q: Dictionary = game.province(n)
				if not q.is_empty():
					nb.append("%s (%s)" % [q["name"], game.houses[int(q["owner"])][ "name"]])
			var capital_txt := "ja" if bool(p.get("capital", false)) else "nein"
			info = "Provinz %s\nLand: %s · %s\nHerzogtum: %s\nBesitzer: %s · Haltung %+d\nHauptstadt: %s · Entwicklung: %d / 10 · Truppen: %d\nNachbarn: %s" % [
				p["name"], p["kingdom_name"], p["empire_name"], p["duchy_name"],
				owner_house["name"], int(game.opinion[int(p["owner"])]),
				capital_txt, int(p["dev"]), int(p["levy"]), ", ".join(nb),
			]
	info_label.text = info

	var spouse: Dictionary = h["spouse"]
	var spouse_txt := "unvermählt"
	if not spouse.is_empty():
		spouse_txt = "%s (%d, %s)" % [spouse["name"], int(spouse["age"]), "w" if str(spouse["gender"]) == "f" else "m"]
	var heir_txt := "keiner"
	if str(h["heir"]) != "":
		heir_txt = "%s (%d)" % [h["heir"], int(h["heir_age"])]
	var lover_txt := "—"
	if int(h["lover_house"]) >= 0 and int(h["lover_house"]) < game.houses.size():
		lover_txt = str(game.houses[int(h["lover_house"])]["name"])
	var capt_txt := "—"
	if not game.captive.is_empty():
		capt_txt = "%s (noch %d Monate)" % [game.captive["name"], int(game.captive["months"])]
	family_label.text = "Gemahl/in: %s\nErbe: %s · Kinder: %d\nGeliebte/r: %s · Gefangene/r: %s\nGold %d · Prestige %d · Legitimität %d" % [
		spouse_txt, heir_txt, h["children"].size(), lover_txt, capt_txt,
		int(h["gold"]), int(h["prestige"]), int(h["legitimacy"]),
	]
	if selected == "":
		hint_label.text = "Tippe auf eine Grafschaft, um sie auszuwählen."
	else:
		var p2: Dictionary = game.province(selected)
		if p2.is_empty():
			hint_label.text = ""
		elif int(p2["owner"]) == game.player:
			hint_label.text = "Eigenes Land: ausbauen oder Truppen werben."
		else:
			hint_label.text = "Feindliches Land: angreifen, wenn es an dein Gebiet grenzt."

	develop_btn.disabled = not game.can_develop(selected)
	recruit_btn.disabled = not game.can_recruit(selected)
	attack_btn.disabled = not game.can_attack(selected)
	court_btn.disabled = not game.can_court()
	marry_btn.disabled = not _any_action("marry")
	seduce_btn.disabled = not _any_action("seduce")
	murder_btn.disabled = not _any_action("murder")
	kidnap_btn.disabled = not _any_action("kidnap")
	bed_btn.disabled = not game.can_bed()
	ransom_btn.visible = not game.captive.is_empty()
	force_btn.visible = not game.captive.is_empty()
	ransom_btn.disabled = not game.can_ransom()
	force_btn.disabled = not game.can_force_marry()

	log_label.text = "\n".join(game.log_lines)
	if game.pending_event != null and not event_layer.visible:
		_show_event()
	if tree_layer.visible:
		_refresh_tree()
	if rule_layer != null and rule_layer.visible:
		_refresh_rule()
	over_layer.visible = game.game_over

func _build_rule_layer() -> void:
	rule_layer = Control.new()
	rule_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rule_layer.visible = false
	rule_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(rule_layer)
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.02, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	rule_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rule_layer.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(720, 0)
	card.add_theme_stylebox_override("panel", _card_style(14))
	center.add_child(card)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(680, 0)
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	box.add_child(head)
	rule_title = _label("Herrschaft", 24, INK)
	rule_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(rule_title)
	var close := _button("Schließen", _hide_rule, "")
	close.custom_minimum_size = Vector2(120, 38)
	head.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 520)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	rule_body = VBoxContainer.new()
	rule_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule_body.add_theme_constant_override("separation", 6)
	scroll.add_child(rule_body)

func _show_rule() -> void:
	if game == null:
		return
	rule_layer.visible = true
	_refresh_rule()

func _hide_rule() -> void:
	if rule_layer != null:
		rule_layer.visible = false

func _clear_rule_body() -> void:
	for child in rule_body.get_children():
		rule_body.remove_child(child)
		child.queue_free()

func _refresh_rule() -> void:
	if game == null or rule_body == null:
		return
	_clear_rule_body()
	var h: Dictionary = game.house()
	rule_title.text = "Herrschaft — %s" % str(h["name"])
	rule_body.add_child(_label("Legitimität %d/100 · Prestige %d · Gold %d" % [
		int(h["legitimacy"]), int(h["prestige"]), int(h["gold"])
	], 13, INK_SOFT))
	rule_body.add_child(_label("Rat", 18, INK))
	var offices := [["marshal", "Marschall", "martial"], ["chancellor", "Kanzler", "diplomacy"], ["steward", "Verwalter", "stewardship"]]
	for office in offices:
		var member: Dictionary = game.council_member(game.player, str(office[0]))
		var member_text := "unbesetzt"
		if not member.is_empty():
			member_text = "%s · %s %d" % [member["name"], office[2], int(member[str(office[2])])]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var row_label := _label("%s: %s" % [office[1], member_text], 13, INK_SOFT)
		row_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(row_label)
		var change := _button("Wechseln", Callable(self, "_cycle_council").bind(str(office[0])), "")
		change.custom_minimum_size = Vector2(110, 36)
		row.add_child(change)
		rule_body.add_child(row)
	rule_body.add_child(_label("Marschallstraining: +%d Truppen pro Jahr (Martial und Legitimität zählen)." % game.council_training_amount(game.player), 11, INK_SOFT))
	rule_body.add_child(HSeparator.new())
	rule_body.add_child(_label("Gesetz", 18, INK))
	var law: String = str(h["laws"]["succession"])
	var law_button := _button("Erbfolge: %s" % ("Ältester" if law == "eldest" else "Jüngster"), _toggle_succession, "")
	rule_body.add_child(law_button)
	rule_body.add_child(_label("Erbe: %s" % (str(h["heir"]) if str(h["heir"]) != "" else "keiner"), 12, INK_SOFT))
	rule_body.add_child(HSeparator.new())
	rule_body.add_child(_label("Bauen", 18, INK))
	var p: Dictionary = {}
	if selected != "":
		p = game.province(selected)
	if p.is_empty():
		rule_body.add_child(_label("Wähle auf der Karte eine eigene Provinz.", 12, INK_SOFT))
	else:
		rule_body.add_child(_label("%s · Truppen %d" % [p["name"], int(p["levy"])], 12, INK_SOFT))
		for entry in [["barracks", "Kaserne"], ["walls", "Mauern"]]:
			var key: String = str(entry[0])
			var level: int = int((p.get("buildings", {}) as Dictionary).get(key, 0))
			var cost: int = game.building_cost(key)
			var button := _button("%s: Stufe %d/3 · %d Gold" % [entry[1], level, cost], Callable(self, "_build_system").bind(key), "")
			button.disabled = not game.can_build(selected, key)
			rule_body.add_child(button)

func _cycle_council(office: String) -> void:
	var h: Dictionary = game.house()
	var courtiers: Array = h.get("courtiers", [])
	if courtiers.is_empty():
		return
	var current: int = int(h["council"].get(office, 0))
	var result: Dictionary = game.assign_council(office, (current + 1) % courtiers.size())
	game.note(str(result["msg"]))
	refresh()

func _toggle_succession() -> void:
	var current: String = str(game.house()["laws"]["succession"])
	var result: Dictionary = game.set_law("succession", "youngest" if current == "eldest" else "eldest")
	game.note(str(result["msg"]))
	refresh()

func _build_system(key: String) -> void:
	if selected == "":
		return
	var result: Dictionary = game.build(selected, key)
	game.note(str(result["msg"]))
	refresh()

func _show_event() -> void:
	var ev: Dictionary = game.pending_event
	event_title.text = str(ev["title"])
	event_text.text = str(ev["text"])
	for c in event_buttons.get_children():
		c.queue_free()
	var options: Array = ev["options"]
	for i in options.size():
		var opt: Dictionary = options[i]
		event_buttons.add_child(_button(str(opt["label"]), Callable(self, "_choose").bind(i), ""))
	event_layer.visible = true

# --- Zeitlauf ------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if rule_layer != null and rule_layer.visible:
			_hide_rule()
			get_viewport().set_input_as_handled()
			return
		if custom_layer != null and custom_layer.visible:
			_custom_cancel()
			get_viewport().set_input_as_handled()
			return
		if create_layer != null and create_layer.visible:
			_hide_create()
			get_viewport().set_input_as_handled()
			return
		if newgame_layer != null and newgame_layer.visible:
			_hide_newgame()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and event.keycode == KEY_F11:
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _process(delta: float) -> void:
	if game == null or game.game_over or game.pending_event != null:
		return
	if game.speed <= 0:
		return
	accum += delta
	var interval: float = [0.0, 1.4, 0.8, 0.35][clampi(game.speed, 0, 3)]
	if accum >= interval:
		accum = 0.0
		game.advance_month()
		refresh()
