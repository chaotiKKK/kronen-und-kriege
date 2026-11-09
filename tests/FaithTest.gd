extends Node
## Glaube, Konfessionen, Frömmigkeit, Kirchenmacht, heilige Stätten,
## Bekehrung, Reliquienkopplung, Ketzerei, Reform, heiliger Krieg, KI und
## Schema-11-Roundtrip.
##
## Aufruf: godot --headless --path . res://tests/FaithTest.tscn
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
	_test_pilgrimage()
	_test_holy_site()
	_test_conversion()
	_test_doctrine()
	_test_derived_power()
	_test_heresy()
	_test_reform()
	_test_holy_war()
	_test_negatives()
	_test_ai_uses_same_commands()
	_test_kernel_and_roundtrip()
	_test_migration()
	if _failed:
		return
	print("FAITHTEST OK: Konfessionen, Frömmigkeit, Kirchenmacht, Stätten, Bekehrung, Ketzerei, Reform, heiliger Krieg, F1-F12, KI, Negativfälle und Schema-11-Roundtrip; %d Prüfungen." % _checks)
	get_tree().quit(0)

func _new_game():
	return GameScript.new(DataScript, 0)

func _test_start() -> void:
	var g = _new_game()
	var f: Dictionary = g.faith()
	_check(not f.is_empty(), "Start hat keinen Glauben.")
	_check(g.faith_confession() == "sun", "Haus 0 startet nicht im Sonnenbund.")
	_check(g.faith_piety() == 20, "Startfrömmigkeit ist nicht 20.")
	_check(g.faith_holy_sites().is_empty(), "Start besitzt bereits heilige Stätten.")
	_check(g.faith_church_power() == 16, "Startkirchenmacht ist nicht 16.")
	_check(g.faith_heresy() == 0, "Startketzerei ist nicht 0.")
	_check(g.faith_reform() == 0, "Startreformstufe ist nicht 0.")
	_check(g.faith_holy_war_target() == -1, "Start hat bereits einen heiligen Krieg.")
	_check(g.faith_piety_gain() == 1, "Startandacht ist nicht 1.")
	_check(int(g.snapshot()["schema_version"]) == SaveGame.CURRENT_VERSION, "Snapshot ist nicht im aktuellen Schema.")
	_check(SaveGame.validate(g.snapshot()).is_empty(), "Schema-11-Snapshot ist ungültig.")

func _test_pilgrimage() -> void:
	var g = _new_game()
	var h: Dictionary = g.house()
	h["gold"] = 1000
	_check(g.can_pilgrimage(), "Wallfahrt mit 1000 Gold ist gesperrt.")
	_check(g.pilgrimage()["ok"], "Wallfahrt scheitert.")
	_check(int(h["gold"]) == 970, "Wallfahrt kostet nicht 30 Gold.")
	_check(g.faith_piety() == 32, "Wallfahrt gibt nicht +12 Frömmigkeit.")
	_check(g.faith_church_power() == 19, "Wallfahrt erhöht die Kirchenmacht nicht.")
	_check(not _find_effect(g, "", "faith_piety").is_empty(), "Wallfahrt erzeugt keinen Frömmigkeitsbeleg.")
	h["gold"] = 0
	_check(not g.pilgrimage()["ok"], "Wallfahrt ohne Gold wurde erlaubt.")

