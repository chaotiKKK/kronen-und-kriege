extends Node

var checks := 0

func _ready() -> void:
	if not check(ResourceLoader.exists("res://scripts/GameRegionData.gd"), "Spieladapter fehlt"):
		return
	var data = load("res://scripts/GameRegionData.gd")
	var provinces: Array = data.provinces()
	if not check(provinces.size() == 108, "108 spielbare Regionen"):
		return
	var income := 0
	var levy := 0
	var incomes := [0, 0, 0, 0, 0, 0, 0, 0, 0]
	var levies := [0, 0, 0, 0, 0, 0, 0, 0, 0]
	var house_data: Array = data.houses()
	for p in provinces:
		income += int(p.base_income)
		levy += int(p.levy)
		incomes[int(p.owner)] += int(p.base_income)
		levies[int(p.owner)] += int(p.levy)
		if not check(not p.parts.is_empty() and p.points.size() >= 3, "Spielgeometrie vorhanden"):
			return
	for index in house_data.size():
		var capital_id := str(house_data[index].capital)
		var capital: Dictionary = {}
		for p in provinces:
			if p.id == capital_id:
				capital = p
		if not check(not capital.is_empty() and int(capital.owner) == index and bool(capital.capital), "Eigene Hauptstadt zugewiesen"):
			return
		incomes[index] += int(int(house_data[index].ruler.stewardship) / 4)
	if not check(income == 740, "Provinzeinkommen exakt erhalten"):
		return
	if not check(levy == 24240, "Aufgebot exakt erhalten"):
		return
	if not check(incomes == [95, 98, 74, 82, 86, 94, 79, 70, 84], "Einkommen je Haus erhalten"):
		return
	if not check(levies == [3090, 3090, 2390, 2710, 2780, 2920, 2480, 2290, 2490], "Aufgebot je Haus erhalten"):
		return
	seed(1701)
	var game = load("res://scripts/Game.gd").new(data, 0)
	if not check(game.provinces.size() == 108, "Bestehende Engine nimmt neue Regionsdaten an"):
		return
	if not check(not game.province(str(game.house().capital)).is_empty(), "Spielerhauptstadt spielbar"):
		return
	if not check(game.has_method("region_income_total"), "Regionsgewichteter Wirtschaftsfluss fehlt"):
		return
	if not check(game.region_income_total() == 762, "Jährliche Startwirtschaft exakt 762"):
		return
	seed(1701)
	var old_game = load("res://scripts/Game.gd").new(load("res://scripts/Data.gd"), 0)
	for index in house_data.size():
		var old_gold := int(old_game.houses[index].gold)
		var new_gold := int(game.houses[index].gold)
		old_game._apply_house_economy(index)
		game._apply_house_economy(index)
		if not check(int(old_game.houses[index].gold) - old_gold == int(game.houses[index].gold) - new_gold, "Tatsächlicher jährlicher Wirtschaftsfluss je Haus erhalten"):
			return
	var state: Dictionary = game.snapshot()
	var restored = load("res://scripts/Game.gd").new(data, 0)
	var loaded: bool = restored.restore(JSON.parse_string(JSON.stringify(state)))
	if not check(loaded, "Roundtrip einer neuen Regionspartie"):
		return
	if not check(restored.provinces.size() == 108, "Roundtrip erhält Regionszahl"):
		return
	if not check(game.has_method("region_capacity"), "Regionsgewichtete Aufgebotskapazität fehlt"):
		return
	var quarter := {"economic_share": 0.25, "levy": 100, "dev": 3}
	var capacity: Dictionary = game.region_capacity(quarter)
	if not check(capacity == {"maximum":1000, "recruit":40, "recruit_cost":8, "develop":30, "develop_cost":13, "annual_flat":1}, "Viertelregion erhält Viertelkapazität und anteilige Kosten"):
		return
	var growth_game = load("res://scripts/Game.gd").new(load("res://scripts/Data.gd"), 0)
	growth_game.provinces = [{"id":"quarter", "name":"Viertel", "owner":0, "dev":3, "levy":100, "economic_share":0.25}, {"levy":100, "economic_share":0.75}]
	growth_game._regenerate_province_levies()
	if not check(int(growth_game.provinces[0].levy) == 103 and int(growth_game.provinces[1].levy) == 106, "Jährlicher Flachbonus skaliert mit der Regionskapazität"):
		return
	growth_game.houses[0].gold = 100
	if not check(bool(growth_game.recruit("quarter").ok) and int(growth_game.provinces[0].levy) == 143 and int(growth_game.houses[0].gold) == 92, "Werbung nutzt echte Regionskosten und Kapazität"):
		return
	if not check(bool(growth_game.develop("quarter").ok) and int(growth_game.provinces[0].levy) == 173 and int(growth_game.houses[0].gold) == 79, "Ausbau nutzt echte Regionskosten und Kapazität"):
		return
	growth_game.provinces[0].levy = 1100
	if not check(not bool(growth_game.recruit("quarter").ok) and int(growth_game.houses[0].gold) == 79 and int(growth_game.provinces[0].levy) == 1100, "Volle Region kostet kein Gold und verliert keine vorhandenen Truppen"):
		return
	growth_game._regenerate_province_levies()
	if not check(int(growth_game.provinces[0].levy) == 1100, "Geerbter Überhang wird beim Jahreswechsel erhalten"):
		return
	if not check(game.has_method("building_effect_units"), "Gewichtete Gebäudewirkung fehlt"):
		return
	var inherited := {"economic_share":0.25,"buildings":{"market":2},"initial_buildings":{"market":1},"building_effects":{"market":0.1}}
	if not check(absf(game.building_effect_units(inherited, "market") - 0.35) < 0.000001, "Geerbte Gebäudewirkung plus lokale Aufwertung"):
		return
	if not check(growth_game.building_cost("market", "quarter") == 15, "Gebäudekosten für Viertelregion gewichtet"):
		return
	print("GAMEREGIONDATATEST OK: %d Prüfungen" % checks)
	get_tree().quit(0)

func check(condition: bool, message: String) -> bool:
	checks += 1
	if condition:
		return true
	print("GAMEREGIONDATATEST FAIL: " + message)
	get_tree().quit(1)
	return false
