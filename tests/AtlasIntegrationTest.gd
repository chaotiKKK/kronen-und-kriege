extends Node
## Reale Geografie, lesbare Kartenschilder und sichtbereichsgebundene Darstellung.
var checks := 0
var failures := 0
var main

class IsolatedLabelAtlas extends RefCounted:
	var original
	var record: Dictionary
	var rivers: Array = []

	func visible_features(rect: Rect2, _zoom: float) -> Array:
		return [record] if record.bounds.intersects(rect) else []

	func visible_cities(_rect: Rect2, _zoom: float) -> Array:
		return []

	func lookup(id: String) -> Dictionary:
		return record if id == str(record.id) else {}

	func path(reference: Array) -> PackedVector2Array:
		return original.path(reference)

	func project(lon: float, lat: float) -> Vector2:
		return original.project(lon, lat)

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
	await _check_unassigned_atlas_location(wiesbaden)
	await _check_label_tap(wiesbaden)
	await _check_background_area_tap(wiesbaden)
	_check_bundeslaender()
	await _check_unknown_source_labels(wiesbaden)
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
	await _check_international_local_views()
	ui.set_text_scale(2.0)
	layer.refresh()
	await get_tree().process_frame
	await get_tree().process_frame
	await _draw_frame()
	_check_labels(layer, 26)
	await _shot("atlas-text-200")
	ui.set_text_scale(1.0)
	await _check_map_focus(ui)
	await _check_large_text_popups(ui)
	await _check_layer_render_cache()
	await _check_boundary_pan_cache()
	_finish()

func _check_international_local_views() -> void:
	var map = main.map_view
	var atlas = map.atlas_data
	var layer = map.atlas_layer
	var previous_size: Vector2 = map.size
	var previous_zoom: float = map.zoom
	var previous_pan: Vector2 = map.pan
	var return_to: Dictionary = atlas.lookup("geonames:2809346")
	var cities := [
		{"country": "DE", "id": "geonames:2809346", "name": "Wiesbaden"},
		{"country": "FR", "id": "geonames:2988507", "name": "Paris"},
		{"country": "IT", "id": "geonames:3173435", "name": "Mailand"},
		{"country": "PL", "id": "geonames:756135", "name": "Warschau"},
		{"country": "HU", "id": "geonames:3054643", "name": "Budapest"},
		{"country": "CZ", "id": "geonames:3067696", "name": "Prag"},
		{"country": "NO", "id": "geonames:3143244", "name": "Oslo"},
		{"country": "LU", "id": "geonames:2960316", "name": "Luxemburg"},
		{"country": "RU", "id": "geonames:524901", "name": "Moskau"},
		{"country": "TR", "id": "geonames:323786", "name": "Ankara", "local_kind": "local_admin"},
		{"country": "AM", "id": "geonames:616052", "name": "Jerewan", "local_kind": "local_admin"},
		{"country": "ES", "id": "geonames:3117735", "name": "Madrid"},
		{"country": "GB", "id": "geonames:2643743", "name": "London"},
	]
	for city_spec in cities:
		var country: String = city_spec.country
		var city: Dictionary = atlas.lookup(str(city_spec.id))
		_check(not city.is_empty(), "%s: Die echte GeoNames-Stadt %s fehlt." % [country, city_spec.name])
		if city.is_empty():
			continue
		_check(str(city.get("id", "")) == str(city_spec.id) and str(city.get("source", "")) == "geonames-cities5000", "%s: Die Vergleichsansicht benötigt den tatsächlichen GeoNames-Ort statt einer gleichnamigen Verwaltungsfläche." % country)
		_check(str(city.get("country", "")) == country, "%s: Der Vergleichsort gehört nicht zum erwarteten Land." % country)
		map.focus_atlas_location(city)
		map.zoom_by(48.0 / map.zoom)
		map.center_on(_point(city))
		layer.refresh()
		await _settle_ui()
		await _draw_frame()
		_check(is_equal_approx(map.zoom, 48.0), "%s: Der internationale Gemeindevergleich verwendet nicht Zoom48." % country)
		_check(map.size.is_equal_approx(previous_size), "%s: Der Ortswechsel verändert die gemeinsame Kartenabmessung." % country)
		var local_ids := {}
		for identifier in layer.audit_features:
			var feature: Dictionary = atlas.lookup(str(identifier))
			if str(feature.get("country", "")) == country and str(feature.get("kind", "")) == str(city_spec.get("local_kind", "municipality")):
				local_ids[str(identifier)] = true
		_check(not local_ids.is_empty(), "%s: Die echte Atlasebene zeichnet um %s bei Zoom48 keine landeseigenen Kommunalflächen." % [country, city_spec.name])
		_check_labels(layer, 13)
		await _shot("atlas-international-%s" % country)
		if country in ["FR", "IT", "ES", "GB"]:
			map.zoom_by(3.0 / map.zoom)
			map.center_on(_point(city))
			layer.refresh()
			await _settle_ui()
			await _draw_frame()
			var regions := 0
			for identifier in layer.audit_features:
				var feature: Dictionary = atlas.lookup(str(identifier))
				if str(feature.get("country", "")) == country and str(feature.get("kind", "")) == "region" and str(feature.get("source", "")) != "natural-earth-regions":
					regions += 1
			_check(regions > 0, "%s: Auf mittlerer Zoomstufe fehlen weiterhin echte obere Verwaltungsregionen." % country)
			_check_labels(layer, 13)
			await _shot("atlas-regional-%s" % country)
	_check(not return_to.is_empty(), "Die internationale Vergleichsprüfung kann die echte Wiesbaden-Ansicht nicht wiederherstellen.")
	if not return_to.is_empty():
		map.focus_atlas_location(return_to)
		map.zoom_by(previous_zoom / map.zoom)
		map.pan = previous_pan
		map._clamp_pan()
		map._sync_base_transform()
		map.queue_redraw()
		layer.refresh()
		await _settle_ui()
		await _draw_frame()
		_check(is_equal_approx(map.zoom, previous_zoom) and map.pan.is_equal_approx(previous_pan), "Die internationale Vergleichsprüfung verändert die vorherige Wiesbaden-Kamera für die 200-%-Prüfung.")

