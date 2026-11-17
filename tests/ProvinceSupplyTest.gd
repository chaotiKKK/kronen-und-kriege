extends Node
const Game = preload("res://scripts/Game.gd")
const Regions = preload("res://scripts/GameRegionData.gd")
var checks := 0
var failures := 0

func _ready() -> void:
	var g = Game.new(Regions,0)
	check(g.has_method("supply_report"),"Gemeinsame Versorgungsbilanz vorhanden")
	if not g.has_method("supply_report"):
		finish()
		return
	_test_network()
	_test_shared_losses()
	_test_equal_fractional_remainders()
	_test_research_and_foreign()
	finish()

func _fixture():
	var g = Game.new(Regions,0)
	var a := str(g.house().capital)
	var b := str(g.neighbours(a)[0])
	for p in g.provinces: p.owner = 1
	g.province(a).owner = 0
	g.province(b).owner = 0
	g.province(a).terrain_supply = 6
	g.province(a).economic_focus = "agriculture"
	g.province(b).terrain_supply = 2
	g.house().armies = [{"id":1,"province":b,"strength":500,"morale":100,"upkeep":2}]
	g.roads = [{"from":a,"to":b,"builder":0,"months":0,"state":"complete"}]
	return {"game":g,"a":a,"b":b}

func _test_network() -> void:
	var f = _fixture()
	var g = f.game
	var before: Dictionary = g.snapshot()
	var report: Dictionary = g.supply_report()
	check(g.snapshot() == before,"Versorgungsbilanz verändert keine Eingaben oder Partie")
	check(report.regions[f.a].export_available == 300 and report.regions[f.a].export == 300,"Nur freier Landwirtschaftsbonus wird einmal exportiert")
	check(report.regions[f.b].demand == 500 and report.regions[f.b].local_capacity == 200 and report.regions[f.b].import == 300 and report.regions[f.b].shortfall == 0,"Kornkammer versorgt echtes benachbartes Heerlager")
	g._apply_army_supply(0)
	check(int(g.army_for().strength) == 500,"Vollständig gedecktes Heer verliert keine Soldaten")
	g.roads[0].state = "building"
	g.roads[0].months = 1
	check(g.supply_report().regions[f.b].import == 0,"Unfertige Straße transportiert nichts")
	g._apply_army_supply(0)
	check(int(g.army_for().strength) == 494,"Ungedeckte300Soldaten erzeugen genau6jährliche Verluste")
	g.roads[0].state = "complete"
	g.roads[0].months = 0
	g.province(f.a).siege = 10
	g.province(f.a).siege_owner = 1
	check(g.supply_report().regions[f.b].import == 0,"Feindliche Belagerung kappt den Export sofort")
	g.province(f.a).siege = 0
	g.province(f.a).owner = 1
	check(g.supply_report().regions[f.b].import == 0,"Fremder Besitz kappt Straßenversorgung sofort")

func _test_shared_losses() -> void:
	var f = _fixture()
	var g = f.game
	g.house().armies = [{"id":2,"province":f.b,"strength":600,"morale":100,"upkeep":2},{"id":1,"province":f.b,"strength":400,"morale":100,"upkeep":2}]
	var report: Dictionary = g.supply_report()
	check(report.regions[f.b].demand == 1000 and report.regions[f.b].shortfall == 500,"Zwei Heere teilen dieselbe örtliche Deckung und denselben Import")
	g._apply_army_supply(0)
	check(int(g.house().armies[0].strength) == 594 and int(g.house().armies[1].strength) == 396,"Gemeinsames10MannVerlustbudget wird anteilig6zu4 verteilt")
	f = _fixture()
	g = f.game
	g.roads = []
	g.province(f.b).terrain_supply = 0
	g.house().armies = [{"id":2,"province":f.b,"strength":1,"morale":100,"upkeep":2},{"id":1,"province":f.b,"strength":1,"morale":100,"upkeep":2}]
	g._apply_army_supply(0)
	check(g.house().armies.size() == 1 and int(g.army_for().id) == 2 and int(g.army_for().strength) == 1,"Ein einziges Verlustbudget statt Mindestverlust je Heer; Rest entscheidet stabile ID")

func _test_equal_fractional_remainders() -> void:
	for order in [[1,2,3],[3,2,1]]:
		var f = _fixture()
		var g = f.game
		g.roads = []
		g.province(f.b).terrain_supply = 4
		g.house().research.known = ["surveying","road_building","logistics"]
		g.house().armies = []
		for id in order:
			g.house().armies.append({"id":id,"province":f.b,"strength":400 if id == 1 else 100,"morale":100,"upkeep":2})
		var report: Dictionary = g.supply_report()
		check(report.regions[f.b].local_capacity == 480 and report.regions[f.b].demand == 600 and report.regions[f.b].shortfall == 120,"Gleiche-Rest-Fixture: 400/100/100Mann teilen480Kapazität und genau2Verluste")
		g._apply_army_supply(0)
		var after := {}
		for army in g.house().armies:
			after[int(army.id)] = int(army.strength)
		check(after == {1:398,2:100,3:100},"Mathematisch gleiche Drittelreste entscheiden nach kleinster ID: Verluste2/0/0 unabhängig von Listenreihenfolge")

func _test_research_and_foreign() -> void:
	var f = _fixture()
	var g = f.game
	g.house().research.known = ["surveying","crop_rotation","road_building","logistics","granaries"]
	var report: Dictionary = g.supply_report()
	check(g.army_supply_capacity(f.a) == 1170 and report.regions[f.a].export_available == 390,"600Basis×1,3Forschung×1,5Fokus; Exportbonus390genaueinmal")
	g.province(f.b).owner = 1
	g.houses[1].research.known = []
	check(g.supply_report().regions[f.b].local_capacity == 260 and g.supply_report().regions[f.b].import == 0,"Eigenes Heer im Ausland nutzt eigene Forschung und örtlichen Fokus, keinen fremden Straßentransport")
	g.province(f.b).economic_focus = "trade"
	check(g.supply_report().regions[f.b].local_capacity == 208,"Fremder örtlicher Schwerpunkt multipliziert Forschung des stationierten Heeres genau einmal")
	check(g.supply_report(999).regions.is_empty(),"Ungültiges Haus liefert sichere leere Bilanz")

func check(ok: bool,message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("PROVINCESUPPLYTEST FAIL: " + message)

func finish() -> void:
	print("PROVINCESUPPLYTEST %s: %d Prüfungen" % ["OK" if failures == 0 else "FAIL",checks])
	get_tree().quit(0 if failures == 0 else 1)
