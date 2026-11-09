extends VBoxContainer
## Deutsche Ortsuche für den eingebetteten Referenzatlas, ohne Netzwerkzugriff.
const KIND_NAMES := {"country": "Land / Gebiet", "region": "Region", "district": "Kreis / Verwaltungsbezirk", "municipality": "Gemeinde", "local_admin": "Ortsverwaltung", "city": "Ort"}
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
var _sources_layout: VBoxContainer
var _sources_title: Label
var _sources_close: Button
var _sources_action: Button

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
	_sources_action = sources
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
		if str(record.get("country", "")) == "DE" and str(record.get("unit_type", "")) == "Gemeindefreies Gebiet":
			category = "Gemeindefreies Gebiet"
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
	if _sources_panel.visible:
		_close_sources()
		return
	_refresh_sources()
	search_field.release_focus()
	_sources_panel.visible = true
	_fit_sources()
	call_deferred("_fit_sources")
	_sources_close.grab_focus()

func _close_sources() -> void:
	_sources_panel.visible = false
	if _sources_action != null and _sources_action.is_visible_in_tree():
		_sources_action.grab_focus()

func _unhandled_key_input(event: InputEvent) -> void:
	if _sources_panel != null and _sources_panel.visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close_sources()
		get_viewport().set_input_as_handled()

func _build_sources() -> void:
	_sources_panel = _floating_panel()
	_sources_panel.accessibility_name = "Quellen und Lizenzen des Referenzatlas"
	_sources_layout = VBoxContainer.new()
	_sources_layout.add_theme_constant_override("separation", 10)
	_sources_panel.add_child(_sources_layout)
	_sources_title = _main._label("Quellen und Lizenzen", 15)
	_sources_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sources_layout.add_child(_sources_title)
	_sources_scroll = _scroll_container()
	_sources_scroll.name = "AtlasQuellenRollbereich"
	_sources_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sources_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sources_scroll.follow_focus = true
	_sources_layout.add_child(_sources_scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sources_scroll.add_child(box)
	_sources_content = box
	box.minimum_size_changed.connect(_fit_sources, Object.CONNECT_DEFERRED)
	_sources_layout.minimum_size_changed.connect(_fit_sources, Object.CONNECT_DEFERRED)
	_sources_close = _main._button("Quellen schließen", _close_sources)
	_sources_close.name = "AtlasQuellenSchliessen"
	_sources_close.accessibility_name = "Quellenfenster schließen"
	_sources_close.set_meta("atlas_font_size", 14)
	_sources_close.add_theme_font_size_override("font_size", int(round(14.0 * float(_main.ModernInterfaceScript.text_scale))))
	_sources_close.custom_minimum_size.y = 48
	_sources_layout.add_child(_sources_close)
	_refresh_sources()

func _refresh_sources() -> void:
	for child in _sources_content.get_children():
		_sources_content.remove_child(child)
		child.queue_free()
	var available_sources: Array = []
	if _map != null and _map.atlas_data != null:
		available_sources = _map.atlas_data.sources
	var count := 0
	var coverage: Label = _main._label(_coverage_text(), 13)
	coverage.name = "AtlasLandabdeckung"
	coverage.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	coverage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sources_content.add_child(coverage)
	_sources_content.add_child(HSeparator.new())
	for raw in available_sources:
		if not (raw is Dictionary):
			continue
		if count > 0:
			_sources_content.add_child(HSeparator.new())
		var label: Label = _main._label(_source_text(raw), 13)
		label.name = "AtlasQuelle%d" % count
		label.set_meta("atlas_source_id", str(raw.get("id", "")))
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_sources_content.add_child(label)
		count += 1
	_sources_title.text = "Quellen und Lizenzen · %d Datensätze" % count
	if count == 0:
		var missing: Label = _main._label("Zurzeit sind keine Quelleninformationen verfügbar.", 13)
		missing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_sources_content.add_child(missing)
	var note: Label = _main._label("Kartenausschnitt, Projektion, Vereinfachung und deutsche Ortsnamen wurden für das Spiel aufbereitet. Heutige Verwaltungsgrenzen sind keine historischen Herrschaftsgrenzen.", 13)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sources_content.add_child(note)
	_sources_scroll.scroll_vertical = 0

func _coverage_text() -> String:
	var lines := PackedStringArray(["Lokale Verwaltungsflächen · Abdeckungsprüfung", "Ziel: mindestens 95 % der Landreferenz im Kartenausschnitt. Ein erreichter Prüfwert ersetzt keinen aktuellen amtlichen Vollständigkeitsnachweis."])
	if _map == null or _map.atlas_data == null:
		lines.append("Zurzeit ist keine Abdeckungsprüfung verfügbar.")
		return "\n".join(lines)
	var countries: Array = []
	for feature in _map.atlas_data.features:
		if str(feature.kind) == "country":
			countries.append(feature)
	countries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.name) < str(b.name))
	var statuses := {"complete": "Prüfwert erreicht", "gap": "Lücke", "source_review": "Quellprüfung offen", "reference_review": "Landreferenz muss geprüft werden", "single_jurisdiction": "gebietsweite Verwaltung"}
	for country in countries:
		var code := str(country.country)
		var entry: Dictionary = _map.atlas_data.coverage_for_country(code)
		var state := str(entry.get("status", "unbekannt"))
		var percent := ("%.2f %%" % (float(entry.get("fraction", 0.0)) * 100.0)).replace(".", ",")
		if state == "reference_review":
			percent = "Prozentwert nicht belastbar"
		elif state == "single_jurisdiction":
			var native: Dictionary = entry.get("native_scope", {})
			percent = "Eine landesweite Gemeinde" if native.get("authority_role") == "municipality" else "Zentrale Verwaltung; tiefere Kommunalebene nicht belegt"
		elif entry.is_empty():
			percent = "keine Messung vorhanden"
		lines.append("%s (%s): %s · %s" % [str(country.name), code, percent, str(statuses.get(state, "Stand unklar"))])
	return "\n".join(lines)

