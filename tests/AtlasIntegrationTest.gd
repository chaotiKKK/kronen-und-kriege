extends Node
## Reale Geografie, lesbare Kartenschilder und sichtbereichsgebundene Darstellung.
var checks := 0
var failures := 0
var main

func _ready() -> void:
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	main._start(0)
	main.game.speed = 0
	await get_tree().process_frame
	var map = main.map_view
	_check(main.has_meta("atlas_search"), "Die deutsche Orts- und Regionensuche fehlt in der Kartenansicht.")
	_check(map.clip_contents, "Die Hauptkarte muss ihren sichtbaren Ausschnitt clippen.")
	map.zoom_by(100.0)
	_check(is_equal_approx(map.zoom, 64.0), "Gemeinden benötigen eine tatsächlich nutzbare Nahansicht bis Zoom 64.")
	map.reset_view()
	_check_minimap_revision()
	var properties := {}
	for property in map.get_property_list():
		properties[str(property.name)] = true
	_check(properties.has("atlas_data"), "Die Hauptkarte hat keinen Zugriff auf die echten Atlasdaten.")
	_check(properties.has("atlas_layer"), "Die getrennte Atlasebene fehlt.")
	if not properties.has("atlas_data") or not properties.has("atlas_layer"):
		_finish()
		return
	var atlas = map.get("atlas_data")
	var layer = map.get("atlas_layer")
	_check(atlas != null and layer != null, "Atlasdaten und Atlasebene müssen tatsächlich installiert sein.")
	if atlas == null or layer == null:
		_finish()
		return
	for method in ["project", "search", "visible_features", "path"]:
		_check(atlas.has_method(method), "Atlas-Datenzugriff fehlt: %s." % method)
		if not atlas.has_method(method):
			_finish()
			return
	_check(layer.has_method("configure") and layer.has_method("refresh"), "Die Atlasebene benötigt eine echte Aktualisierungsschnittstelle.")
	if not layer.has_method("refresh"):
		_finish()
		return
	_check(atlas.project(-12.0, 72.0).is_equal_approx(Vector2.ZERO), "Atlasprojektion verschiebt die nordwestliche Kartenecke.")
	_check(atlas.project(52.0, 33.0).is_equal_approx(Vector2(1200, 760)), "Atlasprojektion verschiebt die südöstliche Kartenecke.")
	var wiesbaden: Dictionary = _find_city(atlas.search("Wiesbaden", 20), "Wiesbaden")
	var berlin: Dictionary = _find_city(atlas.search("Berlin", 20), "Berlin")
	_check(not wiesbaden.is_empty(), "Die Ortssuche findet Wiesbaden nicht.")
	_check(not berlin.is_empty(), "Die Ortssuche findet Berlin nicht.")
	var wiesbaden_point := _point(wiesbaden)
	var berlin_point := _point(berlin)
	_check(wiesbaden_point.distance_to(Vector2(379.5, 427.159)) < 1.0, "Wiesbaden liegt nicht bei ungefähr 8,24° Ost / 50,08° Nord.")
	_check(berlin_point.distance_to(Vector2(476.344, 379.610)) < 2.0, "Berlin liegt nicht bei ungefähr 13,405° Ost / 52,52° Nord.")
	await _check_search_widget(wiesbaden_point)
	_check_bundeslaender()
	var local_rect := Rect2(Vector2(367, 415), Vector2(25, 25))
	var local_features: Array = atlas.visible_features(local_rect, 12.0)
	_check(not local_features.is_empty(), "Im Wiesbadener Nahbereich fehlen sichtbare Verwaltungsdetails.")
	for feature in local_features:
		var bounds = feature.get("bounds", [])
		var feature_rect := _rect(bounds)
		_check(feature_rect.intersects(local_rect), "Die Sichtbereichsauswahl lädt vollständig entfernte Verwaltungsflächen.")
	var river_found := false
	for river in map.rivers():
		var river_name := str(river.get("name", "")).to_lower()
		if not (river_name.contains("rhine") or river_name.contains("rhein")):
			continue
		river_found = true
		var points = river.get("points", [])
		_check(points.size() >= 2, "Der Rhein benötigt einen tatsächlichen Linienzug.")
		for point in points:
			var p: Vector2 = point if point is Vector2 else Vector2(float(point[0]), float(point[1]))
			_check(Rect2(280, 350, 170, 200).has_point(p), "Der Rhein verläuft weiterhin außerhalb seines geografischen Korridors.")
	_check(river_found, "Der echte Rhein ist nicht in die Hauptkarte eingebunden.")
	var ui = main.get_meta("modern_interface")
	ui.set_text_scale(1.0)
	map.reset_view()
	layer.refresh()
	await get_tree().process_frame
	await get_tree().process_frame
	await _draw_frame()
	_check_labels(layer, 13)
	await _shot("atlas-overview")
	map.zoom_by(12.0)
	map.center_on(wiesbaden_point)
	layer.refresh()
	await get_tree().process_frame
	await get_tree().process_frame
	await _draw_frame()
	_check_labels(layer, 13)
	await _shot("atlas-germany")
	map.zoom_by(4.0)
	map.center_on(wiesbaden_point)
	layer.refresh()
	await get_tree().process_frame
	await get_tree().process_frame
	await _draw_frame()
	_check_labels(layer, 13)
	await _shot("atlas-gemeinden")
	ui.set_text_scale(2.0)
	layer.refresh()
	await get_tree().process_frame
	await get_tree().process_frame
	await _draw_frame()
	_check_labels(layer, 26)
	await _shot("atlas-text-200")
	ui.set_text_scale(1.0)
	await _check_map_focus(ui)
	_finish()