func _check_unknown_source_labels(return_to: Dictionary) -> void:
	var map = main.map_view
	var layer = map.atlas_layer
	var unknown: Dictionary = {}
	var largest := -1.0
	for feature in map.atlas_data.features:
		if str(feature.get("country", "")) != "DZ" or bool(feature.get("name_known", true)):
			continue
		var area: float = feature.bounds.get_area()
		if area > largest:
			unknown = feature
			largest = area
	_check(not unknown.is_empty(), "Für die Prüfung fehlt ein echter algerischer Polygon mit unbekanntem Quellnamen.")
	if unknown.is_empty():
		return
	map.focus_atlas_location(unknown)
	await _settle_ui()
	await _draw_frame()
	# Echte DZ-Geometrie und stabile ID, aber eine kontrollierte kurze
	# Beschriftung ohne andere Kandidaten/HUD-Kollisionen. Ein positiver
	# Kontrollfall beweist anschließend, dass diese Position beschriftbar ist.
	var original_atlas = map.atlas_data
	var original_obstacles: Array = map.atlas_obstacles
	var isolated := IsolatedLabelAtlas.new()
	isolated.original = original_atlas
	isolated.record = unknown.duplicate()
	isolated.record["name"] = "?"
	map.atlas_data = isolated
	map.atlas_obstacles = []
	layer.selected_id = ""
	layer.refresh()
	await _settle_ui()
	await _draw_frame()
	_check(str(unknown.id) in layer.audit_features, "Der Polygon mit unbekanntem Namen verschwindet statt nur seine automatische Beschriftung.")
	var automatic_fallback := false
	for label in layer.audit_labels:
		if str(label.get("id", "")) == str(unknown.id):
			automatic_fallback = true
	_check(not automatic_fallback, "Der ehrliche Hinweis auf einen fehlenden Quellnamen wird als automatischer Ortsname auf die Karte geschrieben.")
	isolated.record["name_known"] = true
	layer.refresh()
	await _settle_ui()
	await _draw_frame()
	var known_control_visible := false
	for label in layer.audit_labels:
		if str(label.get("id", "")) == str(unknown.id):
			known_control_visible = true
	_check(known_control_visible, "Die kontrollierte freie Labelposition ist nicht tatsächlich beschriftbar; der Namensfiltertest wäre unempfindlich.")
	isolated.record["name_known"] = false
	layer.selected_id = str(unknown.id)
	layer.refresh()
	await _settle_ui()
	await _draw_frame()
	var explicit_fallback := false
	for label in layer.audit_labels:
		if str(label.get("id", "")) == str(unknown.id) and str(label.get("text", "")) == "?":
			explicit_fallback = true
	_check(explicit_fallback, "Die ausdrücklich ausgewählte namenlose Fläche verliert ihren ehrlichen Hinweis.")
	map.atlas_data = original_atlas
	map.atlas_obstacles = original_obstacles
	layer.refresh()
	await _settle_ui()
	await _draw_frame()
	var original_fallback_visible := false
	for label in layer.audit_labels:
		if str(label.get("id", "")) == str(unknown.id) and str(label.get("text", "")) == str(unknown.name):
			original_fallback_visible = true
	_check(original_fallback_visible, "Die ausdrückliche Auswahl der echten DZ-Fläche zeigt nach dem Test ihren ursprünglichen ehrlichen Hinweis nicht mehr.")
	map.focus_atlas_location(return_to)
	await _settle_ui()

