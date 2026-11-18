extends Node
## Reguläre Staatskasse, echte Monatszüge/NPCs/Ereignisse. Keine Rohstoff-,
## Technologie-, Armee- oder Geldgeschenke. Infrastruktur entsteht über Game.
const Game = preload("res://scripts/Game.gd")
const Data = preload("res://scripts/GameRegionData.gd")
const Save = preload("res://scripts/SaveGame.gd")
const Store = preload("res://scripts/SaveStore.gd")
var game
var checks := 0
var failures := 0
var actions: Array=[]
var months: Array=[]
var flows: Array=[]
var npc_orders: Array=[]
var spending := 0
var world_delta := 0
var event_delta := 0
var start_gold := 0
var source_start_dev := 0
var concurrent := false
var reloaded := false
var workshop_export := false
var depot_proved := false
var frontier: Dictionary={}
var source := "germanien__03" # München: tatsächlicher eigener Waldstandort.
var destination := "germanien__05" # Wien: tatsächliche eigene Landnachbarschaft.
var army_start := "germanien__02"
var target := "skythien__01" # Budapest: tatsächliches benachbartes Fremdgebiet.

func _ready() -> void:
	seed(20261118)
	game=Game.new(Data,0)
	game.speed=0
	start_gold=int(game.house().gold)
	source_start_dev=int(game.province(source).dev)
	check(start_gold==140 and game.provinces.size()==108 and game.houses.size()==9,"Unveränderter normaler Unetice-Start mit140Gold/108Regionen/neunHäusern")
	check(buy("Werkstätten München",func():return game.set_province_focus(source,"workshops")),"Erste Produktionsentscheidung ist regulär bezahlt")
	check(buy("Markt Hauptstadt",func():return game.build(str(game.house().capital),"market")),"Erster echter örtlicher Markt startet aus normaler Kasse")
	check(buy("Vermessung",func():return game.start_research("surveying")),"Forschungsweg beginnt ohne geschenkte Innovation")
	for step in 84:
		if game.game_over: break
		if int(game.province(source).owner)!=0 or int(game.province(destination).owner)!=0: break
		decide()
		if depot_proved: break
		var before: int=game.house().gold
		game.advance_month()
		world_delta+=int(game.house().gold)-before
		settle_event()
		observe()
		if not reloaded and game.calendar_index()>=12:
			var state: Dictionary=game.snapshot()
			check(Save.validate(state).is_empty(),"Regulärer Zwischenstand ist als aktueller Spielstand gültig")
			var checkpoint := "user://production-campaign-checkpoint.json"
			check(Store.write_snapshot(checkpoint,state),"Regulärer Zwischenstand wird über den tatsächlichen atomaren SaveStore geschrieben")
			var loaded: Dictionary=Store.load_snapshot(checkpoint)
			var copy = Game.new(Data,0)
			var restored: bool=bool(loaded.ok) and copy.restore(loaded.get("data",{}))
			var differences: Array=Save.diff(state,copy.snapshot()) if restored else [str(loaded.get("message","Restore fehlgeschlagen"))]
			if not differences.is_empty(): print("CAMPAIGN_SAVE_DIAGNOSTIC: ",JSON.stringify(differences))
			check(restored and differences.is_empty(),"Echter SaveStore-/JSON-Roundtrip erhält alle Spielwerte nach bestehendem Floatvergleichsvertrag")
			var exact_production := restored and int(copy.project_serial)==int(state.project_serial)
			if restored:
				for p in state.provinces:
					var q: Dictionary=copy.province(str(p.id))
					for key in ["production","regional_project","logistics_sites"]:
						if q[key]!=p[key]: exact_production=false
			check(exact_production,"Baustoffquanten, Verbrauchsreste, Projekte, Depots und Seriennummer bleiben zusätzlich exakt erhalten")
			game=copy
			reloaded=true
	check(workshop_export,"Regulär erzeugte Werkstattbaustoffe erreichen über tatsächlich errichtete Straße eine andere Baustelle")
	check(concurrent,"Entwicklung und Straßenbein konkurrieren tatsächlich am selben Standort um örtliche Arbeit")
	check(road_complete(),"Die regulär bezahlte zweibeinige Straße wird fertig")
	check(int(game.province(destination).buildings.walls)>=1,"Die belieferte tatsächliche Zielregion erhält ihre fertige Befestigung")
	check(int(game.province(destination).logistics_sites.depot)==1 and game.house().research.known.has("logistics"),"Erforschtes Frontdepot entsteht vollständig aus normalen Aufträgen")
	check(depot_proved,"Regulär bezahlte Armee und echter Nachschub verändern die vorhandene Belagerungsbewertung")
	check(not npc_orders.is_empty(),"Die acht nichtmenschlichen Häuser entwickeln ihre echte Welt während der Partie weiter")
	check(int(game.house().gold)==start_gold+world_delta+event_delta-spending,"Vollständige normale Geldrechnung ist ohne Debugguthaben geschlossen")
	check(Save.validate(game.snapshot()).is_empty(),"Endstand einschließlich aller NPC-Vorhaben bleibt gültig speicherbar")
	write_proof()
	print("PRODUCTIONCAMPAIGNTEST %s: %d Prüfungen, %d Fehler, Monat%d, Gold%d" % ["OK" if failures==0 else "FAIL",checks,failures,game.calendar_index(),int(game.house().gold)])
	get_tree().quit(0 if failures==0 else 1)

