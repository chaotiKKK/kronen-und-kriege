extends Node

var checks := 0

func _ready() -> void:
	if not check(ResourceLoader.exists("res://scripts/GameRegionCatalog.gd"), "Regionskatalog fehlt"):
		return
	var script = load("res://scripts/GameRegionCatalog.gd")
	var catalog = script.new()
	if not check(catalog.load_data(), "Realer Katalog lädt: " + str(catalog.error_message)):
		return
	var regions: Array = catalog.regions()
	if not check(regions.size() == 108, "108 eingefrorene Spielregionen"):
		return
	var ids := {}
	for region in regions:
		if not check(not ids.has(region.id), "Eindeutige ID"):
			return
		ids[region.id] = true
		if not check(region.kind == "game_region", "Eigene Spielregionenrolle"):
			return
		var hit: Dictionary = catalog.region_at(region.capital_anchor)
		if not check(str(hit.get("id", "")) == region.id, "Anker per Raumindex wiedergefunden: " + str(region.id)):
			return
		if not check(not region.parts.is_empty(), "Binärgeometrie dekodiert"):
			return
	if not check(catalog.region_at(Vector2(-100, -100)).is_empty(), "Außerhalb kein Treffer"):
		return
	if not check(catalog.query(Rect2(-100, -100, 10, 10)).is_empty(), "Außerhalb keine Kandidaten"):
		return
	var first_id: String = str(regions[0].id)
	regions[0].name = "MUTATED"
	if not check(catalog.get_region(first_id).name != "MUTATED", "Katalog gegen Aufrufermutation geschützt"):
		return
	var geometry := FileAccess.get_file_as_bytes("res://data/game_region_geometry.bin")
	geometry[0] = geometry[0] ^ 1
	var raw := FileAccess.get_file_as_string("res://data/game_regions.json")
	if not check(not catalog.load_bytes(raw, geometry), "Beschädigte Binärgeometrie abgewiesen"):
		return
	if not check(catalog.regions().is_empty(), "Fehlgeschlagener Reload liefert keine alten Regionen"):
		return
	if not check(not catalog.error_message.is_empty(), "Deutsche Fehlerdiagnose vorhanden"):
		return
	print("GAMEREGIONCATALOGTEST OK: %d Prüfungen" % checks)
	get_tree().quit(0)

func check(condition: bool, message: String) -> bool:
	checks += 1
	if condition:
		return true
	print("GAMEREGIONCATALOGTEST FAIL: " + message)
	get_tree().quit(1)
	return false
