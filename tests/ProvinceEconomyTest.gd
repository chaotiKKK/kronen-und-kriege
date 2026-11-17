extends Node
const Game = preload("res://scripts/Game.gd")
const Regions = preload("res://scripts/GameRegionData.gd")
const Save = preload("res://scripts/SaveGame.gd")
var checks := 0
var failures := 0

func _ready() -> void:
	var g = Game.new(Regions,0)
	check(g.has_method("set_province_focus"),"Schwerpunkt-API vorhanden")
	if not g.has_method("set_province_focus"):
		finish()
		return
	_test_real_start(g)
	_test_annual_values()
	_test_weighted_markets()
	_test_migration()
	_test_sandbox()
	finish()

func _test_real_start(g) -> void:
	check(g.provinces.size() == 108 and int(g.house().gold) == 140,"Echter 108-Regionen-Start ohne Kassencheat")
	var home := str(g.house().capital)
	var p: Dictionary = g.province(home)
	var cost := maxi(1,roundi(20 * float(p.economic_share)))
	var before: Dictionary = g.snapshot()
	var preview: Dictionary = g.province_economy_preview(home,"agriculture")
	check(g.snapshot() == before,"Vorschau ist frei von Buchungen und Zustandsänderungen")
	check(preview.current_focus == "balanced" and preview.focus == "agriculture" and int(preview.cost) == cost,"Vorschau nennt echte Auswahl und gewichtete Kosten")
	check(int(preview.projected_supply) == roundi(int(preview.current_supply) * 1.5),"Kornkammer erhöht lokale Versorgung um50Prozent")
	var choices: Array = g.province_focus_choices(home)
	check(choices.size() == 3 and not choices[0].enabled and choices[1].enabled,"Ein Wähler enthält drei wohldefinierte Schwerpunkte")
	check(g.set_province_focus(home,"agriculture").ok,"Erster legaler Wechsel mit tatsächlicher Startkasse")
	check(int(g.house().gold) == 140 - cost and p.economic_focus == "agriculture" and int(p.focus_changed_month) == 0,"Gold wird genau einmal gebucht und erster Wechselzeitpunkt gespeichert")
	check(g.province_economy_preview(home,"trade").lock_months == 12,"Bindung beträgt volle zwölf Monate")
	before = g.snapshot()
	check(not g.set_province_focus(home,"agriculture").ok and g.snapshot() == before,"Gleiche Auswahl kostet nichts und verändert nichts")
	check(not g.set_province_focus(home,"trade").ok and g.snapshot() == before,"Vorzeitiger Wechsel hat keinerlei Wirkung")
	check(not g.set_province_focus(home,"missing").ok and g.snapshot() == before,"Unbekannter Schwerpunkt verändert nichts")
	check(not g.set_province_focus(home,"trade",1).ok and g.snapshot() == before,"Fremdes Eigentum ist ohne Mutation geschützt")
	var restored = Game.new(Regions,0)
	check(restored.restore(JSON.parse_string(JSON.stringify(before))),"Schwerpunktzustand ist als JSON speicherbar")
	check(restored.province(home).economic_focus == "agriculture" and restored.province_economy_preview(home,"trade").lock_months == 12,"JSON-Roundtrip bewahrt Schwerpunkt und Bindung")
	g._capture_province(home,1)
	check(p.economic_focus == "agriculture" and int(p.focus_changed_month) == 0 and not g.set_province_focus(home,"trade",1).ok,"Eroberung erhält Schwerpunkt und bestehende Bindung")
	var ids: Array = []
	for hi in restored.houses.size(): ids.append(hi)
	restored.configure_human_houses(ids)
	for month in 11: restored.advance_month()
	check(not restored.set_province_focus(home,"trade").ok and restored.province_economy_preview(home,"trade").lock_months == 1,"Auch nach elf echten Monaten bleibt ein Monat Bindung")
	restored.advance_month()
	check(restored.province_economy_preview(home,"trade").lock_months == 0 and restored.set_province_focus(home,"trade").ok,"Nach zwölf echten Monaten wird der Wechsel wieder möglich")

func _old_income(g,p: Dictionary) -> int:
	var delta := int(p.dev) - int(p.initial_dev)
	var base := maxi(0,int(p.base_income) + roundi(delta * 4.0 * float(p.economic_share)))
	return roundi(base * (1.0 + minf(40.0,g.research_bonus("income_percent",int(p.owner),p)) / 100.0))

