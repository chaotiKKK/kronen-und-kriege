extends Node
## Prüft echte Mehrhaus-Simulation und isolierte Spielerperspektiven ohne Netz/GUI.

const DataScript = preload("res://scripts/Data.gd")
const GameScript = preload("res://scripts/Game.gd")
const SaveGameScript = preload("res://scripts/SaveGame.gd")

var _checks := 0
var _failed := false

func _ready() -> void:
	var probe = GameScript.new(DataScript, 0)
	if not probe.has_method("configure_human_houses"):
		_check(false, "Mehrere menschliche Häuser können noch nicht konfiguriert werden.")
		_finish()
		return
	_test_configuration_and_costs()
	_test_personal_actions_and_events()
	_test_world_tick_and_ai()
	_test_resolver_ownership()
	_test_extinction()
	_test_snapshots()
	_test_legacy_event()
	_test_invalid_lan_player_indices()
	_test_passive_guest_infrastructure_and_birth()
	_test_passive_guest_military_and_faith()
	_test_naval_recipient_messages()
	_test_log_limits_privacy_and_roundtrip()
	_finish()

func _new_game():
	var game = GameScript.new(DataScript, 0)
	_check(game.configure_human_houses([0, 1]), "Zwei gültige Menschenhäuser wurden abgelehnt.")
	return game

func _test_configuration_and_costs() -> void:
	var game = GameScript.new(DataScript, 0)
	_check(not game.configure_human_houses([0]), "Eine Person wurde als Mehrspielerpartie akzeptiert.")
	_check(not game.configure_human_houses([0, 0]), "Doppelte Häuser wurden akzeptiert.")
	_check(not game.configure_human_houses([0, 999]), "Ungültiges Haus wurde akzeptiert.")
	_check(not game.configure_human_houses([0, 1.5]), "Gebrochener Hausindex wurde akzeptiert.")
	_check(not game.configure_human_houses([0, 1, 2, 3, 4]), "Mehr als vier Menschen wurden akzeptiert.")
	_check(game.human_houses.is_empty(), "Abgewiesene Konfiguration änderte den Einzelspielermodus.")
	_check(game.configure_human_houses([0, 1]), "Gültige Konfiguration scheiterte.")
	_check(game.is_human_house(0) and game.is_human_house(1) and not game.is_human_house(2), "Menschen- und KI-Häuser werden verwechselt.")
	game.houses[0]["gold"] = 500
	game.houses[1]["gold"] = 600
	var cap0 := str(game.houses[0]["capital"])
	var cap1 := str(game.houses[1]["capital"])
	game.province(cap0)["dev"] = 1
	game.province(cap1)["dev"] = 1
	_check(bool(game.develop(cap0)["ok"]), "Host konnte eigenes Land nicht ausbauen.")
	_check(game.select_player_context(1), "Gastperspektive wurde nicht aktiviert.")
	_check(not bool(game.develop(cap0)["ok"]), "Gast konnte fremdes Land ausbauen.")
	_check(bool(game.develop(cap1)["ok"]), "Gast konnte eigenes Land nicht ausbauen.")
	_check(int(game.houses[0]["gold"]) == 450 and int(game.houses[1]["gold"]) == 550, "Kosten wurden nicht genau einmal vom richtigen Haus abgezogen.")
	_check(not game.select_player_context(-1) and game.player == 1, "Ungültiger Perspektivwechsel veränderte das aktive Haus.")

