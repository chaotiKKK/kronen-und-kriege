extends Node
## Save-Migrationstest für Banger Queens.
##
## Beweist:
## 1. Ein Altspielstand ohne schema_version/buildings/victory/legitimacy und
##    ohne die Welle-2/3-Felder wird geladen.
## 2. Alle vorhandenen Altfelder bleiben erhalten; neue Felder bekommen Defaults.
## 3. Ein JSON-Speichern/Laden-Zyklus im Schema 4 liefert exakt denselben Zustand.
## 4. validate() und diff() erkennen entfernte Pflichtwerte.
##
## Aufruf: godot --headless --path . res://tests/SaveMigrationTest.tscn
## Exit-Code 0 = bestanden, 1 = fehlgeschlagen.

const DataScript = preload("res://scripts/Data.gd")
const GameScript = preload("res://scripts/Game.gd")
const SaveGame = preload("res://scripts/SaveGame.gd")

var _failed := false

func _ready() -> void:
	seed(20261106)
	_test_legacy_fixture()

	# --- Quelle: echter Spielzustand mit allen dynamischen Feldern ----------
	var source = GameScript.new(DataScript, 2)
	source.year = -1997
	source.month = 7
	source.speed = 3
	source.event_timer = 4
	source.game_over = false
	source.scandal = 2
	source.victory = true
	source.custom_start = true
	source.log_lines = ["Zeile A", "Zeile B"]
	source.opinion[2] = 17
	source.cooldowns["marry"] = 123
	source.captive = {"house": 1, "name": "Gefangener", "gender": "m", "months": 5}
	var h: Dictionary = source.house()
	h["gold"] = 321
	h["prestige"] = 42
	h["legitimacy"] = 73
	h["crest"] = 4
	h["realm"] = "Testreich"
	h["ruler"]["name"] = "Testherrscher"
	h["ruler"]["traits"] = ["Gelehrsam", "Kriegserprobt"]
	h["factions"][0]["power"] = 37
	h["secrets"].append({"id": "s1", "target": 1, "kind": "scandal", "known": true})
	h["claims"].append({"province": "lugdunum", "strength": 2, "expires": 240})
	h["armies"].append({"id": 1, "province": "cantium", "strength": 420, "upkeep": 2, "morale": 91})
	h["truces"]["1"] = 99
	var owned: Array = source.owned()
	_check(not owned.is_empty(), "Haus 2 besitzt keine Provinz.")
	var province: Dictionary = owned[0]
	province["name"] = "Testland"
	province["dev"] = 7
	province["levy"] = 999
	province["buildings"]["market"] = 2
	province["buildings"]["walls"] = 1
	province["defense"] = 17
	province["siege"] = 8
	province["siege_owner"] = 1

	var v4: Dictionary = source.snapshot()
	_check(v4.has("schema_version") and int(v4["schema_version"]) == 4, "Schema 4 fehlt im Snapshot.")
	_check(v4.has("victory") and bool(v4["victory"]) == true, "victory fehlt im Snapshot.")
	_check(int(v4["houses"][2]["legitimacy"]) == 73, "legitimacy fehlt im Snapshot.")
	_check((v4["houses"][2]["factions"] as Array).size() == 2, "factions fehlen im Snapshot.")
	_check(not (v4["houses"][2]["secrets"] as Array).is_empty(), "secrets fehlen im Snapshot.")
	_check(not (v4["houses"][2]["claims"] as Array).is_empty(), "claims fehlen im Snapshot.")
	_check(not (v4["houses"][2]["armies"] as Array).is_empty(), "armies fehlen im Snapshot.")
	_check(int(v4["houses"][2]["truces"]["1"]) == 99, "truces fehlen im Snapshot.")
	var source_province: Dictionary = _find_province(v4["provinces"], str(province["id"]))
	_check(not source_province.is_empty(), "Provinz fehlt im Snapshot.")
	_check(int(source_province["buildings"]["market"]) == 2, "Gebäude market fehlt im Snapshot.")
	_check(int(source_province["defense"]) == 17, "defense fehlt im Snapshot.")
	_check(int(source_province["siege"]) == 8, "siege fehlt im Snapshot.")
	_check(int(source_province["siege_owner"]) == 1, "siege_owner fehlt im Snapshot.")

	# --- Altstand: aktuelle Altfelder, aber ohne alle neuen Zusätze ----------
	var legacy: Dictionary = v4.duplicate(true)
	legacy.erase("schema_version")
	legacy.erase("victory")
	for p in legacy["provinces"]:
		p.erase("buildings")
		p.erase("defense")
		p.erase("siege")
		p.erase("siege_owner")
	for old_house in legacy["houses"]:
		old_house.erase("legitimacy")
		old_house.erase("factions")
		old_house.erase("secrets")
		old_house.erase("claims")
		old_house.erase("armies")
		old_house.erase("truces")
		if old_house.get("ruler") is Dictionary:
			old_house["ruler"].erase("traits")
		for child in old_house.get("children", []):
			child.erase("education")
	legacy["legacy_marker"] = "muss-erhalten-bleiben"

	# --- Migration und Laden des Altstands ----------------------------------
	var result: Dictionary = SaveGame.migrate(legacy)
	_check(bool(result["ok"]), "Migration meldet Fehler: %s" % "; ".join(result["errors"]))
	var migrated_data: Dictionary = result["data"]
	_check(int(migrated_data["schema_version"]) == 4, "Migration setzt Schema 4 nicht.")
	_check(migrated_data.has("victory") and bool(migrated_data["victory"]) == false, "victory-Default fehlt.")
	_check(int(migrated_data["houses"][0]["legitimacy"]) == 50, "legitimacy-Default 50 fehlt.")
	_check((migrated_data["houses"][0]["factions"] as Array).size() == 2, "factions-Default fehlt.")
	_check((migrated_data["houses"][0]["secrets"] as Array).is_empty(), "secrets-Default ist nicht leer.")
	_check((migrated_data["houses"][0]["claims"] as Array).is_empty(), "claims-Default ist nicht leer.")
	_check((migrated_data["houses"][0]["armies"] as Array).is_empty(), "armies-Default ist nicht leer.")
	_check((migrated_data["houses"][0]["truces"] as Dictionary).is_empty(), "truces-Default ist nicht leer.")
	_check(not (migrated_data["houses"][0]["ruler"]["traits"] as Array).is_empty(), "traits-Default fehlt.")
	var migrated_province: Dictionary = _find_province(migrated_data["provinces"], str(province["id"]))
	_check(int(migrated_province["defense"]) == 0, "defense-Default fehlt.")
	_check(int(migrated_province["siege"]) == 0, "siege-Default fehlt.")
	_check(int(migrated_province["siege_owner"]) == -1, "siege_owner-Default fehlt.")
	_check(str(migrated_data.get("legacy_marker", "")) == "muss-erhalten-bleiben", "Unbekanntes Feld ging bei Migration verloren.")

	var loaded = GameScript.new(DataScript, 2)
	_check(loaded.restore(legacy), "Altspielstand wurde nicht geladen.")
	var migrated: Dictionary = loaded.snapshot()
	_check(str(migrated.get("legacy_marker", "")) == "muss-erhalten-bleiben", "Unbekanntes Top-Level-Feld ging beim Laden verloren.")
	_check(int(migrated["houses"][0]["legitimacy"]) == 50, "legitimacy wurde beim Laden nicht mit 50 ergänzt.")
	_check((migrated["houses"][0]["factions"] as Array).size() == 2, "factions wurden beim Laden nicht ergänzt.")

	# Vorhandene Altfelder müssen exakt erhalten sein.
	for key in ["year", "month", "player", "speed", "event_timer", "game_over",
			"log", "pending", "opinion", "cooldowns", "captive", "scandal", "custom"]:
		_assert_same(legacy[key], migrated[key], "Top-Level %s" % key)
	for i in (legacy["houses"] as Array).size():
		var old_house: Dictionary = legacy["houses"][i]
		var new_house: Dictionary = migrated["houses"][i]
		for key in old_house.keys():
			if key == "children":
				var old_children: Array = old_house[key]
				var new_children: Array = new_house[key]
				_check(old_children.size() == new_children.size(), "houses[%d].children Länge verändert." % i)
				for ci in old_children.size():
					for child_key in old_children[ci].keys():
						_assert_same(old_children[ci][child_key], new_children[ci][child_key], "houses[%d].children[%d].%s" % [i, ci, child_key])
				continue
			if key == "ruler":
				for ruler_key in old_house[key].keys():
					_assert_same(old_house[key][ruler_key], new_house[key][ruler_key], "houses[%d].ruler.%s" % [i, ruler_key])
				continue
			_assert_same(old_house[key], new_house[key], "houses[%d].%s" % [i, key])
	for old_province in legacy["provinces"]:
		var new_province: Dictionary = _find_province(migrated["provinces"], str(old_province["id"]))
		_check(not new_province.is_empty(), "Provinz %s fehlt nach Migration." % old_province["id"])
		for key in old_province.keys():
			_assert_same(old_province[key], new_province[key], "provinces[%s].%s" % [old_province["id"], key])
		_check(new_province.has("buildings"), "buildings fehlt nach Migration bei %s." % old_province["id"])
		for building_key in ["market", "barracks", "walls"]:
			_check(int(new_province["buildings"][building_key]) == 0, "buildings.%s ist nicht 0 bei %s." % [building_key, old_province["id"]])
		_check(int(new_province["defense"]) == 0, "defense ist nicht 0 bei %s." % old_province["id"])

	# --- Schema-4-Roundtrip über echtes JSON --------------------------------
	var encoded: String = JSON.stringify(migrated)
	var parsed = JSON.parse_string(encoded)
	_check(parsed is Dictionary, "JSON-Roundtrip liefert kein Dictionary.")
	var roundtrip = GameScript.new(DataScript, 2)
	_check(roundtrip.restore(parsed), "Schema-4-Stand wurde nicht geladen.")
	var actual: Dictionary = roundtrip.snapshot()
	var roundtrip_errors: Array = SaveGame.diff(migrated, actual)
	_check(roundtrip_errors.is_empty(), "Roundtrip verliert Zustand: %s" % "; ".join(roundtrip_errors))
	_check(SaveGame.validate(actual).is_empty(), "validate() meldet Fehler: %s" % "; ".join(SaveGame.validate(actual)))

	# --- Schema 4 bewahrt Gebäude, Systemfelder und Legitimität --------------
	var direct = GameScript.new(DataScript, 2)
	_check(direct.restore(v4), "Schema-4-Snapshot wurde nicht geladen.")
	var direct_again: Dictionary = direct.snapshot()
	var direct_province: Dictionary = _find_province(direct_again["provinces"], str(province["id"]))
	_check(int(direct_province["buildings"]["market"]) == 2, "Schema 4 verliert market-Gebäude.")
	_check(int(direct_province["defense"]) == 17, "Schema 4 verliert defense.")
	_check(bool(direct_again["victory"]) == true, "Schema 4 verliert victory.")
	_check(int(direct_again["houses"][2]["legitimacy"]) == 73, "Schema 4 verliert legitimacy.")
	_check(int(direct_again["houses"][2]["truces"]["1"]) == 99, "Schema 4 verliert truces.")

	# --- Negativkontrolle: entfernte Pflichtfelder müssen auffallen ---------
	var broken: Dictionary = migrated.duplicate(true)
	broken["provinces"][0].erase("dev")
	var loss_errors: Array = SaveGame.diff(migrated, broken)
	_check(not loss_errors.is_empty(), "diff() erkennt entferntes Feld dev nicht.")
	var validation_errors: Array = SaveGame.validate(broken)
	_check(not validation_errors.is_empty(), "validate() erkennt entferntes Feld dev nicht.")
	print("FELDVERLUST-KONTROLLE: %s" % "; ".join(loss_errors))

	var broken_legitimacy: Dictionary = migrated.duplicate(true)
	broken_legitimacy["houses"][0].erase("legitimacy")
	var legitimacy_errors: Array = SaveGame.diff(migrated, broken_legitimacy)
	_check(not legitimacy_errors.is_empty(), "diff() erkennt entfernte legitimacy nicht.")
	var legitimacy_validation: Array = SaveGame.validate(broken_legitimacy)
	_check(not legitimacy_validation.is_empty(), "validate() erkennt entfernte legitimacy nicht.")
	print("LEGITIMITÄTS-KONTROLLE: %s" % "; ".join(legitimacy_errors))

	var broken_defense: Dictionary = migrated.duplicate(true)
	broken_defense["provinces"][0].erase("defense")
	var defense_errors: Array = SaveGame.diff(migrated, broken_defense)
	_check(not defense_errors.is_empty(), "diff() erkennt entfernte defense nicht.")
	var defense_validation: Array = SaveGame.validate(broken_defense)
	_check(not defense_validation.is_empty(), "validate() erkennt entfernte defense nicht.")
	print("VERTEIDIGUNGS-KONTROLLE: %s" % "; ".join(defense_errors))

	# --- Zukünftige Schemata werden abgelehnt, nicht geraten ---------------
	var future: Dictionary = migrated.duplicate(true)
	future["schema_version"] = 99
	var future_result: Dictionary = SaveGame.migrate(future)
	_check(not bool(future_result["ok"]), "Zukünftiges Schema 99 wurde akzeptiert.")

	if _failed:
		return
	print("SAVEMIGRATIONTEST OK: v1->v4, %d Häuser, %d Provinzen, Altfelder erhalten, legitimacy/factions/defense additiv, JSON-Roundtrip identisch, Feldverlust erkannt." % [
		(migrated["houses"] as Array).size(), (migrated["provinces"] as Array).size()
	])
	get_tree().quit(0)

