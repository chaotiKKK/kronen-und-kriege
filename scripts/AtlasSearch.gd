extends VBoxContainer
## Deutsche Ortsuche für den eingebetteten Referenzatlas, ohne Netzwerkzugriff.
const KIND_NAMES := {"country": "Land", "region": "Region", "district": "Kreis", "municipality": "Gemeinde", "city": "Ort"}
var search_field: LineEdit
var results_box: VBoxContainer
var _map
var _main
var _results: Array = []
var _status: Label
var _results_panel: PanelContainer
var _results_scroll: ScrollContainer
var _sources_panel: PanelContainer
var _sources_scroll: ScrollContainer
var _sources_content: VBoxContainer

func configure(map_view, main) -> void:
	_map = map_view
	_main = main
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 5)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	search_field = main._field("", "Ort oder Region suchen …")
	search_field.name = "AtlasOrtssuche"
	search_field.accessibility_name = "Ort oder Region suchen"
	search_field.tooltip_text = "Heutige Orte, Bundesländer, Kreise und Gemeinden im Offline-Atlas suchen."
	search_field.custom_minimum_size = Vector2(0, 44)
	search_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_field.text_changed.connect(_search_changed)
	search_field.text_submitted.connect(_submit)
	search_field.gui_input.connect(_search_input)
	row.add_child(search_field)
	var sources: Button = main._button("Quellen", _toggle_sources)
	sources.custom_minimum_size = Vector2(96, 44)
	sources.accessibility_name = "Quellen und Lizenzen des Referenzatlas anzeigen"
	row.add_child(sources)
	var reference: Label = main._label("Referenzatlas · heutige Orts- und Verwaltungsnamen", 13)
	reference.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(reference)
	results_box = VBoxContainer.new()
	results_box.name = "AtlasSuchtreffer"
	results_box.add_theme_constant_override("separation", 4)
	results_box.visible = false
	_results_panel = _floating_panel()
	_results_scroll = _scroll_container()
	_results_panel.add_child(_results_scroll)
	_results_scroll.add_child(results_box)
	results_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	results_box.minimum_size_changed.connect(_fit_results, Object.CONNECT_DEFERRED)
	_status = main._label("", 13)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.visible = false
	add_child(_status)
	_build_sources()
	resized.connect(_fit_popups)

func _search_changed(query: String) -> void:
	_clear_results()
	_status.visible = false
	_sources_panel.visible = false
	if query.strip_edges().is_empty():
		return
	if _map == null or _map.atlas_data == null:
		_status.text = "Die eingebetteten Atlasdaten sind nicht verfügbar."
		_status.visible = true
		return
	_results = _map.atlas_data.search(query, 6)
	for record in _results:
		var kind := str(record.get("kind", "city"))
		var category := str(KIND_NAMES.get(kind, "Ort"))
		if kind == "region" and str(record.get("country", "")) == "DE":
			category = "Bundesland"
		var title := "%s · %s" % [str(record.get("name", "")), category]
		var button: Button = _main._button(title, _choose.bind(record))
		button.custom_minimum_size = Vector2(0, 44)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.clip_text = true
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.tooltip_text = title
		button.accessibility_name = "%s auf der Karte anzeigen" % title
		button.set_meta("atlas_font_size", 14)
		button.add_theme_font_size_override("font_size", int(round(14.0 * float(_main.ModernInterfaceScript.text_scale))))
		results_box.add_child(button)
	results_box.visible = not _results.is_empty()
	_results_panel.visible = results_box.visible
	_fit_results()
	call_deferred("_fit_results")
	if _results.is_empty():
		_status.text = "Kein Ort gefunden. Bitte den Namen genauer eingeben."
		_status.visible = true

func _process(_delta: float) -> void:
	if _main != null and (_results_panel.visible or _sources_panel.visible) and _main.kernel.top_modal() != "game":
		_clear_query()
		_sources_panel.visible = false

func _submit(_query: String) -> void:
	if not _results.is_empty():
		_choose(_results[0])

