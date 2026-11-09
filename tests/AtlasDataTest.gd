extends Node
## Prüft den echten eingebetteten Atlas, seine Projektion und Sichtbereichsregeln.
var checks := 0
var failures := 0

func _ready() -> void:
	if not _check(ResourceLoader.exists("res://scripts/AtlasData.gd"), "Der native Atlas-Datenleser fehlt."):
		_finish()
		return
	var atlas = load("res://scripts/AtlasData.gd").new()
	if not _check(atlas.load_data(), "Der eingebettete Atlas ist nicht vollständig lesbar."):
		_finish()
		return
	_check(atlas.project(-12.0, 72.0).distance_to(Vector2.ZERO) < 0.001, "Nordwestliche Projektion ist verschoben.")
	_check(atlas.project(52.0, 33.0).distance_to(Vector2(1200, 760)) < 0.001, "Südöstliche Projektion ist verschoben.")
	var berlin: Vector2 = atlas.project(13.405, 52.52)
	_check(berlin.distance_to(Vector2(476.34375, 379.61026)) < 0.05, "Berlin liegt in der falschen Projektion.")
	var found: Array = atlas.search("Wiesbaden", 8)
	_check(not found.is_empty(), "Wiesbaden fehlt im tatsächlichen Ortsindex.")
	if not found.is_empty():
		_check(str(found[0].name).to_lower().contains("wiesbaden"), "Die genaue Ortsuche wird von unpassenden Treffern verdrängt.")
		_check(found[0].point.distance_to(atlas.project(8.24, 50.08)) < 2.5, "Wiesbaden hat falsche Geokoordinaten.")
	_check(atlas.search("zzzzzz-unbekannter-ort", 8).is_empty(), "Unbekannte Orte liefern erfundene Treffer.")
	_check(atlas.search("", 8).is_empty(), "Leere Suche erzeugt eine unbeschränkte Ortsliste.")
	_check(atlas.search("a", 3).size() <= 3, "Die Suchtreffergrenze wird ignoriert.")
	var germany := Rect2(atlas.project(5.5, 55.5), atlas.project(15.5, 47.0) - atlas.project(5.5, 55.5))
	var regional: Array = atlas.visible_features(germany, 3.0)
	var local: Array = atlas.visible_features(germany, 48.0)
	var wiesbaden_rect := Rect2(Vector2(367, 415), Vector2(25, 25))
	var medium_municipalities := 0
	for feature in atlas.visible_features(wiesbaden_rect, 12.0):
		if str(feature.kind) == "municipality":
			medium_municipalities += 1
	var close_municipalities := 0
	for feature in atlas.visible_features(wiesbaden_rect, 48.0):
		if str(feature.kind) == "municipality":
			close_municipalities += 1
	_check(medium_municipalities == 0, "Gemeindeumrisse überfrachten bereits die mittlere Ortsansicht bei Zoom 12.")
	_check(close_municipalities > 0, "Die kommunale Nahansicht bei Zoom 48 verliert die echten Gemeindegrenzen.")
	var municipalities := 0
	for feature in local:
		_check(feature.bounds.intersects(germany), "Ein vollständig unsichtbarer Umriss gelangt in den Draw-Pfad.")
		if str(feature.kind) == "municipality":
			municipalities += 1
	_check(municipalities > 9000, "Die kommunale Ebene enthält keine vollständigen deutschen Gemeinden.")
	for feature in regional:
		_check(str(feature.kind) not in ["district", "municipality"], "Kommunale Linien überfrachten bereits die Übersicht.")
	_check(atlas.path([-1, 8]).is_empty(), "Negativer Geometrieoffset wird gelesen.")
	_check(atlas.path([0, 2147483647]).is_empty(), "Unvollständiger Geometriepfad wird gelesen.")
	var valid_path := false
	for feature in regional:
		if not feature.paths.is_empty():
			var points: PackedVector2Array = atlas.path(feature.paths[0])
			_check(points.size() == int(feature.paths[0][1]), "Binärpfad und Metadaten widersprechen sich.")
			_check(points.size() >= 2 and is_finite(points[0].x) and is_finite(points[0].y), "Geometrie enthält unbrauchbare Punkte.")
			valid_path = true
			break
	_check(valid_path, "Keine gültige sichtbare Verwaltungsgrenze materialisierbar.")
	_check(not atlas.sources.is_empty(), "Die Laufzeit enthält keine Herkunfts-/Lizenzangaben.")
	_check_unknown_names(atlas)
	_check_spatial_query_contract(atlas)
	_check_shared_query_contract(atlas)
	_check_boundary_line_clipping()
	_check_boundary_path_visibility()
	_check_native_local_role()
	_check_country_coverage(atlas)
	_check_polygon_holes()
	_check_local_area_selection(atlas)
	_check_source_quality_descriptions()
	_finish()