func _test_holy_site() -> void:
	var g = _new_game()
	var h: Dictionary = g.house()
	h["gold"] = 1000
	h["prestige"] = 100
	h["faith"]["piety"] = 50
	g._refresh_faith_power(0)
	var capital := str(h["capital"])
	_check(g.can_consecrate_site(capital), "Hauptstadt ist nicht weihbar.")
	_check(g.consecrate_site(capital)["ok"], "Weihung scheitert.")
	_check(g.faith_site_count() == 1, "Weihung speichert keine Stätte.")
	_check(int(h["gold"]) == 940, "Weihung kostet nicht 60 Gold.")
	_check(g.faith_piety() == 35, "Weihung kostet nicht 15 Frömmigkeit.")
	_check(int(h["prestige"]) == 106, "Weihung gibt nicht +6 Prestige.")
	_check(g.faith_church_power() == 29, "Weihung erhöht die Kirchenmacht nicht um 10.")
	_check(not _find_effect(g, "F4", "prestige").is_empty(), "Weihung erzeugt keinen F4-Beleg.")
	_check(not g.consecrate_site(capital)["ok"], "Doppelte Weihung wurde erlaubt.")
	h["gold"] = 1000
	h["faith"]["piety"] = 50
	g._refresh_faith_power(0)
	g.set_edge_enabled("F4", false)
	_check(not g.consecrate_site(str(g.owned()[1]["id"]))["ok"], "Deaktivierte F4-Kante wurde ignoriert.")
	_check(g.faith_site_count() == 1, "Deaktivierte F4-Kante weihte trotzdem.")

func _test_conversion() -> void:
	var g = _new_game()
	var h: Dictionary = g.house()
	h["gold"] = 1000
	h["prestige"] = 100
	for v in h["vassals"]:
		v["opinion"] = 50
	_check(g.can_convert_faith("moon"), "Wechsel zum Mondorakel ist gesperrt.")
	_check(g.convert_faith("moon")["ok"], "Bekehrung scheitert.")
	_check(g.faith_confession() == "moon", "Bekehrung setzt die Konfession nicht.")
	_check(int(h["gold"]) == 920, "Bekehrung kostet nicht 80 Gold.")
	_check(int(h["prestige"]) == 85, "Bekehrung kostet nicht 15 Prestige.")
	_check(int(h["vassals"][0]["opinion"]) == 44, "Bekehrung senkt die Vasallenmeinung nicht um 6.")
	_check(g.faith_church_power() == 13, "Mondorakel-Kirchenmacht ist nicht 13.")
	_check(not g.convert_faith("moon")["ok"], "Wechsel auf dieselbe Konfession wurde erlaubt.")
	h["gold"] = 0
	_check(not g.convert_faith("earth")["ok"], "Bekehrung ohne Gold wurde erlaubt.")

func _test_doctrine() -> void:
	var g = _new_game()
	var h: Dictionary = g.house()
	h["legitimacy"] = 50
	g.effect_log.clear()
	g._apply_faith_doctrine(0)
	_check(int(h["legitimacy"]) == 51, "Sonnenbund gibt nicht +1 Legitimität.")
	_check(not _find_effect(g, "F1", "legitimacy").is_empty(), "Sonnenbund erzeugt keinen F1-Beleg.")
	h["faith"]["confession"] = "moon"
	g._refresh_faith_power(0)
	var intrigue_before := int(h["council_effects"]["intrigue"])
	g.effect_log.clear()
	g._apply_faith_doctrine(0)
	_check(int(h["council_effects"]["intrigue"]) == intrigue_before + 1, "Mondorakel gibt nicht +1 Intrige.")
	_check(not _find_effect(g, "F2", "council_intrigue").is_empty(), "Mondorakel erzeugt keinen F2-Beleg.")
	h["faith"]["confession"] = "earth"
	g._refresh_faith_power(0)
	h["prestige"] = 10
	g.effect_log.clear()
	g._apply_faith_doctrine(0)
	_check(int(h["prestige"]) == 11, "Erdbund gibt nicht +1 Prestige.")
	_check(not _find_effect(g, "F3", "prestige").is_empty(), "Erdbund erzeugt keinen F3-Beleg.")