func _test_personal_actions_and_events() -> void:
	var game = _new_game()
	game.houses[0]["spouse"] = {}
	game.houses[1]["spouse"] = {}
	game.houses[0]["gold"] = 500
	game.houses[1]["gold"] = 500
	game.marry(2)
	game.captive = {"house": 2, "name": "Hostgefangene", "gender": "f", "months": 4}
	game.scandal = 3
	game.opinion[2] = -45
	game._trigger_event()
	var instance0: int = game.pending_event_instance()
	_check(instance0 > 0 and game.has_pending_human_events(), "Hostereignis hat keine Instanz oder wurde nicht erkannt.")
	game.select_player_context(1)
	_check(game._cooldown_left("marry") <= 0 and game.captive.is_empty() and game.scandal == 0 and int(game.opinion[2]) == 0, "Intrigenzustand eines Hauses floss in den Gast über.")
	_check(game.pending_event == null and game.pending_event_instance() == 0, "Hostereignis wurde dem Gast zugeordnet.")
	game.marry(2)
	_check(game._cooldown_left("marry") > 0, "Gast erhielt keinen eigenen Intrigencooldown.")
	game._trigger_event()
	var instance1: int = game.pending_event_instance()
	game.apply_event(0)
	_check(game.pending_event == null and game.pending_event_instance() == instance1, "Ereignisantwort ließ ein Ereignis offen oder verlor die Instanz.")
	game._trigger_event()
	_check(game.pending_event_instance() > instance1, "Wiederholtes Ereignis besitzt keine neue Instanz.")
	game.select_player_context(0)
	_check(game.pending_event != null and game.pending_event_instance() == instance0, "Gastantwort beantwortete das Hostereignis.")
	_check(game.scandal == 3 and int(game.opinion[2]) == -45 and str(game.captive.get("name")) == "Hostgefangene", "Hostperspektive wurde nicht vollständig wiederhergestellt.")
	game.select_player_context(1)
	game.captive = {"house": 3, "name": "Gastgefangene", "gender": "f", "months": 2}
	game.select_player_context(0)
	game.advance_month()
	_check(int(game.captive.get("months")) == 3, "Hostgefangene wurden nicht genau einmal getaktet.")
	game.select_player_context(1)
	_check(int(game.captive.get("months")) == 1, "Gastgefangene wurden nicht genau einmal getaktet.")

func _test_world_tick_and_ai() -> void:
	var game = _new_game()
	for i in game.houses.size():
		var h: Dictionary = game.houses[i]
		h["gold"] = 1000
		h["courtiers"] = []
		h["vassals"] = []
		h["armies"] = []
		h["fleets"] = []
		h["ruler"]["stewardship"] = 8
		h["ruler"]["traits"] = []
		h["ruler"]["age"] = -1000
		h["ruler"]["health"] = 100
		h["laws"]["tax"] = 1
		h["court"]["amenities"] = {"table": 0, "chambers": 0, "retinue": 0}
		h["spouse"] = {}
	for p in game.provinces:
		p["owner"] = 2
		p["buildings"] = {"market": 0, "barracks": 0, "walls": 0}
	for i in [0, 1]:
		var p: Dictionary = game.province(str(game.houses[i]["capital"]))
		p["owner"] = i
		p["dev"] = 1
	game.month = 12
	game.advance_month()
	_check(game.year == -1999 and game.month == 1, "Gemeinsamer Monat/Jahreswechsel wurde mehrfach ausgeführt.")
	_check(int(game.houses[0]["gold"]) == 1006 and int(game.houses[1]["gold"]) == 1006, "Jahreseinkommen wurde nicht exakt einmal pro Haus gezahlt.")
	_check(game.houses[0]["spouse"].is_empty() and game.houses[1]["spouse"].is_empty(), "Menschliche Häuser wurden automatisch verheiratet.")
	var ai_game = _new_game()
	ai_game.houses[0]["gold"] = 1000
	ai_game.houses[1]["gold"] = 1000
	# Gegner dürfen Menschen angreifen. Hier geht es gezielt um deren eigene
	# Rats-/Hofentscheidungen; mittellose Gegner können keine Beute abziehen.
	for index in range(2, ai_game.houses.size()):
		ai_game.houses[index]["gold"] = 0
		ai_game.houses[index]["claims"] = []
		ai_game.houses[index]["armies"] = []
		ai_game.houses[index]["fleets"] = []
	var before0: Dictionary = ai_game.houses[0].duplicate(true)
	var before1: Dictionary = ai_game.houses[1].duplicate(true)
	ai_game.run_ai_turn()
	_check(SaveGameScript.state_equal(before0, ai_game.houses[0]), "KI spielte für das Hosthaus.")
	_check(SaveGameScript.state_equal(before1, ai_game.houses[1]), "KI spielte für das Gasthaus: " + "; ".join(SaveGameScript.diff(before1, ai_game.houses[1])))
	for i in [0, 1]:
		ai_game.select_player_context(i)
		ai_game.pending_event = null
		ai_game.event_timer = 1
	ai_game.select_player_context(0)
	ai_game.advance_month()
	_check(ai_game.pending_event != null, "Hostereignisuhr lief nicht.")
	ai_game.select_player_context(1)
	_check(ai_game.pending_event != null, "Gastereignisuhr lief nicht.")

