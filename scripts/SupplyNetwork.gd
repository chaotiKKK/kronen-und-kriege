extends RefCounted
## Abgeleitete, ganzzahlige Versorgung; weder Zustandsänderung noch Nahrungsvorrat.
## Armeen gehören bereits dem angefragten Haus. Kapazitäten enthalten den Bonus.

static func calculate(provinces: Array, roads: Array, armies: Array, house_index: int, local_capacities: Dictionary, agriculture_bonuses: Dictionary, blocked: Dictionary = {}) -> Dictionary:
	var catalog := {}
	var own := {}
	var demand := {}
	for province in provinces:
		if not province is Dictionary or str(province.get("id","")).is_empty():
			continue
		var id := str(province.id)
		catalog[id] = province
		if house_index >= 0 and int(province.get("owner",-1)) == house_index:
			own[id] = true
	for army in armies:
		if not army is Dictionary:
			continue
		var id := str(army.get("province",""))
		if catalog.has(id):
			demand[id] = int(demand.get(id,0)) + maxi(0,int(army.get("strength",0)))
	var included := own.duplicate()
	for id in demand:
		included[id] = true
	var ids: Array = included.keys()
	ids.sort()
	var regions := {}
	for id in ids:
		var capacity := maxi(0,int(local_capacities.get(id,0)))
		var needed := int(demand.get(id,0))
		var available := mini(maxi(0,int(agriculture_bonuses.get(id,0))),maxi(0,capacity-needed)) if own.has(id) else 0
		regions[id] = {"demand":needed,"local_capacity":capacity,"export_available":available,"export":0,"import":0,"shortfall":maxi(0,needed-capacity)}
	var edges := _roads(roads,catalog,own,house_index,blocked)
	var graph := {}
	var own_ids: Array = own.keys()
	own_ids.sort()
	for id in own_ids:
		graph[id] = []
	for edge in edges:
		if edge.active:
			graph[edge.from].append(edge.to)
			graph[edge.to].append(edge.from)
	var visited := {}
	var networks: Array = []
	for id in own_ids:
		if visited.has(id):
			continue
		var members: Array = [id]
		visited[id] = true
		var next := 0
		while next < members.size():
			for neighbour in graph[members[next]]:
				if not visited.has(neighbour):
					visited[neighbour] = true
					members.append(neighbour)
			next += 1
		members.sort()
		networks.append(_distribute(members,regions))
	return {"regions":regions,"roads":edges,"networks":networks}

static func _roads(roads: Array, catalog: Dictionary, own: Dictionary, house_index: int, blocked: Dictionary = {}) -> Array:
	# Gegenläufige/mehrfach gespeicherte Kanten teilen genau eine Verbindung.
	# Falls alte Daten eine Baustelle und fertige Kante enthalten, gilt die fertige.
	var unique := {}
	for road in roads:
		if not road is Dictionary:
			continue
		var a := str(road.get("from",""))
		var b := str(road.get("to",""))
		if a > b:
			var swap := a
			a = b
			b = swap
		var key := JSON.stringify([a,b])
		unique[key] = bool(unique.get(key,false)) or str(road.get("state","")) == "complete"
	var result: Array = []
	for key in unique:
		var endpoints: Array = JSON.parse_string(key)
		var a: String = endpoints[0]
		var b: String = endpoints[1]
		var reason := ""
		if a == b:
			reason = "Keine Verbindung zwischen verschiedenen Provinzen."
		elif not catalog.has(a) or not catalog.has(b):
			reason = "Unbekannter Straßenendpunkt."
		elif not bool(unique[key]):
			reason = "Straße noch nicht fertiggestellt."
		elif not own.has(a) or not own.has(b):
			reason = "Straßenendpunkte stehen nicht beide unter eigener Kontrolle."
		elif _hostile_siege(catalog[a],house_index) or _hostile_siege(catalog[b],house_index):
			reason = "Feindliche Belagerung unterbricht die Versorgung."
		elif blocked.has(a) or blocked.has(b):
			reason = "Fremdes Feldheer unterbricht die Versorgung."
		result.append({"from":a,"to":b,"active":reason.is_empty(),"reason":reason})
	result.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		return a.from < b.from if a.from != b.from else a.to < b.to)
	return result

static func _hostile_siege(province: Dictionary, house_index: int) -> bool:
	var besieger := int(province.get("siege_owner",-1))
	return int(province.get("siege",0)) > 0 and besieger >= 0 and besieger != house_index

static func _distribute(members: Array, regions: Dictionary) -> Dictionary:
	var supplies := {}
	var deficits := {}
	var available := 0
	var missing := 0
	var network := {"id":members[0],"members":members,"demand":0,"local_capacity":0,"export_available":0,"export":0,"import":0,"shortfall":0}
	for id in members:
		var region: Dictionary = regions[id]
		supplies[id] = int(region.export_available)
		deficits[id] = int(region.shortfall)
		available += int(region.export_available)
		missing += int(region.shortfall)
		network.demand += int(region.demand)
		network.local_capacity += int(region.local_capacity)
	var transferred := mini(available,missing)
	var imports := _apportion(members,deficits,missing,transferred)
	var exports := _apportion(members,supplies,available,transferred)
	for id in members:
		regions[id]["export"] = exports[id]
		regions[id]["import"] = imports[id]
		regions[id]["shortfall"] = int(deficits[id])-int(imports[id])
	network.export_available = available
	network["export"] = transferred
	network["import"] = transferred
	network.shortfall = missing-transferred
	return network

static func _apportion(ids: Array, weights: Dictionary, total: int, budget: int) -> Dictionary:
	var assigned := {}
	var remainders: Array = []
	var used := 0
	for id in ids:
		var numerator := int(weights[id])*budget
		@warning_ignore("integer_division")
		var share: int = numerator/total if total > 0 else 0
		assigned[id] = share
		used += share
		if total > 0 and int(weights[id]) > 0:
			remainders.append({"id":id,"remainder":numerator%total})
	remainders.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		return a.remainder > b.remainder if a.remainder != b.remainder else a.id < b.id)
	for index in budget-used:
		assigned[remainders[index].id] += 1
	return assigned
