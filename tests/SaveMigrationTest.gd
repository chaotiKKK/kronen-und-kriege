extends Node
## Save-Migrationstest für Banger Queens.
##
## Beweist:
## 1. Ein Altspielstand ohne schema_version/buildings/victory/legitimacy und
##    ohne die Welle-2/3-Felder wird geladen.
## 2. Alle vorhandenen Altfelder bleiben erhalten; neue Felder bekommen Defaults.
## 3. Ein JSON-Speichern/Laden-Zyklus im Schema 11 liefert exakt denselben Zustand.
## 5. Der Glaube wird aus dem Altstand additiv ergänzt und seine abgeleitete
##    Kirchenmacht manipulationfest validiert.
## 4. validate() und diff() erkennen entfernte Pflichtwerte.
##
## Aufruf: godot --headless --path . res://tests/SaveMigrationTest.tscn
## Exit-Code 0 = bestanden, 1 = fehlgeschlagen.

const DataScript = preload("res://scripts/Data.gd")
const GameScript = preload("res://scripts/Game.gd")
const SaveGame = preload("res://scripts/SaveGame.gd")

var _failed := false
var _checks := 0

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
	h["renown"] = 345
	h["legacies"] = {"war": 2, "crown": 1, "guile": 0}
	h["crest"] = 4
	h["realm"] = "Testreich"
	h["ruler"]["name"] = "Testherrscher"
	h["ruler"]["traits"] = ["Gelehrsam", "Kriegserprobt"]
	h["factions"][0]["power"] = 37
	h["secrets"].append({"id": "s1", "target": 1, "kind": "scandal", "known": true})
	h["claims"].append({"province": "lugdunum", "strength": 2, "expires": 240})
	h["armies"].append({"id": 1, "province": "cantium", "strength": 420, "upkeep": 2, "morale": 91})
	h["fleets"].append({"id": 1, "province": "cantium", "station": "cantium", "ships": 12, "upkeep": 2, "morale": 88})
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
	province["blockade"] = 3
	province["blockade_owner"] = 1

	var v6: Dictionary = source.snapshot()
	_check(v6.has("schema_version") and int(v6["schema_version"]) == SaveGame.CURRENT_VERSION, "Aktuelle Schemaversion fehlt im Snapshot.")
	_check(v6.has("victory") and bool(v6["victory"]) == true, "victory fehlt im Snapshot.")
	_check(int(v6["houses"][2]["legitimacy"]) == 73, "legitimacy fehlt im Snapshot.")
	_check(int(v6["houses"][2]["renown"]) == 345, "renown fehlt im Snapshot.")
	_check(int(v6["houses"][2]["legacies"]["war"]) == 2, "legacies.war fehlt im Snapshot.")
	_check((v6["houses"][2]["vassals"] as Array).size() == 3, "vassals fehlen im Snapshot.")
	_check((v6["houses"][2]["council_effects"] as Dictionary).has("intrigue"), "council_effects fehlen im Snapshot.")
	_check((v6["houses"][2].get("court", null) is Dictionary), "court fehlt im Snapshot.")
	_check(int(v6["houses"][2]["court"]["grandeur"]) == 20, "court.grandeur ist nicht 20.")
	_check((v6["houses"][2]["court"]["relics"] as Array).is_empty(), "court.relics ist nicht leer.")
	_check((v6["houses"][2]["court"].get("amenities", null) is Dictionary), "court.amenities fehlt im Snapshot.")
	for amenity_id in ["table", "chambers", "retinue"]:
		_check(int(v6["houses"][2]["court"]["amenities"][amenity_id]) == 0, "court.amenities.%s ist nicht 0." % amenity_id)
	_check((v6["houses"][2]["factions"] as Array).size() == 2, "factions fehlen im Snapshot.")
	_check(not (v6["houses"][2]["secrets"] as Array).is_empty(), "secrets fehlen im Snapshot.")
	_check(not (v6["houses"][2]["claims"] as Array).is_empty(), "claims fehlen im Snapshot.")
	_check(not (v6["houses"][2]["armies"] as Array).is_empty(), "armies fehlen im Snapshot.")
	_check(not (v6["houses"][2]["fleets"] as Array).is_empty(), "fleets fehlen im Snapshot.")
	_check(int(v6["houses"][2]["truces"]["1"]) == 99, "truces fehlen im Snapshot.")
	var source_province: Dictionary = _find_province(v6["provinces"], str(province["id"]))
	_check(not source_province.is_empty(), "Provinz fehlt im Snapshot.")
	_check(int(source_province["buildings"]["market"]) == 2, "Gebäude market fehlt im Snapshot.")
	_check(int(source_province["defense"]) == 17, "defense fehlt im Snapshot.")
	_check(int(source_province["siege"]) == 8, "siege fehlt im Snapshot.")
	_check(int(source_province["siege_owner"]) == 1, "siege_owner fehlt im Snapshot.")
	_check(int(source_province["blockade"]) == 3, "blockade fehlt im Snapshot.")
	_check(int(source_province["blockade_owner"]) == 1, "blockade_owner fehlt im Snapshot.")

	# --- Altstand: aktuelle Altfelder, aber ohne alle neuen Zusätze ----------
	var legacy: Dictionary = v6.duplicate(true)
	legacy.erase("schema_version")
	legacy.erase("victory")
	for p in legacy["provinces"]:
		p.erase("buildings")
		p.erase("defense")
		p.erase("siege")
		p.erase("siege_owner")
		p.erase("blockade")
		p.erase("blockade_owner")
	for old_house in legacy["houses"]:
		old_house.erase("legitimacy")
		old_house.erase("renown")
		old_house.erase("legacies")
		old_house.erase("vassals")
		old_house.erase("council_effects")
		old_house.erase("factions")
		old_house.erase("secrets")
		old_house.erase("claims")
		old_house.erase("armies")
		old_house.erase("fleets")
		old_house.erase("truces")
		old_house.erase("court")
		old_house.erase("faith")
		if old_house.get("ruler") is Dictionary:
			old_house["ruler"].erase("traits")
		for child in old_house.get("children", []):
			child.erase("education")
	legacy["legacy_marker"] = "muss-erhalten-bleiben"

	# --- Migration und Laden des Altstands ----------------------------------
	var result: Dictionary = SaveGame.migrate(legacy)
	_check(bool(result["ok"]), "Migration meldet Fehler: %s" % "; ".join(result["errors"]))
	var migrated_data: Dictionary = result["data"]
	_check(int(migrated_data["schema_version"]) == SaveGame.CURRENT_VERSION, "Migration setzt aktuelle Schemaversion nicht.")
	_check(migrated_data.has("victory") and bool(migrated_data["victory"]) == false, "victory-Default fehlt.")
	_check(int(migrated_data["houses"][0]["legitimacy"]) == 50, "legitimacy-Default 50 fehlt.")
	_check(int(migrated_data["houses"][0]["renown"]) == 80, "renown-Default 80 fehlt.")
	_check(int(migrated_data["houses"][0]["legacies"]["war"]) == 0, "legacies.war-Default fehlt.")
	_check(int(migrated_data["houses"][0]["legacies"]["guile"]) == 0, "legacies.guile-Default fehlt.")
	_check((migrated_data["houses"][0]["vassals"] as Array).size() == 3, "vassals-Default fehlt.")
	_check(int(migrated_data["houses"][0]["vassals"][0]["level"]) == 1, "vassals-Defaultstufe ist nicht 1.")
	_check(int(migrated_data["houses"][0]["council_effects"]["intrigue"]) == 0, "council_effects-Default fehlt.")
	_check((migrated_data["houses"][0].get("court", null) is Dictionary), "court-Default fehlt.")
	_check(int(migrated_data["houses"][0]["court"]["hall"]) == 0, "court.hall-Default ist nicht 0.")
	_check(int(migrated_data["houses"][0]["court"]["grandeur"]) == 20, "court.grandeur-Default ist nicht 20.")
	_check((migrated_data["houses"][0]["court"].get("amenities", null) is Dictionary), "court.amenities-Default fehlt.")
	for amenity_id in ["table", "chambers", "retinue"]:
		_check(int(migrated_data["houses"][0]["court"]["amenities"][amenity_id]) == 0, "court.amenities.%s-Default ist nicht 0." % amenity_id)
	_check(migrated_data["houses"][0].get("faith", null) is Dictionary, "faith-Default fehlt.")
	_check(str(migrated_data["houses"][0]["faith"]["confession"]) == "sun", "faith.confession-Default ist nicht sun.")
	_check(int(migrated_data["houses"][0]["faith"]["piety"]) == 20, "faith.piety-Default ist nicht 20.")
	_check((migrated_data["houses"][0]["faith"]["holy_sites"] as Array).is_empty(), "faith.holy_sites-Default ist nicht leer.")
	_check(int(migrated_data["houses"][0]["faith"]["church_power"]) == 16, "faith.church_power-Default ist nicht 16.")
	_check(int(migrated_data["houses"][0]["faith"]["heresy"]) == 0, "faith.heresy-Default ist nicht 0.")
	_check(int(migrated_data["houses"][0]["faith"]["reform"]) == 0, "faith.reform-Default ist nicht 0.")
	_check(int(migrated_data["houses"][0]["faith"]["holy_war"]["target"]) == -1, "faith.holy_war.target-Default ist nicht -1.")
	_check(int(migrated_data["houses"][0]["faith"]["holy_war"]["months"]) == 0, "faith.holy_war.months-Default ist nicht 0.")
	_check((migrated_data["houses"][0]["factions"] as Array).size() == 2, "factions-Default fehlt.")
	_check((migrated_data["houses"][0]["secrets"] as Array).is_empty(), "secrets-Default ist nicht leer.")
	_check((migrated_data["houses"][0]["claims"] as Array).is_empty(), "claims-Default ist nicht leer.")
	_check((migrated_data["houses"][0]["armies"] as Array).is_empty(), "armies-Default ist nicht leer.")
	_check((migrated_data["houses"][0]["fleets"] as Array).is_empty(), "fleets-Default ist nicht leer.")
	_check((migrated_data["houses"][0]["truces"] as Dictionary).is_empty(), "truces-Default ist nicht leer.")
	_check(not (migrated_data["houses"][0]["ruler"]["traits"] as Array).is_empty(), "traits-Default fehlt.")
	var migrated_province: Dictionary = _find_province(migrated_data["provinces"], str(province["id"]))
	_check(int(migrated_province["defense"]) == 0, "defense-Default fehlt.")
	_check(int(migrated_province["siege"]) == 0, "siege-Default fehlt.")
	_check(int(migrated_province["siege_owner"]) == -1, "siege_owner-Default fehlt.")
	_check(int(migrated_province["blockade"]) == 0, "blockade-Default fehlt.")
	_check(int(migrated_province["blockade_owner"]) == -1, "blockade_owner-Default fehlt.")
	_check(str(migrated_data.get("legacy_marker", "")) == "muss-erhalten-bleiben", "Unbekanntes Feld ging bei Migration verloren.")

	var loaded = GameScript.new(DataScript, 2)
	_check(loaded.restore(legacy), "Altspielstand wurde nicht geladen.")
	var migrated: Dictionary = loaded.snapshot()
	_check(str(migrated.get("legacy_marker", "")) == "muss-erhalten-bleiben", "Unbekanntes Top-Level-Feld ging beim Laden verloren.")
	_check(int(migrated["houses"][0]["legitimacy"]) == 50, "legitimacy wurde beim Laden nicht mit 50 ergänzt.")
	_check(int(migrated["houses"][0]["renown"]) == 80, "renown wurde beim Laden nicht mit 80 ergänzt.")
	_check(int(migrated["houses"][0]["legacies"]["crown"]) == 0, "legacies wurden beim Laden nicht ergänzt.")
	_check((migrated["houses"][0]["vassals"] as Array).size() == 3, "vassals wurden beim Laden nicht ergänzt.")
	_check(int(migrated["houses"][0]["council_effects"]["intrigue"]) == 0, "council_effects wurden beim Laden nicht ergänzt.")
	_check((migrated["houses"][0].get("court", null) is Dictionary), "court wurde beim Laden nicht ergänzt.")
	_check(int(migrated["houses"][0]["court"]["grandeur"]) == 20, "court.grandeur wurde beim Laden nicht mit 20 ergänzt.")
	_check((migrated["houses"][0]["court"].get("amenities", null) is Dictionary), "court.amenities wurde beim Laden nicht ergänzt.")
	for amenity_id in ["table", "chambers", "retinue"]:
		_check(int(migrated["houses"][0]["court"]["amenities"][amenity_id]) == 0, "court.amenities.%s wurde beim Laden nicht mit 0 ergänzt." % amenity_id)
	_check(migrated["houses"][0].get("faith", null) is Dictionary, "faith wurde beim Laden nicht ergänzt.")
	_check(int(migrated["houses"][0]["faith"]["church_power"]) == 16, "faith.church_power wurde beim Laden nicht mit 16 ergänzt.")
	_check(int(migrated["houses"][0]["faith"]["heresy"]) == 0, "faith.heresy wurde beim Laden nicht mit 0 ergänzt.")
	_check(int(migrated["houses"][0]["faith"]["reform"]) == 0, "faith.reform wurde beim Laden nicht mit 0 ergänzt.")
	_check(int(migrated["houses"][0]["faith"]["holy_war"]["target"]) == -1, "faith.holy_war wurde beim Laden nicht mit -1 ergänzt.")
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
			if key == "council":
				for council_key in old_house[key].keys():
					_assert_same(old_house[key][council_key], new_house[key][council_key], "houses[%d].council.%s" % [i, council_key])
				_check(new_house[key].has("spymaster"), "houses[%d].council.spymaster fehlt additiv." % i)
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

	# --- Schema-11-Roundtrip über echtes JSON --------------------------------
	var encoded: String = JSON.stringify(migrated)
	var parsed = JSON.parse_string(encoded)
	_check(parsed is Dictionary, "JSON-Roundtrip liefert kein Dictionary.")
	var roundtrip = GameScript.new(DataScript, 2)
	_check(roundtrip.restore(parsed), "Schema-11-Stand wurde nicht geladen.")
	var actual: Dictionary = roundtrip.snapshot()
	var roundtrip_errors: Array = SaveGame.diff(migrated, actual)
	_check(roundtrip_errors.is_empty(), "Roundtrip verliert Zustand: %s" % "; ".join(roundtrip_errors))
	_check(SaveGame.validate(actual).is_empty(), "validate() meldet Fehler: %s" % "; ".join(SaveGame.validate(actual)))

	# --- Schema 11 bewahrt Gebäude, Systemfelder und Legitimität --------------
	var direct = GameScript.new(DataScript, 2)
	_check(direct.restore(v6), "Schema-11-Snapshot wurde nicht geladen.")
	var direct_again: Dictionary = direct.snapshot()
	var direct_province: Dictionary = _find_province(direct_again["provinces"], str(province["id"]))
	_check(int(direct_province["buildings"]["market"]) == 2, "Schema 6 verliert market-Gebäude.")
	_check(int(direct_province["defense"]) == 17, "Schema 6 verliert defense.")
	_check(bool(direct_again["victory"]) == true, "Schema 6 verliert victory.")
	_check(int(direct_again["houses"][2]["legitimacy"]) == 73, "Schema 6 verliert legitimacy.")
	_check(int(direct_again["houses"][2]["renown"]) == 345, "Schema 6 verliert renown.")
	_check(int(direct_again["houses"][2]["legacies"]["war"]) == 2, "Schema 11 verliert legacies.")
	_check((direct_again["houses"][2]["vassals"] as Array).size() == 3, "Schema 11 verliert vassals.")
	_check(int(direct_again["houses"][2]["council_effects"]["intrigue"]) == 0, "Schema 11 verliert council_effects.")
	_check(int(direct_again["houses"][2]["court"]["grandeur"]) == 20, "Schema 11 verliert court.grandeur.")
	_check(direct_again["houses"][2].get("faith", null) is Dictionary, "Schema 11 verliert faith.")
	_check(int(direct_again["houses"][2]["faith"]["church_power"]) == 10, "Schema 11 verliert faith.church_power.")
	_check(int(direct_again["houses"][2]["faith"]["heresy"]) == 0, "Schema 11 verliert faith.heresy.")
	_check(int(direct_again["houses"][2]["faith"]["reform"]) == 0, "Schema 11 verliert faith.reform.")
	_check(int(direct_again["houses"][2]["faith"]["holy_war"]["target"]) == -1, "Schema 11 verliert faith.holy_war.")
	_check(int(direct_again["houses"][2]["truces"]["1"]) == 99, "Schema 6 verliert truces.")
	_check((direct_again["houses"][2]["fleets"] as Array).size() == 1, "Schema 6 verliert fleets.")
	var direct_blocked: Dictionary = _find_province(direct_again["provinces"], str(province["id"]))
	_check(int(direct_blocked["blockade"]) == 3, "Schema 6 verliert blockade.")

	# --- Negativkontrolle: entfernte Pflichtfelder müssen auffallen ---------
	var broken: Dictionary = migrated.duplicate(true)
	broken["provinces"][0].erase("dev")
	var loss_errors: Array = SaveGame.diff(migrated, broken)
	_check(not loss_errors.is_empty(), "diff() erkennt entferntes Feld dev nicht.")
	var validation_errors: Array = SaveGame.validate(broken)
	_check(not validation_errors.is_empty(), "validate() erkennt entferntes Feld dev nicht.")
	var manipulated: Dictionary = migrated.duplicate(true)
	manipulated["houses"][0]["faith"]["church_power"] = 99
	_check(not SaveGame.validate(manipulated).is_empty(), "validate() erkennt manipulierte Kirchenmacht nicht.")
	var manipulated_heresy: Dictionary = migrated.duplicate(true)
	manipulated_heresy["houses"][0]["faith"]["heresy"] = 101
	_check(not SaveGame.validate(manipulated_heresy).is_empty(), "validate() erkennt manipulierte Ketzerei nicht.")
	var manipulated_war: Dictionary = migrated.duplicate(true)
	manipulated_war["houses"][0]["faith"]["holy_war"] = {"target": 99, "months": 12}
	_check(not SaveGame.validate(manipulated_war).is_empty(), "validate() erkennt unbekanntes Kriegsziel nicht.")
	print("FELDVERLUST-KONTROLLE: %s" % "; ".join(loss_errors))

	var broken_renown: Dictionary = migrated.duplicate(true)
	broken_renown["houses"][0].erase("renown")
	var renown_errors: Array = SaveGame.diff(migrated, broken_renown)
	_check(not renown_errors.is_empty(), "diff() erkennt entfernten renown nicht.")
	var renown_validation: Array = SaveGame.validate(broken_renown)
	_check(not renown_validation.is_empty(), "validate() erkennt entfernten renown nicht.")
	print("RUHM-KONTROLLE: %s" % "; ".join(renown_errors))

	var broken_legitimacy: Dictionary = migrated.duplicate(true)
	broken_legitimacy["houses"][0].erase("legitimacy")
	var legitimacy_errors: Array = SaveGame.diff(migrated, broken_legitimacy)
	_check(not legitimacy_errors.is_empty(), "diff() erkennt entfernte legitimacy nicht.")
	var legitimacy_validation: Array = SaveGame.validate(broken_legitimacy)
	_check(not legitimacy_validation.is_empty(), "validate() erkennt entfernte legitimacy nicht.")
	print("LEGITIMITÄTS-KONTROLLE: %s" % "; ".join(legitimacy_errors))

	var broken_court: Dictionary = migrated.duplicate(true)
	broken_court["houses"][0]["court"]["grandeur"] = 99
	var court_errors: Array = SaveGame.diff(migrated, broken_court)
	_check(not court_errors.is_empty(), "diff() erkennt manipulierte Hofpracht nicht.")
	var court_validation: Array = SaveGame.validate(broken_court)
	_check(not court_validation.is_empty(), "validate() erkennt manipulierte Hofpracht nicht.")
	print("HOFPRACHT-KONTROLLE: %s" % "; ".join(court_validation))

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
	_check(not bool(future_result["ok"]), "Zukünftiges Schema 119 wurde akzeptiert.")

	if _failed:
		return
	print("SAVEMIGRATIONTEST OK: v1->v11, %d Häuser, %d Provinzen, Altfelder erhalten, legitimacy/renown/legacies/vassals/council/court/faith mit Ketzerei/Reform/Krieg/defense/fleets additiv, JSON-Roundtrip identisch, Feldverlust und Glaubensmanipulation erkannt; %d Prüfungen." % [
		(migrated["houses"] as Array).size(), (migrated["provinces"] as Array).size(), _checks
	])
	get_tree().quit(0)

