extends Node
## Verträge, Rat, Stimmen, KI und Schema-11-Roundtrip.
##
## Aufruf: godot --headless --path . res://tests/CouncilTest.tscn
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
	_test_contracts()
	_test_contract_negatives()
	_test_economy_and_army()
	_test_council_roles()
	_test_votes_and_resolutions()
	_test_ai()
	_test_kernel_and_roundtrip()
	if _failed:
		return
	print("COUNCILTEST OK: drei Vasallenverträge, vier Ratssitze, Stimmen, vier Beschlüsse, KI, Negativfälle und Schema-11-Roundtrip; %d Prüfungen." % _checks)
	get_tree().quit(0)

func _new_game():
	return GameScript.new(DataScript, 0)

func _test_start() -> void:
	var g = _new_game()
	var h: Dictionary = g.house()
	_check((h["vassals"] as Array).size() == 3, "Start hat nicht drei Vasallen.")
	_check(int(g.vassal_tax_income()) == 15, "Startsteuern sind nicht 15.")
	_check(int(g.vassal_levy_bonus()) == 90, "Startaufgebot ist nicht 90.")
	_check(int(g.vassal_opinion_avg()) == 50, "Startmeinung ist nicht 50.")
	for role in ["marshal", "chancellor", "steward", "spymaster"]:
		_check((h["council"] as Dictionary).has(role), "Ratssitz %s fehlt." % role)
		_check(not g.council_member(0, role).is_empty(), "Ratssitz %s ist unbesetzt." % role)
	_check(int((h["council_effects"] as Dictionary).get("intrigue", -1)) == 0, "Intrigenbonus startet nicht bei 0.")
	_check(int(g.snapshot()["schema_version"]) == SaveGame.CURRENT_VERSION, "Snapshot ist nicht im aktuellen Schema.")
	_check(SaveGame.validate(g.snapshot()).is_empty(), "Schema-11-Snapshot ist ungültig.")

func _test_contracts() -> void:
	var g = _new_game()
	var h: Dictionary = g.house()
	h["gold"] = 500
	h["legitimacy"] = 80
	h["prestige"] = 40
	var result: Dictionary = g.change_vassal_contract(0, 2)
	_check(bool(result["ok"]), "Vertragserhöhung scheitert: %s" % str(result.get("msg", "")))
	_check(g.vassal_contract_level(0) == 2, "Vertragsstufe ist nicht 2.")
	_check(int(h["gold"]) == 420, "Vertragserhöhung kostet nicht 80 Gold.")
	_check(int((h["vassals"] as Array)[0]["opinion"]) == 40, "Meinung sinkt nicht um 10.")
	_check(g.vassal_tax_income() == 18, "Steuern steigen nicht auf 18.")
	_check(g.vassal_levy_bonus() == 120, "Aufgebot steigt nicht auf 120.")
	_check(not _find_effect(g, "V3", "vassal_opinion", 0).is_empty(), "Vertragsmeinung erzeugt keinen V3-Beleg.")
	var lower: Dictionary = g.change_vassal_contract(0, 0)
	_check(bool(lower["ok"]), "Vertragssenkung scheitert.")
	_check(g.vassal_contract_level(0) == 0, "Vertragsstufe ist nicht 0.")
	_check(int((h["vassals"] as Array)[0]["opinion"]) == 50, "Meinung steigt bei Senkung nicht auf 50.")
	_check(int(h["gold"]) == 420, "Senkung kostet unerwartet Gold.")

