extends RefCounted
## Präsentation des vorhandenen Spiels. Enthält keine Spielregeln.
const BG := Color("101e2b")
const PANEL := Color("1a3042")
const TEXT := Color("edf3f5")
const MUTED := Color("afbfca")
const COPPER := Color("d4a875")
const SEA := Color("78c6bd")
static var appearance := 0
static var text_scale := 1.0

var main
var navigation: ScrollContainer
var section_buttons: Dictionary = {}
var pages: Dictionary = {}
var layout_row: HBoxContainer
var map_wrap: Control
var sidebar_tabs: GridContainer
var current_section := "overview"
var last_width := -1.0
var dialogs: Array = []

static func surface(color: Color = PANEL, margin: int = 16) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.set_meta("atlas_bg", color)
	box.bg_color = _surface_color(color)
	box.border_color = Color("365064")
	box.set_border_width_all(1)
	box.set_corner_radius_all(7)
	box.content_margin_left = margin
	box.content_margin_right = margin
	box.content_margin_top = margin
	box.content_margin_bottom = margin
	return box

static func readable(color: Color) -> Color:
	if appearance == 1:
		return Color.WHITE
	if appearance == 2:
		return Color("152b39")
	if color.get_luminance() >= 0.5:
		return color
	if color.g > color.r * 1.5:
		return Color("85d9b0")
	if color.r > color.g * 1.65 and color.r > 0.3:
		return Color("ef9c92")
	return MUTED

static func _surface_color(color: Color) -> Color:
	if color.a == 0:
		return color
	if appearance == 1:
		return Color(0.015, 0.025, 0.035, color.a)
	if appearance == 2:
		return Color(0.92, 0.95, 0.96, color.a)
	return color

static func effect_markup(source: String) -> String:
	var positive := "#85d9b0"
	var negative := "#f29d96"
	var neutral := "#e7c774"
	if appearance == 1:
		positive = "#a0f2aa"
		negative = "#ffb4ab"
		neutral = "#ffe58b"
	elif appearance == 2:
		positive = "#21613c"
		negative = "#9e2832"
		neutral = "#78590d"
	return source.replace("#1c6b2f", positive).replace("#9c2f24", negative).replace("#d8c9a6", neutral).replace("[b]", "").replace("[/b]", "")

func install(host) -> void:
	main = host
	main.set_meta("modern_interface", self)
	for child in main.get_children():
		if child is ColorRect and child.has_meta("atlas_background"):
			child.color = BG
	_rebuild_header()
	_rebuild_map_tools()
	_rebuild_sidebar()
	_rebuild_menu()
	_prepare_dialogs(main)
	main.resized.connect(fit_layout)
	fit_layout()
	set_appearance(int(main.settings.get("ui_theme", 0)))
	set_text_scale(float(main.settings.get("text_scale", 1.0)))

func set_text_scale(value: float) -> void:
	text_scale = clampf(value, 1.0, 2.0)
	main.settings["text_scale"] = text_scale
	_scale_text(main)
	_fit_dialogs()

func _scale_text(node: Node) -> void:
	if node is Label or node is Button or node is LineEdit:
		var control := node as Control
		var base: int = int(control.get_meta("atlas_font_size", control.get_theme_font_size("font_size")))
		control.set_meta("atlas_font_size", base)
		if not is_equal_approx(float(control.get_meta("atlas_applied_scale", -1.0)), text_scale):
			control.add_theme_font_size_override("font_size", int(round(base * text_scale)))
			control.set_meta("atlas_applied_scale", text_scale)
	elif node is RichTextLabel and node.has_meta("atlas_effect_source"):
		node.add_theme_font_size_override("normal_font_size", int(round(14 * text_scale)))
		node.add_theme_font_size_override("bold_font_size", int(round(14 * text_scale)))
	for child in node.get_children():
		_scale_text(child)
	if node is Button and node.has_meta("rich_choice"):
		# Verkleinern sofort übernehmen, bevor verschachtelte Container neu sortieren.
		node.custom_minimum_size.y = 64 * text_scale
		node.size.y = node.custom_minimum_size.y

