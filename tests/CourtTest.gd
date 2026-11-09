extends Node
## Hofpracht, Reliquien, Hofhalle, Ausstattung, Erwartung, Jahreswirkungen,
## KI und Schema-11-Roundtrip.
##
## Aufruf: godot --headless --path . res://tests/CourtTest.tscn
## Exit 0 = bestanden, 1 = fehlgeschlagen.

const DataScript = preload("res://scripts/Data.gd")
const GameScript = preload("res://scripts/Game.gd")
const SaveGame = preload("res://scripts/SaveGame.gd")
const KernelScript = preload("res://scripts/UiKernel.gd")

var _failed := false
var _checks := 0

func _ready() -> void:
	seed(20261109)
	_test_start()
	_test_relics()
	_test_hall()
	_test_amenities()
	_test_expectation()
	_test_annual_court()
	_test_negatives()
	_test_ai()
	_test_kernel_and_roundtrip()
	_test_migration()
	if _failed:
		return
	print("COURTTEST OK: Reliquien, Hofhalle, Hofpracht, Ausstattung, Erwartung, R1-R8, KI, Negativfälle und Schema-11-Roundtrip; %d Prüfungen." % _checks)
	get_tree().quit(0)

func _new_game():
	return GameScript.new(DataScript, 0)

func _test_start() -> void:
	var g = _new_game()
	var h: Dictionary = g.house()
	_check(h.get("court", null) is Dictionary, "Start hat keinen Hof.")
	_check(g.court_grandeur() == 20, "Starthofpracht ist nicht 20.")
	_check(g.court_hall_level() == 0, "Starthalle ist nicht 0.")
	_check(g.court_relics().is_empty(), "Start besitzt bereits Reliquien.")
	_check(g.court_amenity_total() == 0, "Start besitzt bereits Hofausstattung.")
	for amenity_id in g.COURT_AMENITY_ORDER:
		_check(g.court_amenity_level(str(amenity_id)) == 0, "Startausstattung %s ist nicht 0." % amenity_id)
	_check(g.court_amenity_upkeep() == 0, "Startausstattung kostet bereits Unterhalt.")
	var expected := 5 + g.owned().size() * 2 + int(int(h["legitimacy"]) / 5)
	_check(g.court_expected_grandeur() == clampi(expected, 0, 100), "Erwartete Hofpracht ist nicht aus Provinzen und Legitimität abgeleitet.")
	_check(g.court_expectation_delta() == 20 - g.court_expected_grandeur(), "Erwartungsdelta ist falsch.")
	_check(int(g.snapshot()["schema_version"]) == SaveGame.CURRENT_VERSION, "Snapshot ist nicht im aktuellen Schema.")
	_check(SaveGame.validate(g.snapshot()).is_empty(), "Schema-11-Snapshot ist ungültig.")

func _test_relics() -> void:
	var g = _new_game()
	var h: Dictionary = g.house()
	h["gold"] = 1000
	h["prestige"] = 100
	h["legitimacy"] = 50
	var capital: Dictionary = g.province(str(h["capital"]))
	var levy_before: int = int(capital["levy"])
	var crown: Dictionary = g.forge_relic("crown")
	_check(bool(crown["ok"]), "Krone lässt sich nicht schmieden: %s" % str(crown.get("msg", "")))
	_check(g.has_relic("crown"), "Krone fehlt nach dem Schmieden.")
	_check(int(h["gold"]) == 900, "Krone kostet nicht 100 Gold.")
	_check(int(h["prestige"]) == 90, "Krone kostet nicht 10 Prestige.")
	_check(int(h["legitimacy"]) == 60, "Krone erhöht Legitimität nicht um 10.")
	_check(g.court_grandeur() == 35, "Krone erhöht Hofpracht nicht auf 35.")
	_check(not _find_effect(g, "R1", "legitimacy").is_empty(), "Krone erzeugt keinen R1-Beleg.")
	_check(not _find_effect(g, "R1", "court_grandeur").is_empty(), "Krone erzeugt keinen Hofpracht-Beleg.")
	var before_gold: int = int(h["gold"])
	var duplicate: Dictionary = g.forge_relic("crown")
	_check(not bool(duplicate["ok"]), "Zweite Krone wurde erlaubt.")
	_check(int(h["gold"]) == before_gold, "Zweite Krone kostet Gold.")

	var seal: Dictionary = g.forge_relic("seal")
	_check(bool(seal["ok"]), "Siegel lässt sich nicht schmieden.")
	_check(int(h["council_effects"]["intrigue"]) == 2, "Siegel erhöht Intrigenbonus nicht auf 2.")
	_check(g.council_intrigue_percent() > 0, "Siegel verbessert die Intrigenchance nicht.")
	_check(g.court_grandeur() == 50, "Zwei Reliquien ergeben nicht 50 Hofpracht.")
	_check(not _find_effect(g, "R3", "council_intrigue").is_empty(), "Siegel erzeugt keinen R3-Beleg.")

	var blade: Dictionary = g.forge_relic("blade")
	_check(bool(blade["ok"]), "Klinge lässt sich nicht schmieden.")
	_check(int(capital["levy"]) == levy_before + 80, "Klinge erhöht das Hauptstadtaufgebot nicht um 80.")
	_check(g.court_grandeur() == 65, "Drei Reliquien ergeben nicht 65 Hofpracht.")
	_check(not _find_effect(g, "R2", "levy").is_empty(), "Klinge erzeugt keinen R2-Beleg.")
	_check(g.court_prestige_gain() == 2, "Hofpracht 65 gibt nicht +2 Prestige.")
	_check(g.court_opinion_gain() == 1, "Hofpracht 65 gibt nicht +1 Meinung.")

