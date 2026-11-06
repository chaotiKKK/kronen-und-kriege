extends Node
## Welle-1-Kausalitätstest für Banger Queens.
##
## Jede Kante wird positiv als Kette geprüft:
##   Eingriff in der Quellsäule -> messbare Zustandsänderung in der Zielsäule.
## Danach wird dieselbe Kante über den Testhook abgeschaltet. Die Aktion bleibt
## erlaubt, aber die Zielgröße darf sich nicht mehr über diese Kante ändern.
##
## Kanten:
##   H1  Rat/Marschall -> Krieg/provinces[].levy
##   H2  Erbfolgegesetz -> Dynastie/houses[].heir
##   H5  Kaserne -> Krieg/provinces[].levy
##   D5  Ehe -> Herrschaft/houses[].legitimacy
##   AI1 KI-Marschall -> Krieg/provinces[].levy (derselbe Resolver)
##
## Aufruf: godot --headless --path . res://tests/SystemicDepthTest.tscn
## Exit-Code 0 = bestanden, 1 = fehlgeschlagen.

const DataScript = preload("res://scripts/Data.gd")
const GameScript = preload("res://scripts/Game.gd")

var _failed := false
var _checks := 0

func _ready() -> void:
	seed(20261106)
	_test_h1()
	_test_h2()
	_test_h5()
	_test_d5()
	_test_ai1()
	if _failed:
		return
	print("SYSTEMICDEPTHTEST OK: H1, H2, H5, D5, AI1 positiv; alle fünf Negativkontrollen ohne Zieländerung; %d Prüfungen." % _checks)
	get_tree().quit(0)

func _test_h1() -> void:
	var g = _new_game(0)
	var capital: Dictionary = _capital(g, 0)
	var house: Dictionary = g.house()
	var marshal_index: int = _best(house["courtiers"], "martial")
	var result: Dictionary = g.assign_council("marshal", marshal_index)
	_check(bool(result["ok"]), "H1: Marschall konnte nicht eingesetzt werden.")
	var before: int = int(capital["levy"])
	g.month = 12
	g.advance_month()
	var effect: Dictionary = _find_effect(g, "H1", "levy", 0)
	_check(not effect.is_empty(), "H1: Kein Effektbeleg für Marschallstraining.")
	_check(int(effect.get("delta", 0)) > 0, "H1: Trainingsdelta ist nicht positiv.")
	_check(int(capital["levy"]) >= before + int(effect.get("delta", 0)), "H1: Levy ist nicht gestiegen.")
	print("H1 OK: Rat/Marschall -> Krieg/levy +%d (vorher %d, nachher %d)." % [
		int(effect.get("delta", 0)), before, int(capital["levy"])
	])
	if _failed:
		return

	var control = _new_game(0)
	var control_capital: Dictionary = _capital(control, 0)
	var control_house: Dictionary = control.house()
	control.assign_council("marshal", _best(control_house["courtiers"], "martial"))
	control.set_edge_enabled("H1", false)
	var control_before: int = int(control_capital["levy"])
	control.month = 12
	control.advance_month()
	_check(_find_effect(control, "H1", "levy", 0).is_empty(), "H1-Negativ: Effekt lief trotz deaktivierter Kante.")
	_check(int(control_capital["levy"]) >= control_before, "H1-Negativ: allgemeines Levy-Wachstum fehlt.")
	print("NEGATIV H1 OK: deaktivierte Kante erzeugt keinen Marschall-Effekt.")