func _test_contract_negatives() -> void:
	var g = _new_game()
	var h: Dictionary = g.house()
	h["gold"] = 10
	h["legitimacy"] = 80
	h["prestige"] = 40
	_check(not g.change_vassal_contract(0, 2)["ok"], "Unbezahlbarer Vertrag wurde erlaubt.")
	_check(g.vassal_contract_level(0) == 1, "Unbezahlbarer Vertrag änderte die Stufe.")
	h["gold"] = 500
	h["legitimacy"] = 20
	_check(not g.change_vassal_contract(0, 2)["ok"], "Vertrag mit zu niedriger Legitimität wurde erlaubt.")
	h["legitimacy"] = 80
	h["prestige"] = 0
	_check(not g.change_vassal_contract(0, 2)["ok"], "Vertrag mit zu niedrigem Prestige wurde erlaubt.")
	_check(not g.change_vassal_contract(0, 1)["ok"], "Unveränderte Vertragsstufe wurde erlaubt.")
	_check(not g.change_vassal_contract(99, 2)["ok"], "Ungültiger Vasall wurde erlaubt.")
	h["gold"] = 500
	h["prestige"] = 40
	g.set_edge_enabled("V3", false)
	_check(not g.change_vassal_contract(0, 2)["ok"], "Deaktivierte Vertragskante wurde ignoriert.")

func _test_economy_and_army() -> void:
	var g = _new_game()
	var h: Dictionary = g.house()
	for vi in 3:
		h["vassals"][vi]["level"] = 2
		h["vassals"][vi]["opinion"] = 50
	var capital: Dictionary = g.province(str(h["capital"]))
	capital["levy"] = 1000
	h["gold"] = 500
	g.effect_log.clear()
	g._apply_vassal_tax(0)
	var tax_effect := _find_effect(g, "V1", "gold", 0)
	_check(not tax_effect.is_empty(), "Vasallensteuer erzeugt keinen V1-Beleg.")
	_check(int(tax_effect.get("delta", 0)) == 24, "Vasallensteuer ist nicht +24.")
	g.raise_army(str(capital["id"]))
	_check(int((h["armies"] as Array)[0]["strength"]) == 680, "Vasallenaufgebot erhöht Armee nicht auf 680.")
	_check(not _find_effect(g, "V2", "army_strength", 0).is_empty(), "Vasallenaufgebot erzeugt keinen V2-Beleg.")

	for vi in 3:
		h["vassals"][vi]["opinion"] = 30
	var legitimacy_before: int = int(h["legitimacy"])
	g._apply_vassal_politics(0)
	_check(int(h["legitimacy"]) < legitimacy_before, "Unmut senkt die Legitimität nicht.")
	for vi in 3:
		h["vassals"][vi]["opinion"] = 80
	legitimacy_before = int(h["legitimacy"])
	g._apply_vassal_politics(0)
	_check(int(h["legitimacy"]) > legitimacy_before, "Vasallenloyalität hebt die Legitimität nicht.")

func _test_council_roles() -> void:
	var g = _new_game()
	var h: Dictionary = g.house()
	var best_chancellor := _best(h["courtiers"], "diplomacy")
	var best_steward := _best(h["courtiers"], "stewardship")
	var best_spy := _best(h["courtiers"], "intrigue")
	g.assign_council("chancellor", best_chancellor)
	g.assign_council("steward", best_steward)
	g.assign_council("spymaster", best_spy)
	var gain: int = g.chancellor_opinion_gain()
	_check(gain > 0, "Kanzler erzeugt keine Meinungsgewinne.")
	var opinion_before: int = int((h["vassals"] as Array)[0]["opinion"])
	g._apply_chancellor_opinion(0)
	_check(int((h["vassals"] as Array)[0]["opinion"]) == opinion_before + gain, "Kanzler erhöht Meinung nicht.")
	var steward_gain: int = g.council_steward_income()
	var gold_before: int = int(h["gold"])
	g._apply_steward_income(0)
	_check(steward_gain > 0 and int(h["gold"]) == gold_before + steward_gain, "Kämmerer erzeugt keine Steuern.")
	_check(g.council_intrigue_percent() > 0, "Spionmeister erzeugt keinen Intrigenbonus.")
	var base_chance: float = g.action_chance("murder", 1)
	h["council"]["spymaster"] = _worst(h["courtiers"], "intrigue")
	var weak_chance: float = g.action_chance("murder", 1)
	h["council"]["spymaster"] = best_spy
	_check(g.action_chance("murder", 1) > weak_chance, "Spionmeister verbessert die Intrigenchance nicht.")
	_check(g.council_member(0, "spymaster")["name"] == h["courtiers"][best_spy]["name"], "Spionmeister wurde nicht eingesetzt.")