func _test_hall() -> void:
	var g = _new_game()
	var h: Dictionary = g.house()
	h["gold"] = 1000
	h["prestige"] = 100
	var first: Dictionary = g.upgrade_court_hall()
	_check(bool(first["ok"]), "Erster Hallenausbau scheitert: %s" % str(first.get("msg", "")))
	_check(g.court_hall_level() == 1, "Halle erreicht Stufe 1 nicht.")
	_check(int(h["gold"]) == 920, "Stufe 1 kostet nicht 80 Gold.")
	_check(int(h["prestige"]) == 95, "Stufe 1 kostet nicht 5 Prestige.")
	_check(g.court_grandeur() == 35, "Stufe 1 erhöht Hofpracht nicht auf 35.")
	_check(not _find_effect(g, "R4", "court_grandeur").is_empty(), "Halle erzeugt keinen R4-Beleg.")
	var second: Dictionary = g.upgrade_court_hall()
	_check(bool(second["ok"]), "Zweiter Hallenausbau scheitert.")
	_check(int(h["gold"]) == 780, "Stufe 2 kostet nicht 140 Gold.")
	_check(g.court_grandeur() == 50, "Stufe 2 ergibt nicht 50 Hofpracht.")
	var third: Dictionary = g.upgrade_court_hall()
	_check(bool(third["ok"]), "Dritter Hallenausbau scheitert.")
	_check(g.court_grandeur() == 65, "Stufe 3 ergibt nicht 65 Hofpracht.")
	var maxed: Dictionary = g.upgrade_court_hall()
	_check(not bool(maxed["ok"]), "Vierte Hallenstufe wurde erlaubt.")
	_check(int(h["gold"]) == 560, "Maximale Halle zieht weiter Gold ab.")

