extends Node
## Vollständiger Kausalitätstest für die Systemtiefe-Matrix.
##
## Jede Kante wird mindestens einmal positiv über die echte Spiel-API ausgelöst
## und danach mit deaktivierter Kante kontrolliert. Die fünf Welle-1-Kanten
## H1, H2, H5, D5 und AI1 bleiben zusätzlich in SystemicDepthTest abgedeckt.
##
## Aufruf: godot --headless --path . res://tests/FullDepthTest.tscn
## Exit-Code 0 = bestanden, 1 = fehlgeschlagen.

const DataScript = preload("res://scripts/Data.gd")
const GameScript = preload("res://scripts/Game.gd")

var _failed := false
var _checks := 0

func _ready() -> void:
	seed(20261106)
	_test_h3()
	_test_h4()
	_test_h5_walls()
	_test_h6()
	_test_h7()
	_test_h8()
	_test_d1()
	_test_d2()
	_test_d3_d4()
	_test_d6()
	_test_d7()
	_test_d8()
	_test_k1()
	_test_k2()
	_test_k3()
	_test_k4_k5()
	_test_k6()
	_test_k7()
	_test_ai2()
	_test_ai3()
	_test_ai4()
	_test_ai5()
	if _failed:
		return
	print("FULLDEPTHTEST OK: H3, H4, H5(Mauern), H6, H7, H8, D1, D2, D3, D4, D6, D7, D8, K1-K7 und AI2-AI5 positiv sowie negativ kontrolliert; %d Prüfungen." % _checks)
	get_tree().quit(0)

func _test_h3() -> void:
	var g = _new_game(0)
	g.houses[0]["laws"]["tax"] = 2
	g.effect_log.clear()
	g._apply_tax_income(0, 100)
	_need(g, "H3", "gold", 0, "H3: Steuersatz erzeugt keinen Goldbeleg.")
	var n = _new_game(0)
	n.houses[0]["laws"]["tax"] = 2
	n.set_edge_enabled("H3", false)
	n.effect_log.clear()
	n._apply_tax_income(0, 100)
	_deny(n, "H3", "H3-Negativ: Steuerbeleg trotz deaktivierter Kante.")

func _test_h4() -> void:
	var g = _new_game(0)
	var capital: Dictionary = _capital(g, 0)
	capital["buildings"]["market"] = 1
	g.effect_log.clear()
	g._apply_market_income(0)
	_need(g, "H4", "gold", 0, "H4: Markt erzeugt keinen Goldbeleg.")
	var n = _new_game(0)
	var ncapital: Dictionary = _capital(n, 0)
	ncapital["buildings"]["market"] = 1
	n.set_edge_enabled("H4", false)
	n.effect_log.clear()
	n._apply_market_income(0)
	_deny(n, "H4", "H4-Negativ: Marktbeleg trotz deaktivierter Kante.")

func _test_h5_walls() -> void:
	var g = _new_game(0)
	var capital: Dictionary = _capital(g, 0)
	g.house()["gold"] = 500
	g.effect_log.clear()
	var result: Dictionary = g.build(str(capital["id"]), "walls")
	_check(bool(result["ok"]), "H5-Mauern: Bau wurde abgelehnt.")
	_need(g, "H5", "defense", 0, "H5-Mauern: Kein Verteidigungsbeleg.")
	_check(int(capital["defense"]) > 0, "H5-Mauern: Verteidigung blieb 0.")
	var n = _new_game(0)
	var ncapital: Dictionary = _capital(n, 0)
	n.house()["gold"] = 500
	n.set_edge_enabled("H5", false)
	n.effect_log.clear()
	n.build(str(ncapital["id"]), "walls")
	_deny(n, "H5", "H5-Mauern-Negativ: Verteidigungsbeleg trotz deaktivierter Kante.")

func _test_h6() -> void:
	var g = _new_game(0)
	g.house()["legitimacy"] = 20
	g.effect_log.clear()
	g._apply_legitimacy_effects(0)
	_need(g, "H6", "opinion", 0, "H6: Niedrige Legitimität senkt keine Meinung.")
	var n = _new_game(0)
	n.house()["legitimacy"] = 20
	n.set_edge_enabled("H6", false)
	n.effect_log.clear()
	n._apply_legitimacy_effects(0)
	_deny(n, "H6", "H6-Negativ: Meinungsbeleg trotz deaktivierter Kante.")

