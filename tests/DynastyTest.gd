extends Node
## Dynastie-Test für Ruhm und drei Vermächtniszweige.
##
## Beweist:
## 1. Jedes Haus startet mit Ruhm und drei leeren Zweigen.
## 2. Monatlicher Ruhmgewinn wird über den Resolver gebucht.
## 3. Kauf kostet Ruhm, erhöht die Stufe und respektiert Maximalstufe,
##    fehlenden Ruhm und die deaktivierte Kante L1.
## 4. Kriegsvermächtnis erhöht die aufgestellte Armee messbar.
## 5. Kronvermächtnis erzeugt zusätzliches Gold über L2.
## 6. Ränkevermächtnis erhöht die Intrigenchance über L3.
## 7. KI kauft Vermächtnisse über dieselbe Methode.
## 8. UiKernel routet das Kommando; Schema 11 überlebt einen JSON-Roundtrip.
##
## Aufruf: godot --headless --path . res://tests/DynastyTest.tscn

const DataScript = preload("res://scripts/Data.gd")
const GameScript = preload("res://scripts/Game.gd")
const SaveGame = preload("res://scripts/SaveGame.gd")
const KernelScript = preload("res://scripts/UiKernel.gd")

var _failed := false
var _checks := 0

func _ready() -> void:
	seed(20261109)
	_test_start_and_gain()
	_test_unlock_and_war()
	_test_crown()
	_test_guile()
	_test_negative_edge()
	_test_ai()
	_test_kernel_and_roundtrip()
	if _failed:
		return
	print("DYNASTYTEST OK: Ruhm, drei Vermächtnisse, Kauf/Maximum, L1/L2/L3-Effekte, KI, UiKernel und Schema-11-Roundtrip; %d Prüfungen." % _checks)
	get_tree().quit(0)

func _new_game():
	return GameScript.new(DataScript, 0)

func _test_start_and_gain() -> void:
	var g = _new_game()
	var h: Dictionary = g.house()
	_check(int(h["renown"]) == 80, "Startruhm ist nicht 80.")
	for track in ["war", "crown", "guile"]:
		_check(int(h["legacies"][track]) == 0, "Startstufe %s ist nicht 0." % track)
	var gain: int = g.renown_gain(0)
	_check(gain >= 1, "Ruhmgewinn ist nicht positiv.")
	var before: int = int(h["renown"])
	g._tick_dynasty()
	_check(int(h["renown"]) == before + gain, "Monatlicher Ruhmgewinn stimmt nicht.")
	_check(not _find_effect(g, "", "renown", 0).is_empty(), "Ruhmgewinn erzeugt keinen Beleg.")

func _test_unlock_and_war() -> void:
	var g = _new_game()
	var h: Dictionary = g.house()
	h["renown"] = 80
	var result: Dictionary = g.unlock_legacy("war")
	_check(bool(result["ok"]), "Erster Kriegskauf scheitert: %s" % str(result.get("msg", "")))
	_check(int(h["legacies"]["war"]) == 1, "Kriegsstufe ist nicht 1.")
	_check(int(h["renown"]) == 0, "Kriegskauf zieht nicht 80 Ruhm ab.")
	var cost_effect: Dictionary = _find_effect(g, "L1", "renown", 0)
	_check(int(cost_effect.get("delta", 0)) == -80, "Kaufbeleg zeigt nicht -80 Ruhm.")
	_check(not g.can_unlock_legacy("war"), "Kauf ohne Ruhm ist erlaubt.")
	h["renown"] = 1000
	_check(bool(g.unlock_legacy("war")["ok"]), "Zweiter Kriegskauf scheitert.")
	_check(int(h["renown"]) == 840, "Zweiter Kriegskauf kostet nicht 160 Ruhm.")
	h["renown"] = 1000
	_check(bool(g.unlock_legacy("war")["ok"]), "Dritter Kriegskauf scheitert.")
	_check(int(h["legacies"]["war"]) == 3, "Kriegsstufe ist nicht 3.")
	_check(int(h["renown"]) == 760, "Dritter Kriegskauf kostet nicht 240 Ruhm.")
	_check(g.legacy_cost("war") == -1, "Maximalstufe hat noch Kosten.")
	_check(not g.unlock_legacy("war")["ok"], "Kauf über Maximalstufe ist erlaubt.")
	_check(is_equal_approx(g.legacy_war_multiplier(), 1.3), "Kriegsmultiplikator ist nicht 1,3.")

	var base = _new_game()
	var base_capital: Dictionary = base.province(str(base.house()["capital"]))
	var upgraded_capital: Dictionary = g.province(str(h["capital"]))
	base_capital["levy"] = 1000
	upgraded_capital["levy"] = 1000
	base.house()["gold"] = 500
	h["gold"] = 500
	base.raise_army(str(base_capital["id"]))
	g.raise_army(str(upgraded_capital["id"]))
	var base_strength: int = int((base.house()["armies"] as Array)[0]["strength"])
	var boosted_strength: int = int((h["armies"] as Array)[0]["strength"])
	_check(base_strength == 590, "Basisarmee ist nicht 590 stark (inkl. 90 Vasallenaufgebot).")
	_check(boosted_strength == 740, "Kriegsvermächtnis erhöht Armee nicht auf 740 (ist %d)." % boosted_strength)