func _check_source_quality_descriptions() -> void:
	var widget = load("res://scripts/AtlasSearch.gd").new()
	var source := {"id": "source-quality-fixture", "blocks_full_coverage_claim": true,
		"coverage_note": "Nur ein geprüfter Teilbestand.",
		"source_geometry_defect_note": "Zwei Quellpolygone ohne Punkte.",
		"administrative_geometry_eligible": false,
		"administrative_ineligibility_note": "Keine belegte Verwaltungsebene.",
		"territorial_scope_note": "Referenzteile ohne neue Gebietskörperschaft.",
		"unit_semantics": {"reference_note": "Datierter Bestand vor der Reform."}}
	var text: String = widget._source_text(source)
	for message in [source.coverage_note, source.source_geometry_defect_note,
			source.administrative_ineligibility_note, source.territorial_scope_note,
			source.unit_semantics.reference_note]:
		_check(text.contains(str(message)), "Die Quellenanzeige verschweigt eine konkrete Einschränkung: %s" % message)
	_check(text.contains("ausgeschlossen"), "Eine Quelle ohne belegte Verwaltungsrolle erscheint ohne ihren Ausschlussstatus.")
	var mixed: String = widget._source_text({"id": "mixed-role-source", "administrative_eligibility_note": "Elf Alt-Belde sind einzeln ausgeschlossen; 74 bleiben als Quellgemeinden erhalten."})
	_check(mixed.contains("Elf Alt-Belde"), "Die Quellenanzeige verschweigt die teilweise Rollenquarantäne eines gemischten Datensatzes.")
	widget.free()

func _check_local_area_selection(atlas) -> void:
	# Die reale Multipart-Gemeinde hat eine größere Gesamtbox als ihr Bezirk.
	# Trotzdem muss die kommunale Fläche in der Nahansicht Vorrang haben.
	var arrifana: Dictionary = atlas.lookup("gbOpen:PRT:ADM3:12082587B11215328965887")
	if _check(not arrifana.is_empty(), "Die reale Gemeinde Arrifana fehlt für die gebietsübergreifende Auswahlprüfung."):
		var selected: Dictionary = atlas.feature_at(arrifana.center, 48.0)
		_check(str(selected.get("id", "")) == str(arrifana.id), "Ein Bezirk mit kleinerer Gesamtbox verdrängt die echte Gemeinde Arrifana bei der Flächenauswahl.")
	var vienna: Dictionary = atlas.feature_at(Vector2(531.9932, 463.3863), 48.0)
	_check(str(vienna.get("kind", "")) == "municipality" and str(vienna.get("country", "")) == "AT", "Die grobe Region Wien verdrängt ihre tatsächliche Gemeinde in der Nahansicht.")
	var regional: Dictionary = atlas.feature_at(Vector2(531.9932, 463.3863), 3.0)
	_check(str(regional.get("kind", "")) == "region", "Die Gemeindeauswahl hebt die maßstabsabhängige regionale Auswahl auf.")