func _test_votes_and_resolutions() -> void:
	var g = _new_game()
	var h: Dictionary = g.house()
	_make_loyal_council(g)
	h["legitimacy"] = 80
	h["gold"] = 200
	h["prestige"] = 50
	for vi in 3:
		h["vassals"][vi]["opinion"] = 50
	var preview: Dictionary = g.council_vote_preview("land_frieden")
	_check(bool(preview["passed"]), "Landfrieden hat bei loyalem Rat keine Mehrheit.")
	_check(int(preview["yes"]) >= 3, "Landfrieden hat nicht mindestens drei Ja-Stimmen.")
	var result: Dictionary = g.enact_council_resolution("land_frieden")
	_check(bool(result["ok"]), "Landfrieden scheitert: %s" % str(result.get("msg", "")))
	_check(int(h["gold"]) == 140, "Landfrieden kostet nicht 60 Gold.")
	_check(int((h["vassals"] as Array)[0]["opinion"]) == 56, "Landfrieden erhöht Meinung nicht um 6.")
	_check(int(h["legitimacy"]) == 82, "Landfrieden erhöht Legitimität nicht um 2.")
	_check(not _find_effect(g, "C2", "vassal_opinion", 0).is_empty(), "Landfrieden erzeugt keinen C2-Beleg.")

	h["legitimacy"] = 80
	h["gold"] = 200
	h["prestige"] = 50
	for c in h["courtiers"]:
		c["loyalty"] = 0
	var blocked: Dictionary = g.enact_council_resolution("land_frieden")
	_check(not bool(blocked["ok"]), "Beschluss ohne Mehrheit wurde erlaubt.")
	_check(int(h["gold"]) == 200, "Abgelehnter Beschluss kostet Gold.")
	_check(int((h["vassals"] as Array)[0]["opinion"]) == 56, "Abgelehnter Beschluss verändert Meinung.")

	_make_loyal_council(g)
	h["gold"] = 200
	h["prestige"] = 50
	var levy_before: int = int(g.province(str(h["capital"]))["levy"])
	var war_result: Dictionary = g.enact_council_resolution("war_levy")
	_check(bool(war_result["ok"]), "Kriegsaufgebot scheitert.")
	_check(int(g.province(str(h["capital"]))["levy"]) == levy_before + 80, "Kriegsaufgebot erhöht Aufgebot nicht um 80.")
	_check(not _find_effect(g, "C1", "levy", 0).is_empty(), "Kriegsaufgebot erzeugt keinen C1-Beleg.")

	var bonus_before: int = g.council_intrigue_percent()
	var shadow: Dictionary = g.enact_council_resolution("shadow_network")
	_check(bool(shadow["ok"]), "Schattennetz scheitert.")
	_check(g.council_intrigue_percent() >= bonus_before, "Schattennetz erhöht Intrigenchance nicht.")
	_check(int(h["council_effects"]["intrigue"]) == 2, "Schattennetz setzt Intrigenstufe nicht auf 2.")

	h["gold"] = 0
	h["prestige"] = 50
	var tax_result: Dictionary = g.enact_council_resolution("crown_tax")
	_check(bool(tax_result["ok"]), "Kronsteuer scheitert.")
	_check(int(h["gold"]) == 80, "Kronsteuer erzeugt nicht 80 Gold.")
	_check(int((h["vassals"] as Array)[0]["opinion"]) < 56, "Kronsteuer senkt Meinung nicht.")