func _test_resolver_ownership() -> void:
	var game = _new_game()
	game.resolver.apply(game, [{"kind": "opinion", "house": 2, "index": 3, "amount": 20}, {"kind": "scandal", "house": 2, "amount": 2}])
	_check(game.opinion_value(2, 3) == 20 and game.scandal_value(2) == 2, "KI-Effekte wurden dem falschen Haus zugeordnet.")
	_check(game.opinion_value(0, 3) == 0 and game.scandal_value(0) == 0 and game.opinion_value(1, 3) == 0, "KI-Effekte veränderten Menschenzustand.")
	game.resolver.apply(game, [{"kind": "opinion", "house": 1, "index": 3, "amount": -15}])
	game.select_player_context(1)
	_check(int(game.opinion[3]) == -15, "Perspektive zeigt nicht ihre eigene Diplomatie.")
	var legacy = GameScript.new(DataScript, 0)
	legacy.resolver.apply(legacy, [{"kind": "opinion", "house": 2, "index": 3, "amount": 20}])
	_check(int(legacy.opinion[3]) == 20, "Einzelspieler-Legacyverhalten wurde geändert.")

func _test_extinction() -> void:
	var game = _new_game()
	game.houses[1]["children"] = []
	game.houses[1]["heir"] = ""
	game._succession(1)
	_check(not game.game_over and not game.all_human_houses_over(), "Gastverlust beendete das Hosthaus.")
	game.select_player_context(1)
	_check(game.game_over, "Erbloses Menschenhaus erhielt einen KI-Ersatzherrscher.")
	game.month = 12
	game.houses[2]["gold"] = 200
	game.houses[2]["prestige"] = 0
	game.houses[2]["ruler"]["age"] = -1000
	game.houses[2]["faith"]["piety"] = 20
	var month_before: int = game.calendar_index()
	game.advance_month()
	_check(game.calendar_index() == month_before + 1 and game.player == 1, "Ausgeschiedene Gastperspektive stoppte den gemeinsamen Monat oder wurde nicht wiederhergestellt.")
	_check(game.faith_piety(2) > 25, "Ausgeschiedene Gastperspektive blockierte Glaubensentscheidungen der KI.")
	game.houses[0]["children"] = []
	game.houses[0]["heir"] = ""
	game._succession(0)
	_check(game.all_human_houses_over(), "Vollständiges Hausende wurde nicht erkannt.")