func _test_annual_values() -> void:
	var g = Game.new(Regions,0)
	var units := 0.0
	for p in g.provinces:
		check(g.region_income(p) == _old_income(g,p),"Ausgewogener Grundbetrag bleibt exakt erhalten:" + str(p.id))
		if int(p.owner) == 0: units += g.building_effect_units(p,"market")
	var before := int(g.house().gold)
	g._apply_market_income(0)
	check(int(g.house().gold) - before == roundi(units * 4.0),"Ausgewogene Marktsteuer erhält die alte Summenrundung exakt")
	var p: Dictionary = g.province(str(g.house().capital))
	p.base_income = 100
	p.initial_dev = p.dev
	p.buildings.market = 1
	p.initial_buildings.market = 1
	p.building_effects.market = 1.0
	g.house().research.known = ["surveying","accounting","trade_charters","road_building","logistics"]
	var base: Dictionary = g.province_economy_preview(str(p.id))
	var farming: Dictionary = g.province_economy_preview(str(p.id),"agriculture")
	var trade: Dictionary = g.province_economy_preview(str(p.id),"trade")
	check(int(farming.projected_income) < int(base.current_income) and int(trade.projected_income) > int(base.current_income),"Schwerpunkte tauschen echte Grund- und Markteinnahmen gegen Versorgung")
	check(int(base.current_supply) == roundi(int(p.terrain_supply) * 100 * 1.2),"Forschung beeinflusst die lokale Basis genau einmal")
	check(int(farming.projected_supply) == roundi(int(base.current_supply) * 1.5) and int(trade.projected_supply) == roundi(int(base.current_supply) * 0.8),"Schwerpunkte multiplizieren die erforschte Basis genau einmal")
	p.economic_focus = "agriculture"
	check(g.region_income(p) == roundi(105 * 0.85),"Kornkammer senkt auch erforschten Grundbetrag")
	before = int(g.house().gold)
	g._apply_market_income(0)
	check(int(g.house().gold) - before == roundi(4.0 * 1.08 * 0.85),"Kornkammer senkt auch den tatsächlichen Marktertrag")

func _test_weighted_markets() -> void:
	var g = Game.new(Regions,0)
	for index in g.provinces.size():
		var p: Dictionary = g.provinces[index]
		p.buildings.market = 1
		p.initial_buildings.market = 1
		p.building_effects.market = float(index % 7 + 1) / 13.0
	for hi in g.houses.size():
		g.houses[hi].research.known = ["surveying","accounting","trade_charters"]
		var units := 0.0
		for p in g.provinces:
			if int(p.owner) == hi:
				units += g.building_effect_units(p,"market")
		var expected := roundi(units * 4.0 * 1.08)
		var gold := int(g.houses[hi].gold)
		g._apply_market_income(hi)
		check(int(g.houses[hi].gold) - gold == expected,"Alle108gewichteten Alt-Markteffekte erhalten je Haus exakt die bisherige Summenrundung")

func _test_sandbox() -> void:
	var g = Game.new(Regions,0)
	g.year = 2201
	g.month = 4
	g.campaign_sandbox = true
	var id := str(g.house().capital)
	check(g.set_province_focus(id,"agriculture").ok,"Legaler Schwerpunktwechsel nach2200inSandbox")
	var restored = Game.new(Regions,0)
	check(restored.restore(JSON.parse_string(JSON.stringify(g.snapshot()))) and restored.year == 2201,"Sandbox-Schwerpunkt nachKampagnenende speicherbar und ladbar")
	check(restored.province_economy_preview(id,"trade").lock_months == 12,"Sandbox-Roundtrip bewahrt volleBindung ohne künstlicheLAST_MONTHGrenze")

func _test_migration() -> void:
	var g = Game.new(Regions,0)
	var s: Dictionary = g.snapshot()
	check(int(s.schema_version) == Save.CURRENT_VERSION,"Snapshot verwendet das aktuelle Schema")
	var old: Dictionary = s.duplicate(true)
	old.schema_version = 13
	for p in old.provinces:
		p.erase("economic_focus")
		p.erase("focus_changed_month")
	var migrated: Dictionary = Save.migrate(old)
	check(migrated.ok and Save.diff(s,migrated.data).is_empty(),"Schema13 migriert ohne Änderung alter Erträge, Gebäude oder Straßen")
	for invalid in ["missing",1,null]:
		var bad: Dictionary = s.duplicate(true)
		bad.provinces[0].economic_focus = invalid
		check(not Save.migrate(bad).ok,"Unbekannte oder falsch typisierte Fokus-ID abgewiesen")
	for invalid in [-2,0.5,1,"0",null]:
		var bad: Dictionary = s.duplicate(true)
		bad.provinces[0].focus_changed_month = invalid
		check(not Save.migrate(bad).ok,"Ungültiger roher Bindungszeitpunkt abgewiesen")
	var bad: Dictionary = s.duplicate(true)
	bad.provinces[0].erase("economic_focus")
	check(not Save.migrate(bad).ok,"Aktuelles Schema darf Fokusfeld nicht verlieren")
	bad = s.duplicate(true)
	bad.provinces[0].erase("focus_changed_month")
	check(not Save.validate(bad).is_empty(),"Aktuelles Schema darf Bindungsfeld nicht verlieren")

func check(ok: bool,message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("PROVINCEECONOMYTEST FAIL: " + message)

func finish() -> void:
	print("PROVINCEECONOMYTEST %s: %d Prüfungen" % ["OK" if failures == 0 else "FAIL",checks])
	get_tree().quit(0 if failures == 0 else 1)