func _test_derived_power() -> void:
	var g = _new_game()
	var h: Dictionary = g.house()
	_check(g.faith_church_power() == 16, "Derived-Startwert ist nicht 16.")
	h["gold"] = 1000
	h["prestige"] = 100
	_check(g.forge_relic("crown")["ok"], "Krone lässt sich nicht schmieden.")
	_check(g.forge_relic("blade")["ok"], "Klinge lässt sich nicht schmieden.")
	_check(g.forge_relic("seal")["ok"], "Siegel lässt sich nicht schmieden.")
	_check(g.faith_church_power() == 31, "Drei Reliquien erhöhen die Kirchenmacht nicht um 15.")
	h["faith"]["piety"] = 40
	g._refresh_faith_power(0)
	_check(g.faith_church_power() == 36, "Frömmigkeit 40 erhöht die Kirchenmacht nicht um 5.")
	h["faith"]["piety"] = 100
	h["faith"]["holy_sites"] = [str(g.owned()[0]["id"]), str(g.owned()[1]["id"]), str(g.owned()[2]["id"])]
	g._normalize_faith(h, 0)
	_check(g.faith_church_power() == 81, "Drei Stätten, drei Reliquien und 100 Frömmigkeit ergeben nicht 81.")
	_check(g.faith_church_opinion_gain() == 2, "Kirchenmacht 81 gibt nicht +2 Meinung.")
	for v in h["vassals"]:
		v["opinion"] = 50
	g.effect_log.clear()
	g._apply_faith_church(0)
	_check(int(h["vassals"][0]["opinion"]) == 52, "Kirchenmacht erhöht die Vasallenmeinung nicht um 2.")
	_check(not _find_effect(g, "F5", "vassal_opinion").is_empty(), "Kirchenmacht erzeugt keinen F5-Beleg.")

func _test_heresy() -> void:
	var g = _new_game()
	var h: Dictionary = g.house()
	h["legitimacy"] = 50
	h["faith"]["heresy"] = 0
	for v in h["vassals"]:
		v["opinion"] = 50
	g._refresh_faith_power(0)
	_check(g.faith_heresy_growth() == 4, "Ketzerei wächst bei schwacher Kirche nicht um 4.")
	g._apply_faith_heresy(0)
	_check(g.faith_heresy() == 4, "Ketzerei steigt nicht auf 4.")
	h["faith"]["heresy"] = 65
	g._apply_faith_heresy(0)
	_check(g.faith_heresy() == 69, "Ketzerei steigt nicht auf 69.")
	_check(int(h["legitimacy"]) == 49, "Ketzerei senkt die Legitimität nicht um 1.")
	_check(int(h["vassals"][0]["opinion"]) == 48, "Ketzerei senkt die Vasallenmeinung nicht um 2.")
	h["legitimacy"] = 50
	h["faith"]["heresy"] = 65
	for v in h["vassals"]:
		v["opinion"] = 50
	g.set_edge_enabled("F8", false)
	g._apply_faith_heresy(0)
	_check(int(h["legitimacy"]) == 50, "Deaktivierte F8-Kante senkt die Legitimität trotzdem.")
	_check(int(h["vassals"][0]["opinion"]) == 48, "F9 wirkt bei deaktivierter F8 nicht.")
	g.set_edge_enabled("F8", true)
	h["faith"]["heresy"] = 65
	h["legitimacy"] = 50
	for v in h["vassals"]:
		v["opinion"] = 50
	g.set_edge_enabled("F9", false)
	g._apply_faith_heresy(0)
	_check(int(h["legitimacy"]) == 49, "F8 wirkt bei deaktivierter F9 nicht.")
	_check(int(h["vassals"][0]["opinion"]) == 50, "Deaktivierte F9-Kante senkt die Meinung trotzdem.")
	g.set_edge_enabled("F9", true)
	h["faith"]["heresy"] = 50
	_check(g.faith_is_heretic(), "Ketzerei 50 gilt nicht als ketzerisch.")
	h["gold"] = 2000
	h["prestige"] = 100
	h["faith"]["piety"] = 100
	h["faith"]["holy_sites"] = [str(g.owned()[0]["id"]), str(g.owned()[1]["id"]), str(g.owned()[2]["id"])]
	g._normalize_faith(h, 0)
	g.forge_relic("crown")
	g.forge_relic("blade")
	g.forge_relic("seal")
	_check(g.faith_church_power() == 81, "Kirchenmacht für Ketzerei-Abbau ist nicht 81.")
	_check(g.faith_heresy_growth() == -3, "Starke Kirche senkt die Ketzerei nicht um 3.")

