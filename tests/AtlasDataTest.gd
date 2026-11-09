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
	_finish()

func _check(value: bool, message: String) -> bool:
	checks += 1
	if not value:
		failures += 1
		print("ATLASDATATEST FAIL: " + message)
	return value

func _finish() -> void:
	print("ATLASDATATEST %s; %d Prüfungen." % ["OK" if failures == 0 else "FAIL", checks])
	get_tree().quit(0 if failures == 0 else 1)
