extends Node
const Game = preload("res://scripts/Game.gd")
const Data = preload("res://scripts/GameRegionData.gd")
const Infra = preload("res://scripts/Infrastructure.gd")
var checks := 0
var failures := 0

func _ready() -> void:
	if not check(Infra.INNOVATIONS.size() >= 16, "Mindestens sechzehn inhaltliche Innovationen fehlen"):
		finish()
		return
	var g = Game.new(Data, 0)
	check(g.region_income_total() == 762, "Ohne Forschung bleibt die gewichtete Startwirtschaft erhalten")
	check(Infra.INNOVATIONS.surveying.gold == 20 and Infra.INNOVATIONS.surveying.months == 6, "Bestehende Vermessung bleibt kompatibel")
	check(Infra.INNOVATIONS.road_building.gold == 40 and Infra.INNOVATIONS.road_building.months == 12, "Bestehender Straßenbau bleibt kompatibel")
	for id in Infra.INNOVATIONS:
		var entry: Dictionary = Infra.INNOVATIONS[id]
		for field in ["name", "branch", "description", "effect_text", "effects"]:
			check(entry.has(field), "Forschungsbeschreibung fehlt: %s / %s" % [id, field])
		check(str(entry.requires) == "" or Infra.INNOVATIONS.has(str(entry.requires)), "Voraussetzung ist definiert")
		for terrain in entry.get("terrains", []):
			check(load("res://scripts/Data.gd").TERRAIN_TYPES.has(str(terrain)), "Forschung verweist nur auf wirklich vorhandene Geländetypen")
	g.house().gold = 1000
	var choice: Dictionary = _choice(g, "fortification")
	check(str(choice.blocked_reason).contains("Steinbau"), "Voraussetzung verwendet den wirklichen Innovationsnamen")
	check(not bool(choice.enabled) and not bool(choice.known), "Gesperrter Wissenszweig bleibt deaktiviert")
	g.house().research.known = ["surveying"]
	check(g.start_research("crop_rotation").ok, "Fruchtwechsel kann legal begonnen werden")
	for month in 3:
		g._tick_infrastructure()
	choice = _choice(g, "crop_rotation")
	check(choice.active and choice.remaining == 5 and choice.status == "active", "Forschungsfortschritt ist genau ablesbar")
	var restored = Game.new(Data, 0)
	check(restored.restore(JSON.parse_string(JSON.stringify(g.snapshot()))), "Aktive Forschung bleibt nach JSON-Roundtrip erhalten")
	check(restored.house().research.active == "crop_rotation" and restored.house().research.months == 5, "Dauer und Projekt bleiben erhalten")
	g.house().research.active = ""
	g.house().research.months = 0
	var p: Dictionary = g.provinces[0]
	p.owner = 0
	p.terrain = "plains"
	var base_income: int = g.region_income(p)
	g.house().research.known = ["surveying", "crop_rotation"]
	check(g.region_income(p) == roundi(base_income * 1.10), "Fruchtwechsel verbessert tatsächlich örtlichen Ertrag")
	p.terrain = "mountains"
	check(g.region_income(p) == base_income, "Agrarbonus wird nicht wahllos auf Berge angewandt")
	var actual_farmland: Dictionary = {}
	for candidate in g.provinces:
		if str(candidate.terrain) == "farmland":
			actual_farmland = candidate
			break
	check(not actual_farmland.is_empty(), "Echtes Ackerland ist im Regionskatalog vorhanden")
	if not actual_farmland.is_empty():
		actual_farmland.owner = 0
		g.house().research.known = []
		var farm_income: int = g.region_income(actual_farmland)
		g.house().research.known = ["surveying", "crop_rotation"]
		check(g.region_income(actual_farmland) == roundi(farm_income * 1.10), "Fruchtwechsel verbessert eine echte Ackerlandregion")
		check(str(_choice(g, "crop_rotation").applicability).contains("Ackerland"), "Geländewirkung wird mit deutschem Namen erklärt")
	g.house().research.known = ["surveying", "masonry", "engineering", "drill"]
	var share := float(p.economic_share)
	check(g.building_cost("market", p.id) == maxi(1, roundi(roundi(60 * share) * 0.90)), "Steinbau senkt den tatsächlichen regionalen Baupreis")
	check(g.region_capacity(p).recruit_cost == maxi(1, roundi(roundi(30 * share) * 0.90)), "Drill senkt den tatsächlichen Werbungspreis")
	check(g.region_capacity(p).develop_cost == maxi(1, roundi(roundi(50 * share) * 0.90)), "Ingenieurwesen senkt den tatsächlichen Ausbaupreis")
	g.house().research.known = ["surveying", "field_medicine"]
	g.house().ruler.health = 70
	g._apply_research_health(0)
	check(g.house().ruler.health == 72, "Heilkunde wirkt wirklich auf die Gesundheit")
	g.house().research.known = ["surveying", "road_building", "logistics"]
	p.terrain_supply = 6
	if not check(g.has_method("army_upkeep") and g.has_method("army_supply_capacity"), "UI kann wirklichen Armeeunterhalt und Versorgung abfragen"):
		finish()
		return
	check(g.call("army_supply_capacity", str(p.id), 0) == 720, "UI-Versorgung zeigt den tatsächlichen Logistikbonus")
	g.house().armies = [{"id":1,"province":p.id,"strength":700,"upkeep":4,"morale":100}]
	g._apply_army_supply(0)
	check(g.house().armies[0].strength == 700, "Logistik verhindert echte Unterversorgung unter der neuen Kapazität")
	g.house().research.known = []
	g.house().gold = 100
	g.house().doctrine = "balanced"
	g._apply_army_upkeep(0)
	check(g.house().gold == 96, "Ausgewogener Armeeunterhalt bleibt unverändert")
	g.house().gold = 100
	g.house().doctrine = "cavalry"
	g._apply_army_upkeep(0)
	check(g.house().gold == 95, "Kavalleriedoktrin bezahlt den wirklichen höheren Unterhalt")
	check(g.call("army_upkeep", 0) == 5, "UI-Unterhalt enthält denselben Doktrinzuschlag wie die Abbuchung")
	for doctrine in ["balanced", "infantry", "cavalry", "siege"]:
		g.house().doctrine = doctrine
		for strength in [0, 1, 7, 100, 701]:
			var composition: Dictionary = g.call("army_composition", strength, 0)
			check(int(composition.levy) + int(composition.archer) + int(composition.knight) + int(composition.siege) == strength, "Jede Doktrin erhält dasselbe Stärkebudget")
	g.house().doctrine = "cavalry"
	var cavalry: Dictionary = g.call("army_composition", 1000, 0)
	g.house().doctrine = "infantry"
	var infantry: Dictionary = g.call("army_composition", 1000, 0)
	check(cavalry.knight > infantry.knight, "Doktrin verändert die tatsächliche Truppenaufteilung")
	check(g.doctrine_info().defense_multiplier > 1.0 and g.doctrine_info().attack_multiplier < 1.0, "Infanteriedoktrin besitzt einen echten Vor- und Nachteil")
	check(not _battle(1050, "balanced") and _battle(1050, "cavalry"), "Kavallerievorteil ändert den wirklichen Ausgang einer engen Feldschlacht")
	check(_battle(975, "balanced") and not _battle(975, "infantry"), "Infanterie bezahlt ihre Angriffseinbuße in einer wirklichen Schlacht")
	check(_battle(975, "balanced") and not _battle(975, "balanced", "infantry"), "Infanterieverteidigung schützt die wirkliche Zielprovinz")
	check(not _battle(1025, "balanced") and _battle(1025, "balanced", "balanced", ["surveying","drill","military_staff"]), "Erforschte Heeresplanung wirkt in der echten Schlacht")
	check(_battle(950, "balanced") and not _battle(950, "balanced", "balanced", [], ["surveying","masonry","fortification"]), "Befestigungswissen wirkt in der echten Verteidigung")
	check(_siege("siege") == _siege("balanced") + 8, "Belagerungsdoktrin beschleunigt die echte Belagerung um acht Punkte")
	check(_siege("balanced", ["surveying","masonry","engineering"]) == _siege("balanced") + 1, "Ingenieurwissen beschleunigt die echte Belagerung")
	var broken: Dictionary = g.snapshot()
	broken.houses[0].research.known = ["fortification"]
	check(not Infra.validate(broken).is_empty(), "Beliebiger Forschungszweig ohne Voraussetzung wird abgewiesen")
	finish()