func _test_reform() -> void:
	var g = _new_game()
	var h: Dictionary = g.house()
	h["gold"] = 2000
	h["prestige"] = 200
	h["faith"]["piety"] = 60
	h["faith"]["heresy"] = 20
	for v in h["vassals"]:
		v["opinion"] = 50
	g._refresh_faith_power(0)
	_check(g.faith_church_power() == 26, "Startkirchenmacht für Reform ist nicht 26.")
	_check(g.can_reform_faith(), "Reform bei ausreichenden Mitteln ist gesperrt.")
	_check(int(g.reform_cost()["gold"]) == 100, "Erste Reform kostet nicht 100 Gold.")
	_check(g.reform_faith()["ok"], "Erste Reform scheitert.")
	_check(g.faith_reform() == 1, "Reformstufe ist nicht 1.")
	_check(int(h["gold"]) == 1900, "Reform kostet nicht 100 Gold.")
	_check(int(h["prestige"]) == 190, "Reform kostet nicht 10 Prestige.")
	_check(g.faith_piety() == 35, "Reform kostet nicht 25 Frömmigkeit.")
	_check(g.faith_heresy() == 10, "Reform senkt die Ketzerei nicht um 10.")
	_check(int(h["vassals"][0]["opinion"]) == 46, "Reform senkt die Vasallenmeinung nicht um 4.")
	_check(g.faith_church_power() == 23, "Kirchenmacht nach Reform ist nicht 23.")
	h["faith"]["piety"] = 60
	g._refresh_faith_power(0)
	_check(g.faith_church_power() == 30, "F10 gibt nicht +4 Kirchenmacht je Reformstufe.")
	_check(g.faith_heresy_growth() == 2, "F11 senkt den Ketzerei-Zuwachs nicht um 2.")
	g.set_edge_enabled("F11", false)
	_check(g.faith_heresy_growth() == 4, "Deaktivierte F11-Kante senkt den Ketzerei-Zuwachs trotzdem.")
	g.set_edge_enabled("F11", true)
	h["gold"] = 2000
	h["prestige"] = 200
	h["faith"]["piety"] = 100
	h["faith"]["heresy"] = 10
	_check(g.reform_faith()["ok"], "Zweite Reform scheitert.")
	_check(g.faith_reform() == 2, "Reformstufe ist nicht 2.")
	h["gold"] = 2000
	h["prestige"] = 200
	h["faith"]["piety"] = 100
	_check(g.reform_faith()["ok"], "Dritte Reform scheitert.")
	_check(g.faith_reform() == 3, "Reformstufe ist nicht 3.")
	_check(not g.can_reform_faith(), "Vierte Reform wurde erlaubt.")
	h["gold"] = 2000
	h["prestige"] = 200
	h["faith"]["piety"] = 100
	_check(not g.reform_faith()["ok"], "Reform über Stufe 3 wurde erlaubt.")