func _check_map_focus(ui) -> void:
	_check(ui.has_method("set_map_focus"), "Für feine Kartendetails fehlt der vergrößerte Karten-Fokusmodus.")
	if not ui.has_method("set_map_focus"):
		return
	await get_tree().process_frame
	await get_tree().process_frame
	var previous_size: Vector2 = main.map_view.size
	var previous_area := previous_size.x * previous_size.y
	var previous_side_visible: bool = main.side_panel.visible
	ui.set_map_focus(true)
	await get_tree().process_frame
	await get_tree().process_frame
	var focused_size: Vector2 = main.map_view.size
	_check(focused_size.x * focused_size.y > previous_area * 1.4, "Der Karten-Fokusmodus vergrößert die nutzbare Fläche nicht deutlich genug.")
	_check(not main.side_panel.visible, "Das Seitenpanel verdeckt im Karten-Fokusmodus weiterhin die Karte.")
	_check(main.get_viewport_rect().encloses(main.map_view.get_global_rect()), "Die vergrößerte Karte ragt aus dem sichtbaren Spielfenster.")
	await _draw_frame()
	await _shot("atlas-fullscreen")
	ui.set_map_focus(false)
	await get_tree().process_frame
	await get_tree().process_frame
	var restored_size: Vector2 = main.map_view.size
	var restored_area := restored_size.x * restored_size.y
	_check(main.side_panel.visible == previous_side_visible, "Der Rückwechsel stellt den vorherigen Seitenpanel-Zustand nicht wieder her.")
	_check(previous_area > 0.0 and absf(restored_area - previous_area) <= previous_area * 0.02, "Der Rückwechsel stellt die vorherige Kartenfläche nicht wieder her.")

func _check_search_widget(city_point: Vector2) -> void:
	_check(main.has_meta("atlas_search"), "Die deutsche Orts- und Regionensuche fehlt in der Hauptansicht.")
	if not main.has_meta("atlas_search"):
		return
	var widget = main.get_meta("atlas_search")
	var properties := {}
	for property in widget.get_property_list():
		properties[str(property.name)] = true
	_check(properties.has("search_field") and properties.has("results_box"), "Die Ortsuche enthält kein Eingabefeld und keine bedienbare Trefferliste.")
	if not properties.has("search_field") or not properties.has("results_box"):
		return
	var search_field = widget.get("search_field")
	var results_box = widget.get("results_box")
	_check(search_field is LineEdit and results_box is VBoxContainer, "Die Ortsuche braucht ein Texteingabefeld und geordnete Suchtreffer.")
	if not search_field is LineEdit or not results_box is VBoxContainer:
		return
	var reference_labeled := false
	for label in widget.find_children("*", "Label", true, false):
		if label.text.contains("Referenzatlas"):
			reference_labeled = true
	_check(reference_labeled, "Die heutigen geografischen Daten sind nicht als Referenzatlas gekennzeichnet.")
	search_field.text = "Wiesbaden"
	search_field.text_changed.emit("Wiesbaden")
	await get_tree().process_frame
	var buttons: Array = results_box.find_children("*", "Button", true, false)
	_check(results_box.visible and not buttons.is_empty(), "Die Eingabe Wiesbaden erzeugt keinen sichtbaren, antippbaren Treffer.")
	if not buttons.is_empty():
		buttons[0].pressed.emit()
		await get_tree().process_frame
		_check(str(main.map_view.atlas_location).contains("Wiesbaden"), "Der Suchtreffer übernimmt Wiesbaden nicht als ausgewählten Ort.")
		_check(main.map_view.zoom >= 10.0, "Der Suchtreffer zoomt nicht bis zur lesbaren Ortsansicht.")
		var fit: Array = main.map_view._fit()
		var screen_point: Vector2 = city_point * float(fit[0]) + (fit[1] as Vector2)
		_check(Rect2(Vector2.ZERO, main.map_view.size).has_point(screen_point), "Wiesbaden liegt nach dem Suchtreffer weiterhin außerhalb des sichtbaren Kartenfensters.")
	search_field.text = ""
	search_field.text_changed.emit("")
	await get_tree().process_frame
	_check(not results_box.visible, "Die gelöschte Suchanfrage lässt die alte Trefferliste sichtbar.")
	_check(results_box.find_children("*", "Button", true, false).is_empty(), "Nach dem Löschen der Suchanfrage bleiben alte Suchtreffer anklickbar.")