func _check_boundary_pan_cache() -> void:
	var map = main.map_view
	var layer = map.atlas_layer
	map.reset_view()
	map.zoom_by(4.0)
	map.center_on(map.atlas_data.project(8.24, 50.08))
	await _settle_ui()
	await _draw_frame()
	var boundaries = layer.get_node_or_null("AtlasBoundaries")
	_check(boundaries != null, "Kleine Kartenschwenks benötigen eine getrennt zwischengespeicherte Grenzdarstellung.")
	if boundaries == null:
		return
	var draws: Array[int] = [0]
	var observe: Callable = func() -> void: draws[0] += 1
	boundaries.draw.connect(observe)
	var before_position: Vector2 = boundaries.position
	map.pan += Vector2(3, -2)
	map._sync_base_transform()
	map.queue_redraw()
	await _settle_ui()
	await _draw_frame()
	_check(boundaries.position.distance_to(before_position) > 1.0, "Zwischengespeicherte Grenzen folgen der echten Kartenkamera nicht.")
	_check(draws[0] == 0, "Ein kleiner Schwenk baut unveränderte Grenzpfade erneut auf (%d Draws)." % draws[0])
	map.zoom_by(1.5)
	await _settle_ui()
	await _draw_frame()
	_check(draws[0] > 0, "Ein Zoom aktualisiert Detailstufe und Strichbreite der Grenzdarstellung nicht.")
	boundaries.draw.disconnect(observe)

func _check_layer_render_cache() -> void:
	var map = main.map_view
	var layer = map.atlas_layer
	await _settle_ui()
	await _draw_frame()
	var layer_draws: Array[int] = [0]
	var observe_draw: Callable = func() -> void:
		layer_draws[0] += 1
	layer.draw.connect(observe_draw)
	for _frame in 3:
		map.queue_redraw()
		await get_tree().process_frame
		await _draw_frame()
	_check(layer_draws[0] == 0, "Ein unveränderter Karten-Redraw berechnet die zwischengespeicherte Atlasebene erneut (%d Draws)." % layer_draws[0])
	var previous_draws: int = layer_draws[0]
	var previous_zoom: float = map.zoom
	map.zoom_by(0.75 if previous_zoom > 32.0 else 1.25)
	await _settle_ui()
	await _draw_frame()
	_check(not is_equal_approx(map.zoom, previous_zoom), "Die Cacheprüfung muss die Kamera tatsächlich zoomen.")
	_check(layer_draws[0] > previous_draws, "Eine echte Zoomänderung aktualisiert die zwischengespeicherte Atlasebene nicht.")
	layer.draw.disconnect(observe_draw)
	map.zoom_by(previous_zoom / map.zoom)
	await _settle_ui()

