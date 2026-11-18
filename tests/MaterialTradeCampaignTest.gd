extends Node
## Regular 108-region campaigns. No stock, money, owner, research or force gifts.
## Instrumentation observes actual super phases; Game owns every mutation.
const Game = preload("res://scripts/Game.gd")
const Data = preload("res://scripts/GameRegionData.gd")
const Save = preload("res://scripts/SaveGame.gd")
const LIMIT_MONTHS := 60
const MINIMUM_MONTHS := 24
const SEEDS := [20261118,20261119]
var checks := 0
var failures := 0
var cases: Array=[]
var proof_dir := ""

class ObservedGame extends Game:
	var trade_phases: Array=[]
	var finished_projects: Array=[]
	func _tick_material_trade() -> void:
		var stocks: Dictionary={}
		var gold: Dictionary={}
		for p in provinces: stocks[str(p.id)]=int(p.production.materials_u)
		for hi in houses.size(): gold[str(hi)]=int(houses[hi].gold)
		super._tick_material_trade()
		var material_delta:=0
		var gold_delta:=0
		var matches:=true
		var bounded:=true
		for p in provinces:
			var delta:=int(p.production.materials_u)-int(stocks[str(p.id)])
			material_delta+=delta
			matches=matches and delta==int(_last_material_trade.get("stock_deltas",{}).get(str(p.id),0))
			bounded=bounded and int(p.production.materials_u)>=0 and int(p.production.materials_u)<=ProductionScript.stock_capacity_u(p)
		for hi in houses.size():
			var delta:=int(houses[hi].gold)-int(gold[str(hi)])
			gold_delta+=delta
			matches=matches and delta==int(_last_material_trade.get("gold_deltas",{}).get(str(hi),0))
			bounded=bounded and int(houses[hi].gold)>=0
		trade_phases.append({"month":calendar_index(),"material_delta":material_delta,"gold_delta":gold_delta,"matches_plan":matches,"bounded":bounded,"before_stocks":stocks,"before_gold":gold,"actual_plan":_last_material_trade.duplicate(true)})
	func _tick_regional_economy(previous_roads: Array) -> void:
		var projects: Dictionary={}
		for p in provinces:
			if not p.regional_project.is_empty(): projects[str(p.id)]=p.regional_project.duplicate(true)
		super._tick_regional_economy(previous_roads)
		for id in projects:
			var p: Dictionary=province(str(id))
			var old: Dictionary=projects[id]
			if not p.regional_project.is_empty(): continue
			var level: int=int(p.buildings.get(str(old.kind),0)) if BUILDING_KEYS.has(str(old.kind)) else (int(p.dev) if str(old.kind)=="develop" else int(p.logistics_sites.depot))
			if level>=int(old.target_level): finished_projects.append({"month":calendar_index(),"province":str(id),"project":old.duplicate(true)})

func _ready() -> void:
	proof_dir=OS.get_environment("BQ_MATERIAL_TRADE_CAMPAIGN_PROOF")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--proof-dir="): proof_dir=argument.trim_prefix("--proof-dir=")
	if proof_dir.is_empty(): proof_dir="user://material-trade-campaign"
	DirAccess.make_dir_recursive_absolute(proof_dir)
	for case_seed in SEEDS: run_case(int(case_seed),0)
	var report: Dictionary={"passed":failures==0,"checks":checks,"failures":failures,"cases":cases,"normal_budget":true,"resource_or_owner_injection":false,"counterfactual":"Only a snapshot clone before the human offer. Each paired real month begins with the same deterministic global RNG seed; both worlds use normal Game methods/events/NPCs."}
	var file:=FileAccess.open(proof_dir.path_join("campaign-result.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t",true)); file.close()
	print("MATERIALTRADECAMPAIGNTEST %s: %d Prüfungen, %d Fehler" % ["OK" if failures==0 else "FAIL",checks,failures])
	get_tree().quit(0 if failures==0 else 1)

func choose_source(game, human: int) -> String:
	var best:=""
	var score:=-INF
	for p in game.provinces:
		if int(p.owner)!=human: continue
		var borders:=0
		for neighbor in game.neighbours(str(p.id)):
			if int(game.province(str(neighbor)).owner)!=human: borders+=1
		if borders==0: continue
		# Capital is scarce: prefer several foreign customers, then a cheaper
		# specialization. Largest weight is not the best small exporter.
		var value: float=100.0*borders-float(game.ProvinceEconomyScript.change_cost(p))
		if value>score or (is_equal_approx(value,score) and str(p.id)<best): score=value; best=str(p.id)
	return best

