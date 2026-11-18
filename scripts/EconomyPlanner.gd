extends RefCounted
## Read-only bounded NPC investment goals. Game executes at most one returned intent.
const Naval = preload("res://scripts/NavalCampaign.gd")
const Production = preload("res://scripts/RegionalProduction.gd")
const Infrastructure = preload("res://scripts/Infrastructure.gd")
const Economy = preload("res://scripts/ProvinceEconomy.gd")
const RULES := {"algorithm_version":2,"minimum_military_reserve":80,
	"max_regional_projects":3,"max_pending_roads":1,"max_workshop_sources":1,
	"material_shortfall_horizon_months":2,"max_project_previews":6,
	"minimum_annual_civilian_gain":0.25,"one_paid_intent_per_month":true,
	"connected_front_source_score":10.0,
	"skip_humans_and_landless":true,"naval_preparation_precedes_civilian_spending":true,
	"no_mutation_or_free_resources":true,"logistics_requires_real_foreign_army_deficit":true,
	"research_month_guard_uses_validated_original_duration":true,
	"stable_goal_order":"front-supply,material-chain,threat-or-civil-investment",
	"workshop_terrain":["forest","hills"],"research_path":["surveying","road_building","logistics"]}

static func next_order(game, house_index: int) -> Dictionary:
	var hi := house_index
	if hi<0 or hi>=game.houses.size() or game.is_human_house(hi): return {}
	var house: Dictionary=game.houses[hi]
	if bool(house.get("defeated",false)): return {}
	var owned: Array=[]
	var catalog := {}
	for p in game.provinces:
		catalog[str(p.id)]=p
		if int(p.owner)==hi: owned.append(p)
	if owned.is_empty(): return {}
	owned.sort_custom(func(a: Dictionary,b: Dictionary)->bool: return str(a.id)<str(b.id))
	if _already_bought(game,hi,owned): return {}
	# Even an affordable sea package belongs to the military owner, not this planner.
	if not Naval.preparation(game,hi).is_empty(): return {}
	var reserve := maxi(int(RULES.minimum_military_reserve),Naval.military_reserve(game,hi))
	var spendable := int(house.get("gold",0))-reserve
	if spendable<=0: return {}
	var report: Dictionary=game.regional_production_report(hi)
	var blocked := {}
	var projects := 0
	for p in owned:
		if not str(report.regions.get(str(p.id),{}).get("blocked_reason","")).is_empty(): blocked[str(p.id)]=true
		if not p.get("regional_project",{}).is_empty(): projects+=1
	var allow_project := projects<int(RULES.max_regional_projects)
	var front := _front_goal(game,hi,owned,catalog,blocked)
	if not front.is_empty(): return _front_order(game,hi,owned,catalog,blocked,front,spendable,allow_project)
	var material := _material_goal(owned,report,blocked)
	if not material.is_empty():
		var order := _material_order(game,hi,owned,catalog,blocked,material,spendable)
		if not order.is_empty(): return order
	if not allow_project: return {}
	return _civil_order(game,hi,owned,catalog,blocked,spendable)

static func _already_bought(game, hi: int, owned: Array) -> bool:
	var now: int=game.calendar_index()
	for p in owned:
		if int(p.get("focus_changed_month",-1))==now: return true
		var project: Dictionary=p.get("regional_project",{})
		if not project.is_empty() and int(project.get("started_month",-1))==now: return true
	for road in game.roads:
		var construction: Dictionary=road.get("construction",{})
		if int(road.get("builder",-1))==hi and not construction.is_empty() and int(construction.get("started_month",-1))==now: return true
	var research: Dictionary=game.houses[hi].get("research",{})
	var active:=str(research.get("active",""))
	return Infrastructure.INNOVATIONS.has(active) and int(research.get("months",0))==Infrastructure.research_duration(research)

static func _material_goal(owned: Array, report: Dictionary, blocked: Dictionary) -> Dictionary:
	var best := {}
	var best_score := -1.0
	for p in owned:
		var id:=str(p.id)
		if blocked.has(id): continue
		var region: Dictionary=report.regions.get(id,{})
		var remaining:=0
		var started:=2147483647
		for task in region.get("tasks",[]):
			remaining+=maxi(0,int(task.material_total_u)-int(task.material_spent_u))
			started=mini(started,int(task.get("started_month",0)))
		var gap:=remaining-int(region.get("materials_u",0))
		if gap<=int(region.get("production_per_month_u",0))*int(RULES.material_shortfall_horizon_months): continue
		var score:=float(gap)/maxf(1.0,float(Production.weight_u(p)))+1.0/(1.0+maxi(0,started))
		if score>best_score:
			best_score=score
			best={"province":id,"gap_u":gap}
	return best