func _check_map_focus(ui) -> void:
	_check(ui.has_method("set_map_focus"), "Für feine Kartendetails fehlt der vergrößerte Karten-Fokusmodus.")
	if not ui.has_method("set_map_focus"):
		return
	await get_tree().process_frame
	await get_tree().process_frame
	var previous_size: Vector2 = main.map_view.size
	var previous_area := previous_size.x * previous_size.y
	var previous_fit: Array = main.map_view._fit()
	var previous_center: Vector2 = (previous_size * 0.5 - (previous_fit[1] as Vector2)) / float(previous_fit[0])
	var previous_side_visible: bool = main.side_panel.visible
	ui.set_map_focus(true)
	await get_tree().process_frame
	await get_tree().process_frame
	var focused_size: Vector2 = main.map_view.size
	var focused_fit: Array = main.map_view._fit()
	var focused_center: Vector2 = (focused_size * 0.5 - (focused_fit[1] as Vector2)) / float(focused_fit[0])
	_check(focused_center.distance_to(previous_center) < 0.5, "Der Karten-Fokusmodus verschiebt den geografischen Mittelpunkt vom betrachteten Ort weg.")
	_check(focused_size.x * focused_size.y > previous_area * 1.4, "Der Karten-Fokusmodus vergrößert die nutzbare Fläche nicht deutlich genug.")
	_check(not main.side_panel.visible, "Das Seitenpanel verdeckt im Karten-Fokusmodus weiterhin die Karte.")
	_check(main.get_viewport_rect().encloses(main.map_view.get_global_rect()), "Die vergrößerte Karte ragt aus dem sichtbaren Spielfenster.")
	await _draw_frame()
	await _shot("atlas-fullscreen")
	ui.set_map_focus(false)
	await get_tree().process_frame
	await get_tree().process_frame
	var restored_size: Vector2 = main.map_view.size
	var restored_fit: Array = main.map_view._fit()
	var restored_center: Vector2 = (restored_size * 0.5 - (restored_fit[1] as Vector2)) / float(restored_fit[0])
	_check(restored_center.distance_to(previous_center) < 0.5, "Die Rückkehr aus dem Karten-Fokusmodus verschiebt den geografischen Mittelpunkt.")
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

func _check_unassigned_atlas_location(wiesbaden: Dictionary) -> void:
	var map = main.map_view
	map.focus_atlas_location(wiesbaden)
	await _settle_ui()
	var previous_province: Dictionary = main.game.province(main.selected)
	_check(not previous_province.is_empty(), "Der Wiesbaden-Ausgangsort besitzt keine tatsächliche Spielgebietsauswahl.")
	var previous_house := ""
	if not previous_province.is_empty():
		previous_house = str(main.game.houses[int(previous_province.owner)].name)
	var algiers: Dictionary = map.atlas_data.lookup("geonames:2507480")
	_check(not algiers.is_empty() and str(algiers.get("province_id", "")).is_empty(), "Der Referenzort Algier muss als echter Ort außerhalb der 49 Spielgebiete vorliegen.")
	if not algiers.is_empty():
		map.focus_atlas_location(algiers)
		await _settle_ui()
		_check(str(main.selected).is_empty() and str(map.selected).is_empty(), "Ein Ort außerhalb der Spielgebiete behält die vorherige Wiesbaden-Herrschaftsauswahl.")
		_check(main.map_header_meta.text.contains(str(algiers.name)), "Der Kartenkopf zeigt den neu gewählten Referenzort außerhalb der Spielgebiete nicht an.")
		_check(previous_house.is_empty() or not main.map_header_meta.text.contains(previous_house), "Der unzugeordnete Referenzort erbt im Kartenkopf die Herrschaft des vorherigen Ortes.")
	map.focus_atlas_location(wiesbaden)
	await _settle_ui()