func _test_amenities() -> void:
	var g = _new_game()
	var h: Dictionary = g.house()
	h["gold"] = 1000
	h["prestige"] = 100
	h["legitimacy"] = 50
	for v in h["vassals"]:
		v["opinion"] = 50
	var capital: Dictionary = g.province(str(h["capital"]))
	var diplomacy_before: int = int(h["ruler"]["diplomacy"])
	var levy_before: int = int(capital["levy"])
	g.effect_log.clear()

	var table: Dictionary = g.upgrade_court_amenity("table")
	_check(bool(table["ok"]), "Tafel lässt sich nicht ausbauen: %s" % str(table.get("msg", "")))
	_check(g.court_amenity_level("table") == 1, "Tafel erreicht Stufe 1 nicht.")
	_check(int(h["gold"]) == 950, "Tafel kostet nicht 50 Gold.")
	_check(g.court_grandeur() == 25, "Tafel erhöht die Hofpracht nicht um 5.")
	_check(g.court_amenity_upkeep() == 8, "Tafel erzeugt nicht 8 Gold Jahresunterhalt.")
	_check(int(h["vassals"][0]["opinion"]) == 52, "Tafel erhöht die Vasallenmeinung nicht um 2.")
	_check(not _find_effect(g, "R7", "gold").is_empty(), "Tafel erzeugt keinen R7-Goldbeleg.")
	_check(not _find_effect(g, "R7", "court_grandeur").is_empty(), "Tafel erzeugt keinen R7-Hofprachtbeleg.")
	_check(not _find_effect(g, "R7", "vassal_opinion").is_empty(), "Tafel erzeugt keinen R7-Meinungsbeleg.")

	var chambers: Dictionary = g.upgrade_court_amenity("chambers")
	_check(bool(chambers["ok"]), "Gemächer lassen sich nicht ausbauen.")
	_check(g.court_amenity_level("chambers") == 1, "Gemächer erreichen Stufe 1 nicht.")
	_check(int(h["gold"]) == 900, "Gemächer kosten nicht 50 Gold.")
	_check(g.court_grandeur() == 30, "Gemächer erhöhen die Hofpracht nicht um 5.")
	_check(int(h["ruler"]["diplomacy"]) == diplomacy_before + 1, "Gemächer erhöhen die Diplomatie nicht.")
	_check(not _find_effect(g, "R7", "ruler_stat").is_empty(), "Gemächer erzeugen keinen R7-Diplomatiebeleg.")

	var retinue: Dictionary = g.upgrade_court_amenity("retinue")
	_check(bool(retinue["ok"]), "Gefolge lässt sich nicht ausbauen.")
	_check(g.court_amenity_level("retinue") == 1, "Gefolge erreicht Stufe 1 nicht.")
	_check(int(h["gold"]) == 850, "Gefolge kostet nicht 50 Gold.")
	_check(g.court_grandeur() == 35, "Gefolge erhöht die Hofpracht nicht um 5.")
	_check(int(capital["levy"]) == levy_before + 40, "Gefolge erhöht das Hauptstadtaufgebot nicht um 40.")
	_check(not _find_effect(g, "R7", "levy").is_empty(), "Gefolge erzeugt keinen R7-Aufgebotsbeleg.")

	var table2: Dictionary = g.upgrade_court_amenity("table")
	_check(bool(table2["ok"]), "Tafel lässt sich nicht auf Stufe 2 ausbauen.")
	_check(int(h["gold"]) == 760, "Tafel Stufe 2 kostet nicht 90 Gold.")
	_check(g.court_grandeur() == 40, "Tafel Stufe 2 erhöht die Hofpracht nicht auf 40.")
	_check(g.court_amenity_upkeep() == 32, "Vier Ausstattungsstufen ergeben nicht 32 Gold Unterhalt.")
	_check(int(h["vassals"][0]["opinion"]) == 54, "Tafel Stufe 2 erhöht die Vasallenmeinung nicht erneut um 2.")

	h["gold"] = 5000
	for amenity_id in g.COURT_AMENITY_ORDER:
		while g.court_amenity_level(str(amenity_id)) < g.COURT_AMENITY_MAX:
			var upgraded: Dictionary = g.upgrade_court_amenity(str(amenity_id))
			_check(bool(upgraded["ok"]), "%s lässt sich nicht bis zur Maximalstufe ausbauen." % amenity_id)
	_check(g.court_amenity_total() == 9, "Ausstattung erreicht nicht insgesamt 9 Stufen.")
	_check(g.court_grandeur() == 65, "Maximale Ausstattung ergibt nicht 65 Hofpracht.")
	_check(g.court_amenity_upkeep() == 72, "Maximale Ausstattung kostet nicht 72 Gold im Jahr.")
	_check(bool(g.court_amenity_info("table")["maxed"]), "Maximale Tafel wird nicht als vollendet gemeldet.")

