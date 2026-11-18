extends RefCounted
## Pure monthly transport of real original stocks. Game supplies eligible offers/reserves.
const Production = preload("res://scripts/RegionalProduction.gd")
const MAX_UNITS := 1000000000000
const MAX_SERIAL := 1000000000
const RULES := {"algorithm_version":1,"max_units":MAX_UNITS,"max_serial":MAX_SERIAL,
	"capacity_per_edge_weight":4,"max_demands":2048,"max_flows":4096,
	"offers_are_after_game_reserve":true,"offers_bounded_by_original_stock":true,
	"received_stock_cannot_relay":true,"shared_bidirectional_edge_capacity":true,
	"equal_priority_rotates_by_month":true,"requires_own_completed_unblocked_path":true,
	"reserves_and_two_month_demand_computed_by_game":true,"overflow_import_forbidden":true}

static func plan(provinces: Array, roads: Array, demands: Array, offers: Dictionary, month_index: int, blocked: Dictionary = {}) -> Dictionary:
	var catalog := _catalog(provinces)
	var edges := _edges(roads,catalog,blocked)
	var graph := {}
	var available := {}
	var room := {}
	var ids: Array=catalog.keys()
	ids.sort()
	for id in ids:
		graph[id]=[]
		var p: Dictionary=catalog[id]
		var production: Dictionary=p.get("production",{}) if p.get("production",{}) is Dictionary else {}
		var stock := clampi(int(production.get("materials_u",0)),0,MAX_UNITS)
		available[id]=mini(stock,_amount(offers.get(id,0))) if not _blocked(p,blocked) else 0
		room[id]=maxi(0,Production.stock_capacity_u(p)-stock)
	for index in edges.size():
		var edge: Dictionary=edges[index]
		if not bool(edge.active): continue
		graph[edge.from].append({"to":edge.to,"index":index})
		graph[edge.to].append({"to":edge.from,"index":index})
	for id in ids:
		graph[id].sort_custom(func(a: Dictionary,b: Dictionary)->bool: return str(a.to)<str(b.to))
	var pending := _demands(demands,catalog,blocked)
	var deltas := {}
	var flows: Array=[]
	for priority in [1,0]:
		var group: Array=[]
		for item in pending:
			if int(item.priority)==priority: group.append(item)
		if group.is_empty(): continue
		var rotation := posmod(month_index,group.size())
		for position in group.size():
			var item: Dictionary=group[(position+rotation)%group.size()]
			var target := str(item.province)
			var needed := mini(int(item.amount_u),int(room[target]))
			while needed>0 and flows.size()<int(RULES.max_flows):
				var route := _source_path(target,int(item.house),catalog,graph,edges,available)
				if route.is_empty(): break
				var source := str(route.source)
				var amount := mini(needed,int(available[source]))
				for edge_index in route.edge_indices:
					amount=mini(amount,int(edges[edge_index].capacity_u)-int(edges[edge_index].used_u))
				if amount<=0: break
				available[source]=int(available[source])-amount
				room[target]=int(room[target])-amount
				needed-=amount
				deltas[source]=int(deltas.get(source,0))-amount
				deltas[target]=int(deltas.get(target,0))+amount
				for edge_index in route.edge_indices:
					edges[edge_index].used_u=int(edges[edge_index].used_u)+amount
				flows.append({"from":source,"to":target,"amount_u":amount,"path":route.path})
	var ordered_deltas := {}
	for id in ids:
		if int(deltas.get(id,0))!=0: ordered_deltas[id]=int(deltas[id])
	return {"deltas":ordered_deltas,"flows":flows,"edges":edges}

static func _amount(value: Variant) -> int:
	if not value is int: return 0
	return clampi(int(value),0,MAX_UNITS)

static func _catalog(provinces: Array) -> Dictionary:
	var counts := {}
	for p in provinces:
		if p is Dictionary and not str(p.get("id","")).is_empty():
			var id := str(p.id)
			counts[id]=int(counts.get(id,0))+1
	var result := {}
	for p in provinces:
		if not p is Dictionary: continue
		var id := str(p.get("id",""))
		if id.is_empty() or int(counts.get(id,0))!=1: continue
		result[id]=p
	return result