func decide() -> void:
	var research: Dictionary=game.house().research
	if research.known.has("surveying") and not research.known.has("road_building") and str(research.active).is_empty() and int(game.house().gold)>=40:
		buy("Straßenbau erforschen",func():return game.start_research("road_building"))
	if research.known.has("road_building") and game.roads.filter(func(r):return [str(r.from),str(r.to)].has(source) and [str(r.from),str(r.to)].has(destination)).is_empty():
		if game.road_preview(source,destination).ok:
			buy("Straße München–Wien",func():return game.build_road(source,destination))
			var road: Dictionary=find_road()
			if not road.is_empty(): buy("Straße bevorzugen",func():return game.prioritize_construction(source,int(road.construction.id),1))
	var road: Dictionary=find_road()
	if not road.is_empty() and int(game.province(source).dev)==source_start_dev and game.province(source).regional_project.is_empty() and game.regional_project_preview(source,"develop").ok:
		buy("Entwicklung München neben Straßenarbeit",func():return game.develop(source))
	if research.known.has("road_building") and not research.known.has("logistics") and str(research.active).is_empty() and int(game.house().gold)>=55:
		buy("Versorgungswesen",func():return game.start_research("logistics"))
	if road_complete() and int(game.province(destination).buildings.walls)==0 and game.province(destination).regional_project.is_empty() and game.regional_project_preview(destination,"walls").ok:
		buy("Grenzmauern Wien",func():return game.build(destination,"walls"))
	if workshop_export and str(game.province(source).economic_focus)=="workshops" and game.province_focus_reason(source,"agriculture").is_empty():
		buy("Werkstätten werden zur Kornkammer",func():return game.set_province_focus(source,"agriculture"))
	if research.known.has("logistics") and int(game.province(destination).buildings.walls)>0 and int(game.province(destination).logistics_sites.depot)==0 and game.province(destination).regional_project.is_empty() and game.regional_project_preview(destination,"depot").ok:
		buy("Frontdepot Wien",func():return game.build(destination,"depot"))
	if int(game.province(destination).logistics_sites.depot)!=1: return
	var army: Dictionary=game.army_for()
	if army.is_empty() and int(game.house().gold)>=90 and int(game.province(army_start).owner)==0:
		buy("Feldarmee Hamburg",func():return game.raise_army(army_start))
		army=game.army_for()
	if army.is_empty(): return
	if int(game.province(target).owner)==0: return
	if not game.has_claim(target) and game.claim_reason(target).is_empty(): buy("Anspruch auf Grenzziel",func():return game.fabricate_claim(target))
	var position := str(army.province)
	var next := ""
	if position==army_start: next=source
	elif position==source: next=destination
	elif position==destination and game.has_claim(target): next=target
	if not next.is_empty() and game.can_march(next): buy("Feldmarsch nach "+next,func():return game.march_army(next))
	if str(army.province)==target and game.siege_reason(target).is_empty(): prove_frontier()

func observe() -> void:
	var report: Dictionary=game.regional_production_report()
	for id in report.ledger:
		var row: Dictionary=report.ledger[id]
		check(int(row.before_u)+int(row.produced_u)+int(row.import_u)-int(row.used_u)-int(row.export_u)-int(row.wasted_u)==int(row.after_u),"Erhaltener örtlicher Materialfluss in Monat%d/%s" % [game.calendar_index(),id])
	for flow in report.flows:
		flows.append({"month":game.calendar_index(),"flow":flow.duplicate(true)})
		if str(flow.from)==source and str(flow.to)==destination and str(game.province(source).economic_focus)=="workshops": workshop_export=true
	var road: Dictionary=find_road()
	if not road.is_empty() and not road.get("construction",{}).is_empty() and not game.province(source).regional_project.is_empty():
		for leg in road.construction.legs:
			if str(leg.province)==source and int(leg.work_done_u)>0 and int(game.province(source).regional_project.work_done_u)>0: concurrent=true
	for hi in game._last_economy_orders:
		var order: Dictionary=game._last_economy_orders[hi]
		npc_orders.append({"house":hi,"order":order.duplicate(true)})
	months.append({"index":game.calendar_index(),"gold":int(game.house().gold),"source_stock_u":int(game.province(source).production.materials_u),"destination_stock_u":int(game.province(destination).production.materials_u),"road_complete":road_complete(),"npc_orders":game._last_economy_orders.size()})