func _test_crown() -> void:
	var g = _new_game()
	var h: Dictionary = g.house()
	h["legacies"]["crown"] = 2
	var before: int = int(h["gold"])
	g._apply_house_economy(0)
	var effect: Dictionary = _find_effect(g, "L2", "gold", 0)
	_check(not effect.is_empty(), "Kronvermächtnis erzeugt keinen Goldbeleg.")
	_check(int(effect.get("delta", 0)) == 4, "Kronvermächtnis Stufe 2 gibt nicht 4 Gold.")
	_check(int(h["gold"]) >= before + 4, "Gold ist nicht um den Kronanteil gestiegen.")
	g.effect_log.clear()
	h["legacies"]["crown"] = 0
	g._apply_house_economy(0)
	_check(_find_effect(g, "L2", "gold", 0).is_empty(), "Kronwirkung läuft ohne Stufe.")

func _test_guile() -> void:
	var control = _new_game()
	var g = _new_game()
	control.house()["legacies"]["guile"] = 0
	g.house()["legacies"]["guile"] = 2
	# Der neue Spionmeister würde beide Chancen am 85-%-Cap kappen; für die
	# reine Vermächtniswirkung wird der Ratssitz daher neutralisiert.
	control.house()["council"]["spymaster"] = -1
	g.house()["council"]["spymaster"] = -1
	var base_chance: float = control.action_chance("murder", 1)
	var boosted_chance: float = g.action_chance("murder", 1)
	_check(absf((boosted_chance - base_chance) - 0.06) < 0.0001, "Ränke Stufe 2 erhöht die Chance nicht um 6 Prozentpunkte.")
	var r: Dictionary = g.unlock_legacy("guile")
	_check(not bool(r["ok"]), "Ränkekauf ohne Ruhm ist erlaubt.")

func _test_negative_edge() -> void:
	var g = _new_game()
	var h: Dictionary = g.house()
	h["renown"] = 80
	g.set_edge_enabled("L1", false)
	var result: Dictionary = g.unlock_legacy("war")
	_check(not bool(result["ok"]), "Deaktivierte Kante L1 meldet Erfolg.")
	_check(int(h["legacies"]["war"]) == 0, "Deaktivierte Kante L1 erhöht die Stufe.")
	_check(int(h["renown"]) == 80, "Deaktivierte Kante L1 zieht Ruhm ab.")

func _test_ai() -> void:
	var g = _new_game()
	for i in range(1, g.houses.size()):
		g.houses[i]["renown"] = 1000
	g.run_ai_turn()
	var bought: int = 0
	for i in range(1, g.houses.size()):
		for track in ["war", "crown", "guile"]:
			bought += int(g.houses[i]["legacies"][track])
	_check(bought > 0, "Keine KI kauft ein Vermächtnis.")
	var ai_effect: Dictionary = {}
	for entry in g.effect_log:
		if int(entry.get("house", 0)) != g.player and str(entry.get("edge", "")) in ["L1", "L2", "L3"]:
			ai_effect = entry
			break
	_check(not ai_effect.is_empty(), "KI-Kauf erzeugt keinen L1/L2/L3-Beleg.")

func _test_kernel_and_roundtrip() -> void:
	var g = _new_game()
	g.house()["renown"] = 80
	var kernel = KernelScript.new()
	kernel.bind_game(g)
	var result: Dictionary = kernel.dispatch({"id": "legacy", "track": "war"})
	_check(bool(result["ok"]), "UiKernel routet das Vermächtnis-Kommando nicht.")
	_check(int(g.house()["legacies"]["war"]) == 1, "UiKernel-Kauf erhöht die Stufe nicht.")

	g.house()["renown"] = 321
	g.house()["legacies"] = {"war": 2, "crown": 1, "guile": 3}
	var snapshot: Dictionary = g.snapshot()
	_check(int(snapshot["schema_version"]) == SaveGame.CURRENT_VERSION, "Snapshot ist nicht im aktuellen Schema.")
	_check(SaveGame.validate(snapshot).is_empty(), "Schema-11-Snapshot ist ungültig.")
	var parsed = JSON.parse_string(JSON.stringify(snapshot))
	_check(parsed is Dictionary, "JSON-Roundtrip liefert kein Dictionary.")
	var loaded = _new_game()
	_check(loaded.restore(parsed), "Schema-11-Snapshot wurde nicht geladen.")
	var diff: Array = SaveGame.diff(snapshot, loaded.snapshot())
	_check(diff.is_empty(), "Schema-11-Roundtrip verliert Zustand: %s" % "; ".join(diff))
	_check(int(loaded.house()["renown"]) == 321, "Ruhm überlebt den Roundtrip nicht.")
	_check(int(loaded.house()["legacies"]["guile"]) == 3, "Vermächtnis überlebt den Roundtrip nicht.")

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
	print("DYNASTYTEST FAIL: " + message)
	get_tree().quit(1)