func _test_holy_war() -> void:
	var g = _new_game()
	var h: Dictionary = g.house()
	h["gold"] = 1000
	h["prestige"] = 100
	h["faith"]["piety"] = 80
	for v in h["vassals"]:
		v["opinion"] = 50
	var target := 1
	var target_capital := str(g.houses[target]["capital"])
	_check(g.faith_confession(target) != g.faith_confession(0), "Zielhaus ist nicht andersgläubig.")
	_check(g.can_declare_holy_war(target), "Heiliger Krieg gegen Andersgläubige ist gesperrt.")
	_check(g.declare_holy_war(target)["ok"], "Heiliger Krieg scheitert.")
	_check(int(h["gold"]) == 940, "Heiliger Krieg kostet nicht 60 Gold.")
	_check(g.faith_piety() == 60, "Heiliger Krieg kostet nicht 20 Frömmigkeit.")
	_check(int(h["prestige"]) == 90, "Heiliger Krieg kostet nicht 10 Prestige.")
	_check(int(h["vassals"][0]["opinion"]) == 47, "Heiliger Krieg senkt die Vasallenmeinung nicht um 3.")
	_check(g.faith_holy_war_target() == target, "Heiliger Krieg speichert das Ziel nicht.")
	_check(int(g.faith_holy_war()["months"]) == 24, "Heiliger Krieg läuft nicht 24 Monate.")
	_check(g.has_claim(target_capital), "Heiliger Krieg erhebt keinen Anspruch.")
	_check(not g.can_declare_holy_war(2), "Zweiter heiliger Krieg wurde erlaubt.")
	g.province(target_capital)["owner"] = 0
	g._apply_faith_holy_war(0)
	_check(int(h["prestige"]) == 100, "Sieg im heiligen Krieg gibt nicht +10 Prestige.")
	_check(int(h["legitimacy"]) == 55, "Sieg im heiligen Krieg gibt nicht +5 Legitimität.")
	_check(g.faith_holy_war_target() == -1, "Heiliger Krieg endet nach dem Sieg nicht.")
	_check(not _find_effect(g, "F12", "prestige").is_empty(), "Sieg erzeugt keinen F12-Beleg.")
	var g2 = _new_game()
	g2.houses[2]["faith"]["confession"] = "sun"
	g2.houses[2]["faith"]["heresy"] = 0
	_check(not g2.can_declare_holy_war(2), "Heiliger Krieg gegen gleiche Konfession wurde erlaubt.")
	g2.houses[1]["truces"]["0"] = g2._now() + 10
	_check(not g2.can_declare_holy_war(1), "Heiliger Krieg trotz Waffenstillstand wurde erlaubt.")
	var g3 = _new_game()
	g3.house()["faith"]["piety"] = 0
	_check(not g3.can_declare_holy_war(1), "Heiliger Krieg ohne Frömmigkeit wurde erlaubt.")
	var g4 = _new_game()
	var ai: Dictionary = g4.houses[3]
	ai["gold"] = 450
	ai["prestige"] = 40
	ai["faith"]["piety"] = 60
	g4._ai_faith(3)
	_check(g4.faith_holy_war_target(3) >= 0, "KI erklärt keinen heiligen Krieg.")
	_check(int(ai["gold"]) == 390, "KI-Heiliger-Krieg kostet nicht dieselben 60 Gold.")

func _test_negatives() -> void:
	var g = _new_game()
	var h: Dictionary = g.house()
	h["gold"] = 0
	h["faith"]["piety"] = 50
	_check(not g.consecrate_site(str(h["capital"]))["ok"], "Weihung ohne Gold wurde erlaubt.")
	h["gold"] = 1000
	h["faith"]["piety"] = 5
	_check(not g.consecrate_site(str(h["capital"]))["ok"], "Weihung ohne Frömmigkeit wurde erlaubt.")
	_check(not g.convert_faith("unbekannt")["ok"], "Unbekannte Konfession wurde erlaubt.")
	var snap: Dictionary = g.snapshot()
	snap["houses"][0]["faith"]["church_power"] = 99
	_check(not SaveGame.validate(snap).is_empty(), "Manipulierte Kirchenmacht wird nicht erkannt.")
	snap = g.snapshot()
	snap["houses"][0]["faith"]["piety"] = 101
	_check(not SaveGame.validate(snap).is_empty(), "Frömmigkeit über 100 wird nicht erkannt.")
	snap = g.snapshot()
	snap["houses"][0]["faith"]["heresy"] = 101
	_check(not SaveGame.validate(snap).is_empty(), "Ketzerei über 100 wird nicht erkannt.")
	snap = g.snapshot()
	snap["houses"][0]["faith"]["reform"] = 4
	_check(not SaveGame.validate(snap).is_empty(), "Reformstufe über 3 wird nicht erkannt.")
	snap = g.snapshot()
	snap["houses"][0]["faith"]["holy_war"] = {"target": 99, "months": 12}
	_check(not SaveGame.validate(snap).is_empty(), "Unbekanntes Kriegsziel wird nicht erkannt.")