func _test_snapshots() -> void:
	var game = _new_game()
	game.captive = {"house": 2, "name": "Nur Host", "gender": "f", "months": 8}
	game._trigger_event()
	var instance0: int = game.pending_event_instance()
	game.select_player_context(1)
	game.scandal = 4
	game.opinion[2] = -71
	game._set_cooldown("marry", 12)
	game._trigger_event()
	var instance1: int = game.pending_event_instance()
	game.select_player_context(0)
	var full: Dictionary = game.snapshot()
	var restored = GameScript.new(DataScript, 0)
	_check(restored.restore(JSON.parse_string(JSON.stringify(full))), "Hostspielstand mit Menschenkontexten wurde nicht wiederhergestellt.")
	_check(SaveGameScript.state_equal(full, restored.snapshot()), "Host-Roundtrip verlor Mehrhauszustand.")
	restored.select_player_context(1)
	_check(restored.scandal == 4 and int(restored.opinion[2]) == -71 and restored._cooldown_left("marry") > 0 and restored.pending_event_instance() == instance1, "Gastzustand ging beim Host-Roundtrip verloren.")
	restored.select_player_context(0)
	_check(restored.pending_event_instance() == instance0 and str(restored.captive.get("name")) == "Nur Host", "Hostzustand ging beim Roundtrip verloren.")
	var projection: Dictionary = game.snapshot_for_player(1)
	_check(game.player == 0 and str(game.captive.get("name")) == "Nur Host", "Gastprojektion veränderte die Hostansicht.")
	_check(int(projection.get("player")) == 1 and (projection.get("captive", {}) as Dictionary).is_empty(), "Gastprojektion enthält Hostperspektive.")
	_check(not projection.has("lan_contexts") and not JSON.stringify(projection).contains("Nur Host"), "Gast erhielt persönliche Zustände anderer Häuser.")
	var guest = GameScript.new(DataScript, 1)
	_check(guest.restore(JSON.parse_string(JSON.stringify(projection))), "Gastprojektion ist nicht wiederherstellbar.")
	_check(guest.player == 1 and guest.scandal == 4 and guest.pending_event_instance() == instance1, "Gastprojektion zeigt falsche persönliche Daten.")
	var corrupt: Dictionary = full.duplicate(true)
	corrupt["lan_human_houses"] = [0, 0]
	var saved: Dictionary = game.snapshot()
	_check(not game.restore(corrupt), "Doppelte Menschenhäuser wurden aus Save akzeptiert.")
	_check(SaveGameScript.state_equal(saved, game.snapshot()), "Ungültiger LAN-Save veränderte das laufende Spiel.")
	corrupt = full.duplicate(true)
	corrupt["lan_contexts"]["1"]["opinion"] = [999]
	_check(not game.restore(corrupt), "Beschädigter persönlicher Zustand wurde akzeptiert.")
	_check(SaveGameScript.state_equal(saved, game.snapshot()), "Beschädigter Kontext veränderte das laufende Spiel.")

func _test_legacy_event() -> void:
	var legacy = GameScript.new(DataScript, 0)
	legacy._trigger_event()
	var old_save: Dictionary = legacy.snapshot()
	old_save.erase("event_instance")
	var restored = GameScript.new(DataScript, 0)
	_check(restored.restore(old_save), "Älteres Einzelspielerereignis wurde abgelehnt.")
	_check(restored.pending_event != null and restored.pending_event_instance() > 0, "Älteres offenes Ereignis hat keine gültige Antwortinstanz.")
	_check(restored.configure_human_houses([0, 1, 2, 3]), "Vier Menschen oder vorhandenes Einzelspielerereignis verhindern LAN-Konfiguration.")
	var loaded = GameScript.new(DataScript, 0)
	_check(loaded.restore(restored.snapshot()), "Übernommenes Legacy-Ereignis erzeugt einen unlesbaren LAN-Spielstand.")

func _test_invalid_lan_player_indices() -> void:
	var game = _new_game()
	var before: Dictionary = game.snapshot()
	for invalid in [-1, 999]:
		var broken: Dictionary = before.duplicate(true)
		broken["player"] = invalid
		_check(not game.restore(broken), "Ungültiger LAN-Spielerindex %d wurde akzeptiert." % invalid)
		_check(SaveGameScript.state_equal(before, game.snapshot()), "Abgewiesener Spielerindex %d veränderte die aktive Welt." % invalid)

func _logs(game, index: int) -> Array:
	return game.snapshot_for_player(index).get("log", [])

func _messages_with(game, index: int, fragment: String) -> int:
	var count := 0
	for line in _logs(game, index):
		if str(line).contains(fragment):
			count += 1
	return count