func _test_ai() -> void:
	var g = _new_game()
	for i in range(1, g.houses.size()):
		var h: Dictionary = g.houses[i]
		h["gold"] = 1000
		h["prestige"] = 200
		h["legitimacy"] = 90
		for c in h["courtiers"]:
			c["loyalty"] = 100
			c["martial"] = 18
			c["diplomacy"] = 18
			c["stewardship"] = 18
			c["intrigue"] = 18
	g.effect_log.clear()
	g.run_ai_turn()
	var ai_council := false
	var ai_contract := false
	for entry in g.effect_log:
		if int(entry.get("house", 0)) == g.player:
			continue
		var edge := str(entry.get("edge", ""))
		if edge in ["C1", "C2", "C3", "C4", "C5"]:
			ai_council = true
		if edge == "V3":
			ai_contract = true
	_check(ai_council, "Keine KI nutzt einen Ratsbeschluss.")
	_check(ai_contract, "Keine KI nutzt denselben Vertragspfad.")

func _test_kernel_and_roundtrip() -> void:
	var g = _new_game()
	var h: Dictionary = g.house()
	h["gold"] = 500
	h["legitimacy"] = 80
	h["prestige"] = 40
	var kernel = KernelScript.new()
	kernel.bind_game(g)
	var contract: Dictionary = kernel.dispatch({"id": "vassal_contract", "vassal": 0, "level": 2})
	_check(bool(contract["ok"]), "UiKernel routet den Vertrag nicht.")
	_check(g.vassal_contract_level(0) == 2, "UiKernel-Vertrag ändert die Stufe nicht.")
	var resolution: Dictionary = kernel.dispatch({"id": "council_resolution", "resolution": "land_frieden"})
	_check(bool(resolution["ok"]), "UiKernel routet den Ratsbeschluss nicht.")

	var snapshot: Dictionary = g.snapshot()
	_check(int(snapshot["schema_version"]) == SaveGame.CURRENT_VERSION, "Snapshot ist nicht im aktuellen Schema.")
	_check(SaveGame.validate(snapshot).is_empty(), "Schema-11-Snapshot ist ungültig.")
	var parsed = JSON.parse_string(JSON.stringify(snapshot))
	_check(parsed is Dictionary, "JSON-Roundtrip liefert kein Dictionary.")
	var loaded = _new_game()
	_check(loaded.restore(parsed), "Schema-11-Snapshot ließ sich nicht laden.")
	var actual: Dictionary = loaded.snapshot()
	var diff: Array = SaveGame.diff(snapshot, actual)
	_check(diff.is_empty(), "Schema-11-Roundtrip verliert Zustand: %s" % "; ".join(diff))
	_check(loaded.vassal_contract_level(0) == 2, "Vertragsstufe überlebt den Roundtrip nicht.")
	_check(loaded.council_intrigue_percent() == g.council_intrigue_percent(), "Ratseffekt überlebt den Roundtrip nicht.")

func _make_loyal_council(g) -> void:
	for c in g.house()["courtiers"]:
		c["loyalty"] = 100
		c["martial"] = 18
		c["diplomacy"] = 18
		c["stewardship"] = 18
		c["intrigue"] = 18
	g.assign_council("marshal", 0)
	g.assign_council("chancellor", 1)
	g.assign_council("steward", 2)
	g.assign_council("spymaster", 3)

func _best(courtiers: Array, stat: String) -> int:
	var best := 0
	for i in courtiers.size():
		if int(courtiers[i].get(stat, 0)) > int(courtiers[best].get(stat, 0)):
			best = i
	return best

func _worst(courtiers: Array, stat: String) -> int:
	var worst := 0
	for i in courtiers.size():
		if int(courtiers[i].get(stat, 0)) < int(courtiers[worst].get(stat, 0)):
			worst = i
	return worst

func _find_effect(g, edge: String, kind: String, house_index: int) -> Dictionary:
	for entry in g.effect_log:
		if str(entry.get("edge", "")) == edge and str(entry.get("kind", "")) == kind and int(entry.get("house", -1)) == house_index:
			return entry
	return {}

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	if _failed:
		return
	_failed = true
	print("COUNCILTEST FAIL: " + message)
	get_tree().quit(1)
