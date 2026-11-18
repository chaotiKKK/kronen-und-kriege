extends Node
## Ordinary untouched worlds. Only time and legal human event choices are acted on;
## every workshop, research, army, road and regional project is the actual NPC's.
const Game = preload("res://scripts/Game.gd")
const Data = preload("res://scripts/GameRegionData.gd")
const Save = preload("res://scripts/SaveGame.gd")
const Production = preload("res://scripts/RegionalProduction.gd")
const Planner = preload("res://scripts/EconomyPlanner.gd")
const Naval = preload("res://scripts/NavalCampaign.gd")
const MAX_MONTHS := 120
var checks := 0
var failures := 0
var probes: Array = []
var output := ""

func _ready() -> void:
	output=OS.get_environment("BQ_PRODUCTION_NPC_PROOF")
	if output.is_empty(): output=ProjectSettings.globalize_path("user://production-npc")
	DirAccess.make_dir_recursive_absolute(output)
	var probe_files: Array=[]
	for human in [0,2]:
		var result := run_probe(20261118,human)
		probes.append(result)
		write_json("probe-human%d.json" % human,result)
		probe_files.append("probe-human%d.json" % human)
		if int(result.completed_chains)>0 and not result.frontier_effects.is_empty(): break
	var chains := 0
	var orders := 0
	var frontier := 0
	var frontier_effects := 0
	for result in probes:
		chains+=int(result.completed_chains)
		orders+=result.orders.size()
		frontier+=result.frontier_deliveries.size()
		frontier_effects+=result.frontier_effects.size()
	check(orders>0,"Actual NPCs make paid economic decisions in ordinary campaigns")
	check(chains>0,"An actual NPC workshop, paid road, export and completed destination form one financed chain")
	check(frontier>0,"An actual normally financed NPC depot supplies a real foreign-positioned army and reduces its measured shortfall")
	write_json("npc-campaign-result.json",{"passed":failures==0,"checks":checks,"failures":failures,"maximum_months_per_probe":MAX_MONTHS,"probe_count":probes.size(),"completed_chains":chains,"npc_orders":orders,"frontier_delivery_records":frontier,"natural_frontier_effect_records":frontier_effects,"probe_files":probe_files,"scope":"No resource/research/unit/ownership/road injection; normal constructors, monthly NPCs and legal human event responses only."})
	print("PRODUCTIONNPCCAMPAIGNTEST %s: %d Prüfungen, %d Fehler, %d bezahlteNPC-Aufträge, %d vollständigeKetten, %d Frontlieferungsbelege" % ["OK" if failures==0 else "FAIL",checks,failures,orders,chains,frontier])
	get_tree().quit(0 if failures==0 else 1)

func run_probe(seed_value: int, human: int) -> Dictionary:
	seed(seed_value)
	var game = Game.new(Data,human)
	var proof := {"seed":seed_value,"human_house":human,"limit":MAX_MONTHS,"month":0,"stop_reason":"month_limit","orders":[],"workshops":{},"road_starts":{},"road_completions":[],"project_completions":[],"flows":[],"chains":{},"completed_chains":0,"frontier_deliveries":[],"frontier_effects":[],"last_military":{},"foreign_deficit_months":{},"events":[],"months":[],"initial_gold":[],"final_houses":[]}
	check(game.provinces.size()==108 and game.houses.size()==9 and game.roads.is_empty(),"Ordinary108region/ninehouse world starts without constructed roads for human"+str(human))
	var empty_start := true
	for p in game.provinces:
		empty_start=empty_start and int(p.production.materials_u)==0 and p.regional_project.is_empty() and int(p.logistics_sites.depot)==0
	check(empty_start and int(game.project_serial)==0,"Ordinary world starts without gifted materials, projects or depots")
	for house in game.houses: proof.initial_gold.append(int(house.gold))
	for step in MAX_MONTHS:
		if game.game_over:
			proof.stop_reason="human_defeated"
			break
		var before := province_state(game)
		var old_month: int=game.calendar_index()
		game.advance_month()
		if int(game.calendar_index())!=old_month+1:
			proof.stop_reason="time_did_not_advance"
			break
		settle_event(game,proof)
		observe(game,before,proof)
		proof.month=game.calendar_index()
		if game.calendar_index()%12==0:
			var state: Dictionary=game.snapshot()
			check(not state.is_empty() and Save.validate(state).is_empty(),"Actual NPC year remains a nonempty valid save at month"+str(game.calendar_index()))
			write_json("progress-human%d.json" % human,{"month":game.calendar_index(),"orders":proof.orders.size(),"workshops":proof.workshops.size(),"roads_started":proof.road_starts.size(),"roads_complete":proof.road_completions.size(),"flows":proof.flows.size(),"completed_chains":proof.completed_chains,"frontier_deliveries":proof.frontier_deliveries.size()})
			print("NPC_PROBE_PROGRESS human=",human," month=",game.calendar_index()," orders=",proof.orders.size()," workshops=",proof.workshops.size()," roads=",proof.road_completions.size()," flows=",proof.flows.size()," chains=",proof.completed_chains)
		if int(proof.completed_chains)>0 and not proof.frontier_effects.is_empty():
			proof.stop_reason="chain_and_frontier_observed"
			break
	for hi in game.houses.size():
		if hi!=human: proof.final_houses.append(house_diagnostic(game,hi))
	write_json("final-save-human%d.json" % human,game.snapshot())
	check(int(game.calendar_index())<=MAX_MONTHS,"Probe never exceeds120ordinary months")
	print("NPC_PROBE_RESULT human=",human," month=",game.calendar_index()," reason=",proof.stop_reason," orders=",proof.orders.size()," workshops=",proof.workshops.size()," roadstarts=",proof.road_starts.size()," exports=",proof.flows.size()," chains=",proof.completed_chains)
	return proof

