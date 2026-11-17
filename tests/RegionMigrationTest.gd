extends Node

const Legacy = preload("res://scripts/Data.gd")
const Regions = preload("res://scripts/GameRegionData.gd")
const Game = preload("res://scripts/Game.gd")
const Save = preload("res://scripts/SaveGame.gd")
var checks := 0

func _ready() -> void:
	if not check(ResourceLoader.exists("res://scripts/RegionMigration.gd"), "Regionsmigration fehlt"):
		return
	var migration = load("res://scripts/RegionMigration.gd")
	var original: Dictionary = Game.new(Legacy, 0).snapshot()
	original.schema_version = 12
	original["private_extension"] = {"kept":17}
	original.houses[0]["private_house"] = "erhalten"
	for p in original.provinces:
		p.buildings.market = 1
	original.provinces[0]["private_province"] = 99
	original.provinces[0].siege = 55
	original.houses[0].armies = [{"id":1, "province":"suebia", "strength":123, "morale":77, "upkeep":2}]
	original.houses[0].claims = [{"province":"suebia", "strength":3, "expires":600}]
	original.houses[0].fleets = [{"id":1, "province":"frisia", "station":"frisia", "ships":7, "upkeep":1, "morale":81}]
	var before := JSON.stringify(original)
	var result: Dictionary = migration.migrate_state(original)
	if not check(bool(result.ok), "Vollständiger Altstand migriert: " + str(result.get("errors", []))):
		return
	if not check(JSON.stringify(original) == before, "Eingabestand bleibt byteinhaltlich unverändert"):
		return
	var state: Dictionary = result.data
	if not check(state.provinces.size() == 108 and int(state.schema_version) == 13, "108 Regionen im neuen Schema"):
		return
	var total_levy := 0
	var total_income := 0
	var market_units := 0.0
	var ids := {}
	for p in state.provinces:
		total_levy += int(p.levy)
		total_income += int(p.base_income)
		market_units += float(p.building_effects.market)
		ids[str(p.id)] = true
		if not check(int(p.siege) == 0 and int(p.siege_owner) == -1, "Belagerung zurückgesetzt und berichtet"):
			return
	if not check(total_levy == 24240 and total_income == 740 and absf(market_units - 49.0) < 0.000001, "Truppen, Wirtschaft und Markt-Gesamtwirkung exakt erhalten"):
		return
	if not check(state.private_extension.kept == 17 and state.houses[0].private_house == "erhalten" and state.migration_legacy.provinces[0].private_province == 99, "Erweiterungsdaten und ursprüngliche Provinzen erhalten"):
		return
	for h in state.houses:
		if not check(ids.has(str(h.capital)), "Gültige neue Hauptstadt"):
			return
		for unit in h.armies + h.fleets + h.claims:
			if not check(ids.has(str(unit.province)), "Armeen, Flotten und Ansprüche auf neue IDs gebunden"):
				return
	if not check(state.houses[0].armies[0].strength == 123 and state.houses[0].fleets[0].ships == 7, "Armee- und Flottenstärke erhalten"):
		return
	var repeated: Dictionary = migration.migrate_state(state)
	if not check(bool(repeated.ok) and Save.state_equal(state, repeated.data), "Migration ist idempotent"):
		return
	var corrupt: Dictionary = original.duplicate(true)
	corrupt.provinces.append(corrupt.provinces[0].duplicate(true))
	if not check(not bool(migration.migrate_state(corrupt).ok), "Doppelte Alt-IDs abgewiesen"):
		return
	corrupt = state.duplicate(true)
	corrupt.region_catalog_hash = "fremder Katalog"
	if not check(not bool(migration.migrate_state(corrupt).ok), "Fremder Katalog abgewiesen"):
		return
	corrupt = state.duplicate(true)
	corrupt.provinces[0].base_income = -5
	if not check(not bool(migration.migrate_state(corrupt).ok), "Beschädigte Regionswirtschaft abgewiesen"):
		return
	corrupt = state.duplicate(true)
	corrupt.provinces[0].owner = 999
	if not check(not bool(migration.migrate_state(corrupt).ok), "Unbekannter Regionsbesitzer abgewiesen"):
		return
	var candidate := {"id":"new", "legacy_region_shares":{"a":0.8,"b":0.2}, "legacy_parent_shares":{"a":0.1,"b":0.9}}
	var parents := {"a":{"owner":0},"b":{"owner":1}}
	if not check(migration.owner_for(candidate, parents, {}) == 0, "Besitzerwahl nutzt Anteil an der neuen Region"):
		return
	if not check(migration.owner_for(candidate, parents, {"b":"new"}) == 1, "Einzige enthaltene Hauptstadt hat Vorrang"):
		return
	var runtime := Game.new(Regions, 0)
	if not check(runtime.restore(state), "Migrierte Gebäudedaten in echter Spiellogik geladen"):
		return
	var market_income := 0
	for index in runtime.houses.size():
		var gold := int(runtime.houses[index].gold)
		runtime._apply_market_income(index)
		market_income += int(runtime.houses[index].gold) - gold
	if not check(market_income == 196, "49 alte Märkte erzeugen weiterhin196 Gold"):
		return
	var legacy_runtime := Game.new(Legacy, 0)
	var initial_runtime := Game.new(Regions, 0)
	for index in 9:
		if not check(initial_runtime.court_expected_grandeur(index) == legacy_runtime.court_expected_grandeur(index), "Hofanspruch bleibt je Haus kapazitätsneutral"):
			return
		if not check(initial_runtime.renown_gain(index) == legacy_runtime.renown_gain(index), "Ruhm wächst durch Gebietsteilung nicht"):
			return
	runtime.provinces = [{"id":"own","owner":0}, {"id":"poor","owner":1,"dev":2,"base_income":5,"initial_dev":2,"levy":100,"defense":0}, {"id":"wealthy","owner":1,"dev":4,"initial_dev":4,"base_income":120,"levy":800,"defense":20}]
	runtime.adjacency = {"own":["poor","wealthy"],"poor":["own"],"wealthy":["own"]}
	runtime.houses[0].claims = []
	if not check(runtime._ai_claim_target(0) == "wealthy", "KI bewertet erreichbare Wirtschaftsziele statt der ersten ID"):
		return
	var road_source: Dictionary = original.duplicate(true)
	road_source.roads = [{"from":"gades","to":"corduba","builder":3,"state":"complete","months":0}]
	var with_road: Dictionary = migration.migrate_state(road_source)
	var road_game := Game.new(Regions, 0)
	if not check(bool(with_road.ok) and road_game.restore(with_road.data) and road_game.road_income(3) == 2, "Vorhandene Straßenverbindung und Einkommen bleiben erhalten"):
		return
	var mixed_source: Dictionary = original.duplicate(true)
	var mixed: Dictionary = {}
	for r in Regions.provinces():
		var qualified: Array = []
		for id in r.legacy_region_shares:
			if float(r.legacy_region_shares[id]) >= .2:
				qualified.append(id)
		if qualified.size() >= 2:
			mixed = r
			for p in mixed_source.provinces:
				if str(p.id) == str(qualified[0]):
					p.owner = 0
				elif str(p.id) == str(qualified[1]):
					p.owner = 1
			break
	var with_mixed: Dictionary = migration.migrate_state(mixed_source)
	if not check(not mixed.is_empty() and bool(with_mixed.ok) and with_mixed.report.mixed_regions.has(mixed.id) and not with_mixed.report.compensation_claims.is_empty(), "Gemischte Besitzer erhalten Migrationsbericht und Ausgleichsansprüche"):
		return
	print("REGIONMIGRATIONTEST OK: %d Prüfungen" % checks)
	get_tree().quit(0)

func check(condition: bool, message: String) -> bool:
	checks += 1
	if condition:
		return true
	print("REGIONMIGRATIONTEST FAIL: " + message)
	get_tree().quit(1)
	return false