static func _material_order(game, hi: int, owned: Array, catalog: Dictionary, blocked: Dictionary, goal: Dictionary, spendable: int) -> Dictionary:
	var target:=str(goal.province)
	var sources: Array=[]
	for p in owned:
		if str(p.get("economic_focus","balanced"))=="workshops" and not blocked.has(str(p.id)):
			var path:=_land_path(game,hi,str(p.id),target,catalog,blocked)
			if not path.is_empty(): sources.append({"province":str(p.id),"path":path})
	if not sources.is_empty():
		sources.sort_custom(func(a: Dictionary,b: Dictionary)->bool:
			return a.path.size()<b.path.size() if a.path.size()!=b.path.size() else str(a.province)<str(b.province))
		return _road_order(game,hi,sources[0].path,spendable)
	var source_count:=0
	for p in owned:
		if str(p.get("economic_focus","balanced"))=="workshops": source_count+=1
	if source_count>=int(RULES.max_workshop_sources): return {}
	var best: Dictionary={}
	var best_score:=-INF
	for p in owned:
		var id:=str(p.id)
		if blocked.has(id) or not RULES.workshop_terrain.has(str(p.get("terrain",""))): continue
		if str(p.get("economic_focus","balanced"))!="balanced": continue
		var path:=_land_path(game,hi,id,target,catalog,blocked)
		if path.is_empty() or not game.province_focus_reason(id,"workshops",hi).is_empty(): continue
		var price:=_focus_cost(game,id,"workshops",hi)
		if price>spendable: continue
		# Lost tax per added monthly material plus real focus price; completed paths help.
		var extra:=float(Production.weight_u(p))*1.5/Production.UNIT
		var lost:=float(game.region_income(p))*0.20
		var score:=100.0/(1.0+lost/maxf(0.000001,extra)+float(price)/12.0)-float(path.size())
		if _path_complete(game,path): score+=20.0
		if not p.get("regional_project",{}).is_empty(): score-=5.0
		if score>best_score:
			best_score=score
			best={"id":"province_focus","province":id,"focus":"workshops"}
	return best

static func _front_goal(game, hi: int, owned: Array, catalog: Dictionary, blocked: Dictionary) -> Dictionary:
	if game.houses[hi].get("armies",[]).is_empty(): return {}
	var supply: Dictionary=game.supply_report(hi)
	var best: Dictionary={}
	var best_score:=-INF
	for army in game.houses[hi].get("armies",[]):
		var target:=str(army.get("province",""))
		if not catalog.has(target) or int(catalog[target].owner)==hi or int(army.get("strength",0))<=0 or int(army.get("morale",0))<=0: continue
		var shortfall:=int(supply.get("regions",{}).get(target,{}).get("shortfall",0))
		if shortfall<=0: continue
		for p in owned:
			var id:=str(p.id)
			if blocked.has(id) or not game.neighbours(id).has(target): continue
			var capacity:=Production.mul_div_floor(Production.weight_u(p),300,Production.UNIT)
			if capacity<=0: continue
			var delivered:=0
			for flow in supply.get("frontier_deliveries",[]):
				if str(flow.get("depot",""))==id: delivered+=int(flow.get("amount",0))
			if int(p.get("logistics_sites",{}).get("depot",0))==1 and delivered>=capacity: continue
			var project: Dictionary=p.get("regional_project",{})
			if not project.is_empty() and str(project.get("kind",""))!="depot": continue
			var score:=float(mini(capacity-delivered,shortfall))/maxf(1.0,50.0*float(p.get("economic_share",1.0)))
			for source in owned:
				var source_id:=str(source.id)
				if blocked.has(source_id): continue
				var source_region: Dictionary=supply.get("regions",{}).get(source_id,{})
				if int(source_region.get("export_available",0))-int(source_region.get("export",0))<=0: continue
				var path:=_land_path(game,hi,source_id,id,catalog,blocked)
				if not path.is_empty() and _path_complete(game,path):
					score+=float(RULES.connected_front_source_score)
					break
			if int(p.get("logistics_sites",{}).get("depot",0))==1: score+=1000.0
			if score>best_score:
				best_score=score
				best={"province":id,"target":target,"supply":supply}
	return best