func _check_polygon_holes() -> void:
	var isolated = load("res://scripts/AtlasData.gd").new()
	var points := PackedVector2Array([
		Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10), Vector2(0, 0),
		Vector2(2, 2), Vector2(8, 2), Vector2(8, 8), Vector2(2, 8), Vector2(2, 2),
		Vector2(4, 4), Vector2(6, 4), Vector2(6, 6), Vector2(4, 6), Vector2(4, 4)])
	var bytes := PackedByteArray()
	bytes.resize(points.size() * 8)
	for i in points.size():
		bytes.encode_float(i * 8, points[i].x)
		bytes.encode_float(i * 8 + 4, points[i].y)
	isolated._geometry = bytes
	var feature := {"id": "fixture:enclave", "kind": "municipality", "bounds": Rect2(0, 0, 10, 10), "paths": [[0, 5], [5, 5], [10, 5]]}
	isolated.features = [feature]
	isolated._feature_grids = {"municipality": {}}
	isolated._index_rect(isolated._feature_grids.municipality, feature.bounds, 0)
	_check(not isolated.feature_at(Vector2(1, 1), 48).is_empty(), "Eine echte Außenfläche wird bei der Auswahl ausgelassen.")
	_check(isolated.feature_at(Vector2(3, 3), 48).is_empty(), "Eine Aussparung wird fälschlich der umgebenden Verwaltung zugeschlagen.")
	_check(not isolated.feature_at(Vector2(5, 5), 48).is_empty(), "Eine echte Insel innerhalb einer Aussparung verliert ihre Flächenauswahl.")

func _check_country_coverage(atlas) -> void:
	if not _check(atlas.has_method("coverage_for_country"), "Die Oberfläche kann den gemessenen Abdeckungsstand je Land nicht abfragen."):
		return
	var shared = load("res://scripts/AtlasData.gd").new()
	shared.load_data()
	for feature in atlas.features:
		if str(feature.kind) != "country":
			continue
		var code := str(feature.country)
		var entry: Dictionary = atlas.coverage_for_country(code)
		_check(entry.has("fraction") and entry.has("status"), "Der sichtbare Abdeckungsstand für %s fehlt." % code)
		_check(shared.coverage_for_country(code) == entry, "Eine weitere Atlasinstanz verliert den Abdeckungsstand für %s." % code)
	_check(atlas.coverage_for_country("unbekannt").is_empty(), "Ein unbekanntes Land bekommt erfundene Abdeckungswerte.")

func _check_native_local_role() -> void:
	var isolated = load("res://scripts/AtlasData.gd").new()
	var local := {"id": "native:mahalle", "name": "Test", "kind": "local_admin", "bounds": Rect2(200, 200, 20, 20)}
	isolated.features = [local]
	isolated._feature_grids = {"local_admin": {}}
	isolated._index_rect(isolated._feature_grids.local_admin, local.bounds, 0)
	_check(isolated.visible_features(local.bounds, 12).is_empty(), "Native Ortsverwaltungen erscheinen früher als die vergleichbare lokale Detailstufe.")
	_check(isolated.visible_features(local.bounds, 24).size() == 1, "Eine echte Ortsverwaltung wird in der lokalen Nahansicht ausgeblendet.")

func _check_boundary_line_clipping() -> void:
	var boundaries = load("res://scripts/AtlasBoundaries.gd").new()
	if not _check(boundaries.has_method("clip_line_to_rect"), "Grenzen müssen vor dem Rendern auf den gepufferten Sichtbereich begrenzt werden."):
		boundaries.free()
		return
	var rect := Rect2(10, 10, 20, 20)
	var parts: Array = boundaries.clip_line_to_rect(PackedVector2Array([Vector2(0, 20), Vector2(40, 20)]), rect)
	_check(parts.size() == 1 and parts[0].size() == 2, "Eine schneidende echte Grenze wird entfernt oder künstlich geschlossen.")
	if parts.size() == 1 and parts[0].size() == 2:
		_check(parts[0][0].distance_to(Vector2(10, 20)) < 0.01 and parts[0][1].distance_to(Vector2(30, 20)) < 0.01, "Die Grenze wird an falschen geografischen Schnittpunkten abgeschnitten.")
	_check(boundaries.clip_line_to_rect(PackedVector2Array([Vector2(0, 0), Vector2(5, 5)]), rect).is_empty(), "Vollständig entfernte Linien belasten weiterhin den Renderpfad.")
	var twice: Array = boundaries.clip_line_to_rect(PackedVector2Array([Vector2(0, 15), Vector2(40, 15), Vector2(40, 25), Vector2(0, 25)]), rect)
	_check(twice.size() == 2, "Getrennte Grenzstücke werden über eine künstliche Rechteckkante verbunden.")
	boundaries.free()