func _battle(target_levy: int, attacker: String, defender: String = "balanced", attack_tech: Array = [], defense_tech: Array = []) -> bool:
	var g = Game.new(load("res://scripts/Data.gd"), 0)
	var source: Dictionary = g.provinces[0]
	var target: Dictionary = g.province(str(g.neighbours(str(source.id))[0]))
	for p in g.provinces:
		p.owner = 8
	source.owner = 0
	source.levy = 1000
	target.owner = 1
	target.levy = target_levy
	target.dev = 0
	target.defense = 0
	target.terrain_defense = 0
	g.houses[0].ruler.martial = 0
	g.houses[1].ruler.martial = 0
	g.houses[0].doctrine = attacker
	g.houses[1].doctrine = defender
	g.houses[0].research.known = attack_tech
	g.houses[1].research.known = defense_tech
	g.houses[0].gold=1000
	g.houses[0].armies=[{"id":1,"province":source.id,"strength":1000,"upkeep":4,"morale":100}]
	g._add_claim(0, str(target.id))
	g.attack_roll_override = 1.0
	var result: Dictionary = g.attack(str(target.id))
	check(bool(result.ok),"Forschungsvergleich löst tatsächliche bezahlte Schlacht mit realem1000-Mann-Heer auf")
	return bool(result.get("won",false))

func _siege(doctrine: String, tech: Array = []) -> int:
	var g = Game.new(load("res://scripts/Data.gd"), 0)
	var target: Dictionary = g.province(str(g.neighbours(str(g.provinces[0].id))[0]))
	target.owner = 1
	g.houses[0].ruler.martial = 8
	g.house().doctrine = doctrine
	g.house().research.known = tech
	g._add_claim(0, str(target.id))
	g.house().armies = [{"id":1,"province":target.id,"strength":600,"upkeep":3,"morale":100}]
	g.advance_siege(str(target.id), 0)
	return int(target.siege)

func _choice(g, id: String) -> Dictionary:
	for choice in g.research_choices():
		if choice.id == id:
			return choice
	return {}

func check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		print("RESEARCHDEPTHTEST FAIL: " + message)
	return ok

func finish() -> void:
	print("RESEARCHDEPTHTEST %s; %d Prüfungen." % ["OK" if failures == 0 else "FAIL", checks])
	get_tree().quit(0 if failures == 0 else 1)