func _test_ai_uses_same_commands() -> void:
	var g = _new_game()
	var ai: Dictionary = g.houses[1]
	ai["gold"] = 300
	ai["prestige"] = 100
	ai["faith"]["piety"] = 80
	g.effect_log.clear()
	g._ai_faith(1)
	_check(int(ai["gold"]) == 240, "KI-Weihung kostet nicht dieselben 60 Gold.")
	_check((ai["faith"]["holy_sites"] as Array).size() == 1, "KI hat keine heilige Stätte geweiht.")
	_check(not _find_effect(g, "F4", "prestige").is_empty(), "KI-Weihung erzeugt keinen F4-Beleg.")
	var ai2: Dictionary = g.houses[2]
	ai2["gold"] = 300
	ai2["faith"]["piety"] = 20
	g.effect_log.clear()
	g._ai_faith(2)
	_check(int(ai2["gold"]) == 270, "KI-Wallfahrt kostet nicht dieselben 30 Gold.")
	_check(int(ai2["faith"]["piety"]) == 32, "KI-Wallfahrt gibt nicht dieselben +12 Frömmigkeit.")

func _test_kernel_and_roundtrip() -> void:
	var g = _new_game()
	var h: Dictionary = g.house()
	h["gold"] = 1000
	h["prestige"] = 100
	h["faith"]["piety"] = 50
	g._refresh_faith_power(0)
	var kernel = KernelScript.new()
	kernel.bind_game(g)
	var pilgrimage: Dictionary = kernel.dispatch({"id": "pilgrimage"})
	_check(bool(pilgrimage["ok"]), "UiKernel routet pilgrimage nicht.")
	_check(g.faith_piety() == 62, "Kernel-Wallfahrt erhöht die Frömmigkeit nicht.")
	var site: Dictionary = kernel.dispatch({"id": "consecrate_site", "province": str(h["capital"])})
	_check(bool(site["ok"]), "UiKernel routet consecrate_site nicht.")
	_check(g.faith_site_count() == 1, "Kernel-Weihung speichert keine Stätte.")
	var convert: Dictionary = kernel.dispatch({"id": "convert_faith", "confession": "moon"})
	_check(bool(convert["ok"]), "UiKernel routet convert_faith nicht.")
	_check(g.faith_confession() == "moon", "Kernel-Bekehrung setzt die Konfession nicht.")
	h["faith"]["heresy"] = 60
	var suppress: Dictionary = kernel.dispatch({"id": "suppress_heresy"})
	_check(bool(suppress["ok"]), "UiKernel routet suppress_heresy nicht.")
	_check(g.faith_heresy() == 35, "Kernel-Ketzergericht senkt die Ketzerei nicht.")
	var reform: Dictionary = kernel.dispatch({"id": "reform_faith"})
	_check(bool(reform["ok"]), "UiKernel routet reform_faith nicht.")
	_check(g.faith_reform() == 1, "Kernel-Reform erhöht die Stufe nicht.")
	var holy_war: Dictionary = kernel.dispatch({"id": "declare_holy_war", "target": 2})
	_check(bool(holy_war["ok"]), "UiKernel routet declare_holy_war nicht.")
	_check(g.faith_holy_war_target() == 2, "Kernel-Heiliger-Krieg speichert das Ziel nicht.")
	var digest: Dictionary = kernel._digest()
	_check(str(digest["confession"]) == "moon", "Digest zeigt die falsche Konfession.")
	_check(int(digest["faith_piety"]) == g.faith_piety(), "Digest zeigt die falsche Frömmigkeit.")
	_check(int(digest["church_power"]) == g.faith_church_power(), "Digest zeigt die falsche Kirchenmacht.")
	_check(int(digest["holy_sites"]) == 1, "Digest zeigt die falsche Stättenzahl.")
	_check(int(digest["faith_heresy"]) == g.faith_heresy(), "Digest zeigt die falsche Ketzerei.")
	_check(int(digest["faith_reform"]) == 1, "Digest zeigt die falsche Reformstufe.")
	_check(int(digest["holy_war_target"]) == 2, "Digest zeigt das falsche Kriegsziel.")

	var snapshot: Dictionary = g.snapshot()
	_check(int(snapshot["schema_version"]) == SaveGame.CURRENT_VERSION, "Snapshot ist nicht im aktuellen Schema.")
	_check(SaveGame.validate(snapshot).is_empty(), "Schema-11-Snapshot ist ungültig.")
	var parsed = JSON.parse_string(JSON.stringify(snapshot))
	_check(parsed is Dictionary, "JSON-Roundtrip liefert kein Dictionary.")
	var loaded = _new_game()
	_check(loaded.restore(parsed), "Schema-11-Snapshot ließ sich nicht laden.")
	var diff: Array = SaveGame.diff(snapshot, loaded.snapshot())
	_check(diff.is_empty(), "Schema-11-Roundtrip verliert Zustand: %s" % "; ".join(diff))
	_check(loaded.faith_confession() == "moon", "Konfession überlebt den Roundtrip nicht.")
	_check(loaded.faith_piety() == g.faith_piety(), "Frömmigkeit überlebt den Roundtrip nicht.")
	_check(loaded.faith_church_power() == g.faith_church_power(), "Kirchenmacht überlebt den Roundtrip nicht.")
	_check(loaded.faith_site_count() == 1, "Heilige Stätte überlebt den Roundtrip nicht.")
	_check(loaded.faith_heresy() == g.faith_heresy(), "Ketzerei überlebt den Roundtrip nicht.")
	_check(loaded.faith_reform() == 1, "Reformstufe überlebt den Roundtrip nicht.")
	_check(loaded.faith_holy_war_target() == 2, "Heiliger Krieg überlebt den Roundtrip nicht.")