static func _blocked(province: Dictionary, blocked: Dictionary) -> bool:
	var reason = blocked.get(str(province.get("id","")),false)
	if reason is bool and reason: return true
	if reason is String and not reason.is_empty(): return true
	var siege_owner := int(province.get("siege_owner",-1))
	return int(province.get("siege",0))>0 and siege_owner>=0 and siege_owner!=int(province.get("owner",-1))

static func _edges(roads: Array, catalog: Dictionary, blocked: Dictionary) -> Array:
	var unique := {}
	for road in roads:
		if not road is Dictionary: continue
		var a := str(road.get("from",""))
		var b := str(road.get("to",""))
		if a>b:
			var swap:=a; a=b; b=swap
		var key:=JSON.stringify([a,b])
		unique[key]=bool(unique.get(key,false)) or str(road.get("state",""))=="complete"
	var keys: Array=unique.keys()
	keys.sort()
	var result: Array=[]
	for key in keys:
		var endpoints: Array=JSON.parse_string(key)
		var a:=str(endpoints[0])
		var b:=str(endpoints[1])
		var reason:=""
		var capacity:=0
		if a==b: reason="Identical road endpoints."
		elif not catalog.has(a) or not catalog.has(b): reason="Unknown road endpoint."
		elif not bool(unique[key]): reason="Road is not complete."
		elif int(catalog[a].get("owner",-1))<0 or int(catalog[a].get("owner",-1))!=int(catalog[b].get("owner",-1)): reason="Road endpoints are not under the same own control."
		elif _blocked(catalog[a],blocked) or _blocked(catalog[b],blocked): reason="Hostile occupation blocks the road."
		else: capacity=int(RULES.capacity_per_edge_weight)*Production.edge_weight_u(catalog[a],catalog[b])
		result.append({"from":a,"to":b,"capacity_u":capacity,"used_u":0,"active":reason.is_empty(),"reason":reason})
	return result

static func _demands(demands: Array, catalog: Dictionary, blocked: Dictionary) -> Array:
	var result: Array=[]
	for item in demands.slice(0,int(RULES.max_demands)):
		if not item is Dictionary: continue
		var id:=str(item.get("province",""))
		var house:=int(item.get("house",-1))
		var project:=int(item.get("project_id",-1))
		if not catalog.has(id) or int(catalog[id].get("owner",-1))!=house or house<0 or _blocked(catalog[id],blocked): continue
		if project<0 or project>MAX_SERIAL: continue
		var amount:=_amount(item.get("amount_u",0))
		if amount<=0: continue
		result.append({"province":id,"house":house,"amount_u":amount,"priority":clampi(int(item.get("priority",0)),0,1),"project_id":project})
	result.sort_custom(func(a: Dictionary,b: Dictionary)->bool:
		if int(a.project_id)!=int(b.project_id): return int(a.project_id)<int(b.project_id)
		if str(a.province)!=str(b.province): return str(a.province)<str(b.province)
		if int(a.priority)!=int(b.priority): return int(a.priority)>int(b.priority)
		return int(a.amount_u)<int(b.amount_u))
	return result

static func _source_path(target: String, house: int, catalog: Dictionary, graph: Dictionary, edges: Array, available: Dictionary) -> Dictionary:
	var queue: Array=[target]
	var previous: Dictionary={target:""}
	var edge_to: Dictionary={}
	var next:=0
	while next<queue.size():
		var node:=str(queue[next])
		next+=1
		if node!=target and int(available.get(node,0))>0:
			var path: Array=[node]
			var path_edges: Array=[]
			var cursor:=node
			while cursor!=target:
				path_edges.append(int(edge_to[cursor]))
				cursor=str(previous[cursor])
				path.append(cursor)
			return {"source":node,"path":path,"edge_indices":path_edges}
		for neighbour in graph.get(node,[]):
			var id:=str(neighbour.to)
			var edge_index:=int(neighbour.index)
			if previous.has(id) or int(catalog[id].get("owner",-1))!=house: continue
			if int(edges[edge_index].used_u)>=int(edges[edge_index].capacity_u): continue
			previous[id]=node
			edge_to[id]=edge_index
			queue.append(id)
	return {}