func _test_passive_guest_infrastructure_and_birth() -> void:
	var research = _new_game()
	research.log_lines.clear()
	research.houses[1]["gold"] = 500
	_check(research.start_research("surveying", 1).ok, "Gastforschung konnte nicht real gestartet werden.")
	for _month in 6:
		research.advance_month()
	_check(research.player == 0 and research.calendar_index() == 6, "Gastforschung wechselte Perspektive oder taktete die Welt mehrfach.")
	_check(research.houses[1].research.known == ["surveying"] and int(research.houses[1].gold) == 480, "Gastforschung wurde nicht einmalig abgeschlossen und bezahlt.")
	_check(_messages_with(research, 1, "Forschung abgeschlossen") == 1, "Gast sieht den eigenen Forschungsabschluss nicht genau einmal.")
	_check(_messages_with(research, 0, "Forschung abgeschlossen") == 0, "Gastforschung wurde im privaten Hostlog gemeldet.")
	var roads = _new_game()
	roads.log_lines.clear()
	roads.houses[1].research.known = ["surveying", "road_building"]
	roads.houses[1].gold = 500
	var a := str(roads.houses[1].capital)
	var b := str(roads.neighbours(a)[0])
	roads.province(a).owner = 1
	roads.province(b).owner = 1
	_check(roads.build_road(a, b, 1).ok, "Gaststraße konnte nicht real gestartet werden.")
	for _month in 3:
		roads.advance_month()
	_check(roads.player == 0 and roads.calendar_index() == 3 and int(roads.houses[1].gold) == 470, "Straßenmeldung verursachte weitere Kosten oder Welttakte.")
	_check(roads.roads.size() == 1 and roads.roads[0].state == "complete" and roads.road_income(1) == 2, "Gaststraße wurde nicht genau einmal fertiggestellt.")
	_check(_messages_with(roads, 1, "Straßenverbindung ist fertiggestellt") == 1 and _messages_with(roads, 0, "Straßenverbindung ist fertiggestellt") == 0, "Gaststraßenmeldung fehlt beim Besitzer oder landet beim Host.")
	var birth = _new_game()
	birth.log_lines.clear()
	var children: int = birth.houses[1].children.size()
	var prestige: int = int(birth.houses[1].prestige)
	var renown: int = int(birth.houses[1].renown)
	birth.houses[1].pregnant = 1
	birth._tick_family()
	_check(birth.player == 0 and birth.calendar_index() == 0 and birth.houses[1].children.size() == children + 1, "Gastgeburt wechselte Kontext oder erzeugte mehrere Kinder/Monate.")
	_check(int(birth.houses[1].prestige) == prestige + 5 and int(birth.houses[1].renown) == renown + 6, "Gastgeburt verbuchte ihre Wirkungen nicht genau einmal.")
	_check(_messages_with(birth, 1, "Ein Kind wird geboren") == 1 and _messages_with(birth, 0, "Ein Kind wird geboren") == 0, "Private Gastgeburt wird dem falschen Menschen gemeldet.")
	var legacy = GameScript.new(DataScript, 0)
	legacy.log_lines.clear()
	legacy._birth(1)
	_check(legacy.log_lines.is_empty(), "Einzelspieler zeigt plötzlich die private Geburt eines anderen Hauses.")
	legacy._birth(0)
	_check(legacy.log_lines.size() == 1 and str(legacy.log_lines[0]).contains("Ein Kind wird geboren"), "Einzelspieler verlor die eigene Geburtsmeldung.")