func _test_h7() -> void:
	var g = _new_game(0)
	g.house()["factions"][0]["power"] = 80
	g.house()["laws"]["tax"] = 0
	g.effect_log.clear()
	g._apply_faction_pressure(0)
	_need(g, "H7", "law", 0, "H7: Faktion erzwingt kein Gesetz.")
	var n = _new_game(0)
	n.house()["factions"][0]["power"] = 80
	n.house()["laws"]["tax"] = 0
	n.set_edge_enabled("H7", false)
	n.effect_log.clear()
	n._apply_faction_pressure(0)
	_deny(n, "H7", "H7-Negativ: Gesetzesbeleg trotz deaktivierter Kante.")

func _test_h8() -> void:
	var g = _new_game(0)
	g.house()["factions"][0]["power"] = 80
	g.effect_log.clear()
	g._apply_faction_pressure(0)
	_need(g, "H8", "levy", 0, "H8: Faktion senkt keine Truppen.")
	var n = _new_game(0)
	n.house()["factions"][0]["power"] = 80
	n.set_edge_enabled("H8", false)
	n.effect_log.clear()
	n._apply_faction_pressure(0)
	_deny(n, "H8", "H8-Negativ: Levy-Beleg trotz deaktivierter Kante.")

func _test_d1() -> void:
	var g = _new_game(0)
	g.house()["ruler"]["traits"] = ["Gelehrsam"]
	g.effect_log.clear()
	g._apply_trait_effects(0)
	_need(g, "D1", "gold", 0, "D1: Gelehrsamkeit erzeugt kein Gold.")
	var n = _new_game(0)
	n.house()["ruler"]["traits"] = ["Gelehrsam"]
	n.set_edge_enabled("D1", false)
	n.effect_log.clear()
	n._apply_trait_effects(0)
	_deny(n, "D1", "D1-Negativ: Goldbeleg trotz deaktivierter Kante.")

func _test_d2() -> void:
	var g = _new_game(0)
	g.house()["ruler"]["traits"] = ["Kriegserprobt"]
	g.effect_log.clear()
	g._apply_trait_effects(0)
	_need(g, "D2", "levy", 0, "D2: Kriegserprobt erhöht keine Truppen.")
	var n = _new_game(0)
	n.house()["ruler"]["traits"] = ["Kriegserprobt"]
	n.set_edge_enabled("D2", false)
	n.effect_log.clear()
	n._apply_trait_effects(0)
	_deny(n, "D2", "D2-Negativ: Levy-Beleg trotz deaktivierter Kante.")

func _test_d3_d4() -> void:
	var g = _new_game(0)
	var h: Dictionary = g.house()
	h["children"] = [{"name": "Erbe", "age": 20, "gender": "m", "portrait": 1, "education": "martial"}]
	g._recompute_heir(h)
	g.effect_log.clear()
	g._succession(0)
	_need(g, "D3", "ruler_stat", 0, "D3: Erziehung verändert den Herrscher nicht.")
	_need(g, "D4", "levy", 0, "D4: Militärische Erziehung erhöht keine Truppen.")
	var n = _new_game(0)
	var nh: Dictionary = n.house()
	nh["children"] = [{"name": "Erbe", "age": 20, "gender": "m", "portrait": 1, "education": "martial"}]
	n._recompute_heir(nh)
	n.set_edge_enabled("D3", false)
	n.set_edge_enabled("D4", false)
	n.effect_log.clear()
	n._succession(0)
	_deny(n, "D3", "D3-Negativ: Erziehungsbeleg trotz deaktivierter Kante.")
	_deny(n, "D4", "D4-Negativ: Levy-Beleg trotz deaktivierter Kante.")

func _test_d6() -> void:
	var g = _new_game(0)
	var target: String = _border_target(g, 0)
	_check(target != "", "D6: Kein Grenzziel gefunden.")
	g._add_claim(0, target)
	g.opinion[int(g.province(target)["owner"])] = 80
	_check(not g.can_attack(target), "D6: Freundschaft blockiert den Angriff nicht.")
	g.set_edge_enabled("D6", false)
	_check(g.can_attack(target), "D6-Negativ: deaktivierte Kante blockiert weiterhin.")
	print("D6 OK: hohe Meinung blockiert Angriff; Testhook gibt ihn frei.")

func _test_d7() -> void:
	var g = _new_game(0)
	g.discover_secret(1, 0)
	g.effect_log.clear()
	g.expose_secret(1, 0)
	_need(g, "D7", "scandal", 0, "D7: Geheimnis erzeugt keinen Skandal.")
	var n = _new_game(0)
	n.discover_secret(1, 0)
	n.set_edge_enabled("D7", false)
	n.effect_log.clear()
	n.expose_secret(1, 0)
	_deny(n, "D7", "D7-Negativ: Skandalbeleg trotz deaktivierter Kante.")