func _boundary_path_fixture(with_metadata: bool) -> Dictionary:
	var isolated = load("res://scripts/AtlasData.gd").new()
	# Echte Float32-Geometrie und öffentlicher Atlas-Leser, kein Pfad-Mock.
	var sequences := [
		PackedVector2Array([Vector2(100, 120), Vector2(130, 120)]),
		PackedVector2Array([Vector2(110, 130), Vector2(110.5, 130)]),
		PackedVector2Array([Vector2(600, 600), Vector2(601, 600)]),
		PackedVector2Array([Vector2(120, 125), Vector2(120.75, 125)]),
		PackedVector2Array([Vector2(80, 140), Vector2(160, 140)]),
		PackedVector2Array([Vector2(141, 118), Vector2(146, 118)]),
	]
	var points := PackedVector2Array()
	var references: Array = []
	var bounds: Array = []
	for sequence in sequences:
		references.append([points.size(), sequence.size()])
		var extent := Rect2(sequence[0], Vector2.ZERO)
		for point in sequence:
			extent = extent.expand(point)
		bounds.append([extent.position.x, extent.position.y, extent.size.x, extent.size.y])
		points.append_array(sequence)
	var bytes := PackedByteArray()
	bytes.resize(points.size() * 8)
	for i in points.size():
		bytes.encode_float(i * 8, points[i].x)
		bytes.encode_float(i * 8 + 4, points[i].y)
	isolated._geometry = bytes
	var feature := {"id": "fixture:coastal-country", "kind": "country", "bounds": Rect2(80, 100, 560, 540), "paths": references}
	if with_metadata:
		feature["path_bounds"] = bounds
	isolated.features = [feature]
	isolated._feature_grids = {"country": {}}
	isolated._index_rect(isolated._feature_grids.country, feature.bounds, 0)
	return {"atlas": isolated, "feature": feature, "sequences": sequences, "references": references, "bytes": bytes}

func _boundary_has_path(lines: Array, expected: PackedVector2Array) -> bool:
	for line in lines:
		var actual: PackedVector2Array = line.points
		if actual.size() != expected.size():
			continue
		var matches := true
		for i in actual.size():
			if actual[i].distance_to(expected[i]) > 0.001:
				matches = false
		if matches:
			return true
	return false