func _test_passive_guest_military_and_faith() -> void:
	var game = _new_game()
	game.log_lines.clear()
	var capital := str(game.houses[1].capital)
	game.province(capital).terrain_supply = 1
	game.houses[1].armies = [{"id":1, "province":capital, "strength":1000, "morale":100, "upkeep":1}]
	game._apply_army_supply(1)
	_check(int(game.houses[1].armies[0].strength) == 982, "Gastversorgung zog nicht exakt 18 Mann einmalig ab.")
	_check(_messages_with(game, 1, "Versorgung") == 1 and _messages_with(game, 0, "Versorgung") == 0, "Versorgungsverlust fehlt im Gastlog oder leakt zum Host.")
	game.houses[1].council.marshal = 0
	game.houses[1].courtiers[0].martial = 6
	game.houses[1].legitimacy = 50
	game.province(capital).levy = 500
	game._apply_council_training(1)
	_check(int(game.province(capital).levy) == 508, "Gastmarschall trainierte nicht exakt einmal acht Mann.")
	_check(_messages_with(game, 1, "trainiert") == 1 and _messages_with(game, 0, "trainiert") == 0, "Marschallmeldung fehlt im Gastlog oder leakt zum Host.")
	game.houses[1].gold = 0
	game.houses[1].fleets = [{"id":1, "province":capital, "station":capital, "ships":5, "upkeep":2, "morale":100}]
	game._apply_fleet_upkeep(1)
	_check(int(game.houses[1].fleets[0].ships) == 4 and int(game.houses[1].fleets[0].morale) == 80, "Unbezahlte Gastflotte wurde mehrfach beschädigt.")
	_check(_messages_with(game, 1, "Schiffe desertieren") == 1 and _messages_with(game, 0, "Schiffe desertieren") == 0, "Flottenunterhalt meldet an das falsche Haus.")
	_check(game.player == 0 and game.calendar_index() == 0, "Militärmeldungen wechselten Perspektive oder Zeit.")
	for outcome in ["expired", "won", "timeout"]:
		var faith = _new_game()
		faith.log_lines.clear()
		var target := str(faith.houses[2].capital)
		faith.houses[1].faith.holy_war = {"target":2, "months":1}
		if outcome != "expired":
			faith._add_claim(1, target)
		if outcome == "won":
			faith.province(target).owner = 1
		var prestige: int = int(faith.houses[1].prestige)
		var legitimacy: int = int(faith.houses[1].legitimacy)
		faith._apply_faith_holy_war(1)
		_check(faith.faith_holy_war_target(1) == -1, "Gastheiligerkrieg endete nicht: " + outcome)
		if outcome == "won":
			_check(int(faith.houses[1].prestige) == prestige + 10 and int(faith.houses[1].legitimacy) == legitimacy + 5, "Gewonnener Gastheiligerkrieg verbuchte mehrfache Boni.")
		_check(_logs(faith, 1).size() == 1 and faith.log_lines.is_empty() and faith.player == 0, "Glaubensendmeldung landet nicht genau einmal beim Gast: " + outcome)

func _naval_log_fixture():
	var game = GameScript.new(DataScript, 0)
	_check(game.configure_human_houses([0, 1, 2]), "Drei Empfängerhäuser wurden nicht eingerichtet.")
	game.log_lines.clear()
	game.province("cantium").owner = 1
	game.province("iceni").owner = 2
	game.province("iceni").dev = 4
	game.province("iceni").levy = 500
	game.houses[1].gold = 100
	game.houses[2].gold = 1000
	game.houses[1].fleets = [{"id":1, "province":"cantium", "station":"cantium", "ships":12, "upkeep":2, "morale":100}]
	game.houses[2].fleets = []
	return game

func _test_naval_recipient_messages() -> void:
	var game = _naval_log_fixture()
	_check(game.blockade("iceni", 1).ok, "Kontrollierte Gastblockade scheiterte.")
	_check(int(game.houses[1].gold) == 120 and int(game.houses[2].gold) == 980 and int(game.province("iceni").levy) == 450, "Blockadebeute oder Aufgebotsverlust wurden mehrfach angewandt.")
	_check(_messages_with(game, 1, "wird blockiert") == 1 and _messages_with(game, 2, "wird blockiert") == 1 and game.log_lines.is_empty(), "Blockade meldet nicht beiden betroffenen Menschen oder leakt zum Host.")
	game.province("iceni").blockade = 1
	game._tick_naval()
	_check(int(game.province("iceni").blockade) == 0 and int(game.houses[1].gold) == 120, "Blockadeende taktete Beute zusätzlich.")
	_check(_messages_with(game, 1, "Blockade von") == 1 and _messages_with(game, 2, "Blockade von") == 1 and game.log_lines.is_empty(), "Blockadeende fehlt bei einem betroffenen Menschen.")
	game._sink_fleet(1, game.houses[1].fleets[0])
	_check(game.houses[1].fleets.is_empty() and _messages_with(game, 1, "eigene Flotte ist versenkt") == 1 and _messages_with(game, 2, "eigene Flotte ist versenkt") == 0, "Versenkte Gastflotte meldet an falsche Empfänger.")
	game._capture_province("iceni", 1)
	_check(int(game.province("iceni").owner) == 1 and int(game.province("iceni").dev) == 3 and int(game.province("iceni").levy) == 270, "Gastbelagerung wirkt nicht exakt einmal nach der Blockade.")
	_check(_messages_with(game, 1, "Belagerung nimmt") == 1 and _messages_with(game, 2, "Belagerung nimmt") == 0 and game.log_lines.is_empty(), "Einnahmemeldung fehlt beim neuen Besitzer oder geht an Fremde.")
	var battle = _naval_log_fixture()
	battle.houses[1].fleets[0].ships = 1
	battle.houses[2].fleets = [{"id":1, "province":"iceni", "station":"iceni", "ships":30, "upkeep":3, "morale":100}]
	battle.attack_roll_override = 0.0
	_check(not battle.blockade("iceni", 1).ok and battle.houses[1].fleets.is_empty(), "Kontrollierte Seeniederlage trat nicht ein.")
	_check(_messages_with(battle, 1, "Seeschlacht vor") == 1 and _messages_with(battle, 2, "Seeschlacht vor") == 1 and battle.log_lines.is_empty(), "Seeniederlage meldet nicht beiden Beteiligten.")
	_check(game.player == 0 and battle.player == 0 and game.calendar_index() == 0, "Empfängerwechsel taktete Welt oder aktive Perspektive um.")