func _test_legacy_fixture() -> void:
	var file := FileAccess.open("res://tests/fixtures/legacy_v1.json", FileAccess.READ)
	_check(file != null, "Legacy-Fixture fehlt.")
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	_check(parsed is Dictionary, "Legacy-Fixture ist kein JSON-Objekt.")
	var legacy: Dictionary = parsed
	_check(not legacy.has("schema_version"), "Legacy-Fixture ist bereits Schema 4.")
	var loaded = GameScript.new(DataScript, int(legacy.get("player", 0)))
	_check(loaded.restore(legacy), "Echter Altspielstand wurde nicht geladen.")
	var migrated: Dictionary = loaded.snapshot()
	_check(int(migrated["schema_version"]) == 4, "Echter Altspielstand wurde nicht auf Schema 4 gehoben.")
	for key in legacy.keys():
		if key == "houses" or key == "provinces":
			continue
		_assert_same(legacy[key], migrated[key], "FIXTURE.%s" % key)
	for i in (legacy["houses"] as Array).size():
		var old_house: Dictionary = legacy["houses"][i]
		var new_house: Dictionary = migrated["houses"][i]
		for key in old_house.keys():
			if key == "children":
				var old_children: Array = old_house[key]
				var new_children: Array = new_house[key]
				_check(old_children.size() == new_children.size(), "FIXTURE.houses[%d].children Länge verändert." % i)
				for ci in old_children.size():
					for child_key in old_children[ci].keys():
						_assert_same(old_children[ci][child_key], new_children[ci][child_key], "FIXTURE.houses[%d].children[%d].%s" % [i, ci, child_key])
				continue
			if key == "ruler":
				for ruler_key in old_house[key].keys():
					_assert_same(old_house[key][ruler_key], new_house[key][ruler_key], "FIXTURE.houses[%d].ruler.%s" % [i, ruler_key])
				continue
			_assert_same(old_house[key], new_house[key], "FIXTURE.houses[%d].%s" % [i, key])
		_check(int(new_house["legitimacy"]) == 50, "FIXTURE.houses[%d].legitimacy ist nicht 50." % i)
		_check((new_house["factions"] as Array).size() == 2, "FIXTURE.houses[%d].factions fehlen." % i)
		_check((new_house["secrets"] as Array).is_empty(), "FIXTURE.houses[%d].secrets sind nicht leer." % i)
	for old_province in legacy["provinces"]:
		var new_province: Dictionary = _find_province(migrated["provinces"], str(old_province["id"]))
		_check(not new_province.is_empty(), "FIXTURE-Provinz %s fehlt." % old_province["id"])
		for key in old_province.keys():
			_assert_same(old_province[key], new_province[key], "FIXTURE.provinces[%s].%s" % [old_province["id"], key])
		for building_key in ["market", "barracks", "walls"]:
			_check(int(new_province["buildings"][building_key]) == 0, "FIXTURE.buildings.%s ist nicht 0." % building_key)
		_check(int(new_province["defense"]) == 0, "FIXTURE.defense ist nicht 0.")
		_check(int(new_province["siege_owner"]) == -1, "FIXTURE.siege_owner ist nicht -1.")
	var roundtrip_parsed = JSON.parse_string(JSON.stringify(migrated))
	_check(roundtrip_parsed is Dictionary, "FIXTURE-JSON-Roundtrip liefert kein Dictionary.")
	var roundtrip = GameScript.new(DataScript, int(legacy.get("player", 0)))
	_check(roundtrip.restore(roundtrip_parsed), "FIXTURE-Schema-4-Stand wurde nicht geladen.")
	var actual: Dictionary = roundtrip.snapshot()
	var errors: Array = SaveGame.diff(migrated, actual)
	_check(errors.is_empty(), "FIXTURE-Roundtrip verliert Zustand: %s" % "; ".join(errors))
	print("ALTSTAND-FIXTURE OK: %d Häuser, %d Provinzen, alle Altfelder erhalten, Schema 4, Systemfelder additiv, Roundtrip identisch." % [
		(migrated["houses"] as Array).size(), (migrated["provinces"] as Array).size()
	])

func _find_province(provinces: Array, id: String) -> Dictionary:
	for p in provinces:
		if str(p.get("id", "")) == id:
			return p
	return {}

func _assert_same(expected, actual, label: String) -> void:
	var errors: Array = SaveGame.diff(expected, actual, label)
	_check(errors.is_empty(), "Zustandsverlust: %s" % "; ".join(errors))

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	if _failed:
		return
	_failed = true
	print("SAVEMIGRATIONTEST FAIL: " + message)
	get_tree().quit(1)