func _prepare_dialogs(node: Node) -> void:
	# ScrollContainer begrenzt die Inhaltsgröße, ohne alte Dialoglogik zu ersetzen.
	for child in node.get_children():
		_prepare_dialogs(child)
	if not (node is CenterContainer):
		return
	for card in node.get_children():
		if not (card is PanelContainer) or card.get_child_count() != 1 or not (card.get_child(0) is VBoxContainer):
			continue
		var content: Control = card.get_child(0)
		var width: float = maxf(400.0, card.custom_minimum_size.x)
		card.remove_child(content)
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		card.add_child(scroll)
		scroll.add_child(content)
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.minimum_size_changed.connect(_fit_dialogs, Object.CONNECT_DEFERRED)
		dialogs.append({"card": card, "scroll": scroll, "content": content, "width": width})

func _fit_dialogs() -> void:
	var viewport: Vector2 = main.get_viewport_rect().size
	for dialog in dialogs:
		var max_height := maxf(160.0, viewport.y - 100)
		dialog.card.custom_minimum_size = Vector2(minf(float(dialog.width), viewport.x - 64), 0)
		dialog.scroll.custom_minimum_size = Vector2(0, minf(dialog.content.get_combined_minimum_size().y, max_height))

func set_appearance(index: int) -> void:
	appearance = clampi(index, 0, 2)
	main.settings["ui_theme"] = appearance
	_recolor(main)
	for child in main.get_children():
		if child is ColorRect and child.has_meta("atlas_background"):
			child.color = _surface_color(BG)

func _recolor(node: Node) -> void:
	if node is Control:
		var control := node as Control
		if control is Label or control is Button or control is LineEdit:
			var original: Color = control.get_meta("atlas_color", control.get_theme_color("font_color"))
			control.set_meta("atlas_color", original)
			control.add_theme_color_override("font_color", readable(original))
			if control is Button:
				control.add_theme_color_override("font_disabled_color", readable(MUTED))
				control.add_theme_color_override("font_pressed_color", readable(original))
				control.add_theme_color_override("font_hover_color", readable(original))
				control.add_theme_color_override("font_focus_color", readable(original))
				if control.has_meta("rich_choice"):
					for role in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
						control.add_theme_color_override(role, Color.TRANSPARENT)
		if control is RichTextLabel and control.has_meta("atlas_effect_source"):
			control.text = "[center]" + effect_markup(str(control.get_meta("atlas_effect_source"))) + "[/center]"
		for style_name in ["panel", "normal", "hover", "pressed", "disabled", "focus"]:
			if not control.has_theme_stylebox_override(style_name):
				continue
			var style = control.get_theme_stylebox(style_name)
			if style is StyleBoxFlat:
				var copy: StyleBoxFlat = style.duplicate()
				copy.bg_color = _surface_color(copy.get_meta("atlas_bg", copy.bg_color))
				if appearance == 1:
					copy.border_color = Color("afbfca")
				elif appearance == 2:
					copy.border_color = Color("708897")
				control.add_theme_stylebox_override(style_name, copy)
	for child in node.get_children():
		_recolor(child)

func _rebuild_header() -> void:
	var old_row: HBoxContainer = main.top_crest.get_parent().get_parent()
	var panel: PanelContainer = old_row.get_parent()
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	panel.remove_child(old_row)
	panel.add_child(rows)
	panel.add_theme_stylebox_override("panel", surface(BG, 12))
	panel.custom_minimum_size.y = 116
	var identity := HBoxContainer.new()
	identity.add_theme_constant_override("separation", 16)
	var identity_scroll := ScrollContainer.new()
	identity_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	identity_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	rows.add_child(identity_scroll)
	identity_scroll.add_child(identity)
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_block: Control = main.top_crest.get_parent()
	name_block.reparent(identity)
	var date: Control = main.date_label.get_parent()
	date.reparent(identity)
	main.date_label.add_theme_font_size_override("font_size", 18)
	identity.add_child(main._spacer())
	for node in old_row.get_children():
		if node is Button and not main.speed_buttons.has(node):
			node.reparent(identity)
			_style_tool(node)
	var economy := HBoxContainer.new()
	economy.add_theme_constant_override("separation", 12)
	var economy_scroll := ScrollContainer.new()
	economy_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	economy_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	rows.add_child(economy_scroll)
	economy_scroll.add_child(economy)
	economy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var resources: Control = main.gold_label.get_parent()
	resources.reparent(economy)
	economy.add_child(main._spacer())
	for button in main.speed_buttons:
		button.reparent(economy)
		_style_tool(button)
		button.custom_minimum_size = Vector2(54, 44)
	old_row.queue_free()
	main.top_world_label.add_theme_font_size_override("font_size", 11)
	main.top_realm_label.add_theme_font_size_override("font_size", 21)
	main.top_world_label.add_theme_color_override("font_color", SEA)
	main.gold_label.add_theme_font_size_override("font_size", 16)
	main.prestige_label.add_theme_font_size_override("font_size", 16)
	main.renown_label.add_theme_font_size_override("font_size", 16)