func _test_migration() -> void:
	var g = _new_game()
	var legacy: Dictionary = g.snapshot()
	for h in legacy["houses"]:
		h.erase("faith")
	legacy["schema_version"] = 9
	var result: Dictionary = SaveGame.migrate(legacy)
	_check(bool(result["ok"]), "Schema-11-Migration meldet Fehler: %s" % "; ".join(result["errors"]))
	var data: Dictionary = result["data"]
	_check(int(data["schema_version"]) == SaveGame.CURRENT_VERSION, "Migration hebt nicht auf aktuelles Schema.")
	for i in data["houses"].size():
		var h: Dictionary = data["houses"][i]
		_check(h.get("faith", null) is Dictionary, "Migration ergänzt keinen Glauben.")
		_check(int(h["faith"]["piety"]) == 20, "Migrationsfrömmigkeit ist nicht 20.")
		_check((h["faith"]["holy_sites"] as Array).is_empty(), "Migrationsstätten sind nicht leer.")
		_check(int(h["faith"]["church_power"]) == [16, 13, 10][i % 3], "Migrationskirchenmacht ist falsch.")
		_check(int(h["faith"]["heresy"]) == 0, "Migrationsketzerei ist nicht 0.")
		_check(int(h["faith"]["reform"]) == 0, "Migrationsreform ist nicht 0.")
		_check(int(h["faith"]["holy_war"]["target"]) == -1, "Migrationskriegsziel ist nicht -1.")
		_check(int(h["faith"]["holy_war"]["months"]) == 0, "Migrationskriegsmonate sind nicht 0.")
	_check(SaveGame.validate(data).is_empty(), "Migrationsergebnis ist ungültig.")

func _find_effect(g, edge: String, kind: String) -> Dictionary:
	for entry in g.effect_log:
		if str(entry.get("edge", "")) == edge and str(entry.get("kind", "")) == kind:
			return entry
	return {}

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition or _failed:
		return
	_failed = true
	print("FAITHTEST FAIL: " + message)
	get_tree().quit(1)