func run_case(case_seed: int, human: int) -> void:
	seed(case_seed)
	var game=ObservedGame.new(Data,human)
	var control: ObservedGame=null
	var source:=choose_source(game,human)
	var result: Dictionary={"seed":case_seed,"human":human,"source":source,"actions":[],"events":[],"deliveries":[],"npc_deliveries":[],"monthly":[],"blocker_histogram":{},"counterfactual":{},"start_gold":int(game.house().gold)}
	cases.append(result)
	check(game.provinces.size()==108 and game.houses.size()==9 and game.house().gold==140,"Seed%d uses unmodified108/9/140Gold start" % case_seed)
	check(game.calendar_index()==0 and game.provinces.all(func(p):return p.regional_project.is_empty() and int(p.production.materials_u)==0),"Every source/project begins at its actual empty normal-game state")
	if not check(not source.is_empty(),"Seed%d has an affordable owned exporter on a genuine foreign land border" % case_seed): return
	result["source_terrain"]=str(game.province(source).terrain)
	result["source_weight"]=float(game.province(source).economic_share)
	check(game.house().research.known.is_empty() and game.house().armies.is_empty(),"No research or army is inserted for the trade route")
	var before: int=game.house().gold
	var focus: Dictionary=game.set_province_focus(source,"workshops")
	var spending:=before-int(game.house().gold)
	check(bool(focus.ok) and spending>0,"Actual workshop focus is paid from the original treasury")
	if not focus.ok: return
	result.actions.append({"month":0,"action":"workshops","paid_gold":spending})
	var world_delta:=0
	var event_delta:=0
	var trade_net:=0
	var target:=""
	var project_id:=-1
	var contract_id:=-1
	var offer_month:=-1
	var purchased_u:=0
	var target_used:=0
	var control_used:=0
	var completed_month:=-1
	var control_completed_month:=-1
	var allocation_advantage:=false
	var offered:=false
	for step in LIMIT_MONTHS:
		if game.game_over: break
		if not offered and int(game.province(source).owner)==human:
			for option in game.material_trade_options(source,human):
				if str(option.kind)!="offer" or str(option.from)!=source: continue
				if not bool(option.preview.ok):
					var reason:=str(option.preview.reason)
					result.blocker_histogram[reason]=int(result.blocker_histogram.get(reason,0))+1
					continue
				var buyer: int=int(option.preview.buyer)
				var destination: Dictionary=game.province(str(option.to))
				if game.is_human_house(buyer) or destination.regional_project.is_empty(): continue
				var snapshot: Dictionary=game.snapshot()
				control=ObservedGame.new(Data,human)
				if not check(control.restore(JSON.parse_string(JSON.stringify(snapshot))),"Counterworld clones the actual fully paid world before the trade offer"): return
				check(Save.state_equal(control.snapshot(),snapshot),"Counterworld starts byte-value equivalent, without resetting NPC projects or stocks")
				target=str(destination.id); project_id=int(destination.regional_project.id)
				var accepted: Dictionary=game.offer_material_trade(source,target,human)
				if not check(bool(accepted.ok),"Actual visible sale quote closes a real NPC-approved contract"): return
				offered=true; offer_month=game.calendar_index(); contract_id=int(game.trade_serial)
				check(game.house().gold==snapshot.houses[human].gold and game.province(source).production==find(snapshot.provinces,source).production,"Contract creation transfers no money or material in advance")
				result.actions.append({"month":offer_month,"action":"offer_material_trade","contract":contract_id,"from":source,"to":target,"quote":option.preview.duplicate(true),"npc_project":destination.regional_project.duplicate(true)})
				break
		var month_seed:=case_seed+(step+1)*7919
		var old_gold: int=game.house().gold
		seed(month_seed)
		game.advance_month()
		var phase: Dictionary=game.trade_phases[-1]
		check(phase.material_delta==0 and phase.gold_delta==0,"Real trade phase conserves world goods/money at seed%d month%d" % [case_seed,game.calendar_index()])
		check(bool(phase.matches_plan) and bool(phase.bounded),"Actual treasury/stock writes match the atomic plan and remain bounded")
		var own_trade_delta:=0
		for delivery in phase.actual_plan.get("deliveries",[]):
			if int(delivery.seller)==human: own_trade_delta+=int(delivery.gold)
			if int(delivery.buyer)==human: own_trade_delta-=int(delivery.gold)
			if not game.is_human_house(int(delivery.seller)) and not game.is_human_house(int(delivery.buyer)):
				result.npc_deliveries.append({"month":game.calendar_index(),"delivery":delivery.duplicate(true)})
			if int(delivery.trade_id)==contract_id:
				purchased_u+=int(delivery.amount_u)
				result.deliveries.append({"month":game.calendar_index(),"delivery":delivery.duplicate(true),"source_before":phase.before_stocks[source],"target_before":phase.before_stocks[target],"seller_gold_before":phase.before_gold[str(human)],"buyer_gold_before":phase.before_gold[str(delivery.buyer)]})
				check(game.calendar_index()>offer_month and int(delivery.seller)==human and str(delivery.from)==source and str(delivery.to)==target,"Delivery occurs after acceptance using the real seller, buyer and regions")
		trade_net+=own_trade_delta
		world_delta+=int(game.house().gold)-old_gold-own_trade_delta
		var event_id:=str(game.pending_event.get("id","")) if game.pending_event!=null else ""
		var delta:=settle_event(game)
		event_delta+=delta
		if not event_id.is_empty(): result.events.append({"month":game.calendar_index(),"event":event_id,"gold_delta":delta,"policy":"Decline when legal; otherwise first actually available option."})
		if control!=null:
			seed(month_seed)
			control.advance_month()
			settle_event(control)
			var counter_phase: Dictionary=control.trade_phases[-1]
			check(counter_phase.material_delta==0 and counter_phase.gold_delta==0 and counter_phase.matches_plan and counter_phase.bounded,"Uncontracted counterworld also preserves every trade-phase account")
			check(not control.material_trades.any(func(t):return human in [int(t.seller),int(t.buyer)]),"NPC automation never inserts a human contract into the uncontracted counterworld")
			if not target.is_empty():
				var used: int=int(game._last_production.get("regions",{}).get(target,{}).get("used_u",0))
				var baseline_used: int=int(control._last_production.get("regions",{}).get(target,{}).get("used_u",0))
				target_used+=used; control_used+=baseline_used
				if purchased_u>0 and used>baseline_used: allocation_advantage=true
				for finished in game.finished_projects:
					if int(finished.project.id)==project_id and completed_month<0: completed_month=int(finished.month)
				for finished in control.finished_projects:
					if int(finished.project.id)==project_id and control_completed_month<0: control_completed_month=int(finished.month)
		check(int(game.house().gold)==int(result.start_gold)-spending+world_delta+event_delta+trade_net,"Player gold closes across spending, ordinary world changes, events and actual trade")
		result.monthly.append({"month":game.calendar_index(),"gold":int(game.house().gold),"source_owner":int(game.province(source).owner),"source_materials_u":int(game.province(source).production.materials_u),"trade_contracts":game.material_trades.size(),"human_purchased_u":purchased_u,"target_used_u":target_used,"control_used_u":control_used,"trade_phase":{"material_delta":phase.material_delta,"gold_delta":phase.gold_delta,"writes_match_plan":phase.matches_plan,"bounded":phase.bounded,"deliveries":phase.actual_plan.get("deliveries",[]).duplicate(true),"statuses":phase.actual_plan.get("statuses",{}).duplicate(true)}})
		if game.calendar_index()>=MINIMUM_MONTHS and completed_month>=0 and control_completed_month>=0 and purchased_u>0 and not result.npc_deliveries.is_empty() and (allocation_advantage or completed_month<control_completed_month): break
	result["offered"]=offered; result["offer_month"]=offer_month; result["purchased_u"]=purchased_u
	result["spending"]=spending; result["world_delta"]=world_delta; result["event_delta"]=event_delta; result["trade_net"]=trade_net; result["final_gold"]=int(game.house().gold)
	result["final_month"]=game.calendar_index(); result["completed_month"]=completed_month
	result.counterfactual={"target":target,"project":project_id,"actual_used_u":target_used,"without_contract_used_u":control_used,"without_contract_completion":control_completed_month,"actual_allocation_advantage":allocation_advantage}
	check(offered and purchased_u>0 and trade_net>0,"Seed%d earns actual money by selling self-produced surplus to a real NPC project" % case_seed)
	check(completed_month>=0 and target_used>=purchased_u,"Bought material participates in later genuine project work and the original buyer project completes")
	check(allocation_advantage or (completed_month>=0 and (control_completed_month<0 or completed_month<control_completed_month)),"The uncontracted same-seed counterworld proves a real timing/material-allocation difference")
	check(not result.npc_deliveries.is_empty(),"NPC houses also exchange real goods and gold without using human stocks or treasury")
	check(Save.validate(game.snapshot()).is_empty(),"Actual normally financed campaign remains valid schema18")
	if control!=null: check(Save.validate(control.snapshot()).is_empty(),"The independently evolved uncontracted counterworld remains valid schema18")
	var file:=FileAccess.open(proof_dir.path_join("campaign-%d-save.json" % case_seed),FileAccess.WRITE)
	file.store_string(JSON.stringify(game.snapshot(),"\t",true)); file.close()
	print("MATERIALTRADECAMPAIGNTEST case ",JSON.stringify(result))

func settle_event(game) -> int:
	if game.pending_event==null: return 0
	var before: int=game.house().gold
	var resolved:=false
	if game.event_decline_reason().is_empty(): resolved=bool(game.decline_event().ok)
	else:
		for index in game.pending_event.get("options",[]).size():
			if game.event_option_reason(index).is_empty(): resolved=bool(game.apply_event(index).ok); break
	check(resolved,"An actual available event option resolves the event without debug dismissal")
	return int(game.house().gold)-before

func find(provinces: Array, id: String) -> Dictionary:
	for p in provinces:
		if str(p.id)==id: return p
	return {}

func check(ok: bool, message: String) -> bool:
	checks+=1
	if not ok:
		failures+=1
		print("MATERIALTRADECAMPAIGNTEST FAIL: "+message)
	return ok
