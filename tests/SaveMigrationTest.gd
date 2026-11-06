extends Node
## Save-Migrationstest für Banger Queens.
##
## Beweist:
## 1. Ein Altspielstand ohne schema_version/buildings/victory wird geladen.
## 2. Alle vorhandenen Altfelder bleiben erhalten; neue Felder bekommen Defaults.
## 3. Ein JSON-Speichern/Laden-Zyklus im Schema 2 liefert exakt denselben Zustand.
## 4. validate() und diff() erkennen einen entfernten Pflichtwert.
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
	h["crest"] = 4
	h["realm"] = "Testreich"
	h["ruler"]["name"] = "Testherrscher"
	var owned: Array = source.owned()
	_check(not owned.is_empty(), "Haus 2 besitzt keine Provinz.")
	var province: Dictionary = owned[0]
	province["name"] = "Testland"
	province["dev"] = 7
	province["levy"] = 999
	province["buildings"]["market"] = 2
	province["buildings"]["walls"] = 1

	var v2: Dictionary = source.snapshot()
	_check(v2.has("schema_version") and int(v2["schema_version"]) == 2, "Schema 2 fehlt im Snapshot.")
	_check(v2.has("victory") and bool(v2["victory"]) == true, "victory fehlt im Snapshot.")
	var source_province: Dictionary = _find_province(v2["provinces"], str(province["id"]))
	_check(not source_province.is_empty(), "Provinz fehlt im Snapshot.")
	_check(int(source_province["buildings"]["market"]) == 2, "Gebäude market fehlt im Snapshot.")

	# --- Altstand: aktuelle Altfelder, aber ohne Schema-2-Zusätze ------------
	var legacy: Dictionary = v2.duplicate(true)
	legacy.erase("schema_version")
	legacy.erase("victory")
	for p in legacy["provinces"]:
		p.erase("buildings")
	legacy["legacy_marker"] = "muss-erhalten-bleiben"

	# --- Migration und Laden des Altstands ----------------------------------
	var result: Dictionary = SaveGame.migrate(legacy)
	_check(bool(result["ok"]), "Migration meldet Fehler: %s" % "; ".join(result["errors"]))
	var migrated_data: Dictionary = result["data"]
	_check(int(migrated_data["schema_version"]) == 2, "Migration setzt Schema 2 nicht.")
	_check(migrated_data.has("victory") and bool(migrated_data["victory"]) == false, "victory-Default fehlt.")
	_check(str(migrated_data.get("legacy_marker", "")) == "muss-erhalten-bleiben", "Unbekanntes Feld ging bei Migration verloren.")

	var loaded = GameScript.new(DataScript, 2)
	_check(loaded.restore(legacy), "Altspielstand wurde nicht geladen.")
	var migrated: Dictionary = loaded.snapshot()
	_check(str(migrated.get("legacy_marker", "")) == "muss-erhalten-bleiben", "Unbekanntes Top-Level-Feld ging beim Laden verloren.")

	# Vorhandene Altfelder müssen exakt erhalten sein.
	for key in ["year", "month", "player", "speed", "event_timer", "game_over",
			"log", "pending", "opinion", "cooldowns", "captive", "scandal", "custom"]:
		_assert_same(legacy[key], migrated[key], "Top-Level %s" % key)
	for i in (legacy["houses"] as Array).size():
		var old_house: Dictionary = legacy["houses"][i]
		var new_house: Dictionary = migrated["houses"][i]
		for key in old_house.keys():
			_assert_same(old_house[key], new_house[key], "houses[%d].%s" % [i, key])
	for old_province in legacy["provinces"]:
		var new_province: Dictionary = _find_province(migrated["provinces"], str(old_province["id"]))
		_check(not new_province.is_empty(), "Provinz %s fehlt nach Migration." % old_province["id"])
		for key in old_province.keys():
			_assert_same(old_province[key], new_province[key], "provinces[%s].%s" % [old_province["id"], key])
		_check(new_province.has("buildings"), "buildings fehlt nach Migration bei %s." % old_province["id"])
		for building_key in ["market", "barracks", "walls"]:
			_check(int(new_province["buildings"][building_key]) == 0, "buildings.%s ist nicht 0 bei %s." % [building_key, old_province["id"]])

	# --- Schema-2-Roundtrip über echtes JSON --------------------------------
	var encoded: String = JSON.stringify(migrated)
	var parsed = JSON.parse_string(encoded)
	_check(parsed is Dictionary, "JSON-Roundtrip liefert kein Dictionary.")
	var roundtrip = GameScript.new(DataScript, 2)
	_check(roundtrip.restore(parsed), "Schema-2-Stand wurde nicht geladen.")
	var actual: Dictionary = roundtrip.snapshot()
	var roundtrip_errors: Array = SaveGame.diff(migrated, actual)
	_check(roundtrip_errors.is_empty(), "Roundtrip verliert Zustand: %s" % "; ".join(roundtrip_errors))
	_check(SaveGame.validate(actual).is_empty(), "validate() meldet Fehler: %s" % "; ".join(SaveGame.validate(actual)))

	# --- Schema 2 bewahrt Gebäude und victory ------------------------------
	var direct = GameScript.new(DataScript, 2)
	_check(direct.restore(v2), "Schema-2-Snapshot wurde nicht geladen.")
	var direct_again: Dictionary = direct.snapshot()
	var direct_province: Dictionary = _find_province(direct_again["provinces"], str(province["id"]))
	_check(int(direct_province["buildings"]["market"]) == 2, "Schema 2 verliert market-Gebäude.")
	_check(bool(direct_again["victory"]) == true, "Schema 2 verliert victory.")

	# --- Negativkontrolle: ein entferntes Pflichtfeld muss auffallen --------
	var broken: Dictionary = migrated.duplicate(true)
	broken["provinces"][0].erase("dev")
	var loss_errors: Array = SaveGame.diff(migrated, broken)
	_check(not loss_errors.is_empty(), "diff() erkennt entferntes Feld dev nicht.")
	var validation_errors: Array = SaveGame.validate(broken)
	_check(not validation_errors.is_empty(), "validate() erkennt entferntes Feld dev nicht.")
	print("FELDVERLUST-KONTROLLE: %s" % "; ".join(loss_errors))

	# --- Zukünftige Schemata werden abgelehnt, nicht geraten ---------------
	var future: Dictionary = migrated.duplicate(true)
	future["schema_version"] = 99
	var future_result: Dictionary = SaveGame.migrate(future)
	_check(not bool(future_result["ok"]), "Zukünftiges Schema 99 wurde akzeptiert.")

	if _failed:
		return
	print("SAVEMIGRATIONTEST OK: v1->v2, %d Häuser, %d Provinzen, Altfelder erhalten, JSON-Roundtrip identisch, Feldverlust erkannt." % [
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
	_check(not legacy.has("schema_version"), "Legacy-Fixture ist bereits Schema 2.")
	var loaded = GameScript.new(DataScript, int(legacy.get("player", 0)))
	_check(loaded.restore(legacy), "Echter Altspielstand wurde nicht geladen.")
	var migrated: Dictionary = loaded.snapshot()
	_check(int(migrated["schema_version"]) == 2, "Echter Altspielstand wurde nicht auf Schema 2 gehoben.")
	for key in legacy.keys():
		if key == "houses" or key == "provinces":
			continue
		_assert_same(legacy[key], migrated[key], "FIXTURE.%s" % key)
	for i in (legacy["houses"] as Array).size():
		var old_house: Dictionary = legacy["houses"][i]
		var new_house: Dictionary = migrated["houses"][i]
		for key in old_house.keys():
			_assert_same(old_house[key], new_house[key], "FIXTURE.houses[%d].%s" % [i, key])
	for old_province in legacy["provinces"]:
		var new_province: Dictionary = _find_province(migrated["provinces"], str(old_province["id"]))
		_check(not new_province.is_empty(), "FIXTURE-Provinz %s fehlt." % old_province["id"])
		for key in old_province.keys():
			_assert_same(old_province[key], new_province[key], "FIXTURE.provinces[%s].%s" % [old_province["id"], key])
		for building_key in ["market", "barracks", "walls"]:
			_check(int(new_province["buildings"][building_key]) == 0, "FIXTURE.buildings.%s ist nicht 0." % building_key)
	var roundtrip_parsed = JSON.parse_string(JSON.stringify(migrated))
	_check(roundtrip_parsed is Dictionary, "FIXTURE-JSON-Roundtrip liefert kein Dictionary.")
	var roundtrip = GameScript.new(DataScript, int(legacy.get("player", 0)))
	_check(roundtrip.restore(roundtrip_parsed), "FIXTURE-Schema-2-Stand wurde nicht geladen.")
	var actual: Dictionary = roundtrip.snapshot()
	var errors: Array = SaveGame.diff(migrated, actual)
	_check(errors.is_empty(), "FIXTURE-Roundtrip verliert Zustand: %s" % "; ".join(errors))
	print("ALTSTAND-FIXTURE OK: %d Häuser, %d Provinzen, alle Altfelder erhalten, Schema 2, Roundtrip identisch." % [
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