func _check_label_tap(wiesbaden: Dictionary) -> void:
	var map = main.map_view
	map.focus_atlas_location(wiesbaden)
	map.atlas_layer.refresh()
	await _settle_ui()
	await _draw_frame()
	var fit: Array = map._fit()
	var candidate: Dictionary = {}
	var tap := Vector2.ZERO
	for entry in map.atlas_layer.audit_labels:
		if str(entry.get("kind", "")) != "city" or str(entry.get("id", "")) == str(map.atlas_layer.selected_id):
			continue
		var record: Dictionary = map.atlas_data.lookup(str(entry.id))
		if record.is_empty():
			continue
		var box: Rect2 = entry.rect
		var anchor: Vector2 = _point(record) * float(fit[0]) + (fit[1] as Vector2)
		var label_center := box.get_center()
		if label_center.distance_to(anchor) > 13.0:
			candidate = record
			tap = label_center
			break
	_check(not candidate.is_empty(), "Die echte Ortsansicht enthält kein antippbares Stadtschild außerhalb des Markerradius.")
	if not candidate.is_empty():
		map._pick_at(tap)
		await _settle_ui()
		_check(str(map.atlas_layer.selected_id) == str(candidate.id), "Der Tipp auf ein sichtbares Stadtschild wählt die Gemeinde unter dem Text statt der beschrifteten Stadt.")
		_check(str(map.atlas_location) == str(candidate.name), "Der Tipp auf den Ortsnamen übernimmt nicht den Namen der sichtbaren Stadt.")
		var expected_province := str(candidate.get("province_id", ""))
		_check(str(main.selected) == expected_province and str(map.selected) == expected_province, "Der Tipp auf ein Stadtschild übernimmt das Spielgebiet unter der Textposition statt das Gebiet des beschrifteten Ortes.")
	map.focus_atlas_location(wiesbaden)
	await _settle_ui()

func _check_background_area_tap(wiesbaden: Dictionary) -> void:
	var map = main.map_view
	var ui = main.get_meta("modern_interface")
	ui._toggle_map_focus()
	await _settle_ui()
	var point: Vector2 = map.atlas_data.project(11.4, 53.04)
	map.reset_view()
	map.zoom_by(5.5)
	map.center_on(point)
	map.atlas_layer.refresh()
	await _settle_ui()
	await _draw_frame()
	var fit: Array = map._fit()
	var tap: Vector2 = point * float(fit[0]) + (fit[1] as Vector2)
	var label_hit := false
	for label in map.atlas_layer.audit_labels:
		label_hit = label_hit or (label.rect as Rect2).has_point(tap)
	_check(not label_hit, "Der Flächentest bei Lüchow trifft versehentlich ein Ortsnamensschild.")
	_check(map.atlas_data.nearest_city(point, 12.0 / float(fit[0])).is_empty(), "Der Flächentest bei Lüchow trifft versehentlich einen Ortsmarker.")
	_check(str(map._province_at(tap)) == "vandalia", "Die tatsächlich angetippte Spielgebietsfläche bei Lüchow ist nicht Vandalia.")
	map._pick_at(tap)
	await _settle_ui()
	_check(str(map.atlas_layer.selected_id) == "region:DE-03", "Der Hintergrundtipp bei Lüchow verliert die echte Region Niedersachsen.")
	_check(str(main.selected) == "vandalia" and str(map.selected) == "vandalia", "Ein Hintergrundtipp übernimmt das Spielgebiet des Regionsmittelpunkts statt der angetippten Fläche.")
	ui._toggle_map_focus()
	await _settle_ui()
	map.focus_atlas_location(wiesbaden)
	await _settle_ui()