func _test_h2() -> void:
	var g = _new_game(0)
	var house: Dictionary = g.house()
	house["children"] = [
		{"name": "Alt", "age": 20, "gender": "m"},
		{"name": "Jung", "age": 8, "gender": "f"},
	]
	house["laws"]["succession"] = "eldest"
	g._recompute_heir(house)
	_check(str(house["heir"]) == "Alt", "H2: Ausgangserbe ist nicht der Älteste.")
	var result: Dictionary = g.set_law("succession", "youngest")
	_check(bool(result["ok"]), "H2: Gesetzeswechsel wurde abgelehnt.")
	var effect: Dictionary = _find_effect(g, "H2", "heir", 0)
	_check(not effect.is_empty(), "H2: Kein Effektbeleg für Erbfolge.")
	_check(str(house["heir"]) == "Jung", "H2: Erbe ist nicht der Jüngste.")
	print("H2 OK: Erbfolgegesetz -> Dynastie/heir %s -> %s." % [str(effect.get("before", "")), str(effect.get("after", ""))])
	if _failed:
		return

	var control = _new_game(0)
	var control_house: Dictionary = control.house()
	control_house["children"] = [
		{"name": "Alt", "age": 20, "gender": "m"},
		{"name": "Jung", "age": 8, "gender": "f"},
	]
	control_house["laws"]["succession"] = "eldest"
	control._recompute_heir(control_house)
	control.set_edge_enabled("H2", false)
	control.set_law("succession", "youngest")
	_check(_find_effect(control, "H2", "heir", 0).is_empty(), "H2-Negativ: Effekt lief trotz deaktivierter Kante.")
	_check(str(control_house["heir"]) == "Alt", "H2-Negativ: Erbe wurde ohne Verdrahtung geändert.")
	print("NEGATIV H2 OK: deaktivierte Kante lässt den Erben unverändert.")

func _test_h5() -> void:
	var g = _new_game(0)
	var capital: Dictionary = _capital(g, 0)
	g.house()["gold"] = 500
	var before: int = int(capital["levy"])
	var result: Dictionary = g.build(str(capital["id"]), "barracks")
	_check(bool(result["ok"]), "H5: Kaserne konnte nicht gebaut werden.")
	var effect: Dictionary = _find_effect(g, "H5", "levy", 0)
	_check(not effect.is_empty(), "H5: Kein Effektbeleg für Kaserne.")
	_check(int(effect.get("delta", 0)) > 0, "H5: Kaserne erhöht Levy nicht.")
	_check(int(capital["levy"]) == before + int(effect.get("delta", 0)), "H5: Levy entspricht nicht dem Beleg.")
	_check(int(capital["buildings"]["barracks"]) == 1, "H5: Kaserne wurde nicht auf Stufe 1 gesetzt.")
	print("H5 OK: Gebäude Kaserne -> Krieg/levy +%d (Stufe 1)." % int(effect.get("delta", 0)))
	if _failed:
		return

	var control = _new_game(0)
	var control_capital: Dictionary = _capital(control, 0)
	control.house()["gold"] = 500
	var control_before: int = int(control_capital["levy"])
	control.set_edge_enabled("H5", false)
	var control_result: Dictionary = control.build(str(control_capital["id"]), "barracks")
	_check(bool(control_result["ok"]), "H5-Negativ: Bau wurde durch den Testhook blockiert.")
	_check(_find_effect(control, "H5", "levy", 0).is_empty(), "H5-Negativ: Levy-Effekt lief trotz deaktivierter Kante.")
	_check(int(control_capital["levy"]) == control_before, "H5-Negativ: Levy änderte sich ohne Verdrahtung.")
	_check(int(control_capital["buildings"]["barracks"]) == 1, "H5-Negativ: Gebäude sollte trotzdem gebaut sein.")
	print("NEGATIV H5 OK: Gebäude entsteht, aber die Levy-Kante bleibt aus.")