func _check_minimap_revision() -> void:
	main.minimap._process(0.0)
	var old_key: String = main.minimap._last_state
	var old_zoom: float = main.map_view.zoom
	var province: Dictionary = main.game.provinces[0]
	var owner: int = int(province.owner)
	province.owner = (owner + 1) % main.game.houses.size()
	main.refresh()
	main.minimap._process(0.0)
	_check(main.minimap._last_state != old_key, "Ein Besitzerwechsel aktualisiert die Minimap ohne Bewegung nicht.")
	_check(is_equal_approx(main.map_view.zoom, old_zoom), "Die Minimapprüfung darf den Besitzerwechsel nicht durch einen Zoom kaschieren.")
	province.owner = owner
	main.refresh()
	main.minimap._process(0.0)

func _check_bundeslaender() -> void:
	var file := FileAccess.open("res://data/atlas.json", FileAccess.READ)
	_check(file != null, "Die offline eingebetteten Atlasdaten fehlen.")
	if file == null:
		return
	var document = JSON.parse_string(file.get_as_text())
	file.close()
	_check(document is Dictionary, "Die eingebetteten Atlasdaten sind nicht lesbar.")
	if not document is Dictionary:
		return
	var states := {}
	for feature in document.get("features", []):
		if str(feature.get("kind", "")) == "region" and str(feature.get("country", "")) == "DE" and str(feature.get("source", "")) == "bkg-vg250":
			states[str(feature.get("ags", ""))] = true
	_check(states.size() == 16, "Die amtlichen Verwaltungsdaten enthalten nicht alle 16 Bundesländer.")
	_check(states.has("06") and states.has("11"), "Hessen und Berlin verlieren ihren amtlichen zweistelligen Schlüssel.")

func _check_labels(layer, minimum_size: int) -> void:
	var labels: Array = layer.get("audit_labels")
	_check(not labels.is_empty(), "Die echte Atlasebene zeichnet keine Beschriftungen.")
	var viewport := Rect2(Vector2.ZERO, main.map_view.size)
	var occupied: Array[Rect2] = []
	for entry in labels:
		var box: Rect2 = entry.get("rect", Rect2())
		_check(not str(entry.get("text", "")).is_empty(), "Ein gezeichnetes Atlasschild enthält keinen Namen.")
		_check(int(entry.get("font_size", 0)) >= minimum_size, "Gezeichnete Ortsnamen unterschreiten die eingestellte lesbare Mindestgröße.")
		_check(viewport.encloses(box), "Ein gezeichnetes Atlasschild ragt aus dem sichtbaren Kartenfenster.")
		var overlap := false
		for previous in occupied:
			if previous.intersects(box):
				overlap = true
				break
		_check(not overlap, "Gezeichnete Atlasschilder überlappen sich.")
		occupied.append(box)

func _find_city(results: Array, name: String) -> Dictionary:
	for result in results:
		if str(result.get("name", "")).to_lower() == name.to_lower() and result.has("point"):
			return result
	for result in results:
		if str(result.get("name", "")).to_lower() == name.to_lower():
			return result
	return {}

func _point(feature: Dictionary) -> Vector2:
	var value = feature.get("point", feature.get("center", []))
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2(-1000, -1000)

func _rect(value) -> Rect2:
	if value is Rect2:
		return value
	if value is Array and value.size() >= 4:
		return Rect2(float(value[0]), float(value[1]), float(value[2]), float(value[3]))
	return Rect2()

func _draw_frame() -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw

func _shot(name: String) -> void:
	if DisplayServer.get_name() != "headless":
		_check(get_viewport().get_texture().get_image().save_png("res://build/verify/%s.png" % name) == OK, "Atlasaufnahme konnte nicht gespeichert werden: %s." % name)

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("ATLASINTEGRATIONTEST FAIL: " + message)

func _finish() -> void:
	print("ATLASINTEGRATIONTEST %s; %d Prüfungen." % ["OK" if failures == 0 else "FAIL", checks])
	get_tree().quit(0 if failures == 0 else 1)