func _rebuild_map_tools() -> void:
	map_wrap = main.map_view.get_parent()
	var column: VBoxContainer = map_wrap.get_parent()
	layout_row = column.get_parent()
	map_wrap.custom_minimum_size = Vector2(160, 160)
	var modes: HBoxContainer = main.map_mode_buttons["political"].get_parent()
	var old_panel: Control = modes.get_parent()
	navigation = ScrollContainer.new()
	navigation.name = "Kartennavigation"
	navigation.custom_minimum_size.y = 62
	navigation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	navigation.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	navigation.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	column.add_child(navigation)
	column.move_child(navigation, 0)
	modes.reparent(navigation)
	modes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modes.add_theme_constant_override("separation", 6)
	for child in modes.get_children():
		if child is Button:
			_style_tool(child)
			child.custom_minimum_size = Vector2(78, 48)
			child.add_theme_font_size_override("font_size", 13)
		elif child is Label:
			child.text = "KARTE  "
			child.add_theme_font_size_override("font_size", 11)
	old_panel.queue_free()
	# Informations-/Zoomzeile wird ebenfalls reserviert, statt die Karte zu verdecken.
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	column.add_child(tools)
	column.move_child(tools, 1)
	var header: Control = main.map_header_title.get_parent().get_parent()
	header.reparent(tools)
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.custom_minimum_size = Vector2(0, 64)
	main.map_header_meta.add_theme_font_size_override("font_size", 12)
	var zoom: HBoxContainer = main.side_toggle_btn.get_parent()
	zoom.reparent(tools)
	zoom.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	for button in zoom.get_children():
		if button is Button:
			_style_tool(button)
			button.custom_minimum_size = Vector2(44, 48)
	var ticker: Control = main.log_label.get_parent()
	ticker.reparent(column)
	ticker.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	ticker.custom_minimum_size = Vector2(0, 38)
	main.log_label.add_theme_font_size_override("font_size", 12)
	main.minimap.custom_minimum_size = Vector2.ZERO
	main.minimap.offset_left = -176
	main.minimap.offset_top = -116
	main.minimap.offset_right = -12
	main.minimap.offset_bottom = -12

func _style_tool(button: Button) -> void:
	button.custom_minimum_size.y = 48
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_disabled_color", MUTED)
	button.add_theme_stylebox_override("normal", surface(Color("182d3c"), 9))
	button.add_theme_stylebox_override("hover", surface(Color("294856"), 9))
	var selected := surface(Color("26565a"), 9)
	selected.border_color = SEA
	button.add_theme_stylebox_override("pressed", selected)
	var focus := surface(Color(0, 0, 0, 0), 9)
	focus.border_color = COPPER
	focus.set_border_width_all(2)
	button.add_theme_stylebox_override("focus", focus)

func _rebuild_sidebar() -> void:
	var scroll: ScrollContainer = main.side_panel.get_child(0)
	var old_box: VBoxContainer = scroll.get_child(0)
	var children := old_box.get_children()
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 14)
	main.side_panel.remove_child(scroll)
	main.side_panel.add_child(outer)
	var portrait_header: Control = main.crest_rect.get_parent()
	portrait_header.reparent(outer)
	main.portrait_rect.custom_minimum_size = Vector2(68, 84)
	main.crest_rect.custom_minimum_size = Vector2(40, 48)
	main.title_label.add_theme_font_size_override("font_size", 22)
	main.info_label.add_theme_font_size_override("font_size", 13)
	sidebar_tabs = GridContainer.new()
	sidebar_tabs.columns = 4
	sidebar_tabs.add_theme_constant_override("h_separation", 4)
	outer.add_child(sidebar_tabs)
	var group := ButtonGroup.new()
	for entry in [["overview", "Übersicht"], ["politics", "Politik"], ["family", "Familie"], ["world", "Welt"]]:
		var id := str(entry[0])
		var button: Button = main._button(str(entry[1]), show_section.bind(id))
		button.add_theme_font_size_override("font_size", 12)
		button.custom_minimum_size.x = 0
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.button_group = group
		_style_tool(button)
		section_buttons[id] = button
		sidebar_tabs.add_child(button)
		var page := VBoxContainer.new()
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page.add_theme_constant_override("separation", 10)
		old_box.add_child(page)
		pages[id] = page
	outer.add_child(scroll)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for child in children:
		if child == portrait_header:
			continue
		var section := "overview"
		if child == main.family_label or child in [main.marry_btn, main.bed_btn, main.seduce_btn, main.murder_btn, main.kidnap_btn, main.ransom_btn, main.force_btn]:
			section = "family"
		elif child is Button:
			var text := str(child.text)
			if text.contains("Stammbaum"):
				section = "family"
			elif text.contains("Hof") or text.contains("Glaube") or text == "Herrschaft":
				section = "politics"
			elif text.contains("speichern") or text.contains("laden") or text.contains("Forschung"):
				section = "world"
		elif child is HSeparator or (child is Label and child != main.hint_label):
			old_box.remove_child(child)
			child.queue_free()
			continue
		child.reparent(pages[section])
	main.side_panel.add_theme_stylebox_override("panel", surface(PANEL, 16))
	show_section("overview")