func _check_large_text_popups(ui) -> void:
	if not main.has_meta("atlas_search"):
		return
	var widget = main.get_meta("atlas_search")
	var search_field: LineEdit = widget.search_field
	var results_box: VBoxContainer = widget.results_box
	var original_scale: float = float(main.settings.get("text_scale", 1.0))
	ui.set_text_scale(2.0)
	await _settle_ui()
	var previous_size: Vector2 = main.map_view.size
	search_field.text = "ber"
	search_field.text_changed.emit("ber")
	await _settle_ui()
	var buttons: Array = results_box.find_children("*", "Button", true, false)
	_check(buttons.size() == 6, "Die mehrdeutige Suche ber liefert bei 200 % nicht sechs erreichbare Treffer.")
	var results_panel := _panel_ancestor(results_box)
	var results_scroll := _scroll_ancestor(results_box)
	_check(results_panel != null and results_panel.is_visible_in_tree(), "Die vergrößerten Suchtreffer erscheinen nicht in einem sichtbaren Panel.")
	_check(results_scroll != null, "Die sechs vergrößerten Suchtreffer benötigen einen bedienbaren Rollbereich.")
	_check(main.map_view.size.distance_to(previous_size) <= 1.0, "Die geöffnete Trefferliste verdrängt die Kartenfläche bei 200 % Textgröße.")
	if results_panel != null:
		_check(main.get_viewport_rect().grow(1).encloses(results_panel.get_global_rect()), "Das Suchtrefferpanel ragt bei 200 % Textgröße aus dem Spielfenster.")
	if results_scroll != null:
		var scrollbar: VScrollBar = results_scroll.get_v_scroll_bar()
		_check(scrollbar.max_value > scrollbar.page, "Die lange Trefferliste bietet keinen nutzbaren Scrollweg.")
	await _draw_frame()
	await _shot("atlas-search-200")
	if results_scroll != null:
		for button in buttons:
			_check(not button.disabled and button.get_theme_font_size("font_size") >= 28, "Ein Suchtreffer ist bei 200 % deaktiviert oder wieder zu klein beschriftet.")
			results_scroll.ensure_control_visible(button)
			await _settle_ui()
			_check(results_scroll.get_global_rect().grow(1).encloses(button.get_global_rect()), "Ein vergrößerter Suchtreffer bleibt trotz Scrollen teilweise abgeschnitten.")
	search_field.text = ""
	search_field.text_changed.emit("")
	await _settle_ui()
	_check(main.map_view.size.distance_to(previous_size) <= 1.0, "Das Schließen der Trefferliste verändert die Kartenfläche bei 200 % Textgröße.")
	_check(not results_box.visible and results_box.get_child_count() == 0, "Das Löschen der 200-%-Suchanfrage hinterlässt sichtbare oder alte antippbare Treffer.")
	var source_action := _find_action(widget, "Quellen")
	_check(source_action != null, "Die Quellen des Referenzatlas sind nicht über einen Button erreichbar.")
	if source_action != null:
		source_action.pressed.emit()
		await _settle_ui()
		var close_action := _find_action(widget, "Quellen schließen")
		_check(close_action != null, "Die Quellenanzeige bietet keine erreichbare Schließen-Aktion.")
		if close_action != null:
			var source_panel := _panel_ancestor(close_action)
			var source_scroll := widget.get("_sources_scroll") as ScrollContainer
			_check(source_panel != null and source_panel.is_visible_in_tree(), "Der Quellenbutton öffnet bei 200 % kein sichtbares Quellenpanel.")
			_check(source_scroll != null, "Lange Quellennachweise benötigen bei großer Schrift einen Rollbereich.")
			_check(_scroll_ancestor(close_action) == null, "Die Schließen-Aktion verschwindet noch mit den langen Quellen im Rollbereich.")
			_check(close_action.get_theme_font_size("font_size") >= 28, "Die feste Schließen-Aktion bleibt bei 200 % zu klein beschriftet.")
			_check_source_descriptions(widget)
			if source_panel != null:
				_check(main.get_viewport_rect().grow(1).encloses(source_panel.get_global_rect()), "Die Quellenanzeige ragt bei 200 % aus dem sichtbaren Spielfenster.")
			_check(main.map_view.size.distance_to(previous_size) <= 1.0, "Die Quellenanzeige verdrängt die Karte bei 200 % Textgröße.")
			await _draw_frame()
			await _shot("atlas-sources-200")
			if source_scroll != null:
				var source_bar := source_scroll.get_v_scroll_bar()
				_check(source_bar.max_value > source_bar.page, "Sämtliche eingebetteten Quellen bieten bei 200 % keinen bedienbaren Scrollweg.")
				source_scroll.scroll_vertical = int(source_bar.max_value)
				await _settle_ui()
				_check(source_panel.get_global_rect().grow(1).encloses(close_action.get_global_rect()), "Quellen schließen ist bei 200 % nach dem Scrollen abgeschnitten.")
			close_action.pressed.emit()
			await _settle_ui()
			_check(source_panel != null and not source_panel.visible, "Die Schließen-Aktion lässt das Quellenpanel geöffnet.")
			_check(main.map_view.size.distance_to(previous_size) <= 1.0, "Das Schließen der Quellenanzeige verschiebt die Kartenfläche.")
	ui.set_text_scale(original_scale)
	await _settle_ui()