func _test_expectation() -> void:
	var g = _new_game()
	var h: Dictionary = g.house()
	h["legitimacy"] = 100
	g._normalize_court(h)
	var expected: int = g.court_expected_grandeur()
	_check(expected > g.court_grandeur(), "Testzustand ist nicht unter der Erwartung.")
	h["prestige"] = 10
	for v in h["vassals"]:
		v["opinion"] = 50
	var under: Dictionary = g.court_expectation_effect()
	_check(int(under["prestige"]) < 0, "Untererfüllung erzeugt keinen Prestigemalus.")
	_check(int(under["opinion"]) < 0, "Untererfüllung erzeugt keinen Meinungsmalus.")
	g.effect_log.clear()
	g._apply_court_expectation(0)
	_check(int(h["prestige"]) == maxi(0, 10 + int(under["prestige"])), "Untererfüllung bucht den Prestigemalus nicht.")
	_check(int(h["vassals"][0]["opinion"]) == clampi(50 + int(under["opinion"]), 0, 100), "Untererfüllung bucht den Meinungsmalus nicht.")
	_check(not _find_effect(g, "R8", "prestige").is_empty(), "Untererfüllung erzeugt keinen R8-Prestigebeleg.")
	_check(not _find_effect(g, "R8", "vassal_opinion").is_empty(), "Untererfüllung erzeugt keinen R8-Meinungsbeleg.")

	h["legitimacy"] = 50
	h["court"]["relics"] = ["crown", "blade", "seal"]
	h["court"]["hall"] = 3
	h["court"]["amenities"] = {"table": 3, "chambers": 3, "retinue": 3}
	g._normalize_court(h)
	expected = g.court_expected_grandeur()
	_check(g.court_grandeur() > expected, "Vollausbau ist nicht über der Erwartung.")
	h["prestige"] = 10
	for v in h["vassals"]:
		v["opinion"] = 50
	var over: Dictionary = g.court_expectation_effect()
	_check(int(over["prestige"]) > 0, "Übererfüllung erzeugt keinen Prestigebonus.")
	_check(int(over["opinion"]) > 0, "Übererfüllung erzeugt keinen Meinungsbonus.")
	g.effect_log.clear()
	g._apply_court_expectation(0)
	_check(int(h["prestige"]) == 10 + int(over["prestige"]), "Übererfüllung bucht den Prestigebonus nicht.")
	_check(int(h["vassals"][0]["opinion"]) == clampi(50 + int(over["opinion"]), 0, 100), "Übererfüllung bucht den Meinungsbonus nicht.")
	_check(not _find_effect(g, "R8", "prestige").is_empty(), "Übererfüllung erzeugt keinen R8-Prestigebeleg.")

	h["prestige"] = 10
	for v in h["vassals"]:
		v["opinion"] = 50
	g.set_edge_enabled("R8", false)
	g.effect_log.clear()
	g._apply_court_expectation(0)
	_check(int(h["prestige"]) == 10 and int(h["vassals"][0]["opinion"]) == 50, "Deaktivierte R8-Kante verändert den Hof trotzdem.")
	g.set_edge_enabled("R8", true)

func _test_annual_court() -> void:
	var g = _new_game()
	var h: Dictionary = g.house()
	h["gold"] = 1000
	h["prestige"] = 100
	h["legitimacy"] = 100
	_check(bool(g.upgrade_court_amenity("table")["ok"]), "Tafel für Jahrestest nicht ausbaubar.")
	_check(bool(g.upgrade_court_amenity("chambers")["ok"]), "Gemächer für Jahrestest nicht ausbaubar.")
	var upkeep: int = g.court_amenity_upkeep()
	_check(upkeep == 16, "Jahrestest-Unterhalt ist nicht 16.")
	g.year = -2000
	g.month = 12
	g.effect_log.clear()
	g.advance_month()
	var upkeep_effect: Dictionary = _find_effect_for_house(g, "R7", "gold", 0)
	_check(not upkeep_effect.is_empty(), "Der Jahreswechsel bucht keinen Ausstattungsunterhalt.")
	_check(str(upkeep_effect.get("reason", "")).contains("Unterhalt"), "Der R7-Goldbeleg ist kein Unterhalt.")
	_check(int(upkeep_effect.get("delta", 0)) == -upkeep, "Der Jahresunterhalt ist nicht vollständig abgebucht.")
	var expectation_effect: Dictionary = _find_effect_for_house(g, "R8", "prestige", 0)
	_check(not expectation_effect.is_empty(), "Der Jahreswechsel bucht keine Hofpracht-Erwartung.")
	_check(not _find_effect_for_house(g, "R8", "vassal_opinion", 0).is_empty(), "Der Jahreswechsel bucht keine Erwartungsmeinung.")