func province_state(game) -> Dictionary:
	var result := {}
	for p in game.provinces:
		result[str(p.id)]={"owner":int(p.owner),"dev":int(p.dev),"focus":str(p.economic_focus),"buildings":p.buildings.duplicate(true),"depot":int(p.logistics_sites.depot),"project":p.regional_project.duplicate(true)}
	return result

func observe(game, before: Dictionary, proof: Dictionary) -> void:
	var month: int=game.calendar_index()
	var ledger: Dictionary=game._last_production.get("regions",{})
	var export_total := 0
	var import_total := 0
	var conserved := true
	for id in ledger:
		var row: Dictionary=ledger[id]
		conserved=conserved and int(row.before_u)+int(row.produced_u)+int(row.import_u)-int(row.used_u)-int(row.export_u)-int(row.wasted_u)==int(row.after_u)
		conserved=conserved and int(row.work_u)+int(row.production_work_u)+int(row.legacy_work_u)<=Production.labor_capacity_u(game.province(str(id)))
		export_total+=int(row.export_u)
		import_total+=int(row.import_u)
	check(conserved and export_total==import_total,"Actual all-house monthly material and shared-labor accounts conserve at month"+str(month))
	for hi in game._last_economy_orders:
		var row: Dictionary=game._last_economy_orders[hi].duplicate(true)
		row["house"]=int(hi)
		row["paid_gold"]=int(row.gold_before)-int(row.gold_after)
		check(int(hi)!=int(proof.human_house) and int(row.paid_gold)>0 and int(row.gold_after)>=0,"Actual accepted NPC order pays its real treasury once")
		proof.orders.append(row)
		var intent: Dictionary=row.intent
		if str(intent.id)=="province_focus" and str(intent.get("focus",""))=="workshops":
			proof.workshops[house_region(int(hi),str(intent.province))]=row.duplicate(true)
		if str(intent.id)=="road":
			var key:=edge(str(intent.province),str(intent.to))
			for road in game.roads:
				if edge(str(road.from),str(road.to))==key and not road.get("construction",{}).is_empty():
					row["project_id"]=int(road.construction.id)
					row["from"]=str(road.from)
					row["to"]=str(road.to)
					proof.road_starts[key]=row.duplicate(true)
	for road in game.roads:
		var key:=edge(str(road.from),str(road.to))
		if str(road.state)=="complete" and proof.road_starts.has(key) and not proof.road_starts[key].has("completed_month"):
			proof.road_starts[key]["completed_month"]=month
			proof.road_completions.append(proof.road_starts[key].duplicate(true))
	for flow in game._last_production.get("flows",[]):
		var from:=str(flow.from)
		var to:=str(flow.to)
		var hi:=int(ledger.get(from,{}).get("owner",-1))
		if hi<0 or hi==int(proof.human_house): continue
		var entry: Dictionary=flow.duplicate(true)
		entry["house"]=hi
		entry["month"]=month
		proof.flows.append(entry)
		var source:=house_region(hi,from)
		if not proof.workshops.has(source) or str(before[from].focus)!="workshops": continue
		var target: Dictionary=before[to].project
		var current: Dictionary=game.province(to).regional_project
		if target.is_empty() or current.is_empty() or int(target.id)!=int(current.id) or int(target.builder)!=hi: continue
		var paid_path: Array=[]
		var path_ok := int(proof.workshops[source].month_index)<month
		for index in flow.path.size()-1:
			var key:=edge(str(flow.path[index]),str(flow.path[index+1]))
			if not proof.road_starts.has(key): path_ok=false; break
			var receipt: Dictionary=proof.road_starts[key]
			if int(receipt.house)!=hi or not receipt.has("completed_month") or int(receipt.completed_month)>=month or int(receipt.month_index)<int(proof.workshops[source].month_index): path_ok=false; break
			paid_path.append(receipt.duplicate(true))
		if not path_ok or paid_path.is_empty(): continue
		var token:=house_region(hi,from)+"|"+to+"|"+str(target.id)
		if not proof.chains.has(token):
			proof.chains[token]={"house":hi,"source":from,"target":to,"target_project":target.duplicate(true),"workshop":proof.workshops[source].duplicate(true),"roads":paid_path,"first_import_month":month,"imported_u":0,"complete":false}
		proof.chains[token].imported_u=int(proof.chains[token].imported_u)+int(flow.amount_u)
	for p in game.provinces:
		var old: Dictionary=before[str(p.id)]
		var project: Dictionary=old.project
		if project.is_empty() or int(project.builder)==int(proof.human_house) or int(p.owner)!=int(project.builder): continue
		if not p.regional_project.is_empty() and int(p.regional_project.id)==int(project.id): continue
		var kind:=str(project.kind)
		var complete: bool=int(p.dev)>int(old.dev) if kind=="develop" else (int(p.logistics_sites.depot)==1 if kind=="depot" else int(p.buildings.get(kind,0))>=int(project.target_level))
		if not complete: continue
		var completion: Dictionary=project.duplicate(true)
		completion["month"]=month
		completion["province"]=str(p.id)
		proof.project_completions.append(completion)
		for token in proof.chains:
			var chain: Dictionary=proof.chains[token]
			if not bool(chain.complete) and int(chain.target_project.id)==int(project.id) and month>int(chain.first_import_month):
				chain.complete=true
				chain["completed_month"]=month
				proof.completed_chains=int(proof.completed_chains)+1
	var military_now := {}
	for hi in game.houses.size():
		if hi==int(proof.human_house): continue
		var supply: Dictionary=game.supply_report(hi)
		for army in game.houses[hi].get("armies",[]):
			var region:=str(army.province)
			if int(game.province(region).get("owner",-1))==hi: continue
			var preview: Dictionary=game.siege_preview(region,hi)
			if str(preview.get("origin",""))!=region: continue
			var token:=str(hi)+"|"+str(army.id)+"|"+region
			@warning_ignore("integer_division")
			var martial_band: int=int(game.houses[hi].ruler.martial)/4
			military_now[token]={"house":hi,"month":month,"martial_band":martial_band,"supply":supply.regions.get(region,{}).duplicate(true),"siege":preview}
		for delivery in supply.get("frontier_deliveries",[]):
			var entry: Dictionary=delivery.duplicate(true)
			entry["house"]=hi
			entry["month"]=month
			entry["supply"]=supply.regions.get(str(delivery.to),{}).duplicate(true)
			entry["siege_preview"]=game.siege_preview(str(delivery.to),hi)
			var real_supply: Dictionary=entry.supply
			check(int(delivery.amount)>0 and int(real_supply.get("import",0))>=int(delivery.amount) and int(real_supply.get("shortfall",0))==maxi(0,int(real_supply.get("demand",0))-int(real_supply.get("local_capacity",0))-int(real_supply.get("import",0))),"Real NPC depot imports reduce the existing actual foreign-army shortfall")
			proof.frontier_deliveries.append(entry)
			var token:=str(hi)+"|"+str(entry.siege_preview.get("army_id",-1))+"|"+str(delivery.to)
			if military_now.has(token) and proof.last_military.has(token):
				var previous: Dictionary=proof.last_military[token]
				var current: Dictionary=military_now[token]
				var stable: bool=int(previous.martial_band)==int(current.martial_band) and int(previous.supply.get("demand",0))==int(current.supply.get("demand",0)) and int(previous.supply.get("local_capacity",0))==int(current.supply.get("local_capacity",0))
				for field in ["strength","effective_strength","fort_bonus","wall_level","blockade_factor","doctrine_bonus","research_bonus","defender_strength"]:
					stable=stable and previous.siege.get(field)==current.siege.get(field)
				if stable and int(current.supply.get("shortfall",0))<int(previous.supply.get("shortfall",0)) and int(current.siege.get("progress",0))>int(previous.siege.get("progress",0)):
					proof.frontier_effects.append({"delivery":entry.duplicate(true),"before":previous.duplicate(true),"after":current.duplicate(true),"comparison":"Two consecutive actual ordinary world months; unchanged strength, martial band, local capacity and fort/combat modifiers. No counterfactual clone or override."})
		for army in game.houses[hi].get("armies",[]):
			var region:=str(army.province)
			if int(game.province(region).get("owner",-1))!=hi and int(supply.regions.get(region,{}).get("shortfall",0))>0:
				proof.foreign_deficit_months[str(hi)]=int(proof.foreign_deficit_months.get(str(hi),0))+1
	proof.last_military=military_now
	var gold: Array=[]
	for house in game.houses: gold.append(int(house.gold))
	proof.months.append({"month":month,"gold":gold,"economic_orders":game._last_economy_orders.size(),"imports_u":import_total,"projects":game.construction_sites().size()})

