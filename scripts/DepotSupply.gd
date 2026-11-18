extends RefCounted
## Finite frontier delivery after the existing own-network allocation.
## Inputs and own demand/import/shortfall totals remain unchanged.
const RULES := {
	"unit":1000000,
	"depot_men_per_weight":300,
	"depot_level":1,
	"source_budget":"export_available-minus-existing-export",
	"network":"existing-members-and-active-roads-own-unblocked-only",
	"receiver":"own-army-on-land-adjacent-foreign-region-no-relay",
	"order":"network-id-depot-id-receiver-id-source-id",
	"network_export":"internal-plus-frontier-export",
	"network_import_demand_shortfall":"own-members-only",
	"blocked":"explicit-region-or-hostile-siege",
	"food_creation":false
}

static func apply(report: Dictionary, provinces: Array, adjacency: Dictionary, armies: Array, house_index: int, blocked: Dictionary = {}) -> Dictionary:
	var result: Dictionary = report.duplicate(true)
	result["frontier_deliveries"] = []
	var catalog := {}
	for province in provinces:
		if province is Dictionary and not str(province.get("id","")).is_empty():
			catalog[str(province.id)] = province
	var receivers := {}
	for army in armies:
		if army is Dictionary and int(army.get("strength",0)) > 0:
			receivers[str(army.get("province",""))] = true
	var regions: Dictionary = result.get("regions",{})
	var networks: Array = result.get("networks",[])
	var order: Array = range(networks.size())
	order.sort_custom(func(a: int,b: int) -> bool: return str(networks[a].get("id","")) < str(networks[b].get("id","")))
	var depot_remaining := {}
	for index in order:
		var network: Dictionary = networks[index]
		network["frontier_export"] = 0
		var graph := _network_graph(network,result.get("roads",[]),catalog,house_index,blocked)
		var depots: Array = graph.keys()
		depots.sort()
		for depot_id in depots:
			var site: Dictionary = catalog[depot_id]
			if int(site.get("logistics_sites",{}).get("depot",0)) != int(RULES.depot_level):
				continue
			if not depot_remaining.has(depot_id):
				depot_remaining[depot_id] = _capacity(site)
			if int(depot_remaining[depot_id]) <= 0:
				continue
			var targets: Array = []
			for neighbor in adjacency.get(depot_id,[]):
				var target := str(neighbor)
				if targets.has(target) or not receivers.has(target) or not catalog.has(target) or not regions.has(target):
					continue
				if int(catalog[target].get("owner",-1)) == house_index or _blocked(catalog[target],house_index,blocked):
					continue
				targets.append(target)
			targets.sort()
			var sources := _reachable(depot_id,graph)
			for target in targets:
				for source in sources:
					if int(depot_remaining[depot_id]) <= 0 or int(regions[target].get("shortfall",0)) <= 0:
						break
					if not regions.has(source):
						continue
					var available := maxi(0,int(regions[source].get("export_available",0))-int(regions[source].get("export",0)))
					var amount := mini(available,mini(int(depot_remaining[depot_id]),int(regions[target].shortfall)))
					if amount <= 0:
						continue
					regions[source]["export"] = int(regions[source].get("export",0))+amount
					regions[target]["import"] = int(regions[target].get("import",0))+amount
					regions[target]["shortfall"] = int(regions[target].shortfall)-amount
					depot_remaining[depot_id] = int(depot_remaining[depot_id])-amount
					network["export"] = int(network.get("export",0))+amount
					network["frontier_export"] = int(network.frontier_export)+amount
					result.frontier_deliveries.append({"from":source,"depot":depot_id,"to":target,"amount":amount})
	return result

static func _network_graph(network: Dictionary, roads: Array, catalog: Dictionary, house_index: int, blocked: Dictionary) -> Dictionary:
	var graph := {}
	for member in network.get("members",[]):
		var id := str(member)
		if catalog.has(id) and int(catalog[id].get("owner",-1)) == house_index and not _blocked(catalog[id],house_index,blocked):
			graph[id] = []
	for road in roads:
		var a := str(road.get("from",""))
		var b := str(road.get("to",""))
		if bool(road.get("active",false)) and graph.has(a) and graph.has(b):
			if not graph[a].has(b): graph[a].append(b)
			if not graph[b].has(a): graph[b].append(a)
	return graph

static func _reachable(start: String, graph: Dictionary) -> Array:
	var seen := {start:true}
	var pending: Array = [start]
	var next := 0
	while next < pending.size():
		for neighbor in graph[pending[next]]:
			if not seen.has(neighbor):
				seen[neighbor] = true
				pending.append(neighbor)
		next += 1
	var ids: Array = seen.keys()
	ids.sort()
	return ids

static func _blocked(province: Dictionary, house_index: int, blocked: Dictionary) -> bool:
	var obstruction = blocked.get(str(province.id),false)
	if obstruction is bool:
		if obstruction: return true
	elif obstruction is String or obstruction is StringName:
		if not str(obstruction).is_empty(): return true
	var besieger := int(province.get("siege_owner",-1))
	return int(province.get("siege",0)) > 0 and besieger >= 0 and besieger != house_index

static func _capacity(province: Dictionary) -> int:
	var weight := maxi(1,roundi(float(province.get("economic_share",1.0))*int(RULES.unit)))
	@warning_ignore("integer_division")
	return int(RULES.depot_men_per_weight)*weight/int(RULES.unit)