func _check_source_descriptions(widget) -> void:
	_check(widget.has_method("_coverage_text"), "Die Quellenanzeige verschweigt die landesweisen Abdeckungslücken.")
	if widget.has_method("_coverage_text"):
		var coverage_text := str(widget._coverage_text())
		for feature in main.map_view.atlas_data.features:
			if str(feature.kind) == "country":
				_check(coverage_text.contains("(%s)" % feature.country), "Die Abdeckungsanzeige lässt ein sichtbares Gebiet aus: %s." % feature.country)
		_check(coverage_text.contains("Lücke") and coverage_text.contains("95 %"), "Abdeckungsgrenze und Lücken werden nicht verständlich genannt.")
		_check(coverage_text.contains("Eine landesweite Gemeinde"), "Monacos eine belegte Commune wird weiter als fehlender Gemeindedatensatz behandelt.")
		_check(coverage_text.contains("tiefere Kommunalebene nicht belegt"), "Zentrale Gebietsverwaltung wird als erfundene kommunale Flächenmessung ausgegeben.")
	var content := widget.get("_sources_content") as Node
	_check(content != null, "Der dynamische Quelleninhalt fehlt.")
	if content == null:
		return
	var displayed := _source_label_text(content)
	for raw in main.map_view.atlas_data.sources:
		if not (raw is Dictionary):
			continue
		var source: Dictionary = raw
		var identifier := str(source.get("id", ""))
		for field in ["id", "date", "license", "attribution", "url", "license_url"]:
			var required := str(source.get(field, ""))
			if not required.is_empty():
				_check(displayed.contains(required), "Quelle %s verliert %s in der Laufzeitanzeige." % [identifier, field])
	_check(widget.has_method("_source_text"), "Die Quellenanzeige besitzt keine gemeinsame dynamische Beschreibung für neue Quelltypen.")
	if not widget.has_method("_source_text"):
		return
	var ons := {"id": "ons-LAD25-UK-BGC", "date": "2025-12", "license": "Open Government Licence v3.0",
		"url": "https://example.org/ons-data", "license_url": "https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/",
		"attribution": "Source: Office for National Statistics licensed under the Open Government Licence v.3.0; Contains OS data © Crown copyright and database right 2025"}
	var ons_text: String = widget._source_text(ons)
	_check(ons_text.contains(str(ons.attribution)), "Der vollständige ONS-Doppelcredit wird gekürzt oder verändert.")
	var swiss := {"id": "gbOpen-CHE-ADM3", "date": "2022", "license": "Federal Office of Topography swisstopo License",
		"url": "https://example.org/swiss-data", "attribution": "Federal Office of Topography swisstopo"}
	_check(str(widget._source_text(swiss)).contains(str(swiss.attribution)), "Die Quellenbeschreibung unterschlägt den swisstopo-Herkunftshinweis.")
	_check(str(widget._source_text({"id": "incomplete-source"})).contains("nicht angegeben"), "Fehlende Quellenmetadaten werden verdeckt oder erfunden.")

func _source_label_text(node: Node) -> String:
	var text := (node as Label).text + "\n" if node is Label else ""
	for child in node.get_children():
		text += _source_label_text(child)
	return text

func _find_action(scope: Node, title: String) -> Button:
	for button in scope.find_children("*", "Button", true, false):
		if button.text == title:
			return button
	return null

func _panel_ancestor(node: Node) -> PanelContainer:
	var ancestor: Node = node.get_parent()
	while ancestor != null:
		if ancestor is PanelContainer:
			return ancestor
		ancestor = ancestor.get_parent()
	return null

func _scroll_ancestor(node: Node) -> ScrollContainer:
	var ancestor: Node = node.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			return ancestor
		ancestor = ancestor.get_parent()
	return null

func _settle_ui() -> void:
	# Schrift, Wortumbruch und die schwebenden Panels sortieren verschachtelt.
	for _frame in 4:
		await get_tree().process_frame

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