func _test_log_limits_privacy_and_roundtrip() -> void:
	var game = _new_game()
	if not game.has_method("_note_for_houses"):
		_check(false, "Die deduplizierende persönliche Empfängerhilfe fehlt.")
		return
	game.log_lines.clear()
	var houses_before: Array = game.houses.duplicate(true)
	game._note_for_houses([1, 1, 2, 0, 0], "Gemeinsame Empfängermeldung")
	_check(game.log_lines.size() == 1 and _logs(game, 1).size() == 1, "Doppelte Empfänger erzeugen mehrere Meldungen.")
	for index in 13:
		game._note_for_house(1, "Privat %d" % index)
	var guest_log: Array = _logs(game, 1)
	_check(guest_log.size() == 10 and str(guest_log[0]) == "Privat 3" and str(guest_log[-1]) == "Privat 12", "Persönliches Gastlog hält nicht die letzten zehn Meldungen.")
	_check(game.log_lines.size() == 1 and game.player == 0 and game.calendar_index() == 0, "Private Gastmeldungen veränderten Hostlog, Perspektive oder Datum.")
	_check(SaveGameScript.state_equal({"houses":houses_before}, {"houses":game.houses}), "Empfängerhilfe veränderte Häuser oder Wirkungen.")
	game.select_player_context(2)
	_check(game.log_lines.is_empty(), "Persönliche Menschenmeldungen wurden einem KI-Haus zugestellt.")
	game.select_player_context(0)
	var full: Dictionary = game.snapshot()
	var loaded = GameScript.new(DataScript, 0)
	_check(loaded.restore(JSON.parse_string(JSON.stringify(full))) and SaveGameScript.state_equal(full, loaded.snapshot()), "Volles Save verliert persönlich geroutete Meldungen.")
	var projection: Dictionary = game.snapshot_for_player(1)
	var guest = GameScript.new(DataScript, 1)
	_check(guest.restore(JSON.parse_string(JSON.stringify(projection))) and guest.log_lines == guest_log, "Gastprojektion verliert das eigene begrenzte Log.")
	_check(not JSON.stringify(game.snapshot_for_player(0)).contains("Privat 12"), "Hostprojektion enthält Gast-private Meldungen.")
	var legacy = GameScript.new(DataScript, 0)
	legacy.log_lines.clear()
	legacy._note_for_houses([1, 1, 0, 0], "SP-Empfänger")
	_check(legacy.log_lines == ["SP-Empfänger"] and legacy.player == 0, "Einzelspieler-Empfängerfilter oder Deduplizierung änderte sich.")

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failed = true
		print("LANGAMESTATETEST FAIL: " + message)

func _finish() -> void:
	if not _failed:
		print("LANGAMESTATETEST OK: %d Prüfungen; Kosten, Weltmonat, KI, Diplomatie, Intrigen, Ereignisse, Hausende und Save-Perspektiven." % _checks)
	get_tree().quit(1 if _failed else 0)