func _test_negatives() -> void:
	var g = _new_game()
	var h: Dictionary = g.house()
	h["gold"] = 999
	h["prestige"] = 8
	_check(not g.forge_relic("crown")["ok"], "Krone mit 8 Prestige wurde erlaubt.")
	h["gold"] = 1000
	h["prestige"] = 10
	g.set_edge_enabled("R1", false)
	_check(not g.forge_relic("crown")["ok"], "Deaktivierte R1-Kante wurde ignoriert.")
	_check(not g.has_relic("crown"), "Deaktivierte Kante vergab die Krone.")
	g.set_edge_enabled("R1", true)
	h["gold"] = 50
	h["prestige"] = 5
	_check(not g.upgrade_court_hall()["ok"], "Halle mit 50 Gold wurde erlaubt.")
	h["gold"] = 1000
	h["prestige"] = 100
	g.set_edge_enabled("R4", false)
	_check(not g.upgrade_court_hall()["ok"], "Deaktivierte R4-Kante wurde ignoriert.")
	_check(g.court_hall_level() == 0, "Deaktivierte R4-Kante baute die Halle.")
	g.set_edge_enabled("R4", true)

	h["gold"] = 49
	_check(not g.can_upgrade_court_amenity("table"), "Tafel mit 49 Gold wurde erlaubt.")
	_check(not g.upgrade_court_amenity("table")["ok"], "Tafel mit 49 Gold wurde gebucht.")
	h["gold"] = 1000
	g.set_edge_enabled("R7", false)
	_check(not g.upgrade_court_amenity("table")["ok"], "Deaktivierte R7-Kante wurde ignoriert.")
	_check(g.court_amenity_level("table") == 0, "Deaktivierte R7-Kante baute die Tafel.")
	_check(int(h["gold"]) == 1000, "Deaktivierte R7-Kante zog Gold ab.")
	g.set_edge_enabled("R7", true)

func _test_ai() -> void:
	var g = _new_game()
	for i in range(1, g.houses.size()):
		var h: Dictionary = g.houses[i]
		h["gold"] = 1000
		h["prestige"] = 200
		h["legitimacy"] = 50
	g.effect_log.clear()
	g.run_ai_turn()
	var ai_amenity := false
	for entry in g.effect_log:
		if int(entry.get("house", 0)) != g.player and str(entry.get("edge", "")) == "R7" and str(entry.get("kind", "")) == "court_grandeur":
			ai_amenity = true
			break
	_check(ai_amenity, "Keine KI baut ihre Hofausstattung über R7 aus.")

	var g2 = _new_game()
	for i in range(1, g2.houses.size()):
		var h2: Dictionary = g2.houses[i]
		h2["court"]["amenities"] = {"table": 3, "chambers": 3, "retinue": 3}
		g2._normalize_court(h2)
		h2["gold"] = 1000
		h2["prestige"] = 200
		h2["legitimacy"] = 50
	g2.effect_log.clear()
	g2.run_ai_turn()
	var ai_relic_or_hall := false
	for entry in g2.effect_log:
		if int(entry.get("house", 0)) != g2.player and str(entry.get("edge", "")) in ["R1", "R2", "R3", "R4"]:
			ai_relic_or_hall = true
			break
	_check(ai_relic_or_hall, "Keine KI nutzt nach voller Ausstattung den Reliquien-/Hallenpfad.")

func _test_kernel_and_roundtrip() -> void:
	var g = _new_game()
	var h: Dictionary = g.house()
	h["gold"] = 1000
	h["prestige"] = 100
	var kernel = KernelScript.new()
	kernel.bind_game(g)
	var forge: Dictionary = kernel.dispatch({"id": "forge_relic", "relic": "crown"})
	_check(bool(forge["ok"]), "UiKernel routet forge_relic nicht.")
	_check(g.has_relic("crown"), "UiKernel forge_relic vergab keine Reliquie.")
	var hall: Dictionary = kernel.dispatch({"id": "upgrade_court_hall"})
	_check(bool(hall["ok"]), "UiKernel routet upgrade_court_hall nicht.")
	_check(g.court_hall_level() == 1, "UiKernel-Ausbau erhöht die Halle nicht.")
	var amenity: Dictionary = kernel.dispatch({"id": "upgrade_court_amenity", "amenity": "table"})
	_check(bool(amenity["ok"]), "UiKernel routet upgrade_court_amenity nicht.")
	_check(g.court_amenity_level("table") == 1, "UiKernel-Ausbau erhöht die Tafel nicht.")
	var digest: Dictionary = kernel._digest()
	_check(int(digest["court_grandeur"]) == g.court_grandeur(), "Digest zeigt falsche Hofpracht.")
	_check(int(digest["court_expected"]) == g.court_expected_grandeur(), "Digest zeigt falsche Erwartung.")
	_check(int(digest["court_hall"]) == 1, "Digest zeigt falsche Halle.")
	_check(int(digest["relics"]) == 1, "Digest zeigt falsche Reliquienzahl.")
	_check(int(digest["court_amenities"]) == 1, "Digest zeigt falsche Ausstattungszahl.")
	_check(int(digest["court_upkeep"]) == 8, "Digest zeigt falschen Hofunterhalt.")

	var snapshot: Dictionary = g.snapshot()
	_check(int(snapshot["schema_version"]) == SaveGame.CURRENT_VERSION, "Snapshot ist nicht im aktuellen Schema.")
	_check(SaveGame.validate(snapshot).is_empty(), "Schema-11-Snapshot ist ungültig.")
	var parsed = JSON.parse_string(JSON.stringify(snapshot))
	_check(parsed is Dictionary, "JSON-Roundtrip liefert kein Dictionary.")
	var loaded = _new_game()
	_check(loaded.restore(parsed), "Schema-11-Snapshot ließ sich nicht laden.")
	var diff: Array = SaveGame.diff(snapshot, loaded.snapshot())
	_check(diff.is_empty(), "Schema-11-Roundtrip verliert Zustand: %s" % "; ".join(diff))
	_check(loaded.has_relic("crown"), "Reliquie überlebt den Roundtrip nicht.")
	_check(loaded.court_hall_level() == 1, "Halle überlebt den Roundtrip nicht.")
	_check(loaded.court_amenity_level("table") == 1, "Tafel überlebt den Roundtrip nicht.")
	_check(loaded.court_grandeur() == 55, "Hofpracht überlebt den Roundtrip nicht.")
	_check(loaded.court_amenity_upkeep() == 8, "Ausstattungsunterhalt überlebt den Roundtrip nicht.")
	_check(loaded.court_expected_grandeur() == g.court_expected_grandeur(), "Erwartung überlebt den Roundtrip nicht.")