func _choose(record: Dictionary) -> void:
	_map.focus_atlas_location(record)
	_clear_query()
	search_field.release_focus()
	_sources_panel.visible = false

func _clear_query() -> void:
	search_field.text = ""
	_clear_results()
	_status.visible = false

func _clear_results() -> void:
	_results = []
	for child in results_box.get_children():
		results_box.remove_child(child)
		child.queue_free()
	results_box.visible = false
	_results_panel.visible = false

func _search_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_clear_query()
		_sources_panel.visible = false
		search_field.release_focus()
		search_field.accept_event()

func _toggle_sources() -> void:
	_clear_results()
	_sources_panel.visible = not _sources_panel.visible
	_fit_sources()
	call_deferred("_fit_sources")

func _build_sources() -> void:
	_sources_panel = _floating_panel()
	_sources_scroll = _scroll_container()
	_sources_panel.add_child(_sources_scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sources_scroll.add_child(box)
	_sources_content = box
	box.minimum_size_changed.connect(_fit_sources, Object.CONNECT_DEFERRED)
	for text in [
		"Quellen des heutigen Referenzatlas",
		"Natural Earth · Public Domain · naturalearthdata.com/about/terms-of-use/",
		"Verwaltungsgrenzen: © BKG (2026) · Datenstand 01.01.2025 · dl-de/by-2-0 · govdata.de/dl-de/by-2-0",
		"Ortsdaten: GeoNames · CC BY 4.0 · geonames.org · creativecommons.org/licenses/by/4.0/",
		"Kartenausschnitt, Projektion, Vereinfachung und deutsche Ortsnamen wurden für das Spiel aufbereitet. Heutige Verwaltungsgrenzen sind keine historischen Herrschaftsgrenzen."
	]:
		var label: Label = _main._label(text, 13)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(label)
	var close: Button = _main._button("Quellen schließen", _toggle_sources)
	close.custom_minimum_size.y = 44
	box.add_child(close)

func _floating_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _main._card_style(12))
	panel.visible = false
	panel.set_as_top_level(true)
	panel.z_index = 30
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	add_child(panel)
	return panel

func _scroll_container() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	return scroll

func _fit_popups() -> void:
	_fit_results()
	_fit_sources()

func _fit_results() -> void:
	if _results_panel != null and _results_panel.visible:
		_fit_popup(_results_panel, _results_scroll, results_box, 220.0)

func _fit_sources() -> void:
	if _sources_panel != null and _sources_panel.visible:
		_fit_popup(_sources_panel, _sources_scroll, _sources_content, get_viewport_rect().size.y - 32.0)

func _fit_popup(panel: PanelContainer, scroll: ScrollContainer, content: VBoxContainer, maximum_height: float) -> void:
	var viewport := get_viewport_rect()
	var popup_width := minf(maxf(260.0, size.x), viewport.size.x - 24.0)
	var below := get_global_rect().end.y + 5.0
	var space_below := maxf(80.0, viewport.end.y - below - 12.0)
	var space_above := maxf(80.0, global_position.y - viewport.position.y - 12.0)
	var content_height: float = content.get_combined_minimum_size().y
	var desired_height := minf(content_height + 24.0, maximum_height)
	var open_above := space_above > space_below and desired_height > space_below
	var available := space_above if open_above else space_below
	var popup_height := minf(desired_height, available)
	scroll.custom_minimum_size = Vector2(0, maxf(40.0, popup_height - 24.0))
	panel.custom_minimum_size = Vector2(popup_width, 0)
	panel.size = Vector2(popup_width, popup_height)
	var popup_x := clampf(global_position.x, viewport.position.x + 12.0, viewport.end.x - popup_width - 12.0)
	var popup_y := global_position.y - popup_height - 5.0 if open_above else below
	panel.position = Vector2(popup_x, clampf(popup_y, viewport.position.y + 8.0, viewport.end.y - popup_height - 8.0))