func _test_legacy_fixture() -> void:
	var file := FileAccess.open("res://tests/fixtures/legacy_v1.json", FileAccess.READ)
	_check(file != null, "Legacy-Fixture fehlt.")
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	_check(parsed is Dictionary, "Legacy-Fixture ist kein JSON-Objekt.")
	var legacy: Dictionary = parsed
	_check(not legacy.has("schema_version"), "Legacy-Fixture ist bereits Schema 11.")
	var loaded = GameScript.new(DataScript, int(legacy.get("player", 0)))
	_check(loaded.restore(legacy), "Echter Altspielstand wurde nicht geladen.")
	var migrated: Dictionary = loaded.snapshot()
	_check(int(migrated["schema_version"]) == SaveGame.CURRENT_VERSION, "Echter Altstand wurde nicht auf aktuelle Schemaversion gehoben.")
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
			if key == "council":
				for council_key in old_house[key].keys():
					_assert_same(old_house[key][council_key], new_house[key][council_key], "FIXTURE.houses[%d].council.%s" % [i, council_key])
				_check(new_house[key].has("spymaster"), "FIXTURE.houses[%d].council.spymaster fehlt additiv." % i)
				continue
			_assert_same(old_house[key], new_house[key], "FIXTURE.houses[%d].%s" % [i, key])
		_check(int(new_house["legitimacy"]) == 50, "FIXTURE.houses[%d].legitimacy ist nicht 50." % i)
		_check((new_house["factions"] as Array).size() == 2, "FIXTURE.houses[%d].factions fehlen." % i)
		_check((new_house["vassals"] as Array).size() == 3, "FIXTURE.houses[%d].vassals fehlen." % i)
		_check((new_house["secrets"] as Array).is_empty(), "FIXTURE.houses[%d].secrets sind nicht leer." % i)
		_check((new_house["fleets"] as Array).is_empty(), "FIXTURE.houses[%d].fleets sind nicht leer." % i)
	for old_province in legacy["provinces"]:
		var new_province: Dictionary = _find_province(migrated["provinces"], str(old_province["id"]))
		_check(not new_province.is_empty(), "FIXTURE-Provinz %s fehlt." % old_province["id"])
		for key in old_province.keys():
			_assert_same(old_province[key], new_province[key], "FIXTURE.provinces[%s].%s" % [old_province["id"], key])
		for building_key in ["market", "barracks", "walls"]:
			_check(int(new_province["buildings"][building_key]) == 0, "FIXTURE.buildings.%s ist nicht 0." % building_key)
		_check(int(new_province["defense"]) == 0, "FIXTURE.defense ist nicht 0.")
		_check(int(new_province["siege_owner"]) == -1, "FIXTURE.siege_owner ist nicht -1.")
		_check(int(new_province["blockade"]) == 0, "FIXTURE.blockade ist nicht 0.")
		_check(int(new_province["blockade_owner"]) == -1, "FIXTURE.blockade_owner ist nicht -1.")
	var roundtrip_parsed = JSON.parse_string(JSON.stringify(migrated))
	_check(roundtrip_parsed is Dictionary, "FIXTURE-JSON-Roundtrip liefert kein Dictionary.")
	var roundtrip = GameScript.new(DataScript, int(legacy.get("player", 0)))
	_check(roundtrip.restore(roundtrip_parsed), "FIXTURE-Schema-11-Stand wurde nicht geladen.")
	var actual: Dictionary = roundtrip.snapshot()
	var errors: Array = SaveGame.diff(migrated, actual)
	_check(errors.is_empty(), "FIXTURE-Roundtrip verliert Zustand: %s" % "; ".join(errors))
	print("ALTSTAND-FIXTURE OK: %d Häuser, %d Provinzen, alle Altfelder erhalten, Schema 11, Systemfelder additiv, Roundtrip identisch." % [
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
	_checks += 1
	if condition:
		return
	if _failed:
		return
	_failed = true
	print("SAVEMIGRATIONTEST FAIL: " + message)
	get_tree().quit(1)