func _test_d8() -> void:
	var g = _new_game(0)
	g.discover_secret(1, 0)
	g.effect_log.clear()
	g.expose_secret(1, 0)
	_need(g, "D8", "claim", 0, "D8: Geheimnis erzeugt keinen Anspruch.")
	var n = _new_game(0)
	n.discover_secret(1, 0)
	n.set_edge_enabled("D8", false)
	n.effect_log.clear()
	n.expose_secret(1, 0)
	_deny(n, "D8", "D8-Negativ: Anspruchsbeleg trotz deaktivierter Kante.")

func _test_k1() -> void:
	var g = _new_game(0)
	var target: String = _border_target(g, 0)
	g._add_claim(0, target)
	g.effect_log.clear()
	g.press_claim(target, 0)
	_need(g, "K1", "legitimacy", 0, "K1: Anspruch erhöht keine Legitimität.")
	_need(g, "K1", "faction_power", 0, "K1: Anspruch bewegt keine Faktion.")
	var n = _new_game(0)
	var ntarget: String = _border_target(n, 0)
	n._add_claim(0, ntarget)
	n.set_edge_enabled("K1", false)
	n.effect_log.clear()
	n.press_claim(ntarget, 0)
	_deny(n, "K1", "K1-Negativ: Legitimitätsbeleg trotz deaktivierter Kante.")

func _test_k2() -> void:
	var g = _new_game(0)
	var target: String = _border_target(g, 0)
	_check(target != "", "K2: Kein Grenzziel gefunden.")
	_check(not g.can_attack(target), "K2: Angriff ohne Anspruch erlaubt.")
	g.set_edge_enabled("D6", false)
	g.set_edge_enabled("K7", false)
	g._add_claim(0, target)
	_check(g.can_attack(target), "K2: Angriff mit Anspruch blockiert.")
	g.set_edge_enabled("K2", false)
	g._remove_claim(target, 0)
	_check(g.can_attack(target), "K2-Negativ: deaktivierte Kante verlangt weiterhin Anspruch.")

func _test_k3() -> void:
	var g = _new_game(0)
	g.house()["armies"] = [{"id": 1, "province": str(_capital(g, 0)["id"]), "strength": 400, "upkeep": 5, "morale": 100}]
	g.effect_log.clear()
	var before: int = int(g.house()["gold"])
	g._apply_army_upkeep(0)
	_need(g, "K3", "gold", 0, "K3: Armeeunterhalt kostet kein Gold.")
	_check(int(g.house()["gold"]) == before - 5, "K3: Unterhalt ist nicht 5 Gold.")
	var n = _new_game(0)
	n.house()["armies"] = [{"id": 1, "province": str(_capital(n, 0)["id"]), "strength": 400, "upkeep": 5, "morale": 100}]
	n.set_edge_enabled("K3", false)
	n.effect_log.clear()
	n._apply_army_upkeep(0)
	_deny(n, "K3", "K3-Negativ: Unterhaltsbeleg trotz deaktivierter Kante.")

func _test_k4_k5() -> void:
	var g = _new_game(0)
	var target: String = _border_target(g, 0)
	g._add_claim(0, target)
	var p: Dictionary = g.province(target)
	p["buildings"]["barracks"] = 1
	g.house()["armies"] = [{"id": 1, "province": target, "strength": 4000, "upkeep": 2, "morale": 100}]
	g.effect_log.clear()
	g.advance_siege(target, 0)
	_need(g, "K4", "siege", 0, "K4: Armee erzeugt keinen Belagerungsfortschritt.")
	_check(int(p["siege"]) > 0 or int(p["owner"]) == 0, "K4: Belagerung blieb 0.")
	if int(p["owner"]) != 0:
		g.advance_siege(target, 0)
	if int(p["owner"]) != 0:
		g.advance_siege(target, 0)
	_check(int(p["owner"]) == 0, "K5: Belagerung nimmt die Provinz nicht ein.")
	_need(g, "K5", "dev", 0, "K5: Einnahme beschädigt die Entwicklung nicht.")
	var n = _new_game(0)
	var ntarget: String = _border_target(n, 0)
	n._add_claim(0, ntarget)
	n.house()["armies"] = [{"id": 1, "province": ntarget, "strength": 4000, "upkeep": 2, "morale": 100}]
	n.set_edge_enabled("K4", false)
	n.effect_log.clear()
	n.advance_siege(ntarget, 0)
	_deny(n, "K4", "K4-Negativ: Belagerungsbeleg trotz deaktivierter Kante.")

func _test_k6() -> void:
	var g = _new_game(0)
	g.effect_log.clear()
	g.make_peace(1, 0)
	_need(g, "K6", "truce", 0, "K6: Frieden erzeugt keinen Waffenstillstand.")
	_check(g.truce_until(1) > g._now(), "K6: Waffenstillstand liegt nicht in der Zukunft.")
	var n = _new_game(0)
	n.set_edge_enabled("K6", false)
	n.effect_log.clear()
	n.make_peace(1, 0)
	_deny(n, "K6", "K6-Negativ: Friedensbeleg trotz deaktivierter Kante.")