func house_diagnostic(game, hi: int) -> Dictionary:
	var owned: Array=[]
	var workshops: Array=[]
	var projects: Array=[]
	var depots: Array=[]
	for p in game.provinces:
		if int(p.owner)!=hi: continue
		owned.append(str(p.id))
		if str(p.economic_focus)=="workshops": workshops.append(str(p.id))
		if int(p.logistics_sites.depot)>0: depots.append(str(p.id))
		if not p.regional_project.is_empty(): projects.append({"province":str(p.id),"project":p.regional_project.duplicate(true),"stock":p.production.duplicate(true)})
	var report: Dictionary=game.regional_production_report(hi)
	var blocked := {}
	for id in report.regions:
		if not str(report.regions[id].blocked_reason).is_empty(): blocked[id]=report.regions[id].blocked_reason
	var reserve:=maxi(int(Planner.RULES.minimum_military_reserve),Naval.military_reserve(game,hi))
	return {"house":hi,"name":str(game.houses[hi].name),"gold":int(game.houses[hi].gold),"protected_reserve":reserve,"spendable":int(game.houses[hi].gold)-reserve,"research":game.houses[hi].research.duplicate(true),"owned":owned,"workshops":workshops,"depots":depots,"projects":projects,"roads":report.roads,"blocked":blocked,"naval_preparation":Naval.preparation(game,hi),"planner_next_order":Planner.next_order(game,hi),"armies":game.houses[hi].armies.duplicate(true)}