func _check_boundary_path_visibility() -> void:
	var viewport_rect := Rect2(100, 100, 40, 40)
	for with_metadata in [true, false]:
		var fixture := _boundary_path_fixture(with_metadata)
		var isolated = fixture.atlas
		var boundaries = load("res://scripts/AtlasBoundaries.gd").new()
		boundaries.update_view(isolated, viewport_rect, 1.0, 1.0, Vector2.ZERO)
		_check(boundaries._lines.size() == 4, "Küstenpfade werden nicht einzeln nach Sichtbereich und 0,75-Pixel-Ausdehnung gefiltert (Metadaten: %s)." % with_metadata)
		_check(_boundary_has_path(boundaries._lines, fixture.sequences[0]), "Eine sichtbare offene Grenzlinie verschwindet oder wird künstlich geschlossen.")
		_check(_boundary_has_path(boundaries._lines, fixture.sequences[3]), "Ein Pfad mit exakt 0,75 Pixel maximaler Ausdehnung wird fälschlich entfernt.")
		_check(_boundary_has_path(boundaries._lines, fixture.sequences[5]), "Der gepufferte Sichtbereich verliert die für den nächsten kleinen Schwenk benötigte Grenze.")
		_check(not _boundary_has_path(boundaries._lines, fixture.sequences[1]), "Ein Küstenpfad unter 0,75 Pixel erzeugt weiterhin ein Draw-Kommando.")
		_check(_boundary_has_path(boundaries._lines, PackedVector2Array([Vector2(92, 140), Vector2(148, 140)])), "Ein teilweiser Küstenpfad wird nicht als echte offene Linie am gepufferten Sichtbereich geschnitten.")
		if with_metadata:
			var tiny: Array = fixture.references[1]
			var distant: Array = fixture.references[2]
			_check(not isolated._paths.has(Vector2i(tiny[0], tiny[1])), "Eine mikroskopische Küstenkomponente wird trotz path_bounds vorab als Floatpfad dekodiert.")
			_check(not isolated._paths.has(Vector2i(distant[0], distant[1])), "Eine unsichtbare Küstenkomponente wird trotz path_bounds vorab als Floatpfad dekodiert.")
		boundaries.update_view(isolated, viewport_rect, 2.0, 2.0, Vector2.ZERO)
		_check(_boundary_has_path(boundaries._lines, fixture.sequences[1]), "Die unverändert gespeicherte kleine Inselkomponente kehrt beim Heranzoomen nicht zurück.")
		boundaries.update_view(isolated, Rect2(590, 590, 40, 40), 48.0, 48.0, Vector2.ZERO)
		_check(_boundary_has_path(boundaries._lines, fixture.sequences[2]), "Eine zuvor unsichtbare Quellkomponente fehlt nach dem geografischen Schwenk.")
		_check(isolated._geometry == fixture.bytes and fixture.feature.paths.size() == 6, "Die Sichtbarkeitsoptimierung löscht kleine Quellpfade oder verändert die eingebetteten Geometriebytes.")
		boundaries.free()

func _check_unknown_names(atlas) -> void:
	var isolated = load("res://scripts/AtlasData.gd").new()
	var unnamed := {"id": "municipality:unknown", "name": "Gemeinde (Name in Quelle fehlt)", "name_known": false, "kind": "municipality"}
	isolated._add_lookup(unnamed, 0)
	isolated._add_lookup({"id": "city:known", "name": "Bekannter Ort", "kind": "city"}, 1)
	_check(isolated.lookup("municipality:unknown") == unnamed, "Ein namenloser Quellpolygon verliert seinen Lookup und damit die ausdrückliche Flächenauswahl.")
	_check(isolated.search("Quelle", 10).is_empty(), "Ein ausdrücklich unbekannter Ortsname erscheint als automatisch gesuchter geografischer Name.")
	_check(isolated.search("Bekannter", 10).size() == 1, "Bestandsdaten ohne name_known-Markierung werden fälschlich aus der Suche entfernt.")
	var unknown_names := {}
	for record in atlas.features:
		if not bool(record.get("name_known", true)):
			_check(not atlas.lookup(str(record.id)).is_empty(), "Ein echter namenloser Quellpolygon wurde aus dem ID-Lookup entfernt.")
			_check(not record.paths.is_empty(), "Ein echter namenloser Quellpolygon verliert seine Flächengeometrie.")
			unknown_names[str(record.name)] = true
	for fallback in unknown_names:
		for match in atlas.search(str(fallback), 100):
			_check(bool(match.get("name_known", true)), "Der Suchindex enthält weiterhin unbekannte Namen als automatische Treffer.")