func show_section(id: String) -> void:
	if not pages.has(id):
		return
	current_section = id
	for key in pages:
		pages[key].visible = key == id
		section_buttons[key].set_pressed_no_signal(key == id)

func _rebuild_menu() -> void:
	for child in main.start_layer.get_children():
		main.start_layer.remove_child(child)
		child.queue_free()
	var art := TextureRect.new()
	art.texture = main.TEX_TITLE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main.start_layer.add_child(art)
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.08, 0.12, 0.24)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main.start_layer.add_child(shade)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.54
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.add_theme_stylebox_override("panel", surface(Color(0.063, 0.118, 0.169, 1.0), 34))
	main.start_layer.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 12)
	scroll.add_child(box)
	box.add_child(main._label("D Y N A S T I E N  ·  M A C H T  ·  W A N D E L", 11, SEA))
	var brand: Label = main._label("Banger\nQueens", 62, TEXT)
	var display := SystemFont.new()
	display.font_names = PackedStringArray(["Georgia", "Noto Serif", "serif"])
	brand.add_theme_font_override("font", display)
	box.add_child(brand)
	var subtitle: Label = main._label("Eine Welt. Dein Vermächtnis.", 20, COPPER)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(subtitle)
	var timeline := PanelContainer.new()
	timeline.add_theme_stylebox_override("panel", surface(Color("20394a"), 14))
	box.add_child(timeline)
	var period: Label = main._label("2000 v. Chr.    —    2200 n. Chr.\n4200 Jahre alternative Geschichte", 14, MUTED)
	period.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	timeline.add_child(period)
	for entry in [["Neues Spiel", main._show_newgame], ["Spiel laden", main._load_from_title], ["Optionen", main._show_options], ["Beenden", main._quit_game]]:
		var button: Button = main._button(str(entry[0]), entry[1])
		button.custom_minimum_size.y = 56
		button.add_theme_font_size_override("font_size", 18)
		_style_tool(button)
		if str(entry[0]) == "Neues Spiel":
			var primary := surface(Color("3c6e6d"), 14)
			primary.border_color = SEA
			button.add_theme_stylebox_override("normal", primary)
		box.add_child(button)
	main.title_status = main._label("", 12, COPPER)
	main.title_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(main.title_status)
	box.add_child(main._label("VERSION %s    ·    DEUTSCH    ·    OFFLINE" % ProjectSettings.get_setting("application/config/version"), 11, MUTED))

func refresh_summary() -> void:
	if main.game == null:
		return
	var h: Dictionary = main.game.house()
	main.title_label.text = str(h.name)
	main.info_label.text = "%s · %d Jahre\n%d Grafschaften · Legitimität %d" % [h.ruler.name, h.ruler.age, main.game.owned().size(), h.legitimacy]
	main.family_label.text = "Familie & Nachfolge\nGemahl/in: %s\nErbe: %s · Kinder: %d" % [h.spouse.get("name", "unvermählt"), str(h.heir) if str(h.heir) != "" else "keiner", h.children.size()]
	_scale_text(main)
	_fit_dialogs()
	fit_layout()

func fit_layout() -> void:
	if main == null or navigation == null:
		return
	var width: float = main.get_viewport_rect().size.x
	_fit_dialogs()
	if is_equal_approx(width, last_width):
		return
	last_width = width
	main.side_panel.custom_minimum_size.x = clampf(width * 0.29, 300.0, 400.0)
	sidebar_tabs.columns = 4 if width >= 1100 else 2
	navigation.custom_minimum_size.x = 0