func settle_event(game, proof: Dictionary) -> void:
	if game.pending_event==null: return
	var event_id:=str(game.pending_event.id)
	var before: int=game.house().gold
	if game.event_decline_reason().is_empty():
		game.decline_event()
		proof.events.append({"month":game.calendar_index(),"event":event_id,"choice":"legal_decline","gold_delta":int(game.house().gold)-before})
		return
	for option in game.pending_event.get("options",[]).size():
		if game.event_option_reason(option).is_empty():
			var result: Dictionary=game.apply_event(option)
			proof.events.append({"month":game.calendar_index(),"event":event_id,"choice":option,"accepted":bool(result.ok),"gold_delta":int(game.house().gold)-before})
			return

func edge(a: String, b: String) -> String:
	return a+"|"+b if a<b else b+"|"+a

func house_region(house: int, province: String) -> String:
	return str(house)+"|"+province

func write_json(name: String, value: Dictionary) -> void:
	var file:=FileAccess.open(output.path_join(name),FileAccess.WRITE)
	file.store_string(JSON.stringify(value,"\t",true))
	file.close()

func check(ok: bool, message: String) -> bool:
	checks+=1
	if not ok:
		failures+=1
		print("PRODUCTIONNPCCAMPAIGNTEST FAIL: "+message)
	return ok