static func _front_order(game, hi: int, owned: Array, catalog: Dictionary, blocked: Dictionary, goal: Dictionary, spendable: int, allow_project: bool) -> Dictionary:
	var base:=str(goal.province)
	var supply: Dictionary=goal.supply
	var sources: Array=[]
	for p in owned:
		var id:=str(p.id)
		if blocked.has(id) or str(p.get("economic_focus","balanced"))!="agriculture": continue
		var region: Dictionary=supply.get("regions",{}).get(id,{})
		if int(region.get("export_available",0))-int(region.get("export",0))<=0: continue
		var path:=_land_path(game,hi,id,base,catalog,blocked)
		if not path.is_empty(): sources.append({"province":id,"path":path,"complete":_path_complete(game,path)})
	if sources.is_empty():
		var best: Dictionary={}
		var best_score:=-INF
		for p in owned:
			var id:=str(p.id)
			if blocked.has(id) or str(p.get("economic_focus","balanced"))=="workshops": continue
			if not game.province_focus_reason(id,"agriculture",hi).is_empty(): continue
			var path:=_land_path(game,hi,id,base,catalog,blocked)
			if path.is_empty(): continue
			var price:=_focus_cost(game,id,"agriculture",hi)
			if price>spendable: continue
			var preview: Dictionary=game.province_economy_preview(id,"agriculture",hi)
			var balanced: Dictionary=game.province_economy_preview(id,"balanced",hi)
			var gain:=int(preview.projected_supply)-int(balanced.projected_supply)
			if gain<=0: continue
			var score:=float(gain)/(1.0+float(price)+float(game.region_income(p))*0.15)-float(path.size())
			if score>best_score:
				best_score=score
				best={"id":"province_focus","province":id,"focus":"agriculture"}
		return best
	sources.sort_custom(func(a: Dictionary,b: Dictionary)->bool:
		if bool(a.complete)!=bool(b.complete): return bool(a.complete)
		return a.path.size()<b.path.size() if a.path.size()!=b.path.size() else str(a.province)<str(b.province))
	var chosen: Dictionary=sources[0]
	if not bool(chosen.complete): return _road_order(game,hi,chosen.path,spendable)
	if not game.houses[hi].research.known.has("logistics"):
		return _research_order(game,hi,"logistics",base,spendable)
	var p: Dictionary=catalog[base]
	if not allow_project or int(p.logistics_sites.depot)==1 or not p.regional_project.is_empty(): return {}
	var quote: Dictionary=game.regional_project_preview(base,"depot",hi)
	return {"id":"build","province":base,"key":"depot"} if bool(quote.ok) and int(quote.gold)<=spendable else {}

static func _road_order(game, hi: int, path: Array, spendable: int) -> Dictionary:
	if path.size()<2: return {}
	var pending:=0
	for road in game.roads:
		if int(road.get("builder",-1))==hi and str(road.get("state",""))=="building": pending+=1
	for index in path.size()-1:
		var a:=str(path[index])
		var b:=str(path[index+1])
		var state:=_road_state(game,a,b)
		if state=="complete": continue
		if state=="building" or pending>=int(RULES.max_pending_roads): return {}
		if not game.houses[hi].research.known.has("road_building"):
			return _research_order(game,hi,"road_building",b,spendable)
		var quote: Dictionary=game.road_preview(a,b,hi)
		return {"id":"road","province":a,"to":b} if bool(quote.ok) and int(quote.gold)<=spendable else {}
	return {}

static func _research_order(game, hi: int, wanted: String, province: String, spendable: int) -> Dictionary:
	if not str(game.houses[hi].research.active).is_empty(): return {}
	var choices:= {}
	for choice in game.research_choices(hi,province): choices[str(choice.id)]=choice
	for innovation in RULES.research_path:
		if not game.houses[hi].research.known.has(innovation):
			var choice: Dictionary=choices.get(str(innovation),{})
			if bool(choice.get("enabled",false)) and int(choice.get("gold",0))<=spendable:
				return {"id":"research","province":province,"innovation":str(innovation)}
			return {}
		if str(innovation)==wanted: return {}
	return {}