func _test_d5() -> void:
	var g = _new_game(0)
	var house: Dictionary = g.house()
	house["spouse"] = {}
	var before_legitimacy: int = int(house["legitimacy"])
	var before_prestige: int = int(house["prestige"])
	var result: Dictionary = g.settle_marriage(1)
	_check(bool(result["ok"]), "D5: Ehe konnte nicht geschlossen werden.")
	var effect: Dictionary = _find_effect(g, "D5", "legitimacy", 0)
	_check(not effect.is_empty(), "D5: Kein Effektbeleg für Legitimität.")
	_check(int(house["legitimacy"]) == before_legitimacy + 5, "D5: Legitimität stieg nicht um 5.")
	_check(int(house["prestige"]) == before_prestige + 10, "D5: Prestige stieg nicht um 10.")
	_check(not house["spouse"].is_empty(), "D5: Ehe wurde nicht gesetzt.")
	print("D5 OK: Ehe -> Herrschaft/legitimität %d -> %d, Prestige +10." % [before_legitimacy, int(house["legitimacy"])])
	if _failed:
		return

	var control = _new_game(0)
	var control_house: Dictionary = control.house()
	control_house["spouse"] = {}
	var control_before: int = int(control_house["legitimacy"])
	control.set_edge_enabled("D5", false)
	var control_result: Dictionary = control.settle_marriage(1)
	_check(bool(control_result["ok"]), "D5-Negativ: Ehe wurde durch den Testhook blockiert.")
	_check(_find_effect(control, "D5", "legitimacy", 0).is_empty(), "D5-Negativ: Legitimitäts-Effekt lief trotz deaktivierter Kante.")
	_check(int(control_house["legitimacy"]) == control_before, "D5-Negativ: Legitimität änderte sich ohne Verdrahtung.")
	_check(not control_house["spouse"].is_empty(), "D5-Negativ: Ehe sollte trotzdem bestehen.")
	print("NEGATIV D5 OK: Ehe besteht, aber Legitimität bleibt unverändert.")

	# Kreislauf: D5 hebt Legitimität über die H1-Schwelle.
	var loop = _new_game(0)
	loop.house()["spouse"] = {}
	loop.house()["legitimacy"] = 39
	var low: int = loop.council_training_amount(0)
	loop.settle_marriage(1)
	var high: int = loop.council_training_amount(0)
	_check(high > low, "D5->H1: Legitimitätsanstieg erhöht das Marschallstraining nicht.")
	print("D5->H1 OK: Trainingsbetrag %d -> %d durch Legitimität." % [low, high])

func _test_ai1() -> void:
	var g = _new_game(0)
	var ai_house: Dictionary = g.houses[1]
	ai_house["gold"] = 0
	g.run_ai_turn()
	var capital: Dictionary = g.province(str(ai_house["capital"]))
	_check(not capital.is_empty(), "AI1: KI-Hauptstadt fehlt.")
	var marshal: Dictionary = g.council_member(1, "marshal")
	_check(not marshal.is_empty(), "AI1: KI hat keinen Marschall.")
	var before: int = int(capital["levy"])
	g.month = 12
	g.advance_month()
	var effect: Dictionary = _find_effect(g, "AI1", "levy", 1)
	_check(not effect.is_empty(), "AI1: Kein Effektbeleg für KI-Marschall.")
	_check(int(effect.get("delta", 0)) > 0, "AI1: KI-Trainingsdelta ist nicht positiv.")
	_check(int(capital["levy"]) >= before + int(effect.get("delta", 0)), "AI1: KI-Levy ist nicht gestiegen.")
	print("AI1 OK: KI-Marschall -> Krieg/levy +%d über denselben Resolver." % int(effect.get("delta", 0)))
	if _failed:
		return

	var control = _new_game(0)
	var control_ai: Dictionary = control.houses[1]
	control_ai["gold"] = 0
	control.set_edge_enabled("AI1", false)
	control.run_ai_turn()
	var control_capital: Dictionary = control.province(str(control_ai["capital"]))
	control.month = 12
	control.advance_month()
	_check(_find_effect(control, "AI1", "levy", 1).is_empty(), "AI1-Negativ: KI-Effekt lief trotz deaktivierter Kante.")
	_check(int(control_capital["levy"]) >= 0, "AI1-Negativ: Levy ist ungültig.")
	print("NEGATIV AI1 OK: deaktivierte KI-Kante erzeugt keinen Trainingsbeleg.")

func _new_game(player_index: int):
	return GameScript.new(DataScript, player_index)

func _capital(g, house_index: int) -> Dictionary:
	var h: Dictionary = g.houses[house_index]
	var p: Dictionary = g.province(str(h.get("capital", "")))
	if not p.is_empty():
		return p
	for q in g.provinces:
		if int(q["owner"]) == house_index:
			return q
	return {}

func _best(courtiers: Array, stat: String) -> int:
	var best: int = 0
	var value: int = -999
	for i in courtiers.size():
		var current: int = int(courtiers[i].get(stat, 0))
		if current > value:
			value = current
			best = i
	return best

func _find_effect(g, edge: String, kind: String, house_index: int) -> Dictionary:
	for entry in g.effect_log:
		if str(entry.get("edge", "")) != edge:
			continue
		if str(entry.get("kind", "")) != kind:
			continue
		if int(entry.get("house", -1)) != house_index:
			continue
		return entry
	return {}

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	if _failed:
		return
	_failed = true
	print("SYSTEMICDEPTHTEST FAIL: " + message)
	get_tree().quit(1)
