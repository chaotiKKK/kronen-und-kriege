extends Node

const Game = preload("res://scripts/Game.gd")
const Data = preload("res://scripts/GameRegionData.gd")
const Save = preload("res://scripts/SaveGame.gd")
const Infra = preload("res://scripts/Infrastructure.gd")
const Kernel = preload("res://scripts/UiKernel.gd")
const SITE := "irrigation_works"
const TERRAINS := ["plains","farmland","steppe"]
var checks := 0
var failures := 0

func _ready() -> void:
	run_campaign()
	print("IRRIGATIONWORKSTEST %s: %d Prüfungen, %d Fehler" % ["OK" if failures==0 else "FAIL",checks,failures])
	get_tree().quit(0 if failures==0 else 1)

func run_campaign() -> void:
	seed(271108)
	var id := "iberien__04"
	var game = Game.new(Data,3)
	var player := int(game.player)
	var province: Dictionary = game.province(id)
	if not check(int(province.owner)==player and str(province.terrain) in TERRAINS,"Málaga ist ein reguläres geeignetes Startgebiet von Haus Tartessos"): return
	var missing: Dictionary = game.regional_project_preview(id,SITE)
	if not check(not missing.ok and str(missing.reason).contains("Bewässerung"),"Die Forschung schaltet einen tatsächlichen Regionalauftrag frei"): return
	for key in ["surveying","crop_rotation","irrigation"]:
		var before := int(game.house().gold)
		var started: Dictionary = game.start_research(key)
		if not check(started.ok and before-int(game.house().gold)==int(Infra.INNOVATIONS[key].gold),"Reguläre Forschung bezahlt: "+key): return
		for month in int(Infra.INNOVATIONS[key].months): advance(game)
		check(game.house().research.known.has(key),"Forschung schließt tatsächlich ab: "+key)
	var too_steep: Array = game.owned().filter(func(p): return not str(p.terrain) in TERRAINS)
	if not too_steep.is_empty():
		var refused: Dictionary = game.regional_project_preview(str(too_steep[0].id), SITE)
		check(not refused.ok and str(refused.reason).contains("Steppe"),"Wald oder Gebirge erhält bei gleicher Forschung keinen Hof")
	var quote: Dictionary = game.regional_project_preview(id,SITE)
	for month in 24:
		if quote.ok: break
		advance(game)
		quote = game.regional_project_preview(id,SITE)
	if not check(quote.ok and int(quote.gold)>0 and int(quote.material_total_u)>0 and int(quote.work_total_u)>0,"Der normale Haushalt finanziert einen bewerteten Anlagenbau: "+str(quote.reason)+" · "+id+" · Gold "+str(game.house().gold)): return
	var before := int(game.house().gold)
	write_evidence("BQ_IRRIGATION_BEFORE_PROOF",game.snapshot())
	var kernel = Kernel.new()
	kernel.bind_game(game)
	kernel.select_province(id)
	if not check(kernel.dispatch({"id":"build","key":SITE}).ok,"Bau wird über den regulären UI-Befehl angenommen"): return
	check(before-int(game.house().gold)==int(quote.gold) and province.regional_project.kind==SITE,"Auftrag bucht den Preis genau einmal")
	check(not game.start_regional_project(id,SITE).ok,"Es gibt keinen parallelen zweiten Kanalbau")
	var construction: Dictionary = game.snapshot()
	var staging = Game.new(Data,0)
	check(not construction.is_empty() and staging.restore(JSON.parse_string(JSON.stringify(construction))),"Offener Bauauftrag bleibt im Spielstand ladbar")
	var interrupted: Dictionary = staging.province(id)
	var builder_state: Dictionary = interrupted.regional_project.duplicate(true)
	var enemy: int = (player+1)%staging.houses.size()
	staging.houses[enemy].armies.append({"id":92,"province":id,"strength":100,"upkeep":1,"morale":90})
	staging._tick_regional_economy(staging.road_segments())
	check(staging._production_blocked().has(id) and interrupted.regional_project==builder_state,"Feindliches Feldheer unterbricht die reguläre Bauarbeit")
	staging._capture_province(id,enemy)
	check(interrupted.regional_project.is_empty() and not interrupted.logistics_sites.has(SITE),"Eroberung während des Baus hinterlässt kein fertiges Werk")
	var broken := construction.duplicate(true)
	find_province(broken,id).regional_project.work_total_u += 1
	check(not Save.validate(broken).is_empty(),"Gefälschte Arbeitskosten des Kanals werden abgewiesen")
	var without_knowledge := construction.duplicate(true)
	without_knowledge.houses[player].research.known.erase("irrigation")
	check(not Save.validate(without_knowledge).is_empty(),"Angefangener Kanalbau ohne Wissen wird abgewiesen")
	var progress := false
	var finished_month := -1
	for month in 72:
		advance(game)
		if int(province.logistics_sites.get(SITE,0))==1:
			finished_month = game.calendar_index()
			break
		var paid: Dictionary = province.regional_project
		if not paid.is_empty() and int(paid.work_done_u)>0 and int(paid.material_spent_u)>0:
			progress = true
	if not check(progress and finished_month>int(construction.month_index) and province.regional_project.is_empty(),"Werk entsteht aus gebuchten Materialien und Arbeit über mehrere Monate"): return
	var finished: Dictionary = game.snapshot()
	var without = Game.new(Data,0)
	if not check(not finished.is_empty() and without.restore(JSON.parse_string(JSON.stringify(finished))),"Gebaute Anlage ist Teil des Spielstands"): return
	without.province(id).logistics_sites.erase(SITE)
	var earlier: Dictionary = game.provision_report().regions[id]
	check(int(earlier.produced_u)>=0 and game.calendar_index()==finished_month,"Baufertigstellung und zivile Bilanz bleiben nachvollziehbar")
	var before_yield: Dictionary = without.provision_preview(id).next
	var after_yield: Dictionary = game.provision_preview(id).next
	check(int(after_yield.farm_work_u)<int(before_yield.farm_work_u) and int(after_yield.consumed_u)==int(before_yield.consumed_u) and int(after_yield.industry_labor_u)>int(before_yield.industry_labor_u),"Dieselbe Ration braucht weniger Landarbeit und lässt Arbeit für Ausbau frei")
	write_evidence("BQ_IRRIGATION_CAMPAIGN_PROOF",finished)
	seed(271108)
	advance(game)
	seed(271108)
	advance(without)
	var actual: Dictionary = game.provision_report().regions[id]
	var no_site: Dictionary = without.provision_report().regions[id]
	check(int(actual.farm_work_u)==int(after_yield.farm_work_u) and int(actual.farm_work_u)<int(no_site.farm_work_u),"Der reguläre Folgemonat bucht wirklich den Entlastungseffekt")
	check(not game.start_regional_project(id,SITE).ok,"Eine fertiggestellte Anlage lässt keine zweite zu")
	var malformed := finished.duplicate(true)
	find_province(malformed,id).logistics_sites[SITE] = 2
	check(not Save.validate(malformed).is_empty(),"Gefälschte Anlagenstufe wird abgewiesen")
	if not too_steep.is_empty():
		malformed = finished.duplicate(true)
		find_province(malformed,str(too_steep[0].id)).logistics_sites[SITE] = 1
		check(not Save.validate(malformed).is_empty(),"Ein fertiges Werk in ungeeignetem Gelände ist ungültig")
	var occupied = Game.new(Data,0)
	check(occupied.restore(finished),"Kontrollwelt kann den wirklichen Bauabschluss laden")
	occupied._capture_province(id,(player+1)%occupied.houses.size())
	check(int(occupied.province(id).logistics_sites.get(SITE,0))==1 and not occupied.snapshot().is_empty(),"Eigentumswechsel erhält den gebauten Standort")
	print("IRRIGATION_RESULT province=",province.name," id=",id," built_month=",finished_month," price=",quote.gold," farm_before=",no_site.farm_work_u," farm_with=",actual.farm_work_u," ration_u=",actual.consumed_u," industry_with=",actual.industry_labor_u)

func write_evidence(variable: String, state: Dictionary) -> void:
	var path := OS.get_environment(variable)
	if path.is_empty(): return
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(state))

func advance(game) -> void:
	game.advance_month()
	if game.pending_event!=null:
		for i in range(game.pending_event.options.size()-1,-1,-1):
			if game.apply_event(i).ok: break
		if game.pending_event!=null: game.decline_event()

func find_province(state: Dictionary, id: String) -> Dictionary:
	for row in state.get("provinces", []):
		if str(row.id)==id: return row
	return {}

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		print("IRRIGATIONWORKSTEST FAIL: "+label)
	return ok
