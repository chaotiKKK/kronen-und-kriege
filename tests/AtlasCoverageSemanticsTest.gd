extends Node

class CoverageAtlas extends RefCounted:
	var features: Array = [{"kind": "country", "country": "JO", "name": "Jordanien"}]
	var entry: Dictionary = {"status": "complete", "fraction": 0.95817}
	func coverage_for_country(_country: String) -> Dictionary:
		return entry

class CoverageMap extends RefCounted:
	var atlas_data = CoverageAtlas.new()

func _ready() -> void:
	var map_fixture := CoverageMap.new()
	var widget = load("res://scripts/AtlasSearch.gd").new()
	widget._map = map_fixture
	map_fixture.atlas_data.entry["nonmunicipal_terminal_administration"] = [{
		"id": "geofabrik:JO:5:13376111", "unit_type": "Liwa", "scope": "Ruwaished",
		"municipal_boundary_status": "not-established-by-this-source"}]
	var text := str(widget._coverage_text())
	var failures := 0
	for required in ["95,82 %", "Jordanien (JO)", "staatliche Ortsverwaltung", "Gemeindegrenzen nicht nachgewiesen"]:
		if not text.contains(required):
			push_error("Die Abdeckungsanzeige verschweigt die tatsächliche Rolle: " + required)
			failures += 1
	map_fixture.atlas_data.entry.erase("nonmunicipal_terminal_administration")
	if str(widget._coverage_text()).contains("Gemeindegrenzen nicht nachgewiesen"):
		push_error("Eine gewöhnliche Gemeindemessung erhält einen fremden Einschränkungstext.")
		failures += 1
	var source: Dictionary = {"id": "cy-fixture", "blocks_full_coverage_claim": false,
		"blocks_full_coverage_claim_countries": ["CNM"]}
	var source_text := str(widget._source_text(source))
	for required in ["Gebietsbezogene Prüfgrenze", "CNM"]:
		if not source_text.contains(required):
			push_error("Ein territorialer Quellenvorbehalt wird verschwiegen: " + required)
			failures += 1
	source["blocks_full_coverage_claim_countries"] = []
	if str(widget._source_text(source)).contains("Gebietsbezogene Prüfgrenze"):
		push_error("Eine leere territoriale Liste erzeugt einen falschen Vorbehalt.")
		failures += 1
	widget.free()
	print("ATLASCOVERAGESEMANTICSTEST %s; 8 Prüfungen." % ("FAIL" if failures else "OK"))
	get_tree().quit(1 if failures else 0)