func prove_frontier() -> void:
	var current: Dictionary=game.snapshot()
	var alternative = Game.new(Data,0)
	check(alternative.restore(JSON.parse_string(JSON.stringify(current))),"Kontrollvergleich klont den tatsächlich finanzierten Endstand")
	alternative.province(destination).logistics_sites.depot=0 # Ausschließlich Kontrollwelt; keine Änderung der regulären Partie.
	var baseline: Dictionary=alternative.supply_report()
	var supplied: Dictionary=game.supply_report()
	var before: Dictionary=alternative.siege_preview(target)
	var after: Dictionary=game.siege_preview(target)
	var delivered := 0
	for flow in supplied.frontier_deliveries:
		if str(flow.depot)==destination and str(flow.to)==target: delivered+=int(flow.amount)
	frontier={"baseline":baseline.regions.get(target,{}),"supplied":supplied.regions.get(target,{}),"depot_delivered":delivered,"siege_without":before,"siege_with":after,"army":game.army_for().duplicate(true)}
	if delivered<=0 or int(after.get("progress",0))<=int(before.get("progress",0)): return
	check(game.snapshot()==current,"Reiner Gegenvergleich verändert die tatsächliche Partie nicht")
	var old_progress: int=game.province(target).siege
	check(buy("Tatsächliche Belagerung",func():return game.advance_siege(target)),"Vorhandener Belagerungsbefehl nutzt das echte versorgte Feldheer")
	depot_proved=int(game.province(target).siege)>old_progress

func settle_event() -> void:
	if game.pending_event==null: return
	var before: int=game.house().gold
	if game.event_decline_reason().is_empty(): game.decline_event()
	else:
		for index in game.pending_event.get("options",[]).size():
			if game.event_option_reason(index).is_empty(): game.apply_event(index); break
	event_delta+=int(game.house().gold)-before

func buy(label: String, action: Callable) -> bool:
	var before: int=game.house().gold
	var result: Dictionary=action.call()
	if not bool(result.get("ok",false)): return false
	var paid: int=before-int(game.house().gold)
	check(paid>=0,"Spielerabsicht erzeugt kein Debugguthaben: "+label)
	spending+=paid
	actions.append({"month":game.calendar_index(),"action":label,"paid_gold":paid,"gold_after":int(game.house().gold)})
	return true

func find_road() -> Dictionary:
	for road in game.roads:
		if source in [str(road.from),str(road.to)] and destination in [str(road.from),str(road.to)]: return road
	return {}

func road_complete() -> bool:
	return str(find_road().get("state",""))=="complete"

func write_proof() -> void:
	var directory := OS.get_environment("BQ_PRODUCTION_CAMPAIGN_PROOF")
	if directory.is_empty(): directory=ProjectSettings.globalize_path("user://production-campaign")
	DirAccess.make_dir_recursive_absolute(directory)
	var result := {"passed":failures==0,"checks":checks,"failures":failures,"seed":20261118,"start_gold":start_gold,"spending":spending,"world_delta":world_delta,"event_delta":event_delta,"final_gold":int(game.house().gold),"month":game.calendar_index(),"actions":actions,"months":months,"flows":flows,"npc_orders":npc_orders,"frontier":frontier,"concurrent":concurrent,"reloaded":reloaded,"workshop_export":workshop_export,"depot_proved":depot_proved,"controlled_comparison":"Only a separate cloned world removes the already-paid depot; normal game state is unchanged."}
	var file := FileAccess.open(directory.path_join("campaign-result.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t",true)); file.close()
	file=FileAccess.open(directory.path_join("campaign-save.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(game.snapshot(),"\t",true)); file.close()

func check(ok: bool, message: String) -> bool:
	checks+=1
	if not ok:
		failures+=1
		print("PRODUCTIONCAMPAIGNTEST FAIL: "+message)
	return ok