static func _civil_order(game, hi: int, owned: Array, catalog: Dictionary, blocked: Dictionary, spendable: int) -> Dictionary:
	var candidates: Array=[]
	for p in owned:
		var id:=str(p.id)
		if blocked.has(id) or not p.get("regional_project",{}).is_empty(): continue
		var threat:=_threat(game,hi,p,catalog)
		if threat>0 and int(p.buildings.walls)<3:
			var price: int=game.building_cost("walls",id)
			if price<=spendable: candidates.append({"province":id,"kind":"walls","score":1000.0+threat})
		if int(p.dev)<10:
			var next: Dictionary=p.duplicate(true)
			next.dev=int(p.dev)+1
			var gain: int=game.region_income(next)-game.region_income(p)
			var price: int=game.region_capacity(p).develop_cost
			if float(gain)>=float(RULES.minimum_annual_civilian_gain) and price<=spendable:
				candidates.append({"province":id,"kind":"develop","score":100.0*gain/maxi(1,price)})
		if int(p.buildings.market)<3:
			var gain:=4.0*float(p.get("economic_share",1.0))*(1.0+float(game.research_bonus("market_percent",hi,p))/100.0)*Economy.income_multiplier(str(p.get("economic_focus","balanced")))
			var price: int=game.building_cost("market",id)
			if gain>=float(RULES.minimum_annual_civilian_gain) and price<=spendable:
				candidates.append({"province":id,"kind":"market","score":100.0*gain/maxi(1,price)})
	candidates.sort_custom(func(a: Dictionary,b: Dictionary)->bool:
		if float(a.score)!=float(b.score): return float(a.score)>float(b.score)
		if str(a.province)!=str(b.province): return str(a.province)<str(b.province)
		return str(a.kind)<str(b.kind))
	for candidate in candidates.slice(0,int(RULES.max_project_previews)):
		var quote: Dictionary=game.regional_project_preview(str(candidate.province),str(candidate.kind),hi)
		if not bool(quote.ok) or int(quote.gold)>spendable: continue
		return {"id":"develop","province":str(candidate.province)} if str(candidate.kind)=="develop" else {"id":"build","province":str(candidate.province),"key":str(candidate.kind)}
	return {}

static func _threat(game, hi: int, p: Dictionary, catalog: Dictionary) -> float:
	var pressure:=0.0
	var neighbours: Array=game.neighbours(str(p.id))
	for enemy in game.houses.size():
		if enemy==hi or game.truce_until(enemy,hi)>game.calendar_index() or game.opinion_value(hi,enemy)>=60: continue
		for army in game.houses[enemy].get("armies",[]):
			var location:=str(army.get("province",""))
			if not neighbours.has(location) or not catalog.has(location) or int(catalog[location].owner)==hi: continue
			if int(army.get("strength",0))>0 and int(army.get("morale",0))>0:
				pressure+=float(army.strength)*float(army.morale)/100.0
	return pressure/maxf(100.0,float(p.get("levy",0)))

static func _focus_cost(game, id: String, focus: String, hi: int) -> int:
	for choice in game.province_focus_choices(id,hi):
		if str(choice.id)==focus: return int(choice.cost)
	return Production.MAX_UNITS

static func _land_path(game, hi: int, origin: String, target: String, catalog: Dictionary, blocked: Dictionary) -> Array:
	if not catalog.has(origin) or not catalog.has(target) or blocked.has(origin) or blocked.has(target): return []
	var queue: Array=[origin]
	var previous: Dictionary={origin:""}
	var next:=0
	while next<queue.size():
		var at:=str(queue[next]); next+=1
		if at==target:
			var result: Array=[]
			var cursor:=at
			while not cursor.is_empty():
				result.push_front(cursor)
				cursor=str(previous[cursor])
			return result
		var neighbours: Array=game.neighbours(at).duplicate()
		neighbours.sort()
		for value in neighbours:
			var id:=str(value)
			if previous.has(id) or blocked.has(id) or not catalog.has(id) or int(catalog[id].owner)!=hi: continue
			previous[id]=at
			queue.append(id)
	return []

static func _road_state(game, a: String, b: String) -> String:
	var state:=""
	for road in game.roads:
		if not ((str(road.from)==a and str(road.to)==b) or (str(road.from)==b and str(road.to)==a)): continue
		if str(road.state)=="complete": return "complete"
		state=str(road.state)
	return state

static func _path_complete(game, path: Array) -> bool:
	for index in path.size()-1:
		if _road_state(game,str(path[index]),str(path[index+1]))!="complete": return false
	return true