func _check_spatial_query_contract(atlas) -> void:
	# Unabhängiges Orakel: alle öffentlichen Datensätze direkt nach den
	# dokumentierten Sichtbarkeitsregeln prüfen, ohne irgendeinen Raumindex.
	var rectangles := [
		Rect2(0, 0, 1200, 760),
		Rect2(367, 415, 25, 25),
		Rect2(150, 400, 250, 180),
	]
	for rect in rectangles:
		for zoom in [0.5, 1.0, 1.99, 2.0, 5.99, 6.0, 23.99, 24.0, 48.0]:
			var records: Array = atlas.visible_features(rect, zoom)
			var actual := _ids(records)
			var expected := _expected_feature_ids(atlas.features, rect, zoom)
			_check(actual == expected and records.size() == actual.size(), "Der Verwaltungsindex verändert die sichtbaren Gebiets-IDs bei Zoom %.2f in %s." % [zoom, rect])
		for threshold in [[1.0, 1000000], [1.79, 1000000], [1.8, 350000], [2.99, 350000], [3.0, 80000], [4.99, 80000], [5.0, 20000], [7.99, 20000], [8.0, 0], [48.0, 0]]:
			var zoom: float = float(threshold[0])
			var population: int = int(threshold[1])
			var records: Array = atlas.visible_cities(rect, zoom)
			var actual := _ids(records)
			var expected := _expected_city_ids(atlas.cities, rect, population)
			_check(actual == expected and records.size() == actual.size(), "Der Bevölkerungsindex verändert die sichtbaren Orts-IDs bei Zoom %.2f in %s." % [zoom, rect])

func _check_shared_query_contract(atlas) -> void:
	var shared = load("res://scripts/AtlasData.gd").new()
	if not _check(shared.load_data(), "Eine weitere Atlasinstanz kann die gemeinsamen Daten nicht übernehmen."):
		return
	var rect := Rect2(150, 400, 250, 180)
	for zoom in [4.0, 48.0]:
		_check(_ids(shared.visible_features(rect, zoom)) == _expected_feature_ids(atlas.features, rect, zoom), "Der gemeinsame Cache verliert Verwaltungsindizes bei Zoom %.1f." % zoom)
	for threshold in [[1.0, 1000000], [4.0, 80000], [48.0, 0]]:
		_check(_ids(shared.visible_cities(rect, float(threshold[0]))) == _expected_city_ids(atlas.cities, rect, int(threshold[1])), "Der gemeinsame Cache verliert einen Bevölkerungsindex.")
	var small_city: Dictionary = {}
	for city in atlas.cities:
		if int(city.population) > 0 and int(city.population) < 20000:
			small_city = city
			break
	_check(not small_city.is_empty(), "Die räumliche Auswahlprüfung benötigt einen echten kleinen Ort unter 20.000 Einwohnern.")
	if not small_city.is_empty():
		var best := 0.01 * 0.01
		var expected_id := ""
		for city in atlas.cities:
			var distance: float = city.point.distance_squared_to(small_city.point)
			if distance < best:
				best = distance
				expected_id = str(city.id)
		var nearest: Dictionary = shared.nearest_city(small_city.point, 0.01)
		_check(str(nearest.get("id", "")) == expected_id, "Die räumliche Ortsauswahl verliert kleine Orte durch einen Bevölkerungsfilter.")

func _expected_feature_ids(records: Array, rect: Rect2, zoom: float) -> Dictionary:
	var minimum_zoom := {"country": 1.0, "region": 2.0, "district": 6.0, "municipality": 24.0, "local_admin": 24.0}
	var result := {}
	for record in records:
		if zoom >= float(minimum_zoom.get(str(record.kind), 10.0)) and record.bounds.intersects(rect):
			result[str(record.id)] = true
	return result

func _expected_city_ids(records: Array, rect: Rect2, population: int) -> Dictionary:
	var result := {}
	for record in records:
		if int(record.population) >= population and rect.has_point(record.point):
			result[str(record.id)] = true
	return result

func _ids(records: Array) -> Dictionary:
	var result := {}
	for record in records:
		result[str(record.id)] = true
	return result

func _check(value: bool, message: String) -> bool:
	checks += 1
	if not value:
		failures += 1
		print("ATLASDATATEST FAIL: " + message)
	return value

func _finish() -> void:
	print("ATLASDATATEST %s; %d Prüfungen." % ["OK" if failures == 0 else "FAIL", checks])
	get_tree().quit(0 if failures == 0 else 1)