func _source_text(source: Dictionary) -> String:
	var lines := PackedStringArray()
	lines.append("Quelle: %s" % _source_value(source, "id"))
	if source.has("country"):
		lines.append("Gebiet: %s" % _source_value(source, "country"))
	if source.has("unit_type"):
		lines.append("Verwaltungstyp der Quelle: %s" % _source_value(source, "unit_type"))
	lines.append("Stand: %s" % _source_value(source, "date"))
	lines.append("Lizenz: %s" % _source_value(source, "license"))
	# Der vollständige Urheberhinweis bleibt einschließlich mehrerer Credits erhalten.
	lines.append("Herkunfts- und Urheberhinweis: %s" % _source_value(source, "attribution"))
	lines.append("Datengrundlage: %s" % _source_value(source, "url"))
	lines.append("Lizenzadresse: %s" % _source_value(source, "license_url"))
	if source.get("administrative_geometry_eligible", true) == false:
		lines.append("Verwaltungsdarstellung: ausgeschlossen; die Rolle dieser Flächen ist nicht belegt.")
	elif bool(source.get("blocks_full_coverage_claim", false)):
		lines.append("Prüfgrenze: Diese Quelle ist unvollständig oder fachlich noch zu prüfen.")
	for note in [["coverage_note", "Abdeckung"], ["source_geometry_defect_note", "Geometrieprüfung"],
			["administrative_ineligibility_note", "Grund des Ausschlusses"], ["administrative_eligibility_note", "Rollenprüfung"],
			["territorial_scope_note", "Gebietliche Einordnung"]]:
		var value = source.get(note[0])
		if value is String and not value.strip_edges().is_empty():
			lines.append("%s: %s" % [note[1], value])
	var semantics = source.get("unit_semantics", {})
	if semantics is Dictionary and not str(semantics.get("reference_note", "")).is_empty():
		lines.append("Einordnung der Verwaltungsebene: %s" % semantics.reference_note)
	var combined = source.get("combined_role_basis", {})
	if combined is Dictionary and not str(combined.get("limits", "")).is_empty():
		lines.append("Grenzen des Rollennachweises: %s" % combined.limits)
	var shown_urls := {str(source.get("url", "")): true, str(source.get("license_url", "")): true}
	for link in [["product_url", "Produktbeschreibung"], ["metadata_url", "Metadaten"], ["pinnedmetadataURL", "Festgeschriebene Metadaten"], ["license_evidence_url", "Nutzungsbedingungen des Anbieters"], ["original_license_source", "Ursprünglicher Lizenzverweis"]]:
		var address := str(source.get(link[0], ""))
		if not address.is_empty() and not shown_urls.has(address):
			lines.append("%s: %s" % [link[1], address])
			shown_urls[address] = true
	for evidence in source.get("evidence", []):
		if evidence is Dictionary and not str(evidence.get("url", "")).is_empty():
			lines.append("Amtlicher Beleg %s: %s\n%s" % [str(evidence.get("country", "")), str(evidence.get("title", "")), str(evidence.url)])
	return "\n".join(lines)

func _source_value(source: Dictionary, key: String) -> String:
	var value = source.get(key)
	if value == null or str(value).strip_edges().is_empty():
		return "nicht angegeben"
	return str(value)

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
	if _sources_panel == null or not _sources_panel.visible:
		return
	var viewport := get_viewport_rect()
	var popup_width := minf(maxf(520.0, size.x), minf(760.0, maxf(1.0, viewport.size.x - 24.0)))
	_sources_panel.custom_minimum_size = Vector2(popup_width, 0)
	_sources_panel.size.x = popup_width
	_sources_scroll.custom_minimum_size = Vector2.ZERO
	var chrome_height := _sources_panel.get_theme_stylebox("panel").get_minimum_size().y
	chrome_height += _sources_title.get_combined_minimum_size().y + _sources_close.get_combined_minimum_size().y
	chrome_height += float(_sources_layout.get_theme_constant("separation")) * 2.0
	var desired_height := maxf(chrome_height + 40.0, _sources_content.get_combined_minimum_size().y + chrome_height)
	var popup_height := minf(desired_height, maxf(1.0, viewport.size.y - 24.0))
	_sources_panel.size = Vector2(popup_width, popup_height)
	var popup_x := clampf(global_position.x, viewport.position.x + 12.0, viewport.end.x - popup_width - 12.0)
	_sources_panel.position = Vector2(popup_x, viewport.position.y + (viewport.size.y - popup_height) * 0.5)

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