func _test_migration() -> void:
	var g = _new_game()
	var legacy: Dictionary = g.snapshot()
	legacy["schema_version"] = 10
	for h in legacy["houses"]:
		(h["court"] as Dictionary).erase("amenities")
	var first: Dictionary = legacy["houses"][0]
	first["court"]["relics"] = ["crown"]
	first["court"]["hall"] = 1
	first["court"]["grandeur"] = 50
	var result: Dictionary = SaveGame.migrate(legacy)
	_check(bool(result["ok"]), "Schema-10-Migration meldet Fehler: %s" % "; ".join(result["errors"]))
	var data: Dictionary = result["data"]
	_check(int(data["schema_version"]) == SaveGame.CURRENT_VERSION, "Migration hebt nicht auf aktuelles Schema.")
	for h in data["houses"]:
		_check(h.get("court", null) is Dictionary, "Migration ergänzt keinen Hof.")
		_check(h["court"].get("amenities", null) is Dictionary, "Migration ergänzt keine Ausstattung.")
		for amenity_id in g.COURT_AMENITY_ORDER:
			_check(int(h["court"]["amenities"][str(amenity_id)]) == 0, "Migrationsausstattung %s ist nicht 0." % amenity_id)
	_check((data["houses"][0]["court"]["relics"] as Array).has("crown"), "Migration verliert die Reliquie.")
	_check(int(data["houses"][0]["court"]["hall"]) == 1, "Migration verliert die Halle.")
	_check(int(data["houses"][0]["court"]["grandeur"]) == 50, "Migration berechnet die Hofpracht mit Reliquie und Halle nicht neu.")
	_check(SaveGame.validate(data).is_empty(), "Migrationsergebnis ist ungültig.")

	var loaded = _new_game()
	_check(loaded.restore(legacy), "Schema-10-Altstand wurde nicht geladen.")
	var migrated: Dictionary = loaded.snapshot()
	_check(int(migrated["schema_version"]) == SaveGame.CURRENT_VERSION, "Geladener Altstand ist nicht im aktuellen Schema.")
	_check(loaded.has_relic("crown"), "Geladener Altstand verliert die Reliquie.")
	_check(loaded.court_hall_level() == 1, "Geladener Altstand verliert die Halle.")
	_check(loaded.court_amenity_total() == 0, "Geladener Altstand erhält unerwartete Ausstattung.")
	_check(loaded.court_grandeur() == 50, "Geladener Altstand verliert die Hofpracht.")

func _find_effect(g, edge: String, kind: String) -> Dictionary:
	for entry in g.effect_log:
		if str(entry.get("edge", "")) == edge and str(entry.get("kind", "")) == kind:
			return entry
	return {}

func _find_effect_for_house(g, edge: String, kind: String, house_index: int) -> Dictionary:
	for entry in g.effect_log:
		if int(entry.get("house", -1)) == house_index and str(entry.get("edge", "")) == edge and str(entry.get("kind", "")) == kind:
			return entry
	return {}

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition or _failed:
		return
	_failed = true
	print("COURTTEST FAIL: " + message)
	get_tree().quit(1)