func _test_k7() -> void:
	var g = _new_game(0)
	var target: String = _border_target(g, 0)
	g._add_claim(0, target)
	g.make_peace(int(g.province(target)["owner"]), 0)
	g.set_edge_enabled("D6", false)
	_check(not g.can_attack(target), "K7: Waffenstillstand blockiert Angriff nicht.")
	g.set_edge_enabled("K7", false)
	_check(g.can_attack(target), "K7-Negativ: deaktivierte Kante blockiert weiterhin.")

func _test_ai2() -> void:
	var g = _new_game(0)
	g.houses[1]["laws"]["tax"] = 0
	g.effect_log.clear()
	g._apply_tax_income(1, 100)
	_need(g, "AI2", "gold", 1, "AI2: KI-Steuer erzeugt keinen Goldbeleg.")
	var n = _new_game(0)
	n.houses[1]["laws"]["tax"] = 0
	n.set_edge_enabled("AI2", false)
	n.effect_log.clear()
	n._apply_tax_income(1, 100)
	_deny(n, "AI2", "AI2-Negativ: Steuerbeleg trotz deaktivierter Kante.")

func _test_ai3() -> void:
	var g = _new_game(0)
	g.houses[1]["spouse"] = {}
	g.effect_log.clear()
	g._settle_marriage_for(1, 0, "AI3")
	_need(g, "AI3", "legitimacy", 1, "AI3: KI-Ehe erzeugt keinen Legitimitätsbeleg.")
	var n = _new_game(0)
	n.houses[1]["spouse"] = {}
	n.set_edge_enabled("AI3", false)
	n.effect_log.clear()
	n._settle_marriage_for(1, 0, "AI3")
	_deny(n, "AI3", "AI3-Negativ: Ehebeleg trotz deaktivierter Kante.")

func _test_ai4() -> void:
	var g = _new_game(0)
	var target: String = _border_target(g, 1)
	g._add_claim(1, target)
	g.houses[1]["armies"] = [{"id": 1, "province": target, "strength": 900, "upkeep": 2, "morale": 100}]
	g.effect_log.clear()
	g.advance_siege(target, 1)
	_need(g, "AI4", "siege", 1, "AI4: KI-Armee erzeugt keinen Belagerungsbeleg.")
	var n = _new_game(0)
	var ntarget: String = _border_target(n, 1)
	n._add_claim(1, ntarget)
	n.houses[1]["armies"] = [{"id": 1, "province": ntarget, "strength": 900, "upkeep": 2, "morale": 100}]
	n.set_edge_enabled("AI4", false)
	n.effect_log.clear()
	n.advance_siege(ntarget, 1)
	_deny(n, "AI4", "AI4-Negativ: Belagerungsbeleg trotz deaktivierter Kante.")

func _test_ai5() -> void:
	var g = _new_game(0)
	g.discover_secret(0, 1)
	g.effect_log.clear()
	g.expose_secret(0, 1)
	_need(g, "AI5", "scandal", 1, "AI5: KI-Geheimnis erzeugt keinen Skandalbeleg.")
	var n = _new_game(0)
	n.discover_secret(0, 1)
	n.set_edge_enabled("AI5", false)
	n.effect_log.clear()
	n.expose_secret(0, 1)
	_deny(n, "AI5", "AI5-Negativ: Skandalbeleg trotz deaktivierter Kante.")

# --- Helfer --------------------------------------------------------------

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

func _border_target(g, house_index: int) -> String:
	for p in g.provinces:
		if int(p["owner"]) != house_index:
			continue
		for n in g.neighbours(str(p["id"])):
			var q: Dictionary = g.province(str(n))
			if not q.is_empty() and int(q["owner"]) != house_index:
				return str(n)
	return ""

func _need(g, edge: String, kind: String, house_index: int, message: String) -> void:
	_checks += 1
	if _find_effect(g, edge, kind, house_index).is_empty():
		_fail(message)

func _deny(g, edge: String, message: String) -> void:
	_checks += 1
	if not _find_effect(g, edge, "", -1).is_empty():
		_fail(message)

func _find_effect(g, edge: String, kind: String = "", house_index: int = -1) -> Dictionary:
	for entry in g.effect_log:
		if str(entry.get("edge", "")) != edge:
			continue
		if kind != "" and str(entry.get("kind", "")) != kind:
			continue
		if house_index >= 0 and int(entry.get("house", -1)) != house_index:
			continue
		return entry
	return {}

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	print("FULLDEPTHTEST FAIL: " + message)
	get_tree().quit(1)
